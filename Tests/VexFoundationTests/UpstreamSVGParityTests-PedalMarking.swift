import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("PedalMarking.Simple_Pedal_1")
    func pedalMarkingSimplePedal1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Simple_Pedal_1", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[2], notes0[3], notes1[3]],
                type: .text
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Simple_Pedal_2")
    func pedalMarkingSimplePedal2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Simple_Pedal_2", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[2], notes0[3], notes1[3]],
                type: .bracket
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Simple_Pedal_3")
    func pedalMarkingSimplePedal3MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Simple_Pedal_3", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[2], notes0[3], notes1[3]],
                type: .mixed
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Release_and_Depress_on_Same_Note_1")
    func pedalMarkingReleaseAndDepressOnSameNote1MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "PedalMarking",
            test: "Release_and_Depress_on_Same_Note_1",
            width: 550,
            height: 200
        ) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[3], notes0[3], notes1[1], notes1[1], notes1[3]],
                type: .bracket
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Release_and_Depress_on_Same_Note_2")
    func pedalMarkingReleaseAndDepressOnSameNote2MatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "PedalMarking",
            test: "Release_and_Depress_on_Same_Note_2",
            width: 550,
            height: 200
        ) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[3], notes0[3], notes1[1], notes1[1], notes1[3]],
                type: .mixed
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Custom_Text_1")
    func pedalMarkingCustomText1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Custom_Text_1", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes1[3]],
                type: .text
            )
                .setCustomText("una corda", release: "tre corda")
            try factory.draw()
        }
    }

    @Test("PedalMarking.Custom_Text_2")
    func pedalMarkingCustomText2MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Custom_Text_2", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = try setupPedalMarkingVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes1[3]],
                type: .mixed
            )
                .setCustomText("Sost. Ped.")
            try factory.draw()
        }
    }

    @Test("PedalMarking.Simple_Pedal_1b")
    func pedalMarkingSimplePedal1bMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Simple_Pedal_1b", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = setupPedalMarkingTwoVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[2], notes0[3], notes1[3]],
                type: .text
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Simple_Pedal_2b")
    func pedalMarkingSimplePedal2bMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Simple_Pedal_2b", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = setupPedalMarkingTwoVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[2], notes0[3], notes1[3]],
                type: .bracket
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Simple_Pedal_3b")
    func pedalMarkingSimplePedal3bMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Simple_Pedal_3b", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = setupPedalMarkingTwoVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[2], notes0[3], notes1[3]],
                type: .mixed
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Release_and_Depress_on_Same_Note_1b")
    func pedalMarkingReleaseAndDepressOnSameNote1bMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Release_and_Depress_on_Same_Note_1b", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = setupPedalMarkingTwoVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[3], notes0[3], notes1[1], notes1[1], notes1[3]],
                type: .bracket
            )
            try factory.draw()
        }
    }

    @Test("PedalMarking.Release_and_Depress_on_Same_Note_2b")
    func pedalMarkingReleaseAndDepressOnSameNote2bMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "PedalMarking", test: "Release_and_Depress_on_Same_Note_2b", width: 550, height: 200) { factory, _ in
            let (notes0, notes1) = setupPedalMarkingTwoVoices(factory: factory)
            _ = factory.PedalMarking(
                notes: [notes0[0], notes0[3], notes0[3], notes1[1], notes1[1], notes1[3]],
                type: .mixed
            )
            try factory.draw()
        }
    }

    /// Upstream `createTest2`: two staves with two voices each.
    private func setupPedalMarkingTwoVoices(factory: Factory) -> (notes0: [StaveNote], notes1: [StaveNote]) {
        let score = factory.EasyScore()

        let stave0 = factory.Stave(width: 250).addClef(.treble)
        let voice0 = score.voice(score.notes("b4/4, b4, b4, b4", options: ["stem": "down"]))
        let voice0b = score.voice(score.notes("b5/4, b5, b5, b5", options: ["stem": "up"]))
        _ = factory.Formatter().joinVoices([voice0, voice0b]).formatToStave([voice0, voice0b], stave: stave0)

        let stave1 = factory.Stave(x: 250, width: 260)
        let voice1 = score.voice(score.notes("c4/4, c4, c4, c4", options: ["stem": "down"]))
        let voice1b = score.voice(score.notes("c5/4, c5, c5, c5/16, c5/16, c5/16, c5/16", options: ["stem": "up"]))
        _ = factory.Formatter().joinVoices([voice1, voice1b]).formatToStave([voice1, voice1b], stave: stave1)

        return (
            voice0.getTickables().compactMap { $0 as? StaveNote },
            voice1.getTickables().compactMap { $0 as? StaveNote }
        )
    }

    private func setupPedalMarkingVoices(factory: Factory) throws -> (notes0: [StaveNote], notes1: [StaveNote]) {
        let stave0 = factory.Stave(width: 250).addClef(.treble)

        let notes0: [StaveNote] = try [
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4"], duration: "4", stemDirection: .up)),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4"], duration: "4", stemDirection: .up)),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4"], duration: "4", stemDirection: .up)),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["b/4"], duration: "4", stemDirection: .down)),
        ]
        let voice0 = factory.Voice().addTickables(notes0.map { $0 as Tickable })
        _ = factory.Formatter().joinVoices([voice0]).formatToStave([voice0], stave: stave0)

        let stave1 = factory.Stave(x: 250, width: 260)
        let notes1: [StaveNote] = try [
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", stemDirection: .up)),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", stemDirection: .up)),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", stemDirection: .up)),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["c/4"], duration: "4", stemDirection: .up)),
        ]
        let voice1 = factory.Voice().addTickables(notes1.map { $0 as Tickable })
        _ = factory.Formatter().joinVoices([voice1]).formatToStave([voice1], stave: stave1)

        return (notes0, notes1)
    }
}
