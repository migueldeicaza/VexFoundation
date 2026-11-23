import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("ChordSymbol.Bounding_Box")
    func chordSymbolBoundingBoxMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Bounding_Box", width: 750, height: 580) { factory, context in
            try drawChordSymbolWithModifiers(factory, context, drawBoundingBox: true)
        }
    }

    @Test("ChordSymbol.Chord_Symbol_With_Modifiers")
    func chordSymbolWithModifiersMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Chord_Symbol_With_Modifiers", width: 750, height: 580) { factory, context in
            try drawChordSymbolWithModifiers(factory, context, drawBoundingBox: false)
        }
    }

    /// Upstream `withModifiers`; `drawBoundingBox` draws each chord symbol box after its row.
    private func drawChordSymbolWithModifiers(
        _ factory: Factory,
        _ context: SVGRenderContext,
        drawBoundingBox: Bool
    ) throws {
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

            let stave = factory.Stave(x: 10, y: y, width: staffWidth).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()
            try voice.draw(context: context, stave: stave)
        }

        var chords: [ChordSymbol] = [
            makeChordSymbol(factory, fontSize: 10)
                .addText("F7")
                .addGlyph("leftParenTall")
                .addGlyphOrText("b9", symbolModifier: .sup)
                .addGlyphOrText("#11", symbolModifier: .sub)
                .addGlyph("rightParenTall"),
            makeChordSymbol(factory, fontSize: 12)
                .addText("F7")
                .addGlyphOrText("b9", symbolModifier: .sup)
                .addGlyphOrText("#11", symbolModifier: .sub),
            makeChordSymbol(factory, fontSize: 14)
                .addText("F7")
                .addGlyph("leftParenTall")
                .addGlyphOrText("add 3", symbolModifier: .sup)
                .addGlyphOrText("omit 9", symbolModifier: .sub)
                .addGlyph("rightParenTall"),
            makeChordSymbol(factory, fontSize: 16)
                .addText("F7")
                .addGlyph("leftParenTall")
                .addGlyphOrText("b9", symbolModifier: .sup)
                .addGlyphOrText("#11", symbolModifier: .sub)
                .addGlyph("rightParenTall"),
        ]
        try drawRow(chords, y: 40)
        if drawBoundingBox { drawUpstreamBoundingBoxes(context, chords) }

        chords = [
            makeChordSymbol(factory, fontSize: 10)
                .setFontSize(10)
                .addText("F7")
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub),
            makeChordSymbol(factory, fontSize: 12)
                .addText("F7")
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub),
            makeChordSymbol(factory, fontSize: 14)
                .addText("F7")
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub),
            makeChordSymbol(factory, fontSize: 16)
                .setFontSize(16)
                .addText("F7")
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub),
        ]
        try drawRow(chords, y: 140)
        if drawBoundingBox { drawUpstreamBoundingBoxes(context, chords) }

        chords = [
            makeChordSymbol(factory, fontSize: 10).addGlyphOrText("Ab").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
            makeChordSymbol(factory, fontSize: 14).addGlyphOrText("C#").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
            makeChordSymbol(factory, fontSize: 16).addGlyphOrText("Ab").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
            makeChordSymbol(factory, fontSize: 18).addGlyphOrText("C#").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
        ]
        try drawRow(chords, y: 240)
        if drawBoundingBox { drawUpstreamBoundingBoxes(context, chords) }
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
                try factory.draw()
            }

            var chords: [ChordSymbol] = [
                makeChordSymbol(factory, fontSize: 10)
                    .addText("F7")
                    .addGlyph("leftParenTall")
                    .addGlyphOrText("b9", symbolModifier: .sup)
                    .addGlyphOrText("#11", symbolModifier: .sub)
                    .addGlyph("rightParenTall"),
                makeChordSymbol(factory, fontSize: 12)
                    .addText("F7")
                    .addGlyphOrText("b9", symbolModifier: .sup)
                    .addGlyphOrText("#11", symbolModifier: .sub),
                makeChordSymbol(factory, fontSize: 14)
                    .addText("F7")
                    .addGlyph("leftParenTall")
                    .addGlyphOrText("add 3", symbolModifier: .sup)
                    .addGlyphOrText("omit 9", symbolModifier: .sub)
                    .addGlyph("rightParenTall"),
                makeChordSymbol(factory, fontSize: 16)
                    .addText("F7")
                    .addGlyph("leftParenTall")
                    .addGlyphOrText("b9", symbolModifier: .sup)
                    .addGlyphOrText("#11", symbolModifier: .sub)
                    .addGlyph("rightParenTall"),
            ]
            try drawRow(chords, y: 40)

            chords = [
                makeChordSymbol(factory, fontSize: 10)
                    .setFontSize(10)
                    .addText("F7")
                    .addGlyphOrText("#11", symbolModifier: .sup)
                    .addGlyphOrText("b9", symbolModifier: .sub),
                makeChordSymbol(factory, fontSize: 12)
                    .addText("F7")
                    .addGlyphOrText("#11", symbolModifier: .sup)
                    .addGlyphOrText("b9", symbolModifier: .sub),
                makeChordSymbol(factory, fontSize: 14)
                    .addText("F7")
                    .addGlyphOrText("#11", symbolModifier: .sup)
                    .addGlyphOrText("b9", symbolModifier: .sub),
                makeChordSymbol(factory, fontSize: 16)
                    .setFontSize(16)
                    .addText("F7")
                    .addGlyphOrText("#11", symbolModifier: .sup)
                    .addGlyphOrText("b9", symbolModifier: .sub),
            ]
            try drawRow(chords, y: 140)

            chords = [
                makeChordSymbol(factory, fontSize: 10).addGlyphOrText("Ab").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
                makeChordSymbol(factory, fontSize: 14).addGlyphOrText("C#").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
                makeChordSymbol(factory, fontSize: 16).addGlyphOrText("Ab").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
                makeChordSymbol(factory, fontSize: 18).addGlyphOrText("C#").addGlyphOrText("7(#11b9)", symbolModifier: .sup),
            ]
            try drawRow(chords, y: 240)
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
                let stave = factory.Stave(x: 10, y: y, width: 450).addClef(.treble)
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
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory, hJustify: .left).addText("C").addGlyph("halfDiminished", symbolModifier: .sup),
                makeChordSymbol(factory).addText("D").addGlyph("halfDiminished", symbolModifier: .sup),
            ]
            try drawRow(chords, y: 10)

            chords = [
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("dim"),
                makeChordSymbol(factory).addText("A").addGlyphSuperscript("+").addTextSuperscript("5"),
                makeChordSymbol(factory).addText("G").addGlyphSuperscript("+").addTextSuperscript("5"),
            ]
            try drawRow(chords, y: 110)

            chords = [
                makeChordSymbol(factory).addText("A").addGlyph("-"),
                makeChordSymbol(factory).addText("E").addGlyph("-"),
                makeChordSymbol(factory).addText("A").addGlyphOrText("(#11)", symbolModifier: .sup),
                makeChordSymbol(factory).addText("E").addGlyphOrText("(#9)", symbolModifier: .sup),
            ]
            try drawRow(chords, y: 210)

            chords = [
                makeChordSymbol(factory).addGlyphOrText("F/B").addGlyphOrText("b", symbolModifier: .sup),
                makeChordSymbol(factory).addText("E").addGlyphOrText("V/V"),
                makeChordSymbol(factory).addText("A").addGlyphOrText("(#11)", symbolModifier: .sup),
                makeChordSymbol(factory).addText("E").addGlyphOrText("(#9)", symbolModifier: .sup),
            ]
            try drawRow(chords, y: 310)
        }
    }

    @Test("ChordSymbol.Top_Chord_Symbols")
    func chordSymbolTopMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Top_Chord_Symbols", width: 650 * 1.5, height: 650) { factory, context in
            _ = context.scale(1.5, 1.5)

            func draw(_ c1: ChordSymbol, _ c2: ChordSymbol, y: Double) throws {
                let stave = factory.Stave(x: 10, y: y, width: 450).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()
                let note1 = try chordSymbolNote(factory, ["e/4", "a/4", "d/5"], "h", c1, stemDirection: .up)
                    .addModifier(factory.Accidental(type: .flat), index: 0)
                let note2 = try chordSymbolNote(factory, ["c/5", "e/5", "c/6"], "h", c2, stemDirection: .down)
                let score = factory.EasyScore()
                let voice = score.voice([note1, note2].map { $0 as Note }, time: .meter(4, 4))
                _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                try factory.draw()
            }

            var chord1 = makeChordSymbol(factory).addText("F7").setHorizontal(.left)
                .addGlyphOrText("(#11b9)", symbolModifier: .sup)
            var chord2 = makeChordSymbol(factory).addText("C").setHorizontal(.left).addGlyphSuperscript("majorSeventh")
            try draw(chord1, chord2, y: 40)

            chord1 = makeChordSymbol(factory)
                .addText("F7")
                .addTextSuperscript("(")
                .addGlyphOrText("#11b9", symbolModifier: .sup)
                .addTextSuperscript(")")
            chord2 = makeChordSymbol(factory).addText("C").setHorizontal(.left).addTextSuperscript("Maj.")
            try draw(chord1, chord2, y: 140)

            chord1 = makeChordSymbol(factory)
                .addText("F7")
                .setHorizontal(.left)
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub)
            chord2 = makeChordSymbol(factory).addText("C").addTextSuperscript("sus4")
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
                .addGlyphOrText("(#11b9)", symbolModifier: .sup)
            var chord2 = makeChordSymbol(factory, hJustify: .left).addText("C").addGlyphSuperscript("majorSeventh")
            try draw(chord1, chord2, y: 40)

            chord1 = makeChordSymbol(factory, hJustify: .center)
                .addText("F7")
                .setHorizontal(.left)
                .addGlyphOrText("(#11b9)", symbolModifier: .sup)
            chord2 = makeChordSymbol(factory, hJustify: .center).addText("C").addTextSuperscript("Maj.")
            try draw(chord1, chord2, y: 140)

            chord1 = makeChordSymbol(factory, hJustify: .right)
                .addText("F7")
                .setHorizontal(.left)
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub)
            chord2 = makeChordSymbol(factory, hJustify: .right).addText("C").addTextSuperscript("Maj.")
            try draw(chord1, chord2, y: 240)

            chord1 = makeChordSymbol(factory, hJustify: .left)
                .addText("F7")
                .setHorizontal(.left)
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub)
            chord2 = makeChordSymbol(factory, hJustify: .centerStem).addText("C").addTextSuperscript("Maj.")
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
                makeChordSymbol(factory, vJustify: .bottom).addLine(),
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
                makeChordSymbol(factory, vJustify: .bottom).addLine(),
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
                makeChordSymbol(factory, vJustify: .bottom).addLine(),
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

    @Test("ChordSymbol.Wide_Chord_Symbols")
    func chordSymbolWideMatchesUpstream() throws {
        // VexFlow 5.6.0: a left-justified extension can extend beyond the last barline. Keep its ink on the page.
        let pageWidth = 370.0
        try runCategorySVGParityCase(module: "ChordSymbol", test: "Wide_Chord_Symbols", width: pageWidth * 1.5, height: 680) { factory, context in
            _ = context.scale(1.5, 1.5)

            func drawRow(_ chord1: ChordSymbol, _ chord2: ChordSymbol, y: Double) throws {
                let stave = Stave(x: 10, y: y, width: 250).addClef(.treble)
                _ = stave.setContext(context)
                try stave.drawWithStyle()

                let notes: [StaveNote] = [
                    try chordSymbolNote(factory, ["e/4", "a/4", "d/5"], "h", chord1)
                        .addModifier(Accidental(.flat), index: 0),
                    try chordSymbolNote(factory, ["c/4", "e/4", "B/4"], "h", chord2),
                ]
                _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            }

            var chord1 = makeChordSymbol(factory)
                .addText("FrogToad7")
                .setHorizontal(.left)
                .addGlyphOrText("(#11b9)", symbolModifier: .sup)
            var chord2 = makeChordSymbol(factory, hJustify: .left)
                .addText("CToShiningC")
                .addGlyphSuperscript("majorSeventh")
            try drawRow(chord1, chord2, y: 40)

            chord1 = makeChordSymbol(factory, hJustify: .right)
                .addText("FrogToad7")
                .setHorizontal(.left)
                .addGlyphOrText("#11", symbolModifier: .sup)
                .addGlyphOrText("b9", symbolModifier: .sub)
            chord2 = makeChordSymbol(factory, hJustify: .left)
                .addText("CToShiningC")
                .addTextSuperscript("Maj.")
            try drawRow(chord1, chord2, y: 240)
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
        hJustify: ChordSymbolHorizontalJustify = .center
    ) -> ChordSymbol {
        factory.ChordSymbol(vJustify: vJustify, hJustify: hJustify, fontSize: fontSize)
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

    /// Upstream 5.0 `getGlyphWidth(0xe050 /*gClef*/)`: the glyph width in the current music font.
    private func chordSymbolGClefWidth() -> Double {
        let el = VexElement()
        el.setText(Glyphs.gClef)
        return el.getWidth()
    }
}
