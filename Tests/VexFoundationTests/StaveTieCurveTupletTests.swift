// VexFoundation - Tests for Phase 8: StaveTie, Curve, Tuplet

import Testing
@testable import VexFoundation

@Suite("StaveTie, Curve & Tuplet")
struct StaveTieCurveTupletTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Helper

    private func makeNote(keys: NonEmptyArray<StaffKeySpec>, duration: NoteDurationSpec) -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: keys, duration: duration))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()
        return note
    }

    // MARK: - StaveTie Creation

    @Test func staveTieCreation() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note1, lastNote: note2))
        #expect(tie.getNotes().firstNote === note1)
        #expect(tie.getNotes().lastNote === note2)
        #expect(!tie.isPartial())
    }

    @Test func staveTieWithText() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note1, lastNote: note2), text: "H")
        #expect(tie.text == "H")
    }

    @Test func staveTiePartialFirst() throws {
        let note = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(lastNote: note))
        #expect(tie.isPartial())
        #expect(tie.getNotes().firstNote == nil)
        #expect(tie.getNotes().lastNote === note)
    }

    @Test func staveTiePartialLast() throws {
        let note = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note))
        #expect(tie.isPartial())
        #expect(tie.getNotes().firstNote === note)
        #expect(tie.getNotes().lastNote == nil)
    }

    @Test func staveTieIndices() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4), StaffKeySpec(letter: .e, octave: 4), StaffKeySpec(letter: .g, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4), StaffKeySpec(letter: .e, octave: 4), StaffKeySpec(letter: .g, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(
            firstNote: note1, lastNote: note2,
            firstIndices: [0, 1, 2], lastIndices: [0, 1, 2]
        ))
        #expect(tie.getNotes().firstIndices == [0, 1, 2])
        #expect(tie.getNotes().lastIndices == [0, 1, 2])
    }

    @Test func staveTieDefaultIndices() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note1, lastNote: note2))
        #expect(tie.getNotes().firstIndices == [0])
        #expect(tie.getNotes().lastIndices == [0])
    }

    @Test func staveTieDirection() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note1, lastNote: note2))
        _ = tie.setDirection(Stem.DOWN)
        #expect(tie.direction == .down)
    }

    @Test func staveTieRenderOptions() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note1, lastNote: note2))
        #expect(tie.renderOptions.cp1 == 8)
        #expect(tie.renderOptions.cp2 == 12)
        #expect(tie.renderOptions.yShift == 7)
        #expect(tie.renderOptions.tieSpacing == 0)
    }

    @Test func staveTieCategory() throws {
        #expect(StaveTie.category == "StaveTie")
    }

    @Test func staveTieValidatingInitAndThrowingSetNotes() throws {
        do {
            _ = try StaveTie(validating: TieNotes())
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveTieError == .requiresStartOrEndNote)
        }

        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .quarter)
        let tie = StaveTie(notes: TieNotes(firstNote: note1, lastNote: note2))

        do {
            _ = try tie.setNotesThrowing(TieNotes(
                firstNote: note1,
                lastNote: note2,
                firstIndices: [0, 1],
                lastIndices: [0]
            ))
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveTieError == .mismatchedIndices(firstCount: 2, lastCount: 1))
        }
    }

    // MARK: - Curve Creation

    @Test func curveCreation() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .quarter)
        let curve = Curve(from: note1, to: note2)
        #expect(curve.from === note1)
        #expect(curve.to === note2)
        #expect(!curve.isPartial())
    }

    @Test func curvePartial() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let curve = Curve(from: note1, to: nil)
        #expect(curve.isPartial())
    }

    @Test func curveDefaultOptions() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .quarter)
        let curve = Curve(from: note1, to: note2)
        #expect(curve.renderOptions.thickness == 2)
        #expect(curve.renderOptions.xShift == 0)
        #expect(curve.renderOptions.yShift == 10)
        #expect(curve.renderOptions.position == .nearHead)
        #expect(curve.renderOptions.positionEnd == .nearHead)
        #expect(curve.renderOptions.invert == false)
        #expect(curve.renderOptions.cps.count == 2)
    }

    @Test func curveCustomOptions() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .quarter)
        let opts = CurveOptions(
            cps: [(5, 20), (5, 20)],
            thickness: 3,
            xShift: 5,
            yShift: 15,
            position: .nearTop,
            positionEnd: .nearTop,
            invert: true
        )
        let curve = Curve(from: note1, to: note2, options: opts)
        #expect(curve.renderOptions.thickness == 3)
        #expect(curve.renderOptions.xShift == 5)
        #expect(curve.renderOptions.yShift == 15)
        #expect(curve.renderOptions.position == .nearTop)
        #expect(curve.renderOptions.positionEnd == .nearTop)
        #expect(curve.renderOptions.invert == true)
    }

    @Test func curveSetNotes() throws {
        let note1 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let note2 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .quarter)
        let note3 = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .g, octave: 4)), duration: .quarter)
        let curve = Curve(from: note1, to: note2)
        _ = curve.setNotes(from: note1, to: note3)
        #expect(curve.to === note3)
    }

    @Test func curveCategory() throws {
        #expect(Curve.category == "Curve")
    }

    @Test func curveThrowingSetNotesValidation() throws {
        let note = makeNote(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)
        let curve = Curve(from: note, to: nil)
        do {
            _ = try curve.setNotesThrowing(from: nil, to: nil)
            #expect(Bool(false))
        } catch {
            #expect(error as? CurveError == .requiresStartOrEndNote)
        }
    }

    @Test func curvePositionEnum() throws {
        #expect(CurvePosition.nearHead.rawValue == 1)
        #expect(CurvePosition.nearTop.rawValue == 2)
    }

    // MARK: - Tuplet Creation

    @Test func tupletCreation() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        #expect(tuplet.numNotes == 3)
        #expect(tuplet.notesOccupied == 2) // default
        #expect(tuplet.getNotes().count == 3)
    }

    @Test func tupletDefaultBracketed() throws {
        // Notes without beams should default to bracketed
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        #expect(tuplet.bracketed == true) // no beams
    }

    @Test func tupletBeamedNotBracketed() throws {
        // All notes beamed → not bracketed
        let notes: [StemmableNote] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let beam = try Beam(notes) // must retain beam since Note.beam is weak
        let tuplet = try Tuplet(notes: notes as [Note])
        #expect(tuplet.bracketed == false) // all beamed
        _ = beam // keep beam alive
    }

    @Test func tupletSetBracketed() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        _ = tuplet.setBracketed(false)
        #expect(tuplet.bracketed == false)
    }

    @Test func tupletRatioed() throws {
        // Difference of 1 (3:2) → not ratioed
        let notes3: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let triplet = try Tuplet(notes: notes3)
        #expect(triplet.ratioed == false) // abs(2-3) = 1, not > 1

        // Difference > 1 (5:3) → ratioed
        let notes5: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .f, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .g, octave: 4)), duration: .eighth)),
        ]
        let quintuplet = try Tuplet(notes: notes5, options: TupletOptions(notesOccupied: 3))
        #expect(quintuplet.ratioed == true) // abs(3-5) = 2 > 1
    }

    @Test func tupletSetRatioed() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        _ = tuplet.setRatioed(true)
        #expect(tuplet.ratioed == true)
    }

    @Test func tupletLocation() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        #expect(tuplet.location == .top)

        _ = tuplet.setTupletLocation(.bottom)
        #expect(tuplet.location == .bottom)
    }

    @Test func tupletLocationEnum() throws {
        #expect(TupletLocation.top.rawValue == 1)
        #expect(TupletLocation.bottom.rawValue == -1)
    }

    @Test func tupletCustomNumNotes() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .quarter)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .quarter)),
        ]
        let tuplet = try Tuplet(notes: notes, options: TupletOptions(numNotes: 3, notesOccupied: 2))
        #expect(tuplet.numNotes == 3)
        #expect(tuplet.notesOccupied == 2)
    }

    @Test func tupletCategory() throws {
        #expect(Tuplet.category == "Tuplet")
    }

    @Test func tupletNestingOffset() throws {
        #expect(Tuplet.NESTING_OFFSET == 15)
    }

    @Test func tupletAttach() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        // Each note should have this tuplet in its stack
        for note in notes {
            #expect(note.getTupletStack().contains { $0 === tuplet })
        }
    }

    @Test func tupletDetach() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        tuplet.detach()
        for note in notes {
            #expect(!note.getTupletStack().contains { $0 === tuplet })
        }
    }

    @Test func tupletTickMultiplier() throws {
        // A triplet should adjust ticks: multiply by 2/3
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        let ticksBefore = note.getTicks()
        let notes: [Note] = [
            note,
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        _ = try Tuplet(notes: notes)
        let ticksAfter = note.getTicks()
        // Triplet: 3 notes in space of 2 → ticks * 2/3
        let expectedTicks = ticksBefore.value() * 2.0 / 3.0
        #expect(abs(ticksAfter.value() - expectedTicks) < 0.01)
    }

    @Test func tupletMetrics() throws {
        let m = Tuplet.metrics
        #expect(m.noteHeadOffset > 0)
        #expect(m.stemOffset > 0)
        #expect(m.bottomLine > 0)
        #expect(m.topModifierOffset > 0)
    }

    @Test func tupletGetNoteCount() throws {
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        #expect(tuplet.getNoteCount() == 3)
        #expect(tuplet.getNotesOccupied() == 2)
    }

    @Test func tupletYPositionTop() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        for note in notes {
            _ = note.setStave(stave)
            if let sn = note as? StaveNote {
                _ = sn.setStemDirection(Stem.UP)
                _ = sn.buildStem()
            }
        }
        let tuplet = try Tuplet(notes: notes)
        let yPos = tuplet.getYPosition()
        // Y should be above the stave (lower value = higher position)
        #expect(yPos < stave.getYForLine(3))
    }

    @Test func tupletYPositionBottom() throws {
        let stave = Stave(x: 10, y: 40, width: 300)
        let notes: [Note] = [
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 5)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 5)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 5)), duration: .eighth)),
        ]
        for note in notes {
            _ = note.setStave(stave)
            if let sn = note as? StaveNote {
                _ = sn.setStemDirection(Stem.DOWN)
                _ = sn.buildStem()
            }
        }
        let tuplet = try Tuplet(notes: notes, options: TupletOptions(location: .bottom))
        let yPos = tuplet.getYPosition()
        // Y should be below the stave (higher value = lower position)
        #expect(yPos > stave.getYForLine(3))
    }

    // MARK: - Tickable Tuplet Stack

    @Test func tickableTupletStack() throws {
        let note = StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth))
        #expect(note.getTupletStack().isEmpty)

        let notes: [Note] = [
            note,
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = try Tuplet(notes: notes)
        #expect(note.getTupletStack().count == 1)
        #expect(note.getTuplet() === tuplet)
    }
}
