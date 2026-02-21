import Testing
@testable import VexFoundation

@Suite("Music, KeyManager, Tuning Parity")
struct MusicKeyManagerTuningParityTests {

    private func expectThrows(_ body: () throws -> Void) {
        do {
            try body()
            #expect(Bool(false))
        } catch {
            #expect(Bool(true))
        }
    }

    private func checkStandardTuning(_ tuning: Tuning) throws {
        expectThrows { _ = try tuning.getValueForStringThrowing(0) }
        expectThrows { _ = try tuning.getValueForStringThrowing(9) }

        #expect(try tuning.getValueForStringThrowing(6) == 40) // low E
        #expect(try tuning.getValueForStringThrowing(5) == 45) // A
        #expect(try tuning.getValueForStringThrowing(4) == 50) // D
        #expect(try tuning.getValueForStringThrowing(3) == 55) // G
        #expect(try tuning.getValueForStringThrowing(2) == 59) // B
        #expect(try tuning.getValueForStringThrowing(1) == 64) // high E
    }

    private func checkStandardBanjoTuning(_ tuning: Tuning) throws {
        expectThrows { _ = try tuning.getValueForStringThrowing(0) }
        expectThrows { _ = try tuning.getValueForStringThrowing(6) }

        #expect(try tuning.getValueForStringThrowing(5) == 67) // high G
        #expect(try tuning.getValueForStringThrowing(4) == 50) // D
        #expect(try tuning.getValueForStringThrowing(3) == 55) // G
        #expect(try tuning.getValueForStringThrowing(2) == 59) // B
        #expect(try tuning.getValueForStringThrowing(1) == 62) // high D
    }

    @Test func musicCategoryValidNotesAndKeys() throws {
        let music = Music()

        var parts = try music.getNoteParts("c")
        #expect(parts.root == "c")
        #expect(parts.accidental == nil)

        parts = try music.getNoteParts("C")
        #expect(parts.root == "c")
        #expect(parts.accidental == nil)

        parts = try music.getNoteParts("c#")
        #expect(parts.root == "c")
        #expect(parts.accidental == "#")

        parts = try music.getNoteParts("c##")
        #expect(parts.root == "c")
        #expect(parts.accidental == "##")

        expectThrows { _ = try music.getNoteParts("r") }
        expectThrows { _ = try music.getNoteParts("") }

        var keyParts = try music.getKeyParts("c")
        #expect(keyParts.root == "c")
        #expect(keyParts.accidental == nil)
        #expect(keyParts.type == "M")

        keyParts = try music.getKeyParts("d#")
        #expect(keyParts.root == "d")
        #expect(keyParts.accidental == "#")
        #expect(keyParts.type == "M")

        keyParts = try music.getKeyParts("fbm")
        #expect(keyParts.root == "f")
        #expect(keyParts.accidental == "b")
        #expect(keyParts.type == "m")

        keyParts = try music.getKeyParts("c#mel")
        #expect(keyParts.root == "c")
        #expect(keyParts.accidental == "#")
        #expect(keyParts.type == "mel")

        keyParts = try music.getKeyParts("g#harm")
        #expect(keyParts.root == "g")
        #expect(keyParts.accidental == "#")
        #expect(keyParts.type == "harm")

        expectThrows { _ = try music.getKeyParts("r") }
        expectThrows { _ = try music.getKeyParts("") }
        expectThrows { _ = try music.getKeyParts("#m") }
    }

    @Test func musicCategoryValuesAndCanonicals() throws {
        let music = Music()

        #expect(try music.getNoteValue("c") == 0)
        #expect(try music.getNoteValue("f#") == 6)
        expectThrows { _ = try music.getNoteValue("r") }

        #expect(try music.getIntervalValue("b2") == 1)
        expectThrows { _ = try music.getIntervalValue("7") }

        #expect(try music.getCanonicalNoteName(0) == "c")
        #expect(try music.getCanonicalNoteName(2) == "d")
        expectThrows { _ = try music.getCanonicalNoteName(-1) }

        #expect(try music.getCanonicalIntervalName(0) == "unison")
        #expect(try music.getCanonicalIntervalName(2) == "M2")
        expectThrows { _ = try music.getCanonicalIntervalName(-1) }
    }

