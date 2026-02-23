import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Percussion.Percussion_Clef")
    func percussionClefMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Percussion", test: "Percussion_Clef", width: 400, height: 120) { _, context in
            let stave = Stave(x: 10, y: 10, width: 300).addClef(.percussion)
            _ = stave.setContext(context)
            try stave.draw()
        }
    }

    @Test("Percussion.Percussion_Notes")
    func percussionNotesMatchesUpstream() throws {
        let notes: [(key: String, duration: String)] = [
            ("g/5/d0", "4"),
            ("g/5/d1", "4"),
            ("g/5/d2", "4"),
            ("g/5/d3", "4"),
            ("x/", "1"),
            ("g/5/t0", "1"),
            ("g/5/t1", "4"),
            ("g/5/t2", "4"),
            ("g/5/t3", "4"),
            ("x/", "1"),
            ("g/5/x0", "1"),
            ("g/5/x1", "4"),
            ("g/5/x2", "4"),
            ("g/5/x3", "4"),
        ]

        let width = Double(notes.count) * 25 + 100
        try runCategorySVGParityCase(module: "Percussion", test: "Percussion_Notes", width: width, height: 240) { _, context in
            for row in 0..<2 {
                let stave = Stave(x: 10, y: 10 + Double(row) * 120, width: Double(notes.count) * 25 + 75)
                    .addClef(.percussion)
                _ = stave.setContext(context)
                try stave.draw()

                for (index, noteSpec) in notes.enumerated() {
                    let stemDirection: StemDirection = row == 0 ? .down : .up
                    let note = StaveNote(
                        try StaveNoteStruct(
                            parsingKeys: [noteSpec.key],
                            duration: noteSpec.duration,
                            stemDirection: stemDirection
                        )
                    )
                    _ = note.setStave(stave)
                    _ = TickContext().addTickable(note).preFormat().setX(Double(index + 1) * 25)
                    _ = note.setContext(context)
                    try note.draw()
                }
            }
        }
    }

    @Test("Percussion.Percussion_Basic0")
    func percussionBasic0MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Basic0") { factory in
            let voice0Notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
            ]
            let voice0 = factory.Voice().addTickables(voice0Notes.map { $0 as Tickable })

            let voice1Notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4/x2", "c/5"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4/x2", "c/5"], duration: "4", stemDirection: .down)),
            ]
            _ = factory.Voice().addTickables(voice1Notes.map { $0 as Tickable })

            _ = factory.Beam(notes: voice0.getTickables().compactMap { $0 as? StemmableNote })
            _ = factory.Beam(notes: Array(voice1Notes[0..<2]).map { $0 as StemmableNote })
            _ = factory.Beam(notes: Array(voice1Notes[3..<5]).map { $0 as StemmableNote })
        }
    }

    @Test("Percussion.Percussion_Basic1")
    func percussionBasic1MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Basic1") { factory in
            _ = factory.Voice().addTickables([
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/5/x2"], duration: "4")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/5/x2"], duration: "4")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/5/x2"], duration: "4")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/5/x2"], duration: "4")),
            ].map { $0 as Tickable })

            _ = factory.Voice().addTickables([
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4/x2", "c/5"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4/x2", "c/5"], duration: "4", stemDirection: .down)),
            ].map { $0 as Tickable })
        }
    }

    @Test("Percussion.Percussion_Basic2")
    func percussionBasic2MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Basic2") { factory in
            let voice0Notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5/x3"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/4/n", "g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "8")),
            ]
            _ = factory.Voice().addTickables(voice0Notes.map { $0 as Tickable })
            _ = factory.Beam(notes: Array(voice0Notes[1..<8]).map { $0 as StemmableNote })

            let voice1Notes: [StaveNote] = [
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4/x2", "c/5"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4/x2", "c/5"], duration: "8d", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "16", stemDirection: .down)),
            ]
            Dot.buildAndAttach([voice1Notes[4] as Note], all: true)
            _ = factory.Voice().addTickables(voice1Notes.map { $0 as Tickable })

            _ = factory.Beam(notes: Array(voice1Notes[0..<2]).map { $0 as StemmableNote })
            _ = factory.Beam(notes: Array(voice1Notes[4..<6]).map { $0 as StemmableNote })
        }
    }

    @Test("Percussion.Percussion_Snare0")
    func percussionSnare0MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Snare0") { factory in
            let font = FontInfo(
                family: VexFont.SERIF,
                size: 14,
                weight: VexFontWeight.bold.rawValue,
                style: VexFontStyle.italic.rawValue
            )

            _ = factory.Voice().addTickables([
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Articulation(type: "a>"), index: 0)
                    .addModifier(factory.Annotation(text: "L", font: font), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Annotation(text: "R", font: font), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Annotation(text: "L", font: font), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Annotation(text: "L", font: font), index: 0),
            ].map { $0 as Tickable })
        }
    }

    @Test("Percussion.Percussion_Snare1")
    func percussionSnare1MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Snare1") { factory in
            _ = factory.Voice().addTickables([
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Articulation(type: "ah"), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "4", stemDirection: .down)),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["g/5/x2"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Articulation(type: "ah"), index: 0),
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["a/5/x3"], duration: "4", stemDirection: .down))
                    .addModifier(factory.Articulation(type: "a,"), index: 0),
            ].map { $0 as Tickable })
        }
    }

    @Test("Percussion.Percussion_Snare2")
    func percussionSnare2MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Snare2") { factory in
            _ = factory.Voice().addTickables([
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(Tremolo(1), index: 0) as Tickable,
                try factory.GraceNote(GraceNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(Tremolo(1), index: 0) as Tickable,
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(Tremolo(3), index: 0) as Tickable,
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .down))
                    .addModifier(Tremolo(4), index: 0) as Tickable,
            ])
        }
    }

    @Test("Percussion.Percussion_Snare3")
    func percussionSnare3MatchesUpstream() throws {
        try runPercussionSingleMeasureParityCase(testName: "Percussion_Snare3") { factory in
            _ = factory.Voice().addTickables([
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .up))
                    .addModifier(Tremolo(2), index: 0) as Tickable,
                try factory.GraceNote(GraceNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .up))
                    .addModifier(Tremolo(2), index: 0) as Tickable,
                try factory.GraceNote(GraceNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .up))
                    .addModifier(Tremolo(3), index: 0) as Tickable,
                try factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/5"], duration: "4", stemDirection: .up))
                    .addModifier(Tremolo(4), index: 0) as Tickable,
            ])
        }
    }

    private func runPercussionSingleMeasureParityCase(
        testName: String,
        setup: (Factory) throws -> Void
    ) throws {
        try runCategorySVGParityCase(module: "Percussion", test: testName, width: 500, height: 140) { factory, _ in
            let stave = factory.Stave()
                .addClef(.percussion)
                .addTimeSignature(.meter(4, 4))

            try setup(factory)

            let voices = factory.getVoices()
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }
}
