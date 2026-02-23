import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Articulation.Articulation___Vertical_Placement")
    func articulationVerticalPlacementMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "Articulation___Vertical_Placement", width: 750, height: 300) { _, context in
            let stave = Stave(x: 10, y: 50, width: 750).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q"))
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0)
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(Articulation("a-").setPosition(.below), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0)
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(Articulation("a-").setPosition(.below), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q"))
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0)
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(Articulation("a-").setPosition(.below), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q"))
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(Articulation("a-").setPosition(.below), index: 0)
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(Articulation("a-").setPosition(.below), index: 0)
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q"))
                    .addModifier(Articulation("a.").setPosition(.below), index: 0)
                    .addModifier(Articulation("a-").setPosition(.below), index: 0)
                    .addModifier(Articulation("a@u").setPosition(.below), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0)
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0)
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0)
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("a.").setPosition(.above), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Articulation.Articulation___Vertical_Placement__Glyph_codes_")
    func articulationVerticalPlacementGlyphCodesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Articulation",
            test: "Articulation___Vertical_Placement__Glyph_codes_",
            width: 750,
            height: 300
        ) { _, context in
            let stave = Stave(x: 10, y: 50, width: 750).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let notes: [StaveNote] = [
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q"))
                    .addModifier(Articulation("fermataBelow"), index: 0)
                    .addModifier(Articulation("augmentationDot").setPosition(.below), index: 0)
                    .addModifier(Articulation("articTenutoBelow"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("fermataShortBelow"), index: 0)
                    .addModifier(Articulation("augmentationDot").setPosition(.below), index: 0)
                    .addModifier(Articulation("articTenutoBelow"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q"))
                    .addModifier(Articulation("fermataLongBelow"), index: 0)
                    .addModifier(Articulation("augmentationDot").setPosition(.below), index: 0)
                    .addModifier(Articulation("articTenutoBelow"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q"))
                    .addModifier(Articulation("augmentationDot").setPosition(.below), index: 0)
                    .addModifier(Articulation("articTenutoBelow"), index: 0)
                    .addModifier(Articulation("fermataVeryShortBelow"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("augmentationDot").setPosition(.below), index: 0)
                    .addModifier(Articulation("articTenutoBelow"), index: 0)
                    .addModifier(Articulation("fermataVeryLongBelow"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q"))
                    .addModifier(Articulation("augmentationDot").setPosition(.below).setBetweenLines(), index: 0)
                    .addModifier(Articulation("articTenutoBelow").setBetweenLines(), index: 0)
                    .addModifier(Articulation("fermataBelow"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("fermataAbove"), index: 0)
                    .addModifier(Articulation("augmentationDot").setPosition(.above), index: 0)
                    .addModifier(Articulation("articTenutoAbove"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(Articulation("fermataShortAbove"), index: 0)
                    .addModifier(Articulation("augmentationDot").setPosition(.above), index: 0)
                    .addModifier(Articulation("articTenutoAbove"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("fermataLongAbove"), index: 0)
                    .addModifier(Articulation("augmentationDot").setPosition(.above), index: 0)
                    .addModifier(Articulation("articTenutoAbove"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("augmentationDot").setPosition(.above), index: 0)
                    .addModifier(Articulation("articTenutoAbove"), index: 0)
                    .addModifier(Articulation("fermataVeryShortAbove"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "q"))
                    .addModifier(Articulation("augmentationDot").setPosition(.above), index: 0)
                    .addModifier(Articulation("articTenutoAbove"), index: 0)
                    .addModifier(Articulation("fermataVeryLongAbove"), index: 0),
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "q", stemDirection: .down))
                    .addModifier(Articulation("augmentationDot").setPosition(.above).setBetweenLines(), index: 0)
                    .addModifier(Articulation("articTenutoAbove").setBetweenLines(), index: 0)
                    .addModifier(Articulation("fermataAbove"), index: 0),
            ]

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Articulation.Articulation___Staccato_Staccatissimo")
    func articulationStaccatoStaccatissimoMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "Articulation___Staccato_Staccatissimo", width: 675, height: 195) { factory, context in
            try drawUpstreamArticulationRows(factory: factory, context: context, sym1: "a.", sym2: "av")
        }
    }

    @Test("Articulation.Articulation___Accent_Tenuto")
    func articulationAccentTenutoMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "Articulation___Accent_Tenuto", width: 675, height: 195) { factory, context in
            try drawUpstreamArticulationRows(factory: factory, context: context, sym1: "a>", sym2: "a-")
        }
    }

    @Test("Articulation.Articulation___Marcato_L_H__Pizzicato")
    func articulationMarcatoPizzicatoMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Articulation",
            test: "Articulation___Marcato_L_H__Pizzicato",
            width: 675,
            height: 195
        ) { factory, context in
            try drawUpstreamArticulationRows(factory: factory, context: context, sym1: "a^", sym2: "a+")
        }
    }

    @Test("Articulation.Articulation___Snap_Pizzicato_Fermata")
    func articulationSnapPizzicatoFermataMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Articulation",
            test: "Articulation___Snap_Pizzicato_Fermata",
            width: 675,
            height: 195
        ) { factory, context in
            try drawUpstreamArticulationRows(factory: factory, context: context, sym1: "ao", sym2: "ao")
        }
    }

    @Test("Articulation.Articulation___Up_stroke_Down_Stroke")
    func articulationUpStrokeDownStrokeMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "Articulation___Up_stroke_Down_Stroke", width: 675, height: 195) { factory, context in
            try drawUpstreamArticulationRows(factory: factory, context: context, sym1: "a|", sym2: "am")
        }
    }

    @Test("Articulation.Articulation___Fermata_Above_Below")
    func articulationFermataAboveBelowMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "Articulation___Fermata_Above_Below", width: 400, height: 195) { factory, context in
            try drawUpstreamFermataRows(factory: factory, context: context, sym1: "a@a", sym2: "a@u")
        }
    }

    @Test("Articulation.Articulation___Fermata_Short_Above_Below")
    func articulationFermataShortAboveBelowMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Articulation",
            test: "Articulation___Fermata_Short_Above_Below",
            width: 400,
            height: 195
        ) { factory, context in
            try drawUpstreamFermataRows(factory: factory, context: context, sym1: "a@as", sym2: "a@us")
        }
    }

    @Test("Articulation.Articulation___Fermata_Long_Above_Below")
    func articulationFermataLongAboveBelowMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Articulation",
            test: "Articulation___Fermata_Long_Above_Below",
            width: 400,
            height: 195
        ) { factory, context in
            try drawUpstreamFermataRows(factory: factory, context: context, sym1: "a@al", sym2: "a@ul")
        }
    }

    @Test("Articulation.Articulation___Fermata_Very_Long_Above_Below")
    func articulationFermataVeryLongAboveBelowMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Articulation",
            test: "Articulation___Fermata_Very_Long_Above_Below",
            width: 400,
            height: 195
        ) { factory, context in
            try drawUpstreamFermataRows(factory: factory, context: context, sym1: "a@avl", sym2: "a@uvl")
        }
    }

    @Test("Articulation.Articulation___Inline_Multiple")
    func articulationInlineMultipleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "Articulation___Inline_Multiple", width: 1500, height: 195) { factory, context in
            _ = context.scale(0.8, 0.8)

            let stave1 = Stave(x: 10, y: 50, width: 500)
            _ = stave1.setContext(context)
            try stave1.draw()

            let notesBar1: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/6"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/6"], duration: "16", stemDirection: .down)),
            ]
            for i in 0..<notesBar1.count {
                _ = notesBar1[i].addModifier(Articulation("a.").setPosition(.below), index: 0)
                _ = notesBar1[i].addModifier(Articulation("a>").setPosition(.below), index: 0)
                if i == notesBar1.count - 1 {
                    _ = notesBar1[i].addModifier(Articulation("a@u").setPosition(.below), index: 0)
                }
            }
            let beam1 = try Beam(Array(notesBar1[0..<8]))
            let beam2 = try Beam(Array(notesBar1[8..<16]))
            try Formatter.FormatAndDraw(ctx: context, stave: stave1, notes: notesBar1)
            _ = beam1.setContext(context)
            _ = beam2.setContext(context)
            try beam1.draw()
            try beam2.draw()

            let stave2 = Stave(x: 510, y: 50, width: 500)
            _ = stave2.setContext(context)
            try stave2.draw()

            let notesBar2: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/3"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/3"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/3"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/3"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "16", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/4"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/5"], duration: "16", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5"], duration: "16", stemDirection: .down)),
            ]
            for i in 0..<notesBar2.count {
                _ = notesBar2[i].addModifier(Articulation("a-").setPosition(.above), index: 0)
                _ = notesBar2[i].addModifier(Articulation("a^").setPosition(.above), index: 0)
                if i == notesBar2.count - 1 {
                    _ = notesBar2[i].addModifier(Articulation("a@u").setPosition(.below), index: 0)
                }
            }
            let beam3 = try Beam(Array(notesBar2[0..<8]))
            let beam4 = try Beam(Array(notesBar2[8..<16]))
            try Formatter.FormatAndDraw(ctx: context, stave: stave2, notes: notesBar2)
            _ = beam3.setContext(context)
            _ = beam4.setContext(context)
            try beam3.draw()
            try beam4.draw()

            let stave3 = Stave(x: 1010, y: 50, width: 100)
            _ = stave3.setContext(context)
            try stave3.draw()
            let notesBar3 = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "w", stemDirection: .up))
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Articulation("a>").setPosition(.above), index: 0)
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0),
            ]
            try Formatter.FormatAndDraw(ctx: context, stave: stave3, notes: notesBar3)

            let stave4 = Stave(x: 1110, y: 50, width: 250)
            _ = stave4.setContext(context)
            try stave4.draw()
            let notesBar4: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
            ]
            for i in 0..<notesBar4.count {
                let position: ModifierPosition = i > 1 ? .below : .above
                _ = notesBar4[i].addModifier(Articulation("a-").setPosition(position), index: 0)
            }
            try Formatter.FormatAndDraw(ctx: context, stave: stave4, notes: notesBar4)
        }
    }

    @Test("Articulation.TabNote_Articulation")
    func articulationTabNoteArticulationMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Articulation", test: "TabNote_Articulation", width: 600, height: 200) { _, context in
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

            let notes1 = specs.map { TabNote($0, drawStem: true) }
            let notes2 = specs.map { spec in
                let note = TabNote(spec, drawStem: true)
                _ = note.setStemDirection(.down)
                return note
            }
            let notes3 = specs.map { TabNote($0) }

            _ = notes1[0].addModifier(Articulation("a>").setPosition(.above), index: 0)
            _ = notes1[1].addModifier(Articulation("a>").setPosition(.below), index: 0)
            _ = notes1[2].addModifier(Articulation("a.").setPosition(.above), index: 0)
            _ = notes1[3].addModifier(Articulation("a.").setPosition(.below), index: 0)

            _ = notes2[0].addModifier(Articulation("a>").setPosition(.above), index: 0)
            _ = notes2[1].addModifier(Articulation("a>").setPosition(.below), index: 0)
            _ = notes2[2].addModifier(Articulation("a.").setPosition(.above), index: 0)
            _ = notes2[3].addModifier(Articulation("a.").setPosition(.below), index: 0)

            _ = notes3[0].addModifier(Articulation("a>").setPosition(.above), index: 0)
            _ = notes3[1].addModifier(Articulation("a>").setPosition(.below), index: 0)
            _ = notes3[2].addModifier(Articulation("a.").setPosition(.above), index: 0)
            _ = notes3[3].addModifier(Articulation("a.").setPosition(.below), index: 0)

            let voice = Voice(timeSignature: .meter(4, 4)).setMode(.soft)
            _ = voice.addTickables((notes1 + notes2 + notes3).map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    private func drawUpstreamArticulationRows(
        factory: Factory,
        context: SVGRenderContext,
        sym1: String,
        sym2: String
    ) throws {
        let score = factory.EasyScore()
        let width = 125.0 - Stave.defaultPadding
        var x = 10.0
        let y = 30.0

        let notesBar1: [StaveNote] = [
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/3"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "q", stemDirection: .up)),
        ]
        _ = notesBar1[0].addModifier(Articulation(sym1).setPosition(.below), index: 0)
        _ = notesBar1[1].addModifier(Articulation(sym1).setPosition(.below), index: 0)
        _ = notesBar1[2].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar1[3].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        x += try drawUpstreamArticulationBar(
            factory: factory,
            score: score,
            context: context,
            x: x,
            y: y,
            width: width,
            notes: notesBar1,
            barline: .none
        )

        let notesBar2: [StaveNote] = [
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
        ]
        _ = notesBar2[0].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar2[1].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar2[2].addModifier(Articulation(sym1).setPosition(.below), index: 0)
        _ = notesBar2[3].addModifier(Articulation(sym1).setPosition(.below), index: 0)
        x += try drawUpstreamArticulationBar(
            factory: factory,
            score: score,
            context: context,
            x: x,
            y: y,
            width: width,
            notes: notesBar2,
            barline: .double
        )

        let notesBar3: [StaveNote] = [
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "q", stemDirection: .up)),
        ]
        _ = notesBar3[0].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = notesBar3[1].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = notesBar3[2].addModifier(Articulation(sym2).setPosition(.above), index: 0)
        _ = notesBar3[3].addModifier(Articulation(sym2).setPosition(.above), index: 0)
        x += try drawUpstreamArticulationBar(
            factory: factory,
            score: score,
            context: context,
            x: x,
            y: y,
            width: width,
            notes: notesBar3,
            barline: .none
        )

        let notesBar4: [StaveNote] = [
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
        ]
        _ = notesBar4[0].addModifier(Articulation(sym2).setPosition(.above), index: 0)
        _ = notesBar4[1].addModifier(Articulation(sym2).setPosition(.above), index: 0)
        _ = notesBar4[2].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = notesBar4[3].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = try drawUpstreamArticulationBar(
            factory: factory,
            score: score,
            context: context,
            x: x,
            y: y,
            width: width,
            notes: notesBar4,
            barline: .end
        )
    }

    private func drawUpstreamFermataRows(
        factory: Factory,
        context: SVGRenderContext,
        sym1: String,
        sym2: String
    ) throws {
        let score = factory.EasyScore()
        let width = 150.0 - Stave.defaultPadding
        var x = 50.0
        let y = 30.0

        let notesBar1: [StaveNote] = [
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/4"], duration: "q", stemDirection: .down)),
        ]
        _ = notesBar1[0].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar1[1].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar1[2].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = notesBar1[3].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        x += try drawUpstreamArticulationBar(
            factory: factory,
            score: score,
            context: context,
            x: x,
            y: y,
            width: width,
            notes: notesBar1,
            barline: .none
        )

        let notesBar2: [StaveNote] = [
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .up)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down)),
            try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5"], duration: "q", stemDirection: .down)),
        ]
        _ = notesBar2[0].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar2[1].addModifier(Articulation(sym1).setPosition(.above), index: 0)
        _ = notesBar2[2].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = notesBar2[3].addModifier(Articulation(sym2).setPosition(.below), index: 0)
        _ = try drawUpstreamArticulationBar(
            factory: factory,
            score: score,
            context: context,
            x: x,
            y: y,
            width: width,
            notes: notesBar2,
            barline: .double
        )
    }

    private func drawUpstreamArticulationBar(
        factory: Factory,
        score: EasyScore,
        context: SVGRenderContext,
        x: Double,
        y: Double,
        width: Double,
        notes: [StaveNote],
        barline: BarlineType
    ) throws -> Double {
        let voice = score.voice(notes.map { $0 as Note }, time: .meter(4, 4))
        let formatter = factory.Formatter()
        _ = formatter.joinVoices([voice])
        let noteWidth = max(formatter.preCalculateMinTotalWidth([voice]), width)
        _ = formatter.format([voice], justifyWidth: noteWidth)

        let stave = factory.Stave(x: x, y: y, width: noteWidth + Stave.defaultPadding).setEndBarType(barline)
        _ = stave.setContext(context)
        try stave.draw()
        try voice.draw(context: context, stave: stave)
        return stave.getWidth()
    }
}
