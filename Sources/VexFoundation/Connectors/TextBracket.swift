// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Cyril Silverman
//
// Port of `src/textbracket.ts` (VexFlow 5.4.0).
//
// This file implements `TextBrackets` which extend between two notes.
// The octave transposition markings (8va, 8vb, 15va, 15vb) can be created
// using this class.

import Foundation

// MARK: - TextBracket Position

public enum TextBracketPosition: Int, Sendable {
    case top = 1
    case bottom = -1
}

// MARK: - TextBracket Render Options

public struct TextBracketRenderOptions {
    public var dashed: Bool = true
    public var dash: [Double] = [5]
    /// Explicit color. `nil` (the 5.1.0 default) inherits the score and element styles.
    public var color: String?
    public var lineWidth: Double = 1
    public var showBracket: Bool = true
    public var bracketHeight: Double = 8
    /// In the BOTTOM position, the bracket line can extend under the superscript.
    public var underlineSuperscript: Bool = true

    public init(
        dashed: Bool = true,
        dash: [Double] = [5],
        color: String? = nil,
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

    public static let positionString: [String: TextBracketPosition] = [
        "top": .top,
        "bottom": .bottom,
    ]

    // MARK: - Properties

    public var renderOptions = TextBracketRenderOptions()

    public let textElement: VexElement
    public let superscriptElement: VexElement

    public var line: Double = 1

    public let position: TextBracketPosition
    public let start: Note
    public let stop: Note

    @available(*, deprecated, renamed: "position")
    public var bracketPosition: TextBracketPosition { position }

    @available(*, deprecated, renamed: "renderOptions")
    public var bracketRenderOptions: TextBracketRenderOptions {
        get { renderOptions }
        set { renderOptions = newValue }
    }

    /// The superscript text.
    public var superscriptText: String { superscriptElement.getText() }

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
        self.textElement = VexElement(category: "TextBracket")
        self.superscriptElement = VexElement(category: "TextBracket")
        self.position = position
        super.init()

        textElement.setText(text)
        superscriptElement.setText(superscript)
        let smallerFontSize = VexFont.scaleSize(fontInfo.size, 0.714286)
        superscriptElement.setFontSize(smallerFontSize)

        line = 1
        renderOptions = TextBracketRenderOptions()
    }

    /// Create a text bracket with a position string (`"top"` or `"bottom"`).
    /// An unknown string gives `.top`.
    public convenience init(
        start: Note,
        stop: Note,
        text: String = "",
        superscript: String = "",
        positionString: String
    ) {
        self.init(
            start: start,
            stop: stop,
            text: text,
            superscript: superscript,
            position: TextBracket.positionString[positionString] ?? .top
        )
    }

    // MARK: - Style

    /// Apply the text bracket styling to the provided context.
    /// Upstream overrides `Element.applyStyle(ctx)`; 5.1.0 then applies the element style.
    @discardableResult
    override public func applyStyle(
        context ctx: RenderContext? = nil,
        style: ElementStyle? = nil
    ) -> Self {
        textElement.setFont(fontInfo)
        let f = fontInfo
        // To draw the superscript, we scale the font size by 1/1.4.
        let smallerFontSize = VexFont.scaleSize(f.size, 0.714286)
        superscriptElement.setFont(family: f.family, size: smallerFontSize, weight: f.weight, style: f.style)

        guard let ctx = ctx ?? getContext() else { return self }
        let options = renderOptions
        if let color = options.color {
            ctx.setStrokeStyle(color)
            ctx.setFillStyle(color)
        }
        ctx.setLineWidth(options.lineWidth)
        return super.applyStyle(context: ctx)
    }

    // MARK: - Setters

    /// Set whether the bracket line should be `dashed`. You can also
    /// optionally set the `dash` pattern.
    @discardableResult
    public func setDashed(_ dashed: Bool, dash: [Double]? = nil) -> Self {
        renderOptions.dashed = dashed
        if let dash { renderOptions.dash = dash }
        return self
    }

