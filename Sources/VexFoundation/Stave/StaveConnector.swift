// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Connector Type

public enum ConnectorType: Int {
    case singleRight = 0
    case singleLeft = 1
    case double = 2
    case brace = 3
    case bracket = 4
    case boldDoubleLeft = 5
    case boldDoubleRight = 6
    case thinDouble = 7
    case none = 8
}

// MARK: - StaveConnector

/// Connects two staves with brackets, braces, or lines.
public final class StaveConnector: VexElement {

    override public class var category: String { "StaveConnector" }
    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SERIF,
            size: 16,
            weight: VexFontWeight.normal.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    public let topStave: Stave
    public let bottomStave: Stave
    public var connectorType: ConnectorType = .double
    public var connectorWidth: Double = 3
    public var thickness: Double = Tables.STAVE_LINE_THICKNESS
    public var connectorXShift: Double = 0
    public var texts: [(content: String, shiftX: Double, shiftY: Double)] = []

    // MARK: - Init

    public init(topStave: Stave, bottomStave: Stave) {
        self.topStave = topStave
        self.bottomStave = bottomStave
        super.init()
    }

    // MARK: - Setters

    @discardableResult
    public func setType(_ type: ConnectorType) -> Self {
        connectorType = type
        return self
    }

    public func getType() -> ConnectorType { connectorType }

    @discardableResult
    public func setText(_ text: String, shiftX: Double = 0, shiftY: Double = 0) -> Self {
        texts.append((content: text, shiftX: shiftX, shiftY: shiftY))
        return self
    }

    @discardableResult
    public func setXShift(_ shift: Double) -> Self {
        connectorXShift = shift
        return self
    }

    public func getXShift() -> Double { connectorXShift }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        var topY = topStave.getYForLine(0)
        var botY = bottomStave.getYForLine(Double(bottomStave.getNumLines() - 1)) + thickness
        var width = connectorWidth
        var topX = topStave.getX()

        let isRightSided = connectorType == .singleRight
            || connectorType == .boldDoubleRight
            || connectorType == .thinDouble
        if isRightSided {
            topX = topStave.getX() + topStave.getWidth()
        }

        var attachmentHeight = botY - topY

        switch connectorType {
        case .singleRight, .singleLeft:
            width = 1

        case .double:
            topX -= connectorWidth + 2
            topY -= thickness
            attachmentHeight += 0.5

        case .brace:
            width = 12
            let x1 = topStave.getX() - 2 + connectorXShift
            let y1 = topY
            let x3 = x1
            let y3 = botY
            let x2 = x1 - width
            let y2 = y1 + attachmentHeight / 2
            let cpx1 = x2 - 0.9 * width
            let cpy1 = y1 + 0.2 * attachmentHeight
            let cpx2 = x1 + 1.1 * width
            let cpy2 = y2 - 0.135 * attachmentHeight
            let cpx3 = cpx2
            let cpy3 = y2 + 0.135 * attachmentHeight
            let cpx4 = cpx1
            let cpy4 = y3 - 0.2 * attachmentHeight
            let cpx5 = x2 - width
            let cpy5 = cpy4
            let cpx6 = x1 + 0.4 * width
            let cpy6 = y2 + 0.135 * attachmentHeight
            let cpx7 = cpx6
            let cpy7 = y2 - 0.135 * attachmentHeight
            let cpx8 = cpx5
            let cpy8 = cpy1

            ctx.beginPath()
            ctx.moveTo(x1, y1)
            ctx.bezierCurveTo(cpx1, cpy1, cpx2, cpy2, x2, y2)
            ctx.bezierCurveTo(cpx3, cpy3, cpx4, cpy4, x3, y3)
            ctx.bezierCurveTo(cpx5, cpy5, cpx6, cpy6, x2, y2)
            ctx.bezierCurveTo(cpx7, cpy7, cpx8, cpy8, x1, y1)
            ctx.fill()
            ctx.stroke()

        case .bracket:
            topY -= 6
            botY += 6
            attachmentHeight = botY - topY
            Glyph.renderGlyph(ctx: ctx, xPos: topX - 5, yPos: topY, point: 40, code: "bracketTop")
            Glyph.renderGlyph(ctx: ctx, xPos: topX - 5, yPos: botY, point: 40, code: "bracketBottom")
            topX -= connectorWidth + 2

        case .boldDoubleLeft:
            drawBoldDoubleLine(ctx: ctx, type: connectorType, topX: topX + connectorXShift, topY: topY, botY: botY - thickness)

        case .boldDoubleRight:
            drawBoldDoubleLine(ctx: ctx, type: connectorType, topX: topX, topY: topY, botY: botY - thickness)

        case .thinDouble:
            width = 1
            attachmentHeight -= thickness

        case .none:
            break
        }

        if connectorType != .brace
            && connectorType != .boldDoubleLeft
            && connectorType != .boldDoubleRight
            && connectorType != .none {
            ctx.fillRect(topX, topY, width, attachmentHeight)
        }

        if connectorType == .thinDouble {
            ctx.fillRect(topX - 3, topY, width, attachmentHeight)
        }

        ctx.save()
        _ = ctx.setLineWidth(2)
        _ = ctx.setFont(getFont())
        for text in texts {
            let textWidth = ctx.measureText(text.content).width
            let x = topStave.getX() - textWidth - 24 + text.shiftX
            let y = (topStave.getYForLine(0) + bottomStave.getBottomLineY()) / 2 + text.shiftY
            _ = ctx.fillText(text.content, x, y + 4)
        }
        ctx.restore()
    }

    private func drawBoldDoubleLine(
        ctx: RenderContext,
        type: ConnectorType,
        topX: Double,
        topY: Double,
        botY: Double
    ) {
        guard type == .boldDoubleLeft || type == .boldDoubleRight else { return }

        var xShift = 3.0
        var variableWidth = 3.5
        let thickLineOffset = 2.0

        if type == .boldDoubleRight {
            xShift = -5
            variableWidth = 3
        }

        ctx.fillRect(topX + xShift, topY, 1, botY - topY)
        ctx.fillRect(topX - thickLineOffset, topY, variableWidth, botY - topY)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveConnector", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 300, height: 250) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let top = f.Stave(x: 40, y: 20, width: 240)
        _ = top.addClef(.treble)
        let bottom = f.Stave(x: 40, y: 120, width: 240)
        _ = bottom.addClef(.bass)

        _ = f.StaveConnector(topStave: top, bottomStave: bottom, type: .brace)
        _ = f.StaveConnector(topStave: top, bottomStave: bottom, type: .singleLeft)

        try? f.draw()
    }
    .padding()
}
#endif
