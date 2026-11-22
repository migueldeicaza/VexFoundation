// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/curve.ts` (VexFlow 5.0.0).
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
    /// Two control points for the bezier curves.
    public var cps: [(x: Double, y: Double)]
    public var thickness: Double
    public var xShift: Double
    public var yShift: Double
    public var position: CurvePosition
    public var positionEnd: CurvePosition
    public var invert: Bool
    public var openingDirection: CurveOpeningDirection

    public init(
        cps: [(x: Double, y: Double)] = [(0, 10), (0, 10)],
        thickness: Double = 2,
        xShift: Double = 0,
        yShift: Double = 10,
        position: CurvePosition = .nearHead,
        positionEnd: CurvePosition = .nearHead,
        invert: Bool = false,
        openingDirection: CurveOpeningDirection = .auto
    ) {
        self.cps = cps
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
        self.from = from
        self.to = to
        super.init()
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

    public func renderCurve(
        firstX: Double,
        firstY: Double,
        lastX: Double,
        lastY: Double,
        direction: Double
    ) throws {
        let ctx = try checkContext()

        let xShift = renderOptions.xShift
        let yShift = renderOptions.yShift * direction

        let firstX = firstX + xShift
        let firstY = firstY + yShift
        let lastX = lastX - xShift
        let lastY = lastY + yShift
        let thickness = renderOptions.thickness

        let cps = renderOptions.cps
        let cp0x = cps[0].x
        let cp0y = cps[0].y
        let cp1x = cps[1].x
        let cp1y = cps[1].y

        let controlPointSpacing = (lastX - firstX) / Double(cps.count + 2)

        let hasLineDash = !(style?.lineDash ?? "").isEmpty

        ctx.beginPath()
        ctx.moveTo(firstX, firstY)
        ctx.bezierCurveTo(
            firstX + controlPointSpacing + cp0x,
            firstY + cp0y * direction,
            lastX - controlPointSpacing + cp1x,
            lastY + cp1y * direction,
            lastX,
            lastY
        )
        if !hasLineDash {
            ctx.bezierCurveTo(
                lastX - controlPointSpacing + cp1x,
                lastY + (cp1y + thickness) * direction,
                firstX + controlPointSpacing + cp0x,
                firstY + (cp0y + thickness) * direction,
                firstX,
                firstY
            )
        }
        ctx.stroke()
        ctx.closePath()
        if !hasLineDash { ctx.fill() }
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

        let firstNote = from
        let lastNote = to
        var firstX: Double = 0
        var lastX: Double = 0
        var firstY: Double = 0
        var lastY: Double = 0
        var stemDirection: Double = 0

        var useTopY = false
        var endUseTopY = false

        let position = renderOptions.position
        let positionEnd = renderOptions.positionEnd

        if position == .nearTop {
            useTopY = true
            endUseTopY = true
        }

        if positionEnd == .nearHead {
            endUseTopY = false
        } else if positionEnd == .nearTop {
            endUseTopY = true
        }

        if let firstNote {
            firstX = firstNote.getTieRightX()
            stemDirection = firstNote.getStemDirection().signDouble
            let extents = firstNote.getStemExtents()
            firstY = useTopY ? extents.topY : extents.baseY
        } else if let lastNote {
            let stave = lastNote.checkStave()
            firstX = stave.getTieStartX()
            let extents = lastNote.getStemExtents()
            firstY = useTopY ? extents.topY : extents.baseY
        }

        if let lastNote {
            lastX = lastNote.getTieLeftX()
            stemDirection = lastNote.getStemDirection().signDouble
            let extents = lastNote.getStemExtents()
            lastY = endUseTopY ? extents.topY : extents.baseY
        } else if let firstNote {
            let stave = firstNote.checkStave()
            lastX = stave.getTieEndX()
            let extents = firstNote.getStemExtents()
            lastY = endUseTopY ? extents.topY : extents.baseY
        }

        if renderOptions.openingDirection == .up {
            stemDirection = 1
        }
        if renderOptions.openingDirection == .down {
            stemDirection = -1
        }

        try renderCurve(
            firstX: firstX,
            firstY: firstY,
            lastX: lastX,
            lastY: lastY,
            direction: stemDirection * (renderOptions.invert ? -1 : 1)
        )
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