    /// Set the line of the octave bracket.
    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    /// Port of `Renderer.drawDashedLine`.
    static func drawDashedLine(
        _ context: RenderContext,
        _ fromX: Double,
        _ fromY: Double,
        _ toX: Double,
        _ toY: Double,
        _ dashPattern: [Double]
    ) {
        context.beginPath()

        let dx = toX - fromX
        let dy = toY - fromY
        let angle = atan2(dy, dx)
        var x = fromX
        var y = fromY
        context.moveTo(fromX, fromY)
        var idx = 0
        var draw = true
        while !dashPattern.isEmpty && !((dx < 0 ? x <= toX : x >= toX) && (dy < 0 ? y <= toY : y >= toY)) {
            let dashLength = dashPattern[idx % dashPattern.count]
            idx += 1
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

    /// Draw the octave bracket on the rendering context.
    private var layoutBaseline: Double?

    /// Shared baseline for automatic ottava placement. (VexFlow 5.4.0)
    public func setLayoutBaseline(_ y: Double?) {
        layoutBaseline = y
    }

    private struct Geometry {
        var start: (x: Double, y: Double)
        var superX: Double
        var superY: Double
        var startX: Double
        var endX: Double
        var lineY: Double
        var bracketHeight: Double
        var superWidth: Double
    }

    private func geometry() -> Geometry {
        var y: Double
        switch position {
        case .top:
            y = start.checkStave().getYForTopText(line)
        case .bottom:
            y = start.checkStave().getYForBottomText(line + Tables.TEXT_HEIGHT_OFFSET_HACK)
        }

        y = layoutBaseline ?? y
        // Get the preliminary start and stop coordinates for the bracket
        let start = (x: self.start.getAbsoluteX(), y: y)
        let stop = (x: self.stop.getAbsoluteX(), y: y)

        let posValue = Double(position.rawValue)
        let bracketHeight = renderOptions.bracketHeight * posValue

        // Get the width and height for the octave number
        let mainWidth = textElement.getWidth()
        let mainHeight = textElement.getHeight()

        // Calculate the y position for the super script
        let superY = start.y - mainHeight / 2.5

        // Determine width and height of the superscript
        let superWidth = superscriptElement.getWidth()
        let superHeight = superscriptElement.getHeight()

        // Setup initial coordinates for the bracket line
        var startX = start.x
        var lineY = superY
        let endX = stop.x + self.stop.getGlyphWidth()

        // Adjust x and y coordinates based on position
        switch position {
        case .top:
            startX += mainWidth + superWidth + 5
            lineY -= superHeight / 2.7
        case .bottom:
            lineY += superHeight / 2.7
            startX += mainWidth + 2

            if !renderOptions.underlineSuperscript {
                startX += superWidth
            }
        }

        return Geometry(
            start: start, superX: start.x + mainWidth + 1, superY: superY, startX: startX, endX: endX,
            lineY: lineY, bracketHeight: bracketHeight, superWidth: superWidth
        )
    }

    /// Text, superscript, horizontal line and hook share the same placement as drawing. (VexFlow 5.4.0)
    override public func getBoundingBox() -> BoundingBox? {
        let g = geometry()
        let pad = renderOptions.lineWidth / 2
        let height = renderOptions.showBracket ? g.bracketHeight : 0
        return textElement.getTextInk(g.start.x, g.start.y)
            .merged(with: superscriptElement.getTextInk(g.superX, g.superY))
            .merged(with: BoundingBox(
                min(g.startX, g.endX) - pad,
                min(g.lineY, g.lineY + height) - pad,
                abs(g.endX - g.startX) + 2 * pad,
                abs(height) + 2 * pad
            ))
    }

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        let g = geometry()
        let (startX, lineY, bracketHeight, superWidth) = (g.startX, g.lineY, g.bracketHeight, g.superWidth)
        var endX = g.endX
        let posValue = Double(position.rawValue)
        textElement.renderText(ctx, xPos: g.start.x, yPos: g.start.y)
        superscriptElement.renderText(ctx, xPos: g.superX, yPos: g.superY)

        if renderOptions.dashed {
            // VexFlowPatch (gated): prevent bracket from going backwards, also preventing overlap with text
            if !VexRuntime.getCurrentContext().upstreamParityMode {
                if endX < startX + 5 && position == .top {
                    endX = startX + 5
                } else if endX < startX + superWidth && position == .bottom {
                    endX = startX + superWidth
                }
            }

            // Main line
            Self.drawDashedLine(ctx, startX, lineY, endX, lineY, renderOptions.dash)
            // Ending Bracket
            if renderOptions.showBracket {
                Self.drawDashedLine(
                    ctx,
                    endX,
                    lineY + 1 * posValue,
                    endX,
                    lineY + bracketHeight,
                    renderOptions.dash
                )
            }
        } else {
            ctx.beginPath()
            ctx.moveTo(startX, lineY)
            // Main line
            ctx.lineTo(endX, lineY)
            if renderOptions.showBracket {
                // Ending bracket
                ctx.lineTo(endX, lineY + bracketHeight)
            }
            ctx.stroke()
            ctx.closePath()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TextBracket", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()

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
