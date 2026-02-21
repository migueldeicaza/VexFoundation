import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Font.Set_Text_Font_to_Georgia")
    func fontSetTextFontToGeorgiaMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Font",
            test: "Set_Text_Font_to_Georgia",
            width: 400,
            height: 200
        ) { factory, _ in
            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()

            let voice1Notes = [
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "h", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4", "f/4"], duration: "q", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "f/4", "a/4"], duration: "q", stemDirection: .down)),
            ]
            let voice1 = score.voice(voice1Notes)

            let lyric = factory.TextNote(TextNoteStruct(duration: .whole, text: "Here are some fun lyrics..."))
                .setJustification(.left)
                .setFont(FontInfo(
                    family: "Georgia, Courier New, serif",
                    size: "14pt",
                    weight: VexFontWeight.bold.rawValue,
                    style: VexFontStyle.italic.rawValue
                ))

            let voice2 = score.voice([lyric])
            _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)
            try factory.draw()
        }
    }

    @Test("Font.Set_Music_Font_to_Petaluma")
    func fontSetMusicFontToPetalumaMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Font",
            test: "Set_Music_Font_to_Petaluma",
            width: 400,
            height: 200
        ) { factory, _ in
            _ = Flow.setMusicFont(.petaluma)

            let stave = factory.Stave(y: 40)
            let score = factory.EasyScore()

            let voice = score.voice([
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "h", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4", "f/4"], duration: "q", stemDirection: .down)),
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "f/4", "a/4"], duration: "q", stemDirection: .down)),
            ])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}
