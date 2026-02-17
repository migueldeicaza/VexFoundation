import Testing
@testable import VexFoundation

@Suite("Glyph System")
struct GlyphTests {

    init() {
        // Load fonts before each suite
        FontLoader.loadDefaultFonts()
    }

    @Test func fontLoading() {
        // Verify Bravura loaded
        let bravura = VexFont.load(name: "Bravura")
        #expect(bravura.data != nil)
        #expect(bravura.metrics != nil)

        let glyphs = try! bravura.getGlyphs()
        #expect(glyphs.count > 100, "Bravura should have many glyphs, got \(glyphs.count)")

        // Verify key glyphs exist
        #expect(glyphs["gClef"] != nil, "Should have treble clef glyph")
        #expect(glyphs["fClef"] != nil, "Should have bass clef glyph")
        #expect(glyphs["noteheadBlack"] != nil, "Should have black notehead glyph")
    }

    @Test func outlineParsing() {
        // Simple outline: "m 0 0 l 100 200"
        let outline = GlyphOutline.parse("m 0 0 l 100 200")
        // Should be: [MOVE(0), 0, 0, LINE(1), 100, 200]
        #expect(outline.count == 6)
        #expect(outline[0] == 0) // MOVE
        #expect(outline[1] == 0) // x
        #expect(outline[2] == 0) // y
        #expect(outline[3] == 1) // LINE
        #expect(outline[4] == 100) // x
        #expect(outline[5] == 200) // y
    }

    @Test func outlineParsingComplex() {
        // Quadratic and bezier
        let outline = GlyphOutline.parse("m 10 20 q 30 40 50 60 b 70 80 90 100 110 120")
        // MOVE: 3 values, QUADRATIC: 5 values, BEZIER: 7 values = 15
        #expect(outline.count == 15)
        #expect(outline[0] == 0) // MOVE
        #expect(outline[3] == 2) // QUADRATIC
        #expect(outline[8] == 3) // BEZIER
    }

    @Test func glyphMetricsLoading() {
        let metrics = Glyph.loadMetrics(
            fontStack: Glyph.MUSIC_FONT_STACK,
            code: "noteheadBlack",
            category: nil
        )
        #expect(metrics.outline.count > 0, "Notehead should have outline data")
        #expect(metrics.width > 0, "Notehead should have positive width")
        #expect(metrics.ha > 0, "Notehead should have positive advance")
    }

    @Test func glyphBoundingBox() {
        let metrics = Glyph.loadMetrics(
            fontStack: Glyph.MUSIC_FONT_STACK,
            code: "gClef",
            category: nil
        )
        let bbox = Glyph.getOutlineBoundingBox(
            outline: metrics.outline,
            scale: 1.0,
            xPos: 0,
            yPos: 0
        )
        #expect(bbox.w > 0, "Treble clef bbox should have width")
        #expect(bbox.h > 0, "Treble clef bbox should have height")
    }

    @Test func glyphWidth() {
        let width = Glyph.getWidth(code: "noteheadBlack", point: Tables.NOTATION_FONT_SCALE)
        #expect(width > 0, "Notehead width should be positive, got \(width)")
    }

    @Test func glyphInstance() {
        let glyph = Glyph(code: "noteheadBlack", point: Tables.NOTATION_FONT_SCALE)
        #expect(glyph.code == "noteheadBlack")
        #expect(glyph.bbox.w > 0)

        let metrics = glyph.getMetrics()
        #expect(metrics.width > 0)
    }

    @Test func boundingBoxComputation() {
        var comp = BoundingBoxComputation()
        comp.addPoint(10, 20)
        comp.addPoint(50, 80)
        #expect(comp.getX1() == 10)
        #expect(comp.getY1() == 20)
        #expect(comp.width() == 40)
        #expect(comp.height() == 60)
    }

    @Test func durationToTicks() {
        #expect(Tables.durationToTicks("4") == 4096)
        #expect(Tables.durationToTicks("8") == 2048)
        #expect(Tables.durationToTicks("q") == 4096)
        #expect(Tables.durationToTicks("w") == 16384)
        #expect(Tables.durationToTicks("1") == 16384)
    }
}
