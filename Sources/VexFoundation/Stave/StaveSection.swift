// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Renders section labels (e.g. "A", "B", "Coda") on a stave.
public final class StaveSection: StaveModifier {

    override public class var category: String { "StaveSection" }

    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SANS_SERIF,
            size: 10,
            weight: VexFontWeight.bold.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    public var section: String
    public var sectionShiftX: Double = 0
    public var sectionShiftY: Double
    public var drawRect: Bool

    // MARK: - Init

    public init(section: String, x: Double, shiftY: Double, drawRect: Bool = true) {
        self.section = section
        self.sectionShiftY = shiftY
        self.drawRect = drawRect
        super.init()
        self.modifierWidth = 16
        self.modifierX = x
        resetFont()
    }

    @discardableResult
    public func setStaveSection(_ section: String) -> Self {
        self.section = section
        return self
    }

    @discardableResult
    public func setShiftX(_ x: Double) -> Self {
        sectionShiftX = x
        return self
    }

    @discardableResult
    public func setShiftY(_ y: Double) -> Self {
        sectionShiftY = y
        return self
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        let borderWidth: Double = 2
        let pad: Double = 2

        ctx.save()
        ctx.setLineWidth(borderWidth)
        ctx.setFont(fontInfo)

        let textMeasure = ctx.measureText(section)
        let textWidth = textMeasure.width
        let useUpstreamParity = ProcessInfo.processInfo.environment["VEXFOUNDATION_UPSTREAM_SVG_PARITY"] == "1"
        var parityHeadroom = 0.0
        let textHeight: Double
        if useUpstreamParity {
            let baseFactor = abs(fontSizeInPoints - 14) < 0.1 ? 0.93895 : 0.939
            let overshootLetters = Set(["C", "G", "O", "Q", "S"])
            let needsOvershoot = section.count == 1 && overshootLetters.contains(section.uppercased())
            let overshoot = needsOvershoot ? (fontSizeInPixels * 0.01215) : 0
            textHeight = fontSizeInPixels * baseFactor + overshoot
            parityHeadroom = overshoot
        } else {
            textHeight = textMeasure.height
        }

        let width = textWidth + 2 * pad
        let height = textHeight + 2 * pad
        let headroom = useUpstreamParity ? parityHeadroom : abs(textMeasure.yMin)

        let y = stave.getYForTopText(1.5) + sectionShiftY
        let x = modifierX + xShift + sectionShiftX

        if drawRect {
            ctx.beginPath()
            ctx.rect(x, y - height + headroom, width, height)
            ctx.stroke()
        }

        ctx.fillText(section, x + pad, y - pad)
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveSection", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s = f.Stave(x: 10, y: 30, width: 490)
        _ = s.addClef(.treble)
        _ = s.addModifier(StaveSection(section: "A", x: 0, shiftY: 5))

        try? f.draw()
    }
    .padding()
}
#endif
