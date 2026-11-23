// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/staveconnector.ts` (VexFlow 5.4.0).

import Foundation

// MARK: - Connector Type

/// Connector type. `singleLeft` and `single` are the same value for compatibility
/// with older versions of VexFlow which didn't have right sided stave connectors.
public enum ConnectorType: Int, Sendable {
    case singleRight = 0
    case singleLeft = 1
    case double = 2
    case brace = 3
    case bracket = 4
    case boldDoubleLeft = 5
    case boldDoubleRight = 6
    case thinDouble = 7
    case none = 8

    /// Same as `singleLeft`.
    public static let single: ConnectorType = .singleLeft
}

private func drawBoldDoubleLine(_ ctx: RenderContext, _ type: ConnectorType, _ topX: Double, _ topY: Double,
                                _ botY: Double) throws {
    if type != .boldDoubleLeft && type != .boldDoubleRight {
        throw VexError("InvalidConnector", "A REPEAT_BEGIN or REPEAT_END type must be provided.")
    }

    var xShift: Double = 3
    var variableWidth: Double = 3.5 // Width for avoiding anti-aliasing width issues
    let thickLineOffset: Double = 2 // For aesthetics

    if type == .boldDoubleRight {
        xShift = -5 // Flips the side of the thin line
        variableWidth = 3
    }

    // Thin line
    ctx.fillRect(topX + xShift, topY, 1, botY - topY)
    // Thick line
    ctx.fillRect(topX - thickLineOffset, topY, variableWidth, botY - topY)
}

// MARK: - StaveConnector

/// StaveConnector implements the connector lines between staves of a system.
public final class StaveConnector: VexElement {

    override public class var category: String { "StaveConnector" }

    /// Connector type strings.
    public static let typeString: [String: ConnectorType] = [
        "singleRight": .singleRight,
        "singleLeft": .singleLeft,
        "single": .single,
        "double": .double,
        "brace": .brace,
        "bracket": .bracket,
        "boldDoubleLeft": .boldDoubleLeft,
        "boldDoubleRight": .boldDoubleRight,
        "thinDouble": .thinDouble,
        "none": .none,
    ]

    // MARK: - Properties

    public private(set) var texts: [VexElement] = []
    public private(set) var type: ConnectorType

    public let topStave: Stave
    public let bottomStave: Stave
    public let thickness: Double

    // MARK: - Init

    public init(topStave: Stave, bottomStave: Stave) {
        self.thickness = Tables.STAVE_LINE_THICKNESS
        self.topStave = topStave
        self.bottomStave = bottomStave
        self.type = .double
        super.init(category: nil)

        // 1. Offset Bold Double Left to align with offset Repeat Begin bars
        // 2. Offset BRACE type not to overlap with another StaveConnector
        xShift = 0
        texts = []
    }

    // MARK: - Type

    /// Set type.
    @discardableResult
    public func setType(_ type: ConnectorType) -> Self {
        self.type = type
        return self
    }

    /// Set type from a type string (see `typeString`). Unknown strings are ignored.
    @discardableResult
    public func setType(_ type: String) -> Self {
        if let newType = StaveConnector.typeString[type] {
            self.type = newType
        }
        return self
    }

    /// Get type.
    public func getType() -> ConnectorType { type }

    @available(*, deprecated, message: "Use getType().")
    public var connectorType: ConnectorType {
        get { type }
        set { type = newValue }
    }

    // MARK: - Text

    /// Set optional associated text.
    @discardableResult
    public func setText(_ text: String, shiftX: Double = 0, shiftY: Double = 0) -> Self {
        let textElement = VexElement(category: "StaveConnector.text")
        textElement.setText(text)
        textElement.setXShift(shiftX)
        textElement.setYShift(shiftY)
        texts.append(textElement)
        return self
    }

    /// Upstream `setText(text)` overrides `Element.setText` and adds a text.
    @discardableResult
    override public func setText(_ text: String) -> Self {
        setText(text, shiftX: 0, shiftY: 0)
    }

    // MARK: - Draw

    /// Render connector and associated text.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        var topY = topStave.getYForLine(0)
        var botY = bottomStave.getYForLine(Double(bottomStave.getNumLines() - 1)) + thickness
        var width: Double = 3
        var topX = topStave.getX()

        let isRightSidedConnector = type == .singleRight || type == .boldDoubleRight || type == .thinDouble

        if isRightSidedConnector {
            topX = topStave.getX() + topStave.getWidth()
        }

        var attachmentHeight = botY - topY
        let element = VexElement()
        switch type {
        case .singleLeft:
            width = 1
        case .singleRight:
            width = 1
        case .double:
            topX -= 5
            topY -= thickness
            attachmentHeight += 0.5
        case .brace:
            width = 12
            // May need additional code to draw brace
            let x1 = topStave.getX() - 2 + xShift
            let y1 = topY
            let x3 = x1
            let y3 = botY
            let x2 = x1 - width
            let y2 = y1 + attachmentHeight / 2.0
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
            topX += xShift
            topY -= 6
            botY += 6
            attachmentHeight = botY - topY
            element.setText(Glyphs.bracketTop)
            element.renderText(ctx, xPos: topX - 5, yPos: topY)
            element.setText(Glyphs.bracketBottom)
            element.renderText(ctx, xPos: topX - 5, yPos: botY)
            topX -= 5
        case .boldDoubleLeft:
            try drawBoldDoubleLine(ctx, type, topX + xShift, topY, botY - thickness)
        case .boldDoubleRight:
            try drawBoldDoubleLine(ctx, type, topX, topY, botY - thickness)
        case .thinDouble:
            width = 1
            attachmentHeight -= thickness
        case .none:
            break
        }

        if type != .brace && type != .boldDoubleLeft && type != .boldDoubleRight && type != .none {
            ctx.fillRect(topX, topY, width, attachmentHeight)
        }

        // If the connector is a thin double barline, draw the paralell line
        if type == .thinDouble {
            ctx.fillRect(topX - 3, topY, width, attachmentHeight)
        }

        // Add stave connector text
        for textElement in texts {
            let x = topStave.getX() - textElement.getWidth() - 24
            let y = (topStave.getYForLine(0) + bottomStave.getBottomLineY()) / 2

            textElement.renderText(ctx, xPos: x, yPos: y + 4)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveConnector", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 300, height: 250) { ctx in
        ctx.clear()

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
