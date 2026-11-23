import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("StaveTie.Simple_StaveTie")
    func staveTieSimpleMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "Simple_StaveTie",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [0, 1],
                    lastIndices: [0, 1]
                )
            )
        }
    }

    /// The editorial tie and its solid control both belong to the lower note of each dyad. (VexFlow 5.8.0)
    @Test("StaveTie.Dashed_ties_on_selected_heads")
    func staveTieDashedTiesOnSelectedHeadsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveTie", test: "Dashed_ties_on_selected_heads", width: 510, height: 155) { factory, context in
            _ = try drawUpstreamDashedPitchTies(factory, context)
        }
    }

    /// Keep the open end next to the chosen chord head, including after a width change. (VexFlow 5.8.0)
    @Test("StaveTie.Laissez_vibrer_on_one_chord_head")
    func staveTieLaissezVibrerOnOneChordHeadMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveTie", test: "Laissez_vibrer_on_one_chord_head", width: 600, height: 240) { factory, context in
            _ = try drawUpstreamLaissezVibrerTies(factory, context)
        }
    }

    @Test("StaveTie.Chord_StaveTie")
    func staveTieChordMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "Chord_StaveTie",
            notesData: "(d4 e4 f4)/2, (cn4 f#4 a4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [0, 1, 2],
                    lastIndices: [0, 1, 2]
                )
            )
        }
    }

    @Test("StaveTie.Stem_Up_StaveTie")
    func staveTieStemUpMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "Stem_Up_StaveTie",
            notesData: "(d4 e4 f4)/2, (cn4 f#4 a4)",
            notesOptions: ["stem": "up"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [0, 1, 2],
                    lastIndices: [0, 1, 2]
                )
            )
        }
    }

    @Test("StaveTie.No_End_Note_With_Clef")
    func staveTieNoEndNoteWithClefMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "No_End_Note_With_Clef",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, stave in
            _ = stave.addEndClef(.treble)
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[1],
                    firstIndices: [2],
                    lastIndices: [2]
                ),
                text: "slow."
            )
        }
    }

    @Test("StaveTie.No_End_Note")
    func staveTieNoEndNoteMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "No_End_Note",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[1],
                    firstIndices: [2],
                    lastIndices: [2]
                ),
                text: "slow."
            )
        }
    }

    @Test("StaveTie.No_Start_Note_With_Clef")
    func staveTieNoStartNoteWithClefMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "No_Start_Note_With_Clef",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, stave in
            _ = stave.addClef(.treble)
            _ = factory.StaveTie(
                notes: TieNotes(
                    lastNote: notes[0],
                    firstIndices: [2],
                    lastIndices: [2]
                ),
                text: "H"
            )
        }
    }

    @Test("StaveTie.No_Start_Note")
    func staveTieNoStartNoteMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "No_Start_Note",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    lastNote: notes[0],
                    firstIndices: [2],
                    lastIndices: [2]
                ),
                text: "H"
            )
        }
    }

    @Test("StaveTie.Set_Direction_Down")
    func staveTieSetDirectionDownMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "Set_Direction_Down",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [0, 1],
                    lastIndices: [0, 1]
                ),
                direction: .down
            )
        }
    }

    @Test("StaveTie.Set_Direction_Up")
    func staveTieSetDirectionUpMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "Set_Direction_Up",
            notesData: "(cb4 e#4 a4)/2, (d4 e4 f4)",
            notesOptions: ["stem": "down"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [0, 1],
                    lastIndices: [0, 1]
                ),
                direction: .up
            )
        }
    }

    @Test("StaveTie.Tie_Algorithms")
    func staveTieTieAlgorithmsMatchesUpstream() throws {
        try runStaveTieParityCase(
            testName: "Tie_Algorithms",
            notesData: "(c4 e4 g4)/2, (c4 e4 g4)",
            notesOptions: ["stem": "up"]
        ) { factory, notes, _ in
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [0],
                    lastIndices: [0]
                )
            )
            _ = factory.StaveTie(
                notes: TieNotes(
                    firstNote: notes[0],
                    lastNote: notes[1],
                    firstIndices: [1, 2],
                    lastIndices: [1, 2]
                ),
                direction: .down
            )
        }
    }

    private func runStaveTieParityCase(
        testName: String,
        notesData: String,
        notesOptions: [String: String],
        setupTies: (Factory, [StemmableNote], Stave) -> Void
    ) throws {
        try runCategorySVGParityCase(module: "StaveTie", test: testName, width: 300, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()
            let notes = score.notes(notesData, options: notesOptions)
            let voice = score.voice(notes)

            setupTies(factory, notes, stave)

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}

/// Upstream `dashedPitchTies` (stavetie_tests.ts, VexFlow 5.8.0). Returns the ties and voices.
func drawUpstreamDashedPitchTies(_ f: Factory, _ ctx: RenderContext) throws -> [(tie: StaveTie, voice: Voice)] {
    var result: [(tie: StaveTie, voice: Voice)] = []
    for (bar, key) in ["e/4", "g/4"].enumerated() {
        let stave = f.Stave(x: 10 + Double(bar) * 240, y: 15, width: 240).addClef(.treble)
        let dyad = {
            f.StaveNote(try StaveNoteStruct(parsingKeys: [key, "b/4"], duration: "h", stemDirection: .up))
        }
        let first = try dyad()
        let last = try dyad()
        let voice = f.Voice().addTickables([first, last])
        _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        let tie = f.StaveTie(notes: TieNotes(firstNote: first, lastNote: last, firstIndexes: [0], lastIndexes: [0]))
            .setDirection(TieDirection.up)
        if bar == 0 { _ = tie.setStyle(ElementStyle(lineDash: "4 3")) }
        try stave.draw()
        try voice.draw(context: ctx, stave: stave)
        try tie.drawWithStyle()
        result.append((tie, voice))
    }
    return result
}

/// Upstream `localTies` (stavetie_tests.ts, VexFlow 5.8.0).
func drawUpstreamLaissezVibrerTies(
    _ f: Factory,
    _ ctx: RenderContext
) throws -> [(stave: Stave, lower: StaveNote, rest: StaveNote, upper: StaveNote, voice: Voice, ties: [StaveTie])] {
    var result: [(stave: Stave, lower: StaveNote, rest: StaveNote, upper: StaveNote, voice: Voice, ties: [StaveTie])] = []
    for (row, width) in [540.0, 290.0].enumerated() {
        let stave = f.Stave(x: 12, y: 12 + Double(row) * 110, width: width).addClef(.treble)
        let chord = {
            f.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4", "a/4"], duration: "q", stemDirection: .up))
        }
        let lower = try chord()
        let rest = f.StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr"))
        let upper = try chord()
        let voice = f.Voice().addTickables([
            lower, rest, upper, f.StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr")),
        ])
        _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        let down = f.StaveTie(
            notes: TieNotes(firstNote: lower, firstIndexes: [0]),
            direction: .up,
            laissezVibrer: 18
        )
        let up = f.StaveTie(
            notes: TieNotes(firstNote: upper, firstIndexes: [1]),
            direction: .down,
            laissezVibrer: 22
        )
        try stave.draw()
        try voice.draw(context: ctx, stave: stave)
        for tie in [down, up] { try tie.drawWithStyle() }
        result.append((stave, lower, rest, upper, voice, [down, up]))
    }
    return result
}
