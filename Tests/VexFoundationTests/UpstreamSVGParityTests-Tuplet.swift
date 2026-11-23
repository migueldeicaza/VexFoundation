import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    private func makeTupletNote(
        _ factory: Factory,
        key: String,
        duration: String,
        stemDirection: StemDirection
    ) throws -> StaveNote {
        factory.StaveNote(
            try StaveNoteStruct(
                parsingKeys: [key],
                duration: duration,
                stemDirection: stemDirection
            )
        )
    }

    private func formatAndDrawTupletVoices(
        _ factory: Factory,
        _ stave: Stave,
        _ voices: [Voice]
    ) throws {
        _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
        try factory.draw()
    }

    @Test("Tuplet.Simple_Tuplet")
    func tupletSimpleTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Simple_Tuplet", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 350).addTimeSignature(.meter(3, 4))
            let specs: [(String, String)] = [
                ("g/4", "4"), ("a/4", "4"), ("b/4", "4"),
                ("b/4", "8"), ("a/4", "8"), ("g/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Tuplet(notes: Array(notes[0..<3]).map { $0 as Note })
            _ = factory.Tuplet(notes: Array(notes[3..<6]).map { $0 as Note })

            let voice = factory.Voice(timeSignature: .meter(3, 4))
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Beamed_Tuplet")
    func tupletBeamedTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Beamed_Tuplet", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 350).addTimeSignature(.meter(3, 8))
            let specs: [(String, String)] = [
                ("b/4", "16"), ("a/4", "16"), ("g/4", "16"),
                ("a/4", "8"), ("f/4", "8"), ("a/4", "8"), ("f/4", "8"),
                ("a/4", "8"), ("f/4", "8"), ("g/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[0..<3]))
            _ = factory.Beam(notes: Array(notes[3..<10]))
            _ = factory.Tuplet(notes: Array(notes[0..<3]).map { $0 as Note })
            _ = factory.Tuplet(notes: Array(notes[3..<10]).map { $0 as Note })

            let voice = factory.Voice(timeSignature: .meter(3, 8))
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Ratioed_Tuplet")
    func tupletRatioedTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Ratioed_Tuplet", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 350).addTimeSignature(.meter(4, 4))
            let specs: [(String, String)] = [
                ("f/4", "4"), ("a/4", "4"), ("b/4", "4"),
                ("g/4", "8"), ("e/4", "8"), ("g/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[3..<6]))
            _ = factory.Tuplet(notes: Array(notes[0..<3]).map { $0 as Note }, options: TupletOptions(ratioed: true))
            _ = factory.Tuplet(
                notes: Array(notes[3..<6]).map { $0 as Note },
                options: TupletOptions(notesOccupied: 4, ratioed: true)
            )

            let voice = factory.Voice()
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Bottom_Tuplet")
    func tupletBottomTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Bottom_Tuplet", width: 350, height: 160) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(3, 4))
            let specs: [(String, String)] = [
                ("f/4", "4"), ("c/4", "4"), ("g/4", "4"),
                ("d/5", "8"), ("g/3", "8"), ("b/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .down) }
            _ = factory.Beam(notes: Array(notes[3..<6]))
            _ = factory.Tuplet(notes: Array(notes[0..<3]).map { $0 as Note }, options: TupletOptions(location: .bottom))
            _ = factory.Tuplet(notes: Array(notes[3..<6]).map { $0 as Note }, options: TupletOptions(location: .bottom))

            let voice = factory.Voice(timeSignature: .meter(3, 4))
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Bottom_Ratioed_Tuplet")
    func tupletBottomRatioedTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Bottom_Ratioed_Tuplet", width: 350, height: 160) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(5, 8))
            let specs: [(String, String)] = [
                ("f/4", "4"), ("c/4", "4"), ("d/4", "4"),
                ("d/5", "8"), ("g/5", "8"), ("b/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .down) }
            _ = factory.Beam(notes: Array(notes[3..<6]))
            _ = factory.Tuplet(
                notes: Array(notes[0..<3]).map { $0 as Note },
                options: TupletOptions(ratioed: true, location: .bottom)
            )
            _ = factory.Tuplet(
                notes: Array(notes[3..<6]).map { $0 as Note },
                options: TupletOptions(notesOccupied: 1, location: .bottom)
            )

            let voice = factory.Voice(timeSignature: .meter(5, 8))
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Awkward_Tuplet")
    func tupletAwkwardTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Awkward_Tuplet", width: 370, height: 160) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10)
            let specs: [(String, String)] = [
                ("g/4", "16"), ("b/4", "16"), ("a/4", "16"), ("a/4", "16"),
                ("g/4", "16"), ("f/4", "16"), ("e/4", "16"), ("c/4", "16"),
                ("g/4", "16"), ("a/4", "16"), ("f/4", "16"), ("e/4", "16"),
                ("c/4", "8"), ("d/4", "8"), ("e/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[0..<12]))
            _ = factory.Tuplet(
                notes: Array(notes[0..<12]).map { $0 as Note },
                options: TupletOptions(notesOccupied: 142, ratioed: true)
            )
            _ = factory.Tuplet(
                notes: Array(notes[12..<15]).map { $0 as Note },
                options: TupletOptions(ratioed: true)
            )?.setBracketed(true)

            let voice = factory.Voice()
                .setStrict(false)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Complex_Tuplet")
    func tupletComplexTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Complex_Tuplet", width: 600, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(4, 4))
            let specs1: [(String, String)] = [
                ("b/4", "8d"), ("a/4", "16"), ("g/4", "8"), ("a/4", "16"),
                ("b/4", "16r"), ("g/4", "32"), ("f/4", "32"), ("g/4", "32"),
                ("f/4", "32"), ("a/4", "16"), ("f/4", "8"), ("b/4", "8"),
                ("a/4", "8"), ("g/4", "8"), ("b/4", "8"), ("a/4", "8"),
            ]
            let notes1 = try specs1.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            // Match upstream rest placement for the 16th rest in this sequence.
            _ = notes1[4].setKeyLine(0, line: notes1[4].getKeyLine(0) - 0.5)
            Dot.buildAndAttach([notes1[0]], all: true)

            let specs2: [(String, String)] = [("c/4", "4"), ("c/4", "4"), ("c/4", "4"), ("c/4", "4")]
            let notes2 = try specs2.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .down) }

            _ = factory.Beam(notes: Array(notes1[0..<3]))
            _ = factory.Beam(notes: Array(notes1[5..<9]))
            _ = factory.Beam(notes: Array(notes1[11..<16]))

            _ = factory.Tuplet(notes: Array(notes1[0..<3]).map { $0 as Note })
            _ = factory.Tuplet(
                notes: Array(notes1[3..<11]).map { $0 as Note },
                options: TupletOptions(numNotes: 7, notesOccupied: 4, ratioed: false)
            )
            _ = factory.Tuplet(
                notes: Array(notes1[11..<16]).map { $0 as Note },
                options: TupletOptions(notesOccupied: 4)
            )

            let voice1 = factory.Voice()
                .setStrict(true)
                .addTickables(notes1.map { $0 as Tickable })
            let voice2 = factory.Voice()
                .setStrict(true)
                .addTickables(notes2.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice1, voice2])
        }
    }

    @Test("Tuplet.Mixed_Stem_Direction_Tuplet")
    func tupletMixedStemDirectionTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Mixed_Stem_Direction_Tuplet", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10)
            let specs: [(String, StemDirection)] = [
                ("a/4", .up), ("c/6", .down), ("a/4", .up),
                ("f/5", .up), ("a/4", .down), ("c/6", .down),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: "4", stemDirection: $0.1) }
            _ = factory.Tuplet(notes: Array(notes[0..<2]).map { $0 as Note }, options: TupletOptions(notesOccupied: 3))
            _ = factory.Tuplet(notes: Array(notes[2..<4]).map { $0 as Note }, options: TupletOptions(notesOccupied: 3))
            _ = factory.Tuplet(notes: Array(notes[4..<6]).map { $0 as Note }, options: TupletOptions(notesOccupied: 3))

            let voice = factory.Voice()
                .setStrict(false)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Mixed_Stem_Direction_Bottom_Tuplet")
    func tupletMixedStemDirectionBottomTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Mixed_Stem_Direction_Bottom_Tuplet", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10)
            let specs: [(String, StemDirection)] = [
                ("f/3", .up), ("a/5", .down), ("a/4", .up),
                ("f/3", .up), ("a/4", .down), ("c/4", .down),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: "4", stemDirection: $0.1) }
            _ = factory.Tuplet(notes: Array(notes[0..<2]).map { $0 as Note }, options: TupletOptions(notesOccupied: 3))
            _ = factory.Tuplet(notes: Array(notes[2..<4]).map { $0 as Note }, options: TupletOptions(notesOccupied: 3))
            _ = factory.Tuplet(notes: Array(notes[4..<6]).map { $0 as Note }, options: TupletOptions(notesOccupied: 3))

            let voice = factory.Voice()
                .setStrict(false)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Nested_Tuplets")
    func tupletNestedTupletsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Nested_Tuplets", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(4, 4))
            let specs: [(String, String)] = [
                ("b/4", "4"), ("a/4", "4"), ("g/4", "16"), ("a/4", "16"),
                ("f/4", "16"), ("a/4", "16"), ("g/4", "16"), ("b/4", "2"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[2..<7]))
            _ = factory.Tuplet(
                notes: Array(notes[2..<7]).map { $0 as Note },
                options: TupletOptions(numNotes: 5, notesOccupied: 4)
            )
            _ = factory.Tuplet(
                notes: Array(notes[0..<7]).map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 2)
            )

            let voice = factory.Voice()
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    @Test("Tuplet.Single_Tuplets")
    func tupletSingleTupletsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Single_Tuplets", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(4, 4))
            let specs: [(String, String)] = [
                ("c/4", "4"), ("d/4", "8"), ("e/4", "8"), ("f/4", "8"),
                ("g/4", "8"), ("a/4", "2"), ("b/4", "4"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[1..<4]))
            _ = factory.Tuplet(
                notes: Array(notes[0..<1]).map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 2, ratioed: true)
            )
            _ = factory.Tuplet(
                notes: Array(notes[1..<4]).map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 2)
            )
            _ = factory.Tuplet(
                notes: Array(notes[4..<5]).map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 2, bracketed: true, ratioed: true)
            )
            _ = factory.Tuplet(
                notes: Array(notes[0..<6]).map { $0 as Note },
                options: TupletOptions(numNotes: 4, notesOccupied: 3, bracketed: true, ratioed: true)
            )

            let voice = factory.Voice(timeSignature: .meter(4, 4))
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            try formatAndDrawTupletVoices(factory, stave, [voice])
        }
    }

    // MARK: - VexFlow 5.1.0 cases

    private func makeBoundingTupletNotes(_ factory: Factory) throws -> [StaveNote] {
        try (0..<21).map { i in
            try makeTupletNote(factory, key: ["g/4", "a/4", "b/4"][i % 3], duration: "4", stemDirection: .up)
        }
    }

    private func drawTupletBoundingBox(_ context: SVGRenderContext, _ tuplet: Tuplet?) throws {
        let t = try #require(tuplet)
        let bb = try #require(t.getBoundingBox())
        context.beginPath()
        context.rect(bb.x, bb.y, bb.w, bb.h)
        context.stroke()
    }

    private func runTupletBoundingCase(test: String, location: TupletLocation?) throws {
        try runCategorySVGParityCase(module: "Tuplet", test: test, width: 600, height: 140) { factory, context in
            let stave = factory.Stave(x: 10, y: 10)
            let notes = try makeBoundingTupletNotes(factory)
            func tuplet(_ range: Range<Int>, bracketed: Bool? = nil, ratioed: Bool? = nil, suffix: String? = nil) -> Tuplet? {
                factory.Tuplet(
                    notes: Array(notes[range]).map { $0 as Note },
                    options: TupletOptions(
                        numNotes: 3, notesOccupied: 2, bracketed: bracketed, ratioed: ratioed,
                        location: location, suffix: suffix
                    )
                )
            }
            let tuplets = [
                tuplet(0..<3, bracketed: false),
                tuplet(3..<6, bracketed: false, ratioed: true),
                tuplet(6..<9, bracketed: false, suffix: Glyphs.metNoteQuarterUp),
                tuplet(9..<12, bracketed: false, ratioed: true, suffix: Glyphs.metNoteQuarterUp),
                tuplet(12..<15),
                tuplet(15..<18, ratioed: true),
                tuplet(18..<21, ratioed: true, suffix: Glyphs.metNoteQuarterUp),
            ]

            let voice = factory.Voice().setStrict(false).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()

            for t in tuplets {
                try drawTupletBoundingBox(context, t)
            }
        }
    }

    @Test("Tuplet.Bounding_Box_Above")
    func tupletBoundingBoxAboveMatchesUpstream() throws {
        try runTupletBoundingCase(test: "Bounding_Box_Above", location: nil)
    }

    @Test("Tuplet.Bounding_Box_Below")
    func tupletBoundingBoxBelowMatchesUpstream() throws {
        try runTupletBoundingCase(test: "Bounding_Box_Below", location: .bottom)
    }

    @Test("Tuplet.Suffixed_Tuplet")
    func tupletSuffixedTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Suffixed_Tuplet", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 350).addTimeSignature(.meter(4, 4))
            let specs: [(String, String)] = [
                ("f/4", "4"), ("a/4", "4"), ("b/4", "4"),
                ("g/4", "8"), ("e/4", "8"), ("g/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[3..<6]))
            _ = factory.Tuplet(
                notes: Array(notes[0..<3]).map { $0 as Note },
                options: TupletOptions(ratioed: true, suffix: Glyphs.noteQuarterUp)
            )
            _ = factory.Tuplet(
                notes: Array(notes[3..<6]).map { $0 as Note },
                options: TupletOptions(notesOccupied: 4, ratioed: true, suffix: Glyphs.note8thUp)
            )
            let voice = factory.Voice().setStrict(true).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Tuplet.Bottom_Suffixed_Tuplet")
    func tupletBottomSuffixedTupletMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Bottom_Suffixed_Tuplet", width: 350, height: 160) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(5, 8))
            let specs: [(String, String)] = [
                ("f/4", "4"), ("c/4", "4"), ("d/4", "4"),
                ("d/5", "8"), ("g/5", "8"), ("b/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .down) }
            _ = factory.Beam(notes: Array(notes[3..<6]))
            _ = factory.Tuplet(
                notes: Array(notes[0..<3]).map { $0 as Note },
                options: TupletOptions(ratioed: true, location: .bottom, suffix: Glyphs.metNoteQuarterUp)
            )
            _ = factory.Tuplet(
                notes: Array(notes[3..<6]).map { $0 as Note },
                options: TupletOptions(notesOccupied: 1, location: .bottom, suffix: Glyphs.metNote8thUp)
            )
            let voice = factory.Voice(time: VoiceTime(numBeats: 5, beatValue: 8))
                .setStrict(true)
                .addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Tuplet.Nested_Tuplets_Only_Tuplet_Children")
    func tupletNestedTupletsOnlyTupletChildrenMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Tuplet", test: "Nested_Tuplets_Only_Tuplet_Children", width: 450, height: 140) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10).addTimeSignature(.meter(4, 4))
            let specs: [(String, String)] = [
                ("b/4", "4"), ("a/4", "4"), ("c/4", "4"),
                ("g/4", "8"), ("a/4", "8"), ("f/4", "8"),
            ]
            let notes = try specs.map { try makeTupletNote(factory, key: $0.0, duration: $0.1, stemDirection: .up) }
            _ = factory.Beam(notes: Array(notes[3...]))
            _ = factory.Tuplet(
                notes: Array(notes[0..<3]).map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 2)
            )
            _ = factory.Tuplet(
                notes: Array(notes[3...]).map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 2)
            )
            _ = factory.Tuplet(
                notes: notes.map { $0 as Note },
                options: TupletOptions(numNotes: 3, notesOccupied: 4)
            )
            let voice = factory.Voice().setStrict(true).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}
