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

    @Test("Stave.Stave_End_Modifiers_Test")
    func staveEndModifiersTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Stave_End_Modifiers_Test", width: 800, height: 700) {
            _,
            context in
            let staveWidth = 230.0
            let blockHeight = 80.0
            var x = 10.0
            var y = 0.0

            func drawStavesInTwoLines(_ endBarLine: BarlineType) throws {
                try drawUpstreamEndModifierStave(
                    context: context,
                    x: x,
                    y: y,
                    width: staveWidth + 50,
                    beginBarLine: .repeatBegin,
                    beginClef: .treble,
                    beginKeySignature: "A",
                    endBarLine: endBarLine,
                    endClef: .bass
                )
                x += staveWidth + 50

                try drawUpstreamEndModifierStave(
                    context: context,
                    x: x,
                    y: y,
                    width: staveWidth,
                    beginBarLine: .repeatBegin,
                    endBarLine: endBarLine,
                    endKeySignature: "E"
                )
                x += staveWidth

                try drawUpstreamEndModifierStave(
                    context: context,
                    x: x,
                    y: y,
                    width: staveWidth,
                    beginBarLine: .repeatBegin,
                    endBarLine: endBarLine,
                    endTimeSignature: .meter(2, 4)
                )
                x = 10
                y += blockHeight

                try drawUpstreamEndModifierStave(
                    context: context,
                    x: x,
                    y: y,
                    width: staveWidth,
                    beginBarLine: .repeatBegin,
                    endBarLine: endBarLine,
                    endClef: .bass,
                    endTimeSignature: .meter(2, 4)
                )
                x += staveWidth

                try drawUpstreamEndModifierStave(
                    context: context,
                    x: x,
                    y: y,
                    width: staveWidth,
                    beginBarLine: .repeatBegin,
                    endBarLine: endBarLine,
                    endClef: .treble,
                    endKeySignature: "Ab"
                )
                x += staveWidth

                try drawUpstreamEndModifierStave(
                    context: context,
                    x: x,
                    y: y,
                    width: staveWidth,
                    beginBarLine: .repeatBegin,
                    endBarLine: endBarLine,
                    endClef: .bass,
                    endKeySignature: "Ab",
                    endTimeSignature: .meter(2, 4)
                )
                x += staveWidth
            }

            y = 0
            x = 10
            try drawStavesInTwoLines(.single)
            y += blockHeight + 10
            x = 10
            try drawStavesInTwoLines(.double)
            y += blockHeight + 10
            x = 10
            try drawStavesInTwoLines(.repeatEnd)
            y += blockHeight + 10
            x = 10
            try drawStavesInTwoLines(.repeatBoth)
        }
    }

    @Test("Stave.Multiple_Staves_Volta_Test")
    func staveMultipleStavesVoltaTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Multiple_Staves_Volta_Test", width: 725, height: 200) {
            _,
            context in
            let mm1 = Stave(x: 10, y: 50, width: 125)
            _ = mm1
                .setBegBarType(.repeatBegin)
                .setRepetitionType(.segnoLeft)
                .addClef(.treble)
                .addKeySignature("A")
                .setMeasure(1)
                .setSection("A", y: 0)
                .setContext(context)
            try mm1.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm1, notes: try makeUpstreamVoltaNote("c/4"))

            let mm2 = Stave(x: mm1.getWidth() + mm1.getX(), y: mm1.getY(), width: 60)
            _ = mm2
                .setRepetitionType(.codaRight)
                .setMeasure(2)
                .setContext(context)
            try mm2.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm2, notes: try makeUpstreamVoltaNote("d/4"))

            let mm3 = Stave(x: mm2.getWidth() + mm2.getX(), y: mm1.getY(), width: 60)
            _ = mm3
                .setVoltaType(.begin, number: "1.", yShift: -5)
                .setMeasure(3)
                .setContext(context)
            try mm3.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm3, notes: try makeUpstreamVoltaNote("e/4"))

            let mm4 = Stave(x: mm3.getWidth() + mm3.getX(), y: mm1.getY(), width: 60)
            _ = mm4
                .setVoltaType(.mid, number: "", yShift: -5)
                .setMeasure(4)
                .setContext(context)
            try mm4.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm4, notes: try makeUpstreamVoltaNote("f/4"))

            let mm5 = Stave(x: mm4.getWidth() + mm4.getX(), y: mm1.getY(), width: 60)
            _ = mm5
                .setEndBarType(.repeatEnd)
                .setVoltaType(.end, number: "", yShift: -5)
                .setMeasure(5)
                .setContext(context)
            try mm5.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm5, notes: try makeUpstreamVoltaNote("g/4"))

            let mm6 = Stave(x: mm5.getWidth() + mm5.getX(), y: mm1.getY(), width: 60)
            _ = mm6
                .setVoltaType(.beginEnd, number: "2.", yShift: -5)
                .setEndBarType(.double)
                .setMeasure(6)
                .setContext(context)
            try mm6.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm6, notes: try makeUpstreamVoltaNote("a/4"))

            let mm7 = Stave(x: mm6.getWidth() + mm6.getX(), y: mm1.getY(), width: 60)
            _ = mm7
                .setMeasure(7)
                .setSection("B", y: 0)
                .setContext(context)
            try mm7.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm7, notes: try makeUpstreamVoltaNote("b/4"))

            let mm8 = Stave(x: mm7.getWidth() + mm7.getX(), y: mm1.getY(), width: 60)
            _ = mm8
                .setEndBarType(.double)
                .setRepetitionType(.dsAlCoda)
                .setMeasure(8)
                .setContext(context)
            try mm8.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm8, notes: try makeUpstreamVoltaNote("c/5"))

            let mm9 = Stave(x: mm8.getWidth() + mm8.getX() + 20, y: mm1.getY(), width: 125)
            _ = mm9
                .setEndBarType(.end)
                .setRepetitionType(.codaLeft)
                .addClef(.treble)
                .addKeySignature("A")
                .setMeasure(9)
                .setContext(context)
            try mm9.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm9, notes: try makeUpstreamVoltaNote("d/5"))
        }
    }

    @Test("Stave.Volta___Modifier_Measure_Test")
    func staveVoltaModifierMeasureTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Stave",
            test: "Volta___Modifier_Measure_Test",
            width: 1100,
            height: 200
        ) { _, context in
            let mm1 = Stave(x: 10, y: 50, width: 175)
            _ = mm1
                .setBegBarType(.repeatBegin)
                .setVoltaType(.beginEnd, number: "1.", yShift: -5)
                .addClef(.treble)
                .addKeySignature("A")
                .setMeasure(1)
                .setSection("A", y: 0)
                .setContext(context)
            try mm1.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm1, notes: try makeUpstreamVoltaNote("c/4"))

            let mm2 = Stave(x: mm1.getX() + mm1.getWidth(), y: mm1.getY(), width: 175)
            _ = mm2
                .setBegBarType(.repeatBegin)
                .setRepetitionType(.ds)
                .setVoltaType(.begin, number: "2.", yShift: -5)
                .addClef(.treble)
                .addKeySignature("A")
                .setMeasure(2)
                .setContext(context)
            try mm2.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm2, notes: try makeUpstreamVoltaNote("c/4"))

            let mm3 = Stave(x: mm2.getX() + mm2.getWidth(), y: mm2.getY(), width: 175)
            _ = mm3
                .setVoltaType(.mid, number: "", yShift: -5)
                .setRepetitionType(.ds)
                .addClef(.treble)
                .addKeySignature("B")
                .setMeasure(3)
                .setSection("B", y: 0)
                .setContext(context)
            try mm3.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm3, notes: try makeUpstreamVoltaNote("c/4"))

            let mm4 = Stave(x: mm3.getX() + mm3.getWidth(), y: mm3.getY(), width: 175)
            _ = mm4
                .setVoltaType(.end, number: "1.", yShift: -5)
                .setRepetitionType(.ds)
                .addClef(.treble)
                .addKeySignature("A")
                .setMeasure(4)
                .setSection("C", y: 0)
                .setContext(context)
            try mm4.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm4, notes: try makeUpstreamVoltaNote("c/4"))

            let mm5 = Stave(x: mm4.getX() + mm4.getWidth(), y: mm4.getY(), width: 175)
            _ = mm5
                .setEndBarType(.double)
                .setRepetitionType(.ds)
                .addClef(.treble)
                .addKeySignature("A")
                .setMeasure(5)
                .setSection("D", y: 0)
                .setContext(context)
            try mm5.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm5, notes: try makeUpstreamVoltaNote("c/4"))

            let mm6 = Stave(x: mm5.getX() + mm5.getWidth(), y: mm5.getY(), width: 175)
            _ = mm6
                .setRepetitionType(.ds)
                .setMeasure(6)
                .setSection("E", y: 0)
                .setContext(context)
            try mm6.draw()
            try Formatter.FormatAndDraw(ctx: context, stave: mm6, notes: try makeUpstreamVoltaNote("c/4"))
        }
    }

    @Test("Stave.Tempo_Test")
    func staveTempoTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Stave", test: "Tempo_Test", width: 725, height: 350) { _, context in
            let padding = 10.0
            var x = 0.0
            var y = 50.0

            func drawTempoStaveBar(
                _ width: Double,
                _ tempo: StaveTempoOptions,
                _ tempoY: Double = 0,
                _ notes: [StaveNote]? = nil
            ) throws {
                let staveBar = Stave(x: padding + x, y: y, width: width)
                if x == 0 {
                    _ = staveBar.addClef(.treble)
                }
                _ = staveBar
                    .setTempo(tempo, y: tempoY)
                    .setContext(context)
                try staveBar.draw()

                let notesBar = try notes ?? makeUpstreamStaveCommonQuarterBar()
                try Formatter.FormatAndDraw(ctx: context, stave: staveBar, notes: notesBar)
                x += width
            }

            try drawTempoStaveBar(
                120,
                try StaveTempoOptions(bpm: 80, duration: "q", dots: 1)
            )
            try drawTempoStaveBar(
                100,
                try StaveTempoOptions(bpm: 90, duration: "8", dots: 2)
            )
            try drawTempoStaveBar(
                100,
                try StaveTempoOptions(bpm: 96, duration: "16", dots: 1)
            )
            try drawTempoStaveBar(
                100,
                try StaveTempoOptions(bpm: 70, duration: "32")
            )
            try drawTempoStaveBar(
                250,
                StaveTempoOptions(bpm: 120, name: "Andante"),
                -20,
                try [
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/5"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4"], duration: "8")),
                ]
            )

            x = 0
            y += 150

            try drawTempoStaveBar(
                120,
                try StaveTempoOptions(bpm: 80, duration: "w")
            )
            try drawTempoStaveBar(
                100,
                try StaveTempoOptions(bpm: 90, duration: "h")
            )
            try drawTempoStaveBar(
                100,
                try StaveTempoOptions(bpm: 96, duration: "q")
            )
            try drawTempoStaveBar(
                100,
                try StaveTempoOptions(bpm: 70, duration: "8")
            )
            try drawTempoStaveBar(
                250,
                StaveTempoOptions(name: "Andante grazioso"),
                0,
                try [
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4"], duration: "8")),
                    StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4"], duration: "8")),
                ]
            )
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

    private func drawUpstreamEndModifierStave(
        context: SVGRenderContext,
        x: Double,
        y: Double,
        width: Double,
        beginBarLine: BarlineType? = nil,
        beginClef: ClefName? = nil,
        beginKeySignature: String? = nil,
        beginTimeSignature: TimeSignatureSpec? = nil,
        endBarLine: BarlineType? = nil,
        endClef: ClefName? = nil,
        endKeySignature: String? = nil,
        endTimeSignature: TimeSignatureSpec? = nil
    ) throws {
        let staveBar = Stave(x: x, y: y, width: width - 10)

        if let beginBarLine {
            _ = staveBar.setBegBarType(beginBarLine)
        }
        if let beginClef {
            _ = staveBar.addClef(beginClef)
        }
        if let beginKeySignature {
            _ = staveBar.addKeySignature(beginKeySignature)
        }
        if let beginTimeSignature {
            _ = staveBar.setTimeSignature(beginTimeSignature)
        }

        if let endBarLine {
            _ = staveBar.setEndBarType(endBarLine)
        }
        if let endClef {
            _ = staveBar.addEndClef(endClef)
        }
        if let endKeySignature {
            _ = staveBar.setEndKeySignature(endKeySignature)
        }
        if let endTimeSignature {
            _ = staveBar.setEndTimeSignature(endTimeSignature)
        }

        _ = staveBar.setContext(context)
        try staveBar.draw()

        try Formatter.FormatAndDraw(
            ctx: context,
            stave: staveBar,
            notes: makeUpstreamStaveCommonQuarterBar()
        )
    }

    private func makeUpstreamVoltaNote(_ key: String) throws -> [StaveNote] {
        [
            try StaveNote(validating: StaveNoteStruct(parsingKeys: [key], duration: "w")),
        ]
    }
}
