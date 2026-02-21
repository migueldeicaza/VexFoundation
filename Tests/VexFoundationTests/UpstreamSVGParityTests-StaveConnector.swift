import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("StaveConnector.Single_Draw_Test__4px_Stave_Line_Thickness")
    func staveConnectorSingleDraw4pxStaveLineThicknessMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Single_Draw_Test__4px_Stave_Line_Thickness",
            width: 400,
            height: 300
        ) { _, context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: 10, y2: 120, width: 300)
            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            connector.thickness = 4
            _ = connector.setType(.singleLeft).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
        }
    }

    @Test("StaveConnector.Double_Draw_Test")
    func staveConnectorDoubleDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveConnector", test: "Double_Draw_Test", width: 400, height: 300) {
            _,
            context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: 10, y2: 120, width: 300)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.double).setContext(context)

            let line = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = line.setType(.singleLeft).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
            try line.draw()
        }
    }

    @Test("StaveConnector.Bold_Double_Line_Left_Draw_Test")
    func staveConnectorBoldDoubleLineLeftDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Bold_Double_Line_Left_Draw_Test",
            width: 400,
            height: 300
        ) { _, context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: 10, y2: 120, width: 300)
            _ = stave1.setBegBarType(.repeatBegin)
            _ = stave2.setBegBarType(.repeatBegin)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.boldDoubleLeft).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
        }
    }

    @Test("StaveConnector.Bold_Double_Line_Right_Draw_Test")
    func staveConnectorBoldDoubleLineRightDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Bold_Double_Line_Right_Draw_Test",
            width: 400,
            height: 300
        ) { _, context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: 10, y2: 120, width: 300)
            _ = stave1.setEndBarType(.repeatEnd)
            _ = stave2.setEndBarType(.repeatEnd)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.boldDoubleRight).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
        }
    }

    @Test("StaveConnector.Thin_Double_Line_Right_Draw_Test")
    func staveConnectorThinDoubleLineRightDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Thin_Double_Line_Right_Draw_Test",
            width: 400,
            height: 300
        ) { _, context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: 10, y2: 120, width: 300)
            _ = stave1.setEndBarType(.double)
            _ = stave2.setEndBarType(.double)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.thinDouble).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
        }
    }

    @Test("StaveConnector.Bold_Double_Lines_Overlapping_Draw_Test")
    func staveConnectorBoldDoubleLinesOverlappingDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Bold_Double_Lines_Overlapping_Draw_Test",
            width: 400,
            height: 300
        ) { _, context in
            let stave1 = Stave(x: 25, y: 10, width: 150)
            let stave2 = Stave(x: 25, y: 120, width: 150)
            let stave3 = Stave(x: 175, y: 10, width: 150)
            let stave4 = Stave(x: 175, y: 120, width: 150)
            [stave1, stave2, stave3, stave4].forEach { _ = $0.setContext(context) }

            _ = stave1.setEndBarType(.repeatEnd)
            _ = stave2.setEndBarType(.repeatEnd)
            _ = stave3.setEndBarType(.end)
            _ = stave4.setEndBarType(.end)

            _ = stave1.setBegBarType(.repeatBegin)
            _ = stave2.setBegBarType(.repeatBegin)
            _ = stave3.setBegBarType(.repeatBegin)
            _ = stave4.setBegBarType(.repeatBegin)

            let connector1 = StaveConnector(topStave: stave1, bottomStave: stave2)
            let connector2 = StaveConnector(topStave: stave1, bottomStave: stave2)
            let connector3 = StaveConnector(topStave: stave3, bottomStave: stave4)
            let connector4 = StaveConnector(topStave: stave3, bottomStave: stave4)
            [connector1, connector2, connector3, connector4].forEach { _ = $0.setContext(context) }
            _ = connector1.setType(.boldDoubleLeft)
            _ = connector2.setType(.boldDoubleRight)
            _ = connector3.setType(.boldDoubleLeft)
            _ = connector4.setType(.boldDoubleRight)

            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
            try connector1.draw()
            try connector2.draw()
            try connector3.draw()
            try connector4.draw()
        }
    }

    @Test("StaveConnector.Bold_Double_Lines_Offset_Draw_Test")
    func staveConnectorBoldDoubleLinesOffsetDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Bold_Double_Lines_Offset_Draw_Test",
            width: 400,
            height: 300
        ) { _, context in
            let stave1 = Stave(x: 25, y: 10, width: 150)
            let stave2 = Stave(x: 25, y: 120, width: 150)
            let stave3 = Stave(x: 185, y: 10, width: 150)
            let stave4 = Stave(x: 185, y: 120, width: 150)
            [stave1, stave2, stave3, stave4].forEach { _ = $0.setContext(context) }

            _ = stave1.addClef(.bass)
            _ = stave2.addClef(.alto)
            _ = stave3.addClef(.treble)
            _ = stave4.addClef(.tenor)
            _ = stave3.addKeySignature("Ab")
            _ = stave4.addKeySignature("Ab")
            _ = stave1.addTimeSignature(.meter(4, 4))
            _ = stave2.addTimeSignature(.meter(4, 4))
            _ = stave3.addTimeSignature(.meter(6, 8))
            _ = stave4.addTimeSignature(.meter(6, 8))

            _ = stave1.setEndBarType(.repeatEnd)
            _ = stave2.setEndBarType(.repeatEnd)
            _ = stave3.setEndBarType(.end)
            _ = stave4.setEndBarType(.end)

            _ = stave1.setBegBarType(.repeatBegin)
            _ = stave2.setBegBarType(.repeatBegin)
            _ = stave3.setBegBarType(.repeatBegin)
            _ = stave4.setBegBarType(.repeatBegin)

            let connector1 = StaveConnector(topStave: stave1, bottomStave: stave2)
            let connector2 = StaveConnector(topStave: stave1, bottomStave: stave2)
            let connector3 = StaveConnector(topStave: stave3, bottomStave: stave4)
            let connector4 = StaveConnector(topStave: stave3, bottomStave: stave4)
            let connector5 = StaveConnector(topStave: stave3, bottomStave: stave4)
            [connector1, connector2, connector3, connector4, connector5].forEach { _ = $0.setContext(context) }

            _ = connector1.setType(.boldDoubleLeft)
            _ = connector2.setType(.boldDoubleRight)
            _ = connector3.setType(.boldDoubleLeft)
            _ = connector4.setType(.boldDoubleRight)
            _ = connector5.setType(.singleLeft)

            _ = connector1.setXShift(stave1.getModifierXShift())
            _ = connector3.setXShift(stave3.getModifierXShift())

            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
            try connector1.draw()
            try connector2.draw()
            try connector3.draw()
            try connector4.draw()
            try connector5.draw()
        }
    }

    @Test("StaveConnector.Bold_Double_Lines_Offset_Draw_Test_2")
    func staveConnectorBoldDoubleLinesOffsetDrawTest2MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveConnector",
            test: "Bold_Double_Lines_Offset_Draw_Test_2",
            width: 400,
            height: 300
        ) { _, context in
            let stave1 = Stave(x: 25, y: 10, width: 150)
            let stave2 = Stave(x: 25, y: 120, width: 150)
            let stave3 = Stave(x: 175, y: 10, width: 150)
            let stave4 = Stave(x: 175, y: 120, width: 150)
            [stave1, stave2, stave3, stave4].forEach { _ = $0.setContext(context) }

            _ = stave1.addClef(.treble)
            _ = stave2.addClef(.bass)
            _ = stave3.addClef(.alto)
            _ = stave4.addClef(.treble)
            _ = stave1.addTimeSignature(.meter(4, 4))
            _ = stave2.addTimeSignature(.meter(4, 4))
            _ = stave3.addTimeSignature(.meter(6, 8))
            _ = stave4.addTimeSignature(.meter(6, 8))

            _ = stave1.setEndBarType(.repeatEnd)
            _ = stave2.setEndBarType(.repeatEnd)
            _ = stave3.setEndBarType(.end)
            _ = stave4.setEndBarType(.end)

            _ = stave1.setBegBarType(.repeatBegin)
            _ = stave2.setBegBarType(.repeatBegin)
            _ = stave3.setBegBarType(.repeatBegin)
            _ = stave4.setBegBarType(.repeatBegin)

            let connector1 = StaveConnector(topStave: stave1, bottomStave: stave2)
            let connector2 = StaveConnector(topStave: stave1, bottomStave: stave2)
            let connector3 = StaveConnector(topStave: stave3, bottomStave: stave4)
            let connector4 = StaveConnector(topStave: stave3, bottomStave: stave4)
            let connector5 = StaveConnector(topStave: stave3, bottomStave: stave4)
            [connector1, connector2, connector3, connector4, connector5].forEach { _ = $0.setContext(context) }

            _ = connector1.setType(.boldDoubleLeft)
            _ = connector2.setType(.boldDoubleRight)
            _ = connector3.setType(.boldDoubleLeft)
            _ = connector4.setType(.boldDoubleRight)
            _ = connector5.setType(.singleLeft)

            _ = connector1.setXShift(stave1.getModifierXShift())
            _ = connector3.setXShift(stave3.getModifierXShift())

            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
            try connector1.draw()
            try connector2.draw()
            try connector3.draw()
            try connector4.draw()
            try connector5.draw()
        }
    }

    @Test("StaveConnector.Brace_Draw_Test")
    func staveConnectorBraceDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveConnector", test: "Brace_Draw_Test", width: 450, height: 300) {
            _,
            context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 100, y1: 10, y2: 120, width: 300)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector
                .setType(.brace)
                .setContext(context)
                .setText("Piano")

            let line = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = line.setType(.singleLeft).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
            try line.draw()
        }
    }

    @Test("StaveConnector.Brace_Wide_Draw_Test")
    func staveConnectorBraceWideDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveConnector", test: "Brace_Wide_Draw_Test", width: 400, height: 300) {
            _,
            context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: -20, y2: 200, width: 300)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.brace).setContext(context)

            let line = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = line.setType(.singleLeft).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
            try line.draw()
        }
    }

    @Test("StaveConnector.Bracket_Draw_Test")
    func staveConnectorBracketDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveConnector", test: "Bracket_Draw_Test", width: 400, height: 300) {
            _,
            context in
            let (stave1, stave2) = makeUpstreamStaveConnectorPair(context: context, x: 25, y1: 10, y2: 120, width: 300)

            let connector = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = connector.setType(.bracket).setContext(context)

            let line = StaveConnector(topStave: stave1, bottomStave: stave2)
            _ = line.setType(.singleLeft).setContext(context)

            try stave1.draw()
            try stave2.draw()
            try connector.draw()
            try line.draw()
        }
    }

    @Test("StaveConnector.Combined_Draw_Test")
    func staveConnectorCombinedDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveConnector", test: "Combined_Draw_Test", width: 550, height: 700) {
            _,
            context in
            let stave1 = Stave(x: 150, y: 10, width: 300)
            let stave2 = Stave(x: 150, y: 100, width: 300)
            let stave3 = Stave(x: 150, y: 190, width: 300)
            let stave4 = Stave(x: 150, y: 280, width: 300)
            let stave5 = Stave(x: 150, y: 370, width: 300)
            let stave6 = Stave(x: 150, y: 460, width: 300)
            let stave7 = Stave(x: 150, y: 560, width: 300)
            _ = stave1.setText("Violin", position: .left)

            [stave1, stave2, stave3, stave4, stave5, stave6, stave7].forEach { _ = $0.setContext(context) }

            let connSingle = StaveConnector(topStave: stave1, bottomStave: stave7)
            let connDouble = StaveConnector(topStave: stave2, bottomStave: stave3)
            let connBracket = StaveConnector(topStave: stave4, bottomStave: stave7)
            let connNone = StaveConnector(topStave: stave4, bottomStave: stave5)
            let connBrace = StaveConnector(topStave: stave6, bottomStave: stave7)

            _ = connSingle.setType(.singleLeft)
            _ = connDouble.setType(.double)
            _ = connBracket.setType(.bracket)
            _ = connBrace.setType(.brace)
            _ = connBrace.setXShift(-5)

            _ = connDouble.setText("Piano")
            _ = connNone.setText("Multiple", shiftY: -15)
            _ = connNone.setText("Line Text", shiftY: 15)
            _ = connBrace.setText("Harpsichord")

            [connSingle, connDouble, connBracket, connNone, connBrace].forEach { _ = $0.setContext(context) }

            try stave1.draw()
            try stave2.draw()
            try stave3.draw()
            try stave4.draw()
            try stave5.draw()
            try stave6.draw()
            try stave7.draw()

            try connSingle.draw()
            try connDouble.draw()
            try connBracket.draw()
            try connNone.draw()
            try connBrace.draw()
        }
    }

    private func makeUpstreamStaveConnectorPair(
        context: SVGRenderContext,
        x: Double,
        y1: Double,
        y2: Double,
        width: Double
    ) -> (Stave, Stave) {
        let stave1 = Stave(x: x, y: y1, width: width)
        let stave2 = Stave(x: x, y: y2, width: width)
        _ = stave1.setContext(context)
        _ = stave2.setContext(context)
        return (stave1, stave2)
    }
}
