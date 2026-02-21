import Testing
@testable import VexFoundation

@Suite("Note System")
struct NoteTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - Tables Extensions

    @Test func sanitizeDuration() {
        #expect(Tables.sanitizeDuration("q") == "4")
        #expect(Tables.sanitizeDuration("h") == "2")
        #expect(Tables.sanitizeDuration("w") == "1")
        #expect(Tables.sanitizeDuration("8") == "8")
        #expect(Tables.sanitizeDuration("16") == "16")
    }

    @Test func durationToFraction() {
        let q = Tables.durationToFraction("4")
        #expect(q.numerator == 4)
        #expect(q.denominator == 1)

        let h = Tables.durationToFraction("2")
        #expect(h.numerator == 2)
        #expect(h.denominator == 1)
    }

    @Test func durationToNumber() {
        #expect(Tables.durationToNumber("4") == 4.0)
        #expect(Tables.durationToNumber("2") == 2.0)
        #expect(Tables.durationToNumber("1") == 1.0)
    }

    @Test func clefPropertiesLookup() {
        #expect(Tables.clefProperties(.treble) == 0)
        #expect(Tables.clefProperties(.bass) == 6)
        #expect(Tables.clefProperties(.alto) == 3)
        #expect(Tables.clefProperties(.tenor) == 4)
    }

    @Test func keyPropertiesBasic() throws {
        let c4 = try Tables.keyProperties("c/4")
        #expect(c4.key == "C")
        #expect(c4.octave == 4)
        #expect(c4.intValue == 48) // 4 * 12 + 0
        #expect(c4.accidental == nil)

        let g5 = try Tables.keyProperties("g/5")
        #expect(g5.key == "G")
        #expect(g5.octave == 5)
        #expect(g5.intValue == 67) // 5 * 12 + 7
    }

    @Test func keyPropertiesLine() throws {
        // Middle C (C/4) on treble clef should be at line 5 (below staff)
        // line = (octave * 7 - 28 + index) / 2 + clefShift
        // C/4 treble: (4*7 - 28 + 0) / 2 + 0 = 0
        let c4 = try Tables.keyProperties("c/4")
        #expect(c4.line == 0)

        // On bass clef, C/4 should be higher
        let c4Bass = try Tables.keyProperties("c/4", clef: .bass)
        #expect(c4Bass.line == 6) // shifted by 6
    }

    @Test func keyPropertiesWithAccidental() throws {
        let fSharp = try Tables.keyProperties("f#/4")
        #expect(fSharp.key == "F#")
        #expect(fSharp.accidental == "#")
        #expect(fSharp.intValue == 54) // 4 * 12 + 6
    }

    @Test func integerToNote() {
        #expect(Tables.integerToNote(0) == "C")
        #expect(Tables.integerToNote(4) == "E")
        #expect(Tables.integerToNote(7) == "G")
        #expect(Tables.integerToNote(11) == "B")
    }

    @Test func codeNoteHead() {
        #expect(Tables.codeNoteHead("D", duration: .quarter) == "noteheadDiamondBlack")
        #expect(Tables.codeNoteHead("D", duration: .whole) == "noteheadDiamondWhole")
        #expect(Tables.codeNoteHead("N", duration: .quarter) == "noteheadBlack")
        #expect(Tables.codeNoteHead("N", duration: .whole) == "noteheadWhole")
        #expect(Tables.codeNoteHead("X0", duration: .quarter) == "noteheadXWhole")
    }

    @Test func validTypes() {
        #expect(Tables.validTypes["n"] == "note")
        #expect(Tables.validTypes["r"] == "rest")
        #expect(Tables.validTypes["h"] == "harmonic")
        #expect(Tables.validTypes["s"] == "slash")
        #expect(Tables.validTypes["z"] == nil)
    }

    // MARK: - Modifier

    @Test func modifierProperties() {
        let mod = Modifier()
        #expect(mod.getCategory() == "Modifier")
        #expect(mod.getPosition() == .left)
        #expect(mod.getWidth() == 0)
        #expect(mod.getXShift() == 0)

        mod.setPosition(.right)
        #expect(mod.getPosition() == .right)

        mod.setWidth(10)
        #expect(mod.getWidth() == 10)
    }

    @Test func modifierPositionSendable() {
        // Verifies ModifierPosition is Sendable (compile-time check)
        let positions: [String: ModifierPosition] = [
            "center": .center, "left": .left, "right": .right,
        ]
        #expect(positions.count == 3)
    }

    // MARK: - Stem

    @Test func stemDirections() {
        #expect(Stem.UP.rawValue == 1)
        #expect(Stem.DOWN.rawValue == -1)
    }

    @Test func stemDimensions() {
        #expect(Stem.WIDTH == Tables.STEM_WIDTH)
        #expect(Stem.HEIGHT == Tables.STEM_HEIGHT)
    }

    @Test func stemExtents() {
        let stem = Stem(options: StemOptions(
            stemDirection: Stem.UP,
            yBottom: 50, yTop: 10, xEnd: 100, xBegin: 100
        ))
        let extents = stem.getExtents()
        // For stem up: tip = min(ys) + height * (-1) = 10 + 35 * (-1) = -25
        // base = max(ys) = 50
        #expect(extents.topY == 10 - Stem.HEIGHT)
        #expect(extents.baseY == 50)
    }

    @Test func stemExtentsDown() {
        let stem = Stem(options: StemOptions(
            stemDirection: Stem.DOWN,
            yBottom: 50, yTop: 10, xEnd: 100, xBegin: 100
        ))
        let extents = stem.getExtents()
        // For stem down: innerMost = max(ys) = 50, tip = 50 + 35 * 1 = 85
        // base = min(ys) = 10
        #expect(extents.topY == 50 + Stem.HEIGHT)
        #expect(extents.baseY == 10)
    }

    @Test func stemHeight() {
        let stem = Stem(options: StemOptions(
            stemDirection: Stem.UP,
            yBottom: 50, yTop: 10
        ))
        let height = stem.getHeight()
        // height = (50 - 10 + (35 - 0 + 0)) * 1 = 75
        #expect(height == 75)
    }

    @Test func stemVisibility() {
        let stem = Stem()
        #expect(stem.hide == false)
        stem.setVisibility(false)
        #expect(stem.hide == true)
        stem.setVisibility(true)
        #expect(stem.hide == false)
    }

    // MARK: - Tickable

    @Test func tickableInit() {
        let t = Tickable()
        #expect(t.getTicks().numerator == 0)
        #expect(t.getIntrinsicTicks() == 0)
        #expect(t.shouldIgnoreTicks() == false)
        #expect(t.isCenterAligned() == false)
    }

    @Test func tickableIntrinsicTicks() {
        let t = Tickable()
        t.setIntrinsicTicks(4096) // quarter note
        #expect(t.getIntrinsicTicks() == 4096)
        #expect(t.getTicks().numerator == 4096)
        #expect(t.getTicks().denominator == 1)
    }

    @Test func tickableTickMultiplier() {
        let t = Tickable()
        t.setIntrinsicTicks(4096)
        // Apply triplet: 2/3 (notesOccupied=2, noteCount=3)
        t.applyTickMultiplier(2, 3)
        let ticks = t.getTicks()
        // 4096 * 1 * 2/3 = 8192/3 ≈ 2730.67
        let expected = Fraction(4096 * 2, 3)
        #expect(ticks == expected)
    }

    @Test func tickableDuration() {
        let t = Tickable()
        t.setDuration(Fraction(1, 4))
        // 1/4 → ticks = 1 * (16384 / 4) = 4096
        #expect(t.getTicks().numerator == 4096)
    }

    @Test func tickableThrowingPreconditions() throws {
        let t = Tickable()

        do {
            _ = try t.getTickableWidthThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? TickableError == .unformattedWidth)
        }

        do {
            _ = try t.getVoiceThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? TickableError == .noVoice)
        }

        do {
            _ = try t.checkTickContextThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? TickableError == .noTickContext("Tickable has no tick context."))
        }

        do {
            _ = try t.checkModifierContextThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? TickableError == .noModifierContext)
        }
    }

    // MARK: - Note Parsing

    @Test func parseDuration() {
        let result = Note.parseDuration("4")
        #expect(result != nil)
        #expect(result!.value == .quarter)
        #expect(result!.dots == 0)
        #expect(result!.type == .note)

        let dotted = Note.parseDuration("8d")
        #expect(dotted != nil)
        #expect(dotted!.value == .eighth)
        #expect(dotted!.dots == 1)

        let rest = Note.parseDuration("4r")
        #expect(rest != nil)
        #expect(rest!.type == .rest)

        let doubleDotted = Note.parseDuration("2dd")
        #expect(doubleDotted != nil)
        #expect(doubleDotted!.dots == 2)
    }

    @Test func parseNoteStruct() {
        let ns = NoteStruct(keys: ["c/4", "e/4", "g/4"], duration: .quarter)
        let parsed = Note.parseNoteStruct(ns)
        #expect(parsed != nil)
        #expect(parsed!.duration == .quarter)
        #expect(parsed!.type == .note)
        #expect(parsed!.ticks == Tables.RESOLUTION / 4)
        #expect(parsed!.dots == 0)
    }

    @Test func parseNoteStructDotted() {
        let ns = NoteStruct(keys: ["c/4"], duration: .quarter, dots: 1)
        let parsed = Note.parseNoteStruct(ns)
        #expect(parsed != nil)
        // dotted quarter = 4096 + 2048 = 6144
        #expect(parsed!.ticks == 4096 + 2048)
    }

    @Test func parseNoteStructRest() {
        let ns = NoteStruct(duration: .quarter, type: .rest)
        let parsed = Note.parseNoteStruct(ns)
        #expect(parsed != nil)
        #expect(parsed!.type == .rest)
    }

    @Test func parseNoteStructInvalid() {
        let ns = NoteStruct(parsingDuration: "4z")
        #expect(ns == nil, "Invalid type 'z' should fail")
    }

    @Test func parseNoteStructThrowingValidation() throws {
        let invalid = NoteStruct(keys: ["c/4"], duration: .sixtyFourth, dots: 12)

        do {
            _ = try Note.parseNoteStructThrowing(invalid)
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .invalidInitializationData("64"))
        }

        let fallbackNote = TestNote(invalid)
        #expect(fallbackNote.initError == .invalidInitializationData("64"))
        #expect(fallbackNote.getTicks().numerator > 0)

        do {
            _ = try TestNote(validating: invalid)
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .invalidInitializationData("64"))
        }
    }

    // MARK: - Note Creation

    @Test func noteCreation() {
        let note = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        #expect(note.getDuration() == "4")
        #expect(note.getNoteType() == "n")
        #expect(note.getKeys().count == 1)
        #expect(note.getTicks().numerator == 4096) // quarter = 16384/4
    }

    @Test func noteCreationEighth() {
        let note = TestNote(NoteStruct(keys: ["d/5"], duration: .eighth))
        #expect(note.getDuration() == "8")
        #expect(note.getTicks().numerator == 2048)
        #expect(note.getGlyphProps().stem == true)
        #expect(note.getGlyphProps().flag == true)
        #expect(note.getGlyphProps().beamCount == 1)
    }

    @Test func noteCreationRest() {
        let note = TestNote(NoteStruct(duration: .quarter, type: .rest))
        #expect(note.getNoteType() == "r")
        #expect(note.getGlyphProps().rest == true)
        #expect(note.getGlyphProps().codeHead == "restQuarter")
    }

    @Test func noteHasStem() {
        let note = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        #expect(note.hasStem() == false) // Note base class returns false
    }

    @Test func noteIsRest() {
        let note = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        #expect(note.isRest() == false)
    }

    @Test func noteThrowingPreconditions() throws {
        let note = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))

        do {
            _ = try note.checkStaveThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .noStave)
        }

        do {
            _ = try note.getYsThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .noYValues)
        }

        do {
            _ = try note.getMetricsThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .unformattedMetrics)
        }

        do {
            _ = try note.getStemDirectionThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? NoteError == .noStem)
        }
    }

    // MARK: - Voice

    @Test func voiceCreation() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        #expect(voice.getTotalTicks().numerator == 4 * Tables.RESOLUTION / 4)
        #expect(voice.getMode() == .strict)
        #expect(voice.getTickables().isEmpty)
    }

    @Test func voiceTimeSpecInit() {
        let voice = Voice(timeSignature: .meter(3, 8))
        #expect(voice.time.numBeats == 3)
        #expect(voice.time.beatValue == 8)
    }

    @Test func voiceAddTickable() {
        let voice = Voice(time: VoiceTime(numBeats: 1, beatValue: 4))
        voice.setMode(.soft)
        let note = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        voice.addTickable(note)
        #expect(voice.getTickables().count == 1)
        #expect(voice.getTicksUsed().numerator == 4096)
    }

    @Test func voiceMultipleNotes() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        voice.setMode(.soft)
        for _ in 0..<4 {
            voice.addTickable(TestNote(NoteStruct(keys: ["c/4"], duration: .quarter)))
        }
        #expect(voice.getTickables().count == 4)
        #expect(voice.isComplete())
    }

    @Test func voiceSoftmax() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        voice.setMode(.soft)
        voice.addTickable(TestNote(NoteStruct(keys: ["c/4"], duration: .quarter)))
        voice.addTickable(TestNote(NoteStruct(keys: ["d/4"], duration: .quarter)))

        // Each quarter gets equal softmax
        let sm = voice.softmax(4096)
        #expect(sm > 0)
        #expect(sm <= 1)
    }

    @Test func voiceModeStrict() {
        let voice = Voice(time: VoiceTime(numBeats: 1, beatValue: 4))
        voice.setMode(.strict)
        // Add exactly one quarter note (4096 ticks) - should work
        voice.addTickable(TestNote(NoteStruct(keys: ["c/4"], duration: .quarter)))
        #expect(voice.isComplete())
    }

    // MARK: - TickContext

    @Test func tickContextCreation() {
        let tc = TickContext()
        #expect(tc.getX() == 0)
        #expect(tc.getWidth() == 2) // 0 + padding*2 = 2
        #expect(tc.getTickables().isEmpty)
    }

    @Test func tickContextSetX() {
        let tc = TickContext()
        tc.setX(100)
        #expect(tc.getX() == 100)
        #expect(tc.getXBase() == 100)
        #expect(tc.getXOffset() == 0)
    }

    @Test func tickContextXOffset() {
        let tc = TickContext()
        tc.setX(100)
        tc.setXOffset(10)
        #expect(tc.getX() == 110)
        #expect(tc.getXBase() == 100)
        #expect(tc.getXOffset() == 10)
    }

    @Test func tickContextAddTickable() {
        let tc = TickContext()
        let note = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        tc.addTickable(note)
        #expect(tc.getTickables().count == 1)
        #expect(tc.getMaxTicks().numerator == 4096)
    }

    @Test func tickContextMinMaxTicks() {
        let tc = TickContext()
        let quarter = TestNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        let eighth = TestNote(NoteStruct(keys: ["d/4"], duration: .eighth))
        tc.addTickable(quarter)
        tc.addTickable(eighth)

        #expect(tc.getMaxTicks().numerator == 4096)
        #expect(tc.getMinTicks()?.numerator == 2048)
    }

    @Test func tickContextPadding() {
        let tc = TickContext()
        tc.setPadding(5)
        // Width = 0 + 5*2 = 10
        #expect(tc.getWidth() == 10)
    }

    @Test func tickContextNextContext() {
        let tc1 = TickContext()
        let tc2 = TickContext()
        let tc3 = TickContext()
        tc1.tContexts = [tc1, tc2, tc3]
        tc2.tContexts = [tc1, tc2, tc3]
        tc3.tContexts = [tc1, tc2, tc3]

        let next = TickContext.getNextContext(tc1)
        #expect(next === tc2)

        let next2 = TickContext.getNextContext(tc2)
        #expect(next2 === tc3)

        let next3 = TickContext.getNextContext(tc3)
        #expect(next3 == nil)
    }

    // MARK: - NoteHead

    @Test func noteHeadCreation() {
        let nh = NoteHead(noteHeadStruct: NoteHeadStruct(
            duration: .quarter, line: 3
        ))
        #expect(nh.getCategory() == "NoteHead")
        #expect(nh.getLine() == 3)
        #expect(nh.isDisplaced() == false)
    }

    @Test func noteHeadDisplacement() {
        let nh = NoteHead(noteHeadStruct: NoteHeadStruct(
            duration: .quarter, line: 3, displaced: true
        ))
        #expect(nh.isDisplaced() == true)
    }

    @Test func noteHeadLineSet() {
        let nh = NoteHead(noteHeadStruct: NoteHeadStruct(
            duration: .quarter, line: 2
        ))
        #expect(nh.getLine() == 2)
        nh.setLine(4)
        #expect(nh.getLine() == 4)
    }

    @Test func noteHeadStructParsingDurationConvenience() {
        let parsed = NoteHeadStruct(parsingDuration: "8dr", line: 2)
        #expect(parsed != nil)

        if let parsed {
            #expect(parsed.duration == .eighth)
            #expect(parsed.noteType == .rest)
            #expect(parsed.dots == 1)
            #expect(parsed.line == 2)

            let nh = NoteHead(noteHeadStruct: parsed)
            #expect(nh.getDuration() == "8")
            #expect(nh.getNoteType() == "r")
        }
    }

    // MARK: - StemmableNote (via TestStemmableNote)

    @Test func stemmableNoteStemDirection() {
        let note = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        note.buildStem()
        note.setStemDirection(Stem.UP)
        #expect(note.getStemDirection() == Stem.UP)

        note.setStemDirection(Stem.DOWN)
        #expect(note.getStemDirection() == Stem.DOWN)
    }

    @Test func stemmableNoteStemLength() {
        let note = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        note.buildStem()
        note.setStemDirection(Stem.UP)
        let length = note.getStemLength()
        #expect(length == Stem.HEIGHT + note.getStemExtension())
    }

    @Test func stemmableNoteBeamCount() {
        let q = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        #expect(q.getBeamCount() == 0)

        let e = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .eighth))
        #expect(e.getBeamCount() == 1)

        let s = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .sixteenth))
        #expect(s.getBeamCount() == 2)
    }

    @Test func stemmableNoteHasFlag() {
        let e = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .eighth))
        e.buildStem()
        e.setStemDirection(Stem.UP)
        #expect(e.hasFlag() == true)

        let q = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .quarter))
        q.buildStem()
        q.setStemDirection(Stem.UP)
        #expect(q.hasFlag() == false)
    }

    @Test func stemmableNoteThrowingPreconditions() throws {
        let note = TestStemmableNote(NoteStruct(keys: ["c/4"], duration: .quarter))

        do {
            _ = try note.checkStemThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? StemmableNoteError == .noStem)
        }

        do {
            _ = try note.getStemDirectionThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? StemmableNoteError == .noStem)
        }

        note.buildStem()

        do {
            _ = try note.getStemDirectionThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? StemmableNoteError == .noStemDirection)
        }
    }

    @Test func staveNoteThrowingPreconditions() throws {
        let staveNote = StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)),
            duration: .quarter
        ))

        do {
            _ = try staveNote.getModifierStartXYThrowing(position: .left, index: 0)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveNoteError == .unformattedNoteForModifierStart)
        }

        staveNote.preFormatted = true

        do {
            _ = try staveNote.getModifierStartXYThrowing(position: .left, index: 0)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveNoteError == .noYValues)
        }

        _ = staveNote.setYs([100])
        do {
            _ = try staveNote.getModifierStartXYThrowing(position: .left, index: 2)
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveNoteError == .invalidModifierIndex(2))
        }

        staveNote.preFormatted = false
        do {
            _ = try staveNote.getBoundingBoxThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? StaveNoteError == .unformattedNoteForBoundingBox)
        }
    }
}

// MARK: - Test Helpers

/// Concrete subclass of Note for testing (Note is abstract in intent).
private class TestNote: Note {
    override class var category: String { "TestNote" }
}

/// Concrete subclass of StemmableNote for testing.
private class TestStemmableNote: StemmableNote {
    override class var category: String { "TestStemmableNote" }
    override func hasStem() -> Bool { glyphProps?.stem ?? false }
}
