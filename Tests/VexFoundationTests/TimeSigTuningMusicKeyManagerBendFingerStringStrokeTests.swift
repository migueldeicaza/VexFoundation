// VexFoundation - Tests for Phase 13: TimeSigNote, Tuning, Music, KeyManager,
// Bend, FretHandFinger, StringNumber, Stroke

import Testing
@testable import VexFoundation

@Suite("TimeSigNote, Tuning, Music, KeyManager, Bend, FretHandFinger, StringNumber, Stroke")
struct TimeSigTuningMusicKeyManagerBendFingerStringStrokeTests {

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

    // ============================================================
    // MARK: - TimeSigNote Tests
    // ============================================================

    @Test func timeSigNoteCategory() {
        #expect(TimeSigNote.category == "TimeSigNote")
    }

    @Test func timeSigNoteCreation() {
        let tsn = TimeSigNote(timeSpec: .meter(4, 4))
        #expect(tsn.shouldIgnoreTicks() == true)
    }

    @Test func timeSigNoteWidth() {
        let tsn = TimeSigNote(timeSpec: .meter(3, 4))
        tsn.preFormat()
        #expect(tsn.getTickableWidth() > 0)
    }

    @Test func timeSigNotePreFormat() {
        let tsn = TimeSigNote(timeSpec: .meter(6, 8))
        tsn.preFormat()
        #expect(tsn.preFormatted == true)
    }

    @Test func timeSigNoteAddToModifierContext() {
        let tsn = TimeSigNote(timeSpec: .meter(4, 4))
        let mc = ModifierContext()
        _ = tsn.addToModifierContext(mc)
        // TimeSigNotes don't participate in modifier context
    }

    @Test func timeSigNoteIsNote() {
        let tsn = TimeSigNote(timeSpec: .meter(4, 4))
        #expect(tsn is Note)
    }

    // ============================================================
    // MARK: - Tuning Tests
    // ============================================================

    @Test func tuningDefaultCreation() {
        let tuning = Tuning()
        #expect(tuning.tuningValues.count == 8)
    }

    @Test func tuningStandard() {
        let tuning = Tuning("standard")
        #expect(tuning.tuningValues.count == 6)
    }

    @Test func tuningDropD() {
        let tuning = Tuning("dropd")
        #expect(tuning.tuningValues.count == 6)
    }

    @Test func tuningNoteToInteger() {
        let tuning = Tuning()
        let value = tuning.noteToInteger("C/4")
        #expect(value >= 0)
    }

    @Test func tuningGetValueForString() {
        let tuning = Tuning("standard")
        let val1 = tuning.getValueForString(1) // highest string
        let val6 = tuning.getValueForString(6) // lowest string
        #expect(val1 > val6)
    }

    @Test func tuningGetValueForFret() {
        let tuning = Tuning("standard")
        let open = tuning.getValueForString(1)
        let fret5 = tuning.getValueForFret(5, stringNum: 1)
        #expect(fret5 == open + 5)
    }

    @Test func tuningGetNoteForFret() {
        let tuning = Tuning("standard")
        let note = tuning.getNoteForFret(0, stringNum: 6) // open low E
        #expect(note.contains("/"))
    }

    @Test func tuningNamedTunings() {
        #expect(Tuning.names.count == 8)
        #expect(Tuning.names["standard"] != nil)
        #expect(Tuning.names["dagdad"] != nil)
    }

    // ============================================================
    // MARK: - Music Tests
    // ============================================================

    @Test func musicRoots() {
        #expect(Music.roots.count == 7)
        #expect(Music.roots[0] == "c")
        #expect(Music.roots[6] == "b")
    }

    @Test func musicCanonicalNotes() {
        #expect(Music.canonicalNotes.count == 12)
        #expect(Music.NUM_TONES == 12)
    }

    @Test func musicRootValues() {
        #expect(Music.rootValues.count == 7)
        #expect(Music.rootValues[0] == 0)  // C
        #expect(Music.rootValues[3] == 5)  // F
    }

    @Test func musicNoteValues() {
        #expect(Music.noteValues["c"]?.intVal == 0)
        #expect(Music.noteValues["c#"]?.intVal == 1)
        #expect(Music.noteValues["d"]?.intVal == 2)
        #expect(Music.noteValues["b"]?.intVal == 11)
    }

    @Test func musicIntervals() {
        #expect(Music.intervals["unison"] == 0)
        #expect(Music.intervals["p5"] == 7)
        #expect(Music.intervals["octave"] == 12)
    }

    @Test func musicScales() {
        #expect(Music.scales["major"]?.count == 7)
        #expect(Music.scales["minor"]?.count == 7)
        #expect(Music.scales["major"]! == [2, 2, 1, 2, 2, 2, 1])
    }

