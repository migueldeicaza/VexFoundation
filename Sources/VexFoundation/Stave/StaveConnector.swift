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
            // Render brace using bezier curves
            let topX = x - 2
            let midY = topY + height / 2
            ctx.beginPath()
            ctx.moveTo(topX, topY)
            ctx.bezierCurveTo(
                topX - 8, topY,
                topX - 8, midY,
                topX - 5, midY
            )
            ctx.bezierCurveTo(
                topX - 8, midY,
                topX - 8, bottomY,
                topX, bottomY
            )
            ctx.stroke()
            ctx.closePath()

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
