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

    @Test("Annotation.Placement")
    func annotationPlacementMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Placement", width: 750, height: 300) { _, context in
            let stave = Stave(x: 10, y: 50, width: 750).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            func annotation(_ text: String, size: Double, vj: AnnotationVerticalJustify) -> Annotation {
                Annotation(text)
                    .setFont(FontInfo(family: VexFont.SERIF, size: size))
                    .setVerticalJustification(vj)
            }

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(annotation("v1", size: 10, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 10, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(annotation("v1", size: 10, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 10, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(annotation("v1", size: 10, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 10, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q"))
                    .addModifier(annotation("v1", size: 14, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 14, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("am").setPosition(.above), index: 0)
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(annotation("v1", size: 10, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 20, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(annotation("v1", size: 11, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 11, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(annotation("v1", size: 11, vj: .top), index: 0)
                    .addModifier(annotation("v2", size: 20, vj: .top), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q"))
                    .addModifier(annotation("v1", size: 12, vj: .bottom), index: 0)
                    .addModifier(annotation("v2", size: 12, vj: .bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(annotation("v1", size: 11, vj: .bottom), index: 0)
                    .addModifier(annotation("v2", size: 20, vj: .bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("am").setPosition(.below), index: 0)
                    .addModifier(annotation("v1", size: 10, vj: .bottom), index: 0)
                    .addModifier(annotation("v2", size: 20, vj: .bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q", stemDirection: .down))
                    .addModifier(annotation("v1", size: 10, vj: .bottom), index: 0)
                    .addModifier(annotation("v2", size: 20, vj: .bottom), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "w"))
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0)
                    .addModifier(annotation("v1", size: 11, vj: .bottom), index: 0)
                    .addModifier(annotation("v2", size: 16, vj: .bottom), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Annotation.Lyrics")
    func annotationLyricsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Lyrics", width: 750, height: 260) { _, context in
            let registry = Registry()
            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }

            let factory = Factory(options: FactoryOptions(width: 750, height: 260))
            _ = factory.setContext(context)

            var fontSize = VexFont.SIZE
            var x = 10.0
            var width = 170.0
            let words = ["hand,", "and", "me", "pears", "lead", "the"]

            for _ in 0..<3 {
                let score = factory.EasyScore()
                _ = score.set(defaults: EasyScoreDefaults(time: .meter(3, 4)))
                let system = factory.System(options: SystemOptions(x: x, width: width))

                let row1Notes = score.notes("(C4 F4)/2[id=\"n0\"]") + score.beam(
                    score.notes("(C4 A4)/8[id=\"n1\"], (C4 A4)/8[id=\"n2\"]")
                )
                let row1Voice = score.voice(row1Notes.map { $0 as Note })
                _ = system.addStave(SystemStave(voices: [row1Voice]))

                for (ix, text) in words.enumerated() {
                    let verse = ix / 3
                    let noteGroupID = "n\(ix % 3)"
                    guard let noteGroup = registry.getElementById(noteGroupID) as? Note else { continue }

                    let lyric = factory.Annotation(text: text)
                        .setFont(FontInfo(family: "Roboto Slab", size: fontSize))
                    _ = lyric.setPosition(.below)
                    _ = noteGroup.addModifier(lyric, index: verse)
                }

                let row2Notes = score.notes("(F4 D5)/2") + score.beam(score.notes("(F4 F5)/8, (F4 F5)/8"))
                let row2Voice = score.voice(row2Notes.map { $0 as Note })
                _ = system.addStave(SystemStave(voices: [row2Voice]))

                try factory.draw()

                let ratio = (fontSize + 2) / fontSize
                width *= ratio
                x += width
                fontSize += 2
            }
        }
    }

    @Test("Annotation.Harmonics")
    func annotationHarmonicsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Harmonics", width: 500, height: 240) { _, context in
            _ = context.scale(1.5, 1.5)
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            let note0 = TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 2, fret: 12), TabNotePosition(str: 3, fret: 12)],
                duration: .half
            )).addModifier(Annotation("Harm."), index: 0)

            let note1 = TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 2, fret: 9)],
                duration: .half
            ))
                .addModifier(
                    Annotation("(8va)").setFont(FontInfo(
                        family: VexFont.SERIF,
                        size: VexFont.SIZE,
                        weight: VexFontWeight.normal.rawValue,
                        style: VexFontStyle.italic.rawValue
                    )),
                    index: 0
                )
                .addModifier(Annotation("A.H."), index: 0)

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: [note0, note1])
        }
    }

    @Test("Annotation.Fingerpicking")
    func annotationFingerpickingMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Fingerpicking", width: 500, height: 240) { _, context in
            _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: VexFont.SIZE))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            _ = stave.setContext(context)
            try stave.draw()

            func pickingAnnotation(_ text: String) -> Annotation {
                Annotation(text).setFont(FontInfo(
                    family: VexFont.SERIF,
                    size: VexFont.SIZE,
                    weight: VexFontWeight.normal.rawValue,
                    style: VexFontStyle.italic.rawValue
                ))
            }

            let notes: [TabNote] = [
                TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 1, fret: 0),
                        TabNotePosition(str: 2, fret: 1),
                        TabNotePosition(str: 3, fret: 2),
                        TabNotePosition(str: 4, fret: 2),
                        TabNotePosition(str: 5, fret: 0),
                    ],
                    duration: .half
                )).addModifier(Vibrato().setVibratoWidth(40), index: 0),
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 6, fret: 9)], duration: .eighth))
                    .addModifier(pickingAnnotation("p").setVerticalJustification(.top), index: 0),
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 3, fret: 9)], duration: .eighth))
                    .addModifier(pickingAnnotation("i").setVerticalJustification(.top), index: 0),
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 9)], duration: .eighth))
                    .addModifier(pickingAnnotation("m").setVerticalJustification(.top), index: 0),
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 9)], duration: .eighth))
                    .addModifier(pickingAnnotation("a").setVerticalJustification(.top), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Annotation.Test_Justification_Annotation_Stem_Up")
    func annotationJustificationStemUpMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Test_Justification_Annotation_Stem_Up", width: 650, height: 950) { _, context in
            _ = context.scale(1.5, 1.5)
            for v in 1...4 {
                let stave = Stave(x: 10, y: Double(v - 1) * 150 + 40, width: 400).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()

                let notes: [StaveNote] = [
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/3"], duration: "q"))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 1, v: v), index: 0),
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "q"))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 2, v: v), index: 0),
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "c/5"], duration: "q"))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 3, v: v), index: 0),
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/6"], duration: "q"))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 4, v: v), index: 0),
                ]

                try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            }
        }
    }

    @Test("Annotation.Test_Justification_Annotation_Stem_Down")
    func annotationJustificationStemDownMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Annotation", test: "Test_Justification_Annotation_Stem_Down", width: 650, height: 1000) { _, context in
            _ = context.scale(1.5, 1.5)
            for v in 1...4 {
                let stave = Stave(x: 10, y: Double(v - 1) * 150 + 40, width: 400).addClef(.treble)
                _ = stave.setContext(context)
                try stave.draw()

                let notes: [StaveNote] = [
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/3"], duration: "q", stemDirection: .down))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 1, v: v), index: 0),
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "c/5"], duration: "q", stemDirection: .down))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 2, v: v), index: 0),
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 3, v: v), index: 0),
                    StaveNote(try StaveNoteStruct(parsingKeys: ["c/6"], duration: "q", stemDirection: .down))
                        .addModifier(upstreamJustificationAnnotation(text: "Text", h: 4, v: v), index: 0),
                ]

                try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            }
        }
    }

    @Test("Annotation.TabNote_Annotations")
    func annotationTabNoteAnnotationsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Annotation",
            test: "TabNote_Annotations",
            width: 600,
            height: 200,
            signatureEpsilonOverride: 0.005
        ) { _, context in
            _ = context.setFont(FontInfo(family: "Arial, sans-serif", size: "10pt"))
            let stave = TabStave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)
            try stave.draw()

            let specs = [
                TabNoteStruct(
                    positions: [TabNotePosition(str: 3, fret: 6), TabNotePosition(str: 4, fret: 25)],
                    duration: .eighth
                ),
                TabNoteStruct(
                    positions: [TabNotePosition(str: 2, fret: 10), TabNotePosition(str: 5, fret: 12)],
                    duration: .eighth
                ),
                TabNoteStruct(
                    positions: [TabNotePosition(str: 1, fret: 6), TabNotePosition(str: 3, fret: 5)],
                    duration: .eighth
                ),
                TabNoteStruct(
                    positions: [TabNotePosition(str: 1, fret: 6), TabNotePosition(str: 3, fret: 5)],
                    duration: .eighth
                ),
            ]

            let notes1 = specs.map { spec in TabNote(spec, drawStem: true) }
            let notes2 = specs.map { spec in
                let note = TabNote(spec, drawStem: true)
                _ = note.setStemDirection(.down)
                return note
            }
            let notes3 = specs.map { TabNote($0) }

            _ = notes1[0].addModifier(Annotation("Text").setJustification(.left).setVerticalJustification(.top), index: 0)
            _ = notes1[1].addModifier(Annotation("Text").setJustification(.center).setVerticalJustification(.center), index: 0)
            _ = notes1[2].addModifier(Annotation("Text").setJustification(.right).setVerticalJustification(.bottom), index: 0)
            _ = notes1[3].addModifier(Annotation("Text").setJustification(.centerStem).setVerticalJustification(.centerStem), index: 0)

            _ = notes2[0].addModifier(Annotation("Text").setJustification(.right).setVerticalJustification(.top), index: 0)
            _ = notes2[1].addModifier(Annotation("Text").setJustification(.right).setVerticalJustification(.center), index: 0)
            _ = notes2[2].addModifier(Annotation("Text").setJustification(.right).setVerticalJustification(.bottom), index: 0)
            _ = notes2[3].addModifier(Annotation("Text").setJustification(.right).setVerticalJustification(.centerStem), index: 0)

            _ = notes3[0].addModifier(Annotation("Text").setVerticalJustification(.top), index: 0)
            _ = notes3[1].addModifier(Annotation("Text").setVerticalJustification(.center), index: 0)
            _ = notes3[2].addModifier(Annotation("Text").setVerticalJustification(.bottom), index: 0)
            _ = notes3[3].addModifier(Annotation("Text").setVerticalJustification(.centerStem), index: 0)

            let voice = Voice(timeSignature: .meter(4, 4)).setMode(.soft)
            _ = voice.addTickables((notes1 + notes2 + notes3).map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    private func upstreamJustificationAnnotation(text: String, h: Int, v: Int) -> Annotation {
        let hJust = AnnotationHorizontalJustify(rawValue: h) ?? .center
        let vJust = AnnotationVerticalJustify(rawValue: v) ?? .top
        return Annotation(text)
            .setFont(FontInfo(family: VexFont.SANS_SERIF, size: VexFont.SIZE))
            .setJustification(hJust)
            .setVerticalJustification(vJust)
    }
}
