import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    private func drawUnisonSystemCase(
        factory: Factory,
        unison: Bool,
        voices: [Voice],
        time: TimeSignatureSpec
    ) throws {
        Tables.UNISON = unison

        let system = factory.System(options: SystemOptions(
            factory: factory,
            x: 10,
            width: 400,
            y: 40
        ))
        let stave = system.addStave(SystemStave(voices: voices))
        _ = stave.addClef(ClefName.treble).addTimeSignature(time)

        try factory.draw()
    }

    @Test("Unison.Simple_true_")
    func unisonSimpleTrueMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Simple_true_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let voice1 = score.voice(score.notes("e4/q, e4/q, e4/h"))
            let voice2 = score.voice(score.notes("e4/8, e4/8, e4/q, e4/h"))
            try drawUnisonSystemCase(factory: factory, unison: true, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Simple_false_")
    func unisonSimpleFalseMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Simple_false_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let voice1 = score.voice(score.notes("e4/q, e4/q, e4/h"))
            let voice2 = score.voice(score.notes("e4/8, e4/8, e4/q, e4/h"))
            try drawUnisonSystemCase(factory: factory, unison: false, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Accidentals_true_")
    func unisonAccidentalsTrueMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Accidentals_true_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let voice1 = score.voice(score.notes("e4/q, e#4/q, e#4/h"))
            let voice2 = score.voice(score.notes("e4/8, e4/8, eb4/q, eb4/h"))
            try drawUnisonSystemCase(factory: factory, unison: true, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Accidentals_false_")
    func unisonAccidentalsFalseMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Accidentals_false_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let voice1 = score.voice(score.notes("e4/q, e#4/q, e#4/h"))
            let voice2 = score.voice(score.notes("e4/8, e4/8, eb4/q, eb4/h"))
            try drawUnisonSystemCase(factory: factory, unison: false, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Dots_true_")
    func unisonDotsTrueMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Dots_true_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let voice1 = score.voice(score.notes("e4/q.., e4/16, e4/h"))
            let voice2 = score.voice(score.notes("(a4 e4)/q., e4/8, e4/h"))
            try drawUnisonSystemCase(factory: factory, unison: true, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Dots_false_")
    func unisonDotsFalseMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Dots_false_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let voice1 = score.voice(score.notes("e4/q.., e4/16, e4/h"))
            let voice2 = score.voice(score.notes("(a4 e4)/q., e4/8, e4/h"))
            try drawUnisonSystemCase(factory: factory, unison: false, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Breve_true_")
    func unisonBreveTrueMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Breve_true_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let breve = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/4"], duration: "1/2"))
            let voice1 = score.voice([breve], time: .meter(8, 4))
            let voice2 = score.voice(score.notes("e4/1, e4/1"), time: .meter(8, 4))
            try drawUnisonSystemCase(factory: factory, unison: true, voices: [voice1, voice2], time: .meter(8, 4))
        }
    }

    @Test("Unison.Breve_false_")
    func unisonBreveFalseMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Breve_false_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let breve = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/4"], duration: "1/2"))
            let voice1 = score.voice([breve], time: .meter(8, 4))
            let voice2 = score.voice(score.notes("e4/1, e4/1"), time: .meter(8, 4))
            try drawUnisonSystemCase(factory: factory, unison: false, voices: [voice1, voice2], time: .meter(8, 4))
        }
    }

    @Test("Unison.Style_true_")
    func unisonStyleTrueMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Style_true_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let notes1 = score.notes("e4/q, e4/q, e4/h")
            let notes2 = score.notes("e4/8, e4/8, e4/q, e4/h")
            _ = notes1[2].setStyle(ElementStyle(fillStyle: "blue", strokeStyle: "blue"))
            _ = notes2[3].setStyle(ElementStyle(fillStyle: "green", strokeStyle: "green"))
            let voice1 = score.voice(notes1)
            let voice2 = score.voice(notes2)
            try drawUnisonSystemCase(factory: factory, unison: true, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }

    @Test("Unison.Style_false_")
    func unisonStyleFalseMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Unison", test: "Style_false_", width: 500, height: 200) { factory, _ in
            let score = factory.EasyScore()
            let notes1 = score.notes("e4/q, e4/q, e4/h")
            let notes2 = score.notes("e4/8, e4/8, e4/q, e4/h")
            _ = notes1[2].setStyle(ElementStyle(fillStyle: "blue", strokeStyle: "blue"))
            _ = notes2[3].setStyle(ElementStyle(fillStyle: "green", strokeStyle: "green"))
            let voice1 = score.voice(notes1)
            let voice2 = score.voice(notes2)
            try drawUnisonSystemCase(factory: factory, unison: false, voices: [voice1, voice2], time: .meter(4, 4))
        }
    }
}
