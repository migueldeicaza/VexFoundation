import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TextBracket.Simple_TextBracket")
    func textBracketSimpleTextBracketMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextBracket", test: "Simple_TextBracket", width: 550, height: 140) {
            factory,
            _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let notes = score.notes("c4/4, c4, c4, c4, c4", options: ["stem": "up"])
            let voice = score.voice(notes, time: .meter(5, 4))

            _ = factory.TextBracket(
                from: notes[0],
                to: notes[4],
                text: "15",
                superscript: "va",
                position: .top
            )

            _ = factory.TextBracket(
                from: notes[0],
                to: notes[4],
                text: "8",
                superscript: "vb",
                position: .bottom,
                line: 3
            )

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("TextBracket.TextBracket_Styles")
    func textBracketStylesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TextBracket", test: "TextBracket_Styles", width: 550, height: 140) {
            factory,
            _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let notes = score.notes("c4/4, c4, c4, c4, c4", options: ["stem": "up"])
            let voice = score.voice(notes, time: .meter(5, 4))

            let topOctaves: [TextBracket] = [
                factory.TextBracket(
                    from: notes[0],
                    to: notes[1],
                    text: "Cool notes",
                    superscript: "",
                    position: .top
                ),
                factory.TextBracket(
                    from: notes[2],
                    to: notes[4],
                    text: "Testing",
                    superscript: "superscript",
                    position: .top,
                    font: FontInfo(
                        family: VexFont.SANS_SERIF,
                        size: 15,
                        weight: VexFontWeight.normal.rawValue,
                        style: VexFontStyle.normal.rawValue
                    )
                ),
            ]

            let bottomOctaves: [TextBracket] = [
                factory.TextBracket(
                    from: notes[0],
                    to: notes[1],
                    text: "8",
                    superscript: "vb",
                    position: .bottom,
                    line: 3,
                    font: FontInfo(
                        family: VexFont.SERIF,
                        size: 30,
                        weight: VexFontWeight.normal.rawValue,
                        style: VexFontStyle.italic.rawValue
                    )
                ),
                factory.TextBracket(
                    from: notes[2],
                    to: notes[4],
                    text: "Not cool notes",
                    superscript: " super uncool",
                    position: .bottom,
                    line: 4
                ),
            ]

            topOctaves[1].bracketRenderOptions.lineWidth = 2
            topOctaves[1].bracketRenderOptions.showBracket = false

            bottomOctaves[0].bracketRenderOptions.underlineSuperscript = false
            _ = bottomOctaves[0].setDashed(false)

            bottomOctaves[1].bracketRenderOptions.bracketHeight = 40
            _ = bottomOctaves[1].setDashed(true, dash: [2, 2])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}
