import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("EasyScore.Draw_Basic")
    func easyScoreDrawBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h., c5/q", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let lower = score.voice(
                score.notes("c#3/q, cn3/q, bb3/q, d##3/q", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [lower])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Different_KeySignature")
    func easyScoreDrawDifferentKeySignatureMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Different_KeySignature", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c5/h., c5/q", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice]))
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("D")

            let lower = score.voice(
                score.notes("c#3/q, cn3/q, bb3/q, d##3/q", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [lower]))
                .addClef(.bass)
                .addTimeSignature(.meter(4, 4))
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Accidentals")
    func easyScoreDrawAccidentalsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Accidentals", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(cbbs4 ebb4 gbss4)/q, cbs4/q, cdb4/q/r, cd4/q", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c++-5/h., c++5/q", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let lower = score.voice(
                score.notes("c+-3/q, c+3/q, bb3/q, d##3/q", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [lower])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Basic_Muted")
    func easyScoreDrawBasicMutedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic_Muted", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q/m, c4/q/m, c4/q/r, c4/q/m", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h/m., c5/q/m", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let bassVoice = score.voice(
                score.notes("c#3/q/m, cn3/q/m, bb3/q/m, d##3/q/m", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [bassVoice])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Basic_Harmonic")
    func easyScoreDrawBasicHarmonicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic_Harmonic", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q/h, c4/q/h, c4/q/r, c4/q/h", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h/h., c5/q/h", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let bassVoice = score.voice(
                score.notes("c#3/q/h, cn3/q/h, bb3/q/h, d##3/q/h", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [bassVoice])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Basic_Slash")
    func easyScoreDrawBasicSlashMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Basic_Slash", width: 600, height: 350) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let upperVoice = score.voice(
                score.notes("(d4 e4 g4)/q/s, c4/q/s, c4/q/r, c4/q/s", options: ["stem": "down"]).map { $0 as Note }
            )
            let lowerVoice = score.voice(
                score.notes("c#5/h/s., c5/q/s", options: ["stem": "up"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [upperVoice, lowerVoice])).addClef(.treble)

            let bassVoice = score.voice(
                score.notes("c#3/q/s, cn3/q/s, bb3/q/s, d##3/q/s", options: ["clef": "bass"]).map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [bassVoice])).addClef(.bass)
            _ = system.addConnector(type: .bracket)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Beams")
    func easyScoreDrawBeamsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Beams", width: 600, height: 250) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let lower = score.notes("(c4 e4 g4)/q, c4/q, c4/q/r, c4/q", options: ["stem": "down"])
            let upper = score.notes("c#5/h.", options: ["stem": "up"])
                + score.beam(score.notes("c5/8, c5/8", options: ["stem": "up"]))

            let lowerVoice = score.voice(lower.map { $0 as Note })
            let upperVoice = score.voice(upper.map { $0 as Note })
            _ = system.addStave(SystemStave(voices: [lowerVoice, upperVoice])).addClef(.treble)

            try factory.draw()
        }
    }

    @Test("EasyScore.Draw_Dots")
    func easyScoreDrawDotsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "EasyScore", test: "Draw_Dots", width: 600, height: 250) { factory, _ in
            let score = factory.EasyScore()
            let system = factory.System()

            let voice = score.voice(
                score.notes("(c4 e4 g4)/8., (c4 e4 g4)/8.., (c4 e4 g4)/8..., (c4 e4 g4)/8...., (c4 e4 g4)/16...")
                    .map { $0 as Note }
            )
            _ = system.addStave(SystemStave(voices: [voice])).addClef(.treble)

            try factory.draw()
        }
    }
}
