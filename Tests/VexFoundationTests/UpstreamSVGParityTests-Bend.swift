import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Bend.Double_Bends")
    func bendDoubleBendsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Bend",
            test: "Double_Bends",
            width: 500,
            height: 240,
            signatureEpsilonOverride: 0.006
        ) { _, context in
            _ = context.scale(1.5, 1.5)
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let note0 = TabNote(TabNoteStruct(
                positions: [
                    TabNotePosition(str: 2, fret: 10),
                    TabNotePosition(str: 4, fret: 9),
                ],
                duration: .quarter
            ))
            _ = note0.addModifier(Bend("Full"), index: 0)
            _ = note0.addModifier(Bend("1/2"), index: 1)

            let note1 = TabNote(TabNoteStruct(
                positions: [
                    TabNotePosition(str: 2, fret: 5),
                    TabNotePosition(str: 3, fret: 5),
                ],
                duration: .quarter
            ))
            _ = note1.addModifier(Bend("1/4"), index: 0)
            _ = note1.addModifier(Bend("1/4"), index: 1)

            let note2 = TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 7)],
                duration: .half
            ))

            let notes = [note0, note1, note2]
            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            notes.forEach { drawUpstreamBendNoteMetrics(context: context, note: $0, yPos: 140) }
        }
    }

    @Test("Bend.Double_Bends_With_Release")
    func bendDoubleBendsWithReleaseMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Bend",
            test: "Double_Bends_With_Release",
            width: 550,
            height: 240,
            signatureEpsilonOverride: 0.006
        ) { _, context in
            _ = context.scale(1.0, 1.0)
            _ = context.setBackgroundFillStyle("#FFF")
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 550).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let note0 = TabNote(TabNoteStruct(
                positions: [
                    TabNotePosition(str: 1, fret: 10),
                    TabNotePosition(str: 4, fret: 9),
                ],
                duration: .quarter
            ))
            _ = note0.addModifier(Bend("1/2", release: true), index: 0)
            _ = note0.addModifier(Bend("Full", release: true), index: 1)

            let note1 = TabNote(TabNoteStruct(
                positions: [
                    TabNotePosition(str: 2, fret: 5),
                    TabNotePosition(str: 3, fret: 5),
                    TabNotePosition(str: 4, fret: 5),
                ],
                duration: .quarter
            ))
            _ = note1.addModifier(Bend("1/4", release: true), index: 0)
            _ = note1.addModifier(Bend("Monstrous", release: true), index: 1)
            _ = note1.addModifier(Bend("1/4", release: true), index: 2)

            let note2 = TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 7)],
                duration: .quarter
            ))
            let note3 = TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 7)],
                duration: .quarter
            ))

            let notes = [note0, note1, note2, note3]
            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            notes.forEach { drawUpstreamBendNoteMetrics(context: context, note: $0, yPos: 140) }
        }
    }

    @Test("Bend.Reverse_Bends")
    func bendReverseBendsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Bend",
            test: "Reverse_Bends",
            width: 500,
            height: 240,
            signatureEpsilonOverride: 0.006
        ) { _, context in
            _ = context.scale(1.5, 1.5)
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let notes = [
                TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 2, fret: 10),
                        TabNotePosition(str: 4, fret: 9),
                    ],
                    duration: .whole
                ))
                    .addModifier(Bend("Full"), index: 1)
                    .addModifier(Bend("1/2"), index: 0),
                TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 2, fret: 5),
                        TabNotePosition(str: 3, fret: 5),
                    ],
                    duration: .whole
                ))
                    .addModifier(Bend("1/4"), index: 1)
                    .addModifier(Bend("1/4"), index: 0),
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 4, fret: 7)],
                    duration: .whole
                )),
            ]

            for (index, note) in notes.enumerated() {
                let modifierContext = ModifierContext()
                _ = note.addToModifierContext(modifierContext)
                _ = TickContext().addTickable(note).preFormat().setX(Double(index) * 75)
                _ = note.setStave(stave).setContext(context)
                try note.draw()
                drawUpstreamBendNoteMetrics(context: context, note: note, yPos: 140)
            }
        }
    }

    @Test("Bend.Bend_Phrase")
    func bendPhraseMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Bend",
            test: "Bend_Phrase",
            width: 500,
            height: 240,
            signatureEpsilonOverride: 0.006
        ) { _, context in
            _ = context.scale(1.5, 1.5)
            _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "\(VexFont.SIZE)pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let phrase = [
                BendPhrase(type: Bend.UP, text: "Full"),
                BendPhrase(type: Bend.DOWN, text: "Monstrous"),
                BendPhrase(type: Bend.UP, text: "1/2"),
                BendPhrase(type: Bend.DOWN, text: ""),
            ]
            let bend = Bend("", phrase: phrase).setContext(context)

            let notes = [
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10)],
                    duration: .whole
                ))
                    .addModifier(bend, index: 0),
            ]

            for (index, note) in notes.enumerated() {
                let modifierContext = ModifierContext()
                _ = note.addToModifierContext(modifierContext)
                _ = TickContext().addTickable(note).preFormat().setX(Double(index) * 75)
                _ = note.setStave(stave).setContext(context)
                try note.draw()
                drawUpstreamBendNoteMetrics(context: context, note: note, yPos: 140)
            }
        }
    }

    @Test("Bend.Whako_Bend")
    func bendWhakoBendMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Bend", test: "Whako_Bend", width: 400, height: 240) { _, context in
            _ = context.scale(1.0, 1.0)
            _ = context.setBackgroundFillStyle("#FFF")
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 350).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let phrase1 = [
                BendPhrase(type: Bend.UP, text: "Full"),
                BendPhrase(type: Bend.DOWN, text: ""),
                BendPhrase(type: Bend.UP, text: "1/2"),
                BendPhrase(type: Bend.DOWN, text: ""),
            ]
            let phrase2 = [
                BendPhrase(type: Bend.UP, text: "Full"),
                BendPhrase(type: Bend.UP, text: "Full"),
                BendPhrase(type: Bend.UP, text: "1/2"),
                BendPhrase(type: Bend.DOWN, text: ""),
                BendPhrase(type: Bend.DOWN, text: "Full"),
                BendPhrase(type: Bend.DOWN, text: "Full"),
                BendPhrase(type: Bend.UP, text: "1/2"),
                BendPhrase(type: Bend.DOWN, text: ""),
            ]

            let notes = [
                TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 2, fret: 10),
                        TabNotePosition(str: 3, fret: 9),
                    ],
                    duration: .quarter
                ))
                    .addModifier(Bend("", phrase: phrase1), index: 0)
                    .addModifier(Bend("", phrase: phrase2), index: 1),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            if let first = notes.first {
                drawUpstreamBendNoteMetrics(context: context, note: first, yPos: 140)
            }
        }
    }

    private func drawUpstreamBendNoteMetrics(context: SVGRenderContext, note: Note, yPos: Double) {
        let metrics = note.getMetrics()
        let xStart = note.getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let xPre1 = note.getAbsoluteX() - metrics.leftDisplacedHeadPx
        let xAbs = note.getAbsoluteX()
        let xPost1 = note.getAbsoluteX() + metrics.notePx
        let xPost2 = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx
        let xEnd = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx + metrics.modRightPx
        let xFreedomRight = xEnd + note.getFormatterMetrics().freedom.right
        let xWidth = xEnd - xStart

        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))
        _ = context.fillText("\(Int(xWidth.rounded()))px", xStart + note.getXShift(), yPos)

        let y = yPos + 7
        func stroke(_ x1: Double, _ x2: Double, _ color: String, _ yy: Double = y) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(3)
            _ = context.moveTo(x1 + note.getXShift(), yy)
            _ = context.lineTo(x2 + note.getXShift(), yy)
            _ = context.stroke()
        }

        stroke(xStart, xPre1, "red")
        stroke(xPre1, xAbs, "#999")
        stroke(xAbs, xPost1, "green")
        stroke(xPost1, xPost2, "#999")
        stroke(xPost2, xEnd, "red")
        stroke(xEnd, xFreedomRight, "#DD0")
        stroke(xStart - note.getXShift(), xStart, "#BBB")
        drawUpstreamBendDot(context: context, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let spaceDeviation = formatterMetrics.space.deviation
            let prefix = spaceDeviation >= 0 ? "+" : ""
            _ = context.setFillStyle("red")
            _ = context.fillText("\(prefix)\(Int(spaceDeviation.rounded()))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = context.restore()
    }

    private func drawUpstreamBendDot(context: SVGRenderContext, x: Double, y: Double, color: String = "#F55") {
        _ = context.save()
        _ = context.setFillStyle(color)
        _ = context.beginPath()
        _ = context.arc(x, y, 3, 0, Double.pi * 2, false)
        _ = context.closePath()
        _ = context.fill()
        _ = context.restore()
    }
}