    @Test func musicGetNoteParts() throws {
        let music = Music()
        let parts = try music.getNoteParts("c#")
        #expect(parts.root == "c")
        #expect(parts.accidental == "#")
    }

    @Test func musicGetNotePartsNatural() throws {
        let music = Music()
        let parts = try music.getNoteParts("d")
        #expect(parts.root == "d")
        #expect(parts.accidental == nil)
    }

    @Test func musicGetNotePartsDoubleFlat() throws {
        let music = Music()
        let parts = try music.getNoteParts("ebb")
        #expect(parts.root == "e")
        #expect(parts.accidental == "bb")
    }

    @Test func musicGetKeyParts() throws {
        let music = Music()
        let parts = try music.getKeyParts("cm")
        #expect(parts.root == "c")
        #expect(parts.type == "m")
    }

    @Test func musicGetKeyPartsMajor() throws {
        let music = Music()
        let parts = try music.getKeyParts("g")
        #expect(parts.root == "g")
        #expect(parts.type == "M")
    }

    @Test func musicGetNoteValue() throws {
        let music = Music()
        #expect(try music.getNoteValue("c") == 0)
        #expect(try music.getNoteValue("d") == 2)
        #expect(try music.getNoteValue("b") == 11)
    }

    @Test func musicGetIntervalValue() throws {
        let music = Music()
        #expect(try music.getIntervalValue("p5") == 7)
        #expect(try music.getIntervalValue("M3") == 4)
    }

    @Test func musicGetCanonicalNoteName() throws {
        let music = Music()
        #expect(try music.getCanonicalNoteName(0) == "c")
        #expect(try music.getCanonicalNoteName(7) == "g")
    }

    @Test func musicGetCanonicalIntervalName() throws {
        let music = Music()
        #expect(try music.getCanonicalIntervalName(0) == "unison")
        #expect(try music.getCanonicalIntervalName(7) == "p5")
    }

    @Test func musicGetRelativeNoteValue() throws {
        let music = Music()
        // C + perfect 5th = G (7)
        #expect(try music.getRelativeNoteValue(0, intervalValue: 7) == 7)
        // G + perfect 5th = D (2)
        #expect(try music.getRelativeNoteValue(7, intervalValue: 7) == 2)
    }

    @Test func musicGetRelativeNoteName() throws {
        let music = Music()
        #expect(try music.getRelativeNoteName("c", noteValue: 0) == "c")
        #expect(try music.getRelativeNoteName("c", noteValue: 1) == "c#")
        #expect(try music.getRelativeNoteName("d", noteValue: 1) == "db")
    }

    @Test func musicGetScaleTones() {
        let music = Music()
        let cMajor = music.getScaleTones(0, intervals: Music.scales["major"]!)
        #expect(cMajor.count == 7)
        #expect(cMajor[0] == 0)  // C
        #expect(cMajor[1] == 2)  // D
        #expect(cMajor[2] == 4)  // E
        #expect(cMajor[3] == 5)  // F
        #expect(cMajor[4] == 7)  // G
    }

    @Test func musicGetIntervalBetween() throws {
        let music = Music()
        // C to G ascending = 7
        #expect(try music.getIntervalBetween(0, 7) == 7)
        // G to C ascending = 5
        #expect(try music.getIntervalBetween(7, 0) == 5)
    }

    @Test func musicInvalidDirectionThrows() {
        let music = Music()
        do {
            _ = try music.getRelativeNoteValue(0, intervalValue: 7, direction: 0)
            #expect(Bool(false))
        } catch {
            #expect(error is MusicError)
        }
    }

    @Test func musicCreateScaleMap() throws {
        let music = Music()
        let map = try music.createScaleMap("C")
        #expect(map["c"] == "cn")
        #expect(map["d"] == "dn")
        #expect(map["e"] == "en")
        #expect(map["f"] == "fn")
        #expect(map["g"] == "gn")
    }

    @Test func musicCreateScaleMapGMajor() throws {
        let music = Music()
        let map = try music.createScaleMap("G")
        #expect(map["f"] == "f#")
    }

    // ============================================================
    // MARK: - KeyManager Tests
    // ============================================================

    @Test func keyManagerCreation() throws {
        let km = try KeyManager(parsing: "C")
        #expect(km.getKey() == "C")
    }

    @Test func keyManagerSetKey() throws {
        let km = try KeyManager(parsing: "C")
        _ = try km.setKey(parsing: "G")
        #expect(km.getKey() == "G")
    }

