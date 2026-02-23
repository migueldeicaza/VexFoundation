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
}
