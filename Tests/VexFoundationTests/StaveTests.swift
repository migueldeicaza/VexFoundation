import Testing
@testable import VexFoundation

@Suite("Stave System")
struct StaveTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Tables Data

    @Test func keySignatureLookup() throws {
        // C major: no accidentals
        let cMajor = try Tables.keySignature("C")
        #expect(cMajor.isEmpty)

        // G major: 1 sharp
        let gMajor = try Tables.keySignature("G")
        #expect(gMajor.count == 1)
        #expect(gMajor[0].type == "#")
        #expect(gMajor[0].line == 0)

        // D major: 2 sharps
        let dMajor = try Tables.keySignature("D")
        #expect(dMajor.count == 2)

        // Bb major: 2 flats
        let bbMajor = try Tables.keySignature("Bb")
        #expect(bbMajor.count == 2)
        #expect(bbMajor[0].type == "b")

        // C# major: 7 sharps (max)
        let cSharpMajor = try Tables.keySignature("C#")
        #expect(cSharpMajor.count == 7)

        // Cb major: 7 flats (max)
        let cbMajor = try Tables.keySignature("Cb")
        #expect(cbMajor.count == 7)
    }

    @Test func accidentalCodes() {
        let sharp = Tables.accidentalCode("#")
        #expect(sharp != nil)
        #expect(sharp!.code == "accidentalSharp")

        let flat = Tables.accidentalCode("b")
        #expect(flat != nil)
        #expect(flat!.code == "accidentalFlat")

        let natural = Tables.accidentalCode("n")
        #expect(natural != nil)
        #expect(natural!.code == "accidentalNatural")
    }

    @Test func glyphProps() {
        // Quarter note
        let quarter = Tables.getGlyphProps(duration: "4")
        #expect(quarter != nil)
        #expect(quarter!.stem == true)
        #expect(quarter!.flag == false)
        #expect(quarter!.beamCount == 0)

        // Eighth note
        let eighth = Tables.getGlyphProps(duration: "8")
        #expect(eighth != nil)
        #expect(eighth!.stem == true)
        #expect(eighth!.flag == true)
        #expect(eighth!.beamCount == 1)
        #expect(eighth!.codeFlagUpstem == "flag8thUp")

        // Quarter rest
        let qRest = Tables.getGlyphProps(duration: "4", type: "r")
        #expect(qRest != nil)
        #expect(qRest!.rest == true)
        #expect(qRest!.codeHead == "restQuarter")
    }

    // MARK: - Stave Creation

    @Test func staveCreation() {
        let stave = Stave(x: 10, y: 40, width: 300)
        #expect(stave.getX() == 10)
        #expect(stave.getY() == 40)
        #expect(stave.getWidth() == 300)
        #expect(stave.getNumLines() == 5)
    }

    @Test func staveYPositions() {
        let stave = Stave(x: 0, y: 0, width: 400)
        let lineSpacing = stave.getSpacingBetweenLines()
        #expect(lineSpacing == 10)

        // Lines 0-4 should be evenly spaced
        let y0 = stave.getYForLine(0)
        let y1 = stave.getYForLine(1)
        let y4 = stave.getYForLine(4)
        #expect(y1 - y0 == lineSpacing)
        #expect(y4 - y0 == 4 * lineSpacing)

        // Top/bottom boundary
        let topY = stave.getTopLineTopY()
        let botY = stave.getBottomLineBottomY()
        #expect(topY < y0)
        #expect(botY > y4)
    }

    @Test func staveModifierCount() {
        let stave = Stave(x: 0, y: 0, width: 400)
        // Should start with 2 barlines (begin and end)
        let modifiers = stave.modifiers
        #expect(modifiers.count == 2)
        #expect(modifiers[0] is Barline)
        #expect(modifiers[1] is Barline)
    }

    // MARK: - Barline

    @Test func barlineType() {
        let barline = Barline(.single)
        #expect(barline.getBarlineType() == .single)

        barline.setBarlineType(.double)
        #expect(barline.getBarlineType() == .double)
    }

    @Test func staveBarlineConfig() {
        let stave = Stave(x: 0, y: 0, width: 400)

        stave.setBegBarType(.repeatBegin)
        #expect((stave.modifiers[0] as! Barline).getBarlineType() == .repeatBegin)

        stave.setEndBarType(.end)
        #expect((stave.modifiers[1] as! Barline).getBarlineType() == .end)
    }

    // MARK: - Clef

    @Test func clefTypes() {
        #expect(Clef.types[.treble] != nil)
        #expect(Clef.types[.treble]!.code == "gClef")
        #expect(Clef.types[.bass]!.code == "fClef")
        #expect(Clef.types[.alto]!.code == "cClef")
    }

    @Test func clefAddition() {
        let stave = Stave(x: 0, y: 0, width: 400)
        stave.addClef(.treble)
        #expect(stave.getClef() == .treble)

        let clefs = stave.getModifiers(position: .begin, category: "Clef")
        #expect(clefs.count == 1)
    }

    @Test func clefPoint() {
        let defaultPoint = Clef.getPoint(.default)
        #expect(defaultPoint == Tables.NOTATION_FONT_SCALE)

        let smallPoint = Clef.getPoint(.small)
        #expect(smallPoint < defaultPoint)
    }

    // MARK: - Key Signature

    @Test func keySignatureCreation() {
        let stave = Stave(x: 0, y: 0, width: 400)
        stave.addClef(.treble)
        stave.addKeySignature("D")

        let keySigs = stave.getModifiers(position: .begin, category: "KeySignature")
        #expect(keySigs.count == 1)

        let ks = keySigs[0] as! KeySignature
        #expect(ks.keySpec == "D")
    }

    @Test func keySignatureGlyphs() {
        let stave = Stave(x: 0, y: 0, width: 400)
        stave.addClef(.treble)
        let ks = KeySignature(keySpec: "A")
        ks.setStave(stave)
        ks.format()

        let glyphs = ks.getGlyphs()
        #expect(glyphs.count == 3) // A major has 3 sharps
    }

    @Test func keySignatureCancel() {
        let stave = Stave(x: 0, y: 0, width: 400)
        stave.addClef(.treble)
        let ks = KeySignature(keySpec: "C", cancelKeySpec: "D")
        ks.setStave(stave)
        ks.format()

        // D has 2 sharps, C has none → should produce 2 naturals
        let glyphs = ks.getGlyphs()
        #expect(glyphs.count == 2)
    }

    // MARK: - Time Signature

    @Test func timeSignatureNumeric() {
        let ts = TimeSignature(timeSpec: "4/4")
        #expect(ts.getIsNumeric() == true)
        #expect(ts.getTimeSpec() == "4/4")
    }

    @Test func timeSignatureCommon() {
        let ts = TimeSignature(timeSpec: "C")
        #expect(ts.getIsNumeric() == false)
        #expect(ts.getTimeSpec() == "C")
    }

    @Test func timeSignatureCut() {
        let ts = TimeSignature(timeSpec: "C|")
        #expect(ts.getIsNumeric() == false)
    }

    @Test func timeSignatureAddToStave() {
        let stave = Stave(x: 0, y: 0, width: 400)
        stave.addTimeSignature("3/4")

        let timeSigs = stave.getModifiers(position: .begin, category: "TimeSignature")
        #expect(timeSigs.count == 1)
    }

    // MARK: - Stave Format

    @Test func staveFormat() {
        let stave = Stave(x: 10, y: 40, width: 400)
        stave.addClef(.treble)
        stave.addKeySignature("D")
        stave.addTimeSignature("4/4")

        // Formatting should position modifiers and calculate start_x
        let startX = stave.getNoteStartX()
        let endX = stave.getNoteEndX()

        #expect(startX > stave.getX(), "Notes should start after modifiers")
        #expect(endX > startX, "Note area should have positive width")
        #expect(endX <= stave.getX() + stave.getWidth(), "Notes should end within stave width")
    }

    @Test func staveModifierSorting() {
        let stave = Stave(x: 0, y: 0, width: 400)
        // Add in wrong order
        stave.addTimeSignature("4/4")
        stave.addKeySignature("G")
        stave.addClef(.treble)

        // After format, modifiers should be positioned: Barline < Clef < KeySig < TimeSig
        stave.format()
        let begMods = stave.getModifiers(position: .begin)
        #expect(begMods.count == 4)

        // Verify by position (X coordinate order) rather than array order
        let clef = begMods.first { $0 is Clef }!
        let keySig = begMods.first { $0 is KeySignature }!
        let timeSig = begMods.first { $0 is TimeSignature }!

        #expect(clef.getModifierX() < keySig.getModifierX(), "Clef should be left of key sig")
        #expect(keySig.getModifierX() < timeSig.getModifierX(), "Key sig should be left of time sig")
    }

    // MARK: - Line Configuration

    @Test func staveLineConfig() {
        let stave = Stave(x: 0, y: 0, width: 400)
        let configs = stave.getConfigForLines()
        #expect(configs.count == 5)
        #expect(configs.allSatisfy { $0.visible })

        // Hide middle line
        stave.setConfigForLine(2, config: StaveLineConfig(visible: false))
        #expect(stave.getConfigForLines()[2].visible == false)
    }

    @Test func staveCustomLineCount() {
        let stave = Stave(x: 0, y: 0, width: 400)
        stave.setNumLines(1)
        #expect(stave.getNumLines() == 1)
        #expect(stave.getConfigForLines().count == 1)
    }

    // MARK: - Volta

    @Test func voltaCreation() {
        let volta = Volta(type: .begin, number: "1", x: 0, yShift: 0)
        #expect(volta.voltaType == .begin)
        #expect(volta.number == "1")
    }

    // MARK: - Stave Section

    @Test func sectionCreation() {
        let section = StaveSection(section: "A", x: 0, shiftY: 0)
        #expect(section.section == "A")
    }

    // MARK: - Stave Tempo

    @Test func tempoCreation() {
        let tempo = StaveTempo(
            tempo: StaveTempoOptions(bpm: 120, duration: "4", name: "Allegro"),
            x: 0,
            shiftY: 0
        )
        #expect(tempo.tempo.bpm == 120)
        #expect(tempo.tempo.duration == "4")
        #expect(tempo.tempo.name == "Allegro")
    }

    // MARK: - Full Stave with All Modifiers

    @Test func fullStaveSetup() {
        let stave = Stave(x: 10, y: 40, width: 500)
        stave.addClef(.treble)
        stave.addKeySignature("Eb")
        stave.addTimeSignature("3/4")
        stave.setBegBarType(.single)
        stave.setEndBarType(.double)
        stave.setMeasure(1)

        // Format and verify
        let startX = stave.getNoteStartX()
        #expect(startX > stave.getX())
        #expect(stave.getMeasure() == 1)
        #expect(stave.getClef() == .treble)

        // Check Eb has 3 flats
        let keySigs = stave.getModifiers(position: .begin, category: "KeySignature")
        let ks = keySigs[0] as! KeySignature
        let glyphs = ks.getGlyphs()
        #expect(glyphs.count == 3)
    }

    @Test func multipleStaveAlignment() {
        let stave1 = Stave(x: 10, y: 0, width: 400)
        stave1.addClef(.treble)
        stave1.addKeySignature("D")
        stave1.addTimeSignature("4/4")

        let stave2 = Stave(x: 10, y: 100, width: 400)
        stave2.addClef(.bass)
        stave2.addTimeSignature("4/4")

        Stave.formatBegModifiers([stave1, stave2])

        // After alignment, note start X should be the same
        #expect(stave1.getNoteStartX() == stave2.getNoteStartX())
    }
}
