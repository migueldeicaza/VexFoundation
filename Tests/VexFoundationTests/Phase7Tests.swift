// VexFoundation - Tests for Phase 7: Accidental, Beam, Articulation

import Testing
@testable import VexFoundation

@Suite("Accidental, Beam & Articulation")
struct Phase7Tests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Accidental Creation

    @Test func accidentalCreation() {
        let acc = Accidental("#")
        #expect(acc.type == "#")
        #expect(acc.getPosition() == .left)
        #expect(acc.getWidth() > 0)
    }

    @Test func accidentalFlat() {
        let acc = Accidental("b")
        #expect(acc.type == "b")
        #expect(acc.accidentalData.code == "accidentalFlat")
    }

    @Test func accidentalNatural() {
        let acc = Accidental("n")
        #expect(acc.type == "n")
        #expect(acc.accidentalData.code == "accidentalNatural")
    }

    @Test func accidentalDoubleSharp() {
        let acc = Accidental("##")
        #expect(acc.type == "##")
        #expect(acc.accidentalData.code == "accidentalDoubleSharp")
    }

    @Test func accidentalDoubleFlat() {
        let acc = Accidental("bb")
        #expect(acc.type == "bb")
        #expect(acc.accidentalData.code == "accidentalDoubleFlat")
    }

    @Test func accidentalCautionary() {
        let acc = Accidental("#")
        _ = acc.setAsCautionary()
        #expect(acc.cautionary == true)
        // Cautionary accidentals are wider (include parens)
        let normalAcc = Accidental("#")
        #expect(acc.getWidth() > normalAcc.getWidth())
    }

    @Test func accidentalWidths() {
        let sharp = Accidental("#")
        let flat = Accidental("b")
        let natural = Accidental("n")
        // All should have positive width
        #expect(sharp.getWidth() > 0)
        #expect(flat.getWidth() > 0)
        #expect(natural.getWidth() > 0)
    }

    // MARK: - Accidental Format

    @Test func accidentalFormat() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c#/4"], duration: .quarter))
        _ = note.setStave(stave)

        let acc = Accidental("#")
        _ = note.addModifier(acc, index: 0)

        var state = ModifierContextState()
        Accidental.format([acc], state: &state)
        #expect(state.leftShift > 0)
    }

    @Test func accidentalFormatMultiple() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c#/4", "e/4", "g#/4"], duration: .quarter))
        _ = note.setStave(stave)

        let acc1 = Accidental("#")
        let acc2 = Accidental("#")
        _ = note.addModifier(acc1, index: 0)
        _ = note.addModifier(acc2, index: 2)

        var state = ModifierContextState()
        Accidental.format([acc1, acc2], state: &state)
        // With multiple accidentals, left shift should be larger
        #expect(state.leftShift > 0)
    }

    @Test func accidentalCollisionDetection() {
        // Lines 2 apart → clearance=3, required=3 → abs(3) < 3 is false → no collision
        let line1 = AccidentalLineMetrics(line: 5, flatLine: false, dblSharpLine: false, numAcc: 1, width: 10)
        let line2 = AccidentalLineMetrics(line: 2, flatLine: false, dblSharpLine: false, numAcc: 1, width: 10)
        #expect(Accidental.checkCollision(line1, line2) == false)

        // Lines 2.5 apart → clearance=2.5, required=3 → abs(2.5) < 3 → collision!
        let lineA = AccidentalLineMetrics(line: 5, flatLine: false, dblSharpLine: false, numAcc: 1, width: 10)
        let lineB = AccidentalLineMetrics(line: 2.5, flatLine: false, dblSharpLine: false, numAcc: 1, width: 10)
        #expect(Accidental.checkCollision(lineA, lineB) == true)

        // Lines 4 apart — no collision
        let line3 = AccidentalLineMetrics(line: 5, flatLine: false, dblSharpLine: false, numAcc: 1, width: 10)
        let line4 = AccidentalLineMetrics(line: 1, flatLine: false, dblSharpLine: false, numAcc: 1, width: 10)
        #expect(Accidental.checkCollision(line3, line4) == false)

        // Flat lines need 2.5 clearance — clearance=2.5, required=2.5 → no collision
        let flatLine1 = AccidentalLineMetrics(line: 5, flatLine: true, dblSharpLine: false, numAcc: 1, width: 10)
        let flatLine2 = AccidentalLineMetrics(line: 2.5, flatLine: true, dblSharpLine: false, numAcc: 1, width: 10)
        #expect(Accidental.checkCollision(flatLine1, flatLine2) == false)
    }

    // MARK: - Accidental with ModifierContext

    @Test func accidentalInModifierContext() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c#/4"], duration: .quarter))
        _ = note.setStave(stave)
        let acc = Accidental("#")
        _ = note.addModifier(acc, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(note)
        _ = mc.addMember(acc)
        mc.preFormat()

        // ModifierContext should have accounted for accidental width
        #expect(mc.getWidth() > 0)
    }

    // MARK: - Accidental Columns Table

    @Test func accidentalColumnsTableData() {
        #expect(Tables.accidentalColumnsTable[1] != nil)
        #expect(Tables.accidentalColumnsTable[3]?["a"] == [1, 3, 2])
        #expect(Tables.accidentalColumnsTable[4]?["spaced_out_tetrachord"] == [1, 2, 1, 2])
        #expect(Tables.accidentalColumnsTable[6]?["very_spaced_out_hexachord"] == [1, 2, 1, 2, 1, 2])
    }

    // MARK: - Beam Creation

    @Test func beamCreation() {
        let note1 = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth))
        let beam = Beam([note1, note2])
        #expect(beam.getNotes().count == 2)
        #expect(beam.getBeamCount() == 1) // 8th notes = 1 beam
        #expect(note1.hasBeam())
        #expect(note2.hasBeam())
    }

    @Test func beamSixteenthNotes() {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: .sixteenth)),
        ]
        let beam = Beam(notes)
        #expect(beam.getBeamCount() == 2) // 16th notes = 2 beams
    }

    @Test func beamStemDirection() {
        let note1 = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth))
        _ = note1.setStemDirection(Stem.UP)
        _ = note2.setStemDirection(Stem.UP)
        let beam = Beam([note1, note2])
        #expect(beam.getStemDirection() == Stem.UP)
    }

    @Test func beamAutoStem() {
        // Notes above middle line → stems down
        let note1 = StaveNote(StaveNoteStruct(keys: ["a/5"], duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: ["b/5"], duration: .eighth))
        _ = Beam([note1, note2], autoStem: true)
        #expect(note1.getStemDirection() == Stem.DOWN)
    }

    @Test func beamBreakSecondary() {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: .sixteenth)),
        ]
        let beam = Beam(notes)
        _ = beam.breakSecondaryAt([2])
        // Should still work without crashing
        #expect(beam.getBeamCount() == 2)
    }

    @Test func beamRenderOptions() {
        let note1 = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth))
        let beam = Beam([note1, note2])
        #expect(beam.renderOptions.beamWidth == 5)
        #expect(beam.renderOptions.slopeIterations == 20)
        #expect(beam.renderOptions.partialBeamLength == 10)
    }

    // MARK: - Beam Default Groups

    @Test func beamDefaultGroups() {
        let groups44 = Beam.getDefaultBeamGroups(.meter(4, 4))
        #expect(groups44.count == 1)
        #expect(groups44[0] == Fraction(1, 4))

        // 6/8 is not in the defaults table, falls through to heuristic:
        // beatTotal=6, 6%3==0 → triple meter → 3/8
        let groups68 = Beam.getDefaultBeamGroups(.meter(6, 8))
        #expect(groups68.count == 1)
        #expect(groups68[0] == Fraction(3, 8))

        let groups38 = Beam.getDefaultBeamGroups(.meter(3, 8))
        #expect(groups38.count == 1)
        #expect(groups38[0] == Fraction(3, 8))
    }

    @Test func beamDefaultGroupsUnknownTime() {
        // 7/8 → triple meter (7 % 3 != 0), beatValue > 4, so 2/8
        let groups78 = Beam.getDefaultBeamGroups(.meter(7, 8))
        #expect(groups78.count == 1)
        #expect(groups78[0] == Fraction(2, 8))

        // 9/8 → triple meter (9 % 3 == 0), so 3/8
        let groups98 = Beam.getDefaultBeamGroups(.meter(9, 8))
        #expect(groups98.count == 1)
        #expect(groups98[0] == Fraction(3, 8))
    }

    // MARK: - Beam Generate

    @Test func beamGenerateBasic() {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: .eighth)),
        ]
        let beams = Beam.generateBeams(notes)
        // Default group is 2/8, so 4 eighth notes → 2 beams
        #expect(beams.count == 2)
    }

    @Test func beamGenerateQuarterGroups() {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: .eighth)),
        ]
        let beams = Beam.generateBeams(notes, config: BeamConfig(groups: [Fraction(1, 4)]))
        // 1/4 grouping → each pair of 8ths beamed → 2 beams
        #expect(beams.count == 2)
    }

    @Test func beamGenerateWithStemDirection() {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth)),
        ]
        let beams = Beam.generateBeams(notes, config: BeamConfig(stemDirection: Stem.DOWN))
        #expect(beams.count == 1)
        #expect(notes[0].getStemDirection() == Stem.DOWN)
    }

    // MARK: - Beam Slope Calculation

    @Test func beamSlopeCalculation() {
        let stave = Stave(x: 10, y: 40, width: 400)
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .eighth)),
        ]
        for note in notes {
            _ = (note as! StaveNote).setStave(stave)
        }
        Formatter.SimpleFormat(notes.map { $0 as! StaveNote })
        let beam = Beam(notes)
        beam.postFormat()
        // Slope should be within render options range
        #expect(beam.slope >= beam.renderOptions.minSlope)
        #expect(beam.slope <= beam.renderOptions.maxSlope)
    }

    @Test func beamFlatSlope() {
        let stave = Stave(x: 10, y: 40, width: 400)
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .eighth)),
        ]
        for note in notes {
            _ = (note as! StaveNote).setStave(stave)
        }
        Formatter.SimpleFormat(notes.map { $0 as! StaveNote })
        let beam = Beam(notes)
        beam.renderOptions.flatBeams = true
        beam.postFormat()
        #expect(beam.slope == 0)
    }

    // MARK: - Articulation Creation

    @Test func articulationCreation() {
        let artic = Articulation("a.")
        #expect(artic.type == "a.")
        #expect(artic.getPosition() == .above)
        #expect(artic.getWidth() > 0)
    }

    @Test func articulationTypes() {
        let staccato = Articulation("a.")
        #expect(staccato.articulationData.betweenLines == true)

        let accent = Articulation("a>")
        #expect(accent.articulationData.betweenLines == true)

        let marcato = Articulation("a^")
        #expect(marcato.articulationData.betweenLines == false)

        let fermata = Articulation("a@")
        #expect(fermata.articulationData.betweenLines == false)
    }

    @Test func articulationBetweenLines() {
        let artic = Articulation("a.")
        #expect(artic.articulationData.betweenLines == true)
        _ = artic.setBetweenLines(false)
        #expect(artic.articulationData.betweenLines == false)
    }

    @Test func articulationPositionAboveBelow() {
        let above = Articulation("a>")
        #expect(above.getPosition() == .above)

        let below = Articulation("a>")
        _ = below.setPosition(.below)
        #expect(below.getPosition() == .below)
    }

    @Test func articulationDirectGlyphCode() {
        // Use a direct glyph code instead of a table type
        let artic = Articulation("fermataAbove")
        #expect(artic.type == "fermataAbove")
        #expect(artic.getPosition() == .above)
    }

    // MARK: - Articulation Format

    @Test func articulationFormat() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .quarter))
        _ = note.setStave(stave)

        let artic = Articulation("a.")
        _ = note.addModifier(artic, index: 0)

        var state = ModifierContextState()
        Articulation.format([artic], state: &state)
        #expect(state.topTextLine > 0)
    }

    @Test func articulationFormatBelow() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .quarter))
        _ = note.setStave(stave)

        let artic = Articulation("a.")
        _ = artic.setPosition(.below)
        _ = note.addModifier(artic, index: 0)

        var state = ModifierContextState()
        Articulation.format([artic], state: &state)
        #expect(state.textLine > 0)
    }

    @Test func articulationFormatMultiple() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .quarter))
        _ = note.setStave(stave)

        let staccato = Articulation("a.")
        let accent = Articulation("a>")
        _ = note.addModifier(staccato, index: 0)
        _ = note.addModifier(accent, index: 0)

        var state = ModifierContextState()
        Articulation.format([staccato, accent], state: &state)
        // Two articulations stacked above
        #expect(state.topTextLine > 0)
    }

    // MARK: - Articulation in ModifierContext

    @Test func articulationInModifierContext() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .quarter))
        _ = note.setStave(stave)
        let artic = Articulation("a.")
        _ = note.addModifier(artic, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(note)
        _ = mc.addMember(artic)
        mc.preFormat()

        #expect(mc.formatted)
    }

    // MARK: - Tables Articulation Data

    @Test func articulationTableLookup() {
        let staccato = Tables.articulationCode("a.")
        #expect(staccato != nil)
        #expect(staccato?.code == "augmentationDot")
        #expect(staccato?.betweenLines == true)

        let accent = Tables.articulationCode("a>")
        #expect(accent != nil)
        #expect(accent?.aboveCode == "articAccentAbove")
        #expect(accent?.belowCode == "articAccentBelow")

        let fermata = Tables.articulationCode("a@")
        #expect(fermata != nil)
        #expect(fermata?.aboveCode == "fermataAbove")
        #expect(fermata?.belowCode == "fermataBelow")
    }

    // MARK: - Combined: Note with Accidentals and Articulations

    @Test func noteWithAccidentalAndArticulation() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c#/4"], duration: .quarter))
        _ = note.setStave(stave)

        let acc = Accidental("#")
        let artic = Articulation("a.")
        _ = note.addModifier(acc, index: 0)
        _ = note.addModifier(artic, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(note)
        _ = mc.addMember(acc)
        _ = mc.addMember(artic)
        mc.preFormat()

        // Should format both modifiers without error
        #expect(mc.formatted)
        #expect(mc.getWidth() > 0)
    }

    // MARK: - Beam with Formatter

    @Test func beamWithSimpleFormat() {
        let notes: [StaveNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: .eighth)),
        ]
        Formatter.SimpleFormat(notes)
        let beams = Beam.generateBeams(notes)
        #expect(beams.count == 2)

        // All notes should have beams
        for note in notes {
            #expect(note.hasBeam())
        }
    }

    @Test func beamPartialDirection() {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: .eighth)),
        ]
        let beam = Beam(notes)
        _ = beam.setPartialBeamSideAt(0, side: .right)
        _ = beam.unsetPartialBeamSideAt(0)
        // Should not crash
        #expect(beam.getNotes().count == 2)
    }
}
