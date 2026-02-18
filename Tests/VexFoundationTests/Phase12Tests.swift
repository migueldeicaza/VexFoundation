// VexFoundation - Tests for Phase 12: NoteSubGroup, BarNote, Vibrato, VibratoBracket,
// Parenthesis, Crescendo, MultiMeasureRest

import Testing
@testable import VexFoundation

@Suite("NoteSubGroup, BarNote, Vibrato, VibratoBracket, Parenthesis, Crescendo, MultiMeasureRest")
struct Phase12Tests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Helper

    private func makeNote(keys: [String] = ["c/4"], duration: String = "4") -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: keys, duration: duration))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()
        return note
    }

    private func makeStave(x: Double = 10, y: Double = 40, width: Double = 300) -> Stave {
        Stave(x: x, y: y, width: width)
    }

    // ============================================================
    // MARK: - NoteSubGroup Tests
    // ============================================================

    @Test func noteSubGroupCategory() {
        #expect(NoteSubGroup.category == "NoteSubGroup")
    }

    @Test func noteSubGroupCreation() {
        let clefNote = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clefNote])
        #expect(group.subNotes.count == 1)
        #expect(group.position == .left)
    }

    @Test func noteSubGroupMultipleNotes() {
        let clef = ClefNote(type: "bass")
        let clef2 = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clef, clef2])
        #expect(group.subNotes.count == 2)
    }

    @Test func noteSubGroupPreFormat() {
        let clef = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clef])
        group.preFormat()
        #expect(group.getWidth() > 0)
    }

    @Test func noteSubGroupPreFormatIdempotent() {
        let clef = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clef])
        group.preFormat()
        let w1 = group.getWidth()
        group.preFormat()
        let w2 = group.getWidth()
        #expect(w1 == w2)
    }

    @Test func noteSubGroupStaticFormat() {
        let clef = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clef])
        var state = ModifierContextState()
        let result = NoteSubGroup.format([group], state: &state)
        #expect(result == true)
        #expect(state.leftShift > 0)
    }

    @Test func noteSubGroupFormatEmpty() {
        var state = ModifierContextState()
        let result = NoteSubGroup.format([], state: &state)
        #expect(result == false)
    }

    // ============================================================
    // MARK: - BarNote Tests
    // ============================================================

    @Test func barNoteCategory() {
        #expect(BarNote.category == "BarNote")
    }

    @Test func barNoteDefaultCreation() {
        let barNote = BarNote()
        #expect(barNote.getType() == .single)
    }

    @Test func barNoteTypedCreation() {
        let barNote = BarNote(type: .double)
        #expect(barNote.getType() == .double)
    }

    @Test func barNoteSetType() {
        let barNote = BarNote()
        _ = barNote.setType(.end)
        #expect(barNote.getType() == .end)
    }

    @Test func barNoteWidths() {
        let single = BarNote(type: .single)
        let dbl = BarNote(type: .double)
        let end = BarNote(type: .end)
        let none = BarNote(type: .none)
        // PreFormat to allow width access
        single.preFormat()
        dbl.preFormat()
        end.preFormat()
        none.preFormat()
        // Each type should get a specific width
        #expect(single.getTickableWidth() > 0)
        #expect(dbl.getTickableWidth() > single.getTickableWidth())
        #expect(end.getTickableWidth() > dbl.getTickableWidth())
        #expect(none.getTickableWidth() == 0)
    }

    @Test func barNoteIgnoresTicks() {
        let barNote = BarNote()
        #expect(barNote.shouldIgnoreTicks() == true)
    }

    @Test func barNotePreFormat() {
        let barNote = BarNote()
        barNote.preFormat()
        #expect(barNote.preFormatted == true)
    }

    @Test func barNoteAddToModifierContext() {
        let barNote = BarNote()
        let mc = ModifierContext()
        _ = barNote.addToModifierContext(mc)
        // BarNotes don't participate in modifier context
    }

    // ============================================================
    // MARK: - Vibrato Tests
    // ============================================================

    @Test func vibratoCategory() {
        #expect(Vibrato.category == "Vibrato")
    }

    @Test func vibratoCreation() {
        let vib = Vibrato()
        #expect(vib.position == .right)
        #expect(vib.vibratoRenderOptions.harsh == false)
        #expect(vib.vibratoRenderOptions.vibratoWidth == 20)
    }

    @Test func vibratoSetHarsh() {
        let vib = Vibrato()
        _ = vib.setHarsh(true)
        #expect(vib.vibratoRenderOptions.harsh == true)
    }

    @Test func vibratoSetWidth() {
        let vib = Vibrato()
        _ = vib.setVibratoWidth(30)
        #expect(vib.vibratoRenderOptions.vibratoWidth == 30)
        #expect(vib.getWidth() == 30)
    }

    @Test func vibratoRenderOptionsDefaults() {
        let opts = VibratoRenderOptions()
        #expect(opts.harsh == false)
        #expect(opts.vibratoWidth == 20)
        #expect(opts.waveHeight == 6)
        #expect(opts.waveWidth == 4)
        #expect(opts.waveGirth == 2)
    }

    @Test func vibratoRenderOptionsCustom() {
        let opts = VibratoRenderOptions(harsh: true, vibratoWidth: 30, waveHeight: 8, waveWidth: 5, waveGirth: 3)
        #expect(opts.harsh == true)
        #expect(opts.vibratoWidth == 30)
        #expect(opts.waveHeight == 8)
        #expect(opts.waveWidth == 5)
        #expect(opts.waveGirth == 3)
    }

    @Test func vibratoStaticFormat() {
        let vib = Vibrato()
        var state = ModifierContextState()
        let mc = ModifierContext()
        let result = Vibrato.format([vib], state: &state, context: mc)
        #expect(result == true)
        #expect(state.rightShift > 0)
    }

    @Test func vibratoFormatEmpty() {
        var state = ModifierContextState()
        let mc = ModifierContext()
        let result = Vibrato.format([], state: &state, context: mc)
        #expect(result == false)
    }

    // ============================================================
    // MARK: - VibratoBracket Tests
    // ============================================================

    @Test func vibratoBracketCategory() {
        #expect(VibratoBracket.category == "VibratoBracket")
    }

    @Test func vibratoBracketWithStart() {
        let note = makeNote()
        let vb = VibratoBracket(start: note, stop: nil)
        #expect(vb.start != nil)
        #expect(vb.stop == nil)
    }

    @Test func vibratoBracketWithStop() {
        let note = makeNote()
        let vb = VibratoBracket(start: nil, stop: note)
        #expect(vb.start == nil)
        #expect(vb.stop != nil)
    }

    @Test func vibratoBracketWithBoth() {
        let note1 = makeNote()
        let note2 = makeNote()
        let vb = VibratoBracket(start: note1, stop: note2)
        #expect(vb.start != nil)
        #expect(vb.stop != nil)
    }

    @Test func vibratoBracketSetLine() {
        let note = makeNote()
        let vb = VibratoBracket(start: note)
        _ = vb.setLine(2)
        #expect(vb.vibLine == 2)
    }

    @Test func vibratoBracketSetHarsh() {
        let note = makeNote()
        let vb = VibratoBracket(start: note)
        _ = vb.setHarsh(true)
        #expect(vb.vibRenderOptions.harsh == true)
    }

    // ============================================================
    // MARK: - VibratoRenderOptions Tests
    // ============================================================

    @Test func vibratoRenderOptionsInitWithZeroWidth() {
        let opts = VibratoRenderOptions(vibratoWidth: 0)
        #expect(opts.vibratoWidth == 0)
        #expect(opts.harsh == false)
    }

    // ============================================================
    // MARK: - Parenthesis Tests
    // ============================================================

    @Test func parenthesisCategory() {
        #expect(Parenthesis.category == "Parenthesis")
    }

    @Test func parenthesisLeftCreation() {
        let paren = Parenthesis(position: .left)
        #expect(paren.position == .left)
        #expect(paren.point > 0)
        #expect(paren.getWidth() > 0)
    }

    @Test func parenthesisRightCreation() {
        let paren = Parenthesis(position: .right)
        #expect(paren.position == .right)
        #expect(paren.point > 0)
    }

    @Test func parenthesisSetNoteDefault() {
        let paren = Parenthesis(position: .left)
        let note = makeNote()
        _ = paren.setNote(note)
        #expect(paren.point == Note.getPoint("default"))
    }

    @Test func parenthesisSetNoteGrace() {
        let paren = Parenthesis(position: .left)
        let graceNote = GraceNote(GraceNoteStruct(keys: ["c/4"], duration: "8"))
        _ = paren.setNote(graceNote)
        // Grace note should get a smaller point
        #expect(paren.point == Note.getPoint("gracenote"))
    }

    @Test func parenthesisBuildAndAttach() {
        let note = makeNote(keys: ["c/4", "e/4"])
        Parenthesis.buildAndAttach([note])
        // Each key gets left + right parenthesis = 4 total for 2 keys
        let mods = note.getModifiers()
        let parens = mods.compactMap { $0 as? Parenthesis }
        #expect(parens.count == 4)
    }

    @Test func parenthesisStaticFormat() {
        let paren = Parenthesis(position: .right)
        let note = makeNote()
        _ = note.addModifier(paren, index: 0)
        var state = ModifierContextState()
        let result = Parenthesis.format([paren], state: &state)
        #expect(result == true)
    }

    @Test func parenthesisFormatEmpty() {
        var state = ModifierContextState()
        let result = Parenthesis.format([], state: &state)
        #expect(result == false)
    }

    // ============================================================
    // MARK: - Note Parenthesis Helpers
    // ============================================================

    @Test func noteRightParenthesisPxNonDisplaced() {
        let note = makeNote()
        let px = note.getRightParenthesisPx(index: 0)
        #expect(px == 0)
    }

    @Test func noteLeftParenthesisPxNonDisplaced() {
        let note = makeNote()
        let px = note.getLeftParenthesisPx(index: 0)
        // xShift is 0, displaced is false, so result is -xShift = 0
        #expect(px == 0)
    }

    // ============================================================
    // MARK: - Crescendo Tests
    // ============================================================

    @Test func crescendoCategory() {
        #expect(Crescendo.category == "Crescendo")
    }

    @Test func crescendoCreation() {
        let cresc = Crescendo(NoteStruct(duration: "4"))
        #expect(cresc.decrescendo == false)
        #expect(cresc.height == 15)
        #expect(cresc.line == 0)
    }

    @Test func crescendoWithLine() {
        let cresc = Crescendo(NoteStruct(duration: "4", line: 3))
        #expect(cresc.line == 3)
    }

    @Test func crescendoSetDecrescendo() {
        let cresc = Crescendo(NoteStruct(duration: "4"))
        _ = cresc.setDecrescendo(true)
        #expect(cresc.decrescendo == true)
    }

    @Test func crescendoSetHeight() {
        let cresc = Crescendo(NoteStruct(duration: "4"))
        _ = cresc.setHeight(20)
        #expect(cresc.height == 20)
    }

    @Test func crescendoSetLine() {
        let cresc = Crescendo(NoteStruct(duration: "4"))
        _ = cresc.setLine(2)
        #expect(cresc.line == 2)
    }

    @Test func crescendoPreFormat() {
        let cresc = Crescendo(NoteStruct(duration: "4"))
        cresc.preFormat()
        #expect(cresc.preFormatted == true)
    }

    @Test func crescendoOptions() {
        let opts = CrescendoOptions(extendLeft: 5, extendRight: 10, yShift: 3)
        #expect(opts.extendLeft == 5)
        #expect(opts.extendRight == 10)
        #expect(opts.yShift == 3)
    }

    @Test func crescendoOptionsDefault() {
        let opts = CrescendoOptions()
        #expect(opts.extendLeft == 0)
        #expect(opts.extendRight == 0)
        #expect(opts.yShift == 0)
    }

    // ============================================================
    // MARK: - MultiMeasureRest Tests
    // ============================================================

    @Test func multiMeasureRestCategory() {
        #expect(MultiMeasureRest.category == "MultiMeasureRest")
    }

    @Test func multiMeasureRestCreation() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 4)
        let mmr = MultiMeasureRest(numberOfMeasures: 4, options: opts)
        #expect(mmr.numberOfMeasures == 4)
        #expect(mmr.renderOpts.useSymbols == false)
        #expect(mmr.renderOpts.showNumber == true)
    }

    @Test func multiMeasureRestSetStave() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 4)
        let mmr = MultiMeasureRest(numberOfMeasures: 4, options: opts)
        let stave = makeStave()
        _ = mmr.setStave(stave)
        #expect(mmr.getStave() != nil)
    }

    @Test func multiMeasureRestCheckStave() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 4)
        let mmr = MultiMeasureRest(numberOfMeasures: 4, options: opts)
        let stave = makeStave()
        _ = mmr.setStave(stave)
        let checked = mmr.checkStave()
        #expect(checked === stave)
    }

    @Test func multiMeasureRestRenderOptions() {
        let opts = MultiMeasureRestRenderOptions(
            numberOfMeasures: 8,
            useSymbols: true,
            symbolSpacing: 15,
            showNumber: false,
            numberLine: -1,
            paddingLeft: 10,
            paddingRight: 20,
            line: 3,
            serifThickness: 3
        )
        #expect(opts.useSymbols == true)
        #expect(opts.symbolSpacing == 15)
        #expect(opts.showNumber == false)
        #expect(opts.paddingLeft == 10)
        #expect(opts.paddingRight == 20)
        #expect(opts.line == 3)
        #expect(opts.serifThickness == 3)
    }

    @Test func multiMeasureRestDefaultOptions() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 2)
        #expect(opts.useSymbols == false)
        #expect(opts.showNumber == true)
        #expect(opts.line == 2)
        #expect(opts.spacingBetweenLinesPx == Tables.STAVE_LINE_DISTANCE)
        #expect(opts.semibreveRestGlyphScale == Tables.NOTATION_FONT_SCALE)
        #expect(opts.serifThickness == 2)
    }

    @Test func multiMeasureRestGetXs() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 4)
        let mmr = MultiMeasureRest(numberOfMeasures: 4, options: opts)
        let xs = mmr.getXs()
        #expect(xs.left == 0)
        #expect(xs.right == 0)
    }

    @Test func multiMeasureRestNumberGlyphPoint() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 4, numberGlyphPoint: 50)
        #expect(opts.numberGlyphPoint == 50)
    }

    // ============================================================
    // MARK: - ModifierContext Integration
    // ============================================================

    @Test func modifierContextIncludesNoteSubGroup() {
        let clef = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clef])
        let note = makeNote()
        _ = note.addModifier(group, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(group)
        mc.preFormat()
        #expect(mc.getWidth() > 0)
    }

    @Test func modifierContextIncludesVibrato() {
        let vib = Vibrato()
        let note = makeNote()
        _ = note.addModifier(vib, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(vib)
        mc.preFormat()
        #expect(mc.getWidth() > 0)
    }

    @Test func modifierContextIncludesParenthesis() {
        let paren = Parenthesis(position: .right)
        let note = makeNote()
        _ = note.addModifier(paren, index: 0)

        let mc = ModifierContext()
        _ = mc.addMember(paren)
        mc.preFormat()
    }

    // ============================================================
    // MARK: - Cross-class Integration
    // ============================================================

    @Test func vibratoBracketRenderOptionsLink() {
        let note = makeNote()
        let vb = VibratoBracket(start: note)
        #expect(vb.vibRenderOptions.vibratoWidth == 0)
        _ = vb.setHarsh(true)
        #expect(vb.vibRenderOptions.harsh == true)
    }

    @Test func crescendoIsNote() {
        let cresc = Crescendo(NoteStruct(duration: "4"))
        #expect(cresc is Note)
    }

    @Test func barNoteIsNote() {
        let barNote = BarNote()
        #expect(barNote is Note)
    }

    @Test func multiMeasureRestIsElement() {
        let opts = MultiMeasureRestRenderOptions(numberOfMeasures: 4)
        let mmr = MultiMeasureRest(numberOfMeasures: 4, options: opts)
        #expect(mmr is VexElement)
    }

    @Test func parenthesisIsModifier() {
        let paren = Parenthesis(position: .left)
        #expect(paren is Modifier)
    }

    @Test func vibratoIsModifier() {
        let vib = Vibrato()
        #expect(vib is Modifier)
    }

    @Test func noteSubGroupIsModifier() {
        let clef = ClefNote(type: "treble")
        let group = NoteSubGroup(subNotes: [clef])
        #expect(group is Modifier)
    }
}
