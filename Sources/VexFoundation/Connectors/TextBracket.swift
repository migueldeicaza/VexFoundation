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

    override public class var category: String { "TextBracket" }
    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SERIF,
            size: 15,
            weight: VexFontWeight.normal.rawValue,
            style: VexFontStyle.italic.rawValue
        )
    }

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

    private func drawDashedLine(
        context: any RenderContext,
        fromX: Double,
        fromY: Double,
        toX: Double,
        toY: Double,
        dashPattern: [Double]
    ) {
        context.beginPath()

        let dx = toX - fromX
        let dy = toY - fromY
        let angle = atan2(dy, dx)
        var x = fromX
        var y = fromY
        context.moveTo(fromX, fromY)

        var index = 0
        var draw = true
        while !((dx < 0 ? x <= toX : x >= toX) && (dy < 0 ? y <= toY : y >= toY)) {
            let dashLength = dashPattern[index % dashPattern.count]
            index += 1

            let nx = x + cos(angle) * dashLength
            x = dx < 0 ? max(toX, nx) : min(toX, nx)

            let ny = y + sin(angle) * dashLength
            y = dy < 0 ? max(toY, ny) : min(toY, ny)

            if draw {
                context.lineTo(x, y)
            } else {
                context.moveTo(x, y)
            }
            draw.toggle()
        }

        context.closePath()
        context.stroke()
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

        let baseFont = fontInfo
        let smallerSize = VexFont.scaleSize(fontSizeInPoints, 0.714286)
        _ = ctx.setFont(baseFont.family, smallerSize, baseFont.weight, baseFont.style)
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
            drawDashedLine(
                context: ctx,
                fromX: lineStartX,
                fromY: lineY,
                toX: endX,
                toY: lineY,
                dashPattern: bracketRenderOptions.dash
            )

            if bracketRenderOptions.showBracket {
                drawDashedLine(
                    context: ctx,
                    fromX: endX,
                    fromY: lineY + 1 * posValue,
                    toX: endX,
                    toY: lineY + bracketHeight,
                    dashPattern: bracketRenderOptions.dash
                )
            }
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

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TextBracket", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 20))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()

        _ = f.TextBracket(from: notes[0], to: notes[3], text: "8va", superscript: "ma")

        try? f.draw()
    }
    .padding()
}
#endif
