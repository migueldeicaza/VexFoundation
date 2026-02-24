import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Three_Voice_Rests.Three_Voices____1")
    func threeVoiceRestsThreeVoices1MatchesUpstream() throws {
        try runThreeVoiceRestsCase(
            test: "Three_Voices____1",
            noteGroup1: ("e5/2, e5", ["stem": "up"]),
            noteGroup2: ("(d4 a4 d#5)/8, b4, (d4 a4 c5), b4, (d4 a4 c5), b4, (d4 a4 c5), b4", ["stem": "down"]),
            noteGroup3: ("b3/4, e3, f3, a3", ["stem": "down"]),
            setup: { factory, noteGroups in
                _ = noteGroups[0][0].addModifier(factory.Fingering(number: "0", position: .left), index: 0)
                _ = noteGroups[1][0]
                    .addModifier(factory.Fingering(number: "0", position: .left), index: 0)
                    .addModifier(factory.Fingering(number: "4", position: .left), index: 1)
            }
        )
    }

    @Test("Three_Voice_Rests.Three_Voices____2_Complex")
    func threeVoiceRestsThreeVoices2ComplexMatchesUpstream() throws {
        try runThreeVoiceRestsCase(
            test: "Three_Voices____2_Complex",
            noteGroup1: ("(a4 e5)/16, e5, e5, e5, e5/8, e5, e5/2", ["stem": "up"]),
            noteGroup2: ("(d4 d#5)/16, (b4 c5), d5, e5, (d4 a4 c5)/8, b4, (d4 a4 c5), b4, (d4 a4 c5), b4", ["stem": "down"]),
            noteGroup3: ("b3/8, b3, e3/4, f3, a3", ["stem": "down"]),
            setup: { factory, noteGroups in
                _ = noteGroups[0][0]
                    .addModifier(factory.Fingering(number: "2", position: .left), index: 0)
                    .addModifier(factory.Fingering(number: "0", position: .above), index: 1)
                _ = noteGroups[1][0]
                    .addModifier(factory.Fingering(number: "0", position: .left), index: 0)
                    .addModifier(factory.Fingering(number: "4", position: .left), index: 1)
            }
        )
    }

    @Test("Three_Voice_Rests.Three_Voices____3")
    func threeVoiceRestsThreeVoices3MatchesUpstream() throws {
        try runThreeVoiceRestsCase(
            test: "Three_Voices____3",
            noteGroup1: ("(g4 e5)/4, e5, (g4 e5)/2", ["stem": "up"]),
            noteGroup2: ("c#5/4, b4/8, b4/8/r, a4/4., g4/8", ["stem": "down"]),
            noteGroup3: ("c4/4, b3, a3, g3", ["stem": "down"]),
            setup: { factory, noteGroups in
                _ = noteGroups[0][0]
                    .addModifier(factory.Fingering(number: "0", position: .left), index: 0)
                    .addModifier(factory.Fingering(number: "0", position: .left), index: 1)
                _ = noteGroups[1][0]
                    .addModifier(factory.Fingering(number: "1", position: .left), index: 0)
                _ = noteGroups[2][0]
                    .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
            }
        )
    }

    @Test("Three_Voice_Rests.Auto_Adjust_Rest_Positions___Two_Voices")
    func threeVoiceRestsAutoAdjustRestPositionsTwoVoicesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Three_Voice_Rests",
            test: "Auto_Adjust_Rest_Positions___Two_Voices",
            width: 900,
            height: 200
        ) { factory, context in
            let score = factory.EasyScore()
            var x = 10.0
            var beams: [Beam] = []

            func createMeasure(_ title: String, width: Double, alignRests: Bool) throws {
                let stave = factory.Stave(x: x, y: 50, width: width).setBegBarType(.single)
                x += width

                let notes1 = score.notes(
                    "b4/8/r, e5/16, b4/r, b4/8/r, e5/16, b4/r, b4/8/r, d5/16, b4/r, e5/4",
                    options: ["stem": "up"]
                )
                let notes2 = score.notes(
                    "c5/16, c4, b4/r, d4, e4, f4, b4/r, g4, g4[stem=\"up\"], a4[stem=\"up\"], b4/r, b4[stem=\"up\"], e4/4",
                    options: ["stem": "down"]
                )
                let notes3: [Note] = [
                    factory.TextNote(try TextNoteStruct(duration: "1", text: title, smooth: true, line: -1))
                ]

                let voice1 = score.voice(notes1.map { $0 as Note })
                let voice2 = score.voice(notes2.map { $0 as Note })
                let voice3 = score.voice(notes3)

                beams.append(contentsOf: try Beam.applyAndGetBeams(voice1, stemDirection: .up))
                beams.append(contentsOf: try Beam.applyAndGetBeams(voice2, stemDirection: .down))

                _ = factory.Formatter()
                    .joinVoices([voice1, voice2, voice3])
                    .formatToStave(
                        [voice1, voice2, voice3],
                        stave: stave,
                        options: FormatParams(alignRests: alignRests)
                    )
            }

            try createMeasure("Default Rest Positions", width: 400, alignRests: false)
            try createMeasure("Rests Repositioned To Avoid Collisions", width: 400, alignRests: true)

            try factory.draw()
            for beam in beams {
                _ = beam.setContext(context)
                try beam.draw()
            }
        }
    }

    @Test("Three_Voice_Rests.Auto_Adjust_Rest_Positions___Three_Voices__1")
    func threeVoiceRestsAutoAdjustRestPositionsThreeVoices1MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Three_Voice_Rests",
            test: "Auto_Adjust_Rest_Positions___Three_Voices__1",
            width: 850,
            height: 200
        ) { factory, _ in
            let score = factory.EasyScore()
            var x = 10.0

            func createMeasure(_ title: String, width: Double, alignRests: Bool) throws {
                let stave = factory.Stave(x: x, y: 50, width: width).setBegBarType(.single)
                x += width

                let voice1 = score.voice(
                    score.notes("b4/4/r, e5, e5/r, e5/r, e5, e5, e5, e5/r", options: ["stem": "up"]).map { $0 as Note },
                    time: .meter(8, 4)
                )
                let voice2 = score.voice(
                    score.notes("b4/4/r, b4/r, b4/r, b4, b4/r, b4/r, b4, b4", options: ["stem": "down"]).map { $0 as Note },
                    time: .meter(8, 4)
                )
                let voice3 = score.voice(
                    score.notes("e4/4/r, e4/r, f4, b4/r, g4, c4, e4/r, c4", options: ["stem": "down"]).map { $0 as Note },
                    time: .meter(8, 4)
                )
                let voice4 = score.voice(
                    [
                        factory.TextNote(try TextNoteStruct(duration: "1", text: title, smooth: true, line: -1)),
                        factory.TextNote(try TextNoteStruct(duration: "1", text: "", smooth: true, line: -1)),
                    ],
                    time: .meter(8, 4)
                )

                _ = factory.Formatter()
                    .joinVoices([voice1, voice2, voice3, voice4])
                    .formatToStave(
                        [voice1, voice2, voice3, voice4],
                        stave: stave,
                        options: FormatParams(alignRests: alignRests)
                    )
            }

            try createMeasure("Default Rest Positions", width: 400, alignRests: false)
            try createMeasure("Rests Repositioned To Avoid Collisions", width: 400, alignRests: true)

            try factory.draw()
        }
    }

    @Test("Three_Voice_Rests.Auto_Adjust_Rest_Positions___Three_Voices__2")
    func threeVoiceRestsAutoAdjustRestPositionsThreeVoices2MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Three_Voice_Rests",
            test: "Auto_Adjust_Rest_Positions___Three_Voices__2",
            width: 850,
            height: 200
        ) { factory, _ in
            let score = factory.EasyScore()
            var x = 10.0

            func createMeasure(_ title: String, width: Double, alignRests: Bool) throws {
                let stave = factory.Stave(x: x, y: 50, width: width).setBegBarType(.single)
                x += width

                let voice1 = score.voice(
                    score.notes("b4/16/r, e5, e5/r, e5/r, e5, e5, e5, e5/r").map { $0 as Note },
                    time: .meter(2, 4)
                )
                let voice2 = score.voice(
                    score.notes("b4/16/r, b4/r, b4/r, b4, b4/r, b4/r, b4, b4").map { $0 as Note },
                    time: .meter(2, 4)
                )
                let voice3 = score.voice(
                    score.notes("e4/16/r, e4/r, f4, b4/r, g4, c4, e4/r, c4").map { $0 as Note },
                    time: .meter(2, 4)
                )
                let voice4 = score.voice(
                    [factory.TextNote(try TextNoteStruct(duration: "h", text: title, smooth: true, line: -1))],
                    time: .meter(2, 4)
                )

                _ = factory.Formatter()
                    .joinVoices([voice1, voice2, voice3, voice4])
                    .formatToStave(
                        [voice1, voice2, voice3, voice4],
                        stave: stave,
                        options: FormatParams(alignRests: alignRests)
                    )
            }

            try createMeasure("Default Rest Positions", width: 400, alignRests: false)
            try createMeasure("Rests Repositioned To Avoid Collisions", width: 400, alignRests: true)

            try factory.draw()
        }
    }

    private func runThreeVoiceRestsCase(
        test: String,
        noteGroup1: (notes: String, options: [String: String]),
        noteGroup2: (notes: String, options: [String: String]),
        noteGroup3: (notes: String, options: [String: String]),
        setup: (Factory, [[StemmableNote]]) throws -> Void
    ) throws {
        try runCategorySVGParityCase(
            module: "Three_Voice_Rests",
            test: test,
            width: 600,
            height: 200
        ) { factory, context in
            let stave = factory.Stave()
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
            let score = factory.EasyScore()

            let noteGroups: [[StemmableNote]] = [
                score.notes(noteGroup1.notes, options: noteGroup1.options),
                score.notes(noteGroup2.notes, options: noteGroup2.options),
                score.notes(noteGroup3.notes, options: noteGroup3.options),
            ]
            let voices = noteGroups.map { score.voice($0.map { $0 as Note }) }

            try setup(factory, noteGroups)

            var beams: [Beam] = []
            beams.append(contentsOf: try Beam.applyAndGetBeams(voices[0], stemDirection: .up))
            beams.append(contentsOf: try Beam.applyAndGetBeams(voices[1], stemDirection: .down))
            beams.append(contentsOf: try Beam.applyAndGetBeams(voices[2], stemDirection: .down))

            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()

            for beam in beams {
                _ = beam.setContext(context)
                try beam.draw()
            }
        }
    }
}
