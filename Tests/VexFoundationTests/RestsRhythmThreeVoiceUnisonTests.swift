// VexFoundation - Tests for Phase 2.2 parity scenarios:
// rests, rhythm/slash notes, three voices, and unison-like alignment.

import Testing
@testable import VexFoundation

@Suite("Rests, Rhythm, Three-Voice & Unison")
struct RestsRhythmThreeVoiceUnisonTests {

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

    private func makeRestAlignmentVoice() -> ([StaveNote], Voice) {
        let notes: [StaveNote] = [
            makeNote(.a, octave: 5, duration: .quarter, stem: .up),
            makeNote(.b, octave: 4, duration: .quarter, type: .rest, stem: .up),
            makeNote(.a, octave: 5, duration: .quarter, stem: .up),
            makeNote(.b, octave: 4, duration: .quarter, type: .rest, stem: .up),
        ]
        return (notes, makeVoice(notes))
    }

    private func makeUnisonVoices(
        styleMismatch: Bool = false,
        addUpperDot: Bool = false
    ) -> (upperLead: StaveNote, lowerLead: StaveNote, upperVoice: Voice, lowerVoice: Voice) {
        let upperLead = makeNote(.e, duration: .quarter, stem: .up)
        let upperNotes: [StaveNote] = [
            upperLead,
            makeNote(.e, duration: .quarter, stem: .up),
            makeNote(.e, duration: .half, stem: .up),
        ]

        let lowerLead = makeNote(.e, duration: .quarter, stem: .down)
        let lowerNotes: [StaveNote] = [
            lowerLead,
            makeNote(.e, duration: .quarter, stem: .down),
            makeNote(.e, duration: .half, stem: .down),
        ]

        if styleMismatch {
            lowerLead.setStyle(ElementStyle(fillStyle: "green", strokeStyle: "green"))
        }
        if addUpperDot {
            Dot.buildAndAttach([upperLead])
        }

        return (upperLead, lowerLead, makeVoice(upperNotes), makeVoice(lowerNotes))
    }

