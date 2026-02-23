import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Vibrato.Simple_Vibrato")
    func vibratoSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Vibrato", test: "Simple_Vibrato", width: 500, height: 240) { _, context in
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
                    duration: .half
                ))
                    .addModifier(Vibrato(), index: 0),
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10)],
                    duration: .half
                ))
                    .addModifier(Vibrato(), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Vibrato.Harsh_Vibrato")
    func vibratoHarshMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Vibrato", test: "Harsh_Vibrato", width: 500, height: 240) { _, context in
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
                    duration: .half
                ))
                    .addModifier(Vibrato().setHarsh(true), index: 0),
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10)],
                    duration: .half
                ))
                    .addModifier(Vibrato().setHarsh(true), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Vibrato.Vibrato_with_Bend")
    func vibratoWithBendMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Vibrato", test: "Vibrato_with_Bend", width: 500, height: 240) { _, context in
            _ = context.scale(1.3, 1.3)
            _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "\(VexFont.SIZE)pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let notes = [
                TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 2, fret: 9),
                        TabNotePosition(str: 3, fret: 9),
                    ],
                    duration: .quarter
                ))
                    .addModifier(Bend("1/2", release: true), index: 0)
                    .addModifier(Bend("1/2", release: true), index: 1)
                    .addModifier(Vibrato(), index: 0),
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10)],
                    duration: .quarter
                ))
                    .addModifier(Bend("Full", release: false), index: 0)
                    .addModifier(Vibrato().setVibratoWidth(60), index: 0),
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10)],
                    duration: .half
                ))
                    .addModifier(Vibrato().setVibratoWidth(120).setHarsh(true), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }
}
