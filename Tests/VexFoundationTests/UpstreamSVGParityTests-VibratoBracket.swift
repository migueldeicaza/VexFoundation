import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("VibratoBracket.Simple_VibratoBracket")
    func vibratoBracketSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "VibratoBracket",
            test: "Simple_VibratoBracket",
            width: 650,
            height: 200
        ) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let notes = score.notes("c4/4, c4, c4, c4")
            let voice = score.voice(notes)

            _ = factory.VibratoBracket(from: notes[0], to: notes[3], line: 2)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("VibratoBracket.Harsh_VibratoBracket_Without_End_Note")
    func vibratoBracketHarshWithoutEndMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "VibratoBracket",
            test: "Harsh_VibratoBracket_Without_End_Note",
            width: 650,
            height: 200
        ) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let notes = score.notes("c4/4, c4, c4, c4")
            let voice = score.voice(notes)

            _ = factory.VibratoBracket(from: notes[2], to: nil, line: 2, harsh: true)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("VibratoBracket.Harsh_VibratoBracket_Without_Start_Note")
    func vibratoBracketHarshWithoutStartMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "VibratoBracket",
            test: "Harsh_VibratoBracket_Without_Start_Note",
            width: 650,
            height: 200
        ) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let notes = score.notes("c4/4, c4, c4, c4")
            let voice = score.voice(notes)

            _ = factory.VibratoBracket(from: nil, to: notes[2], line: 2, harsh: true)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}
