// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - StaveLine Notes

public struct StaveLineNotes {
    public var firstNote: StaveNote
    public var firstIndices: [Int]
    public var lastNote: StaveNote
    public var lastIndices: [Int]

    public init(
        firstNote: StaveNote,
        firstIndices: [Int] = [0],
        lastNote: StaveNote,
        lastIndices: [Int] = [0]
    ) {
        self.firstNote = firstNote
        self.firstIndices = firstIndices
        self.lastNote = lastNote
        self.lastIndices = lastIndices
    }
}

// MARK: - StaveLine Text Position

public enum StaveLineTextVerticalPosition: Int {
    case top = 1
    case bottom = 2
}

// MARK: - StaveLine Render Options

public struct StaveLineRenderOptions {
    public var paddingLeft: Double = 4
    public var paddingRight: Double = 3
    public var lineWidth: Double = 1
    public var lineDash: [Double]?
    public var roundedEnd: Bool = true
    public var color: String?
    public var drawStartArrow: Bool = false
    public var drawEndArrow: Bool = false
    public var arrowheadLength: Double = 10
    public var arrowheadAngle: Double = Double.pi / 8
    public var textPositionVertical: StaveLineTextVerticalPosition = .top
    public var textJustification: TextJustification = .center

    public init() {}
}

// MARK: - StaveLine

/// Draws lines connecting two notes (glissando, pedagogical diagrams, etc.).
public final class StaveLine: VexElement {

    override public class var category: String { "StaveLine" }

    // MARK: - Properties

    public var firstNote: StaveNote
    public var firstIndices: [Int]
    public var lastNote: StaveNote
    public var lastIndices: [Int]
    public var lineText: String = ""
    public var lineRenderOptions = StaveLineRenderOptions()

    // MARK: - Init

    public init(notes: StaveLineNotes) {
        guard notes.firstIndices.count == notes.lastIndices.count else {
            fatalError("[VexError] BadArguments: Connected notes must have same number of indices.")
        }
        self.firstNote = notes.firstNote
        self.firstIndices = notes.firstIndices
        self.lastNote = notes.lastNote
        self.lastIndices = notes.lastIndices
        super.init()
    }

    // MARK: - Setters

    @discardableResult
    public func setText(_ text: String) -> Self {
        lineText = text
        return self
    }

    @discardableResult
    public func setNotes(_ notes: StaveLineNotes) -> Self {
        guard notes.firstIndices.count == notes.lastIndices.count else {
            fatalError("[VexError] BadArguments: Connected notes must have same number of indices.")
        }
        firstNote = notes.firstNote
        firstIndices = notes.firstIndices
        lastNote = notes.lastNote
        lastIndices = notes.lastIndices
        return self
    }

    // MARK: - Line Style

    private func applyLineStyle() throws {
        let ctx = try checkContext()

        if let lineDash = lineRenderOptions.lineDash {
            _ = ctx.setLineDash(lineDash)
        }

        _ = ctx.setLineWidth(lineRenderOptions.lineWidth)

        if lineRenderOptions.roundedEnd {
            _ = ctx.setLineCap(.round)
        } else {
            _ = ctx.setLineCap(.square)
        }
    }

    private func applyFontStyle() throws {
        let ctx = try checkContext()
        ctx.setFont(getFont())

        if let color = lineRenderOptions.color {
            _ = ctx.setStrokeStyle(color)
            _ = ctx.setFillStyle(color)
        }
    }

    // MARK: - Arrow Drawing

    private func drawArrowHead(
        ctx: any RenderContext,
        x0: Double, y0: Double,
        x1: Double, y1: Double,
        x2: Double, y2: Double
    ) {
        ctx.beginPath()
        ctx.moveTo(x0, y0)
        ctx.lineTo(x1, y1)
        ctx.lineTo(x2, y2)
        ctx.lineTo(x0, y0)
        ctx.closePath()
        ctx.fill()
    }

