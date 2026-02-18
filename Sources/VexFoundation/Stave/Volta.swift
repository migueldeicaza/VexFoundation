// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Types of volta brackets.
public enum VoltaType: Int {
    case none = 1
    case begin = 2
    case mid = 3
    case end = 4
    case beginEnd = 5
}

/// Renders volta brackets (1st/2nd endings) above a stave.
public final class Volta: StaveModifier {

    override public class var category: String { "Volta" }

    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SANS_SERIF,
            size: 9,
            weight: VexFontWeight.bold.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    public var voltaType: VoltaType
    public var number: String
    public var voltaYShift: Double

    // MARK: - Init

    public init(type: VoltaType, number: String, x: Double, yShift: Double) {
        self.voltaType = type
        self.number = number
        self.voltaYShift = yShift
        super.init()
        self.modifierX = x
        resetFont()
    }

    @discardableResult
    public func setShiftY(_ y: Double) -> Self {
        voltaYShift = y
        return self
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        let topY = stave.getYForTopText(Double(stave.getNumLines())) + voltaYShift
        let vertHeight = 1.5 * stave.getSpacingBetweenLines()
        let width = stave.getWidth() - xShift

        // Vertical lines
        switch voltaType {
        case .begin:
            ctx.fillRect(modifierX + xShift, topY, 1, vertHeight)
        case .end:
            ctx.fillRect(modifierX + xShift + width - 5, topY, 1, vertHeight)
        case .beginEnd:
            ctx.fillRect(modifierX + xShift, topY, 1, vertHeight)
            ctx.fillRect(modifierX + xShift + width - 3, topY, 1, vertHeight)
        default:
            break
        }

        // Number text for BEGIN or BEGIN_END
        if voltaType == .begin || voltaType == .beginEnd {
            ctx.save()
            ctx.setFont(fontInfo)
            ctx.fillText(number, modifierX + xShift + 5, topY + 15)
            ctx.restore()
        }

        // Horizontal line
        ctx.fillRect(modifierX + xShift, topY, width, 1)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Volta", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 30, width: 240)
        _ = s1.addModifier(Volta(type: .begin, number: "1.", x: 0, yShift: -5))

        let s2 = f.Stave(x: 260, y: 30, width: 240)
        _ = s2.addModifier(Volta(type: .beginEnd, number: "2.", x: 0, yShift: -5))

        try? f.draw()
    }
    .padding()
}
#endif
