// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

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

    override public class var CATEGORY: String { "Curve" }

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
        guard from != nil || to != nil else {
            fatalError("[VexError] BadArguments: Curve needs to have either from or to set.")
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
        direction: Int
    ) throws {
        let ctx = try checkContext()

        let xShift = renderOptions.xShift
        let yShift = renderOptions.yShift * Double(direction)

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
            fy + cp0y * Double(direction),
            lx - cpSpacing + cp1x,
            ly + cp1y * Double(direction),
            lx,
            ly
        )
        ctx.bezierCurveTo(
            lx - cpSpacing + cp1x,
            ly + (cp1y + thickness) * Double(direction),
            fx + cpSpacing + cp0x,
            fy + (cp0y + thickness) * Double(direction),
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

        let firstNote = from
        let lastNote = to

        var firstX: Double = 0
        var lastX: Double = 0
        var firstY: Double = 0
        var lastY: Double = 0
        var stemDirection: Int = 0

        // Determine Y metric based on position
        let useTopYForStart = renderOptions.position == .nearTop
        let useTopYForEnd = renderOptions.positionEnd == .nearTop

        if let firstNote {
            firstX = firstNote.getTieRightX()
            stemDirection = firstNote.getStemDirection()
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
            stemDirection = lastNote.getStemDirection()
            let extents = lastNote.getStemExtents()
            lastY = useTopYForEnd ? extents.topY : extents.baseY
        } else if let firstNote {
            let stave = firstNote.checkStave()
            lastX = stave.getTieEndX()
            let extents = firstNote.getStemExtents()
            lastY = useTopYForEnd ? extents.topY : extents.baseY
        }

        let dir = stemDirection * (renderOptions.invert ? -1 : 1)

        try renderCurve(
            firstX: firstX,
            firstY: firstY,
            lastX: lastX,
            lastY: lastY,
            direction: dir
        )
    }
}
