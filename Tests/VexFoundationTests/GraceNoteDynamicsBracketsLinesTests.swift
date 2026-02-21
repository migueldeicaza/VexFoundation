// VexFoundation - Tests for Phase 11: GraceNote, GraceNoteGroup, TextDynamics,
// TextBracket, PedalMarking, StaveLine

import Testing
@testable import VexFoundation

@Suite("GraceNote, Dynamics, Brackets & Lines")
struct GraceNoteDynamicsBracketsLinesTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Helper

    private func makeNote(keys: NonEmptyArray<StaffKeySpec> = NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: NoteDurationSpec = .quarter) -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: keys, duration: duration))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()
        return note
    }

    private func makeFormattedNote(keys: NonEmptyArray<StaffKeySpec> = NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: NoteDurationSpec = .quarter) -> StaveNote {
        let note = makeNote(keys: keys, duration: duration)
        note.preFormat()
        return note
    }

    // MARK: - GraceNote Creation

    @Test func graceNoteCategory() {
        #expect(GraceNote.category == "GraceNote")
    }

    @Test func graceNoteScale() {
        #expect(GraceNote.SCALE == 0.66)
    }

    @Test func graceNoteCreation() {
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        #expect(gn.slash == false)
        #expect(gn.slur == true)
        #expect(gn.tickableWidth == 3)
    }

    @Test func graceNoteStructParsingKeysOrNil() {
        let parsed = GraceNoteStruct(
            parsingKeysOrNil: ["d/5"],
            duration: "16",
            slash: true,
            dots: 1,
            type: "s"
        )
        #expect(parsed != nil)

        if let parsed {
            #expect(parsed.keys.count == 1)
            #expect(parsed.keys[0].rawValue == "d/5")
            #expect(parsed.duration.value == .sixteenth)
            #expect(parsed.slash == true)
            #expect(parsed.dots == 1)
            #expect(parsed.type == .slash)
        }
    }

    @Test func graceNoteWithSlash() {
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth, slash: true))
        #expect(gn.slash == true)
    }

    @Test func graceNoteGetStaveNoteScale() {
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let scale = gn.getStaveNoteScale()
        #expect(abs(scale - 0.66) < 0.01)
    }

    @Test func graceNoteStemExtension() {
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = gn.setStave(stave)
        _ = gn.setStemDirection(Stem.UP)
        // Grace note has a reduced stem extension due to scaling
        let ext = gn.getStemExtension()
        // Should be less than a normal note's stem extension
        #expect(ext < 20)
    }

    @Test func graceNoteLedgerLineOffset() {
        #expect(GraceNote.GRACE_LEDGER_LINE_OFFSET == 2)
        // StaveNote has LEDGER_LINE_OFFSET = 3, grace has 2
    }

    @Test func graceNoteDefaultDuration() {
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4))))
        // Default duration should be "8" (eighth note)
        #expect(gn.getDuration() == "8")
    }

    @Test func graceNoteBeamedSlashBBoxThrowingRequiresBeam() throws {
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        do {
            _ = try gn.calcBeamedNotesSlashBBoxThrowing(
                slashStemOffset: 8,
                slashBeamOffset: 8,
                stemProtrusion: 6,
                beamProtrusion: 5
            )
            #expect(Bool(false))
        } catch {
            #expect(error as? GraceNoteError == .noBeam)
        }
    }

    // MARK: - GraceNoteGroup

    @Test func graceNoteGroupCategory() {
        #expect(GraceNoteGroup.category == "GraceNoteGroup")
    }

    @Test func graceNoteGroupCreation() {
        let gn1 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let gn2 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn1, gn2])
        #expect(group.graceNotes.count == 2)
        #expect(group.position == .left)
    }

    @Test func graceNoteGroupPreFormat() {
        let gn1 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let gn2 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn1, gn2])
        group.preFormat()
        #expect(group.getWidth() > 0)
    }

    @Test func graceNoteGroupBeamNotes() {
        let gn1 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let gn2 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn1, gn2])
        _ = group.beamNotes()
        #expect(group.beams.count == 1)
    }

    @Test func graceNoteGroupSingleNoteNoBeam() {
        let gn1 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn1])
        _ = group.beamNotes()
        // Single note can't be beamed
        #expect(group.beams.isEmpty)
    }

    @Test func graceNoteGroupGetGraceNotes() {
        let gn1 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let gn2 = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn1, gn2])
        #expect(group.getGraceNotes().count == 2)
    }

    @Test func graceNoteGroupFormat() {
        let note = makeNote()
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn])
        _ = group.setNote(note)
        _ = group.setIndex(0)

        var state = ModifierContextState()
        let result = GraceNoteGroup.format([group], state: &state)
        #expect(result == true)
        #expect(state.leftShift > 0)
    }

    @Test func graceNoteGroupFormatEmpty() {
        var state = ModifierContextState()
        let result = GraceNoteGroup.format([], state: &state)
        #expect(result == false)
    }

    @Test func graceNoteGroupInModifierContext() {
        let note = makeNote()
        let gn = GraceNote(GraceNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let group = GraceNoteGroup(graceNotes: [gn])
        _ = note.addModifier(group, index: 0)

        let mc = ModifierContext()
        _ = note.addToModifierContext(mc)
        mc.preFormat()

        #expect(mc.formatted == true)
        #expect(!mc.getMembers("GraceNoteGroup").isEmpty)
    }

    // MARK: - TextDynamics

    @Test func textDynamicsCategory() {
        #expect(TextDynamics.category == "TextDynamics")
    }

    @Test func textDynamicsCreation() {
        let dyn = TextDynamics(TextNoteStruct(text: "ppp"))
        #expect(dyn.sequence == "ppp")
    }

    @Test func textDynamicsUppercaseConverted() {
        let dyn = TextDynamics(TextNoteStruct(text: "FF"))
        #expect(dyn.sequence == "ff")
    }

    @Test func textDynamicsGlyphs() {
        // Verify all glyph characters exist
        let chars: [Character] = ["f", "p", "m", "s", "z", "r"]
        for ch in chars {
            #expect(TextDynamics.GLYPHS[ch] != nil, "Glyph for '\(ch)' should exist")
        }
    }

    @Test func textDynamicsGlyphWidths() {
        #expect(TextDynamics.GLYPHS["f"]!.width == 12)
        #expect(TextDynamics.GLYPHS["p"]!.width == 14)
        #expect(TextDynamics.GLYPHS["m"]!.width == 17)
        #expect(TextDynamics.GLYPHS["s"]!.width == 10)
        #expect(TextDynamics.GLYPHS["z"]!.width == 12)
        #expect(TextDynamics.GLYPHS["r"]!.width == 12)
    }

    @Test func textDynamicsSetLine() {
        let dyn = TextDynamics(TextNoteStruct(text: "p"))
        _ = dyn.setLine(3)
        #expect(dyn.getLine() == 3)
    }

    @Test func textDynamicsPreFormat() {
        let dyn = TextDynamics(TextNoteStruct(text: "mf"))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = dyn.setStave(stave)
        dyn.preFormat()
        #expect(dyn.preFormatted == true)
    }

    @Test func textDynamicsValidatingAndFailableConvenience() {
        let valid = try? TextDynamics(validating: TextNoteStruct(text: "rfz"))
        #expect(valid != nil)

        do {
            _ = try TextDynamics(validating: TextNoteStruct(text: "p!"))
            #expect(Bool(false))
        } catch {
            #expect(error as? TextDynamicsError == .invalidDynamicsCharacter("!"))
        }

        #expect(TextDynamics(parsingOrNil: TextNoteStruct(text: "fff")) != nil)
        #expect(TextDynamics(parsingOrNil: TextNoteStruct(text: "f?")) == nil)
    }

    @Test func textDynamicsPreFormatThrowing() throws {
        let dyn = try TextDynamics(validating: TextNoteStruct(text: "sfz"))
        try dyn.preFormatThrowing()
        #expect(dyn.preFormatted == true)
        #expect(dyn.getTickableWidth() > 0)
    }

    // MARK: - TextBracket Position

    @Test func textBracketPositionEnum() {
        #expect(TextBracketPosition.top.rawValue == 1)
        #expect(TextBracketPosition.bottom.rawValue == -1)
    }

    // MARK: - TextBracket

    @Test func textBracketCategory() {
        #expect(TextBracket.category == "TextBracket")
    }

    @Test func textBracketCreation() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let bracket = TextBracket(start: note1, stop: note2, text: "8va", superscript: "a")
        #expect(bracket.text == "8va")
        #expect(bracket.superscriptText == "a")
        #expect(bracket.bracketPosition == .top)
    }

    @Test func textBracketBottom() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let bracket = TextBracket(
            start: note1, stop: note2, text: "8vb", position: .bottom
        )
        #expect(bracket.bracketPosition == .bottom)
    }

    @Test func textBracketSetLine() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let bracket = TextBracket(start: note1, stop: note2)
        _ = bracket.setLine(3)
        #expect(bracket.line == 3)
    }

    @Test func textBracketSetDashed() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let bracket = TextBracket(start: note1, stop: note2)
        _ = bracket.setDashed(false)
        #expect(bracket.bracketRenderOptions.dashed == false)

        _ = bracket.setDashed(true, dash: [3, 3])
        #expect(bracket.bracketRenderOptions.dashed == true)
        #expect(bracket.bracketRenderOptions.dash == [3, 3])
    }

    @Test func textBracketRenderOptionsDefaults() {
        let opts = TextBracketRenderOptions()
        #expect(opts.dashed == true)
        #expect(opts.color == "black")
        #expect(opts.lineWidth == 1)
        #expect(opts.showBracket == true)
        #expect(opts.bracketHeight == 8)
        #expect(opts.underlineSuperscript == true)
    }

    // MARK: - PedalMarking Type

    @Test func pedalMarkingTypeEnum() {
        #expect(PedalMarkingType.text.rawValue == 1)
        #expect(PedalMarkingType.bracket.rawValue == 2)
        #expect(PedalMarkingType.mixed.rawValue == 3)
    }

    // MARK: - PedalMarking

    @Test func pedalMarkingCategory() {
        #expect(PedalMarking.category == "PedalMarking")
    }

    @Test func pedalMarkingCreation() {
        let note1 = makeNote()
        let note2 = makeNote()
        let pedal = PedalMarking(notes: [note1, note2])
        #expect(pedal.notes.count == 2)
        #expect(pedal.pedalType == .text) // default
    }

    @Test func pedalMarkingSetType() {
        let pedal = PedalMarking(notes: [makeNote()])
        _ = pedal.setType(.bracket)
        #expect(pedal.pedalType == .bracket)

        _ = pedal.setType(.mixed)
        #expect(pedal.pedalType == .mixed)
    }

    @Test func pedalMarkingSetCustomText() {
        let pedal = PedalMarking(notes: [makeNote()])
        _ = pedal.setCustomText("Sost. Ped.", release: "tre corda")
        #expect(pedal.customDepressText == "Sost. Ped.")
        #expect(pedal.customReleaseText == "tre corda")
    }

    @Test func pedalMarkingSetLine() {
        let pedal = PedalMarking(notes: [makeNote()])
        _ = pedal.setLine(2)
        #expect(pedal.pedalLine == 2)
    }

    @Test func pedalMarkingCreateSustain() {
        let note1 = makeNote()
        let note2 = makeNote()
        let pedal = PedalMarking.createSustain(notes: [note1, note2])
        #expect(pedal.pedalType == .text)
        #expect(pedal.notes.count == 2)
    }

    @Test func pedalMarkingCreateSostenuto() {
        let note1 = makeNote()
        let note2 = makeNote()
        let pedal = PedalMarking.createSostenuto(notes: [note1, note2])
        #expect(pedal.pedalType == .mixed)
        #expect(pedal.customDepressText == "Sost. Ped.")
    }

    @Test func pedalMarkingCreateUnaCorda() {
        let note1 = makeNote()
        let note2 = makeNote()
        let pedal = PedalMarking.createUnaCorda(notes: [note1, note2])
        #expect(pedal.pedalType == .text)
        #expect(pedal.customDepressText == "una corda")
        #expect(pedal.customReleaseText == "tre corda")
    }

    @Test func pedalMarkingRenderOptionsDefaults() {
        let opts = PedalMarkingRenderOptions()
        #expect(opts.color == "black")
        #expect(opts.bracketHeight == 10)
        #expect(opts.textMarginRight == 6)
        #expect(opts.bracketLineWidth == 1)
    }

    @Test func pedalMarkingGlyphs() {
        #expect(PedalMarking.GLYPHS["pedal_depress"] == "keyboardPedalPed")
        #expect(PedalMarking.GLYPHS["pedal_release"] == "keyboardPedalUp")
    }

    // MARK: - StaveLine Notes

    @Test func staveLineNotesCreation() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let notes = StaveLineNotes(firstNote: note1, lastNote: note2)
        #expect(notes.firstIndices == [0])
        #expect(notes.lastIndices == [0])
    }

    @Test func staveLineNotesCustomIndices() {
        let note1 = makeFormattedNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4), StaffKeySpec(letter: .e, octave: 4)))
        let note2 = makeFormattedNote(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4), StaffKeySpec(letter: .f, octave: 4)))
        let notes = StaveLineNotes(
            firstNote: note1, firstIndices: [0, 1],
            lastNote: note2, lastIndices: [0, 1]
        )
        #expect(notes.firstIndices.count == 2)
        #expect(notes.lastIndices.count == 2)
    }

    // MARK: - StaveLine

    @Test func staveLineCategory() {
        #expect(StaveLine.category == "StaveLine")
    }

    @Test func staveLineCreation() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let line = StaveLine(notes: StaveLineNotes(firstNote: note1, lastNote: note2))
        #expect(line.firstNote === note1)
        #expect(line.lastNote === note2)
        #expect(line.lineText == "")
    }

    @Test func staveLineSetText() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let line = StaveLine(notes: StaveLineNotes(firstNote: note1, lastNote: note2))
        _ = line.setText("gliss.")
        #expect(line.lineText == "gliss.")
    }

    @Test func staveLineSetNotes() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let note3 = makeFormattedNote()
        let line = StaveLine(notes: StaveLineNotes(firstNote: note1, lastNote: note2))
        _ = line.setNotes(StaveLineNotes(firstNote: note3, lastNote: note2))
        #expect(line.firstNote === note3)
    }

    @Test func staveLineValidatingAndThrowingSetNotes() throws {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        do {
            _ = try StaveLine(validating: StaveLineNotes(
                firstNote: note1,
                firstIndices: [0, 1],
                lastNote: note2,
                lastIndices: [0]
            ))
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveLineError == .mismatchedIndices(firstCount: 2, lastCount: 1))
        }

        let line = StaveLine(notes: StaveLineNotes(firstNote: note1, lastNote: note2))
        do {
            _ = try line.setNotesThrowing(StaveLineNotes(
                firstNote: note1,
                firstIndices: [0, 1],
                lastNote: note2,
                lastIndices: [0]
            ))
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveLineError == .mismatchedIndices(firstCount: 2, lastCount: 1))
        }
    }

    @Test func staveLineRenderOptionsDefaults() {
        let opts = StaveLineRenderOptions()
        #expect(opts.paddingLeft == 4)
        #expect(opts.paddingRight == 3)
        #expect(opts.lineWidth == 1)
        #expect(opts.roundedEnd == true)
        #expect(opts.drawStartArrow == false)
        #expect(opts.drawEndArrow == false)
        #expect(opts.arrowheadLength == 10)
        #expect(opts.textPositionVertical == .top)
        #expect(opts.textJustification == .center)
    }

    @Test func staveLineTextVerticalPositionEnum() {
        #expect(StaveLineTextVerticalPosition.top.rawValue == 1)
        #expect(StaveLineTextVerticalPosition.bottom.rawValue == 2)
    }

    @Test func staveLineArrowOptions() {
        let note1 = makeFormattedNote()
        let note2 = makeFormattedNote()
        let line = StaveLine(notes: StaveLineNotes(firstNote: note1, lastNote: note2))
        line.lineRenderOptions.drawStartArrow = true
        line.lineRenderOptions.drawEndArrow = true
        #expect(line.lineRenderOptions.drawStartArrow == true)
        #expect(line.lineRenderOptions.drawEndArrow == true)
    }

    // MARK: - Modifier.alignSubNotesWithNote

    @Test func modifierAlignSubNotesSetup() {
        // Verify the method exists and can be called
        let modifier = Modifier()
        #expect(modifier.getSpacingFromNextModifier() == 0)
    }
}
