// VexFoundation - Tests for Phase 6: StaveNote, Dot, ModifierContext, Formatter

import Testing
@testable import VexFoundation

@Suite("StaveNote System")
struct StaveNoteTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // MARK: - StaveNote Creation

    @Test func staveNoteCreation() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        #expect(note.getDuration() == "4")
        #expect(note.getNoteType() == "n")
        #expect(note.getKeys().count == 1)
        #expect(note.keyProps.count == 1)
        #expect(note.noteHeads.count == 1)
        #expect(note.hasStem())
    }

    @Test func staveNoteRest() {
        let note = StaveNote(StaveNoteStruct(keys: ["b/4"], duration: "4", type: "r"))
        #expect(note.isRest())
        #expect(!note.hasStem() || note.stem?.hide == true)
        #expect(note.glyphProps.rest)
    }

    @Test func staveNoteChord() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "e/4", "g/4"], duration: "4"))
        #expect(note.isChord())
        #expect(note.getKeys().count == 3)
        #expect(note.keyProps.count == 3)
        #expect(note.noteHeads.count == 3)
    }

    @Test func staveNoteWhole() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "1"))
        #expect(!note.hasStem())
        #expect(!note.hasFlag())
    }

    @Test func staveNoteEighth() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "8"))
        #expect(note.hasStem())
        #expect(note.hasFlag())
        #expect(note.getBeamCount() == 1)
    }

    @Test func staveNoteSixteenth() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "16"))
        #expect(note.hasStem())
        #expect(note.hasFlag())
        #expect(note.getBeamCount() == 2)
    }

    // MARK: - Auto Stem

    @Test func autoStemUp() {
        // Notes below middle line -> stem up
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4", autoStem: true))
        #expect(note.getStemDirection() == Stem.UP)
    }

    @Test func autoStemDown() {
        // Notes above middle line -> stem down
        let note = StaveNote(StaveNoteStruct(keys: ["a/5"], duration: "4", autoStem: true))
        #expect(note.getStemDirection() == Stem.DOWN)
    }

    @Test func autoStemChord() {
        // Chord spanning middle: average determines direction
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "a/5"], duration: "4", autoStem: true))
        // Average of c/4 (line ~0) and a/5 (line ~5) should be around middle
        let dir = note.getStemDirection()
        #expect(dir == Stem.UP || dir == Stem.DOWN)
    }

    @Test func stemDirectionDefault() {
        // Default is stem up
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        #expect(note.getStemDirection() == Stem.UP)
    }

    @Test func stemDirectionExplicit() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4", stemDirection: Stem.DOWN))
        #expect(note.getStemDirection() == Stem.DOWN)
    }

    // MARK: - Key Properties

    @Test func keyPropsCalculation() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "e/4", "g/4"], duration: "4", clef: "treble"))
        #expect(note.keyProps.count == 3)
        #expect(note.sortedKeyProps.count == 3)
        // Sorted by line (ascending)
        #expect(note.sortedKeyProps[0].keyProps.line <= note.sortedKeyProps[1].keyProps.line)
        #expect(note.sortedKeyProps[1].keyProps.line <= note.sortedKeyProps[2].keyProps.line)
    }

    @Test func displacementDetection() {
        // E/4 and F/4 are 0.5 lines apart -> displaced
        let note = StaveNote(StaveNoteStruct(keys: ["e/4", "f/4"], duration: "4"))
        #expect(note.displaced)
    }

    @Test func noDisplacement() {
        // C/4 and E/4 are well separated -> no displacement
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "e/4"], duration: "4"))
        #expect(!note.displaced)
    }

    // MARK: - Line Numbers

    @Test func lineNumber() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "g/4"], duration: "4", clef: "treble"))
        let bottom = note.getLineNumber(isTopNote: false)
        let top = note.getLineNumber(isTopNote: true)
        #expect(top >= bottom)
    }

    // MARK: - NoteHead Bounds

    @Test func noteHeadBoundsOnStave() {
        let stave = Stave(x: 0, y: 0, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "e/4", "g/4"], duration: "4"))
        _ = note.setStave(stave)
        let bounds = note.getNoteHeadBounds()
        #expect(bounds.yTop < bounds.yBottom || bounds.yTop == bounds.yBottom)
        #expect(bounds.highestLine >= bounds.lowestLine)
    }

    // MARK: - Stem X / Note Head X

    @Test func noteHeadBeginX() {
        let stave = Stave(x: 10, y: 0, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        _ = note.setStave(stave)
        Formatter.SimpleFormat([note], x: 0)
        let x = note.getNoteHeadBeginX()
        #expect(x > 0)
    }

    // MARK: - PreFormat

    @Test func preFormatWidth() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        Formatter.SimpleFormat([note])
        #expect(note.preFormatted)
        let width = note.getTickableWidth()
        #expect(width > 0)
    }

    // MARK: - Voice Shift Width

    @Test func voiceShiftWidth() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        Formatter.SimpleFormat([note])
        let vsw = note.getVoiceShiftWidth()
        #expect(vsw > 0)
    }

    // MARK: - Is Chord / Is Rest

    @Test func isChordCheck() {
        let single = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        let chord = StaveNote(StaveNoteStruct(keys: ["c/4", "e/4"], duration: "4"))
        let rest = StaveNote(StaveNoteStruct(keys: ["b/4"], duration: "4", type: "r"))
        #expect(!single.isChord())
        #expect(chord.isChord())
        #expect(!rest.isChord())
    }

    // MARK: - Key Line

    @Test func keyLine() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4", clef: "treble"))
        let line = note.getKeyLine(0)
        // c/4 in treble clef is below the staff
        #expect(line < 5)
    }

    @Test func setKeyLine() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        let originalLine = note.getKeyLine(0)
        _ = note.setKeyLine(0, line: originalLine + 1)
        #expect(note.getKeyLine(0) == originalLine + 1)
    }

    // MARK: - Modifier Start XY

    @Test func modifierStartXY() {
        let stave = Stave(x: 0, y: 0, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        _ = note.setStave(stave)
        Formatter.SimpleFormat([note])
        let xy = note.getModifierStartXY(position: .right, index: 0)
        #expect(xy.x > 0)
    }

    // MARK: - Dot

    @Test func dotCreation() {
        let dot = Dot()
        #expect(dot.getWidth() == 5)
        #expect(dot.radius == 2)
        #expect(dot.position == .right)
    }

    @Test func dotBuildAndAttach() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        Dot.buildAndAttach([note])
        let dots = Dot.getDots(note)
        #expect(dots.count == 1)
    }

    @Test func dotBuildAndAttachAll() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4", "e/4", "g/4"], duration: "4"))
        Dot.buildAndAttach([note], all: true)
        let dots = Dot.getDots(note)
        #expect(dots.count == 3)
    }

    @Test func dotFormat() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        Dot.buildAndAttach([note])
        Formatter.SimpleFormat([note])
        #expect(note.preFormatted)
    }

    // MARK: - ModifierContext

    @Test func modifierContextCreation() {
        let mc = ModifierContext()
        #expect(mc.getWidth() == 0)
        #expect(!mc.preFormatted)
    }

    @Test func modifierContextAddMember() {
        let mc = ModifierContext()
        let dot = Dot()
        _ = mc.addMember(dot)
        #expect(mc.getMembers("Dot").count == 1)
    }

    @Test func modifierContextPreFormat() {
        let mc = ModifierContext()
        mc.preFormat()
        #expect(mc.preFormatted)
        #expect(mc.formatted)
    }

    // MARK: - Formatter

    @Test func formatterSimpleFormat() {
        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        Formatter.SimpleFormat(notes, x: 10, paddingBetween: 15)
        // All notes should be pre-formatted and have X positions
        for note in notes {
            #expect(note.preFormatted)
        }
    }

    @Test func formatterCreateTickContexts() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        let contexts = formatter.createTickContexts([voice])
        // Should have 4 tick contexts (one per quarter note)
        #expect(contexts.list.count == 4)
        #expect(contexts.array.count == 4)
    }

    @Test func formatterJoinVoices() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        // After joining, each note should have a modifier context
        for note in notes {
            #expect(note.modifierContext != nil)
        }
    }

    @Test func formatterFormat() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 300)

        // All tick contexts should have X positions
        let contexts = formatter.getTickContexts()
        for tick in contexts.list {
            if let ctx = contexts.map[tick] {
                #expect(ctx.preFormatted)
            }
        }
    }

    @Test func formatterFormatToStave() {
        let stave = Stave(x: 10, y: 40, width: 300)
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.formatToStave([voice], stave: stave)

        // Notes should be positioned on the stave
        for note in notes {
            #expect(note.preFormatted)
            if let sn = note as? StaveNote {
                #expect(sn.getStave() != nil)
            }
        }
    }

    @Test func formatterResolutionMultiplier() {
        let voice1 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice1.setMode(.soft)
        let voice2 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice2.setMode(.soft)

        let notes1: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        let notes2: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["g/4"], duration: "2")),
            StaveNote(StaveNoteStruct(keys: ["a/4"], duration: "2")),
        ]
        _ = voice1.addTickables(notes1)
        _ = voice2.addTickables(notes2)

        let resMul = Formatter.getResolutionMultiplier([voice1, voice2])
        #expect(resMul >= 1)
    }

    @Test func formatterMinTotalWidth() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4")),
        ]
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 300)

        let mtw = formatter.getMinTotalWidth()
        #expect(mtw > 0)
    }

    // MARK: - Mixed Durations

    @Test func mixedDurations() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let notes: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "2")),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "8")),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "8")),
            StaveNote(StaveNoteStruct(keys: ["g/4"], duration: "4")),
        ]
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 400)

        let contexts = formatter.getTickContexts()
        #expect(contexts.list.count == 4)
    }

    // MARK: - Dotted Notes with Formatter

    @Test func dottedNotesFormat() {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)

        let note1 = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        Dot.buildAndAttach([note1])
        let note2 = StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "8"))
        let note3 = StaveNote(StaveNoteStruct(keys: ["g/4"], duration: "2"))

        _ = voice.addTickables([note1, note2, note3])

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 300)

        // Dotted note should have modifiers
        #expect(note1.getModifiers().count >= 1)
    }

    // MARK: - Two Voices

    @Test func twoVoicesFormat() {
        let voice1 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice1.setMode(.soft)
        let voice2 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice2.setMode(.soft)

        let notes1: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/5"], duration: "4", stemDirection: Stem.UP)),
            StaveNote(StaveNoteStruct(keys: ["d/5"], duration: "4", stemDirection: Stem.UP)),
            StaveNote(StaveNoteStruct(keys: ["e/5"], duration: "4", stemDirection: Stem.UP)),
            StaveNote(StaveNoteStruct(keys: ["f/5"], duration: "4", stemDirection: Stem.UP)),
        ]
        let notes2: [Tickable] = [
            StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4", stemDirection: Stem.DOWN)),
            StaveNote(StaveNoteStruct(keys: ["d/4"], duration: "4", stemDirection: Stem.DOWN)),
            StaveNote(StaveNoteStruct(keys: ["e/4"], duration: "4", stemDirection: Stem.DOWN)),
            StaveNote(StaveNoteStruct(keys: ["f/4"], duration: "4", stemDirection: Stem.DOWN)),
        ]
        _ = voice1.addTickables(notes1)
        _ = voice2.addTickables(notes2)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice1])
        _ = formatter.joinVoices([voice2])
        _ = formatter.format([voice1, voice2], justifyWidth: 400)

        // Both voices should share tick contexts
        let contexts = formatter.getTickContexts()
        #expect(contexts.list.count == 4)
    }

    // MARK: - Clef Variants

    @Test func bassClefNote() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/3"], duration: "4", clef: "bass"))
        #expect(note.clef == "bass")
        #expect(note.keyProps.count == 1)
    }

    @Test func altoClefNote() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4", clef: "alto"))
        #expect(note.clef == "alto")
    }

    // MARK: - Bounding Box

    @Test func boundingBox() {
        let stave = Stave(x: 0, y: 0, width: 300)
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        _ = note.setStave(stave)
        Formatter.SimpleFormat([note])
        let bb = note.getBoundingBox()
        #expect(bb != nil)
        #expect(bb!.w > 0)
        #expect(bb!.h > 0)
    }

    // MARK: - StaveNote Static Format

    @Test func staveNoteStaticFormat() {
        var state = ModifierContextState()
        // Less than 2 notes returns false
        let result = StaveNote.format([], state: &state)
        #expect(!result)

        let n1 = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        let result2 = StaveNote.format([n1], state: &state)
        #expect(!result2)
    }

    // MARK: - StaveNote PostFormat

    @Test func staveNotePostFormat() {
        let note = StaveNote(StaveNoteStruct(keys: ["c/4"], duration: "4"))
        let result = StaveNote.postFormat([note])
        #expect(result)
    }
}