    private func drawArrowLine(
        ctx: any RenderContext,
        pt1: (x: Double, y: Double),
        pt2: (x: Double, y: Double)
    ) {
        let opts = lineRenderOptions
        let bothArrows = opts.drawStartArrow && opts.drawEndArrow

        let x1 = pt1.x, y1 = pt1.y
        let x2 = pt2.x, y2 = pt2.y

        let distance = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
        let ratio = (distance - opts.arrowheadLength / 3) / distance

        let endX: Double, endY: Double, startX: Double, startY: Double

        if opts.drawEndArrow || bothArrows {
            endX = (x1 + (x2 - x1) * ratio).rounded()
            endY = (y1 + (y2 - y1) * ratio).rounded()
        } else {
            endX = x2
            endY = y2
        }

        if opts.drawStartArrow || bothArrows {
            startX = x1 + (x2 - x1) * (1 - ratio)
            startY = y1 + (y2 - y1) * (1 - ratio)
        } else {
            startX = x1
            startY = y1
        }

        if let color = opts.color {
            _ = ctx.setStrokeStyle(color)
            _ = ctx.setFillStyle(color)
        }

        // Draw shaft
        ctx.beginPath()
        ctx.moveTo(startX, startY)
        ctx.lineTo(endX, endY)
        ctx.stroke()
        ctx.closePath()

        // Calculate arrow head geometry
        let lineAngle = atan2(y2 - y1, x2 - x1)
        let h = abs(opts.arrowheadLength / cos(opts.arrowheadAngle))

        if opts.drawEndArrow || bothArrows {
            let angle1 = lineAngle + Double.pi + opts.arrowheadAngle
            let topX = x2 + cos(angle1) * h
            let topY = y2 + sin(angle1) * h

            let angle2 = lineAngle + Double.pi - opts.arrowheadAngle
            let bottomX = x2 + cos(angle2) * h
            let bottomY = y2 + sin(angle2) * h

            drawArrowHead(ctx: ctx, x0: topX, y0: topY, x1: x2, y1: y2, x2: bottomX, y2: bottomY)
        }

        if opts.drawStartArrow || bothArrows {
            let angle1 = lineAngle + opts.arrowheadAngle
            let topX = x1 + cos(angle1) * h
            let topY = y1 + sin(angle1) * h

            let angle2 = lineAngle - opts.arrowheadAngle
            let bottomX = x1 + cos(angle2) * h
            let bottomY = y1 + sin(angle2) * h

            drawArrowHead(ctx: ctx, x0: topX, y0: topY, x1: x1, y1: y1, x2: bottomX, y2: bottomY)
        }
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let opts = lineRenderOptions

        ctx.save()
        try applyLineStyle()

        var startPosition: (x: Double, y: Double) = (0, 0)
        var endPosition: (x: Double, y: Double) = (0, 0)

        for i in 0..<firstIndices.count {
            let firstIndex = firstIndices[i]
            let lastIndex = lastIndices[i]

            startPosition = firstNote.getModifierStartXY(position: .right, index: firstIndex)
            endPosition = lastNote.getModifierStartXY(position: .left, index: lastIndex)
            let upwardsSlope = startPosition.y > endPosition.y

            // Adjust x for modifiers
            let firstMetrics = firstNote.getMetrics()
            let lastMetrics = lastNote.getMetrics()
            startPosition.x += firstMetrics.modRightPx + opts.paddingLeft
            endPosition.x -= lastMetrics.modLeftPx + opts.paddingRight

            // Adjust for displacements
            let noteheadWidth = firstNote.getGlyphWidth()
            let firstKeyProps = firstNote.getKeyProps()
            if firstIndex < firstKeyProps.count && firstKeyProps[firstIndex].displaced
                && firstNote.getStemDirection() == Stem.UP {
                startPosition.x += noteheadWidth + opts.paddingLeft
            }

            let lastKeyProps = lastNote.getKeyProps()
            if lastIndex < lastKeyProps.count && lastKeyProps[lastIndex].displaced
                && lastNote.getStemDirection() == Stem.DOWN {
                endPosition.x -= noteheadWidth + opts.paddingRight
            }

            // Adjust y positions
            startPosition.y += upwardsSlope ? -3 : 1
            endPosition.y += upwardsSlope ? 2 : 0

            drawArrowLine(ctx: ctx, pt1: startPosition, pt2: endPosition)
        }

        ctx.restore()

        // Draw text
        let textWidth = ctx.measureText(lineText).width
        var x: Double = 0

        switch opts.textJustification {
        case .left:
            x = startPosition.x
        case .center:
            let deltaX = endPosition.x - startPosition.x
            let centerX = deltaX / 2 + startPosition.x
            x = centerX - textWidth / 2
        case .right:
            x = endPosition.x - textWidth
        }

        var y: Double = 0
        switch opts.textPositionVertical {
        case .top:
            y = firstNote.checkStave().getYForTopText()
        case .bottom:
            y = firstNote.checkStave().getYForBottomText(Tables.TEXT_HEIGHT_OFFSET_HACK)
        }

        ctx.save()
        try applyFontStyle()
        _ = ctx.fillText(lineText, x, y)
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveLine", traits: .sizeThatFitsLayout) {
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
        )).addClef("treble")

        system.format()

        _ = f.StaveLine(notes: StaveLineNotes(
            firstNote: notes[0] as! StaveNote,
            firstIndices: [0],
            lastNote: notes[3] as! StaveNote,
            lastIndices: [0]
        ))

        try? f.draw()
    }
    .padding()
}
#endif
