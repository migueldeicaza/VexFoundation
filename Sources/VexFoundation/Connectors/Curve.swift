// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/curve.ts` (VexFlow 5.8.0).
// This class implements curves (for slurs).

import Foundation

public enum CurveError: Error, LocalizedError, Equatable, Sendable {
    case requiresStartOrEndNote

    public var errorDescription: String? {
        switch self {
        case .requiresStartOrEndNote:
            return "Curve needs to have either `from` or `to` set."
        }
    }
}

// MARK: - Curve Position

public enum CurvePosition: Int, Sendable {
    /// Upstream `'auto'` (VexFlow 5.3.0 default): the notehead, or the stem tip on the
    /// stem side of a curve with an explicit opening direction.
    case auto = 0
    case nearHead = 1
    case nearTop = 2
}

/// Opening direction of a curve. `.auto` follows the stem direction.
public enum CurveOpeningDirection: String, Sendable {
    case up
    case down
    case auto
}

// MARK: - Curve Options

public struct CurveOptions {
    /// Stroke the first half of the fitted slur with dashes and the second half solid. (VexFlow 5.8.0)
    public var halfDashed: Bool
    /// Two control points for the bezier curves.
    public var cps: [(x: Double, y: Double)]
    public var thickness: Double
    public var xShift: Double
    public var yShift: Double
    public var position: CurvePosition
    public var positionEnd: CurvePosition
    public var invert: Bool
    public var openingDirection: CurveOpeningDirection
    /// True when the caller passed `cps` (upstream `options.cps !== undefined`). (VexFlow 5.4.0)
    public var authoredControls: Bool

    public init(
        cps: [(x: Double, y: Double)]? = nil,
        thickness: Double = 2,
        xShift: Double = 0,
        yShift: Double = 10,
        position: CurvePosition = .auto,
        positionEnd: CurvePosition = .auto,
        invert: Bool = false,
        openingDirection: CurveOpeningDirection = .auto,
        halfDashed: Bool = false
    ) {
        self.halfDashed = halfDashed
        self.cps = cps ?? [(0, 10), (0, 10)]
        self.authoredControls = cps != nil
        self.thickness = thickness
        self.xShift = xShift
        self.yShift = yShift
        self.position = position
        self.positionEnd = positionEnd
        self.invert = invert
        self.openingDirection = openingDirection
    }
}

// MARK: - Curve

/// Implements curves (slurs) between notes using cubic Bézier curves.
public final class Curve: VexElement {

    override public class var category: String { "Curve" }

    public static let positionString: [String: CurvePosition] = [
        "nearHead": .nearHead,
        "nearTop": .nearTop,
        "auto": .auto,
    ]

    // MARK: - Properties

    public var renderOptions: CurveOptions
    public var from: Note?
    public var to: Note?

    // MARK: - Init

    /// - Parameters:
    ///   - from: Start note
    ///   - to: End note
    ///   - options: control points, shifts, positions
    public init(from: Note?, to: Note?, options: CurveOptions = CurveOptions()) {
        self.renderOptions = options
        self.authoredControls = options.authoredControls
        self.from = from
        self.to = to
        super.init()
    }

    private var layoutRise: Double = 0
    private let authoredControls: Bool

    /// Automatic routing changes only the derived lift, preserving the authored control points. (VexFlow 5.4.0)
    public func setLayoutRise(_ rise: Double) {
        layoutRise = rise
    }

    /// True for authored or edited control points. (VexFlow 5.4.0)
    public func hasManualControls() -> Bool {
        authoredControls || renderOptions.cps.contains { $0.x != 0 || $0.y != 10 }
    }

    /// The attached notes. (VexFlow 5.4.0)
    public func getNotes() -> (firstNote: Note?, lastNote: Note?) {
        (from, to)
    }

    /// Subdivided ink of the actual rendered cubic. (VexFlow 5.4.0)
    public func getRouteParts() throws -> [BoundingBox] {
        let (first, last, cps, thicknessCps) = getBezierPoints(try getRenderParams())
        let point: ((x: Double, y: Double)) -> RibbonPoint = { RibbonPoint(x: $0.x, y: $0.y) }
        let outer = [point(first)] + cps.map(point) + [point(last)]
        return ribbonParts(
            outer,
            renderOptions.halfDashed || hasLineDash ? outer : [point(first)] + thicknessCps.reversed().map(point) + [point(last)],
            padding: (getStyle()?.lineWidth ?? 1) / 2
        )
    }

