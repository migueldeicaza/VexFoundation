// VexFoundation - Tests for Phase 3.2 text formatting replacement contract.

import Testing
@testable import VexFoundation

private final class MockRenderContext: RenderContext {
    var fillStyle: String = "#000"
    var strokeStyle: String = "#000"

    private(set) var currentFont: FontInfo = FontInfo()
    private(set) var measuredTexts: [String] = []

    private var fontStack: [FontInfo] = []

    func clear() {}

    @discardableResult
    func save() -> Self {
        fontStack.append(currentFont)
        return self
    }

    @discardableResult
    func restore() -> Self {
        if let font = fontStack.popLast() {
            currentFont = font
        }
        return self
    }

    @discardableResult func setFillStyle(_ style: String) -> Self { fillStyle = style; return self }
    @discardableResult func setBackgroundFillStyle(_ style: String) -> Self { self }
    @discardableResult func setStrokeStyle(_ style: String) -> Self { strokeStyle = style; return self }
    @discardableResult func setShadowColor(_ color: String) -> Self { self }
    @discardableResult func setShadowBlur(_ blur: Double) -> Self { self }
    @discardableResult func setLineWidth(_ width: Double) -> Self { self }
    @discardableResult func setLineCap(_ capType: VexLineCap) -> Self { self }
    @discardableResult func setLineDash(_ dashPattern: [Double]) -> Self { self }
    @discardableResult func scale(_ x: Double, _ y: Double) -> Self { self }
    @discardableResult func resize(_ width: Double, _ height: Double) -> Self { self }
    @discardableResult func beginPath() -> Self { self }
    @discardableResult func moveTo(_ x: Double, _ y: Double) -> Self { self }
    @discardableResult func lineTo(_ x: Double, _ y: Double) -> Self { self }

    @discardableResult
    func bezierCurveTo(
        _ cp1x: Double,
        _ cp1y: Double,
        _ cp2x: Double,
        _ cp2y: Double,
        _ x: Double,
        _ y: Double
    ) -> Self { self }

    @discardableResult
    func quadraticCurveTo(_ cpx: Double, _ cpy: Double, _ x: Double, _ y: Double) -> Self { self }

    @discardableResult
    func arc(
        _ x: Double,
        _ y: Double,
        _ radius: Double,
        _ startAngle: Double,
        _ endAngle: Double,
        _ counterclockwise: Bool
    ) -> Self { self }

    @discardableResult func closePath() -> Self { self }
    @discardableResult func fill() -> Self { self }
    @discardableResult func stroke() -> Self { self }
    @discardableResult func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }
    @discardableResult func fillRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }
    @discardableResult func clearRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }
    @discardableResult func fillText(_ text: String, _ x: Double, _ y: Double) -> Self { self }

    func measureText(_ text: String) -> TextMeasure {
        measuredTexts.append(text)
        let fontPx = VexFont.convertSizeToPixelValue(currentFont.size)
        return TextMeasure(
            x: 0,
            y: -fontPx * 0.8,
            width: Double(text.count) * fontPx * 0.5,
            height: fontPx
        )
    }

    @discardableResult
    func setFont(_ family: String?, _ size: Double?, _ weight: String?, _ style: String?) -> Self {
        currentFont = VexFont.validate(
            family: family ?? currentFont.family,
            size: size.map { "\($0)pt" } ?? currentFont.size,
            weight: weight ?? currentFont.weight,
            style: style ?? currentFont.style
        )
        return self
    }

    @discardableResult
    func setFont(_ fontInfo: FontInfo) -> Self {
        currentFont = VexFont.validate(fontInfo: fontInfo)
        return self
    }

    func getFont() -> String {
        VexFont.toCSSString(currentFont)
    }

    func openGroup(_ cls: String?, _ id: String?) -> Any? { nil }
    func closeGroup() {}
    func add(_ child: Any) {}
}

@Suite("Text Formatter")
struct TextFormatterParityTests {
    init() {
        FontLoader.loadDefaultFonts()
    }

    @Test func textFormatterFallbackReturnsDeterministicWidthAndExtent() {
        let font = FontInfo(family: "Times New Roman", size: "20pt", weight: "normal", style: "normal")
        let formatter = TextFormatter.create(font: font)

        let widthPx = formatter.getWidthForTextInPx("abcd")
        let widthEm = formatter.getWidthForTextInEm("abcd")
        let extent = formatter.getYForStringInPx("Ab")

        #expect(widthPx > 0)
        #expect(widthEm > 0)
        #expect(widthPx == widthEm * formatter.fontSizeInPixels)
        #expect(extent.height > 0)
        #expect(extent.yMin < 0)
    }

    @Test func textFormatterUsesRenderContextMeasurements() {
        let ctx = MockRenderContext()
        let font = FontInfo(family: "Georgia", size: "10pt", weight: "bold", style: "italic")
        let formatter = TextFormatter.create(font: font, context: ctx)

        let width = formatter.getWidthForTextInPx("test")
        let fontPx = VexFont.convertSizeToPixelValue("10pt")
        let expected = 4.0 * fontPx * 0.5

        #expect(width == expected)
        #expect(ctx.measuredTexts == ["test"])
        #expect(ctx.currentFont.family == VexFont.SANS_SERIF)
        #expect(ctx.currentFont.weight == VexFontWeight.normal.rawValue)
        #expect(ctx.currentFont.style == VexFontStyle.normal.rawValue)
    }

    @Test func annotationFormatUsesTextFormatterMeasurement() {
        let ctx = MockRenderContext()
        let stave = Stave(x: 10, y: 40, width: 320)
        _ = stave.setContext(ctx)

        let note = StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)),
            duration: .quarter
        ))
        _ = note.setStave(stave)

        let annotation = Annotation("WIDE")
        _ = note.addModifier(annotation, index: 0)

        var state = ModifierContextState()
        _ = Annotation.format([annotation], state: &state)

        let expectedWidth = 4.0 * annotation.fontSizeInPixels * 0.5
        #expect(annotation.getWidth() == expectedWidth)
        #expect(state.topTextLine > 0)
    }

    @Test func textNotePreFormatUsesTextFormatterMeasurement() {
        let ctx = MockRenderContext()
        let note = TextNote(TextNoteStruct(
            duration: .quarter,
            text: "abcd"
        ))
        _ = note.setContext(ctx)
        note.preFormat()

        let expected = 4.0 * note.fontSizeInPixels * 0.5
        #expect(note.tickableWidth == expected)
    }
}
