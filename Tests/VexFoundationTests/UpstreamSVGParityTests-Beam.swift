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

    private func stemmableTickables(from voice: Voice) -> [StemmableNote] {
        voice.getTickables().compactMap { $0 as? StemmableNote }
    }
}