    // MARK: - Notes

    @discardableResult
    public func setNotes(from: Note?, to: Note?) -> Self {
        _ = try? setNotesThrowing(from: from, to: to)
        return self
    }

    @discardableResult
    public func setNotesThrowing(from: Note?, to: Note?) throws -> Self {
        guard from != nil || to != nil else {
            throw CurveError.requiresStartOrEndNote
        }
        self.from = from
        self.to = to
        return self
    }

    /// Returns true if this is a partial bar.
    public func isPartial() -> Bool {
        from == nil || to == nil
    }

    // MARK: - Render Curve

    /// End points and directions computed by `getRenderParams()`.
    private struct RenderParams {
        var firstX: Double
        var firstY: Double
        var lastX: Double
        var lastY: Double
        var direction: Double
    }

    /// End points and control points of the bezier curve(s) for `renderCurve()`.
    /// The first bezier is the upper edge of the slur, the second one (only drawn for solid lines)
    /// goes back from the last to the first point, at a distance of `thickness`. (VexFlow 5.1.0)
    private func getBezierPoints(_ params: RenderParams) -> (
        first: (x: Double, y: Double),
        last: (x: Double, y: Double),
        cps: [(x: Double, y: Double)],
        thicknessCps: [(x: Double, y: Double)]
    ) {
        let xShift = renderOptions.xShift
        let yShift = renderOptions.yShift * params.direction

        let firstX = params.firstX + xShift
        let firstY = params.firstY + yShift
        let lastX = params.lastX - xShift
        let lastY = params.lastY + yShift
        let thickness = renderOptions.thickness

        let cps = renderOptions.cps
        let cp0x = cps[0].x
        let cp0y = cps[0].y + layoutRise
        let cp1x = cps[1].x
        let cp1y = cps[1].y + layoutRise

        let controlPointSpacing = (lastX - firstX) / Double(cps.count + 2)

        return (
            first: (firstX, firstY),
            last: (lastX, lastY),
            cps: [
                (firstX + controlPointSpacing + cp0x, firstY + cp0y * params.direction),
                (lastX - controlPointSpacing + cp1x, lastY + cp1y * params.direction),
            ],
            thicknessCps: [
                (lastX - controlPointSpacing + cp1x, lastY + (cp1y + thickness) * params.direction),
                (firstX + controlPointSpacing + cp0x, firstY + (cp0y + thickness) * params.direction),
            ]
        )
    }

    private var hasLineDash: Bool { !(style?.lineDash ?? "").isEmpty }

    public func renderCurve(
        firstX: Double,
        firstY: Double,
        lastX: Double,
        lastY: Double,
        direction: Double
    ) throws {
        let ctx = try checkContext()
        let (first, last, cps, thicknessCps) = getBezierPoints(
            RenderParams(firstX: firstX, firstY: firstY, lastX: lastX, lastY: lastY, direction: direction)
        )

        if renderOptions.halfDashed {
            // JavaScript `lineDash.split(' ').map(Number)`: an empty item is 0.
            let dash = hasLineDash
                ? style?.lineDash?.split(separator: " ", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? 0 : Double($0) ?? .nan }
                : nil
            let point: ((x: Double, y: Double)) -> RibbonPoint = { RibbonPoint(x: $0.x, y: $0.y) }
            drawHalfDashedSlur(ctx, [point(first)] + cps.map(point) + [point(last)], dash: dash ?? [4, 3])
            return
        }

        ctx.beginPath()
        ctx.moveTo(first.x, first.y)
        ctx.bezierCurveTo(cps[0].x, cps[0].y, cps[1].x, cps[1].y, last.x, last.y)
        if !hasLineDash {
            ctx.bezierCurveTo(
                thicknessCps[0].x, thicknessCps[0].y, thicknessCps[1].x, thicknessCps[1].y, first.x, first.y
            )
        }
        ctx.stroke()
        ctx.closePath()
        if !hasLineDash { ctx.fill() }
    }

