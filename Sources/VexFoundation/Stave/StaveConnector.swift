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

        let topY = topStave.getYForLine(0)
        let bottomY = bottomStave.getYForLine(Double(bottomStave.getNumLines() - 1))
            + thickness
        let height = bottomY - topY

        let isRightSide = connectorType == .singleRight
            || connectorType == .boldDoubleRight
        let topX = topStave.getX() + (isRightSide ? topStave.getWidth() : 0)
        let x = topX + connectorXShift

        switch connectorType {
        case .singleRight, .singleLeft:
            ctx.fillRect(x, topY, 1, height)

        case .double:
            ctx.fillRect(x - 1, topY, 1, height)
            ctx.fillRect(x + 2, topY, 1, height)

        case .brace:
            let width = 12.0
            let x1 = topStave.getX() - 2 + connectorXShift
            let y1 = topY
            let x3 = x1
            let y3 = bottomY
            let x2 = x1 - width
            let y2 = y1 + height / 2
            let cpx1 = x2 - 0.9 * width
            let cpy1 = y1 + 0.2 * height
            let cpx2 = x1 + 1.1 * width
            let cpy2 = y2 - 0.135 * height
            let cpx3 = cpx2
            let cpy3 = y2 + 0.135 * height
            let cpx4 = cpx1
            let cpy4 = y3 - 0.2 * height
            let cpx5 = x2 - width
            let cpy5 = cpy4
            let cpx6 = x1 + 0.4 * width
            let cpy6 = y2 + 0.135 * height
            let cpx7 = cpx6
            let cpy7 = y2 - 0.135 * height
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
            // Render bracket with top and bottom hooks
            let bracketTopY = topY - 1
            let bracketBottomY = bottomY + 1
            ctx.fillRect(x - 2, bracketTopY, 3, bracketBottomY - bracketTopY)

            // Top hook
            ctx.fillRect(x - 2, bracketTopY, 10, 3)
            // Bottom hook
            ctx.fillRect(x - 2, bracketBottomY - 3, 10, 3)

        case .boldDoubleLeft, .boldDoubleRight:
            ctx.fillRect(x, topY, 3, height)
            ctx.fillRect(x + 5, topY, 1, height)

        case .thinDouble:
            ctx.fillRect(x, topY, 1, height)
            ctx.fillRect(x + 3, topY, 1, height)

        case .none:
            break
        }

        // Draw text labels
        for text in texts {
            let centerX = (topStave.getX() + topStave.getWidth() / 2
                + bottomStave.getX() + bottomStave.getWidth() / 2) / 2
            let centerY = topY + height / 2

            ctx.save()
            ctx.setFont(getFont())
            let measured = ctx.measureText(text.content)
            ctx.fillText(
                text.content,
                centerX - measured.width / 2 + text.shiftX,
                centerY + text.shiftY
            )
            ctx.restore()
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
