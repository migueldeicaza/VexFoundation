import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("ChordSymbol.Chord_Symbol_With_Modifiers")
    func chordSymbolWithModifiersMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Chord_Symbol_With_Modifiers", width: 750, height: 580) { factory, context in
            _ = context.scale(1.5, 1.5)

            func drawRow(_ chords: [ChordSymbol], y: Double) throws {
                let notes: [StaveNote] = [
                    try chordSymbolNote(factory, ["c/4"], "q", chords[0])
                        .addModifier(factory.Ornament("doit"), index: 0),
                    try chordSymbolNote(factory, ["c/4"], "q", chords[1]),
                    try chordSymbolNote(factory, ["c/4"], "q", chords[2])
                        .addModifier(factory.Ornament("fall"), index: 0),
                    try chordSymbolNote(factory, ["c/4"], "q", chords[3]),
                ]

                let score = factory.EasyScore()
                let voice = score.voice(notes.map { $0 as Note }, time: .meter(4, 4))
                let formatter = factory.Formatter()
                _ = formatter.joinVoices([voice])
                let voiceWidth = formatter.preCalculateMinTotalWidth([voice])
                let staffWidth = voiceWidth + Stave.defaultPadding + chordSymbolGClefWidth()
                _ = formatter.format([voice], justifyWidth: voiceWidth)

                let stave = Stave(x: 10, y: y, width: staffWidth).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()
                try voice.draw(context: context, stave: stave)
            }

            var chords: [ChordSymbol] = [
                makeChordSymbol(factory, fontSize: 10)
                    .addText("F7")
                    .addGlyph("leftParenTall"),
                makeChordSymbol(factory, fontSize: 12)
                    .addText("F7"),
                makeChordSymbol(factory, fontSize: 14)
                    .addText("F7")
                    .addGlyph("leftParenTall"),
                makeChordSymbol(factory, fontSize: 16)
                    .addText("F7")
                    .addGlyph("leftParenTall"),
            ]
            _ = chordAddGlyphOrText(chords[0], "b9", modifier: .sup)
            _ = chordAddGlyphOrText(chords[0], "#11", modifier: .sub)
            _ = chords[0].addGlyph("rightParenTall")

            _ = chordAddGlyphOrText(chords[1], "b9", modifier: .sup)
            _ = chordAddGlyphOrText(chords[1], "#11", modifier: .sub)

            _ = chordAddGlyphOrText(chords[2], "add 3", modifier: .sup)
            _ = chordAddGlyphOrText(chords[2], "omit 9", modifier: .sub)
            _ = chords[2].addGlyph("rightParenTall")

            _ = chordAddGlyphOrText(chords[3], "b9", modifier: .sup)
            _ = chordAddGlyphOrText(chords[3], "#11", modifier: .sub)
            _ = chords[3].addGlyph("rightParenTall")
            try drawRow(chords, y: 40)

            chords = [
                makeChordSymbol(factory, fontSize: 10).addText("F7"),
                makeChordSymbol(factory, fontSize: 12).addText("F7"),
                makeChordSymbol(factory, fontSize: 14).addText("F7"),
                makeChordSymbol(factory, fontSize: 16).addText("F7"),
            ]
            _ = chordAddGlyphOrText(chords[0], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[0], "b9", modifier: .sub)
            _ = chordAddGlyphOrText(chords[1], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[1], "b9", modifier: .sub)
            _ = chordAddGlyphOrText(chords[2], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[2], "b9", modifier: .sub)
            _ = chordAddGlyphOrText(chords[3], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[3], "b9", modifier: .sub)
            try drawRow(chords, y: 140)

            chords = [
                makeChordSymbol(factory, fontSize: 10),
                makeChordSymbol(factory, fontSize: 14),
                makeChordSymbol(factory, fontSize: 16),
                makeChordSymbol(factory, fontSize: 18),
            ]
            _ = chords[0].addGlyphOrText("Ab")
            _ = chordAddGlyphOrText(chords[0], "7(#11b9)", modifier: .sup)
            _ = chords[1].addGlyphOrText("C#")
            _ = chordAddGlyphOrText(chords[1], "7(#11b9)", modifier: .sup)
            _ = chords[2].addGlyphOrText("Ab")
            _ = chordAddGlyphOrText(chords[2], "7(#11b9)", modifier: .sup)
            _ = chords[3].addGlyphOrText("C#")
            _ = chordAddGlyphOrText(chords[3], "7(#11b9)", modifier: .sup)
            try drawRow(chords, y: 240)
        }
    }

    @Test("ChordSymbol.Chord_Symbol_Font_Size_Tests")
    func chordSymbolFontSizeTestsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Chord_Symbol_Font_Size_Tests", width: 750, height: 580) { factory, context in
            _ = context.scale(1.5, 1.5)

            func drawRow(_ chords: [ChordSymbol], y: Double) throws {
                let stave = factory.Stave(x: 10, y: y, width: 450).addClef(.treble)
                let notes: [StaveNote] = try [
                    chordSymbolNote(factory, ["c/4"], "q", chords[0]),
                    chordSymbolNote(factory, ["c/4"], "q", chords[1]),
                    chordSymbolNote(factory, ["c/4"], "q", chords[2]),
                    chordSymbolNote(factory, ["c/4"], "q", chords[3]),
                ]
                let score = factory.EasyScore()
                let voice = score.voice(notes.map { $0 as Note }, time: .meter(4, 4))
                _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            }

            var chords: [ChordSymbol] = [
                makeChordSymbol(factory, fontSize: 10, reportWidth: false).addText("F7").addGlyph("leftParenTall"),
                makeChordSymbol(factory, fontSize: 12, reportWidth: false).addText("F7"),
                makeChordSymbol(factory, fontSize: 14, reportWidth: false).addText("F7").addGlyph("leftParenTall"),
                makeChordSymbol(factory, fontSize: 16, reportWidth: false).addText("F7").addGlyph("leftParenTall"),
            ]
            _ = chordAddGlyphOrText(chords[0], "b9", modifier: .sup)
            _ = chordAddGlyphOrText(chords[0], "#11", modifier: .sub)
            _ = chords[0].addGlyph("rightParenTall")

            _ = chordAddGlyphOrText(chords[1], "b9", modifier: .sup)
            _ = chordAddGlyphOrText(chords[1], "#11", modifier: .sub)

            _ = chordAddGlyphOrText(chords[2], "add 3", modifier: .sup)
            _ = chordAddGlyphOrText(chords[2], "omit 9", modifier: .sub)
            _ = chords[2].addGlyph("rightParenTall")

            _ = chordAddGlyphOrText(chords[3], "b9", modifier: .sup)
            _ = chordAddGlyphOrText(chords[3], "#11", modifier: .sub)
            _ = chords[3].addGlyph("rightParenTall")
            try drawRow(chords, y: 40)

            chords = [
                makeChordSymbol(factory, fontSize: 10).addText("F7"),
                makeChordSymbol(factory, fontSize: 12).addText("F7"),
                makeChordSymbol(factory, fontSize: 14).addText("F7"),
                makeChordSymbol(factory, fontSize: 16).addText("F7"),
            ]
            _ = chordAddGlyphOrText(chords[0], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[0], "b9", modifier: .sub)
            _ = chordAddGlyphOrText(chords[1], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[1], "b9", modifier: .sub)
            _ = chordAddGlyphOrText(chords[2], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[2], "b9", modifier: .sub)
            _ = chordAddGlyphOrText(chords[3], "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chords[3], "b9", modifier: .sub)
            try drawRow(chords, y: 140)

            chords = [
                makeChordSymbol(factory, fontSize: 10),
                makeChordSymbol(factory, fontSize: 14),
                makeChordSymbol(factory, fontSize: 16),
                makeChordSymbol(factory, fontSize: 18),
            ]
            _ = chords[0].addGlyphOrText("Ab")
            _ = chordAddGlyphOrText(chords[0], "7(#11b9)", modifier: .sup)
            _ = chords[1].addGlyphOrText("C#")
            _ = chordAddGlyphOrText(chords[1], "7(#11b9)", modifier: .sup)
            _ = chords[2].addGlyphOrText("Ab")
            _ = chordAddGlyphOrText(chords[2], "7(#11b9)", modifier: .sup)
            _ = chords[3].addGlyphOrText("C#")
            _ = chordAddGlyphOrText(chords[3], "7(#11b9)", modifier: .sup)
            try drawRow(chords, y: 240)

            try factory.draw()
        }
    }

    @Test("ChordSymbol.Chord_Symbol_Kerning_Tests")
    func chordSymbolKerningTestsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "ChordSymbol",
            test: "Chord_Symbol_Kerning_Tests",
            width: 650 * 1.5,
            height: 650
        ) { factory, context in
            _ = context.scale(1.5, 1.5)

            func drawRow(_ chords: [ChordSymbol], y: Double) throws {
                let stave = Stave(x: 10, y: y, width: 450).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()
                let notes: [StaveNote] = try [
                    chordSymbolNote(factory, ["c/4"], "q", chords[0]),
                    chordSymbolNote(factory, ["c/4"], "q", chords[1]),
                    chordSymbolNote(factory, ["c/4"], "q", chords[2]),
                    chordSymbolNote(factory, ["c/4"], "q", chords[3]),
                ]
                let score = factory.EasyScore()
                let voice = score.voice(notes.map { $0 as Note }, time: .meter(4, 4))
                _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                try factory.draw()
            }

            var chords: [ChordSymbol] = [
                makeChordSymbol(factory, reportWidth: false).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory, kerning: false, reportWidth: false).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory, hJustify: .left, reportWidth: false).addText("C"),
                makeChordSymbol(factory, reportWidth: false).addText("D"),
            ]
            _ = chords[2].addSymbolBlock(symbolType: .glyph, symbolModifier: .sup, glyphName: "halfDiminished")
            _ = chords[3].addSymbolBlock(symbolType: .glyph, symbolModifier: .sup, glyphName: "halfDiminished")
            try drawRow(chords, y: 10)

            chords = [
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory, kerning: false).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("+").addTextSuperscript("5"),
                makeChordSymbol(factory).addText("G").addGlyphSuperscript("+").addTextSuperscript("5"),
            ]
            try drawRow(chords, y: 110)

            chords = [
                makeChordSymbol(factory).addText("A").addGlyph("-"),
                makeChordSymbol(factory).addText("E").addGlyph("-"),
                makeChordSymbol(factory).addText("A"),
                makeChordSymbol(factory).addText("E"),
            ]
            _ = chordAddGlyphOrText(chords[2], "(#11)", modifier: .sup)
            _ = chordAddGlyphOrText(chords[3], "(#9)", modifier: .sup)
            try drawRow(chords, y: 210)

            chords = [
                makeChordSymbol(factory),
                makeChordSymbol(factory).addText("E").addGlyphOrText("V/V"),
                makeChordSymbol(factory).addText("A"),
                makeChordSymbol(factory).addText("E"),
            ]
            _ = chords[0].addGlyphOrText("F/B")
            _ = chordAddGlyphOrText(chords[0], "b", modifier: .sup)
            _ = chordAddGlyphOrText(chords[2], "(#11)", modifier: .sup)
            _ = chordAddGlyphOrText(chords[3], "(#9)", modifier: .sup)
            try drawRow(chords, y: 310)
        }
    }

    @Test("ChordSymbol.Top_Chord_Symbols")
    func chordSymbolTopMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Top_Chord_Symbols", width: 650 * 1.5, height: 650) { factory, context in
            _ = context.scale(1.5, 1.5)

            func draw(_ c1: ChordSymbol, _ c2: ChordSymbol, y: Double) throws {
                let stave = Stave(x: 10, y: y, width: 450).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()
                let note1 = try chordSymbolNote(factory, ["e/4", "a/4", "d/5"], "h", c1, stemDirection: .up)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                let note2 = try chordSymbolNote(factory, ["c/5", "e/5", "c/6"], "h", c2, stemDirection: .down)
                _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: [note1, note2])
            }

            var chord1 = makeChordSymbol(factory, hJustify: .left, reportWidth: false).addText("F7").setHorizontal(.left)
            var chord2 = makeChordSymbol(factory, hJustify: .left, reportWidth: false).addText("C").setHorizontal(.left)
            _ = chordAddGlyphOrText(chord1, "(#11b9)", modifier: .sup)
            _ = chord2.addGlyphSuperscript("majorSeventh")
            try draw(chord1, chord2, y: 40)

            chord1 = makeChordSymbol(factory).addText("F7").addTextSuperscript("(")
            chord2 = makeChordSymbol(factory).addText("C").setHorizontal(.left).addTextSuperscript("Maj.")
            _ = chordAddGlyphOrText(chord1, "#11b9", modifier: .sup)
            _ = chord1.addTextSuperscript(")")
            try draw(chord1, chord2, y: 140)

            chord1 = makeChordSymbol(factory).addText("F7").setHorizontal(.left)
            chord2 = makeChordSymbol(factory).addText("C").addTextSuperscript("sus4")
            _ = chordAddGlyphOrText(chord1, "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chord1, "b9", modifier: .sub)
            try draw(chord1, chord2, y: 240)
        }
    }

    @Test("ChordSymbol.Top_Chord_Symbols_Justified")
    func chordSymbolTopJustifiedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Top_Chord_Symbols_Justified", width: 500 * 1.5, height: 680) { factory, context in
            _ = context.scale(1.5, 1.5)

            func draw(_ chord1: ChordSymbol, _ chord2: ChordSymbol, y: Double) throws {
                let stave = Stave(x: 10, y: y, width: 450).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()
                let note1 = try chordSymbolNote(factory, ["e/4", "a/4", "d/5"], "h", chord1)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                let note2 = try chordSymbolNote(factory, ["c/4", "e/4", "b/4"], "h", chord2)
                _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: [note1, note2])
            }

            var chord1 = makeChordSymbol(factory).addText("F7").setHorizontal(.left)
            var chord2 = makeChordSymbol(factory, hJustify: .left).addText("C").addGlyphSuperscript("majorSeventh")
            _ = chordAddGlyphOrText(chord1, "(#11b9)", modifier: .sup)
            try draw(chord1, chord2, y: 40)

            chord1 = makeChordSymbol(factory, hJustify: .center).addText("F7").setHorizontal(.left)
            chord2 = makeChordSymbol(factory, hJustify: .center).addText("C").addTextSuperscript("Maj.")
            _ = chordAddGlyphOrText(chord1, "(#11b9)", modifier: .sup)
            try draw(chord1, chord2, y: 140)

            chord1 = makeChordSymbol(factory, hJustify: .right).addText("F7").setHorizontal(.left)
            chord2 = makeChordSymbol(factory, hJustify: .right).addText("C").addTextSuperscript("Maj.")
            _ = chordAddGlyphOrText(chord1, "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chord1, "b9", modifier: .sub)
            try draw(chord1, chord2, y: 240)

            chord1 = makeChordSymbol(factory, hJustify: .left).addText("F7").setHorizontal(.left)
            chord2 = makeChordSymbol(factory, hJustify: .centerStem).addText("C").addTextSuperscript("Maj.")
            _ = chordAddGlyphOrText(chord1, "#11", modifier: .sup)
            _ = chordAddGlyphOrText(chord1, "b9", modifier: .sub)
            try draw(chord1, chord2, y: 340)
        }
    }

    @Test("ChordSymbol.Bottom_Chord_Symbols")
    func chordSymbolBottomMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Bottom_Chord_Symbols", width: 600 * 1.5, height: 230) { factory, context in
            _ = context.scale(1.5, 1.5)
            let chords = [
                makeChordSymbol(factory, vJustify: .bottom).addText("I").addTextSuperscript("6").addTextSubscript("4"),
                makeChordSymbol(factory, vJustify: .bottom).addGlyphOrText("V"),
                makeChordSymbol(factory, vJustify: .bottom).addLine(12),
                makeChordSymbol(factory, vJustify: .bottom).addGlyphOrText("V/V"),
            ]
            try drawBottomChordSymbolsRow(factory: factory, context: context, y: 10, stemDirection: nil, chords1: chords, chords2: nil, staveWidth: 400)
        }
    }

    @Test("ChordSymbol.Bottom_Stem_Down_Chord_Symbols")
    func chordSymbolBottomStemDownMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "ChordSymbol",
            test: "Bottom_Stem_Down_Chord_Symbols",
            width: 600 * 1.5,
            height: 330
        ) { factory, context in
            _ = context.scale(1.5, 1.5)
            let chords = [
                makeChordSymbol(factory, vJustify: .bottom).addGlyphOrText("F"),
                makeChordSymbol(factory, vJustify: .bottom).addGlyphOrText("C7"),
                makeChordSymbol(factory, vJustify: .bottom).addLine(12),
                makeChordSymbol(factory, vJustify: .bottom).addText("A").addGlyphSuperscript("dim"),
            ]
            try drawBottomChordSymbolsRow(
                factory: factory,
                context: context,
                y: 10,
                stemDirection: .down,
                chords1: chords,
                chords2: nil,
                staveWidth: 400
            )
        }
    }

    @Test("ChordSymbol.Double_Bottom_Chord_Symbols")
    func chordSymbolDoubleBottomMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "ChordSymbol",
            test: "Double_Bottom_Chord_Symbols",
            width: 600 * 1.5,
            height: 260
        ) { factory, context in
            _ = context.scale(1.5, 1.5)
            let chords1 = [
                makeChordSymbol(factory, vJustify: .bottom).addText("I").addTextSuperscript("6").addTextSubscript("4"),
                makeChordSymbol(factory, vJustify: .bottom).addGlyphOrText("V"),
                makeChordSymbol(factory, vJustify: .bottom).addLine(12),
                makeChordSymbol(factory, vJustify: .bottom).addGlyphOrText("V/V"),
            ]
            let chords2 = [
                makeChordSymbol(factory, vJustify: .bottom).addText("T"),
                makeChordSymbol(factory, vJustify: .bottom).addText("D"),
                makeChordSymbol(factory, vJustify: .bottom).addText("D"),
                makeChordSymbol(factory, vJustify: .bottom).addText("SD"),
            ]
            try drawBottomChordSymbolsRow(
                factory: factory,
                context: context,
                y: 10,
                stemDirection: nil,
                chords1: chords1,
                chords2: chords2,
                staveWidth: 450
            )
        }
    }

    private func drawBottomChordSymbolsRow(
        factory: Factory,
        context: SVGRenderContext,
        y: Double,
        stemDirection: StemDirection?,
        chords1: [ChordSymbol],
        chords2: [ChordSymbol]?,
        staveWidth: Double
    ) throws {
        let stave = Stave(x: 10, y: y, width: staveWidth).addClef(.treble)
        _ = stave.setContext(context)
        try stave.draw()

        var notes: [StaveNote] = []
        let keyGroups = [
            ["c/4", "f/4", "a/4"],
            ["c/4", "e/4", "b/4"],
            ["c/4", "e/4", "g/4"],
            ["c/4", "f/4", "a/4"],
        ]
        for idx in 0..<4 {
            let note = try chordSymbolNote(factory, keyGroups[idx], "q", chords1[idx], stemDirection: stemDirection)
            if let chords2 {
                _ = note.addModifier(chords2[idx], index: 0)
            }
            notes.append(note)
        }

        _ = notes[1].addModifier(factory.Accidental(type: .flat), index: 2)
        _ = notes[3].addModifier(factory.Accidental(type: .sharp), index: 1)
        _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
    }

    private func makeChordSymbol(
        _ factory: Factory,
        fontSize: Double? = nil,
        vJustify: ChordSymbolVerticalJustify = .top,
        hJustify: ChordSymbolHorizontalJustify = .left,
        kerning: Bool = true,
        reportWidth: Bool = true
    ) -> ChordSymbol {
        let chord = factory.ChordSymbol(vJustify: vJustify, hJustify: hJustify, kerning: kerning, reportWidth: reportWidth)
        if let fontSize {
            _ = chord.setFont(size: fontSize)
        }
        return chord
    }

    private func chordSymbolNote(
        _ factory: Factory,
        _ keys: [String],
        _ duration: String,
        _ chord: ChordSymbol,
        stemDirection: StemDirection? = nil
    ) throws -> StaveNote {
        let note = try factory.StaveNote(StaveNoteStruct(
            parsingKeys: keys,
            duration: duration,
            stemDirection: stemDirection
        ))
        _ = note.addModifier(chord, index: 0)
        return note
    }

    private func chordSymbolGClefWidth() -> Double {
        let point = 38 * (VexFont.scaleToPxFrom["pt"] ?? 1)
        return Glyph.getWidth(code: "gClef", point: point)
    }

    @discardableResult
    private func chordAddGlyphOrText(_ chord: ChordSymbol, _ text: String, modifier: SymbolModifier) -> ChordSymbol {
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
