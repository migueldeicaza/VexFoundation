// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Text justification for StaveText.
public enum StaveTextJustification: Int {
    case left = 1
    case center = 2
    case right = 3
}

/// Renders text above, below, left, or right of a stave.
public final class StaveText: StaveModifier {

    override public class var category: String { "StaveText" }

    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SERIF,
            size: 16,
            weight: VexFontWeight.normal.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    public var text: String
    public var textShiftX: Double
    public var textShiftY: Double
    public var justification: StaveTextJustification

    // MARK: - Init

    public init(text: String, position: StaveModifierPosition,
                shiftX: Double = 0, shiftY: Double = 0,
                justification: StaveTextJustification = .center) {
        self.text = text
        self.textShiftX = shiftX
        self.textShiftY = shiftY
        self.justification = justification
        super.init()
        self.modifierWidth = 16
        self.position = position
        resetFont()
    }

    @discardableResult
    public func setStaveText(_ text: String) -> Self {
        self.text = text
        return self
    }

    @discardableResult
    public func setShiftX(_ x: Double) -> Self {
        textShiftX = x
        return self
    }

    @discardableResult
    public func setShiftY(_ y: Double) -> Self {
        textShiftY = y
        return self
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        ctx.save()
        ctx.setLineWidth(2)
        ctx.setFont(fontInfo)

        let textWidth = ctx.measureText(text).width
        var x: Double
        var y: Double

        switch position {
        case .left:
            x = stave.getX() - textWidth - 24 + textShiftX
            y = (stave.getYForLine(0) + stave.getBottomLineY()) / 2 + textShiftY
        case .right:
            x = stave.getX() + stave.getWidth() + 24 + textShiftX
            y = (stave.getYForLine(0) + stave.getBottomLineY()) / 2 + textShiftY
        case .above:
            x = stave.getX() + textShiftX
            if justification == .center { x += stave.getWidth() / 2 - textWidth / 2 }
            else if justification == .right { x += stave.getWidth() - textWidth }
            y = stave.getYForTopText(2) + textShiftY
        case .below:
            x = stave.getX() + textShiftX
            if justification == .center { x += stave.getWidth() / 2 - textWidth / 2 }
            else if justification == .right { x += stave.getWidth() - textWidth }
            y = stave.getYForBottomText(2) + textShiftY
        default:
            x = stave.getX() + textShiftX
            y = stave.getYForTopText(2) + textShiftY
        }

        ctx.fillText(text, x, y + 4)
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveText", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s = f.Stave(x: 10, y: 30, width: 490)
        _ = s.addClef("treble")
        _ = s.addModifier(StaveText(text: "Allegro", position: .above))

        try? f.draw()
    }
    .padding()
}
#endif
