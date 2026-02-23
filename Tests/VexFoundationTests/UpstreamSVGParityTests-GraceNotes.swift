import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    private var graceStemDurations: [String] { ["8", "16", "32", "64", "128"] }

    private func makeGraceStaveNote(
        _ factory: Factory,
        keys: [String],
        duration: String,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil
    ) throws -> StaveNote {
        try factory.StaveNote(
            StaveNoteStruct(
                parsingKeys: keys,
                duration: duration,
                stemDirection: stemDirection,
                autoStem: autoStem
            )
        )
    }

    private func makeGraceNote(
        _ factory: Factory,
        keys: [String],
        duration: String,
        stemDirection: StemDirection? = nil,
        slash: Bool = false
    ) throws -> GraceNote {
        try factory.GraceNote(
            GraceNoteStruct(
                parsingKeys: keys,
                duration: duration,
                slash: slash,
                stemDirection: stemDirection
            )
        )
    }

    private func makeGraceVoice(_ factory: Factory, _ notes: [StaveNote]) -> Voice {
        factory.Voice()
            .setStrict(false)
            .addTickables(notes.map { $0 as Tickable })
    }

    private func drawGraceStemWithBeamsCase(
        factory: Factory,
        stave: Stave,
        keys1: [String],
        stemDirection1: StemDirection,
        keys2: [String],
        stemDirection2: StemDirection
    ) throws {
        func createBeamedNoteBlock(keys: [String], stemDirection: StemDirection) throws -> [StaveNote] {
            var staveNotes: [StaveNote] = []
            var graceNotes: [GraceNote] = []
            var notesToBeam: [[StemmableNote]] = []

            for duration in graceStemDurations {
                let n0 = try makeGraceStaveNote(factory, keys: keys, duration: duration, stemDirection: stemDirection)
                let n1 = try makeGraceStaveNote(factory, keys: keys, duration: duration, stemDirection: stemDirection)
                staveNotes.append(contentsOf: [n0, n1])
                _ = factory.Beam(notes: [n0, n1])

                let g0 = try makeGraceNote(factory, keys: keys, duration: duration, stemDirection: stemDirection)
                let g1 = try makeGraceNote(factory, keys: keys, duration: duration, stemDirection: stemDirection)
                graceNotes.append(contentsOf: [g0, g1])
                notesToBeam.append([g0, g1])
            }

            let graceGroup = factory.GraceNoteGroup(notes: graceNotes)
            for pair in notesToBeam {
                _ = graceGroup.beamNotes(pair)
            }
            _ = staveNotes[0].addModifier(graceGroup, index: 0)
            return staveNotes
        }

        let voice = factory.Voice().setStrict(false)
        _ = voice.addTickables(try createBeamedNoteBlock(keys: keys1, stemDirection: stemDirection1).map { $0 as Tickable })
        _ = voice.addTickables(try createBeamedNoteBlock(keys: keys2, stemDirection: stemDirection2).map { $0 as Tickable })
        _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        try factory.draw()
    }

    private func drawGraceMultipleVoicesCase(factory: Factory, stave: Stave, drawTwice: Bool) throws {
        let notes: [StaveNote] = try [
            makeGraceStaveNote(factory, keys: ["f/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["f/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["d/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["c/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["c/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["d/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["f/5"], duration: "16", stemDirection: .up),
            makeGraceStaveNote(factory, keys: ["e/5"], duration: "16", stemDirection: .up),
        ]

        let notes2: [StaveNote] = try [
            makeGraceStaveNote(factory, keys: ["f/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["e/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["d/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["c/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["c/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["d/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["f/4"], duration: "16", stemDirection: .down),
            makeGraceStaveNote(factory, keys: ["e/4"], duration: "16", stemDirection: .down),
        ]

        let graceNotes1 = [try makeGraceNote(factory, keys: ["b/4"], duration: "8", stemDirection: .up, slash: true)]
        let graceNotes2 = [try makeGraceNote(factory, keys: ["f/4"], duration: "8", stemDirection: .down, slash: true)]
        let graceNotes3 = try [
            makeGraceNote(factory, keys: ["f/4"], duration: "32", stemDirection: .down),
            makeGraceNote(factory, keys: ["e/4"], duration: "32", stemDirection: .down),
        ]
        let graceNotes4 = try [
            makeGraceNote(factory, keys: ["f/5"], duration: "32", stemDirection: .up),
            makeGraceNote(factory, keys: ["e/5"], duration: "32", stemDirection: .up),
            makeGraceNote(factory, keys: ["e/5"], duration: "8", stemDirection: .up),
        ]

        _ = graceNotes2[0].setStemDirection(.down)
        _ = graceNotes2[0].addModifier(try factory.Accidental(parsing: "#"), index: 0)

        _ = notes[1].addModifier(factory.GraceNoteGroup(notes: graceNotes4).beamNotes(), index: 0)
        _ = notes[3].addModifier(factory.GraceNoteGroup(notes: graceNotes1), index: 0)
        _ = notes2[1].addModifier(factory.GraceNoteGroup(notes: graceNotes2).beamNotes(), index: 0)
        _ = notes2[5].addModifier(factory.GraceNoteGroup(notes: graceNotes3).beamNotes(), index: 0)

        let voice1 = makeGraceVoice(factory, notes)
        let voice2 = makeGraceVoice(factory, notes2)

        _ = factory.Beam(notes: Array(notes[0..<4]))
        _ = factory.Beam(notes: Array(notes[4..<8]))
        _ = factory.Beam(notes: Array(notes2[0..<4]))
        _ = factory.Beam(notes: Array(notes2[4..<8]))

        _ = factory.Formatter().joinVoices([voice1, voice2]).formatToStave([voice1, voice2], stave: stave)

        try factory.draw()
        if drawTwice {
            try factory.draw()
        }
    }

    @Test("Grace_Notes.Grace_Note_Basic")
    func graceNotesBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Basic", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)

            let graceNotes = try [
                makeGraceNote(factory, keys: ["e/4"], duration: "32"),
                makeGraceNote(factory, keys: ["f/4"], duration: "32"),
                makeGraceNote(factory, keys: ["g/4"], duration: "32"),
                makeGraceNote(factory, keys: ["a/4"], duration: "32"),
            ]
            let graceNotes1 = [try makeGraceNote(factory, keys: ["b/4"], duration: "8", slash: false)]
            let graceNotes2 = [try makeGraceNote(factory, keys: ["b/4"], duration: "8", slash: true)]
            let graceNotes3 = try [
                makeGraceNote(factory, keys: ["e/4"], duration: "8"),
                makeGraceNote(factory, keys: ["f/4"], duration: "16"),
                makeGraceNote(factory, keys: ["e/4", "g/4"], duration: "8"),
                makeGraceNote(factory, keys: ["a/4"], duration: "32"),
                makeGraceNote(factory, keys: ["b/4"], duration: "32"),
            ]
            let graceNotes4 = try [
                makeGraceNote(factory, keys: ["g/4"], duration: "8"),
                makeGraceNote(factory, keys: ["g/4"], duration: "16"),
                makeGraceNote(factory, keys: ["g/4"], duration: "16"),
            ]

            _ = graceNotes[1].addModifier(try factory.Accidental(parsing: "##"), index: 0)
            _ = graceNotes3[3].addModifier(try factory.Accidental(parsing: "bb"), index: 0)
            Dot.buildAndAttach([graceNotes4[0] as Note], all: true)

            let notes: [StaveNote] = try [
                makeGraceStaveNote(factory, keys: ["b/4"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(try factory.Accidental(parsing: "#"), index: 0)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes1).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5", "d/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes2).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["a/4"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes3).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["a/4"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes4).beamNotes(), index: 0),
            ]

            let voice = makeGraceVoice(factory, notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Grace_Notes.With_Articulation_and_Annotation_on_Parent_Note")
    func graceNotesWithArticulationAndAnnotationOnParentNoteMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Grace_Notes",
            test: "With_Articulation_and_Annotation_on_Parent_Note",
            width: 700,
            height: 130
        ) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)
            let graceNotes = [try makeGraceNote(factory, keys: ["b/4"], duration: "8", slash: false)]

            let notes: [StaveNote] = try [
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(try factory.Accidental(parsing: "#")),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Annotation("words")),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Articulation("a>").setPosition(.above), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0)
                    .addModifier(Articulation("a-").setPosition(.above), index: 0)
                    .addModifier(Articulation("a>").setPosition(.above), index: 0)
                    .addModifier(Articulation("a@a").setPosition(.above), index: 0),
            ]

            let voice = makeGraceVoice(factory, notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Grace_Notes.Grace_Note_Basic_with_Slurs")
    func graceNotesBasicWithSlursMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Basic_with_Slurs", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)

            let graceNotes0 = try [
                makeGraceNote(factory, keys: ["e/4"], duration: "32"),
                makeGraceNote(factory, keys: ["f/4"], duration: "32"),
                makeGraceNote(factory, keys: ["g/4"], duration: "32"),
                makeGraceNote(factory, keys: ["a/4"], duration: "32"),
            ]
            let graceNotes1 = [try makeGraceNote(factory, keys: ["b/4"], duration: "8", slash: false)]
            let graceNotes2 = [try makeGraceNote(factory, keys: ["b/4"], duration: "8", slash: true)]
            let graceNotes3 = try [
                makeGraceNote(factory, keys: ["e/4"], duration: "8"),
                makeGraceNote(factory, keys: ["f/4"], duration: "16"),
                makeGraceNote(factory, keys: ["e/4", "g/4"], duration: "8"),
                makeGraceNote(factory, keys: ["a/4"], duration: "32"),
                makeGraceNote(factory, keys: ["b/4"], duration: "32"),
            ]
            let graceNotes4 = try [
                makeGraceNote(factory, keys: ["a/4"], duration: "8"),
                makeGraceNote(factory, keys: ["a/4"], duration: "16"),
                makeGraceNote(factory, keys: ["a/4"], duration: "16"),
            ]

            _ = graceNotes0[1].addModifier(try factory.Accidental(parsing: "#"), index: 0)
            _ = graceNotes3[3].addModifier(try factory.Accidental(parsing: "b"), index: 0)
            _ = graceNotes3[2].addModifier(try factory.Accidental(parsing: "n"), index: 0)
            Dot.buildAndAttach([graceNotes4[0] as Note], all: true)

            let notes: [StaveNote] = try [
                makeGraceStaveNote(factory, keys: ["b/4"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes0, slur: true).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5"], duration: "4", autoStem: true)
                    .addModifier(try factory.Accidental(parsing: "#"), index: 0)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes1, slur: true).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["c/5", "d/5"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes2, slur: true).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["a/4"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes3, slur: true).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["a/4"], duration: "4", autoStem: true)
                    .addModifier(factory.GraceNoteGroup(notes: graceNotes4, slur: true).beamNotes(), index: 0),
                makeGraceStaveNote(factory, keys: ["a/4"], duration: "4", autoStem: true),
            ]

            let voice = makeGraceVoice(factory, notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Grace_Notes.Grace_Note_Stem")
    func graceNotesStemMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Stem", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)

            func createNoteBlock(keys: [String], stemDirection: StemDirection) throws -> [StaveNote] {
                let staveNotes = try graceStemDurations.map {
                    try makeGraceStaveNote(factory, keys: keys, duration: $0, stemDirection: stemDirection)
                }
                let graceNotes = try graceStemDurations.map {
                    try makeGraceNote(factory, keys: keys, duration: $0, stemDirection: stemDirection)
                }
                _ = staveNotes[0].addModifier(factory.GraceNoteGroup(notes: graceNotes), index: 0)
                return staveNotes
            }

            let voice = factory.Voice().setStrict(false)
            _ = voice.addTickables(try createNoteBlock(keys: ["g/4"], stemDirection: .up).map { $0 as Tickable })
            _ = voice.addTickables(try createNoteBlock(keys: ["d/5"], stemDirection: .down).map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Grace_Notes.Grace_Note_Stem_with_Beams_1")
    func graceNotesStemWithBeams1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Stem_with_Beams_1", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)
            try drawGraceStemWithBeamsCase(
                factory: factory,
                stave: stave,
                keys1: ["g/4"],
                stemDirection1: .up,
                keys2: ["d/5"],
                stemDirection2: .down
            )
        }
    }

    @Test("Grace_Notes.Grace_Note_Stem_with_Beams_2")
    func graceNotesStemWithBeams2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Stem_with_Beams_2", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)
            try drawGraceStemWithBeamsCase(
                factory: factory,
                stave: stave,
                keys1: ["a/3"],
                stemDirection1: .up,
                keys2: ["a/5"],
                stemDirection2: .down
            )
        }
    }

    @Test("Grace_Notes.Grace_Note_Stem_with_Beams_3")
    func graceNotesStemWithBeams3MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Stem_with_Beams_3", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)
            try drawGraceStemWithBeamsCase(
                factory: factory,
                stave: stave,
                keys1: ["c/4"],
                stemDirection1: .up,
                keys2: ["c/6"],
                stemDirection2: .down
            )
        }
    }

    @Test("Grace_Notes.Grace_Note_Slash")
    func graceNotesSlashMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Slash", width: 700, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 650)

            func createSlashBlock(keys: [String], stemDirection: StemDirection) throws -> [StaveNote] {
                let notes = [try makeGraceStaveNote(factory, keys: ["f/4"], duration: "16", stemDirection: stemDirection)]
                var graceNotes = try graceStemDurations.map {
                    try makeGraceNote(factory, keys: keys, duration: $0, stemDirection: stemDirection, slash: true)
                }

                let duration = "8"
                let grouped: [[GraceNote]] = try [
                    [
                        makeGraceNote(factory, keys: ["d/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["d/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["d/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                    ],
                    [
                        makeGraceNote(factory, keys: ["e/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["e/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["b/4", "f/5"], duration: duration, stemDirection: stemDirection, slash: true),
                    ],
                    [
                        makeGraceNote(factory, keys: ["b/4", "f/5"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["b/4", "f/5"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["e/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                    ],
                ]

                for group in grouped {
                    graceNotes.append(contentsOf: group)
                }

                let graceGroup = factory.GraceNoteGroup(notes: graceNotes)
                for group in grouped {
                    _ = graceGroup.beamNotes(group)
                }

                _ = notes[0].addModifier(graceGroup, index: 0)
                return notes
            }

            let voice = factory.Voice().setStrict(false)
            _ = voice.addTickables(try createSlashBlock(keys: ["d/4", "a/4"], stemDirection: .up).map { $0 as Tickable })
            _ = voice.addTickables(try createSlashBlock(keys: ["d/4", "a/4"], stemDirection: .down).map { $0 as Tickable })

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Grace_Notes.Grace_Note_Slash_with_Beams")
    func graceNotesSlashWithBeamsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Note_Slash_with_Beams", width: 800, height: 130) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 750)

            func createSlashWithBeamsBlock(keys: [String], stemDirection: StemDirection) throws -> [StaveNote] {
                let notes = [try makeGraceStaveNote(factory, keys: ["f/4"], duration: "16", stemDirection: stemDirection)]
                var allGraceNotes: [GraceNote] = []
                var groupsToBeam: [[GraceNote]] = []

                for duration in ["8", "16", "32", "64"] {
                    let group = try [
                        makeGraceNote(factory, keys: ["d/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["d/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: false),
                        makeGraceNote(factory, keys: ["e/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["b/4", "f/5"], duration: duration, stemDirection: stemDirection, slash: false),
                        makeGraceNote(factory, keys: ["b/4", "f/5"], duration: duration, stemDirection: stemDirection, slash: true),
                        makeGraceNote(factory, keys: ["e/4", "a/4"], duration: duration, stemDirection: stemDirection, slash: false),
                    ]
                    groupsToBeam.append([group[0], group[1]])
                    groupsToBeam.append([group[2], group[3]])
                    groupsToBeam.append([group[4], group[5]])
                    allGraceNotes.append(contentsOf: group)
                }

                let graceGroup = factory.GraceNoteGroup(notes: allGraceNotes)
                for group in groupsToBeam {
                    _ = graceGroup.beamNotes(group)
                }
                _ = notes[0].addModifier(graceGroup, index: 0)
                return notes
            }

            let voice = factory.Voice().setStrict(false)
            _ = voice.addTickables(try createSlashWithBeamsBlock(keys: ["d/4", "a/4"], stemDirection: .up).map { $0 as Tickable })
            _ = voice.addTickables(try createSlashWithBeamsBlock(keys: ["d/4", "a/4"], stemDirection: .down).map { $0 as Tickable })
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Grace_Notes.Grace_Notes_Multiple_Voices")
    func graceNotesMultipleVoicesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Grace_Notes", test: "Grace_Notes_Multiple_Voices", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 450)
            try drawGraceMultipleVoicesCase(factory: factory, stave: stave, drawTwice: false)
        }
    }

    @Test("Grace_Notes.Grace_Notes_Multiple_Voices_Multiple_Draws")
    func graceNotesMultipleVoicesMultipleDrawsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Grace_Notes",
            test: "Grace_Notes_Multiple_Voices_Multiple_Draws",
            width: 450,
            height: 140
        ) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 450)
            try drawGraceMultipleVoicesCase(factory: factory, stave: stave, drawTwice: true)
        }
    }
}