    @Test func musicCategoryRelativeNotesAndNames() throws {
        let music = Music()

        let c = try music.getNoteValue("c")
        let d = try music.getNoteValue("d")
        let g = try music.getNoteValue("g")
        let b = try music.getNoteValue("b")
        let b5 = try music.getIntervalValue("b5")
        let b2 = try music.getIntervalValue("b2")

        #expect(try music.getRelativeNoteValue(c, intervalValue: b5) == 6)
        #expect(try music.getRelativeNoteValue(d, intervalValue: try music.getIntervalValue("2"), direction: -1) == 0)
        #expect(try music.getRelativeNoteValue(b, intervalValue: b5) == 5)
        #expect(try music.getRelativeNoteValue(c, intervalValue: b2, direction: -1) == 11)
        #expect(try music.getRelativeNoteValue(g, intervalValue: try music.getIntervalValue("p5")) == 2)

        expectThrows { _ = try music.getRelativeNoteValue(b, intervalValue: try music.getIntervalValue("p4"), direction: 0) }

        #expect(try music.getRelativeNoteName("b", noteValue: try music.getNoteValue("c#")) == "b##")
        #expect(try music.getRelativeNoteName("c", noteValue: try music.getNoteValue("c")) == "c")
        #expect(try music.getRelativeNoteName("c", noteValue: try music.getNoteValue("db")) == "c#")
        #expect(try music.getRelativeNoteName("c", noteValue: try music.getNoteValue("b")) == "cb")
        #expect(try music.getRelativeNoteName("c#", noteValue: try music.getNoteValue("db")) == "c#")
        #expect(try music.getRelativeNoteName("e", noteValue: try music.getNoteValue("f#")) == "e##")
        #expect(try music.getRelativeNoteName("e", noteValue: try music.getNoteValue("d#")) == "eb")
        #expect(try music.getRelativeNoteName("e", noteValue: try music.getNoteValue("fb")) == "e")
        expectThrows { _ = try music.getRelativeNoteName("e", noteValue: try music.getNoteValue("g#")) }
    }

    @Test func musicCategoryScalesAndIntervals() throws {
        let music = Music()
        let manager = try KeyManager(parsing: "CM")

        let cMajor = music.getScaleTones(try music.getNoteValue("c"), intervals: Music.scales["major"]!)
        let cMajorNames = try cMajor.map { try music.getCanonicalNoteName($0) }
        #expect(cMajorNames == ["c", "d", "e", "f", "g", "a", "b"])

        let cDorian = music.getScaleTones(try music.getNoteValue("c"), intervals: Music.scales["dorian"]!)
        let cDorianNames = try cDorian.map { try manager.selectNote(parsing: try music.getCanonicalNoteName($0)).note }
        #expect(cDorianNames == ["c", "d", "eb", "f", "g", "a", "bb"])

        let cMixolydian = music.getScaleTones(try music.getNoteValue("c"), intervals: Music.scales["mixolydian"]!)
        let cMixolydianNames = try cMixolydian.map { try manager.selectNote(parsing: try music.getCanonicalNoteName($0)).note }
        #expect(cMixolydianNames == ["c", "d", "e", "f", "g", "a", "bb"])

        let cToD = try music.getIntervalBetween(try music.getNoteValue("c"), try music.getNoteValue("d"))
        let gToC = try music.getIntervalBetween(try music.getNoteValue("g"), try music.getNoteValue("c"))
        let cToC = try music.getIntervalBetween(try music.getNoteValue("c"), try music.getNoteValue("c"))
        let fToCb = try music.getIntervalBetween(try music.getNoteValue("f"), try music.getNoteValue("cb"))
        let dToCForward = try music.getIntervalBetween(try music.getNoteValue("d"), try music.getNoteValue("c"), direction: 1)
        let dToCBackward = try music.getIntervalBetween(try music.getNoteValue("d"), try music.getNoteValue("c"), direction: -1)

        #expect(try music.getCanonicalIntervalName(cToD) == "M2")
        #expect(try music.getCanonicalIntervalName(gToC) == "p4")
        #expect(try music.getCanonicalIntervalName(cToC) == "unison")
        #expect(try music.getCanonicalIntervalName(fToCb) == "dim5")
        #expect(try music.getCanonicalIntervalName(dToCForward) == "b7")
        #expect(try music.getCanonicalIntervalName(dToCBackward) == "M2")
    }

