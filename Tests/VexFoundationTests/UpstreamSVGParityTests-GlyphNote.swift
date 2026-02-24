import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("GlyphNote.GlyphNote_with_ChordSymbols")
    func glyphNoteWithChordSymbolsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "GlyphNote",
            test: "GlyphNote_with_ChordSymbols",
            width: 300,
            height: 200
        ) { factory, _ in
            Registry.enableDefaultRegistry(Registry())
            defer { Registry.disableDefaultRegistry() }

            let system = factory.System(options: SystemOptions(
                noPadding: false,
                debugFormatter: false,
                x: 50,
                width: 250
            ))
            let score = factory.EasyScore()

            let notes: [GlyphNote] = try [
                factory.GlyphNote(
                    glyph: Glyph(code: "repeatBarSlash", point: 40),
                    noteStruct: NoteStruct(duration: "q")
                ),
                factory.GlyphNote(
                    glyph: Glyph(code: "repeatBarSlash", point: 40),
                    noteStruct: NoteStruct(duration: "q")
                ),
                factory.GlyphNote(
                    glyph: Glyph(code: "repeatBarSlash", point: 40),
                    noteStruct: NoteStruct(duration: "q")
                ),
                factory.GlyphNote(
                    glyph: Glyph(code: "repeatBarSlash", point: 40),
                    noteStruct: NoteStruct(duration: "q")
                ),
            ]

            let chord1 = factory
                .ChordSymbol(reportWidth: false)
                .addText("F7")
                .setHorizontal(.left)
            _ = glyphNoteAddGlyphOrText(chord1, "(#11b9)", modifier: .sup)

            let chord2 = factory
                .ChordSymbol()
                .addText("F7")
                .setHorizontal(.left)
            _ = glyphNoteAddGlyphOrText(chord2, "#11", modifier: .sup)
            _ = glyphNoteAddGlyphOrText(chord2, "b9", modifier: .sub)

            _ = notes[0].addModifier(chord1, index: 0)
            _ = notes[2].addModifier(chord2, index: 0)

            let voice = score.voice(notes.map { $0 as Note })
            _ = system.addStave(SystemStave(voices: [voice], debugNoteMetrics: false))
            _ = system.addConnector().setType(.bracket)

            try factory.draw()
        }
    }

    @Test("GlyphNote.GlyphNote_Positioning")
    func glyphNotePositioningMatchesUpstream() throws {
        try runGlyphNoteBasicCase(test: "GlyphNote_Positioning", debug: false, noPadding: false)
    }

    @Test("GlyphNote.GlyphNote_No_Stave_Padding")
    func glyphNoteNoStavePaddingMatchesUpstream() throws {
        try runGlyphNoteBasicCase(test: "GlyphNote_No_Stave_Padding", debug: true, noPadding: true)
    }

    @Test("GlyphNote.GlyphNote_RepeatNote")
    func glyphNoteRepeatNoteMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "GlyphNote",
            test: "GlyphNote_RepeatNote",
            width: 300,
            height: 500
        ) { factory, _ in
            Registry.enableDefaultRegistry(Registry())
            defer { Registry.disableDefaultRegistry() }

            let system = factory.System(options: SystemOptions(
                noPadding: true,
                debugFormatter: false,
                x: 50,
                width: 250
            ))
            let score = factory.EasyScore()

            let voices: [[RepeatNote]] = try [
                [factory.RepeatNote(type: "1")],
                [factory.RepeatNote(type: "2")],
                [factory.RepeatNote(type: "4")],
                [
                    factory.RepeatNote(type: "slash", noteStruct: NoteStruct(duration: "16")),
                    factory.RepeatNote(type: "slash", noteStruct: NoteStruct(duration: "16")),
                    factory.RepeatNote(type: "slash", noteStruct: NoteStruct(duration: "16")),
                    factory.RepeatNote(type: "slash", noteStruct: NoteStruct(duration: "16")),
                ],
            ]

            for notes in voices {
                let voice = score.voice(notes.map { $0 as Note }, time: .meter(1, 4))
                _ = system.addStave(SystemStave(voices: [voice], debugNoteMetrics: false))
            }
            _ = system.addConnector().setType(.bracket)

            try factory.draw()
        }
    }

    private func runGlyphNoteBasicCase(
        test: String,
        debug: Bool,
        noPadding: Bool
    ) throws {
        try runCategorySVGParityCase(
            module: "GlyphNote",
            test: test,
            width: 300,
            height: 400
        ) { factory, _ in
            Registry.enableDefaultRegistry(Registry())
            defer { Registry.disableDefaultRegistry() }

            let system = factory.System(options: SystemOptions(
                noPadding: noPadding,
                debugFormatter: debug,
                x: 50,
                width: 250
            ))
            let score = factory.EasyScore()

            let voices: [[GlyphNote]] = try [
                [
                    factory.GlyphNote(
                        glyph: Glyph(code: "repeat1Bar", point: 40),
                        noteStruct: NoteStruct(duration: "q"),
                        options: GlyphNoteOptions(line: 4)
                    ),
                ],
                [
                    factory.GlyphNote(
                        glyph: Glyph(code: "repeat2Bars", point: 40),
                        noteStruct: NoteStruct(duration: "q", alignCenter: true)
                    ),
                ],
                [
                    factory.GlyphNote(
                        glyph: Glyph(code: "repeatBarSlash", point: 40),
                        noteStruct: NoteStruct(duration: "16")
                    ),
                    factory.GlyphNote(
                        glyph: Glyph(code: "repeatBarSlash", point: 40),
                        noteStruct: NoteStruct(duration: "16")
                    ),
                    factory.GlyphNote(
                        glyph: Glyph(code: "repeat4Bars", point: 40),
                        noteStruct: NoteStruct(duration: "16")
                    ),
                    factory.GlyphNote(
                        glyph: Glyph(code: "repeatBarSlash", point: 40),
                        noteStruct: NoteStruct(duration: "16")
                    ),
                ],
            ]

            for notes in voices {
                let voice = score.voice(notes.map { $0 as Note }, time: .meter(1, 4))
                _ = system.addStave(SystemStave(voices: [voice], debugNoteMetrics: debug))
            }
            _ = system.addConnector().setType(.bracket)

            try factory.draw()
        }
    }

    @discardableResult
    private func glyphNoteAddGlyphOrText(
        _ chord: ChordSymbol,
        _ text: String,
        modifier: SymbolModifier
    ) -> ChordSymbol {
        guard modifier != .none else {
            _ = chord.addGlyphOrText(text)
            return chord
        }

        var buffered = ""
        for ch in text {
            let symbol = String(ch)
            if ChordSymbol.glyphs[symbol] != nil {
                if !buffered.isEmpty {
                    _ = chord.addText(buffered, symbolModifier: modifier)
                    buffered = ""
                }
                _ = chord.addSymbolBlock(symbolType: .glyph, symbolModifier: modifier, glyphName: symbol)
            } else {
                buffered.append(ch)
            }
        }

        if !buffered.isEmpty {
            _ = chord.addText(buffered, symbolModifier: modifier)
        }
        return chord
    }
}
