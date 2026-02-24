import Foundation
import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Formatter.StaveNote___Justification")
    func formatterStaveNoteJustificationMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "StaveNote___Justification",
            width: 520,
            height: 280
        ) { factory, context in
            let score = factory.EasyScore()
            var y = 30.0

            func justifyToWidth(_ width: Double) {
                _ = factory.Stave(y: y).addClef(.treble)

                let lowerNotes = score.notes(
                    "(cbb4 en4 a4)/2, (d4 e4 f4)/8, (d4 f4 a4)/8, (cn4 f#4 a4)/4",
                    options: ["stem": "down"]
                )
                let upperNotes = score.notes(
                    "(bb4 e#5 a5)/4, (d5 e5 f5)/2, (c##5 fb5 a5)/4",
                    options: ["stem": "up"]
                )

                let lowerVoice = score.voice(lowerNotes.map { $0 as Note })
                let upperVoice = score.voice(upperNotes.map { $0 as Note })
                let voices = [lowerVoice, upperVoice]

                let justifyWidth = width - (Stave.defaultPadding + upstreamFormatterGlyphWidth("gClef"))
                _ = factory.Formatter()
                    .joinVoices(voices)
                    .format(voices, justifyWidth: justifyWidth)

                lowerVoice.getTickables().forEach { tickable in
                    drawUpstreamFormatterNoteMetrics(context: context, note: tickable, yPos: y + 140)
                }
                upperVoice.getTickables().forEach { tickable in
                    drawUpstreamFormatterNoteMetrics(context: context, note: tickable, yPos: y - 20)
                }

                y += 210
            }

            justifyToWidth(520)
            try factory.draw()
        }
    }

    @Test("Formatter.Whitespace_and_justify")
    func formatterWhitespaceAndJustifyMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Whitespace_and_justify",
            width: 1200,
            height: 150
        ) { _, context in
            let time44 = VoiceTime(numBeats: 4, beatValue: 4, resolution: 4 * Tables.RESOLUTION)
            let time34 = VoiceTime(numBeats: 3, beatValue: 4, resolution: 4 * Tables.RESOLUTION)

            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time44,
                noteCount: 3,
                duration: "4",
                finalDuration: "2",
                x: 10,
                width: 300
            )
            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time44,
                noteCount: 1,
                duration: "w",
                finalDuration: "w",
                x: 310,
                width: 300
            )
            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time34,
                noteCount: 3,
                duration: "4",
                finalDuration: "4",
                x: 610,
                width: 300
            )
            try drawUpstreamFormatterRightJustifyScenario(
                context: context,
                time: time34,
                noteCount: 6,
                duration: "8",
                finalDuration: "8",
                x: 910,
                width: 300
            )
        }
    }

    @Test("Formatter.Tight")
    func formatterTightMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Tight", width: 440, height: 250) { factory, context in
            try drawUpstreamFormatterTightCase(
                factory: factory,
                context: context,
                secondVoiceWholeNote: false,
                maxIterations: 10
            )
        }
    }

    @Test("Formatter.Tight_2")
    func formatterTight2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Tight_2", width: 440, height: 250) { factory, context in
            try drawUpstreamFormatterTightCase(
                factory: factory,
                context: context,
                secondVoiceWholeNote: true,
                maxIterations: nil
            )
        }
    }

    @Test("Formatter.Penultimate_Note_Padding")
    func formatterPenultimateNotePaddingMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Penultimate_Note_Padding", width: 500, height: 550) { factory, context in
            try drawUpstreamFormatterPenultimatePaddingCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Notehead_padding")
    func formatterNoteheadPaddingMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Notehead_padding", width: 600, height: 300) { factory, context in
            try drawUpstreamFormatterNoteheadPaddingCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Justification_and_alignment_with_accidentals")
    func formatterAccidentalJustificationMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Justification_and_alignment_with_accidentals",
            width: 600,
            height: 300
        ) { factory, context in
            try drawUpstreamFormatterAccidentalJustificationCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Long_measure_taking_full_space")
    func formatterLongMeasureTakingFullSpaceMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Long_measure_taking_full_space",
            width: 1500,
            height: 300
        ) { factory, context in
            try drawUpstreamFormatterLongMeasureCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Vertical_alignment___few_unaligned_beats")
    func formatterVerticalAlignmentFewUnalignedBeatsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Vertical_alignment___few_unaligned_beats",
            width: 600,
            height: 250
        ) { factory, context in
            try drawUpstreamFormatterVerticalAlignmentFewCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Vertical_alignment___many_unaligned_beats")
    func formatterVerticalAlignmentManyUnalignedBeatsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Vertical_alignment___many_unaligned_beats",
            width: 750,
            height: 280
        ) { factory, context in
            try drawUpstreamFormatterVerticalAlignmentManyCase(factory: factory, context: context, globalSoftmax: false)
        }
    }

    @Test("Formatter.Vertical_alignment___many_unaligned_beats__global_softmax_")
    func formatterVerticalAlignmentManyUnalignedBeatsGlobalSoftmaxMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Vertical_alignment___many_unaligned_beats__global_softmax_",
            width: 750,
            height: 280
        ) { factory, context in
            try drawUpstreamFormatterVerticalAlignmentManyCase(factory: factory, context: context, globalSoftmax: true)
        }
    }

    @Test("Formatter.Vertical_alignment___many_mixed_elements")
    func formatterVerticalAlignmentManyMixedElementsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Vertical_alignment___many_mixed_elements",
            width: 800,
            height: 500
        ) { factory, context in
            try drawUpstreamFormatterVerticalAlignmentMixedCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Notes_with_Tab")
    func formatterNotesWithTabMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Notes_with_Tab",
            width: 420,
            height: 580,
            signatureEpsilonOverride: 0.0015
        ) { factory, context in
            try drawUpstreamFormatterNotesWithTabCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Multiple_Staves___Justified")
    func formatterMultipleStavesJustifiedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Multiple_Staves___Justified", width: 600, height: 400) { factory, context in
            try drawUpstreamFormatterMultipleStavesCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Softmax")
    func formatterSoftmaxMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Softmax", width: 550, height: 500) { factory, context in
            try drawUpstreamFormatterSoftmaxCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Mixtime")
    func formatterMixtimeMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Mixtime", width: 400 + Stave.defaultPadding, height: 250) { factory, context in
            try drawUpstreamFormatterMixtimeCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Annotations")
    func formatterAnnotationsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Formatter", test: "Annotations", width: 916, height: 600) { factory, context in
            try drawUpstreamFormatterAnnotationsCase(factory: factory, context: context)
        }
    }

    @Test("Formatter.Proportional_Formatting___No_Tuning")
    func formatterProportionalFormattingNoTuningMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Proportional_Formatting___No_Tuning",
            width: 775,
            height: 750
        ) { factory, context in
            try drawUpstreamFormatterProportionalCase(
                factory: factory,
                context: context,
                noJustification: false,
                iterations: 0,
                alpha: nil
            )
        }
    }

    @Test("Formatter.Proportional_Formatting___No_Justification")
    func formatterProportionalFormattingNoJustificationMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Proportional_Formatting___No_Justification",
            width: 775,
            height: 750
        ) { factory, context in
            try drawUpstreamFormatterProportionalCase(
                factory: factory,
                context: context,
                noJustification: true,
                iterations: 0,
                alpha: nil
            )
        }
    }

    @Test("Formatter.Proportional_Formatting__20_iterations_")
    func formatterProportionalFormatting20IterationsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Formatter",
            test: "Proportional_Formatting__20_iterations_",
            width: 775,
            height: 750
        ) { factory, context in
            try drawUpstreamFormatterProportionalCase(
                factory: factory,
                context: context,
                noJustification: false,
                iterations: 20,
                alpha: 0.5
            )
        }
    }

    private func drawUpstreamFormatterPenultimatePaddingCase(factory: Factory, context: SVGRenderContext) throws {
        let score = factory.EasyScore()
        let staffWidth = 310.0
        var y = 10.0

        func addRow(softmax: Double) throws {
            let system = factory.System(options: SystemOptions(
                width: staffWidth,
                y: y,
                details: SystemFormatterOptions(softmaxFactor: softmax),
                formatOptions: FormatParams(alignRests: true)
            ))

            let voice1 = score.voice([
                score.notes("C4/8/r", options: ["clef": "bass"])[0],
                score.notes("A3/8", options: ["stem": "up", "clef": "bass"])[0],
                score.notes("C4/4", options: ["stem": "up", "clef": "bass"])[0],
            ]).setMode(.soft)

            let voice2 = score.voice([
                score.notes("(F3 A3)/4", options: ["stem": "down", "clef": "bass"])[0],
                score.notes("B4/4/r")[0],
            ]).setMode(.soft)

            _ = system.addStave(SystemStave(voices: [voice1, voice2]))
                .addClef(ClefName.bass)
                .addTimeSignature(TimeSignatureSpec.meter(2, 4))
            try factory.draw()
            _ = context.fillText("softmax: \(Int(softmax))", staffWidth + 20, y + 50)
            y += 100
        }

        try addRow(softmax: 15)
        try addRow(softmax: 10)
        try addRow(softmax: 5)
        try addRow(softmax: 2)
        try addRow(softmax: 1)
    }

    private func drawUpstreamFormatterNoteheadPaddingCase(factory: Factory, context: SVGRenderContext) throws {
        let registry = Registry()
        Registry.enableDefaultRegistry(registry)
        defer { Registry.disableDefaultRegistry() }

        let score = factory.EasyScore()
        _ = score.set(defaults: EasyScoreDefaults(time: .meter(9, 8)))

        let notes1 = score.notes("(d5 f5)/8,(c5 e5)/8,(d5 f5)/8,(c5 e5)/2.")
        let beams = [try Beam(Array(notes1[0..<3]), autoStem: true)]
        let voice1 = Voice().setMode(.soft).addTickables(notes1.map { $0 as Tickable })

        let notes2 = score.notes("(g4 an4)/2.,(g4 a4)/4.", options: ["clef": "treble"])
        let voice2 = Voice().setMode(.soft).addTickables(notes2.map { $0 as Tickable })

        let formatter = factory.Formatter().joinVoices([voice1]).joinVoices([voice2])
        let width = formatter.preCalculateMinTotalWidth([voice1, voice2])
        _ = formatter.format([voice1, voice2], justifyWidth: width)

        let staveWidth = width + Stave.defaultPadding
        let stave1 = Stave(x: 0, y: 50, width: staveWidth)
        let stave2 = Stave(x: 0, y: 150, width: staveWidth)
        _ = stave1.setContext(context)
        _ = stave2.setContext(context)
        try stave1.draw()
        try stave2.draw()
        try voice1.draw(context: context, stave: stave1)
        try voice2.draw(context: context, stave: stave2)
        for beam in beams {
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    private func drawUpstreamFormatterAccidentalJustificationCase(factory: Factory, context: SVGRenderContext) throws {
        let score = factory.EasyScore()
        let notes11 = score.notes("a4/2, a4/4, a4/8, ab4/16, an4/16")
        let voice11 = score.voice(notes11, time: .meter(4, 4))
        let notes21 = score.notes("c4/2, d4/8, d4/8, e4/8, e4/8")
        let voice21 = score.voice(notes21, time: .meter(4, 4))

        var beams = try Beam.generateBeams(Array(notes11[2...]))
        beams += beams
        beams += try Beam.generateBeams(Array(notes21[1..<3]))
        beams += try Beam.generateBeams(Array(notes21[3...]))

        let formatter = factory.Formatter().joinVoices([voice11]).joinVoices([voice21])
        let width = formatter.preCalculateMinTotalWidth([voice11, voice21])
        let stave11 = Stave(x: 0, y: 20, width: width + Stave.defaultPadding)
        let stave21 = Stave(x: 0, y: 130, width: width + Stave.defaultPadding)
        _ = stave11.setContext(context)
        _ = stave21.setContext(context)

        _ = formatter.format([voice11, voice21], justifyWidth: width)
        try stave11.draw()
        try stave21.draw()
        try voice11.draw(context: context, stave: stave11)
        try voice21.draw(context: context, stave: stave21)
        for beam in beams {
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    private func drawUpstreamFormatterLongMeasureCase(factory: Factory, context: SVGRenderContext) throws {
        let registry = Registry()
        Registry.enableDefaultRegistry(registry)
        defer { Registry.disableDefaultRegistry() }

        let score = factory.EasyScore()
        _ = score.set(defaults: EasyScoreDefaults(time: .meter(4, 4)))

        let notes1 = score.notes("b4/4,b4/8,b4/8,b4/4,b4/4,b4/2,b4/2,b4/4,b4/8,b4/8,b4/4,b4/4,b4/2,b4/2,b4/4,b4/8,b4/8,b4/4,b4/4,b4/2,b4/2,b4/4,b4/2,b4/8,b4/8")
        let voice1 = Voice().setMode(.soft).addTickables(notes1.map { $0 as Tickable })
        let notes2 = score.notes("d3/4,(ab3 f4)/2,d3/4,ab3/4,d3/2,ab3/4,d3/4,ab3/2,d3/4,ab3/4,d3/2,ab3/4,d3/4,ab3/2,d3/4,ab3/4,d3/2,ab3/4,d4/4,d4/2,d4/4", options: ["clef": "bass"])
        let voice2 = Voice().setMode(.soft).addTickables(notes2.map { $0 as Tickable })

        let formatter = factory.Formatter().joinVoices([voice1]).joinVoices([voice2])
        let width = formatter.preCalculateMinTotalWidth([voice1, voice2])
        _ = formatter.format([voice1, voice2], justifyWidth: width)

        let stave1 = Stave(x: 0, y: 50, width: width + Stave.defaultPadding)
        let stave2 = Stave(x: 0, y: 200, width: width + Stave.defaultPadding)
        _ = stave1.setContext(context)
        _ = stave2.setContext(context)
        try stave1.draw()
        try stave2.draw()
        try voice1.draw(context: context, stave: stave1)
        try voice2.draw(context: context, stave: stave2)
    }

    private func drawUpstreamFormatterVerticalAlignmentFewCase(factory: Factory, context: SVGRenderContext) throws {
        let notes11 = [
            StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "8")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "4")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8")),
        ]
        let notes21 = [
            StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "4")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "8d")),
        ]
        Dot.buildAndAttach([notes21[2]], all: true)

        let voice11 = Voice(timeSignature: .meter(2, 4)).setMode(.soft).addTickables(notes11.map { $0 as Tickable })
        let voice21 = Voice(timeSignature: .meter(2, 4)).setMode(.soft).addTickables(notes21.map { $0 as Tickable })
        let beams21 = try Beam.generateBeams(notes21)
        let beams11 = try Beam.generateBeams(notes11)

        let formatter = Formatter().joinVoices([voice11]).joinVoices([voice21])
        let width = formatter.preCalculateMinTotalWidth([voice11, voice21])
        _ = formatter.format([voice11, voice21], justifyWidth: width)

        let stave11 = Stave(x: 0, y: 20, width: width + Stave.defaultPadding)
        let stave21 = Stave(x: 0, y: 130, width: width + Stave.defaultPadding)
        _ = stave11.setContext(context)
        _ = stave21.setContext(context)
        try stave11.draw()
        try stave21.draw()
        try voice11.draw(context: context, stave: stave11)
        try voice21.draw(context: context, stave: stave21)
        try beams21.forEach { beam in
            _ = beam.setContext(context)
            try beam.draw()
        }
        try beams11.forEach { beam in
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    private func drawUpstreamFormatterVerticalAlignmentManyCase(
        factory: Factory,
        context: SVGRenderContext,
        globalSoftmax: Bool
    ) throws {
        let notes1 = [
            StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8r")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8r")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "16")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/5"], duration: "16")),
        ]
        let notes2 = [
            StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "16r")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "8d")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "4")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "16r")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "8d")),
            StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "4")),
        ]

        let voice1 = Voice(timeSignature: .meter(4, 4)).addTickables(notes1.map { $0 as Tickable })
        let voice2 = Voice(timeSignature: .meter(4, 4)).addTickables(notes2.map { $0 as Tickable })
        let formatter = Formatter(options: FormatterOptions(globalSoftmax: globalSoftmax))
            .joinVoices([voice1])
            .joinVoices([voice2])

        let width = formatter.preCalculateMinTotalWidth([voice1, voice2])
        _ = formatter.format([voice1, voice2], justifyWidth: width)

        let stave1 = Stave(x: 10, y: 40, width: width + Stave.defaultPadding)
        let stave2 = Stave(x: 10, y: 100, width: width + Stave.defaultPadding)
        _ = stave1.setContext(context)
        _ = stave2.setContext(context)
        try stave1.draw()
        try stave2.draw()
        try voice1.draw(context: context, stave: stave1)
        try voice2.draw(context: context, stave: stave2)
    }

    private func drawUpstreamFormatterVerticalAlignmentMixedCase(factory: Factory, context: SVGRenderContext) throws {
        let stave = Stave(x: 10, y: 200, width: 400)
        let stave2 = Stave(x: 410, y: 200, width: 400)
        _ = stave.setContext(context)
        _ = stave2.setContext(context)

        let note0 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
            .addModifier(Accidental(.doubleSharp), index: 0)
            .addModifier(FretHandFinger("4").setPosition(.below), index: 0)
            .addModifier(StringNumber("3").setPosition(.below), index: 0)
            .addModifier(Articulation("a.").setPosition(.below), index: 0)
            .addModifier(Articulation("a>").setPosition(.below), index: 0)
            .addModifier(Articulation("a^").setPosition(.below), index: 0)
            .addModifier(Articulation("am").setPosition(.below), index: 0)
            .addModifier(Articulation("a@u").setPosition(.below), index: 0)
            .addModifier(Annotation("yyyy").setVerticalJustification(.bottom), index: 0)
            .addModifier(Annotation("xxxx").setVerticalJustification(.bottom).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)
            .addModifier(Annotation("ttt").setVerticalJustification(.bottom).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)

        let note1 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8", stemDirection: .down))
            .addModifier(StringNumber("3").setPosition(.below), index: 0)
            .addModifier(Articulation("a.").setPosition(.below), index: 0)
            .addModifier(Articulation("a>").setPosition(.below), index: 0)
        let note2 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
        let notes = [note0, note1, note2]

        let note3 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
            .addModifier(StringNumber("3").setPosition(.above), index: 0)
            .addModifier(Articulation("a.").setPosition(.above), index: 0)
            .addModifier(Annotation("yyyy").setVerticalJustification(.top), index: 0)
        let note4 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8", stemDirection: .down))
            .addModifier(FretHandFinger("4").setPosition(.above), index: 0)
            .addModifier(StringNumber("3").setPosition(.above), index: 0)
            .addModifier(Articulation("a.").setPosition(.above), index: 0)
            .addModifier(Articulation("a>").setPosition(.above), index: 0)
            .addModifier(Articulation("a^").setPosition(.above), index: 0)
            .addModifier(Articulation("am").setPosition(.above), index: 0)
            .addModifier(Articulation("a@u").setPosition(.above), index: 0)
            .addModifier(Annotation("yyyy").setVerticalJustification(.top), index: 0)
            .addModifier(Annotation("xxxx").setVerticalJustification(.top).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)
            .addModifier(Annotation("ttt").setVerticalJustification(.top).setFont(FontInfo(family: VexFont.SANS_SERIF, size: 20)), index: 0)
        let note5 = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8"))
        let notesB = [note3, note4, note5]

        let tuplet = try Tuplet(notes: notes)
        _ = tuplet.setTupletLocation(.bottom)
        let tuplet2 = try Tuplet(notes: notesB)
        _ = tuplet2.setTupletLocation(.top)

        _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        _ = try Formatter.FormatAndDraw(ctx: context, stave: stave2, notes: notesB)
        try stave.draw()
        try stave2.draw()
        _ = tuplet.setContext(context)
        _ = tuplet2.setContext(context)
        try tuplet.draw()
        try tuplet2.draw()
    }

    private func drawUpstreamFormatterNotesWithTabCase(factory: Factory, context: SVGRenderContext) throws {
        let score = factory.EasyScore()
        var y = 10.0

        func justifyToWidth(_ width: Double) throws {
            let stave = factory.Stave(y: y).addClef(.treble)
            let voice = score.voice(
                score.notes("d#4/2, (c4 d4)/8, d4/8, (c#4 e4 a4)/4", options: ["stem": "up"])
            )
            y += 100

            let tabStave = factory.TabStave(y: y).addTabGlyph()
            _ = tabStave.setNoteStartX(stave.getNoteStartX())

            let tabNotes: [TabNote] = [
                try factory.TabNote(TabNoteStruct(
                    positions: [.init(str: 3, fret: 6)],
                    duration: "2"
                )).addModifier(Bend("Full"), index: 0),
                try factory.TabNote(TabNoteStruct(
                    positions: [.init(str: 2, fret: 3), .init(str: 3, fret: 5)],
                    duration: "8"
                )).addModifier(Bend("Unison"), index: 1),
                factory.TabNote(try TabNoteStruct(
                    positions: [.init(str: 3, fret: 7)],
                    duration: "8"
                )),
                factory.TabNote(try TabNoteStruct(
                    positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 7), .init(str: 2, fret: 5)],
                    duration: "4"
                )),
            ]
            let tabVoice = score.voice(tabNotes.map { $0 as Note })

            _ = factory.Formatter()
                .joinVoices([voice])
                .joinVoices([tabVoice])
                .format([voice, tabVoice], justifyWidth: width)
            y += 150
        }

        try justifyToWidth(0)
        try justifyToWidth(300)
        try factory.draw()
        _ = context
    }

    private func drawUpstreamFormatterMultipleStavesCase(factory: Factory, context: SVGRenderContext) throws {
        let score = factory.EasyScore()
        let notes11 = score.notes("f4/4, d4/8, g4/4, eb4/8")
        let notes21 = score.notes("d4/8, d4, d4, d4, e4, eb4")
        let notes31 = score.notes("a5/8, a5, a5, a5, a5, a5", options: ["stem": "down"])

        var voices = [
            score.voice(notes11, time: .meter(6, 8)),
            score.voice(notes21, time: .meter(6, 8)),
            score.voice(notes31, time: .meter(6, 8)),
        ]
        var formatter = factory.Formatter()
        voices.forEach { _ = formatter.joinVoices([$0]) }
        var width = formatter.preCalculateMinTotalWidth(voices)
        _ = formatter.format(voices, justifyWidth: width)
        var beams = [
            try Beam(Array(notes21[0..<3]), autoStem: true),
            try Beam(Array(notes21[3..<6]), autoStem: true),
            try Beam(Array(notes31[0..<3]), autoStem: true),
            try Beam(Array(notes31[3..<6]), autoStem: true),
        ]

        let staveYs = [20.0, 130.0, 250.0]
        var staveWidth = width + upstreamFormatterGlyphWidth("gClef") + upstreamFormatterGlyphWidth("timeSig8") + Stave.defaultPadding
        var staves = [
            Stave(x: 0, y: staveYs[0], width: staveWidth).addClef(.treble).addTimeSignature(.meter(6, 8)),
            Stave(x: 0, y: staveYs[1], width: staveWidth).addClef(.treble).addTimeSignature(.meter(6, 8)),
            Stave(x: 0, y: staveYs[2], width: staveWidth).addClef(.bass).addTimeSignature(.meter(6, 8)),
        ]
        _ = factory.StaveConnector(topStave: staves[1], bottomStave: staves[2], type: .brace)

        for idx in 0..<staves.count {
            _ = staves[idx].setContext(context)
            try staves[idx].draw()
            try voices[idx].draw(context: context, stave: staves[idx])
        }
        for beam in beams {
            _ = beam.setContext(context)
            try beam.draw()
        }

        let notes12 = score.notes("ab4/4, bb4/8, (cb5 eb5)/4[stem=\"down\"], d5/8[stem=\"down\"]")
        let notes22 = score.notes("(eb4 ab4)/4., (c4 eb4 ab4)/4, db5/8", options: ["stem": "up"])
        let notes32 = score.notes("a5/8, a5, a5, a5, a5, a5", options: ["stem": "down"])
        voices = [
            score.voice(notes12, time: .meter(6, 8)),
            score.voice(notes22, time: .meter(6, 8)),
            score.voice(notes32, time: .meter(6, 8)),
        ]
        formatter = factory.Formatter()
        voices.forEach { _ = formatter.joinVoices([$0]) }
        width = formatter.preCalculateMinTotalWidth(voices)
        let staveX = staves[0].getX() + staves[0].getWidth()
        staveWidth = width + Stave.defaultPadding
        staves = [
            Stave(x: staveX, y: staveYs[0], width: staveWidth),
            Stave(x: staveX, y: staveYs[1], width: staveWidth),
            Stave(x: staveX, y: staveYs[2], width: staveWidth),
        ]
        _ = formatter.format(voices, justifyWidth: width)
        beams = [
            try Beam(Array(notes32[0..<3]), autoStem: true),
            try Beam(Array(notes32[3..<6]), autoStem: true),
        ]

        for idx in 0..<staves.count {
            _ = staves[idx].setContext(context)
            try staves[idx].draw()
            try voices[idx].draw(context: context, stave: staves[idx])
            voices[idx].getTickables().forEach { drawUpstreamFormatterNoteMetrics(context: context, note: $0, yPos: staveYs[idx] - 20) }
        }
        for beam in beams {
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    private func drawUpstreamFormatterSoftmaxCase(factory: Factory, context: SVGRenderContext) throws {
        let textX = 450.0 / 0.8
        _ = context.scale(0.8, 0.8)

        func addRow(y: Double, factor: Double) throws {
            let score = factory.EasyScore()
            let system = factory.System(options: SystemOptions(
                autoWidth: true,
                x: 100,
                y: y,
                details: SystemFormatterOptions(softmaxFactor: factor)
            ))

            let notes = score.notes("C#5/h, a4/q")
                + score.beam(score.notes("Abb4/8, A4/8"))
                + score.beam(score.notes("A4/16, A#4, A4, Ab4/32, A4"))
            let voice = score.voice(notes, time: .meter(5, 4))

            _ = system.addStave(SystemStave(voices: [voice]))
                .addClef(ClefName.treble)
                .addTimeSignature(TimeSignatureSpec.meter(5, 4))
            try factory.draw()
            _ = context.fillText("softmax: \(Int(factor))", textX, y + 50)
        }

        try addRow(y: 50, factor: 1)
        try addRow(y: 150, factor: 2)
        try addRow(y: 250, factor: 5)
        try addRow(y: 350, factor: 10)
        try addRow(y: 450, factor: 15)
    }

    private func drawUpstreamFormatterMixtimeCase(factory: Factory, context: SVGRenderContext) throws {
        _ = context.scale(0.8, 0.8)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(
            debugFormatter: true,
            autoWidth: true
        ))

        let voice1 = score.voice(
            score.notes("C#5/q, B4")
                + score.beam(score.notes("A4/8, E4, C4, D4"))
        )
        _ = system.addStave(SystemStave(voices: [voice1]))
            .addClef(ClefName.treble)
            .addTimeSignature(TimeSignatureSpec.meter(4, 4))

        let voice2 = score.voice(
            score.notes("C#5/q, B4, B4")
                + score.tuplet(score.beam(score.notes("A4/8, E4, C4")))
        )
        _ = system.addStave(SystemStave(voices: [voice2]))
            .addClef(ClefName.treble)
            .addTimeSignature(TimeSignatureSpec.meter(4, 4))

        try system.formatThrowing()
        try factory.draw()
    }

    private func drawUpstreamFormatterAnnotationsCase(factory: Factory, context: SVGRenderContext) throws {
        let configs: [(sm: Double, width: Double, lyrics: [String], title: String)] = [
            (5, 550, ["ipso", "ipso-", "ipso", "ipso", "ipsoz", "ipso-", "ipso", "ipso", "ipso", "ip", "ipso"], "550px,softMax:5"),
            (5, 550, ["ipso", "ipso-", "ipsoz", "ipso", "ipso", "ipso-", "ipso", "ipso", "ipso", "ip", "ipso"], "550px,softmax:5,different word order"),
            (10, 550, ["ipso", "ipso-", "ipsoz", "ipso", "ipso", "ipso-", "ipso", "ipso", "ipso", "ip", "ipso"], "550px,softmax:10"),
            (15, 550, ["ipso", "ipso-", "ipsoz", "ipso", "ipso", "ipso-", "ipso", "ipso", "ipso", "ip", "ipso"], "550px,softmax:15"),
        ]
        let rowSize = 140.0
        let durations = ["8d", "16", "8", "8d", "16", "8", "8d", "16", "8", "4", "8"]
        let beamGroup = 3
        var y = 40.0
        var beams: [Beam] = []

        for cfg in configs {
            let stave = Stave(x: 10, y: y, width: cfg.width)
            _ = stave.setContext(context)
            _ = context.fillText(cfg.title, 100, y)
            y += rowSize

            var notes: [StaveNote] = []
            for index in 0..<durations.count {
                let duration = durations[index]
                let note = StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: duration))
                if duration.contains("d") {
                    Dot.buildAndAttach([note], all: true)
                }
                if index < cfg.lyrics.count {
                    _ = note.addModifier(
                        Annotation(cfg.lyrics[index])
                            .setVerticalJustification(.bottom)
                            .setFont(FontInfo(family: VexFont.SERIF, size: 12, weight: VexFontWeight.normal.rawValue)),
                        index: 0
                    )
                }
                notes.append(note)
            }

            for note in notes where note.getDuration().contains("d") {
                Dot.buildAndAttach([note], all: true)
            }

            var notesToBeam: [StemmableNote] = []
            for note in notes {
                if note.getIntrinsicTicks() < Double(Tables.RESOLUTION) {
                    notesToBeam.append(note)
                    if notesToBeam.count >= beamGroup {
                        beams.append(try Beam(notesToBeam))
                        notesToBeam.removeAll()
                    }
                } else {
                    notesToBeam.removeAll()
                }
            }

            let voice = Voice(time: VoiceTime(numBeats: 12, beatValue: 8))
                .setMode(.soft)
                .addTickables(notes.map { $0 as Tickable })
            let formatter = Formatter(options: FormatterOptions(softmaxFactor: cfg.sm, maxIterations: 2))
                .joinVoices([voice])
            _ = formatter.format([voice], justifyWidth: cfg.width - 11)

            try stave.draw()
            try voice.draw(context: context, stave: stave)
            for beam in beams {
                _ = beam.setContext(context)
                try beam.draw()
            }
        }
    }

    private func drawUpstreamFormatterProportionalCase(
        factory: Factory,
        context: SVGRenderContext,
        noJustification: Bool,
        iterations: Int,
        alpha: Double?
    ) throws {
        Registry.enableDefaultRegistry(Registry())
        defer { Registry.disableDefaultRegistry() }

        let system = factory.System(options: SystemOptions(
            debugFormatter: true,
            formatIterations: iterations,
            autoWidth: true,
            x: 50,
            details: SystemFormatterOptions(alpha: alpha ?? 0.5)
            ,
            noJustification: noJustification
        ))
        let score = factory.EasyScore()

        let voicesAsNotes: [[StemmableNote]] = [
            score.notes("c5/8, c5"),
            score.tuplet(score.notes("a4/8, a4, a4"), options: TupletOptions(notesOccupied: 2)),
            score.notes("c5/16, c5, c5, c5"),
            score.tuplet(score.notes("a4/16, a4, a4, a4, a4"), options: TupletOptions(notesOccupied: 4)),
            score.tuplet(score.notes("a4/32, a4, a4, a4, a4, a4, a4"), options: TupletOptions(notesOccupied: 8)),
        ]

        for notes in voicesAsNotes {
            let voice = score.voice(notes, time: .meter(1, 4))
            _ = system.addStave(SystemStave(voices: [voice], debugNoteMetrics: true))
                .addClef(ClefName.treble)
                .addTimeSignature(TimeSignatureSpec.meter(1, 4))
        }
        _ = system.addConnector(type: ConnectorType.bracket)
        try system.formatThrowing()
        try factory.draw()
        _ = context
    }

    private func drawUpstreamFormatterRightJustifyScenario(
        context: SVGRenderContext,
        time: VoiceTime,
        noteCount: Int,
        duration: String,
        finalDuration: String,
        x: Double,
        width: Double
    ) throws {
        let formatter = VexFoundation.Formatter()
        let stave = Stave(x: x, y: 20, width: width)
        _ = stave.setContext(context)

        let voice = try makeUpstreamFormatterVoice(
            time: time,
            noteCount: noteCount,
            duration: duration,
            finalDuration: finalDuration
        )
        _ = formatter.joinVoices([voice]).formatToStave([voice], stave: stave)

        try stave.draw()
        try voice.draw(context: context, stave: stave)
    }

    private func makeUpstreamFormatterVoice(
        time: VoiceTime,
        noteCount: Int,
        duration: String,
        finalDuration: String
    ) throws -> Voice {
        let voice = Voice(time: time)
        _ = voice.setMode(.soft)
        var tickables: [Tickable] = []
        for index in 0..<noteCount {
            let noteDuration = (index == noteCount - 1) ? finalDuration : duration
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: noteDuration))
            tickables.append(note)
        }
        _ = voice.addTickables(tickables)
        return voice
    }

    private func drawUpstreamFormatterTightCase(
        factory: Factory,
        context: SVGRenderContext,
        secondVoiceWholeNote: Bool,
        maxIterations: Int?
    ) throws {
        _ = context.scale(0.8, 0.8)
        let score = factory.EasyScore()

        let beamedPrefix = score.beam(score.notes("B4/16, B4, B4, B4, B4, B4, B4, B4"))
        let notesTop = beamedPrefix + score.notes("B4/q, B4")
        let notesBottom: [StemmableNote]
        if secondVoiceWholeNote {
            notesBottom = score.notes("B4/w")
        } else {
            notesBottom = score.notes("B4/q, B4") + score.beam(score.notes("B4/16, B4, B4, B4, B4, B4, B4, B4"))
        }

        let voiceTop = score.voice(notesTop.map { $0 as Note })
        let voiceBottom = score.voice(notesBottom.map { $0 as Note })

        let x = 10.0
        let y = 10.0
        let spaceBetweenStaves = 12.0

        let staveTop = factory.Stave(x: x, y: y, width: 500, options: StaveOptions(leftBar: false))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))
        let staveBottom = factory.Stave(
            x: x,
            y: y + staveTop.space(spaceBetweenStaves),
            width: 500,
            options: StaveOptions(leftBar: false)
        )
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        attachUpstreamFormatterVoice(voiceTop, to: staveTop)
        attachUpstreamFormatterVoice(voiceBottom, to: staveBottom)

        var formatterOptions = FormatterOptions()
        if let maxIterations {
            formatterOptions.maxIterations = maxIterations
        }
        let formatter = VexFoundation.Formatter(options: formatterOptions)
        _ = formatter.joinVoices([voiceTop, voiceBottom])

        let startX = max(staveTop.getNoteStartX(), staveBottom.getNoteStartX())
        _ = staveTop.setNoteStartX(startX)
        _ = staveBottom.setNoteStartX(startX)

        let justifyWidth = formatter.preCalculateMinTotalWidth([voiceTop, voiceBottom])
        let autoWidth = justifyWidth + Stave.rightPadding + (startX - x)
        _ = staveTop.setStaveWidth(autoWidth)
        _ = staveBottom.setStaveWidth(autoWidth)

        _ = formatter.format([voiceTop, voiceBottom], justifyWidth: justifyWidth)
        _ = formatter.postFormat()
        Stave.formatBegModifiers([staveTop, staveBottom])

        try factory.draw()

        let lastY = y + staveTop.space(spaceBetweenStaves) + staveBottom.space(spaceBetweenStaves)
        drawUpstreamFormatterDebugging(context: context, formatter: formatter, xPos: startX, y1: y, y2: lastY)
    }

    private func attachUpstreamFormatterVoice(_ voice: Voice, to stave: Stave) {
        _ = voice.setStave(stave)
        for tickable in voice.getTickables() {
            _ = tickable.setStave(stave)
        }
    }

    private func drawUpstreamFormatterNoteMetrics(context: SVGRenderContext, note: Tickable, yPos: Double) {
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
        drawUpstreamFormatterDot(context: context, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let deviation = formatterMetrics.space.deviation
            let prefix = deviation >= 0 ? "+" : ""
            _ = context.setFillStyle("red")
            _ = context.fillText("\(prefix)\(Int(deviation.rounded()))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = context.restore()
    }

    private func drawUpstreamFormatterDot(context: SVGRenderContext, x: Double, y: Double, color: String = "#F55") {
        _ = context.save()
        _ = context.setFillStyle(color)
        _ = context.beginPath()
        _ = context.arc(x, y, 3, 0, Double.pi * 2, false)
        _ = context.closePath()
        _ = context.fill()
        _ = context.restore()
    }

    private func drawUpstreamFormatterDebugging(
        context: SVGRenderContext,
        formatter: VexFoundation.Formatter,
        xPos: Double,
        y1: Double,
        y2: Double
    ) {
        let stavePadding = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("stave.padding", defaultValue: 0) as? Double) ?? 0
        let x = xPos + stavePadding

        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))

        for gap in formatter.contextGaps.gaps {
            _ = context.beginPath()
            _ = context.setStrokeStyle("rgba(100,200,100,0.4)")
            _ = context.setFillStyle("rgba(100,200,100,0.4)")
            _ = context.setLineWidth(1)
            _ = context.fillRect(x + gap.x1, y1, max(gap.x2 - gap.x1, 0), y2 - y1)
            _ = context.setFillStyle("green")
            _ = context.fillText("\(Int((gap.x2 - gap.x1).rounded()))", x + gap.x1, y2 + 12)
        }

        _ = context.setFillStyle("red")
        let lossText = String(
            format: "Loss: %.2f Shift: %.2f Gap: %.2f",
            formatter.totalCost,
            formatter.totalShift,
            formatter.contextGaps.total
        )
        _ = context.fillText(lossText, x - 20, y2 + 27)
        _ = context.restore()
    }

    private func upstreamFormatterGlyphWidth(_ glyphName: String) -> Double {
        guard let musicFont = Glyph.MUSIC_FONT_STACK.first,
              let glyphs = try? musicFont.getGlyphs(),
              let glyph = glyphs[glyphName],
              let resolution = try? musicFont.getResolution(),
              resolution != 0
        else {
            return Glyph.getWidth(code: glyphName, point: 39)
        }

        let widthInEm = (glyph.xMax - glyph.xMin) / resolution
        let ptScale = VexFont.scaleToPxFrom["pt"] ?? (4.0 / 3.0)
        return widthInEm * 38 * ptScale
    }
}