    @Test func keyManagerCategoryValidNotes() throws {
        let manager = try KeyManager(parsing: "g")
        #expect(try manager.getAccidental(parsing: "f").accidental == "#")

        _ = try manager.setKey(parsing: "a")
        #expect(try manager.getAccidental(parsing: "c").accidental == "#")
        #expect(try manager.getAccidental(parsing: "a").accidental == nil)
        #expect(try manager.getAccidental(parsing: "f").accidental == "#")

        _ = try manager.setKey(parsing: "A")
        #expect(try manager.getAccidental(parsing: "c").accidental == "#")
        #expect(try manager.getAccidental(parsing: "a").accidental == nil)
        #expect(try manager.getAccidental(parsing: "f").accidental == "#")
    }

    @Test func keyManagerCategorySelectNotes() throws {
        let manager = try KeyManager(parsing: "f")
        #expect(try manager.selectNote(parsing: "bb").note == "bb")
        #expect(try manager.selectNote(parsing: "bb").accidental == "b")
        #expect(try manager.selectNote(parsing: "g").note == "g")
        #expect(try manager.selectNote(parsing: "g").accidental == nil)
        #expect(try manager.selectNote(parsing: "b").note == "b")
        #expect(try manager.selectNote(parsing: "b").accidental == nil)
        #expect(try manager.selectNote(parsing: "a#").note == "bb")
        #expect(try manager.selectNote(parsing: "g#").note == "g#")

        #expect(try manager.selectNote(parsing: "g#").note == "g#")
        #expect(try manager.selectNote(parsing: "bb").note == "bb")

        _ = try manager.reset()
        #expect(try manager.selectNote(parsing: "g#").change == true)
        #expect(try manager.selectNote(parsing: "g#").change == false)
        #expect(try manager.selectNote(parsing: "g").change == true)
        #expect(try manager.selectNote(parsing: "g").change == false)
        #expect(try manager.selectNote(parsing: "g#").change == true)

        _ = try manager.reset()
        var note = try manager.selectNote(parsing: "bb")
        #expect(note.change == false)
        #expect(note.accidental == "b")
        note = try manager.selectNote(parsing: "g")
        #expect(note.change == false)
        #expect(note.accidental == nil)
        note = try manager.selectNote(parsing: "g#")
        #expect(note.change == true)
        #expect(note.accidental == "#")
        note = try manager.selectNote(parsing: "g")
        #expect(note.change == true)
        #expect(note.accidental == nil)
        note = try manager.selectNote(parsing: "g")
        #expect(note.change == false)
        #expect(note.accidental == nil)
        note = try manager.selectNote(parsing: "g#")
        #expect(note.change == true)
        #expect(note.accidental == "#")
    }

    @Test func tuningCategoryStandardTuning() throws {
        let tuning = Tuning()
        try checkStandardTuning(tuning)

        tuning.setTuning("standard")
        try checkStandardTuning(tuning)
    }

    @Test func tuningCategoryStandardBanjoTuning() throws {
        let tuning = Tuning()
        tuning.setTuning("standardBanjo")
        try checkStandardBanjoTuning(tuning)
    }

    @Test func tuningCategoryReturnNoteForFret() throws {
        let tuning = Tuning("E/5,B/4,G/4,D/4,A/3,E/3")
        expectThrows { _ = try tuning.getNoteForFretThrowing(-1, stringNum: 1) }
        expectThrows { _ = try tuning.getNoteForFretThrowing(1, stringNum: -1) }

        #expect(try tuning.getNoteForFretThrowing(0, stringNum: 1) == "E/5")
        #expect(try tuning.getNoteForFretThrowing(5, stringNum: 1) == "A/5")
        #expect(try tuning.getNoteForFretThrowing(0, stringNum: 2) == "B/4")
        #expect(try tuning.getNoteForFretThrowing(0, stringNum: 3) == "G/4")
        #expect(try tuning.getNoteForFretThrowing(12, stringNum: 2) == "B/5")
        #expect(try tuning.getNoteForFretThrowing(0, stringNum: 6) == "E/3")
    }
}
