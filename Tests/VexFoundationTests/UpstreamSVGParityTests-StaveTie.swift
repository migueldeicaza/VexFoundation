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
