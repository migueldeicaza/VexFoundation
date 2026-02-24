import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Beam.Simple_Beam")
    func beamSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Simple_Beam", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let notes = score.notes("(cb4 e#4 a4)/2")
                + score.beam(score.notes("(cb4 e#4 a4)/8, (d4 f4 a4), (ebb4 g##4 b4), (f4 a4 c5)", options: ["stem": "up"]))
            let voice = score.voice(notes.map { $0 as Note }, time: .meter(2, 2))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Sixteenth_Beam")
    func beamSixteenthMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Sixteenth_Beam", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let upper = score.beam(score.notes("f5/16, f5, d5, c5", options: ["stem": "up"]))
                + score.beam(score.notes("c5/16, d5, f5, e5", options: ["stem": "up"]))
                + score.notes("f5/2", options: ["stem": "up"])
            let lower = score.beam(score.notes("f4/16, e4/16, d4/16, c4/16", options: ["stem": "down"]))
                + score.beam(score.notes("c4/16, d4/16, f4/16, e4/16", options: ["stem": "down"]))
                + score.notes("f4/2", options: ["stem": "down"])

            let voices = [
                score.voice(upper.map { $0 as Note }),
                score.voice(lower.map { $0 as Note }),
            ]

            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Slopey_Beam")
    func beamSlopeyMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Slopey_Beam", width: 350, height: 140) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let notes = score.beam(score.notes("c4/8, f4/8, d5/8, g5/8", options: ["stem": "up"]))
                + score.beam(score.notes("d6/8, f5/8, d4/8, g3/8", options: ["stem": "up"]))
            let voice = score.voice(notes.map { $0 as Note })

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Multi_Beam")
    func beamMultiMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Multi_Beam", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let upper = score.beam(score.notes("f5/8, e5, d5, c5", options: ["stem": "up"]))
                + score.beam(score.notes("c5, d5, e5, f5", options: ["stem": "up"]))
            let lower = score.beam(score.notes("f4/8, e4, d4, c4", options: ["stem": "down"]))
                + score.beam(score.notes("c4/8, d4, e4, f4", options: ["stem": "down"]))

            let voices = [
                score.voice(upper.map { $0 as Note }),
                score.voice(lower.map { $0 as Note }),
            ]

            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Auto_stemmed_Beam")
    func beamAutoStemmedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Auto_stemmed_Beam", width: 350, height: 140) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voice = score.voice(
                score.notes("a4/8, b4/8, g4/8, c5/8, f4/8, d5/8, e4/8, e5/8, b4/8, b4/8, g4/8, d5/8"),
                time: .meter(6, 4)
            )
            let tickables = stemmableTickables(from: voice)
            #expect(tickables.count == 12)

            let beamRanges = [0..<2, 2..<4, 4..<6, 6..<8, 8..<10, 10..<12]
            let beams = beamRanges.compactMap { factory.Beam(notes: Array(tickables[$0]), autoStem: true) }
            guard beams.count == 6 else {
                Issue.record("Expected 6 auto-stemmed beams, got \(beams.count)")
                return
            }

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

            #expect(beams[0].getStemDirection() == Stem.UP)
            #expect(beams[1].getStemDirection() == Stem.UP)
            #expect(beams[2].getStemDirection() == Stem.UP)
            #expect(beams[3].getStemDirection() == Stem.UP)
            #expect(beams[4].getStemDirection() == Stem.DOWN)
            #expect(beams[5].getStemDirection() == Stem.DOWN)

            try factory.draw()
        }
    }

    @Test("Beam.Mixed_Beam_1")
    func beamMixed1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Mixed_Beam_1", width: 350, height: 140) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voice1 = score.voice(
                score.notes("f5/8, d5/16, c5/16, c5/16, d5/16, e5/8, f5/8, d5/16, c5/16, c5/16, d5/16, e5/8", options: ["stem": "up"])
            )
            let voice2 = score.voice(
                score.notes("f4/16, e4/8, d4/16, c4/16, d4/8, f4/16, f4/16, e4/8, d4/16, c4/16, d4/8, f4/16", options: ["stem": "down"])
            )

            let voice1Notes = stemmableTickables(from: voice1)
            let voice2Notes = stemmableTickables(from: voice2)
            #expect(voice1Notes.count == 12)
            #expect(voice2Notes.count == 12)

            let beamRanges = [0..<4, 4..<8, 8..<12]
            for range in beamRanges {
                #expect(factory.Beam(notes: Array(voice1Notes[range])) != nil)
            }
            for range in beamRanges {
                #expect(factory.Beam(notes: Array(voice2Notes[range])) != nil)
            }

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Mixed_Beam_2")
    func beamMixed2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Mixed_Beam_2", width: 450, height: 180) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voice1 = score.voice(
                score.notes("f5/32, d5/16, c5/32, c5/64, d5/128, e5/8, f5/16, d5/32, c5/64, c5/32, d5/16, e5/128", options: ["stem": "up"]),
                time: .meter(31, 64)
            )
            let voice2 = score.voice(
                score.notes("f4/32, d4/16, c4/32, c4/64, d4/128, e4/8, f4/16, d4/32, c4/64, c4/32, d4/16, e4/128", options: ["stem": "down"]),
                time: .meter(31, 64)
            )

            let voice1Notes = stemmableTickables(from: voice1)
            let voice2Notes = stemmableTickables(from: voice2)
            #expect(voice1Notes.count == 12)
            #expect(voice2Notes.count == 12)

            #expect(factory.Beam(notes: Array(voice1Notes[0..<12])) != nil)
            #expect(factory.Beam(notes: Array(voice2Notes[0..<12])) != nil)

            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Dotted_Beam")
    func beamDottedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Dotted_Beam", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let voice = score.voice(
                score.notes("d4/8, b3/8., a3/16, a3/8, b3/8., c4/16, d4/8, b3/8, a3/8., a3/16, b3/8., c4/16", options: ["stem": "up"]),
                time: .meter(6, 4)
            )
            let notes = stemmableTickables(from: voice)
            #expect(notes.count == 12)
            _ = factory.Beam(notes: Array(notes[0..<4]))
            _ = factory.Beam(notes: Array(notes[4..<8]))
            _ = factory.Beam(notes: Array(notes[8..<12]))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Partial_Beam")
    func beamPartialMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Partial_Beam", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let voice = score.voice(
                score.notes("d4/8, b3/32, c4/16., d4/16., e4/8, c4/64, c4/32, a3/8., b3/32., c4/8, e4/64, b3/16., b3/64, f4/8, e4/8, g4/64, e4/8"),
                time: .meter(89, 64)
            )
            let notes = stemmableTickables(from: voice)
            #expect(notes.count == 17)
            _ = factory.Beam(notes: Array(notes[0..<3]))
            _ = factory.Beam(notes: Array(notes[3..<9]))
            _ = factory.Beam(notes: Array(notes[9..<13]))
            _ = factory.Beam(notes: Array(notes[13..<17]))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Close_Trade_offs_Beam")
    func beamCloseTradeoffsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Close_Trade_offs_Beam", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let voice = score.voice(
                score.notes("a4/8, b4/8, c4/8, d4/8, g4/8, a4/8, b4/8, c4/8", options: ["stem": "up"])
            )
            let notes = stemmableTickables(from: voice)
            _ = factory.Beam(notes: Array(notes[0..<4]))
            _ = factory.Beam(notes: Array(notes[4..<8]))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Insane_Beam")
    func beamInsaneMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Insane_Beam", width: 450, height: 180) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voice = score.voice(
                score.notes(
                    #"g4/8, g5/8, c4/8, b5/8, g4/8[stem="down"], a5[stem="down"], b4[stem="down"], c4/8"#,
                    options: ["stem": "up"]
                )
            )
            let notes = stemmableTickables(from: voice)
            _ = factory.Beam(notes: Array(notes[0..<4]))
            _ = factory.Beam(notes: Array(notes[4..<7]))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Lengthy_Beam")
    func beamLengthyMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Lengthy_Beam", width: 450, height: 180) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voice = score.voice(
                score.beam(score.notes("g4/8, g4, g4, a4", options: ["stem": "up"])),
                time: .meter(2, 4)
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Outlier_Beam")
    func beamOutlierMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Outlier_Beam", width: 450, height: 180) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voice = score.voice(
                score.notes(
                    #"g4/8[stem="up"], f4[stem="up"], d5[stem="up"], e4[stem="up"], d5/8[stem="down"], d5[stem="down"], c5[stem="down"], d5[stem="down"]"#
                )
            )
            let notes = stemmableTickables(from: voice)
            _ = factory.Beam(notes: Array(notes[0..<4]))
            _ = factory.Beam(notes: Array(notes[4..<8]))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Break_Secondary_Beams")
    func beamBreakSecondaryBeamsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Break_Secondary_Beams", width: 600, height: 200) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let voices = [
                score.voice(
                    score.beam(
                        score.notes("f5/16., f5/32, c5/16., d5/32, c5/16., d5/32", options: ["stem": "up"]),
                        secondaryBeamBreaks: [1, 3]
                    )
                        + score.beam(
                            score.notes("f5/16, e5, e5, e5, e5, e5", options: ["stem": "up"]),
                            secondaryBeamBreaks: [2]
                        ),
                    time: .meter(3, 4)
                ),
                score.voice(
                    score.beam(
                        score.notes("f4/32, d4, e4, c4, d4, c4, f4, d4, e4, c4, c4, d4", options: ["stem": "down"]),
                        secondaryBeamBreaks: [3, 7]
                    )
                        + score.beam(
                            score.notes("d4/16, f4, d4, e4, e4, e4", options: ["stem": "down"]),
                            secondaryBeamBreaks: [3]
                        ),
                    time: .meter(3, 4)
                ),
            ]

            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Partial_Beam_Direction")
    func beamPartialBeamDirectionMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Partial_Beam_Direction", width: 600, height: 200) { factory, _ in
            let stave = factory.Stave(y: 20)
            let score = factory.EasyScore()

            let notes = score.beam(score.notes("f4/8, f4/16, f4/8, f4/16", options: ["stem": "up"]))
                + score.beam(
                    score.notes("f4/8, f4/16, f4/8, f4/16", options: ["stem": "up"]),
                    partialBeamDirections: [1: .right]
                )
                + score.beam(
                    score.notes("f4/8, f4/16, f4/8, f4/16", options: ["stem": "up"]),
                    partialBeamDirections: [1: .left]
                )
            let voice = score.voice(notes, time: .meter(9, 8))

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.TabNote_Beams_Up")
    func beamTabBeamsUpMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "TabNote_Beams_Up", width: 600, height: 200) { factory, _ in
            let stave = factory.TabStave(y: 20)
            let specs = upstreamBeamTabSpecsUp()
            let notes = try specs.map { spec in
                let note = try TabNote(validating: spec.toStruct())
                note.renderOptions.drawStem = true
                return note
            }

            _ = factory.Beam(notes: Array(notes[1..<7]))
            _ = factory.Beam(notes: Array(notes[8..<11]))
            _ = factory.Tuplet(notes: Array(notes[8..<11]).map { $0 as Note }, options: TupletOptions(ratioed: true))

            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.TabNote_Beams_Down")
    func beamTabBeamsDownMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "TabNote_Beams_Down", width: 600, height: 250) { factory, _ in
            let stave = factory.TabStave(options: StaveOptions(numLines: 10))
            let specs = upstreamBeamTabSpecsDown()
            let notes = try specs.map { spec in
                let note = try TabNote(validating: spec.toStruct())
                note.renderOptions.drawStem = true
                note.renderOptions.drawDots = true
                return note
            }

            Dot.buildAndAttach([notes[1], notes[1]].map { $0 as Note })
            _ = factory.Beam(notes: Array(notes[1..<7]))
            _ = factory.Beam(notes: Array(notes[8..<11]))
            _ = factory.Tuplet(
                notes: Array(notes[8..<11]).map { $0 as Note },
                options: TupletOptions(location: .bottom)
            )
            _ = factory.Tuplet(
                notes: Array(notes[11..<14]).map { $0 as Note },
                options: TupletOptions(location: .bottom)
            )

            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.TabNote_Auto_Create_Beams")
    func beamTabAutoCreateBeamsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "TabNote_Auto_Create_Beams", width: 600, height: 200) { factory, context in
            let stave = factory.TabStave()
            let specs = upstreamBeamTabSpecsAuto()
            let notes = try specs.map { spec in
                let note = try TabNote(validating: spec.toStruct())
                note.renderOptions.drawStem = true
                note.renderOptions.drawDots = true
                return note
            }

            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })
            let beams = try Beam.applyAndGetBeams(voice, stemDirection: .down)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()

            for beam in beams {
                _ = beam.setContext(context)
                try beam.draw()
            }
        }
    }

    @Test("Beam.TabNote_Beams_Auto_Stem")
    func beamTabBeamsAutoStemMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "TabNote_Beams_Auto_Stem", width: 600, height: 300) { factory, _ in
            let stave = factory.TabStave()
            let specs = upstreamBeamTabSpecsAutoStem()
            let notes = try specs.map { spec in
                let note = try TabNote(validating: spec.toStruct())
                note.renderOptions.drawStem = true
                note.renderOptions.drawDots = true
                return note
            }

            _ = factory.Beam(notes: Array(notes[0..<8]), autoStem: true)
            _ = factory.Beam(notes: Array(notes[8..<12]), autoStem: true)

            let voice = factory.Voice().setMode(.soft).addTickables(notes.map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Complex_Beams_with_Annotations")
    func beamComplexWithAnnotationsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Complex_Beams_with_Annotations", width: 500, height: 200) { factory, _ in
            let stave = factory.Stave(y: 40)
            let font = FontInfo(
                family: VexFont.SERIF,
                size: 14,
                weight: VexFontWeight.bold.rawValue,
                style: VexFontStyle.italic.rawValue
            )

            let notes1 = try upstreamBeamComplexSpecs(stemDirection: .up).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Annotation(text: "1", vJustify: .top, font: font), index: 0)
            }
            let notes2 = try upstreamBeamComplexSpecs(stemDirection: .down).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Annotation(text: "3", vJustify: .bottom, font: font), index: 0)
            }

            _ = factory.Beam(notes: notes1)
            _ = factory.Beam(notes: notes2)

            let voice = factory.Voice()
                .setMode(.soft)
                .addTickables(notes1.map { $0 as Tickable })
                .addTickables(notes2.map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Complex_Beams_with_Articulations")
    func beamComplexWithArticulationsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Complex_Beams_with_Articulations", width: 500, height: 200) { factory, _ in
            let stave = factory.Stave(y: 40)

            let notes1 = try upstreamBeamComplexSpecs(stemDirection: .up).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Articulation(type: "am").setPosition(.above), index: 0)
            }
            let notes2 = try upstreamBeamComplexSpecs(stemDirection: .down).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Articulation(type: "a>").setPosition(.below), index: 0)
            }

            _ = factory.Beam(notes: notes1)
            _ = factory.Beam(notes: notes2)

            let voice = factory.Voice()
                .setMode(.soft)
                .addTickables(notes1.map { $0 as Tickable })
                .addTickables(notes2.map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Beam.Complex_Beams_with_Articulations_two_Staves")
    func beamComplexWithArticulationsTwoStavesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Beam", test: "Complex_Beams_with_Articulations_two_Staves", width: 500, height: 300) { factory, _ in
            let system = factory.System()

            let notes1 = try upstreamBeamComplexSpecs(stemDirection: .up).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Articulation(type: "am").setPosition(.above), index: 0)
            }
            let notes2 = try upstreamBeamComplexSpecs(stemDirection: .down).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Articulation(type: "a>").setPosition(.below), index: 0)
            }
            let notes3 = try upstreamBeamComplexSpecs(stemDirection: .up).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Articulation(type: "am").setPosition(.above), index: 0)
            }
            let notes4 = try upstreamBeamComplexSpecs(stemDirection: .down).map { spec in
                try factory.StaveNote(spec.toStaveNoteStruct())
                    .addModifier(factory.Articulation(type: "a>").setPosition(.below), index: 0)
            }

            _ = factory.Beam(notes: notes1)
            _ = factory.Beam(notes: notes2)
            _ = factory.Beam(notes: notes3)
            _ = factory.Beam(notes: notes4)

            let voice1 = factory.Voice()
                .setMode(.soft)
                .addTickables(notes1.map { $0 as Tickable })
                .addTickables(notes2.map { $0 as Tickable })
            let voice2 = factory.Voice()
                .setMode(.soft)
                .addTickables(notes3.map { $0 as Tickable })
                .addTickables(notes4.map { $0 as Tickable })

            _ = system.addStave(SystemStave(voices: [voice1]))
            _ = system.addStave(SystemStave(voices: [voice2]))
            try system.formatThrowing()
            try factory.draw()
        }
    }

    private func stemmableTickables(from voice: Voice) -> [StemmableNote] {
        voice.getTickables().compactMap { $0 as? StemmableNote }
    }

    private struct UpstreamBeamTabSpec {
        let positions: [TabNotePosition]
        let duration: String
        let stemDirection: StemDirection?

        init(positions: [TabNotePosition], duration: String, stemDirection: StemDirection? = nil) {
            self.positions = positions
            self.duration = duration
            self.stemDirection = stemDirection
        }

        func toStruct() throws -> TabNoteStruct {
            try TabNoteStruct(
                positions: positions,
                duration: duration,
                stemDirection: stemDirection
            )
        }
    }

    private struct UpstreamBeamComplexNoteSpec {
        let keys: [String]
        let duration: String
        let stemDirection: StemDirection

        func toStaveNoteStruct() throws -> StaveNoteStruct {
            try StaveNoteStruct(
                parsingKeys: keys,
                duration: duration,
                stemDirection: stemDirection
            )
        }
    }

    private func upstreamBeamComplexSpecs(stemDirection: StemDirection) -> [UpstreamBeamComplexNoteSpec] {
        let octave = stemDirection == .down ? "5" : "4"
        return [
            UpstreamBeamComplexNoteSpec(keys: ["e/\(octave)"], duration: "128", stemDirection: stemDirection),
            UpstreamBeamComplexNoteSpec(keys: ["d/\(octave)"], duration: "16", stemDirection: stemDirection),
            UpstreamBeamComplexNoteSpec(keys: ["e/\(octave)"], duration: "8", stemDirection: stemDirection),
            UpstreamBeamComplexNoteSpec(
                keys: ["c/\(octave)", "g/\(octave)"],
                duration: "32",
                stemDirection: stemDirection
            ),
            UpstreamBeamComplexNoteSpec(keys: ["c/\(octave)"], duration: "32", stemDirection: stemDirection),
            UpstreamBeamComplexNoteSpec(keys: ["c/\(octave)"], duration: "32", stemDirection: stemDirection),
            UpstreamBeamComplexNoteSpec(keys: ["c/\(octave)"], duration: "32", stemDirection: stemDirection),
        ]
    }

    private func upstreamBeamTabSpecsUp() -> [UpstreamBeamTabSpec] {
        [
            .init(positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 25)], duration: "4"),
            .init(positions: [.init(str: 2, fret: 10), .init(str: 5, fret: 12)], duration: "8"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "32"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "64"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "128"),
            .init(positions: [.init(str: 3, fret: 6)], duration: "8"),
            .init(positions: [.init(str: 3, fret: 6)], duration: "8"),
            .init(positions: [.init(str: 3, fret: 6)], duration: "8"),
            .init(positions: [.init(str: 3, fret: 6)], duration: "8"),
        ]
    }

    private func upstreamBeamTabSpecsDown() -> [UpstreamBeamTabSpec] {
        [
            .init(positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 25)], duration: "4", stemDirection: .down),
            .init(positions: [.init(str: 2, fret: 10), .init(str: 5, fret: 12)], duration: "8dd", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "32", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "64", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "128", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 7, fret: 6)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 7, fret: 6)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 10, fret: 6)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 10, fret: 6)], duration: "8", stemDirection: .down),
        ]
    }

    private func upstreamBeamTabSpecsAuto() -> [UpstreamBeamTabSpec] {
        [
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16"),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16"),
            .init(positions: [.init(str: 1, fret: 6)], duration: "32"),
            .init(positions: [.init(str: 1, fret: 6)], duration: "32"),
            .init(positions: [.init(str: 1, fret: 6)], duration: "32"),
            .init(positions: [.init(str: 6, fret: 6)], duration: "32"),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16"),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16"),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16"),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16"),
        ]
    }

    private func upstreamBeamTabSpecsAutoStem() -> [UpstreamBeamTabSpec] {
        [
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8", stemDirection: .up),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16", stemDirection: .up),
            .init(positions: [.init(str: 1, fret: 6)], duration: "32", stemDirection: .up),
            .init(positions: [.init(str: 1, fret: 6)], duration: "32", stemDirection: .down),
            .init(positions: [.init(str: 1, fret: 6)], duration: "32", stemDirection: .down),
            .init(positions: [.init(str: 6, fret: 6)], duration: "32", stemDirection: .down),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16", stemDirection: .up),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16", stemDirection: .up),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16", stemDirection: .up),
            .init(positions: [.init(str: 6, fret: 6)], duration: "16", stemDirection: .down),
        ]
    }
}
