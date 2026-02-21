import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Stave.Factory_API")
    func staveFactoryAPIMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Factory_API", width: 900, height: 200) { factory, _ in
            let stave = factory.Stave(x: 300, y: 40, width: 300)
            _ = stave.setText("Violin", position: .left, options: StaveTextOptions(shiftY: -10))
            _ = stave.setText("2nd line", position: .left, options: StaveTextOptions(shiftY: 10))
            try factory.draw()
        }
    }

    @Test("Stave.Stave_Text_Test")
    func staveTextTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Stave_Text_Test", width: 900, height: 140) { _, context in
            let stave = Stave(x: 300, y: 10, width: 300)
            _ = stave.setText("Violin", position: .left)
            _ = stave.setText("Right Text", position: .right)
            _ = stave.setText("Above Text", position: .above)
            _ = stave.setText("Below Text", position: .below)
            _ = stave.setContext(context)
            try stave.draw()
        }
    }

    @Test("Stave.Multiple_Line_Stave_Text_Test")
    func staveMultipleLineStaveTextTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Multiple_Line_Stave_Text_Test", width: 900, height: 200) { _, context in
            let stave = Stave(x: 300, y: 40, width: 300)
            _ = stave.setText("Violin", position: .left, options: StaveTextOptions(shiftY: -10))
            _ = stave.setText("2nd line", position: .left, options: StaveTextOptions(shiftY: 10))
            _ = stave.setText("Right Text", position: .right, options: StaveTextOptions(shiftY: -10))
            _ = stave.setText("2nd line", position: .right, options: StaveTextOptions(shiftY: 10))
            _ = stave.setText("Above Text", position: .above, options: StaveTextOptions(shiftY: -10))
            _ = stave.setText("2nd line", position: .above, options: StaveTextOptions(shiftY: 10))
            _ = stave.setText(
                "Left Below Text",
                position: .below,
                options: StaveTextOptions(shiftY: -10, justification: .left)
            )
            _ = stave.setText(
                "Right Below Text",
                position: .below,
                options: StaveTextOptions(shiftY: 10, justification: .right)
            )
            _ = stave.setContext(context)
            try stave.draw()
        }
    }

    @Test("Stave.Multiple_Stave_Barline_Test")
    func staveMultipleStaveBarlineTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Multiple_Stave_Barline_Test", width: 550, height: 200) { _, context in
            try drawUpstreamMultipleStaveBarlineTest(context: context, sectionFontSize: nil)
        }
    }

    @Test("Stave.Multiple_Stave_Barline_Test__14pt_Section_")
    func staveMultipleStaveBarline14ptSectionTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Stave",
            test: "Multiple_Stave_Barline_Test__14pt_Section_",
            width: 550,
            height: 200
        ) { _, context in
            try drawUpstreamMultipleStaveBarlineTest(context: context, sectionFontSize: 14)
        }
    }

    @Test("Stave.Multiple_Stave_Repeats_Test")
    func staveMultipleStaveRepeatsTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Multiple_Stave_Repeats_Test", width: 750, height: 120) {
            _,
            context in
            let staveBar1 = Stave(x: 10, y: 0, width: 250)
            _ = staveBar1
                .setBegBarType(.repeatBegin)
                .setEndBarType(.repeatEnd)
                .addClef(.treble)
                .addKeySignature("A")
                .setContext(context)
            try staveBar1.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: try makeUpstreamStaveCommonQuarterBar())

            let staveBar2 = Stave(
                x: staveBar1.getWidth() + staveBar1.getX(),
                y: staveBar1.getY(),
                width: 250
            )
            _ = staveBar2
                .setBegBarType(.repeatBegin)
                .setEndBarType(.repeatEnd)
                .setContext(context)
            try staveBar2.draw()

            let notesBar2Part1 = try makeUpstreamMultipleStaveBarlineEighthRun()
            let notesBar2Part2 = try makeUpstreamMultipleStaveBarlineEighthRun()
            _ = notesBar2Part2[0].addModifier(try Accidental(parsing: "#"), index: 0)
            _ = notesBar2Part2[1].addModifier(try Accidental(parsing: "#"), index: 0)
            _ = notesBar2Part2[3].addModifier(try Accidental(parsing: "b"), index: 0)
            let notesBar2 = notesBar2Part1 + notesBar2Part2
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar2, notes: notesBar2)

            let beam1 = try Beam(notesBar2Part1.map { $0 as StemmableNote })
            _ = beam1.setContext(context)
            try beam1.draw()

            let beam2 = try Beam(notesBar2Part2.map { $0 as StemmableNote })
            _ = beam2.setContext(context)
            try beam2.draw()

            let staveBar3 = Stave(
                x: staveBar2.getWidth() + staveBar2.getX(),
                y: staveBar2.getY(),
                width: 50
            )
            _ = staveBar3.setContext(context)
            try staveBar3.draw()
            let notesBar3 = [
                try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/5"], duration: "wr")),
            ]
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar3, notes: notesBar3)

            let staveBar4 = Stave(
                x: staveBar3.getWidth() + staveBar3.getX(),
                y: staveBar3.getY(),
                width: 250 - staveBar1.getModifierXShift()
            )
            _ = staveBar4
                .setBegBarType(.repeatBegin)
                .setEndBarType(.repeatEnd)
                .setContext(context)
            try staveBar4.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar4, notes: try makeUpstreamStaveCommonQuarterBar())
        }
    }

    @Test("Stave.Stave_Repetition__CODA__Positioning")
    func staveRepetitionCodaPositioningMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Stave",
            test: "Stave_Repetition__CODA__Positioning",
            width: 725,
            height: 200
        ) { _, context in
            try drawUpstreamStaveRepetitionCODAPositioning(context: context, yShift: 0)
        }
    }

    @Test("Stave.Stave_Repetition__CODA__Positioning___20_")
    func staveRepetitionCodaPositioningNeg20MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Stave",
            test: "Stave_Repetition__CODA__Positioning___20_",
            width: 725,
            height: 200
        ) { _, context in
            try drawUpstreamStaveRepetitionCODAPositioning(context: context, yShift: -20)
        }
    }

    @Test("Stave.Stave_Repetition__CODA__Positioning___10_")
    func staveRepetitionCodaPositioningPos10MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Stave",
            test: "Stave_Repetition__CODA__Positioning___10_",
            width: 725,
            height: 200
        ) { _, context in
            try drawUpstreamStaveRepetitionCODAPositioning(context: context, yShift: 10)
        }
    }

    private func drawUpstreamMultipleStaveBarlineTest(context: SVGRenderContext, sectionFontSize: Double?) throws {
        let staveBar1 = Stave(x: 10, y: 50, width: 200)
        _ = staveBar1
            .setBegBarType(.repeatBegin)
            .setEndBarType(.double)
            .setSection("A", y: 0, xOffset: 0, fontSize: sectionFontSize, drawRect: false)
            .addClef(.treble)
            .setContext(context)
        try staveBar1.draw()

        let notesBar1 = try makeUpstreamMultipleStaveBarlineNotesBar1()
        try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: notesBar1)

        let staveBar2 = Stave(
            x: staveBar1.getWidth() + staveBar1.getX(),
            y: staveBar1.getY(),
            width: 300
        )
        _ = staveBar2
            .setSection("B", y: 0, xOffset: 0, fontSize: sectionFontSize)
            .setEndBarType(.end)
            .setContext(context)
        try staveBar2.draw()

        let notesBar2Part1 = try makeUpstreamMultipleStaveBarlineEighthRun()
        let notesBar2Part2 = try makeUpstreamMultipleStaveBarlineEighthRun()
        let notesBar2 = notesBar2Part1 + notesBar2Part2

        try Formatter.FormatAndDraw(ctx: context, stave: staveBar2, notes: notesBar2)

        let beam1 = try Beam(notesBar2Part1.map { $0 as StemmableNote })
        _ = beam1.setContext(context)
        try beam1.draw()

        let beam2 = try Beam(notesBar2Part2.map { $0 as StemmableNote })
        _ = beam2.setContext(context)
        try beam2.draw()
    }

    private func makeUpstreamMultipleStaveBarlineNotesBar1() throws -> [StaveNote] {
        [
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "g/4"], duration: "q")),
        ]
    }

    private func makeUpstreamMultipleStaveBarlineEighthRun() throws -> [StaveNote] {
        [
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "8")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "8")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "8")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4"], duration: "8")),
        ]
    }

    private func makeUpstreamStaveCommonQuarterBar() throws -> [StaveNote] {
        [
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "g/4"], duration: "q")),
        ]
    }

    private func drawUpstreamStaveRepetitionCODAPositioning(context: SVGRenderContext, yShift: Double) throws {
        let mm1 = Stave(x: 10, y: 50, width: 150)
        _ = mm1
            .addClef(.treble)
            .setRepetitionType(.dsAlFine, yShift: yShift)
            .setMeasure(1)
            .setContext(context)
        try mm1.draw()
        try Formatter.FormatAndDraw(ctx: context, stave: mm1, notes: try makeUpstreamStaveRepetitionQuarterBar())

        let mm2 = Stave(x: mm1.getWidth() + mm1.getX(), y: mm1.getY(), width: 150)
        _ = mm2
            .setRepetitionType(.toCoda, yShift: yShift)
            .setMeasure(2)
            .setContext(context)
        try mm2.draw()
        try Formatter.FormatAndDraw(ctx: context, stave: mm2, notes: try makeUpstreamStaveRepetitionQuarterBar())

        let mm3 = Stave(x: mm2.getWidth() + mm2.getX(), y: mm1.getY(), width: 150)
        _ = mm3
            .setRepetitionType(.dsAlCoda, yShift: yShift)
            .setMeasure(3)
            .setContext(context)
        try mm3.draw()
        try Formatter.FormatAndDraw(ctx: context, stave: mm3, notes: try makeUpstreamStaveRepetitionQuarterBar())

        let mm4 = Stave(x: mm3.getWidth() + mm3.getX(), y: mm1.getY(), width: 150)
        _ = mm4
            .setRepetitionType(.codaLeft, yShift: yShift)
            .setMeasure(4)
            .setContext(context)
        try mm4.draw()
        try Formatter.FormatAndDraw(ctx: context, stave: mm4, notes: try makeUpstreamStaveRepetitionQuarterBar())
    }

    private func makeUpstreamStaveRepetitionQuarterBar() throws -> [StaveNote] {
        [
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4"], duration: "q")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/4"], duration: "q")),
        ]
    }
}