    @Test func keyManagerGetAccidental() throws {
        let km = try KeyManager(parsing: "G")
        let result = try km.getAccidental(parsing: "f")
        #expect(result.note == "f#")
        #expect(result.accidental == "#")
    }

    @Test func keyManagerGetAccidentalNatural() throws {
        let km = try KeyManager(parsing: "C")
        let result = try km.getAccidental(parsing: "c")
        #expect(result.note == "c")
        #expect(result.accidental == nil)
    }

    @Test func keyManagerSelectNote() throws {
        let km = try KeyManager(parsing: "C")
        let result = try km.selectNote(parsing: "c")
        #expect(result.note == "c")
        #expect(result.change == false)
    }

    @Test func keyManagerSelectNoteAccidental() throws {
        let km = try KeyManager(parsing: "G")
        let result = try km.selectNote(parsing: "f#")
        #expect(result.change == false)
    }

    @Test func keyManagerStringConvenienceOrNil() {
        #expect(KeyManager(parsingOrNil: "invalid") == nil)
    }

    // ============================================================
    // MARK: - Bend Tests
    // ============================================================

    @Test func bendCategory() {
        #expect(Bend.category == "Bend")
    }

    @Test func bendCreation() {
        let bend = Bend("Full")
        #expect(bend.getText() == "Full")
        #expect(bend.phrase.count == 1)
        #expect(bend.phrase[0].type == Bend.UP)
    }

    @Test func bendWithRelease() {
        let bend = Bend("Full", release: true)
        #expect(bend.phrase.count == 2)
        #expect(bend.phrase[0].type == Bend.UP)
        #expect(bend.phrase[1].type == Bend.DOWN)
    }

    @Test func bendWithPhrase() {
        let phrases = [
            BendPhrase(type: Bend.UP, text: "Full"),
            BendPhrase(type: Bend.DOWN, text: ""),
            BendPhrase(type: Bend.UP, text: "Half"),
        ]
        let bend = Bend("", phrase: phrases)
        #expect(bend.phrase.count == 3)
    }

    @Test func bendSetTap() {
        let bend = Bend("Full")
        _ = bend.setTap("T")
        #expect(bend.tap == "T")
    }

    @Test func bendRenderOptions() {
        let opts = BendRenderOptions()
        #expect(opts.lineWidth == 1.5)
        #expect(opts.bendWidth == 8)
        #expect(opts.releaseWidth == 8)
    }

    @Test func bendStaticFormat() {
        let bend = Bend("Full")
        var state = ModifierContextState()
        let result = Bend.format([bend], state: &state)
        #expect(result == true)
        #expect(state.topTextLine > 0)
    }

    @Test func bendFormatEmpty() {
        var state = ModifierContextState()
        let result = Bend.format([], state: &state)
        #expect(result == false)
    }

    @Test func bendWidth() {
        let bend = Bend("Full")
        #expect(bend.getWidth() > 0)
    }

    // ============================================================
    // MARK: - FretHandFinger Tests
    // ============================================================

    @Test func fretHandFingerCategory() {
        #expect(FretHandFinger.category == "FretHandFinger")
    }

    @Test func fretHandFingerCreation() {
        let finger = FretHandFinger("1")
        #expect(finger.getFretHandFinger() == "1")
        #expect(finger.position == .left)
        #expect(finger.getWidth() == 7)
    }

    @Test func fretHandFingerSetFinger() {
        let finger = FretHandFinger("1")
        _ = finger.setFretHandFinger("3")
        #expect(finger.getFretHandFinger() == "3")
    }

    @Test func fretHandFingerSetOffsets() {
        let finger = FretHandFinger("1")
        _ = finger.setOffsetX(5)
        _ = finger.setOffsetY(10)
        #expect(finger.xOffset == 5)
        #expect(finger.yOffset == 10)
    }

    @Test func fretHandFingerStaticFormat() {
        let finger = FretHandFinger("1")
        let note = makeNote()
        _ = note.addModifier(finger, index: 0)
        var state = ModifierContextState()
        let result = FretHandFinger.format([finger], state: &state)
        #expect(result == true)
    }

    @Test func fretHandFingerFormatEmpty() {
        var state = ModifierContextState()
        let result = FretHandFinger.format([], state: &state)
        #expect(result == false)
    }

    // ============================================================
    // MARK: - StringNumber Tests
    // ============================================================

    @Test func stringNumberCategory() {
        #expect(StringNumber.category == "StringNumber")
    }

    @Test func stringNumberCreation() {
        let sn = StringNumber("1")
        #expect(sn.stringNumber == "1")
        #expect(sn.position == .above)
        #expect(sn.radius == 8)
        #expect(sn.drawCircle == true)
    }

