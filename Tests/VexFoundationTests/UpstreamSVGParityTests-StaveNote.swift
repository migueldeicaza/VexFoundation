import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("StaveNote.StaveNote_Draw___Treble")
    func staveNoteDrawTrebleMatchesUpstream() throws {
        try runUpstreamStaveNoteDrawBasicCase(
            test: "StaveNote_Draw___Treble",
            clef: .treble,
            octaveShift: 0,
            restKey: "r/4"
        )
    }

    @Test("StaveNote.StaveNote_Draw___Alto")
    func staveNoteDrawAltoMatchesUpstream() throws {
        try runUpstreamStaveNoteDrawBasicCase(
            test: "StaveNote_Draw___Alto",
            clef: .alto,
            octaveShift: -1,
            restKey: "r/4"
        )
    }

    @Test("StaveNote.StaveNote_Draw___Tenor")
    func staveNoteDrawTenorMatchesUpstream() throws {
        try runUpstreamStaveNoteDrawBasicCase(
            test: "StaveNote_Draw___Tenor",
            clef: .tenor,
            octaveShift: -1,
            restKey: "r/3"
        )
    }

    @Test("StaveNote.StaveNote_Draw___Bass")
    func staveNoteDrawBassMatchesUpstream() throws {
        try runUpstreamStaveNoteDrawBasicCase(
            test: "StaveNote_Draw___Bass",
            clef: .bass,
            octaveShift: -2,
            restKey: "r/3"
        )
    }

    @Test("StaveNote.StaveNote_BoundingBoxes___Treble")
    func staveNoteBoundingBoxesTrebleMatchesUpstream() throws {
        try runUpstreamStaveNoteBoundingBoxesTrebleCase()
    }

    @Test("StaveNote.StaveNote_Draw___Bass_2")
    func staveNoteDrawBass2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___Bass_2", width: 600, height: 280) { _, context in
            let stave = Stave(x: 10, y: 10, width: 650)
            _ = stave.setContext(context)
            _ = stave.addClef(.bass)
            try stave.draw()

            let noteStructs: [StaveNoteStruct] = [
                try StaveNoteStruct(parsingKeys: ["c/3", "e/3", "a/3"], duration: "1/2", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "w", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/3", "e/3", "a/3"], duration: "h", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "q", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/3", "e/3", "a/3"], duration: "8", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "16", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/3", "e/3", "a/3"], duration: "32", clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "h", stemDirection: .down, clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "q", stemDirection: .down, clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "8", stemDirection: .down, clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "16", stemDirection: .down, clef: .bass),
                try StaveNoteStruct(parsingKeys: ["c/2", "e/2", "a/2"], duration: "32", stemDirection: .down, clef: .bass),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "1/2r"),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "wr"),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "hr"),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "qr"),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "8r"),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "16r"),
                try StaveNoteStruct(parsingKeys: ["r/4"], duration: "32r"),
                try StaveNoteStruct(parsingKeys: ["x/4"], duration: "h"),
            ]

            for (index, noteStruct) in noteStructs.enumerated() {
                let note = StaveNote(noteStruct)
                _ = try drawUpstreamStaveNote(
                    note,
                    stave: stave,
                    context: context,
                    x: Double(index + 1) * 25
                )
            }
        }
    }

    @Test("StaveNote.StaveNote_Draw___Harmonic_And_Muted")
    func staveNoteDrawHarmonicAndMutedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___Harmonic_And_Muted", width: 1000, height: 180) { _, context in
            let stave = Stave(x: 10, y: 10, width: 950)
            _ = stave.setContext(context)
            try stave.draw()

            let keys = ["c/4", "e/4", "a/4"]
            let durations = ["1/2", "w", "h", "q", "8", "16", "32", "64", "128"]
            var noteStructs: [StaveNoteStruct] = []

            for duration in durations {
                noteStructs.append(try StaveNoteStruct(parsingKeys: keys, duration: "\(duration)h"))
            }
            for duration in durations {
                noteStructs.append(try StaveNoteStruct(parsingKeys: keys, duration: "\(duration)h", stemDirection: .down))
            }
            for duration in durations {
                noteStructs.append(try StaveNoteStruct(parsingKeys: keys, duration: "\(duration)m"))
            }
            for duration in durations {
                noteStructs.append(try StaveNoteStruct(parsingKeys: keys, duration: "\(duration)m", stemDirection: .down))
            }

            for (index, noteStruct) in noteStructs.enumerated() {
                let note = StaveNote(noteStruct)
                _ = try drawUpstreamStaveNote(
                    note,
                    stave: stave,
                    context: context,
                    x: Double(index) * 25 + 5
                )
            }
        }
    }

    @Test("StaveNote.StaveNote_Draw___Slash")
    func staveNoteDrawSlashMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___Slash", width: 700, height: 180) { _, context in
            let stave = Stave(x: 10, y: 10, width: 650)
            _ = stave.setContext(context)
            try stave.draw()

            let noteSpecs: [(duration: String, stemDirection: StemDirection)] = [
                ("1/2s", .down), ("ws", .down), ("hs", .down), ("qs", .down), ("8s", .down), ("16s", .down), ("32s", .down), ("64s", .down), ("128s", .down),
                ("1/2s", .up), ("ws", .up), ("hs", .up), ("qs", .up), ("8s", .up), ("16s", .up), ("32s", .up), ("64s", .up), ("128s", .up),
                ("8s", .down), ("8s", .down), ("8s", .up), ("8s", .up),
            ]

            let notes = try noteSpecs.map { spec in
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: spec.duration, stemDirection: spec.stemDirection))
            }

            let beam1 = try Beam([notes[16], notes[17]])
            let beam2 = try Beam([notes[18], notes[19]])

            _ = try Formatter.FormatAndDraw(
                ctx: context,
                stave: stave,
                notes: notes,
                params: FormatParams(autoBeam: false)
            )

            _ = beam1.setContext(context)
            _ = beam2.setContext(context)
            try beam1.draw()
            try beam2.draw()
        }
    }

    @Test("StaveNote.StaveNote_Draw___Key_Styles")
    func staveNoteDrawKeyStylesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___Key_Styles", width: 300, height: 280) { _, context in
            _ = context.scale(3, 3)
            let stave = Stave(x: 10, y: 0, width: 100)
            _ = stave.setContext(context)

            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["g/4", "bb/4", "d/5"], duration: "q"))
            _ = note.setStave(stave)
            _ = note.addModifier(Accidental(.flat), index: 1)
            _ = note.setKeyStyle(
                1,
                style: ElementStyle(
                    shadowColor: "blue",
                    shadowBlur: 2,
                    fillStyle: "blue"
                )
            )

            _ = TickContext().addTickable(note).preFormat().setX(25)
            try stave.draw()
            _ = note.setContext(context)
            try note.draw()
        }
    }

    @Test("StaveNote.StaveNote_Draw___StaveNote_Stem_Styles")
    func staveNoteDrawStemStylesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___StaveNote_Stem_Styles", width: 300, height: 280) { _, context in
            _ = context.scale(3, 3)
            let stave = Stave(x: 10, y: 0, width: 100)
            _ = stave.setContext(context)

            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["g/4", "bb/4", "d/5"], duration: "q"))
            _ = note.setStave(stave)
            _ = note.addModifier(Accidental(.flat), index: 1)
            _ = note.setStemStyle(ElementStyle(
                shadowColor: "blue",
                shadowBlur: 2,
                fillStyle: "blue",
                strokeStyle: "blue"
            ))

            _ = TickContext().addTickable(note).preFormat().setX(25)
            try stave.draw()
            _ = note.setContext(context)
            try note.draw()
        }
    }

    @Test("StaveNote.StaveNote_Draw___StaveNote_Flag_Styles")
    func staveNoteDrawFlagStylesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___StaveNote_Flag_Styles", width: 300, height: 280) { _, context in
            _ = context.scale(3, 3)
            let stave = Stave(x: 10, y: 0, width: 100)
            _ = stave.setContext(context)

            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["g/4", "bb/4", "d/5"], duration: "8"))
            _ = note.setStave(stave)
            _ = note.addModifier(Accidental(.flat), index: 1)
            note.setFlagStyle(ElementStyle(
                shadowColor: "blue",
                shadowBlur: 2,
                fillStyle: "blue",
                strokeStyle: "blue"
            ))

            _ = TickContext().addTickable(note).preFormat().setX(25)
            try stave.draw()
            _ = note.setContext(context)
            try note.draw()
        }
    }

    @Test("StaveNote.StaveNote_Draw___StaveNote_Styles")
    func staveNoteDrawNoteStylesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___StaveNote_Styles", width: 300, height: 280) { _, context in
            _ = context.scale(3, 3)
            let stave = Stave(x: 10, y: 0, width: 100)
            _ = stave.setContext(context)

            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["g/4", "bb/4", "d/5"], duration: "8"))
            _ = note.setStave(stave)
            _ = note.addModifier(Accidental(.flat), index: 1)
            _ = note.setStyle(ElementStyle(
                shadowColor: "blue",
                shadowBlur: 2,
                fillStyle: "blue",
                strokeStyle: "blue"
            ))

            _ = TickContext().addTickable(note).preFormat().setX(25)
            try stave.draw()
            _ = note.setContext(context)
            try note.draw()
        }
    }

    @Test("StaveNote.StaveNote_Draw___StaveNote_Stem_Lengths")
    func staveNoteDrawStemLengthsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "StaveNote_Draw___StaveNote_Stem_Lengths", width: 975, height: 150) { _, context in
            let stave = Stave(x: 10, y: 10, width: 975)
            _ = stave.setContext(context)
            try stave.draw()

            let keys = [
                "e/3", "f/3", "g/3", "a/3", "b/3",
                "c/4", "d/4", "e/4", "f/4", "g/4",
                "f/5", "g/5", "a/5", "b/5", "c/6",
                "d/6", "e/6", "f/6", "g/6", "a/6",
            ]

            var notes: [StaveNote] = []
            for (index, key) in keys.enumerated() {
                let duration = index.isMultiple(of: 2) ? "q" : "8"
                let note = StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: duration, autoStem: true))
                _ = note.setStave(stave)
                _ = TickContext().addTickable(note)
                _ = note.setContext(context)
                notes.append(note)
            }

            let wholeKeys = ["e/3", "a/3", "f/5", "a/5", "d/6", "a/6"]
            for key in wholeKeys {
                let note = StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: "w"))
                _ = note.setStave(stave)
                _ = TickContext().addTickable(note)
                _ = note.setContext(context)
                notes.append(note)
            }

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
        }
    }

    @Test("StaveNote.Stave__Ledger_Line__Beam__Stem_and_Flag_Styles")
    func staveNoteDrawBeamStylesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveNote",
            test: "Stave__Ledger_Line__Beam__Stem_and_Flag_Styles",
            width: 400,
            height: 160
        ) { _, context in
            let stave = Stave(x: 10, y: 10, width: 380)
            _ = stave.setStyle(ElementStyle(strokeStyle: "#EEAAEE", lineWidth: 3))
            _ = stave.setContext(context)
            try stave.draw()

            let noteStructs: [StaveNoteStruct] = [
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .up),
                try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8", stemDirection: .up),
                try StaveNoteStruct(parsingKeys: ["d/6"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["c/6", "d/6"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["d/6", "e/6"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["e/6", "f/6"], duration: "8", stemDirection: .down),
            ]
            let notes = noteStructs.map(StaveNote.init)

            let beam1 = try Beam(Array(notes[0...1]))
            let beam2 = try Beam(Array(notes[3...4]))
            let beam3 = try Beam(Array(notes[5...6]))
            let beam4 = try Beam(Array(notes[7...8]))

            _ = beam1.setStyle(ElementStyle(fillStyle: "blue", strokeStyle: "blue"))
            _ = notes[0].setKeyStyle(0, style: ElementStyle(fillStyle: "purple"))
            _ = notes[0].setStemStyle(ElementStyle(strokeStyle: "green"))
            _ = notes[1].setStemStyle(ElementStyle(strokeStyle: "orange"))
            _ = notes[1].setKeyStyle(0, style: ElementStyle(fillStyle: "darkturquoise"))
            _ = notes[5].setStyle(ElementStyle(fillStyle: "tomato", strokeStyle: "tomato"))
            _ = beam3.setStyle(ElementStyle(shadowColor: "blue", shadowBlur: 4))
            notes[9].setLedgerLineStyle(ElementStyle(fillStyle: "lawngreen", strokeStyle: "lawngreen", lineWidth: 1))
            notes[9].setFlagStyle(ElementStyle(fillStyle: "orange", strokeStyle: "orange"))

            _ = try Formatter.FormatAndDraw(
                ctx: context,
                stave: stave,
                notes: notes,
                params: FormatParams(autoBeam: false)
            )
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

    @Test("StaveNote.Displacements")
    func staveNoteDisplacementsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveNote", test: "Displacements", width: 700, height: 155) { _, context in
            _ = context.scale(0.9, 0.9)

            let stave = Stave(x: 10, y: 10, width: 675)
            _ = stave.setContext(context)
            try stave.draw()

            let noteStructs: [StaveNoteStruct] = [
                try StaveNoteStruct(parsingKeys: ["g/3", "a/3", "c/4", "d/4", "e/4"], duration: "1/2"),
                try StaveNoteStruct(parsingKeys: ["g/3", "a/3", "c/4", "d/4", "e/4"], duration: "w"),
                try StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4"], duration: "h"),
                try StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4"], duration: "q"),
                try StaveNoteStruct(parsingKeys: ["e/3", "b/3", "c/4", "e/4", "f/4", "g/5", "a/5"], duration: "8"),
                try StaveNoteStruct(parsingKeys: ["a/3", "c/4", "e/4", "g/4", "a/4", "b/4"], duration: "16"),
                try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4"], duration: "32"),
                try StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4", "a/4"], duration: "64"),
                try StaveNoteStruct(parsingKeys: ["g/3", "c/4", "d/4", "e/4"], duration: "h", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4"], duration: "q", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4"], duration: "8", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["c/4", "d/4", "e/4", "f/4", "g/4", "a/4"], duration: "16", stemDirection: .down),
                try StaveNoteStruct(parsingKeys: ["b/3", "c/4", "e/4", "a/4", "b/5", "c/6", "e/6"], duration: "32", stemDirection: .down),
                try StaveNoteStruct(
                    parsingKeys: ["b/3", "c/4", "e/4", "a/4", "b/5", "c/6", "e/6", "e/6"],
                    duration: "64",
                    stemDirection: .down
                ),
            ]

            for (index, noteStruct) in noteStructs.enumerated() {
                let note = StaveNote(noteStruct)
                _ = try drawUpstreamStaveNote(
                    note,
                    stave: stave,
                    context: context,
                    x: Double(index + 1) * 45
                )
            }
        }
    }

    private func runUpstreamStaveNoteDrawBasicCase(
        test: String,
        clef: ClefName,
        octaveShift: Int,
        restKey: String
    ) throws {
        try runCategorySVGParityCase(module: "StaveNote", test: test, width: 700, height: 180) { _, context in
            let stave = Stave(x: 10, y: 30, width: 750)
            _ = stave.setContext(context)
            _ = stave.addClef(clef)
            try stave.draw()

            let lowerKeys = ["c/\(4 + octaveShift)", "e/\(4 + octaveShift)", "a/\(4 + octaveShift)"]
            let higherKeys = ["c/\(5 + octaveShift)", "e/\(5 + octaveShift)", "a/\(5 + octaveShift)"]
            let restKeys = [restKey]

            let noteStructs: [StaveNoteStruct] = [
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "1/2", clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "w", clef: clef),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "h", clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "q", clef: clef),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "8", clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "16", clef: clef),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "32", clef: clef),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "64", clef: clef),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "128", clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "1/2", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "w", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "h", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "q", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "8", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "16", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "32", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "64", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "128", stemDirection: .down, clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "1/2r", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "wr", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "hr", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "qr", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "8r", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "16r", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "32r", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "64r", clef: clef),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "128r", clef: clef),
                try StaveNoteStruct(parsingKeys: ["x/4"], duration: "h"),
            ]

            for (index, noteStruct) in noteStructs.enumerated() {
                let note = StaveNote(noteStruct)
                _ = try drawUpstreamStaveNote(
                    note,
                    stave: stave,
                    context: context,
                    x: Double(index + 1) * 25
                )
            }
        }
    }

    private func runUpstreamStaveNoteBoundingBoxesTrebleCase() throws {
        try runCategorySVGParityCase(
            module: "StaveNote",
            test: "StaveNote_BoundingBoxes___Treble",
            width: 700,
            height: 180
        ) { _, context in
            let stave = Stave(x: 10, y: 30, width: 750)
            _ = stave.setContext(context)
            _ = stave.addClef(.treble)
            try stave.draw()

            let lowerKeys = ["c/4", "e/4", "a/4"]
            let higherKeys = ["c/5", "e/5", "a/5"]
            let restKeys = ["r/4"]

            let noteStructs: [StaveNoteStruct] = [
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "1/2", clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "w", clef: .treble),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "h", clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "q", clef: .treble),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "8", clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "16", clef: .treble),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "32", clef: .treble),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "64", clef: .treble),
                try StaveNoteStruct(parsingKeys: higherKeys, duration: "128", clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "1/2", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "w", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "h", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "q", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "8", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "16", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "32", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "64", stemDirection: .down, clef: .treble),
                try StaveNoteStruct(parsingKeys: lowerKeys, duration: "128", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "1/2r", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "wr", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "hr", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "qr", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "8r", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "16r", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "32r", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "64r", clef: .treble),
                try StaveNoteStruct(parsingKeys: restKeys, duration: "128r", clef: .treble),
                try StaveNoteStruct(parsingKeys: ["x/4"], duration: "h"),
            ]

            for (index, noteStruct) in noteStructs.enumerated() {
                let note = StaveNote(noteStruct)
                _ = try drawUpstreamStaveNote(
                    note,
                    stave: stave,
                    context: context,
                    x: Double(index + 1) * 25,
                    drawBoundingBox: true,
                    addModifierContext: false
                )
            }
        }
    }

    @discardableResult
    private func drawUpstreamStaveNote(
        _ note: StaveNote,
        stave: Stave,
        context: RenderContext,
        x: Double,
        drawBoundingBox: Bool = false,
        addModifierContext: Bool = true
    ) throws -> StaveNote {
        _ = note.setStave(stave)

        if addModifierContext {
            _ = note.addToModifierContext(ModifierContext())
        }

        _ = TickContext().addTickable(note).preFormat().setX(x)
        _ = note.setContext(context)
        try note.draw()

        if drawBoundingBox, let bb = note.getBoundingBox() {
            context.rect(bb.x, bb.y, bb.w, bb.h)
            context.stroke()
        }
        return note
    }
}
