// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Renders section labels (e.g. "A", "B", "Coda") on a stave.
public final class StaveSection: StaveModifier {

    override public class var CATEGORY: String { "StaveSection" }

    override public class var TEXT_FONT: FontInfo {
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
        let textHeight = textMeasure.height

        let width = textWidth + 2 * pad
        let height = textHeight + 2 * pad
        let headroom = abs(textMeasure.yMin)

        let y = stave.getYForTopText(1.5) + sectionShiftY
        let x = modifierX + sectionShiftX

        if drawRect {
            ctx.beginPath()
            ctx.rect(x, y - height + headroom, width, height)
            ctx.stroke()
        }

        ctx.fillText(section, x + pad, y - pad)
        ctx.restore()
    }
}
