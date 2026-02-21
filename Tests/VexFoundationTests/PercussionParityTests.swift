// VexFoundation - Tests for Phase 2.3 parity scenarios:
// percussion clef, percussion noteheads, and percussion-key parsing compatibility.

import Testing
@testable import VexFoundation

@Suite("Percussion")
struct PercussionParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makePercussionNote(
        key: String,
        duration: String,
        stem: StemDirection = .up
    ) -> StaveNote? {
        guard let parsed = StaveNoteStruct(
            parsingKeysOrNil: [key],
            duration: duration,
            stemDirection: stem
        ) else { return nil }
        return StaveNote(parsed)
    }

    private func makeVoice(_ notes: [Tickable], time: VoiceTime = VoiceTime(numBeats: 4, beatValue: 4)) -> Voice {
        let voice = Voice(time: time)
        _ = voice.setMode(.soft)
        _ = voice.addTickables(notes)
        return voice
    }

    @Test func percussionClefUsesUnpitchedGlyph() throws {
        let clef = Clef(type: .percussion)
        #expect(clef.clefDef.code == "unpitchedPercussionClef1")
        #expect(clef.clefDef.line == 2)
    }

    @Test func staffKeyParserAcceptsXSlashShorthand() throws {
        let parsed = StaffKeySpec(parsingOrNil: "x/")
        #expect(parsed != nil)
        #expect(parsed?.octave == 4)
        #expect(parsed?.rawValue == "x/4")
    }

    @Test func staveNoteParserAcceptsXSlashShorthand() throws {
        let parsed = StaveNoteStruct(parsingKeysOrNil: ["x/"], duration: "1")
        #expect(parsed != nil)
        #expect(parsed?.keys.array.first?.rawValue == "x/4")

        if let parsed {
            let note = StaveNote(parsed)
            #expect(note.getKeys().first == "x/4")
            #expect(note.getKeyProps().first?.key == "X")
            #expect(note.noteHeads.first?.glyphCode == "noteheadXBlack")
        }
    }

    @Test func percussionCustomNoteheadsResolveExpectedGlyphCodes() throws {
        let cases: [(key: String, duration: String, expected: String)] = [
            ("g/5/d0", "4", "noteheadDiamondWhole"),
            ("g/5/d1", "4", "noteheadDiamondHalf"),
            ("g/5/d2", "4", "noteheadDiamondBlack"),
            ("g/5/d3", "4", "noteheadDiamondBlack"),
            ("g/5/t0", "1", "noteheadTriangleUpWhole"),
            ("g/5/t1", "4", "noteheadTriangleUpHalf"),
            ("g/5/t2", "4", "noteheadTriangleUpBlack"),
            ("g/5/t3", "4", "noteheadTriangleUpBlack"),
            ("g/5/x0", "1", "noteheadXWhole"),
            ("g/5/x1", "4", "noteheadXHalf"),
            ("g/5/x2", "4", "noteheadXBlack"),
            ("g/5/x3", "4", "noteheadCircleX"),
        ]

        for c in cases {
            let note = makePercussionNote(key: c.key, duration: c.duration)
            #expect(note != nil)
            #expect(note?.noteHeads.first?.glyphCode == c.expected)
        }
    }

    @Test func abstractCustomGlyphUsesActualDuration() throws {
        let wholeDiamond = makePercussionNote(key: "g/5/d", duration: "1")
        let quarterDiamond = makePercussionNote(key: "g/5/d", duration: "4")
        #expect(wholeDiamond != nil)
        #expect(quarterDiamond != nil)
        #expect(wholeDiamond?.noteHeads.first?.glyphCode == "noteheadDiamondWhole")
        #expect(quarterDiamond?.noteHeads.first?.glyphCode == "noteheadDiamondBlack")

        let wholeX = makePercussionNote(key: "g/5/x", duration: "1")
        let quarterX = makePercussionNote(key: "g/5/x", duration: "4")
        #expect(wholeX?.noteHeads.first?.glyphCode == "noteheadXWhole")
        #expect(quarterX?.noteHeads.first?.glyphCode == "noteheadXBlack")
    }

    @Test func percussionTwoVoiceFormattingAndBeamingBaseline() throws {
        let voice0Notes: [StemmableNote] = [
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
            makePercussionNote(key: "g/5/x2", duration: "8", stem: .up),
        ].compactMap { $0 }
        #expect(voice0Notes.count == 8)
        guard voice0Notes.count == 8 else { return }

        let voice0 = makeVoice(voice0Notes)

        let voice1Notes: [StemmableNote] = [
            makePercussionNote(key: "f/4", duration: "8", stem: .down),
            makePercussionNote(key: "f/4", duration: "8", stem: .down),
            makePercussionNote(key: "d/4/x2", duration: "4", stem: .down),
            makePercussionNote(key: "f/4", duration: "8", stem: .down),
            makePercussionNote(key: "f/4", duration: "8", stem: .down),
            makePercussionNote(key: "d/4/x2", duration: "4", stem: .down),
        ].compactMap { $0 }
        #expect(voice1Notes.count == 6)
        guard voice1Notes.count == 6 else { return }

        let voice1 = makeVoice(voice1Notes)

        let beams0 = try Beam.generateBeams(voice0Notes, config: BeamConfig(groups: [Fraction(1, 4)]))
        let beams1 = try Beam.generateBeams(Array(voice1Notes[0...1]), config: BeamConfig(groups: [Fraction(1, 4)]))

        let stave = Stave(x: 10, y: 40, width: 420)
        _ = stave.addClef(.percussion)
        let formatter = Formatter()
        _ = formatter.joinVoices([voice0, voice1])
        _ = formatter.formatToStave([voice0, voice1], stave: stave)

        #expect(voice0.isComplete())
        #expect(voice1.isComplete())
        #expect(beams0.count == 4)
        #expect(beams1.count == 1)
        #expect(formatter.getTickContext(0)?.getTickables().count == 2)
    }
}