    @Test func stringNumberSetStringNumber() {
        let sn = StringNumber("1")
        _ = sn.setStringNumber("3")
        #expect(sn.stringNumber == "3")
    }

    @Test func stringNumberSetDashed() {
        let sn = StringNumber("1")
        _ = sn.setDashed(false)
        #expect(sn.dashed == false)
    }

    @Test func stringNumberSetDrawCircle() {
        let sn = StringNumber("1")
        _ = sn.setDrawCircle(false)
        #expect(sn.drawCircle == false)
    }

    @Test func stringNumberSetLineEndType() {
        let sn = StringNumber("1")
        _ = sn.setLineEndType(.up)
        #expect(sn.leg == .up)
    }

    @Test func stringNumberSetOffsets() {
        let sn = StringNumber("1")
        _ = sn.setOffsetX(5)
        _ = sn.setOffsetY(10)
        #expect(sn.xOffset == 5)
        #expect(sn.yOffset == 10)
    }

    @Test func stringNumberSetLastNote() {
        let sn = StringNumber("1")
        let note = makeNote()
        _ = sn.setLastNote(note)
        #expect(sn.lastNote != nil)
    }

    @Test func stringNumberWidth() {
        let sn = StringNumber("1")
        // width = radius * 2 + 4 = 20
        #expect(sn.getWidth() == 20)
    }

    // ============================================================
    // MARK: - Stroke Tests
    // ============================================================

    @Test func strokeCategory() {
        #expect(Stroke.category == "Stroke")
    }

    @Test func strokeCreation() {
        let stroke = Stroke(type: .brushDown)
        #expect(stroke.strokeType == .brushDown)
        #expect(stroke.position == .left)
        #expect(stroke.allVoices == true)
    }

    @Test func strokeAllTypes() {
        let types: [StrokeType] = [.brushDown, .brushUp, .rollDown, .rollUp,
                                    .rasquedoDown, .rasquedoUp, .arpeggioDirectionless]
        for type in types {
            let stroke = Stroke(type: type)
            #expect(stroke.strokeType == type)
        }
    }

    @Test func strokeAddEndNote() {
        let stroke = Stroke(type: .brushDown)
        let note = makeNote()
        _ = stroke.addEndNote(note)
        #expect(stroke.noteEnd != nil)
    }

    @Test func strokeAllVoicesFalse() {
        let stroke = Stroke(type: .brushUp, allVoices: false)
        #expect(stroke.allVoices == false)
    }

    @Test func strokeStaticFormat() {
        let stroke = Stroke(type: .brushDown)
        let note = makeNote()
        _ = note.addModifier(stroke, index: 0)
        var state = ModifierContextState()
        let result = Stroke.format([stroke], state: &state)
        #expect(result == true)
        #expect(state.leftShift > 0)
    }

    @Test func strokeFormatEmpty() {
        var state = ModifierContextState()
        let result = Stroke.format([], state: &state)
        #expect(result == false)
    }

    @Test func strokeWidth() {
        let stroke = Stroke(type: .rollDown)
        #expect(stroke.getWidth() == 10)
    }

    // ============================================================
    // MARK: - ModifierContext Integration
    // ============================================================

    @Test func modifierContextIncludesFretHandFinger() {
        let finger = FretHandFinger("1")
        let note = makeNote()
        _ = note.addModifier(finger, index: 0)
        let mc = ModifierContext()
        _ = mc.addMember(finger)
        mc.preFormat()
    }

    @Test func modifierContextIncludesStroke() {
        let stroke = Stroke(type: .brushDown)
        let note = makeNote()
        _ = note.addModifier(stroke, index: 0)
        let mc = ModifierContext()
        _ = mc.addMember(stroke)
        mc.preFormat()
    }

    @Test func modifierContextIncludesBend() {
        let bend = Bend("Full")
        let mc = ModifierContext()
        _ = mc.addMember(bend)
        mc.preFormat()
    }

    // ============================================================
    // MARK: - Cross-class Integration
    // ============================================================

    @Test func bendIsModifier() {
        let bend = Bend("Full")
        #expect(bend is Modifier)
    }

    @Test func fretHandFingerIsModifier() {
        let finger = FretHandFinger("1")
        #expect(finger is Modifier)
    }

    @Test func stringNumberIsModifier() {
        let sn = StringNumber("1")
        #expect(sn is Modifier)
    }

    @Test func strokeIsModifier() {
        let stroke = Stroke(type: .brushDown)
        #expect(stroke is Modifier)
    }

    @Test func lineEndTypeValues() {
        #expect(LineEndType.none.rawValue == 1)
        #expect(LineEndType.up.rawValue == 2)
        #expect(LineEndType.down.rawValue == 3)
    }
}
