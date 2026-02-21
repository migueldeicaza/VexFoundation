// VexFoundation - Tests for Phase 7: Accidental, Beam, Articulation

import Testing
@testable import VexFoundation

@Suite("Accidental, Beam & Articulation")
struct AccidentalBeamArticulationTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeNote(
        _ letter: NoteLetter,
        octave: Int = 4,
        duration: NoteDurationSpec = .sixteenth,
        type: NoteType = .note
    ) -> StaveNote {
        StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: letter, octave: octave)),
            duration: duration,
            type: type
        ))
    }

    // MARK: - Accidental Creation

    @Test func accidentalCreation() throws {
        let acc = Accidental(.sharp)
        #expect(acc.type == "#")
        #expect(acc.getPosition() == .left)
        #expect(acc.getWidth() > 0)
    }

    @Test func accidentalStringParsingThrowing() throws {
        let acc = try Accidental(parsing: " # ")
        #expect(acc.accidentalType == .sharp)
    }

    @Test func accidentalStringParsingOrNil() throws {
        let acc = Accidental(parsingOrNil: "invalid")
        #expect(acc == nil)
    }

    @Test func accidentalFlat() throws {
        let acc = Accidental(.flat)
        #expect(acc.type == "b")
        #expect(acc.accidentalData.code == "accidentalFlat")
    }

    @Test func accidentalNatural() throws {
        let acc = Accidental(.natural)
        #expect(acc.type == "n")
        #expect(acc.accidentalData.code == "accidentalNatural")
    }

    @Test func accidentalDoubleSharp() throws {
        let acc = Accidental(.doubleSharp)
        #expect(acc.type == "##")
        #expect(acc.accidentalData.code == "accidentalDoubleSharp")
    }

    @Test func accidentalDoubleFlat() throws {
        let acc = Accidental(.doubleFlat)
        #expect(acc.type == "bb")
        #expect(acc.accidentalData.code == "accidentalDoubleFlat")
    }

    @Test func accidentalCautionary() throws {
        let acc = Accidental(.sharp)
        _ = acc.setAsCautionary()
        #expect(acc.cautionary == true)
        // Cautionary accidentals are wider (include parens)
        let normalAcc = Accidental(.sharp)
        #expect(acc.getWidth() > normalAcc.getWidth())
    }

    @Test func accidentalWidths() throws {
        let sharp = Accidental(.sharp)
        let flat = Accidental(.flat)
        let natural = Accidental(.natural)
        // All should have positive width
        #expect(sharp.getWidth() > 0)
        #expect(flat.getWidth() > 0)
        #expect(natural.getWidth() > 0)
    }

    // MARK: - Accidental Format

    @Test func accidentalFormat() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, accidental: .sharp, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)

        let acc = Accidental(.sharp)
        _ = note.addModifier(acc, index: 0)

        var state = ModifierContextState()
        Accidental.format([acc], state: &state)
        #expect(state.leftShift > 0)
    }

    @Test func accidentalFormatMultiple() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, accidental: .sharp, octave: 4), StaffKeySpec(letter: .e, octave: 4), StaffKeySpec(letter: .g, accidental: .sharp, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)

        let acc1 = Accidental(.sharp)
        let acc2 = Accidental(.sharp)
        _ = note.addModifier(acc1, index: 0)
        _ = note.addModifier(acc2, index: 2)

        var state = ModifierContextState()
        Accidental.format([acc1, acc2], state: &state)
        // With multiple accidentals, left shift should be larger
        #expect(state.leftShift > 0)
    }

    @Test func accidentalCollisionDetection() throws {
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

    @Test func accidentalInModifierContext() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, accidental: .sharp, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)
        let acc = Accidental(.sharp)
        _ = note.addModifier(acc, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(note)
        _ = mc.addMember(acc)
        mc.preFormat()

        // ModifierContext should have accounted for accidental width
        #expect(mc.getWidth() > 0)
    }

    // MARK: - Accidental Columns Table

    @Test func accidentalColumnsTableData() throws {
        #expect(Tables.accidentalColumnsTable[1] != nil)
        #expect(Tables.accidentalColumnsTable[3]?["a"] == [1, 3, 2])
        #expect(Tables.accidentalColumnsTable[4]?["spaced_out_tetrachord"] == [1, 2, 1, 2])
        #expect(Tables.accidentalColumnsTable[6]?["very_spaced_out_hexachord"] == [1, 2, 1, 2, 1, 2])
    }

    // MARK: - Beam Creation

    @Test func beamCreation() throws {
        let note1 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        let beam = try Beam([note1, note2])
        #expect(beam.getNotes().count == 2)
        #expect(beam.getBeamCount() == 1) // 8th notes = 1 beam
        #expect(note1.hasBeam())
        #expect(note2.hasBeam())
    }

    @Test func beamSixteenthNotes() throws {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .f, octave: 4)), duration: .sixteenth)),
        ]
        let beam = try Beam(notes)
        #expect(beam.getBeamCount() == 2) // 16th notes = 2 beams
    }

    @Test func beamStemDirection() throws {
        let note1 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        _ = note1.setStemDirection(Stem.UP)
        _ = note2.setStemDirection(Stem.UP)
        let beam = try Beam([note1, note2])
        #expect(beam.getStemDirection() == Stem.UP)
    }

    @Test func beamAutoStem() throws {
        // Notes above middle line → stems down
        let note1 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .a, octave: 5)), duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .b, octave: 5)), duration: .eighth))
        _ = try Beam([note1, note2], autoStem: true)
        #expect(note1.getStemDirection() == Stem.DOWN)
    }

    @Test func beamBreakSecondary() throws {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .sixteenth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .f, octave: 4)), duration: .sixteenth)),
        ]
        let beam = try Beam(notes)
        _ = beam.breakSecondaryAt([2])
        // Should still work without crashing
        #expect(beam.getBeamCount() == 2)
    }

    @Test func beamRenderOptions() throws {
        let note1 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let note2 = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        let beam = try Beam([note1, note2])
        #expect(beam.renderOptions.beamWidth == 5)
        #expect(beam.renderOptions.slopeIterations == 20)
        #expect(beam.renderOptions.partialBeamLength == 10)
    }

    // MARK: - Beam Default Groups

    @Test func beamDefaultGroups() throws {
        let groups44 = try Beam.getDefaultBeamGroups(.meter(4, 4))
        #expect(groups44.count == 1)
        #expect(groups44[0] == Fraction(1, 4))

        // 6/8 is not in the defaults table, falls through to heuristic:
        // beatTotal=6, 6%3==0 → triple meter → 3/8
        let groups68 = try Beam.getDefaultBeamGroups(.meter(6, 8))
        #expect(groups68.count == 1)
        #expect(groups68[0] == Fraction(3, 8))

        let groups38 = try Beam.getDefaultBeamGroups(.meter(3, 8))
        #expect(groups38.count == 1)
        #expect(groups38[0] == Fraction(3, 8))
    }

    @Test func beamDefaultGroupsUnknownTime() throws {
        // 7/8 → triple meter (7 % 3 != 0), beatValue > 4, so 2/8
        let groups78 = try Beam.getDefaultBeamGroups(.meter(7, 8))
        #expect(groups78.count == 1)
        #expect(groups78[0] == Fraction(2, 8))

        // 9/8 → triple meter (9 % 3 == 0), so 3/8
        let groups98 = try Beam.getDefaultBeamGroups(.meter(9, 8))
        #expect(groups98.count == 1)
        #expect(groups98[0] == Fraction(3, 8))
    }

    // MARK: - Beam Generate

    @Test func beamGenerateBasic() throws {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .f, octave: 4)), duration: .eighth)),
        ]
        let beams = try Beam.generateBeams(notes)
        // Default group is 2/8, so 4 eighth notes → 2 beams
        #expect(beams.count == 2)
    }

    @Test func beamGenerateQuarterGroups() throws {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .f, octave: 4)), duration: .eighth)),
        ]
        let beams = try Beam.generateBeams(notes, config: BeamConfig(groups: [Fraction(1, 4)]))
        // 1/4 grouping → each pair of 8ths beamed → 2 beams
        #expect(beams.count == 2)
    }

    @Test func beamGenerateWithStemDirection() throws {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
        ]
        let beams = try Beam.generateBeams(notes, config: BeamConfig(stemDirection: Stem.DOWN))
        #expect(beams.count == 1)
        #expect(notes[0].getStemDirection() == Stem.DOWN)
    }

    @Test func beamGenerateBeamRestsIncludesInteriorRests() throws {
        func makeSequence() -> ([StemmableNote], StaveNote) {
            let n1 = makeNote(.c)
            let rest = makeNote(.b, type: .rest)
            let n3 = makeNote(.d)
            let n4 = makeNote(.e)
            return ([n1, rest, n3, n4], rest)
        }

        let (notesAcrossRests, interiorRestAcross) = makeSequence()
        let acrossRests = try Beam.generateBeams(
            notesAcrossRests,
            config: BeamConfig(groups: [Fraction(1, 4)], beamRests: true)
        )
        #expect(acrossRests.count == 1)
        #expect(acrossRests[0].getNotes().count == 4)
        #expect(interiorRestAcross.hasBeam())

        let (notesBreakOnRests, interiorRestBreak) = makeSequence()
        let breakOnRests = try Beam.generateBeams(
            notesBreakOnRests,
            config: BeamConfig(groups: [Fraction(1, 4)], beamRests: false)
        )
        #expect(breakOnRests.count == 1)
        #expect(breakOnRests[0].getNotes().count == 2)
        #expect(!interiorRestBreak.hasBeam())
    }

    @Test func beamGenerateMiddleOnlyRestsBreakAtGroupEdges() throws {
        func makeEdgeRestSequence() -> ([StemmableNote], StaveNote, StaveNote) {
            let firstRest = makeNote(.b, type: .rest)
            let n2 = makeNote(.c)
            let n3 = makeNote(.d)
            let lastRest = makeNote(.b, type: .rest)
            return ([firstRest, n2, n3, lastRest], firstRest, lastRest)
        }

        let (middleOnlyNotes, middleOnlyFirstRest, middleOnlyLastRest) = makeEdgeRestSequence()
        let middleOnlyBeams = try Beam.generateBeams(
            middleOnlyNotes,
            config: BeamConfig(groups: [Fraction(1, 4)], beamRests: true, beamMiddleOnly: true)
        )
        #expect(middleOnlyBeams.count == 1)
        #expect(middleOnlyBeams[0].getNotes().count == 2)
        #expect(!middleOnlyFirstRest.hasBeam())
        #expect(!middleOnlyLastRest.hasBeam())

        let (allRestsNotes, allRestsFirstRest, allRestsLastRest) = makeEdgeRestSequence()
        let allRestsBeams = try Beam.generateBeams(
            allRestsNotes,
            config: BeamConfig(groups: [Fraction(1, 4)], beamRests: true, beamMiddleOnly: false)
        )
        #expect(allRestsBeams.count == 1)
        #expect(allRestsBeams[0].getNotes().count == 4)
        #expect(allRestsFirstRest.hasBeam())
        #expect(allRestsLastRest.hasBeam())
    }

    @Test func beamGenerateMaintainStemDirectionsSplitsOnStemChanges() throws {
        func makeStemPattern() -> [StemmableNote] {
            let n1 = makeNote(.c)
            let n2 = makeNote(.c)
            let n3 = makeNote(.c)
            let n4 = makeNote(.c)
            _ = n1.setStemDirection(.up)
            _ = n2.setStemDirection(.down)
            _ = n3.setStemDirection(.down)
            _ = n4.setStemDirection(.up)
            return [n1, n2, n3, n4]
        }

        let maintained = makeStemPattern()
        let maintainedBeams = try Beam.generateBeams(
            maintained,
            config: BeamConfig(groups: [Fraction(1, 4)], maintainStemDirections: true)
        )
        #expect(maintainedBeams.count == 1)
        #expect(maintainedBeams[0].getNotes().count == 2)
        #expect(maintained[0].getStemDirection() == .up)
        #expect(maintained[1].getStemDirection() == .down)
        #expect(maintained[2].getStemDirection() == .down)
        #expect(maintained[3].getStemDirection() == .up)

        let normalized = makeStemPattern()
        let normalizedBeams = try Beam.generateBeams(
            normalized,
            config: BeamConfig(groups: [Fraction(1, 4)], maintainStemDirections: false)
        )
        #expect(normalizedBeams.count == 1)
        #expect(normalizedBeams[0].getNotes().count == 4)
        #expect(Set(normalized.map { $0.getStemDirection() }).count == 1)
    }

    @Test func beamGenerateShowStemletsOnRestWhenBeamingAcrossRests() throws {
        let stave = Stave(x: 10, y: 40, width: 320)
        let n1 = makeNote(.c)
        let rest = makeNote(.b, type: .rest)
        let n3 = makeNote(.d)
        let n4 = makeNote(.e)
        let notes = [n1, rest, n3, n4]
        for note in notes {
            _ = note.setStave(stave)
        }
        Formatter.SimpleFormat(notes)

        let beams = try Beam.generateBeams(
            notes,
            config: BeamConfig(groups: [Fraction(1, 4)], beamRests: true, showStemlets: true)
        )
        #expect(beams.count == 1)
        beams[0].postFormat()

        let stem = rest.getStem()
        #expect(stem != nil)
        #expect(stem?.isStemlet == true)
        #expect(stem?.hide == false)
    }

    @Test func crossStaveStyleBeamKeepsMixedStavesAndStemDirections() throws {
        let topStave = Stave(x: 10, y: 40, width: 320)
        let bottomStave = Stave(x: 10, y: 140, width: 320)

        let n1 = makeNote(.a, octave: 4, duration: .eighth)
        let n2 = makeNote(.g, octave: 4, duration: .eighth)
        let n3 = makeNote(.c, octave: 4, duration: .eighth)
        let n4 = makeNote(.d, octave: 4, duration: .eighth)
        let notes = [n1, n2, n3, n4]

        _ = n1.setStave(topStave)
        _ = n2.setStave(topStave)
        _ = n3.setStave(bottomStave)
        _ = n4.setStave(bottomStave)

        _ = n1.setStemDirection(.down)
        _ = n2.setStemDirection(.down)
        _ = n3.setStemDirection(.up)
        _ = n4.setStemDirection(.up)

        Formatter.SimpleFormat(notes)

        let beam = try Beam(notes)
        beam.postFormat()

        #expect(beam.getNotes().count == 4)
        #expect(beam.getStemDirection() == .down)
        #expect(notes.allSatisfy { $0.hasBeam() })
        #expect(n1.getStemDirection() == .down)
        #expect(n3.getStemDirection() == .up)
        #expect(n1.getYs()[0] != n3.getYs()[0])
    }

    // MARK: - Beam Slope Calculation

    @Test func beamSlopeCalculation() throws {
        let stave = Stave(x: 10, y: 40, width: 400)
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        for note in notes {
            _ = (note as! StaveNote).setStave(stave)
        }
        Formatter.SimpleFormat(notes.map { $0 as! StaveNote })
        let beam = try Beam(notes)
        beam.postFormat()
        // Slope should be within render options range
        #expect(beam.slope >= beam.renderOptions.minSlope)
        #expect(beam.slope <= beam.renderOptions.maxSlope)
    }

    @Test func beamFlatSlope() throws {
        let stave = Stave(x: 10, y: 40, width: 400)
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        for note in notes {
            _ = (note as! StaveNote).setStave(stave)
        }
        Formatter.SimpleFormat(notes.map { $0 as! StaveNote })
        let beam = try Beam(notes)
        beam.renderOptions.flatBeams = true
        beam.postFormat()
        #expect(beam.slope == 0)
    }

    // MARK: - Articulation Creation

    @Test func articulationCreation() throws {
        let artic = Articulation("a.")
        #expect(artic.type == "a.")
        #expect(artic.getPosition() == .above)
        #expect(artic.getWidth() > 0)
    }

    @Test func articulationTypes() throws {
        let staccato = Articulation("a.")
        #expect(staccato.articulationData.betweenLines == true)

        let accent = Articulation("a>")
        #expect(accent.articulationData.betweenLines == true)

        let marcato = Articulation("a^")
        #expect(marcato.articulationData.betweenLines == false)

        let fermata = Articulation("a@")
        #expect(fermata.articulationData.betweenLines == false)
    }

    @Test func articulationBetweenLines() throws {
        let artic = Articulation("a.")
        #expect(artic.articulationData.betweenLines == true)
        _ = artic.setBetweenLines(false)
        #expect(artic.articulationData.betweenLines == false)
    }

    @Test func articulationPositionAboveBelow() throws {
        let above = Articulation("a>")
        #expect(above.getPosition() == .above)

        let below = Articulation("a>")
        _ = below.setPosition(.below)
        #expect(below.getPosition() == .below)
    }

    @Test func articulationDirectGlyphCode() throws {
        // Use a direct glyph code instead of a table type
        let artic = Articulation("fermataAbove")
        #expect(artic.type == "fermataAbove")
        #expect(artic.getPosition() == .above)
    }

    // MARK: - Articulation Format

    @Test func articulationFormat() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)

        let artic = Articulation("a.")
        _ = note.addModifier(artic, index: 0)

        var state = ModifierContextState()
        Articulation.format([artic], state: &state)
        #expect(state.topTextLine > 0)
    }

    @Test func articulationFormatBelow() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)

        let artic = Articulation("a.")
        _ = artic.setPosition(.below)
        _ = note.addModifier(artic, index: 0)

        var state = ModifierContextState()
        Articulation.format([artic], state: &state)
        #expect(state.textLine > 0)
    }

    @Test func articulationFormatMultiple() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
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

    @Test func articulationInModifierContext() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
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

    @Test func articulationTableLookup() throws {
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

    @Test func noteWithAccidentalAndArticulation() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, accidental: .sharp, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)

        let acc = Accidental(.sharp)
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

    @Test func beamWithSimpleFormat() throws {
        let notes: [StaveNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .f, octave: 4)), duration: .eighth)),
        ]
        Formatter.SimpleFormat(notes)
        let beams = try Beam.generateBeams(notes)
        #expect(beams.count == 2)

        // All notes should have beams
        for note in notes {
            #expect(note.hasBeam())
        }
    }

    @Test func beamPartialDirection() throws {
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
        ]
        let beam = try Beam(notes)
        _ = beam.setPartialBeamSideAt(0, side: .right)
        _ = beam.unsetPartialBeamSideAt(0)
        // Should not crash
        #expect(beam.getNotes().count == 2)
    }
}
