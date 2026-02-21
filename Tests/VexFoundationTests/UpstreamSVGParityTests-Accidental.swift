import Foundation
import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Accidental.Basic")
    func accidentalBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Basic", width: 700, height: 240) { _, context in
            let stave = Stave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)

            let notes = try makeAccidentalBasicNotes(stemDown: false)
            prepareSimpleFormattedAccidentalNotes(notes, stave: stave, x: 10, paddingBetween: 45)
            notes.forEach { drawUpstreamAccidentalNoteMetrics(context: context, note: $0, yPos: 140) }
            try stave.draw()
            try drawPreparedAccidentalNotes(notes, context: context)
            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 480, y: 140)
        }
    }

    @Test("Accidental.Stem_Down")
    func accidentalStemDownMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Stem_Down", width: 700, height: 240) { _, context in
            let stave = Stave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)

            let notes = try makeAccidentalBasicStemDownNotes()
            prepareSimpleFormattedAccidentalNotes(notes, stave: stave, x: 0, paddingBetween: 30)
            notes.forEach { drawUpstreamAccidentalNoteMetrics(context: context, note: $0, yPos: 140) }
            try stave.draw()
            try drawPreparedAccidentalNotes(notes, context: context)
            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 480, y: 140)
        }
    }

    @Test("Accidental.Accidental_Arrangement_Special_Cases")
    func accidentalArrangementSpecialCasesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Accidental_Arrangement_Special_Cases",
            width: 700,
            height: 240
        ) { _, context in
            let stave = Stave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)

            let notes = try makeAccidentalSpecialCaseNotes()
            prepareSimpleFormattedAccidentalNotes(notes, stave: stave, x: 0, paddingBetween: 20)
            notes.forEach { drawUpstreamAccidentalNoteMetrics(context: context, note: $0, yPos: 140) }
            try stave.draw()
            try drawPreparedAccidentalNotes(notes, context: context)
            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 480, y: 140)
        }
    }

    @Test("Accidental.Cautionary_Accidental")
    func accidentalCautionaryMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Cautionary_Accidental", width: 850, height: 2110) { _, context in
            let staveCount = 12
            let scale = 0.85
            let staveWidth = 840.0
            context.scale(scale, scale)

            let accids = upstreamCautionaryAccidentalTypes()
            let mod = max(1, Int((Double(accids.count) / Double(staveCount)).rounded()))

            for row in 0..<staveCount {
                let stave = Stave(x: 0, y: 10 + 200 * Double(row), width: staveWidth / scale)
                _ = stave.setContext(context)
                try stave.draw()

                var rowMap: [String] = []
                var index = 0
                while index < mod && index + row * staveCount < accids.count {
                    rowMap.append(accids[index + row * staveCount])
                    index += 1
                }
                guard !rowMap.isEmpty else { continue }

                let notes = try rowMap.map { accidental in
                    try StaveNote(validating: StaveNoteStruct(
                        parsingKeys: ["a/4"],
                        duration: "4",
                        stemDirection: .up
                    ))
                    .addModifier(try makeUpstreamAccidental(accidental).setAsCautionary(), index: 0)
                }

                let voice = Voice(time: VoiceTime(numBeats: rowMap.count, beatValue: 4))
                    .addTickables(notes.map { $0 as Tickable })

                _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                try voice.draw(context: context, stave: stave)
            }
        }
    }

    @Test("Accidental.Multi_Voice")
    func accidentalMultiVoiceMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Multi_Voice", width: 460, height: 250) { _, context in
            let stave = Stave(x: 10, y: 45, width: 420)
            _ = stave.setContext(context)
            try stave.draw()

            var note1 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "2", stemDirection: .down))
            _ = note1.addModifier(try makeUpstreamAccidental("b"), index: 0)
            _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 1)
            _ = note1.addModifier(try makeUpstreamAccidental("#"), index: 2)
            _ = note1.setStave(stave)

            var note2 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/5", "a/5", "b/5"], duration: "2", stemDirection: .up))
            _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 0)
            _ = note2.addModifier(try makeUpstreamAccidental("bb"), index: 1)
            _ = note2.addModifier(try makeUpstreamAccidental("##"), index: 2)
            _ = note2.setStave(stave)
            try drawUpstreamAccidentalVoicePair(note1: note1, note2: note2, context: context, x: 60)

            note1 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "c/5"], duration: "2", stemDirection: .down))
            _ = note1.addModifier(try makeUpstreamAccidental("b"), index: 0)
            _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 1)
            _ = note1.addModifier(try makeUpstreamAccidental("#"), index: 2)
            _ = note1.setStave(stave)

            note2 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/5", "a/5", "b/5"], duration: "4", stemDirection: .up))
            _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 0)
            _ = note2.setStave(stave)
            try drawUpstreamAccidentalVoicePair(note1: note1, note2: note2, context: context, x: 150)

            note1 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4", "c/5", "d/5"], duration: "2", stemDirection: .down))
            _ = note1.addModifier(try makeUpstreamAccidental("b"), index: 0)
            _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 1)
            _ = note1.addModifier(try makeUpstreamAccidental("#"), index: 2)
            _ = note1.setStave(stave)

            note2 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/5", "a/5", "b/5"], duration: "4", stemDirection: .up))
            _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 0)
            _ = note2.setStave(stave)
            try drawUpstreamAccidentalVoicePair(note1: note1, note2: note2, context: context, x: 250)

            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 350, y: 150)
        }
    }

    @Test("Accidental.Microtonal")
    func accidentalMicrotonalMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Microtonal", width: 700, height: 240) { _, context in
            let stave = Stave(x: 10, y: 10, width: 650)
            _ = stave.setContext(context)

            let notes = try makeAccidentalMicrotonalNotes()
            prepareSimpleFormattedAccidentalNotes(notes, stave: stave, x: 0, paddingBetween: 35)
            notes.forEach { drawUpstreamAccidentalNoteMetrics(context: context, note: $0, yPos: 140) }
            try stave.draw()
            try drawPreparedAccidentalNotes(notes, context: context)
            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 580, y: 140)
        }
    }

    @Test("Accidental.Microtonal__Iranian_")
    func accidentalMicrotonalIranianMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Microtonal__Iranian_", width: 700, height: 240) { _, context in
            let stave = Stave(x: 10, y: 10, width: 650)
            _ = stave.setContext(context)

            let notes = try makeAccidentalMicrotonalIranianNotes()
            prepareSimpleFormattedAccidentalNotes(notes, stave: stave, x: 0, paddingBetween: 35)
            notes.forEach { drawUpstreamAccidentalNoteMetrics(context: context, note: $0, yPos: 140) }
            try stave.draw()
            try drawPreparedAccidentalNotes(notes, context: context)
            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 580, y: 140)
        }
    }

    @Test("Accidental.Factory_API")
    func accidentalFactoryAPIMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Factory_API", width: 700, height: 240) { factory, _ in
            _ = factory.Stave(x: 10, y: 10, width: 550)

            let note0 = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "w"))
            _ = note0.addModifier(try factory.Accidental(parsing: "b"), index: 0)
            _ = note0.addModifier(try factory.Accidental(parsing: "#"), index: 1)

            let note1 = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4", "a/4", "c/5", "e/5", "g/5"], duration: "h"))
            _ = note1.addModifier(try factory.Accidental(parsing: "##"), index: 0)
            _ = note1.addModifier(try factory.Accidental(parsing: "n"), index: 1)
            _ = note1.addModifier(try factory.Accidental(parsing: "bb"), index: 2)
            _ = note1.addModifier(try factory.Accidental(parsing: "b"), index: 3)
            _ = note1.addModifier(try factory.Accidental(parsing: "#"), index: 4)
            _ = note1.addModifier(try factory.Accidental(parsing: "n"), index: 5)
            _ = note1.addModifier(try factory.Accidental(parsing: "bb"), index: 6)

            let note2 = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4", "c/5", "e/5", "g/5"], duration: "16"))
            _ = note2.addModifier(try factory.Accidental(parsing: "n"), index: 0)
            _ = note2.addModifier(try factory.Accidental(parsing: "#"), index: 1)
            _ = note2.addModifier(try factory.Accidental(parsing: "#"), index: 2)
            _ = note2.addModifier(try factory.Accidental(parsing: "b"), index: 3)
            _ = note2.addModifier(try factory.Accidental(parsing: "bb"), index: 4)
            _ = note2.addModifier(try factory.Accidental(parsing: "##"), index: 5)
            _ = note2.addModifier(try factory.Accidental(parsing: "#"), index: 6)

            let note3 = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/3", "c/4", "e/4", "b/4", "d/5", "g/5"], duration: "w"))
            _ = note3.addModifier(try factory.Accidental(parsing: "#"), index: 0)
            _ = note3.addModifier(try factory.Accidental(parsing: "##").setAsCautionary(), index: 1)
            _ = note3.addModifier(try factory.Accidental(parsing: "#").setAsCautionary(), index: 2)
            _ = note3.addModifier(try factory.Accidental(parsing: "b"), index: 3)
            _ = note3.addModifier(try factory.Accidental(parsing: "bb").setAsCautionary(), index: 4)
            _ = note3.addModifier(try factory.Accidental(parsing: "b").setAsCautionary(), index: 5)

            Formatter.SimpleFormat([note0, note1, note2, note3].map { $0 as Tickable })
            try factory.draw()
        }
    }

    @Test("Accidental.Accidental_Padding")
    func accidentalPaddingMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Accidental_Padding", width: 750, height: 280) { _, context in
            let notes: [StaveNote] = [
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e##/5"], duration: "8d"))
                    .addModifier(try makeUpstreamAccidental("##"), index: 0),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["b/4"], duration: "16"))
                    .addModifier(try makeUpstreamAccidental("b"), index: 0),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/3"], duration: "8")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/3"], duration: "16")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "g/4"], duration: "16"))
                    .addModifier(try makeUpstreamAccidental("bb"), index: 0)
                    .addModifier(try makeUpstreamAccidental("bb"), index: 1),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "16")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "g/4"], duration: "16"))
                    .addModifier(try makeUpstreamAccidental("#"), index: 0)
                    .addModifier(try makeUpstreamAccidental("#"), index: 1),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "32")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/4"], duration: "32")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "16")),
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "q")),
            ]

            Dot.buildAndAttach([notes[0]], all: true)
            let beams = try Beam.generateBeams(notes.map { $0 as StemmableNote })

            let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
                .addTickables(notes.map { $0 as Tickable })

            let formatter = Formatter(options: FormatterOptions(softmaxFactor: 100)).joinVoices([voice])
            let width = formatter.preCalculateMinTotalWidth([voice])

            let stave = Stave(x: 10, y: 40, width: width + 20)
            _ = stave.setContext(context)
            try stave.draw()

            _ = formatter.format([voice], justifyWidth: width)
            try voice.draw(context: context, stave: stave)

            for beam in beams {
                _ = beam.setContext(context)
                try beam.draw()
            }

            notes.forEach { drawUpstreamAccidentalNoteMetrics(context: context, note: $0, yPos: 30) }
            drawUpstreamAccidentalNoteWidthLegend(context: context, x: 300, y: 150)
        }
    }

    @Test("Accidental.Automatic_Accidentals")
    func accidentalAutomaticAccidentalsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Accidental", test: "Automatic_Accidentals", width: 700, height: 200) { factory, _ in
            let stave = factory.Stave()

            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4", "c/5"], duration: "4"),
                .init(keys: ["c#/4", "c#/5"], duration: "4"),
                .init(keys: ["c#/4", "c#/5"], duration: "4"),
                .init(keys: ["c##/4", "c##/5"], duration: "4"),
                .init(keys: ["c##/4", "c##/5"], duration: "4"),
                .init(keys: ["c/4", "c/5"], duration: "4"),
                .init(keys: ["cn/4", "cn/5"], duration: "4"),
                .init(keys: ["cbb/4", "cbb/5"], duration: "4"),
                .init(keys: ["cbb/4", "cbb/5"], duration: "4"),
                .init(keys: ["cb/4", "cb/5"], duration: "4"),
                .init(keys: ["cb/4", "cb/5"], duration: "4"),
                .init(keys: ["c/4", "c/5"], duration: "4"),
            ])

            let grace = try factory.GraceNote(GraceNoteStruct(parsingKeys: ["d#/4"], duration: "16", slash: true))
            _ = notes[0].addModifier(factory.GraceNoteGroup(notes: [grace]).beamNotes(), index: 0)

            let voice = factory.Voice().setMode(.soft)
            _ = voice.addTickable(factory.TimeSigNote(time: .meter(12, 4)).setStave(stave))
            _ = voice.addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "C")
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___C_major_scale_in_Ab")
    func accidentalAutomaticAccidentalsCMajorScaleInAbMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___C_major_scale_in_Ab",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("Ab")
            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4"),
                .init(keys: ["d/4"], duration: "4"),
                .init(keys: ["e/4"], duration: "4"),
                .init(keys: ["f/4"], duration: "4"),
                .init(keys: ["g/4"], duration: "4"),
                .init(keys: ["a/4"], duration: "4"),
                .init(keys: ["b/4"], duration: "4"),
                .init(keys: ["c/5"], duration: "4"),
            ])
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "Ab")
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___No_Accidentals_Necessary")
    func accidentalAutomaticAccidentalsNoAccidentalsNecessaryMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___No_Accidentals_Necessary",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("A")
            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["a/4"], duration: "4"),
                .init(keys: ["b/4"], duration: "4"),
                .init(keys: ["c#/5"], duration: "4"),
                .init(keys: ["d/5"], duration: "4"),
                .init(keys: ["e/5"], duration: "4"),
                .init(keys: ["f#/5"], duration: "4"),
                .init(keys: ["g#/5"], duration: "4"),
                .init(keys: ["a/5"], duration: "4"),
            ])
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "A")
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___No_Accidentals_Necessary__EasyScore_")
    func accidentalAutomaticAccidentalsNoAccidentalsNecessaryEasyScoreMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___No_Accidentals_Necessary__EasyScore_",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("A")
            let score = factory.EasyScore()
            _ = score.set(defaults: EasyScoreDefaults(time: .meter(8, 4)))
            let notes = score.notes(
                "A4/q, B4/q, C#5/q, D5/q, E5/q,F#5/q, G#5/q, A5/q",
                options: ["stem": "up"]
            )
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "A")
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___Multi_Voice_Inline")
    func accidentalAutomaticAccidentalsMultiVoiceInlineMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___Multi_Voice_Inline",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("Ab")
            let notes0 = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["d/4"], duration: "4", stemDirection: .down),
                .init(keys: ["e/4"], duration: "4", stemDirection: .down),
                .init(keys: ["f/4"], duration: "4", stemDirection: .down),
                .init(keys: ["g/4"], duration: "4", stemDirection: .down),
                .init(keys: ["a/4"], duration: "4", stemDirection: .down),
                .init(keys: ["b/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
            ])
            let notes1 = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/5"], duration: "4"),
                .init(keys: ["d/5"], duration: "4"),
                .init(keys: ["e/5"], duration: "4"),
                .init(keys: ["f/5"], duration: "4"),
                .init(keys: ["g/5"], duration: "4"),
                .init(keys: ["a/5"], duration: "4"),
                .init(keys: ["b/5"], duration: "4"),
                .init(keys: ["c/6"], duration: "4"),
            ])
            let voice0 = factory.Voice().setMode(.soft).addTickables(notes0.map { $0 as Tickable })
            let voice1 = factory.Voice().setMode(.soft).addTickables(notes1.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice0, voice1], keySignature: "Ab")

            expectAccidentalPresence(notes0, expected: [false, true, true, false, false, true, true, false])
            expectAccidentalPresence(notes1, expected: [false, true, true, false, false, true, true, false])

            _ = factory.Formatter().joinVoices([voice0, voice1]).formatToStave([voice0, voice1], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___Multi_Voice_Offset")
    func accidentalAutomaticAccidentalsMultiVoiceOffsetMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___Multi_Voice_Offset",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("Cb")
            let notes0 = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["d/4"], duration: "4", stemDirection: .down),
                .init(keys: ["e/4"], duration: "4", stemDirection: .down),
                .init(keys: ["f/4"], duration: "4", stemDirection: .down),
                .init(keys: ["g/4"], duration: "4", stemDirection: .down),
                .init(keys: ["a/4"], duration: "4", stemDirection: .down),
                .init(keys: ["b/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
            ])
            let notes1 = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/5"], duration: "8"),
                .init(keys: ["c/5"], duration: "4"),
                .init(keys: ["d/5"], duration: "4"),
                .init(keys: ["e/5"], duration: "4"),
                .init(keys: ["f/5"], duration: "4"),
                .init(keys: ["g/5"], duration: "4"),
                .init(keys: ["a/5"], duration: "4"),
                .init(keys: ["b/5"], duration: "4"),
                .init(keys: ["c/6"], duration: "4"),
            ])
            let voice0 = factory.Voice().setMode(.soft).addTickables(notes0.map { $0 as Tickable })
            let voice1 = factory.Voice().setMode(.soft).addTickables(notes1.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice0, voice1], keySignature: "Cb")

            expectAccidentalPresence(notes0, expected: [true, true, true, true, true, true, true, false])
            expectAccidentalPresence(notes1, expected: [true, false, true, true, true, true, true, true, true])

            _ = factory.Formatter().joinVoices([voice0, voice1]).formatToStave([voice0, voice1], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___Key_C__Single_Octave")
    func accidentalAutomaticAccidentalsKeyCSingleOctaveMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___Key_C__Single_Octave",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("C")
            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
            ])
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "C")
            expectAccidentalPresence(notes, expected: [false, true, false, true, false, true, false, true, false])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___Key_C__Two_Octaves")
    func accidentalAutomaticAccidentalsKeyCTwoOctavesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___Key_C__Two_Octaves",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("C")
            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/5"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
            ])
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "C")
            expectAccidentalPresence(
                notes,
                expected: [
                    false, false,
                    true, true,
                    false, false,
                    true, true,
                    false, false,
                    true, true,
                    false, false,
                    true, true,
                    false, false,
                ]
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___Key_C___Single_Octave")
    func accidentalAutomaticAccidentalsKeyCSharpSingleOctaveMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___Key_C___Single_Octave",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("C#")
            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
            ])
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "C#")
            expectAccidentalPresence(notes, expected: [true, true, false, true, false, true, false, true, false])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Accidental.Automatic_Accidentals___Key_C___Two_Octaves")
    func accidentalAutomaticAccidentalsKeyCSharpTwoOctavesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Accidental",
            test: "Automatic_Accidentals___Key_C___Two_Octaves",
            width: 700,
            height: 150
        ) { factory, _ in
            let stave = factory.Stave().addKeySignature("C#")
            let notes = try makeAutomaticAccidentalNotes(factory: factory, specs: [
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c#/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/5"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/4"], duration: "4", stemDirection: .down),
                .init(keys: ["cb/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
                .init(keys: ["c/4"], duration: "4", stemDirection: .down),
                .init(keys: ["c/5"], duration: "4", stemDirection: .down),
            ])
            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })

            try Accidental.applyAccidentals([voice], keySignature: "C#")
            expectAccidentalPresence(
                notes,
                expected: [
                    true, true,
                    true, true,
                    false, false,
                    true, true,
                    false, false,
                    true, true,
                    false, false,
                    true, true,
                    false, false,
                ]
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    private func makeAccidentalBasicNotes(stemDown: Bool) throws -> [StaveNote] {
        let stem: StemDirection = stemDown ? .down : .up

        let note0 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["c/4", "e/4", "a/4"],
            duration: "1",
            stemDirection: stemDown ? stem : nil
        ))
        _ = note0.addModifier(try makeUpstreamAccidental("b"), index: 0)
        _ = note0.addModifier(try makeUpstreamAccidental("#"), index: 1)

        let note1 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["e/4", "f/4", "a/4", "c/5", "e/5", "g/5", "d/4"],
            duration: "2",
            stemDirection: stemDown ? stem : nil
        ))
        _ = note1.addModifier(try makeUpstreamAccidental("##"), index: 6)
        _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 0)
        _ = note1.addModifier(try makeUpstreamAccidental("bb"), index: 1)
        _ = note1.addModifier(try makeUpstreamAccidental("b"), index: 2)
        _ = note1.addModifier(try makeUpstreamAccidental("#"), index: 3)
        _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 4)
        _ = note1.addModifier(try makeUpstreamAccidental("bb"), index: 5)

        let note2 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["g/5", "f/4", "g/4", "a/4", "b/4", "c/5", "e/5"],
            duration: "16",
            stemDirection: stemDown ? stem : nil
        ))
        _ = note2.addModifier(try makeUpstreamAccidental("n"), index: 1)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 2)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 3)
        _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 4)
        _ = note2.addModifier(try makeUpstreamAccidental("bb"), index: 5)
        _ = note2.addModifier(try makeUpstreamAccidental("##"), index: 6)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 0)

        let note3 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["a/3", "c/4", "e/4", "b/4", "d/5", "g/5"],
            duration: "1",
            stemDirection: stemDown ? stem : nil
        ))
        _ = note3.addModifier(try makeUpstreamAccidental("#"), index: 0)
        _ = note3.addModifier(try makeUpstreamAccidental("##").setAsCautionary(), index: 1)
        _ = note3.addModifier(try makeUpstreamAccidental("#").setAsCautionary(), index: 2)
        _ = note3.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note3.addModifier(try makeUpstreamAccidental("bb").setAsCautionary(), index: 4)
        _ = note3.addModifier(try makeUpstreamAccidental("b").setAsCautionary(), index: 5)

        return [note0, note1, note2, note3]
    }

    private func makeAccidentalBasicStemDownNotes() throws -> [StaveNote] {
        let note0 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["c/4", "e/4", "a/4"],
            duration: "w",
            stemDirection: .down
        ))
        _ = note0.addModifier(try makeUpstreamAccidental("b"), index: 0)
        _ = note0.addModifier(try makeUpstreamAccidental("#"), index: 1)

        let note1 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["d/4", "e/4", "f/4", "a/4", "c/5", "e/5", "g/5"],
            duration: "2",
            stemDirection: .down
        ))
        _ = note1.addModifier(try makeUpstreamAccidental("##"), index: 0)
        _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 1)
        _ = note1.addModifier(try makeUpstreamAccidental("bb"), index: 2)
        _ = note1.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note1.addModifier(try makeUpstreamAccidental("#"), index: 4)
        _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 5)
        _ = note1.addModifier(try makeUpstreamAccidental("bb"), index: 6)

        let note2 = try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["f/4", "g/4", "a/4", "b/4", "c/5", "e/5", "g/5"],
            duration: "16",
            stemDirection: .down
        ))
        _ = note2.addModifier(try makeUpstreamAccidental("n"), index: 0)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 1)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 2)
        _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note2.addModifier(try makeUpstreamAccidental("bb"), index: 4)
        _ = note2.addModifier(try makeUpstreamAccidental("##"), index: 5)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 6)

        return [note0, note1, note2]
    }

    private func makeAccidentalSpecialCaseNotes() throws -> [StaveNote] {
        let note0 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "d/5"], duration: "1"))
        _ = note0.addModifier(try makeUpstreamAccidental("#"), index: 0)
        _ = note0.addModifier(try makeUpstreamAccidental("b"), index: 1)

        let note1 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "g/4"], duration: "2"))
        _ = note1.addModifier(try makeUpstreamAccidental("##"), index: 0)
        _ = note1.addModifier(try makeUpstreamAccidental("##"), index: 1)

        let note2 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["b/3", "d/4", "f/4"], duration: "16"))
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 0)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 1)
        _ = note2.addModifier(try makeUpstreamAccidental("##"), index: 2)

        let note3 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4", "a/4", "c/5", "e/5"], duration: "16"))
        _ = note3.addModifier(try makeUpstreamAccidental("b"), index: 0)
        _ = note3.addModifier(try makeUpstreamAccidental("b"), index: 1)
        _ = note3.addModifier(try makeUpstreamAccidental("n"), index: 3)

        let note4 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "g/4", "b/4", "c/5"], duration: "4"))
        _ = note4.addModifier(try makeUpstreamAccidental("b").setAsCautionary(), index: 0)
        _ = note4.addModifier(try makeUpstreamAccidental("b").setAsCautionary(), index: 1)
        _ = note4.addModifier(try makeUpstreamAccidental("bb"), index: 2)
        _ = note4.addModifier(try makeUpstreamAccidental("b"), index: 3)

        let note5 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["b/3", "e/4", "a/4", "d/5", "g/5"], duration: "8"))
        _ = note5.addModifier(try makeUpstreamAccidental("bb"), index: 0)
        _ = note5.addModifier(try makeUpstreamAccidental("b").setAsCautionary(), index: 1)
        _ = note5.addModifier(try makeUpstreamAccidental("n").setAsCautionary(), index: 2)
        _ = note5.addModifier(try makeUpstreamAccidental("#"), index: 3)
        _ = note5.addModifier(try makeUpstreamAccidental("n").setAsCautionary(), index: 4)

        return [note0, note1, note2, note3, note4, note5]
    }

    private func makeAccidentalMicrotonalNotes() throws -> [StaveNote] {
        let note0 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "1"))
        _ = note0.addModifier(try makeUpstreamAccidental("db"), index: 0)
        _ = note0.addModifier(try makeUpstreamAccidental("d"), index: 1)

        let note1 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4", "a/4", "c/5", "e/5", "g/5"], duration: "2"))
        _ = note1.addModifier(try makeUpstreamAccidental("bbs"), index: 0)
        _ = note1.addModifier(try makeUpstreamAccidental("++"), index: 1)
        _ = note1.addModifier(try makeUpstreamAccidental("+"), index: 2)
        _ = note1.addModifier(try makeUpstreamAccidental("d"), index: 3)
        _ = note1.addModifier(try makeUpstreamAccidental("db"), index: 4)
        _ = note1.addModifier(try makeUpstreamAccidental("+"), index: 5)
        _ = note1.addModifier(try makeUpstreamAccidental("##"), index: 6)

        let note2 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4", "c/5", "e/5", "g/5"], duration: "16"))
        _ = note2.addModifier(try makeUpstreamAccidental("++"), index: 0)
        _ = note2.addModifier(try makeUpstreamAccidental("bbs"), index: 1)
        _ = note2.addModifier(try makeUpstreamAccidental("+"), index: 2)
        _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note2.addModifier(try makeUpstreamAccidental("db"), index: 4)
        _ = note2.addModifier(try makeUpstreamAccidental("##"), index: 5)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 6)

        let note3 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/3", "c/4", "e/4", "b/4", "d/5", "g/5"], duration: "1"))
        _ = note3.addModifier(try makeUpstreamAccidental("#"), index: 0)
        _ = note3.addModifier(try makeUpstreamAccidental("db").setAsCautionary(), index: 1)
        _ = note3.addModifier(try makeUpstreamAccidental("bbs").setAsCautionary(), index: 2)
        _ = note3.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note3.addModifier(try makeUpstreamAccidental("++").setAsCautionary(), index: 4)
        _ = note3.addModifier(try makeUpstreamAccidental("d").setAsCautionary(), index: 5)

        let note4 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4", "d/5", "g/5"], duration: "16"))
        _ = note4.addModifier(try makeUpstreamAccidental("++-"), index: 0)
        _ = note4.addModifier(try makeUpstreamAccidental("+-"), index: 1)
        _ = note4.addModifier(try makeUpstreamAccidental("bs"), index: 2)
        _ = note4.addModifier(try makeUpstreamAccidental("bss"), index: 3)
        _ = note4.addModifier(try makeUpstreamAccidental("afhf"), index: 4)
        _ = note4.addModifier(try makeUpstreamAccidental("ashs"), index: 5)

        return [note0, note1, note2, note3, note4]
    }

    private func makeAccidentalMicrotonalIranianNotes() throws -> [StaveNote] {
        let note0 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "1"))
        _ = note0.addModifier(try makeUpstreamAccidental("k"), index: 0)
        _ = note0.addModifier(try makeUpstreamAccidental("o"), index: 1)

        let note1 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4", "a/4", "c/5", "e/5", "g/5"], duration: "2"))
        _ = note1.addModifier(try makeUpstreamAccidental("b"), index: 0)
        _ = note1.addModifier(try makeUpstreamAccidental("k"), index: 1)
        _ = note1.addModifier(try makeUpstreamAccidental("n"), index: 2)
        _ = note1.addModifier(try makeUpstreamAccidental("o"), index: 3)
        _ = note1.addModifier(try makeUpstreamAccidental("#"), index: 4)
        _ = note1.addModifier(try makeUpstreamAccidental("bb"), index: 5)
        _ = note1.addModifier(try makeUpstreamAccidental("##"), index: 6)

        let note2 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4", "c/5", "e/5", "g/5"], duration: "16"))
        _ = note2.addModifier(try makeUpstreamAccidental("o"), index: 0)
        _ = note2.addModifier(try makeUpstreamAccidental("k"), index: 1)
        _ = note2.addModifier(try makeUpstreamAccidental("n"), index: 2)
        _ = note2.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note2.addModifier(try makeUpstreamAccidental("bb"), index: 4)
        _ = note2.addModifier(try makeUpstreamAccidental("##"), index: 5)
        _ = note2.addModifier(try makeUpstreamAccidental("#"), index: 6)

        let note3 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/3", "c/4", "e/4", "b/4", "d/5", "g/5"], duration: "1"))
        _ = note3.addModifier(try makeUpstreamAccidental("#"), index: 0)
        _ = note3.addModifier(try makeUpstreamAccidental("o").setAsCautionary(), index: 1)
        _ = note3.addModifier(try makeUpstreamAccidental("n").setAsCautionary(), index: 2)
        _ = note3.addModifier(try makeUpstreamAccidental("b"), index: 3)
        _ = note3.addModifier(try makeUpstreamAccidental("k").setAsCautionary(), index: 4)

        let note4 = try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4"], duration: "16"))
        _ = note4.addModifier(try makeUpstreamAccidental("k"), index: 0)
        _ = note4.addModifier(try makeUpstreamAccidental("k"), index: 1)
        _ = note4.addModifier(try makeUpstreamAccidental("k"), index: 2)
        _ = note4.addModifier(try makeUpstreamAccidental("k"), index: 3)

        return [note0, note1, note2, note3, note4]
    }

    private struct AutomaticAccidentalNoteSpec {
        var keys: [String]
        var duration: String
        var stemDirection: StemDirection? = nil
    }

    private func makeAutomaticAccidentalNotes(
        factory: Factory,
        specs: [AutomaticAccidentalNoteSpec]
    ) throws -> [StaveNote] {
        try specs.map { spec in
            try factory.StaveNote(StaveNoteStruct(
                parsingKeys: spec.keys,
                duration: spec.duration,
                stemDirection: spec.stemDirection
            ))
        }
    }

    private func hasAccidental(_ note: StaveNote) -> Bool {
        note.getModifiers().contains { $0 is Accidental }
    }

    private func expectAccidentalPresence(_ notes: [StaveNote], expected: [Bool]) {
        #expect(notes.count == expected.count)
        for index in notes.indices {
            #expect(hasAccidental(notes[index]) == expected[index])
        }
    }

    private func upstreamCautionaryAccidentalTypes() -> [String] {
        let fallback = ["#", "##", "b", "bb", "n", "db", "d", "++", "+", "+-", "bs", "bss", "o", "k", "bbs", "++-", "ashs", "afhf"]
        let sourcePath = "../vexflow/src/tables.ts"
        guard let source = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            return fallback
        }

        guard let keyRegex = try? NSRegularExpression(
            pattern: #"^\s*(?:'([^']+)'|([A-Za-z0-9_]+)):\s*\{"#,
            options: []
        ) else {
            return fallback
        }

        var inAccidentals = false
        var keys: [String] = []

        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if !inAccidentals {
                if line.contains("const accidentals:") {
                    inAccidentals = true
                }
                continue
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "};" {
                break
            }

            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = keyRegex.firstMatch(in: line, options: [], range: nsRange) else { continue }

            if let quotedRange = Range(match.range(at: 1), in: line) {
                keys.append(String(line[quotedRange]))
            } else if let bareRange = Range(match.range(at: 2), in: line) {
                keys.append(String(line[bareRange]))
            }
        }

        let filtered = keys.filter { $0 != "{" && $0 != "}" }
        return filtered.isEmpty ? fallback : filtered
    }

    private func prepareSimpleFormattedAccidentalNotes(
        _ notes: [StaveNote],
        stave: Stave,
        x: Double,
        paddingBetween: Double
    ) {
        for note in notes {
            _ = note.setStave(stave)
        }
        Formatter.SimpleFormat(notes.map { $0 as Tickable }, x: x, paddingBetween: paddingBetween)
    }

    private func drawPreparedAccidentalNotes(_ notes: [StaveNote], context: SVGRenderContext) throws {
        for note in notes {
            _ = note.setContext(context)
            try note.draw()
        }
    }

    private func makeUpstreamAccidental(_ type: String) throws -> Accidental {
        try Accidental(parsing: type)
    }

    private func drawUpstreamAccidentalVoicePair(
        note1: StaveNote,
        note2: StaveNote,
        context: SVGRenderContext,
        x: Double
    ) throws {
        let modifierContext = ModifierContext()
        _ = note1.addToModifierContext(modifierContext)
        _ = note2.addToModifierContext(modifierContext)
        _ = TickContext().addTickable(note1).addTickable(note2).preFormat().setX(x)
        _ = note1.setContext(context)
        _ = note2.setContext(context)
        try note1.draw()
        try note2.draw()

        drawUpstreamAccidentalNoteMetrics(context: context, note: note1, yPos: 180)
        drawUpstreamAccidentalNoteMetrics(context: context, note: note2, yPos: 15)
    }

    private func drawUpstreamAccidentalNoteMetrics(context: SVGRenderContext, note: Note, yPos: Double) {
        let metrics = note.getMetrics()
        let xStart = note.getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let xPre1 = note.getAbsoluteX() - metrics.leftDisplacedHeadPx
        let xAbs = note.getAbsoluteX()
        let xPost1 = note.getAbsoluteX() + metrics.notePx
        let xPost2 = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx
        let xEnd = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx + metrics.modRightPx
        let xFreedomRight = xEnd + note.getFormatterMetrics().freedom.right
        let xWidth = xEnd - xStart

        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))
        _ = context.fillText("\(Int(xWidth.rounded()))px", xStart + note.getXShift(), yPos)

        let y = yPos + 7
        func stroke(_ x1: Double, _ x2: Double, _ color: String, _ yy: Double = y) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(3)
            _ = context.moveTo(x1 + note.getXShift(), yy)
            _ = context.lineTo(x2 + note.getXShift(), yy)
            _ = context.stroke()
        }

        stroke(xStart, xPre1, "red")
        stroke(xPre1, xAbs, "#999")
        stroke(xAbs, xPost1, "green")
        stroke(xPost1, xPost2, "#999")
        stroke(xPost2, xEnd, "red")
        stroke(xEnd, xFreedomRight, "#DD0")
        stroke(xStart - note.getXShift(), xStart, "#BBB")
        drawUpstreamAccidentalDot(context: context, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let spaceDeviation = formatterMetrics.space.deviation
            let prefix = spaceDeviation >= 0 ? "+" : ""
            _ = context.setFillStyle("red")
            _ = context.fillText("\(prefix)\(Int(spaceDeviation.rounded()))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = context.restore()
    }

    private func drawUpstreamAccidentalDot(context: SVGRenderContext, x: Double, y: Double, color: String = "#F55") {
        _ = context.save()
        _ = context.setFillStyle(color)
        _ = context.beginPath()
        _ = context.arc(x, y, 3, 0, Double.pi * 2, false)
        _ = context.closePath()
        _ = context.fill()
        _ = context.restore()
    }

    private func drawUpstreamAccidentalNoteWidthLegend(context: SVGRenderContext, x: Double, y: Double) {
        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))
        let spacing = 12.0
        var lastY = y

        func legend(_ color: String, _ text: String) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(10)
            _ = context.moveTo(x, lastY - 4)
            _ = context.lineTo(x + 10, lastY - 4)
            _ = context.stroke()
            _ = context.setFillStyle("black")
            _ = context.fillText(text, x + 15, lastY)
            lastY += spacing
        }

        legend("green", "Note + Flag")
        legend("red", "Modifiers")
        legend("#999", "Displaced Head")
        legend("#DDD", "Formatter Shift")
        _ = context.restore()
    }
}
