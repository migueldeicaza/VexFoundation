// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Cyril Silverman. MIT License.

import Foundation

// MARK: - TextBracket Position

public enum TextBracketPosition: Int {
    case top = 1
    case bottom = -1
}

// MARK: - TextBracket Render Options

public struct TextBracketRenderOptions {
    public var dashed: Bool = true
    public var dash: [Double] = [5]
    public var color: String = "black"
    public var lineWidth: Double = 1
    public var showBracket: Bool = true
    public var bracketHeight: Double = 8
    public var underlineSuperscript: Bool = true

    public init(
        dashed: Bool = true,
        dash: [Double] = [5],
        color: String = "black",
        lineWidth: Double = 1,
        showBracket: Bool = true,
        bracketHeight: Double = 8,
        underlineSuperscript: Bool = true
    ) {
        self.dashed = dashed
        self.dash = dash
        self.color = color
        self.lineWidth = lineWidth
        self.showBracket = showBracket
        self.bracketHeight = bracketHeight
        self.underlineSuperscript = underlineSuperscript
    }
}

// MARK: - TextBracket

/// Renders text brackets spanning between two notes (8va, 8vb, 15ma, etc.).
public final class TextBracket: VexElement {

    override public class var CATEGORY: String { "TextBracket" }

    // MARK: - Properties

    public let start: Note
    public let stop: Note
    public let text: String
    public let superscriptText: String
    public let bracketPosition: TextBracketPosition
    public var line: Double = 1
    public var bracketRenderOptions = TextBracketRenderOptions()

    // MARK: - Init

    public init(
        start: Note,
        stop: Note,
        text: String = "",
        superscript: String = "",
        position: TextBracketPosition = .top
    ) {
        self.start = start
        self.stop = stop
        self.text = text
        self.superscriptText = superscript
        self.bracketPosition = position
        super.init()
    }

    // MARK: - Setters

    @discardableResult
    public func setDashed(_ dashed: Bool, dash: [Double]? = nil) -> Self {
        bracketRenderOptions.dashed = dashed
        if let dash { bracketRenderOptions.dash = dash }
        return self
    }

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let posValue = Double(bracketPosition.rawValue)

        var y: Double
        switch bracketPosition {
        case .top:
            y = start.checkStave().getYForTopText(line)
        case .bottom:
            y = start.checkStave().getYForBottomText(line + Tables.TEXT_HEIGHT_OFFSET_HACK)
        }

        let startX = start.getAbsoluteX()
        let stopX = stop.getAbsoluteX()

        let bracketHeight = bracketRenderOptions.bracketHeight * posValue

        ctx.save()

        // Apply style
        ctx.setFont(getFont())
        _ = ctx.setStrokeStyle(bracketRenderOptions.color)
        _ = ctx.setFillStyle(bracketRenderOptions.color)
        _ = ctx.setLineWidth(bracketRenderOptions.lineWidth)

        // Draw main text
        _ = ctx.fillText(text, startX, y)

        let mainMeasure = ctx.measureText(text)
        let mainWidth = mainMeasure.width
        let mainHeight = mainMeasure.height

        // Superscript position
        let superY = y - mainHeight / 2.5

        // Draw superscript at smaller size
        let smallerSize = 15.0 * 0.714286
        _ = ctx.setFont(nil, smallerSize, nil, "italic")
        _ = ctx.fillText(superscriptText, startX + mainWidth + 1, superY)

        let superMeasure = ctx.measureText(superscriptText)
        let superWidth = superMeasure.width
        let superHeight = superMeasure.height

        // Setup bracket line coordinates
        var lineStartX = startX
        var lineY = superY
        let endX = stopX + stop.getGlyphWidth()

        if bracketPosition == .top {
            lineStartX += mainWidth + superWidth + 5
            lineY -= superHeight / 2.7
        } else {
            lineY += superHeight / 2.7
            lineStartX += mainWidth + 2
            if !bracketRenderOptions.underlineSuperscript {
                lineStartX += superWidth
            }
        }

        if bracketRenderOptions.dashed {
            _ = ctx.setLineDash(bracketRenderOptions.dash)

            // Main line
            ctx.beginPath()
            ctx.moveTo(lineStartX, lineY)
            ctx.lineTo(endX, lineY)
            ctx.stroke()
            ctx.closePath()

            // Ending bracket
            if bracketRenderOptions.showBracket {
                ctx.beginPath()
                ctx.moveTo(endX, lineY + 1 * posValue)
                ctx.lineTo(endX, lineY + bracketHeight)
                ctx.stroke()
                ctx.closePath()
            }

            _ = ctx.setLineDash([])
        } else {
            ctx.beginPath()
            ctx.moveTo(lineStartX, lineY)
            ctx.lineTo(endX, lineY)
            if bracketRenderOptions.showBracket {
                ctx.lineTo(endX, lineY + bracketHeight)
            }
            ctx.stroke()
            ctx.closePath()
        }

        ctx.restore()
    }
}