    @Test func dottedRestsAcrossDurationsAttachDots() throws {
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

    @Test func rhythmSlashNoteheadsCanBeamedInQuarterGroups() throws {
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

        let beams = try Beam.generateBeams(slashNotes, config: BeamConfig(groups: [Fraction(1, 4)]))

        #expect(beams.count == 4)
        #expect(beams.allSatisfy { $0.getNotes().count == 2 })
        #expect(slashNotes.allSatisfy { $0.hasBeam() })
        #expect((slashNotes[0] as! StaveNote).getNoteType() == NoteType.slash.rawValue)
        #expect((slashNotes[0] as! StaveNote).getGlyphWidth() == Tables.SLASH_NOTEHEAD_WIDTH)
    }

    @Test func rhythmSlashParserConvenienceParsesSlashDuration() throws {
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

    @Test func formatterAlignRestsOptionRepositionsUnbeamedRests() throws {
        let stave = Stave(x: 10, y: 40, width: 360)

        let (notesOff, voiceOff) = makeRestAlignmentVoice()
        let initialOff = [notesOff[1].getKeyLine(0), notesOff[3].getKeyLine(0)]
        let formatterOff = Formatter()
        _ = formatterOff.joinVoices([voiceOff])
        _ = formatterOff.formatToStave([voiceOff], stave: stave, options: FormatParams(alignRests: false))
        let afterOff = [notesOff[1].getKeyLine(0), notesOff[3].getKeyLine(0)]
        #expect(afterOff == initialOff)

        let (notesOn, voiceOn) = makeRestAlignmentVoice()
        let initialOn = [notesOn[1].getKeyLine(0), notesOn[3].getKeyLine(0)]
        let formatterOn = Formatter()
        _ = formatterOn.joinVoices([voiceOn])
        _ = formatterOn.formatToStave([voiceOn], stave: stave, options: FormatParams(alignRests: true))
        let afterOn = [notesOn[1].getKeyLine(0), notesOn[3].getKeyLine(0)]

        #expect(afterOn != initialOn)
        let expectedRestLine = notesOn[0].getLineForRest()
        #expect(afterOn[0] == expectedRestLine)
        #expect(afterOn[1] == expectedRestLine)
    }

    @Test func formatterAlignsBeamedRestsWhenAlignRestsDisabled() throws {
        let stave = Stave(x: 10, y: 40, width: 360)

        let n1 = makeNote(.a, octave: 5, duration: .eighth, stem: .up)
        let r1 = makeNote(.b, octave: 4, duration: .eighth, type: .rest, stem: .up)
        let n2 = makeNote(.a, octave: 5, duration: .eighth, stem: .up)
        let r2 = makeNote(.b, octave: 4, duration: .eighth, type: .rest, stem: .up)
        let notes: [StemmableNote] = [n1, r1, n2, r2]

        let initial = [r1.getKeyLine(0), r2.getKeyLine(0)]
        let beam = try Beam(notes)
        let voice = makeVoice(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.formatToStave([voice], stave: stave, options: FormatParams(alignRests: false))
        let after = [r1.getKeyLine(0), r2.getKeyLine(0)]

        #expect(after != initial)
        let expectedRestLine = n1.getLineForRest()
        #expect(after[0] == expectedRestLine)
        #expect(after[1] == expectedRestLine)
        _ = beam // keep strong reference for weak note.beam links
    }

    @Test func alignRestsSkipsTupletRestsUnlessExplicitlyEnabled() throws {
        let n1 = makeNote(.a, octave: 5, duration: .eighth, stem: .up)
        let rest = makeNote(.b, octave: 4, duration: .eighth, type: .rest, stem: .up)
        let n3 = makeNote(.a, octave: 5, duration: .eighth, stem: .up)
        let notes: [Note] = [n1, rest, n3]

        _ = try Tuplet(notes: notes)
        let initial = rest.getKeyLine(0)

        Formatter.AlignRestsToNotes(notes.map { $0 as Tickable }, alignAllNotes: true)
        #expect(rest.getKeyLine(0) == initial)

        Formatter.AlignRestsToNotes(notes.map { $0 as Tickable }, alignAllNotes: true, alignTuplets: true)
        let aligned = rest.getKeyLine(0)
        #expect(aligned != initial)
        #expect(aligned == n1.getLineForRest())
    }

    @Test func threeVoiceFormattingSharesTickContexts() throws {
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

        let beams = try Beam.applyAndGetBeams(voice2, stemDirection: .down)

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

    @Test func unisonLikeVoicesProduceExpectedTickGrid() throws {
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

    @Test func unisonToggleControlsHorizontalShiftForSameLineVoices() throws {
        Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            FontLoader.loadDefaultFonts()

            let stave = Stave(x: 10, y: 40, width: 420)

            Tables.UNISON = true
            do {
                let (_, lower, upperVoice, lowerVoice) = makeUnisonVoices()
                let formatter = Formatter()
                _ = formatter.joinVoices([upperVoice, lowerVoice])
                _ = formatter.formatToStave([upperVoice, lowerVoice], stave: stave)
                #expect(lower.getXShift() == 0)
            }

            Tables.UNISON = false
            do {
                let (_, lower, upperVoice, lowerVoice) = makeUnisonVoices()
                let formatter = Formatter()
                _ = formatter.joinVoices([upperVoice, lowerVoice])
                _ = formatter.formatToStave([upperVoice, lowerVoice], stave: stave)
                #expect(lower.getXShift() > 0)
            }
        }
    }

    @Test func unisonModeStillShiftsForStyleOrDotDifferences() throws {
        Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            FontLoader.loadDefaultFonts()
            Tables.UNISON = true

            let stave = Stave(x: 10, y: 40, width: 420)

            do {
                let (_, lower, upperVoice, lowerVoice) = makeUnisonVoices(styleMismatch: true)
                let formatter = Formatter()
                _ = formatter.joinVoices([upperVoice, lowerVoice])
                _ = formatter.formatToStave([upperVoice, lowerVoice], stave: stave)
                #expect(lower.getXShift() > 0)
            }

            do {
                let (_, lower, upperVoice, lowerVoice) = makeUnisonVoices(addUpperDot: true)
                let formatter = Formatter()
                _ = formatter.joinVoices([upperVoice, lowerVoice])
                _ = formatter.formatToStave([upperVoice, lowerVoice], stave: stave)
                #expect(lower.getXShift() > 0)
            }
        }
    }

    @Test func twoVoiceSameDurationRestsHideLowerRest() throws {
        let upperRests: [StaveNote] = [
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
        ]
        let lowerRests: [StaveNote] = [
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
        ]

        let upperVoice = makeVoice(upperRests)
        let lowerVoice = makeVoice(lowerRests)
        let formatter = Formatter()
        _ = formatter.joinVoices([upperVoice, lowerVoice])
        _ = formatter.formatToStave([upperVoice, lowerVoice], stave: Stave(x: 10, y: 40, width: 420))

        #expect(upperRests[0].renderOptions.draw)
        #expect(!lowerRests[0].renderOptions.draw)
    }

    @Test func threeVoiceAllRestsHideOuterVoicesAtCollisionTicks() throws {
        let upperRests: [StaveNote] = [
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
            makeNote(.b, duration: .quarter, type: .rest, stem: .up),
        ]
        let middleRests: [StaveNote] = [
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
        ]
        let lowerRests: [StaveNote] = [
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
            makeNote(.b, duration: .quarter, type: .rest, stem: .down),
        ]

        let upperVoice = makeVoice(upperRests)
        let middleVoice = makeVoice(middleRests)
        let lowerVoice = makeVoice(lowerRests)

        let formatter = Formatter()
        _ = formatter.joinVoices([upperVoice, middleVoice, lowerVoice])
        _ = formatter.formatToStave([upperVoice, middleVoice, lowerVoice], stave: Stave(x: 10, y: 40, width: 420))

        #expect(!upperRests[0].renderOptions.draw)
        #expect(middleRests[0].renderOptions.draw)
        #expect(!lowerRests[0].renderOptions.draw)
    }
}
