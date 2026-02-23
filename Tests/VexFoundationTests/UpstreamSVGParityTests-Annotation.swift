import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Annotation.Simple_Annotation")
    func annotationSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Simple_Annotation", width: 500, height: 240) { _, context in
            _ = context.scale(1.5, 1.5)
            _ = context.setFont(FontInfo(family: "Arial, sans-serif", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let notes: [TabNote] = [
                TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 2, fret: 10),
                        TabNotePosition(str: 4, fret: 9),
                    ],
                    duration: .half
                )).addModifier(Annotation("T"), index: 0),
                TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10)],
                    duration: .half
                )).addModifier(Bend("Full").setTap("T"), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Annotation.Standard_Notation_Annotation")
    func annotationStandardNotationMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Standard_Notation_Annotation", width: 500, height: 240) { _, context in
            _ = context.scale(1.5, 1.5)
            let stave = Stave(x: 10, y: 10, width: 450).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let quiet = Annotation("quiet").setFont(
                FontInfo(
                    family: VexFont.SERIF,
                    size: VexFont.SIZE,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                )
            )
            let allegro = Annotation("Allegro").setFont(
                FontInfo(
                    family: VexFont.SERIF,
                    size: VexFont.SIZE,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                )
            )

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4"], duration: "h")).addModifier(quiet, index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "c/5"], duration: "h")).addModifier(allegro, index: 2),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Annotation.Styled_Annotation")
    func annotationStyledMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Styled_Annotation", width: 500, height: 240) { _, context in
            _ = context.scale(1.5, 1.5)
            let stave = Stave(x: 10, y: 10, width: 450).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let quiet = Annotation("quiet")
                .setFont(FontInfo(
                    family: VexFont.SERIF,
                    size: VexFont.SIZE,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                ))
                .setStyle(ElementStyle(fillStyle: "#0F0"))
            let allegro = Annotation("Allegro")
                .setFont(FontInfo(
                    family: VexFont.SERIF,
                    size: VexFont.SIZE,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                ))
                .setStyle(ElementStyle(fillStyle: "#00F"))

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4"], duration: "h")).addModifier(quiet, index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "c/5"], duration: "h")).addModifier(allegro, index: 2),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Annotation.Bottom_Annotation")
    func annotationBottomMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Bottom_Annotation", width: 500, height: 240) { _, context in
            _ = context.scale(1.5, 1.5)
            let stave = Stave(x: 10, y: 10, width: 300).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            func bottomAnnotation(_ text: String) -> Annotation {
                Annotation(text)
                    .setFont(FontInfo(family: VexFont.SERIF, size: VexFont.SIZE))
                    .setVerticalJustification(.bottom)
            }

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "w")).addModifier(bottomAnnotation("F"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "w")).addModifier(bottomAnnotation("A"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "w")).addModifier(bottomAnnotation("C"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["e/5"], duration: "w")).addModifier(bottomAnnotation("E"), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Annotation.Bottom_Annotations_with_Beams")
    func annotationBottomWithBeamsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Bottom_Annotations_with_Beams", width: 500, height: 240) { _, context in
            _ = context.scale(1.5, 1.5)
            let stave = Stave(x: 10, y: 10, width: 300).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["a/3"], duration: "8"))
                    .addModifier(Annotation("good").setVerticalJustification(.bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["g/3"], duration: "8"))
                    .addModifier(Annotation("even").setVerticalJustification(.bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "8"))
                    .addModifier(Annotation("under").setVerticalJustification(.bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["d/4"], duration: "8"))
                    .addModifier(Annotation("beam").setVerticalJustification(.bottom), index: 0),
            ]

            let beam = try Beam(Array(notes.dropFirst()))

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = beam.setContext(context)
            try beam.draw()
        }
    }
}
