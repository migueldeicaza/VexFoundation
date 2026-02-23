import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Rests.Outside_Stave")
    func restsOutsideStaveMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Rests", test: "Outside_Stave", width: 700, height: 150) { _, context in
            let stave = try setupRestsContext(context: context, width: 700, height: 150)
            let notes: [StaveNote] = try [
                restsNote(["a/5"], duration: "wr", stemDirection: .up),
                restsNote(["c/6"], duration: "hr", stemDirection: .up),
                restsNote(["b/4"], duration: "hr", stemDirection: .up),
                restsNote(["a/3"], duration: "wr", stemDirection: .up),
                restsNote(["f/3"], duration: "hr", stemDirection: .up),
                restsNote(["b/4"], duration: "wr", stemDirection: .up),
            ]
            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Rests.Dotted")
    func restsDottedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Rests", test: "Dotted", width: 700, height: 150) { _, context in
            let stave = try setupRestsContext(context: context, width: 700, height: 150)
            let notes: [StaveNote] = try [
                restsNote(["b/4"], duration: "1/2r", stemDirection: .up),
                restsNote(["b/4"], duration: "wr", stemDirection: .up),
                restsNote(["b/4"], duration: "hr", stemDirection: .up),
                restsNote(["b/4"], duration: "4r", stemDirection: .up),
                restsNote(["b/4"], duration: "8r", stemDirection: .up),
                restsNote(["b/4"], duration: "16r", stemDirection: .up),
                restsNote(["b/4"], duration: "32r", stemDirection: .up),
                restsNote(["b/4"], duration: "64r", stemDirection: .up),
                restsNote(["b/4"], duration: "128r", stemDirection: .up),
                restsNote(["b/4"], duration: "256r", stemDirection: .up),
            ]
            Dot.buildAndAttach(notes.map { $0 as Note }, all: true)
            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("Rests.Auto_Align___Beamed_Notes_Stems_Up")
    func restsAutoAlignBeamedNotesStemsUpMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Beamed_Notes_Stems_Up",
            width: 600,
            height: 160
        ) { _, context in
            let stave = try setupRestsContext(context: context, width: 600, height: 160)
            let notes: [StaveNote] = try [
                restsNote(["e/5"], duration: "8", stemDirection: .up),
                restsNote(["b/4"], duration: "8r", stemDirection: .up),
                restsNote(["b/5"], duration: "8", stemDirection: .up),
                restsNote(["c/5"], duration: "8", stemDirection: .up),
                restsNote(["b/4", "d/5", "a/5"], duration: "8", stemDirection: .up),
                restsNote(["b/4"], duration: "8r", stemDirection: .up),
                restsNote(["b/4"], duration: "8r", stemDirection: .up),
                restsNote(["c/4"], duration: "8", stemDirection: .up),
                restsNote(["b/4", "d/5", "a/5"], duration: "8", stemDirection: .up),
                restsNote(["b/4"], duration: "8", stemDirection: .up),
                restsNote(["b/4"], duration: "8r", stemDirection: .up),
                restsNote(["c/4"], duration: "8", stemDirection: .up),
            ]

            let beam1 = try Beam(Array(notes[0..<4]).map { $0 as StemmableNote })
            let beam2 = try Beam(Array(notes[4..<8]).map { $0 as StemmableNote })
            let beam3 = try Beam(Array(notes[8..<12]).map { $0 as StemmableNote })

            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = beam1.setContext(context)
            _ = beam2.setContext(context)
            _ = beam3.setContext(context)
            try beam1.draw()
            try beam2.draw()
            try beam3.draw()
        }
    }

    @Test("Rests.Auto_Align___Beamed_Notes_Stems_Down")
    func restsAutoAlignBeamedNotesStemsDownMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Beamed_Notes_Stems_Down",
            width: 600,
            height: 160
        ) { _, context in
            let stave = try setupRestsContext(context: context, width: 600, height: 160)
            let notes: [StaveNote] = try [
                restsNote(["a/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["b/5"], duration: "8", stemDirection: .down),
                restsNote(["c/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4", "d/5", "a/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["e/4"], duration: "8", stemDirection: .down),
                restsNote(["b/4", "d/5", "a/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["e/4"], duration: "8", stemDirection: .down),
            ]

            let beam1 = try Beam(Array(notes[0..<4]).map { $0 as StemmableNote })
            let beam2 = try Beam(Array(notes[4..<8]).map { $0 as StemmableNote })
            let beam3 = try Beam(Array(notes[8..<12]).map { $0 as StemmableNote })

            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = beam1.setContext(context)
            _ = beam2.setContext(context)
            _ = beam3.setContext(context)
            try beam1.draw()
            try beam2.draw()
            try beam3.draw()
        }
    }

    @Test("Rests.Auto_Align___Tuplets_Stems_Up")
    func restsAutoAlignTupletsStemsUpMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Tuplets_Stems_Up",
            width: 600,
            height: 160
        ) { _, context in
            let stave = try setupRestsContext(context: context, width: 600, height: 160)
            let notes: [StaveNote] = try [
                restsNote(["b/4"], duration: "4", stemDirection: .up),
                restsNote(["b/4"], duration: "4", stemDirection: .up),
                restsNote(["a/5"], duration: "4r", stemDirection: .up),
                restsNote(["a/5"], duration: "4r", stemDirection: .up),
                restsNote(["g/5"], duration: "4r", stemDirection: .up),
                restsNote(["b/5"], duration: "4", stemDirection: .up),
                restsNote(["a/5"], duration: "4", stemDirection: .up),
                restsNote(["g/5"], duration: "4r", stemDirection: .up),
                restsNote(["b/4"], duration: "4", stemDirection: .up),
                restsNote(["a/5"], duration: "4", stemDirection: .up),
                restsNote(["b/4"], duration: "4r", stemDirection: .up),
                restsNote(["b/4"], duration: "4r", stemDirection: .up),
            ]

            let tuplet1 = try Tuplet(notes: Array(notes[0..<3]).map { $0 as Note }).setTupletLocation(.top)
            let tuplet2 = try Tuplet(notes: Array(notes[3..<6]).map { $0 as Note }).setTupletLocation(.top)
            let tuplet3 = try Tuplet(notes: Array(notes[6..<9]).map { $0 as Note }).setTupletLocation(.top)
            let tuplet4 = try Tuplet(notes: Array(notes[9..<12]).map { $0 as Note }).setTupletLocation(.top)

            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = tuplet1.setContext(context)
            _ = tuplet2.setContext(context)
            _ = tuplet3.setContext(context)
            _ = tuplet4.setContext(context)
            try tuplet1.draw()
            try tuplet2.draw()
            try tuplet3.draw()
            try tuplet4.draw()
        }
    }

    @Test("Rests.Auto_Align___Tuplets_Stems_Down")
    func restsAutoAlignTupletsStemsDownMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Tuplets_Stems_Down",
            width: 600,
            height: 160
        ) { _, context in
            let stave = try setupRestsContext(context: context, width: 600, height: 160)
            let notes: [StaveNote] = try [
                restsNote(["a/5"], duration: "8r", stemDirection: .down),
                restsNote(["g/5"], duration: "8r", stemDirection: .down),
                restsNote(["b/4"], duration: "8", stemDirection: .down),
                restsNote(["a/5"], duration: "8r", stemDirection: .down),
                restsNote(["g/5"], duration: "8", stemDirection: .down),
                restsNote(["b/5"], duration: "8", stemDirection: .down),
                restsNote(["a/5"], duration: "8", stemDirection: .down),
                restsNote(["g/5"], duration: "8r", stemDirection: .down),
                restsNote(["b/4"], duration: "8", stemDirection: .down),
                restsNote(["a/5"], duration: "8", stemDirection: .down),
                restsNote(["g/5"], duration: "8r", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
            ]

            let beam1 = try Beam(Array(notes[0..<3]).map { $0 as StemmableNote })
            let beam2 = try Beam(Array(notes[3..<6]).map { $0 as StemmableNote })
            let beam3 = try Beam(Array(notes[6..<9]).map { $0 as StemmableNote })
            let beam4 = try Beam(Array(notes[9..<12]).map { $0 as StemmableNote })
            let tuplet1 = try Tuplet(notes: Array(notes[0..<3]).map { $0 as Note }).setTupletLocation(.bottom)
            let tuplet2 = try Tuplet(notes: Array(notes[3..<6]).map { $0 as Note }).setTupletLocation(.bottom)
            let tuplet3 = try Tuplet(notes: Array(notes[6..<9]).map { $0 as Note }).setTupletLocation(.bottom)
            let tuplet4 = try Tuplet(notes: Array(notes[9..<12]).map { $0 as Note }).setTupletLocation(.bottom)

            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = tuplet1.setContext(context)
            _ = tuplet2.setContext(context)
            _ = tuplet3.setContext(context)
            _ = tuplet4.setContext(context)
            try tuplet1.draw()
            try tuplet2.draw()
            try tuplet3.draw()
            try tuplet4.draw()

            _ = beam1.setContext(context)
            _ = beam2.setContext(context)
            _ = beam3.setContext(context)
            _ = beam4.setContext(context)
            try beam1.draw()
            try beam2.draw()
            try beam3.draw()
            try beam4.draw()
        }
    }

    @Test("Rests.Auto_Align___Single_Voice__Default_")
    func restsAutoAlignSingleVoiceDefaultMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Single_Voice__Default_",
            width: 600,
            height: 160
        ) { _, context in
            let stave = try setupRestsContext(context: context, width: 600, height: 160)
            let notes: [StaveNote] = try [
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
                restsNote(["f/4"], duration: "4", stemDirection: .down),
                restsNote(["e/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["a/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["b/4"], duration: "8", stemDirection: .down),
                restsNote(["e/5"], duration: "8", stemDirection: .down),
                restsNote(["a/5"], duration: "4", stemDirection: .up),
                restsNote(["b/4"], duration: "4r", stemDirection: .up),
                restsNote(["b/5"], duration: "4", stemDirection: .up),
                restsNote(["d/5"], duration: "4", stemDirection: .down),
                restsNote(["g/5"], duration: "4", stemDirection: .down),
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
            ]

            let beam = try Beam(Array(notes[5..<9]).map { $0 as StemmableNote })
            let tuplet = try Tuplet(notes: Array(notes[9..<12]).map { $0 as Note }).setTupletLocation(.top)

            _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
            _ = tuplet.setContext(context)
            try tuplet.draw()
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    @Test("Rests.Auto_Align___Single_Voice__Align_All_")
    func restsAutoAlignSingleVoiceAlignAllMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Single_Voice__Align_All_",
            width: 600,
            height: 160
        ) { _, context in
            let stave = try setupRestsContext(context: context, width: 600, height: 160)
            let notes: [StaveNote] = try [
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
                restsNote(["f/4"], duration: "4", stemDirection: .down),
                restsNote(["e/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["a/5"], duration: "8", stemDirection: .down),
                restsNote(["b/4"], duration: "8r", stemDirection: .down),
                restsNote(["b/4"], duration: "8", stemDirection: .down),
                restsNote(["e/5"], duration: "8", stemDirection: .down),
                restsNote(["a/5"], duration: "4", stemDirection: .up),
                restsNote(["b/4"], duration: "4r", stemDirection: .up),
                restsNote(["b/5"], duration: "4", stemDirection: .up),
                restsNote(["d/5"], duration: "4", stemDirection: .down),
                restsNote(["g/5"], duration: "4", stemDirection: .down),
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
                restsNote(["b/4"], duration: "4r", stemDirection: .down),
            ]

            let beam = try Beam(Array(notes[5..<9]).map { $0 as StemmableNote })
            let tuplet = try Tuplet(notes: Array(notes[9..<12]).map { $0 as Note }).setTupletLocation(.top)

            _ = try Formatter.FormatAndDraw(
                ctx: context,
                stave: stave,
                notes: notes,
                params: FormatParams(alignRests: true)
            )
            _ = tuplet.setContext(context)
            try tuplet.draw()
            _ = beam.setContext(context)
            try beam.draw()
        }
    }

    @Test("Rests.Auto_Align___Multi_Voice")
    func restsAutoAlignMultiVoiceMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rests",
            test: "Auto_Align___Multi_Voice",
            width: 600,
            height: 200
        ) { _, context in
            let stave = Stave(x: 50, y: 10, width: 500).addClef(.treble)
            _ = stave.setContext(context)
            _ = stave.addTimeSignature(.meter(4, 4))
            try stave.draw()

            func noteOnStave(_ keys: [String], duration: String, stemDirection: StemDirection? = nil) throws -> StaveNote {
                let note = StaveNote(try StaveNoteStruct(parsingKeys: keys, duration: duration, stemDirection: stemDirection))
                _ = note.setStave(stave)
                return note
            }

            let notes1: [StaveNote] = try [
                noteOnStave(["c/4", "e/4", "g/4"], duration: "4"),
                noteOnStave(["b/4"], duration: "4r"),
                noteOnStave(["c/4", "d/4", "a/4"], duration: "4"),
                noteOnStave(["b/4"], duration: "4r"),
            ]
            let notes2: [StaveNote] = try [
                noteOnStave(["e/3"], duration: "8", stemDirection: .down),
                noteOnStave(["b/4"], duration: "8r", stemDirection: .down),
                noteOnStave(["b/4"], duration: "8r", stemDirection: .down),
                noteOnStave(["e/3"], duration: "8", stemDirection: .down),
                noteOnStave(["e/3"], duration: "8", stemDirection: .down),
                noteOnStave(["b/4"], duration: "8r", stemDirection: .down),
                noteOnStave(["e/3"], duration: "8", stemDirection: .down),
                noteOnStave(["e/3"], duration: "8", stemDirection: .down),
            ]

            let voice1 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables(notes1.map { $0 as Tickable })
            let voice2 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables(notes2.map { $0 as Tickable })

            _ = Formatter()
                .joinVoices([voice1, voice2])
                .formatToStave([voice1, voice2], stave: stave, options: FormatParams(alignRests: true))

            let beam21 = try Beam(Array(notes2[0..<4]).map { $0 as StemmableNote })
            let beam22 = try Beam(Array(notes2[4..<8]).map { $0 as StemmableNote })

            try voice2.draw(context: context)
            try voice1.draw(context: context)

            _ = beam21.setContext(context)
            _ = beam22.setContext(context)
            try beam21.draw()
            try beam22.draw()
        }
    }

    private func setupRestsContext(
        context: SVGRenderContext,
        width: Double,
        height _: Double
    ) throws -> Stave {
        _ = context.scale(0.9, 0.9)
        _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
        let stave = Stave(x: 10, y: 30, width: width)
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))
        _ = stave.setContext(context)
        try stave.draw()
        return stave
    }

    private func restsNote(
        _ keys: [String],
        duration: String,
        stemDirection: StemDirection
    ) throws -> StaveNote {
        StaveNote(try StaveNoteStruct(
            parsingKeys: keys,
            duration: duration,
            stemDirection: stemDirection
        ))
    }
}