    /// Values of a cubic bezier curve (along one axis) at its end points and at its local extrema.
    /// The extrema are where the derivative, a quadratic in t, is zero.
    static func bezierExtrema(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> [Double] {
        var values = [p0, p3]
        // Derivative / 3 = a * t^2 + b * t + c
        let a = -p0 + 3 * p1 - 3 * p2 + p3
        let b = 2 * (p0 - 2 * p1 + p2)
        let c = p1 - p0

        var ts: [Double] = []
        if abs(a) < 1e-12 {
            if abs(b) > 1e-12 { ts.append(-c / b) }
        } else {
            let discriminant = b * b - 4 * a * c
            if discriminant >= 0 {
                let root = discriminant.squareRoot()
                ts.append((-b + root) / (2 * a))
                ts.append((-b - root) / (2 * a))
            }
        }
        for t in ts where t > 0 && t < 1 {
            let u = 1 - t
            values.append(u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3)
        }
        return values
    }

    /// The bounding box of the drawn curve, including its thickness but not the stroke width.
    /// The notes must be formatted. The box is fitted to the extrema of the bezier curves,
    /// not to their control points. (VexFlow 5.1.0)
    override public func getBoundingBox() -> BoundingBox? {
        guard let params = try? getRenderParams() else { return nil }
        let (first, last, cps, thicknessCps) = getBezierPoints(params)
        var xs = Self.bezierExtrema(first.x, cps[0].x, cps[1].x, last.x)
        var ys = Self.bezierExtrema(first.y, cps[0].y, cps[1].y, last.y)
        if !renderOptions.halfDashed && !hasLineDash {
            xs += Self.bezierExtrema(last.x, thicknessCps[0].x, thicknessCps[1].x, first.x)
            ys += Self.bezierExtrema(last.y, thicknessCps[0].y, thicknessCps[1].y, first.y)
        }
        let minX = xs.min() ?? 0
        let minY = ys.min() ?? 0
        return BoundingBox(x: minX, y: minY, w: (xs.max() ?? 0) - minX, h: (ys.max() ?? 0) - minY)
    }

    /// Source-compatibility overload that takes a `TieDirection`.
    public func renderCurve(
        firstX: Double,
        firstY: Double,
        lastX: Double,
        lastY: Double,
        direction: TieDirection
    ) throws {
        try renderCurve(firstX: firstX, firstY: firstY, lastX: lastX, lastY: lastY, direction: direction.signDouble)
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        guard from != nil || to != nil else {
            throw CurveError.requiresStartOrEndNote
        }

        // Local change (1af03ba): apply the element style in draw().
        ctx.save()
        defer { ctx.restore() }
        applyStyle(context: ctx)

        let params = try getRenderParams()
        try renderCurve(
            firstX: params.firstX,
            firstY: params.firstY,
            lastX: params.lastX,
            lastY: params.lastY,
            direction: params.direction
        )
    }

    /// The points where the curve starts and ends, and the direction it bulges to.
    /// Requires formatted notes.
    private func getRenderParams() throws -> RenderParams {
        guard from != nil || to != nil else {
            throw CurveError.requiresStartOrEndNote
        }
        guard let start = from ?? to, let end = to ?? from else {
            throw CurveError.requiresStartOrEndNote
        }
        let openingDirection = renderOptions.openingDirection
        var direction = end.getStemDirection().signDouble
        if openingDirection == .up { direction = 1 }
        if openingDirection == .down { direction = -1 }
        if renderOptions.invert { direction *= -1 }

        // An opening-up slur sits below the staff. On its stem side, attach beyond the stem
        // tip (and beam). Keep authored head/tip anchors and automatic-opening defaults.
        func endpointY(_ note: Note, _ position: CurvePosition) -> Double {
            let extents = note.getStemExtents()
            let onStemSide = direction == -note.getStemDirection().signDouble
            let useTip = position == .nearTop || (position == .auto && openingDirection != .auto && onStemSide)
            return useTip ? extents.topY : extents.baseY
        }

        return RenderParams(
            firstX: from.map { $0.getTieRightX() } ?? end.checkStave().getTieStartX(),
            firstY: endpointY(start, renderOptions.position),
            lastX: to.map { $0.getTieLeftX() } ?? start.checkStave().getTieEndX(),
            lastY: endpointY(end, renderOptions.positionEnd),
            direction: direction
        )
    }

    /// Endpoints on the rendered curve after authored shifts. (VexFlow 5.3.0)
    public func getAnchors() throws -> (start: (x: Double, y: Double), end: (x: Double, y: Double)) {
        let points = getBezierPoints(try getRenderParams())
        return (start: points.first, end: points.last)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Curve", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()

        _ = f.Curve(from: notes[0], to: notes[3])

        try? f.draw()
    }
    .padding()
}
#endif
