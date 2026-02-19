// VexFoundation - Tests for Phase 9: Note Types & Annotation

import Testing
@testable import VexFoundation

@Suite("Note Types & Annotation")
struct Phase9Tests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Helper

    private func makeNote(keys: NonEmptyArray<StaffKeySpec> = NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: NoteValue = .quarter) -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: keys, duration: duration))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()
        return note
    }

    // MARK: - GhostNote

    @Test func ghostNoteCreation() {
        let ghost = GhostNote(.quarter)
        #expect(GhostNote.category == "GhostNote")
        #expect(ghost.isRest())
    }

    @Test func ghostNoteFromStruct() {
        let ghost = GhostNote(NoteStruct(duration: .eighth))
        #expect(ghost.isRest())
    }

    @Test func ghostNotePreFormat() {
        let ghost = GhostNote(.quarter)
        ghost.preFormat()
        #expect(ghost.preFormatted == true)
    }

    @Test func ghostNoteDoesNotParticipateInModifierContext() {
        let ghost = GhostNote(.quarter)
        let mc = ModifierContext()
        _ = ghost.addToModifierContext(mc)
        // Ghost note should not add itself to modifier context
        #expect(mc.getMembers("GhostNote").isEmpty)
    }

    // MARK: - GlyphNote

    @Test func glyphNoteCreation() {
        let glyph = Glyph(code: "segno", point: 40)
        let note = GlyphNote(glyph: glyph, noteStruct: NoteStruct(duration: .quarter))
        #expect(GlyphNote.category == "GlyphNote")
        #expect(note.getGlyphWidth() > 0)
    }

    @Test func glyphNoteOptions() {
        let glyph = Glyph(code: "coda", point: 40)
        let options = GlyphNoteOptions(ignoreTicks: true, line: 3)
        let note = GlyphNote(glyph: glyph, noteStruct: NoteStruct(duration: .quarter), options: options)
        #expect(note.glyphNoteOptions.ignoreTicks == true)
        #expect(note.glyphNoteOptions.line == 3)
    }

    @Test func glyphNoteSetGlyph() {
        let glyph1 = Glyph(code: "segno", point: 40)
        let glyph2 = Glyph(code: "coda", point: 40)
        let note = GlyphNote(glyph: glyph1, noteStruct: NoteStruct(duration: .quarter))
        let width1 = note.getGlyphWidth()
        _ = note.setGlyph(glyph2)
        let width2 = note.getGlyphWidth()
        // Both should have positive width (may or may not differ)
        #expect(width1 > 0)
        #expect(width2 > 0)
    }

    @Test func glyphNotePreFormat() {
        let glyph = Glyph(code: "segno", point: 40)
        let note = GlyphNote(glyph: glyph, noteStruct: NoteStruct(duration: .quarter))
        note.preFormat()
        #expect(note.preFormatted == true)
    }

    // MARK: - RepeatNote

    @Test func repeatNoteCreation() {
        let note = RepeatNote(type: "1")
        #expect(RepeatNote.category == "RepeatNote")
        #expect(note.getGlyphWidth() > 0)
    }

    @Test func repeatNoteTypes() {
        let note1 = RepeatNote(type: "1")
        let note2 = RepeatNote(type: "2")
        let note4 = RepeatNote(type: "4")
        let slash = RepeatNote(type: "slash")
        // All should have positive widths
        #expect(note1.getGlyphWidth() > 0)
        #expect(note2.getGlyphWidth() > 0)
        #expect(note4.getGlyphWidth() > 0)
        #expect(slash.getGlyphWidth() > 0)
    }

    @Test func repeatNoteUnknownType() {
        // Unknown type defaults to repeat1Bar
        let note = RepeatNote(type: "unknown")
        #expect(note.getGlyphWidth() > 0)
    }

    // MARK: - ClefNote

    @Test func clefNoteCreation() {
        let note = ClefNote(type: .treble)
        #expect(ClefNote.category == "ClefNote")
        #expect(note.clefDef.code == "gClef")
        #expect(note.clefSize == .default)
    }

    @Test func clefNoteBass() {
        let note = ClefNote(type: .bass)
        #expect(note.clefDef.code == "fClef")
    }

    @Test func clefNoteAlto() {
        let note = ClefNote(type: .alto)
        #expect(note.clefDef.code == "cClef")
    }

    @Test func clefNoteSmallSize() {
        let note = ClefNote(type: .treble, size: .small)
        #expect(note.clefSize == .small)
    }

    @Test func clefNoteWithAnnotation() {
        let note = ClefNote(type: .treble, annotation: .octaveUp)
        #expect(note.clefAnnotation != nil)
    }

    @Test func clefNotePreFormat() {
        let note = ClefNote(type: .treble)
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        note.preFormat()
        #expect(note.preFormatted == true)
    }

    @Test func clefNoteSetType() {
        let note = ClefNote(type: .treble)
        _ = note.setType(.bass)
        #expect(note.clefDef.code == "fClef")
        #expect(note.clefTypeName == .bass)
    }

    // MARK: - KeySigNote

    @Test func keySigNoteCreation() {
        let note = KeySigNote(keySpec: "G")
        #expect(KeySigNote.category == "KeySigNote")
        #expect(note.shouldIgnoreTicks())
    }

    @Test func keySigNotePreFormat() {
        let note = KeySigNote(keySpec: "D")
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        note.preFormat()
        #expect(note.preFormatted == true)
    }

    @Test func keySigNoteDoesNotParticipateInModifierContext() {
        let note = KeySigNote(keySpec: "G")
        let mc = ModifierContext()
        _ = note.addToModifierContext(mc)
        #expect(mc.getMembers("KeySigNote").isEmpty)
    }

    // MARK: - TextNote

    @Test func textNoteCreation() {
        let note = TextNote(TextNoteStruct(text: "Hello"))
        #expect(TextNote.category == "TextNote")
        #expect(note.getText() == "Hello")
    }

    @Test func textNoteWithGlyph() {
        let note = TextNote(TextNoteStruct(glyph: "segno"))
        #expect(note.noteGlyph != nil)
    }

    @Test func textNoteJustification() {
        let note = TextNote(TextNoteStruct(text: "test"))
        _ = note.setJustification(.center)
        #expect(note.justification == .center)

        _ = note.setJustification(.right)
        #expect(note.justification == .right)
    }

    @Test func textNoteLine() {
        let note = TextNote(TextNoteStruct(text: "test", line: 3))
        #expect(note.getLine() == 3)

        _ = note.setLine(5)
        #expect(note.getLine() == 5)
    }

    @Test func textNoteSmooth() {
        let note = TextNote(TextNoteStruct(text: "test", smooth: true))
        #expect(note.smooth == true)
        note.preFormat()
        // Smooth notes have 0 width
    }

    @Test func textNoteSuperscript() {
        let note = TextNote(TextNoteStruct(text: "rit.", superscript: "decresc."))
        #expect(note.superscriptText == "decresc.")
    }

    @Test func textNoteSubscript() {
        let note = TextNote(TextNoteStruct(text: "p", subscriptText: "sub"))
        #expect(note.subscriptText == "sub")
    }

    @Test func textNoteIgnoreTicks() {
        let note = TextNote(TextNoteStruct(text: "segno", ignoreTicks: true))
        #expect(note.shouldIgnoreTicks() == true)
    }

    @Test func textNotePreFormat() {
        let note = TextNote(TextNoteStruct(text: "test"))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        note.preFormat()
        #expect(note.preFormatted == true)
    }

    @Test func textJustificationEnum() {
        #expect(TextJustification.left.rawValue == 1)
        #expect(TextJustification.center.rawValue == 2)
        #expect(TextJustification.right.rawValue == 3)
    }

    @Test func textNoteGlyphTypes() {
        // Test various glyph types create valid notes
        let types = ["segno", "coda", "f", "p", "tr", "turn", "breath"]
        for type in types {
            let note = TextNote(TextNoteStruct(glyph: type))
            #expect(note.noteGlyph != nil, "Glyph \(type) should exist")
        }
    }

    // MARK: - Annotation

    @Test func annotationCreation() {
        let ann = Annotation("Test")
        #expect(Annotation.category == "Annotation")
        #expect(ann.text == "Test")
        #expect(ann.getWidth() > 0)
    }

    @Test func annotationHorizontalJustification() {
        let ann = Annotation("Test")
        #expect(ann.getJustification() == .center) // default

        _ = ann.setJustification(.left)
        #expect(ann.getJustification() == .left)

        _ = ann.setJustification(.right)
        #expect(ann.getJustification() == .right)

        _ = ann.setJustification(.centerStem)
        #expect(ann.getJustification() == .centerStem)
    }

    @Test func annotationVerticalJustification() {
        let ann = Annotation("Test")
        #expect(ann.verticalJustification == .top) // default

        _ = ann.setVerticalJustification(.bottom)
        #expect(ann.verticalJustification == .bottom)

        _ = ann.setVerticalJustification(.center)
        #expect(ann.verticalJustification == .center)
    }

    @Test func annotationJustificationEnums() {
        #expect(AnnotationHorizontalJustify.left.rawValue == 1)
        #expect(AnnotationHorizontalJustify.center.rawValue == 2)
        #expect(AnnotationHorizontalJustify.right.rawValue == 3)
        #expect(AnnotationHorizontalJustify.centerStem.rawValue == 4)

        #expect(AnnotationVerticalJustify.top.rawValue == 1)
        #expect(AnnotationVerticalJustify.center.rawValue == 2)
        #expect(AnnotationVerticalJustify.bottom.rawValue == 3)
        #expect(AnnotationVerticalJustify.centerStem.rawValue == 4)
    }

    @Test func annotationFormat() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()

        let ann = Annotation("Test")
        _ = ann.setNote(note)
        _ = ann.setIndex(0)

        var state = ModifierContextState()
        let result = Annotation.format([ann], state: &state)
        #expect(result == true)
        #expect(state.topTextLine > 0) // Should have advanced text line
    }

    @Test func annotationFormatBottom() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()

        let ann = Annotation("Below")
        _ = ann.setVerticalJustification(.bottom)
        _ = ann.setNote(note)
        _ = ann.setIndex(0)

        var state = ModifierContextState()
        Annotation.format([ann], state: &state)
        #expect(state.textLine > 0) // Should have advanced bottom text line
    }

    @Test func annotationModifierContext() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()

        let ann = Annotation("Test")
        _ = note.addModifier(ann, index: 0)

        let mc = ModifierContext()
        _ = note.addToModifierContext(mc)
        mc.preFormat()

        #expect(mc.formatted == true)
    }

    // MARK: - Glyph renderToStave

    @Test func glyphRenderToStaveSetup() {
        let glyph = Glyph(code: "gClef", point: 40)
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = glyph.setStave(stave)
        #expect(glyph.stave === stave)
    }

    @Test func glyphSetYShift() {
        let glyph = Glyph(code: "gClef", point: 40)
        _ = glyph.setYShift(5)
        #expect(glyph.getYShift() == 5)
    }

    @Test func glyphSetXShift() {
        let glyph = Glyph(code: "gClef", point: 40)
        _ = glyph.setXShift(3)
        #expect(glyph.getXShift() == 3)
    }
}
