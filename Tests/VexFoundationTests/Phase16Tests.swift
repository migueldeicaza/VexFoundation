// VexFoundation - Tests for Phase 2.2 parity scenarios:
// rests, rhythm/slash notes, three voices, and unison-like alignment.

import Testing
@testable import VexFoundation

@Suite("Rests, Rhythm, Three-Voice & Unison")
struct Phase16Tests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeNote(
        _ letter: NoteLetter,
        octave: Int = 4,
        duration: NoteDurationSpec,
        type: NoteType = .note,
        stem: StemDirection = .up
    ) -> StaveNote {
        StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: letter, octave: octave)),
            duration: duration,
            type: type,
            stemDirection: stem
        ))
    }

    private func makeVoice(_ notes: [Tickable], time: VoiceTime = VoiceTime(numBeats: 4, beatValue: 4)) -> Voice {
        let voice = Voice(time: time)
        _ = voice.setMode(.soft)
        _ = voice.addTickables(notes)
        return voice
    }

    @Test func dottedRestsAcrossDurationsAttachDots() {
        let durations: [NoteDurationSpec] = [
            .whole, .half, .quarter, .eighth, .sixteenth, .thirtySecond, .sixtyFourth,
        ]

        let rests: [Note] = durations.map {
            makeNote(.b, duration: $0, type: .rest)
        }

        Dot.buildAndAttach(rests)

        for rest in rests {
            #expect(rest.isRest())
            #expect(Dot.getDots(rest).count == 1)
        }
    }

    @Test func rhythmSlashNoteheadsCanBeamedInQuarterGroups() {
        let slashNotes: [StemmableNote] = [
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
            makeNote(.b, duration: .eighth, type: .slash, stem: .down),
        ]

        let beams = Beam.generateBeams(slashNotes, config: BeamConfig(groups: [Fraction(1, 4)]))

        #expect(beams.count == 4)
        #expect(beams.allSatisfy { $0.getNotes().count == 2 })
        #expect(slashNotes.allSatisfy { $0.hasBeam() })
        #expect((slashNotes[0] as! StaveNote).getNoteType() == NoteType.slash.rawValue)
        #expect((slashNotes[0] as! StaveNote).getGlyphWidth() == Tables.SLASH_NOTEHEAD_WIDTH)
    }

    @Test func rhythmSlashParserConvenienceParsesSlashDuration() {
        let parsed = StaveNoteStruct(
            parsingKeysOrNil: ["b/4"],
            duration: "8s"
        )

        #expect(parsed != nil)
        #expect(parsed?.duration.value == .eighth)
        #expect(parsed?.duration.type == .slash)
        if let parsed {
            let note = StaveNote(parsed)
            #expect(note.getDuration() == "8")
            #expect(note.getNoteType() == NoteType.slash.rawValue)
            #expect(note.getGlyphWidth() == Tables.SLASH_NOTEHEAD_WIDTH)
            #expect(note.noteHeads.first?.getWidth() == Tables.SLASH_NOTEHEAD_WIDTH)
        }
    }

    @Test func threeVoiceFormattingSharesTickContexts() {
        let stave = Stave(x: 10, y: 40, width: 520)

        let voice1 = makeVoice([
            makeNote(.e, octave: 5, duration: .half, stem: .up),
            makeNote(.e, octave: 5, duration: .half, stem: .up),
        ])

        let voice2Notes: [StemmableNote] = [
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
            makeNote(.d, octave: 4, duration: .eighth, stem: .down),
        ]
        let voice2 = makeVoice(voice2Notes)

        let voice3 = makeVoice([
            makeNote(.b, octave: 3, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, octave: 3, duration: .quarter, stem: .down),
            makeNote(.b, octave: 3, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, octave: 3, duration: .quarter, stem: .down),
        ])

        let beams = Beam.applyAndGetBeams(voice2, stemDirection: .down)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice1, voice2, voice3])
        _ = formatter.formatToStave(
            [voice1, voice2, voice3],
            stave: stave,
            options: FormatParams(alignRests: true)
        )

        let halfTicks = Tables.durationToTicks("2") ?? 8192

        #expect(voice1.isComplete())
        #expect(voice2.isComplete())
        #expect(voice3.isComplete())
        #expect(beams.count == 4)
        #expect(formatter.getTickContext(0)?.getTickables().count == 3)
        #expect(formatter.getTickContext(halfTicks)?.getTickables().count == 3)
    }

    @Test func unisonLikeVoicesProduceExpectedTickGrid() {
        let voice1 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice1.setMode(.soft)
        _ = voice1.addTickables([
            makeNote(.e, duration: .quarter, stem: .up),
            makeNote(.e, duration: .quarter, stem: .up),
            makeNote(.e, duration: .half, stem: .up),
        ])

        let voice2 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice2.setMode(.soft)
        _ = voice2.addTickables([
            makeNote(.e, duration: .eighth, stem: .down),
            makeNote(.e, duration: .eighth, stem: .down),
            makeNote(.e, duration: .quarter, stem: .down),
            makeNote(.e, duration: .half, stem: .down),
        ])

        let formatter = Formatter()
        let contexts = formatter.createTickContexts([voice1, voice2])

        let eighthTicks = Tables.durationToTicks("8") ?? 2048
        let quarterTicks = Tables.durationToTicks("4") ?? 4096
        let halfTicks = Tables.durationToTicks("2") ?? 8192

        #expect(contexts.list == [0, eighthTicks, quarterTicks, halfTicks])
        #expect(contexts.map[0]?.getTickables().count == 2)
        #expect(contexts.map[quarterTicks]?.getTickables().count == 2)
        #expect(contexts.map[halfTicks]?.getTickables().count == 2)
    }
}
