import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Strokes.Strokes___Brush_Roll_Rasquedo")
    func strokesBrushRollRasquedoMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Strokes", test: "Strokes___Brush_Roll_Rasquedo", width: 600, height: 200) {
            factory,
            _ in
            let score = factory.EasyScore()

            let stave1 = factory.Stave(width: 250).setEndBarType(.double)
            let notes1 = score.notes("(a3 e4 a4)/4, (c4 e4 g4), (c4 e4 g4), (c4 e4 g4)", options: ["stem": "up"])
            _ = notes1[0].addModifier(Stroke(type: .brushDown), index: 0)
            _ = notes1[1]
                .addModifier(Stroke(type: .brushUp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 0)
            _ = notes1[2].addModifier(Stroke(type: .brushDown), index: 0)
            _ = notes1[3].addModifier(Stroke(type: .brushUp), index: 0)
            let voice1 = score.voice(notes1)
            _ = factory.Formatter().joinVoices([voice1]).formatToStave([voice1], stave: stave1)

            let stave2 = factory
                .Stave(x: stave1.getWidth() + stave1.getX(), y: stave1.getY(), width: 300)
                .setEndBarType(.double)
            let notes2 = score.notes("(c4 d4 g4)/4, (c4 d4 g4), (c4 d4 g4), (c4 d4 a4)", options: ["stem": "up"])
            _ = notes2[0].addModifier(Stroke(type: .rollDown), index: 0)
            _ = notes2[1].addModifier(Stroke(type: .rollUp), index: 0)
            _ = notes2[2].addModifier(Stroke(type: .rasquedoDown), index: 0)
            _ = notes2[3]
                .addModifier(Stroke(type: .rasquedoUp), index: 0)
                .addModifier(factory.Accidental(type: .doubleFlat), index: 0)
                .addModifier(factory.Accidental(type: .doubleFlat), index: 1)
                .addModifier(factory.Accidental(type: .doubleFlat), index: 2)
            let voice2 = score.voice(notes2)
            _ = factory.Formatter().joinVoices([voice2]).formatToStave([voice2], stave: stave2)

            try factory.draw()
        }
    }

    @Test("Strokes.Strokes___Arpeggio_directionless__without_arrows_")
    func strokesArpeggioDirectionlessMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Strokes",
            test: "Strokes___Arpeggio_directionless__without_arrows_",
            width: 700,
            height: 200
        ) { factory, _ in
            let score = factory.EasyScore()
            let stave = factory.Stave(x: 100, width: 500).setEndBarType(.double)

            let notes = score.notes("(g4 b4 d5)/4, (g4 b4 d5 g5), (g4 b4 d5 g5), (g4 b4 d5)", options: ["stem": "up"])

            let graceNoteStructs = try [
                GraceNoteStruct(parsingKeys: ["e/4"], duration: "32"),
                GraceNoteStruct(parsingKeys: ["f/4"], duration: "32"),
                GraceNoteStruct(parsingKeys: ["g/4"], duration: "32"),
            ]
            let graceNotes = graceNoteStructs.map { factory.GraceNote($0) }
            let graceNoteGroup = factory.GraceNoteGroup(notes: graceNotes, slur: false)
            _ = graceNoteGroup.beamNotes()

            _ = notes[0].addModifier(Stroke(type: .arpeggioDirectionless), index: 0)
            _ = notes[1]
                .addModifier(Stroke(type: .arpeggioDirectionless), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 3)
            _ = notes[2]
                .addModifier(Stroke(type: .arpeggioDirectionless), index: 0)
                .addModifier(factory.Accidental(type: .flat), index: 1)
                .addModifier(graceNoteGroup, index: 0)
            _ = notes[3]
                .addModifier(Stroke(type: .arpeggioDirectionless), index: 0)
                .addModifier(
                    factory.NoteSubGroup(notes: [
                        factory.ClefNote(type: .treble, size: .default, annotation: .octaveUp),
                    ]),
                    index: 0
                )

            let voice = score.voice(notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Strokes.Strokes___Multi_Voice")
    func strokesMultiVoiceMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Strokes", test: "Strokes___Multi_Voice", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let stave = factory.Stave()

            let notes1 = score.notes("(c4 e4 g4)/4, (c4 e4 g4), (c4 d4 a4), (c4 d4 a4)", options: ["stem": "up"])
            _ = notes1[0].addModifier(Stroke(type: .rasquedoDown), index: 0)
            _ = notes1[1]
                .addModifier(Stroke(type: .rasquedoUp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
            _ = notes1[2].addModifier(Stroke(type: .brushUp), index: 0)
            _ = notes1[3].addModifier(Stroke(type: .brushDown), index: 0)

            let notes2 = score.notes("e3/8, e3, e3, e3, e3, e3, e3, e3", options: ["stem": "down"])
            _ = factory.Beam(notes: Array(notes2[0..<4]))
            _ = factory.Beam(notes: Array(notes2[4..<8]))

            let voices = [score.voice(notes1), score.voice(notes2)]
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }

    @Test("Strokes.Strokes___Notation_and_Tab")
    func strokesNotationAndTabMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Strokes", test: "Strokes___Notation_and_Tab", width: 500, height: 300) { factory, context in
            let stave = factory.Stave(x: 15, y: 40, width: 450).addClef(.treble)

            let notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4", "d/5", "g/5"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Accidental(type: .flat), index: 1)
                    .addModifier(factory.Accidental(type: .flat), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5", "d/5"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/3", "e/4", "a/4", "d/5"], duration: "8", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/3", "e/4", "a/4", "c/5", "e/5", "a/5"], duration: "8", stemDirection: .up))
                    .addModifier(factory.Accidental(type: .sharp), index: 3),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/3", "e/4", "a/4", "d/5"], duration: "8", stemDirection: .up)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/3", "e/4", "a/4", "c/5", "f/5", "a/5"], duration: "8", stemDirection: .up))
                    .addModifier(factory.Accidental(type: .sharp), index: 3)
                    .addModifier(factory.Accidental(type: .sharp), index: 4),
            ]

            let tabStave = factory
                .TabStave(x: stave.getX(), y: 140, width: 450)
                .addClef(.tab)
                .setNoteStartX(stave.getNoteStartX())

            let tabNotes: [TabNote] = [
                factory
                    .TabNote(TabNoteStruct(
                        positions: [
                            TabNotePosition(str: 1, fret: 3),
                            TabNotePosition(str: 2, fret: 2),
                            TabNotePosition(str: 3, fret: 3),
                        ],
                        duration: .quarter
                    ))
                    .addModifier(Bend("Full"), index: 0),
                factory
                    .TabNote(TabNoteStruct(
                        positions: [
                            TabNotePosition(str: 2, fret: 3),
                            TabNotePosition(str: 3, fret: 5),
                        ],
                        duration: .quarter
                    ))
                    .addModifier(Bend("Unison"), index: 1),
                factory.TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 3, fret: 7),
                        TabNotePosition(str: 4, fret: 7),
                        TabNotePosition(str: 5, fret: 7),
                        TabNotePosition(str: 6, fret: 7),
                    ],
                    duration: .eighth
                )),
                factory.TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 1, fret: 5),
                        TabNotePosition(str: 2, fret: 5),
                        TabNotePosition(str: 3, fret: 6),
                        TabNotePosition(str: 4, fret: 7),
                        TabNotePosition(str: 5, fret: 7),
                        TabNotePosition(str: 6, fret: 5),
                    ],
                    duration: .eighth
                )),
                factory.TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 3, fret: 7),
                        TabNotePosition(str: 4, fret: 7),
                        TabNotePosition(str: 5, fret: 7),
                        TabNotePosition(str: 6, fret: 7),
                    ],
                    duration: .eighth
                )),
                factory.TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 1, fret: 5),
                        TabNotePosition(str: 2, fret: 5),
                        TabNotePosition(str: 3, fret: 6),
                        TabNotePosition(str: 4, fret: 7),
                        TabNotePosition(str: 5, fret: 7),
                        TabNotePosition(str: 6, fret: 5),
                    ],
                    duration: .eighth
                )),
            ]

            _ = notes[0].addModifier(Stroke(type: .brushDown), index: 0)
            _ = notes[1].addModifier(Stroke(type: .brushUp), index: 0)
            _ = notes[2].addModifier(Stroke(type: .rollDown), index: 0)
            _ = notes[3].addModifier(Stroke(type: .rollUp), index: 0)
            _ = notes[4].addModifier(Stroke(type: .rasquedoDown), index: 0)
            _ = notes[5].addModifier(Stroke(type: .rasquedoUp), index: 0)

            _ = tabNotes[0].addModifier(Stroke(type: .brushDown), index: 0)
            _ = tabNotes[1].addModifier(Stroke(type: .brushUp), index: 0)
            _ = tabNotes[2].addModifier(Stroke(type: .rollDown), index: 0)
            _ = tabNotes[3].addModifier(Stroke(type: .rollUp), index: 0)
            _ = tabNotes[4].addModifier(Stroke(type: .rasquedoDown), index: 0)
            _ = tabNotes[5].addModifier(Stroke(type: .rasquedoUp), index: 0)

            let bracket = StaveConnector(topStave: stave, bottomStave: tabStave).setType(.bracket).setContext(context)
            let line = StaveConnector(topStave: stave, bottomStave: tabStave).setType(.singleLeft).setContext(context)

            let voice = factory.Voice().addTickables(notes.map { $0 as Tickable })
            let tabVoice = factory.Voice().addTickables(tabNotes.map { $0 as Tickable })
            let beams = try Beam.applyAndGetBeams(voice)
            _ = factory.Formatter().joinVoices([voice]).joinVoices([tabVoice]).formatToStave([voice, tabVoice], stave: stave)

            try stave.draw()
            try tabStave.draw()
            try voice.draw(context: context, stave: stave)
            try tabVoice.draw(context: context, stave: tabStave)
            try bracket.draw()
            try line.draw()
            try drawUpstreamStrokeBeams(beams, context: context)
        }
    }

    @Test("Strokes.Strokes___Multi_Voice_Notation_and_Tab")
    func strokesMultiVoiceNotationAndTabMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Strokes",
            test: "Strokes___Multi_Voice_Notation_and_Tab",
            width: 400,
            height: 275
        ) { factory, context in
            let score = factory.EasyScore()
            let stave = factory.Stave().addClef(.treble)

            let notes1 = score.notes("(g4 b4 e5)/4, (g4 b4 e5), (g4 b4 e5), (g4 b4 e5)", options: ["stem": "up"])
            _ = notes1[0].addModifier(Stroke(type: .rollDown, allVoices: false), index: 0)
            _ = notes1[1].addModifier(Stroke(type: .rasquedoUp), index: 0)
            _ = notes1[2].addModifier(Stroke(type: .brushUp, allVoices: false), index: 0)
            _ = notes1[3].addModifier(Stroke(type: .brushDown), index: 0)

            let notes2 = score.notes("g3/4, g3, g3, g3", options: ["stem": "down"])

            let tabStave = factory.TabStave(y: 100).addClef(.tab).setNoteStartX(stave.getNoteStartX())

            let tabNotes1: [TabNote] = (0..<4).map { index in
                let note = factory.TabNote(TabNoteStruct(
                    positions: [
                        TabNotePosition(str: 3, fret: 0),
                        TabNotePosition(str: 2, fret: 0),
                        TabNotePosition(str: 1, fret: 1),
                    ],
                    duration: .quarter
                ))
                switch index {
                case 0:
                    _ = note.addModifier(Stroke(type: .rollDown, allVoices: false), index: 0)
                case 1:
                    _ = note.addModifier(Stroke(type: .rasquedoUp), index: 0)
                case 2:
                    _ = note.addModifier(Stroke(type: .brushUp, allVoices: false), index: 0)
                default:
                    _ = note.addModifier(Stroke(type: .brushDown), index: 0)
                }
                return note
            }

            let tabNotes2: [TabNote] = (0..<4).map { _ in
                factory.TabNote(TabNoteStruct(
                    positions: [TabNotePosition(str: 6, fret: 3)],
                    duration: .quarter
                ))
            }

            let voices = [
                score.voice(notes1),
                score.voice(notes2),
                score.voice(tabNotes1),
                score.voice(tabNotes2),
            ]
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try stave.draw()
            try tabStave.draw()
            try voices[0].draw(context: context, stave: stave)
            try voices[1].draw(context: context, stave: stave)
            try voices[2].draw(context: context, stave: tabStave)
            try voices[3].draw(context: context, stave: tabStave)
        }
    }

    private func drawUpstreamStrokeBeams(_ beams: [Beam], context: SVGRenderContext) throws {
        for beam in beams {
            _ = beam.setContext(context)
            try beam.draw()
        }
    }
}
