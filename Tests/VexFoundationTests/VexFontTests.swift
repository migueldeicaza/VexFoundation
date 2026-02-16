import Testing
@testable import VexFoundation

@Suite("VexFont")
struct VexFontTests {

    @Test func sizeConversion() {
        // 10pt in pixels = 10 * 4/3 ≈ 13.333
        let px = VexFont.convertSizeToPixelValue(10.0)
        #expect(abs(px - 13.333) < 0.01)

        let px2 = VexFont.convertSizeToPixelValue("12pt")
        #expect(abs(px2 - 16.0) < 0.01)

        let px3 = VexFont.convertSizeToPixelValue("16px")
        #expect(px3 == 16.0)
    }

    @Test func pointConversion() {
        let pt = VexFont.convertSizeToPointValue(12.0)
        #expect(pt == 12.0)

        let pt2 = VexFont.convertSizeToPointValue("16px")
        #expect(pt2 == 12.0) // 16px / (4/3) = 12pt
    }

    @Test func cssString() {
        let info = FontInfo(family: "Arial", size: "10pt", weight: "bold", style: "italic")
        let css = VexFont.toCSSString(info)
        #expect(css == "italic bold 10pt Arial")
    }

    @Test func cssStringDefaults() {
        let info = FontInfo()
        let css = VexFont.toCSSString(info)
        #expect(css.contains("pt"))
        #expect(css.contains("Arial"))
    }

    @Test func isBold() {
        #expect(VexFont.isBold("bold") == true)
        #expect(VexFont.isBold("normal") == false)
        #expect(VexFont.isBold("700") == true)
        #expect(VexFont.isBold("400") == false)
        #expect(VexFont.isBold(nil) == false)
    }

    @Test func isItalic() {
        #expect(VexFont.isItalic("italic") == true)
        #expect(VexFont.isItalic("normal") == false)
        #expect(VexFont.isItalic(nil) == false)
    }

    @Test func scaleSize() {
        #expect(VexFont.scaleSize("10pt", 2.0) == "20.0pt")
        #expect(VexFont.scaleSize(10.0, 2.0) == 20.0)
    }
}
