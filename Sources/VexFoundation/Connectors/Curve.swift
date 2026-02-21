// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum CurveError: Error, LocalizedError, Equatable, Sendable {
    case requiresStartOrEndNote

    public var errorDescription: String? {
        switch self {
        case .requiresStartOrEndNote:
            return "Curve needs to have either from or to set."
        }
    }
}

// MARK: - Curve Position

public enum CurvePosition: Int {
    case nearHead = 1
    case nearTop = 2
}

// MARK: - Curve Options

public struct CurveOptions {
    public var cps: [(x: Double, y: Double)]
    public var thickness: Double
    public var xShift: Double
    public var yShift: Double
    public var position: CurvePosition
    public var positionEnd: CurvePosition
    public var invert: Bool

    public init(
        cps: [(x: Double, y: Double)] = [(0, 10), (0, 10)],
        thickness: Double = 2,
        xShift: Double = 0,
        yShift: Double = 10,
        position: CurvePosition = .nearHead,
        positionEnd: CurvePosition = .nearHead,
        invert: Bool = false
    ) {
        self.cps = cps
        self.thickness = thickness
        self.xShift = xShift
        self.yShift = yShift
        self.position = position
        self.positionEnd = positionEnd
        self.invert = invert
    }
}

// MARK: - Curve

/// Implements curves (slurs) between notes using cubic Bézier curves.
public final class Curve: VexElement {

    override public class var category: String { "Curve" }

    // MARK: - Properties

    public var renderOptions: CurveOptions
    public var from: Note?
    public var to: Note?

    // MARK: - Init

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

    public func isPartial() -> Bool {
        from == nil || to == nil
    }

    // MARK: - Render Curve

    public func renderCurve(
        firstX: Double,
        firstY: Double,
        lastX: Double,
        lastY: Double,
        direction: TieDirection
    ) throws {
        let ctx = try checkContext()

        let xShift = renderOptions.xShift
        let yShift = renderOptions.yShift * direction.signDouble

        let fx = firstX + xShift
        let fy = firstY + yShift
        let lx = lastX - xShift
        let ly = lastY + yShift
        let thickness = renderOptions.thickness

        let cps = renderOptions.cps
        let cp0x = cps[0].x
        let cp0y = cps[0].y
        let cp1x = cps[1].x
        let cp1y = cps[1].y

        let cpSpacing = (lx - fx) / Double(cps.count + 2)

        ctx.beginPath()
        ctx.moveTo(fx, fy)
        ctx.bezierCurveTo(
            fx + cpSpacing + cp0x,
            fy + cp0y * direction.signDouble,
            lx - cpSpacing + cp1x,
            ly + cp1y * direction.signDouble,
            lx,
            ly
        )
        ctx.bezierCurveTo(
            lx - cpSpacing + cp1x,
            ly + (cp1y + thickness) * direction.signDouble,
            fx + cpSpacing + cp0x,
            fy + (cp0y + thickness) * direction.signDouble,
            fx,
            fy
        )
        ctx.stroke()
        ctx.closePath()
        ctx.fill()
    }

    // MARK: - Draw

    override public func draw() throws {
        _ = try checkContext()
        setRendered()

        guard from != nil || to != nil else {
            throw CurveError.requiresStartOrEndNote
        }

        let firstNote = from
        let lastNote = to

        var firstX: Double = 0
        var lastX: Double = 0
        var firstY: Double = 0
        var lastY: Double = 0
        var tieDirection: TieDirection?

        // Determine Y metric based on position
        let useTopYForStart = renderOptions.position == .nearTop
        let useTopYForEnd = renderOptions.positionEnd == .nearTop

        if let firstNote {
            firstX = firstNote.getTieRightX()
            tieDirection = TieDirection(stemDirection: firstNote.getStemDirection())
            let extents = firstNote.getStemExtents()
            firstY = useTopYForStart ? extents.topY : extents.baseY
        } else if let lastNote {
            let stave = lastNote.checkStave()
            firstX = stave.getTieStartX()
            let extents = lastNote.getStemExtents()
            firstY = useTopYForStart ? extents.topY : extents.baseY
        }

        if let lastNote {
            lastX = lastNote.getTieLeftX()
            tieDirection = TieDirection(stemDirection: lastNote.getStemDirection())
            let extents = lastNote.getStemExtents()
            lastY = useTopYForEnd ? extents.topY : extents.baseY
        } else if let firstNote {
            let stave = firstNote.checkStave()
            lastX = stave.getTieEndX()
            let extents = firstNote.getStemExtents()
            lastY = useTopYForEnd ? extents.topY : extents.baseY
        }

        let direction = renderOptions.invert ? (tieDirection ?? .up).inverted : (tieDirection ?? .up)

        try renderCurve(
            firstX: firstX,
            firstY: firstY,
            lastX: lastX,
            lastY: lastY,
            direction: direction
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
        FontLoader.loadDefaultFonts()

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
