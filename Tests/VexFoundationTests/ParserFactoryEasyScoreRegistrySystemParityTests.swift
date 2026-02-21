import Testing
@testable import VexFoundation

@Suite("Parser, Factory, EasyScore, Registry, System Parity")
struct ParserFactoryEasyScoreRegistrySystemParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private final class MicroScoreGrammar: Grammar {
        func begin() -> RuleFunction { LINE }

        func LINE() -> Rule { Rule(expect: [ITEM, MAYBE_MORE_ITEMS, EOL]) }
        func ITEM() -> Rule { Rule(expect: [PIANO_KEY_NUMBER, CHORD], or: true) }
        func MAYBE_MORE_ITEMS() -> Rule { Rule(expect: [ITEM], zeroOrMore: true) }
        func PIANO_KEY_NUMBER() -> Rule { Rule(expect: [NUM], oneOrMore: true) }
        func CHORD() -> Rule { Rule(expect: [LEFT_BRACKET, PIANO_KEY_NUMBER, MORE_CHORD_PARTS, RIGHT_BRACKET]) }
        func MORE_CHORD_PARTS() -> Rule { Rule(expect: [PERIOD, PIANO_KEY_NUMBER], oneOrMore: true) }

        func NUM() -> Rule { Rule(token: "\\d+") }
        func PERIOD() -> Rule { Rule(token: "\\.") }
        func LEFT_BRACKET() -> Rule { Rule(token: "\\[") }
        func RIGHT_BRACKET() -> Rule { Rule(token: "\\]") }
        func EOL() -> Rule { Rule(token: "$") }
    }

    private func makeEasyScore() -> EasyScore {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 500)
        return factory.EasyScore()
    }

    private func assertAllPass(_ lines: [String], score: EasyScore) {
        for line in lines {
            let result = score.parse(line)
            #expect(result.success, "'\(line)' should parse successfully.")
        }
    }

    @Test func parserCategoryMicroScore_mustPass() throws {
        let parser = Parser(grammar: MicroScoreGrammar())
        let mustPass = [
            "40 42 44 45 47 49 51 52",
            "[40.44.47] [45.49.52] [47.51.54] [49.52.56]",
            "40 [40.44.47] 45 47 [44.47.51]",
        ]

        for line in mustPass {
            let result = parser.parse(line)
            #expect(result.success, "'\(line)' should parse successfully.")
            #expect(result.matches.count == 3, "Expected 3 top-level matches for '\(line)'.")
        }
    }

    @Test func parserCategoryMicroScore_failurePositions() throws {
        let parser = Parser(grammar: MicroScoreGrammar())

        let badA = parser.parse("40 42 44 45 47 49 5A 52")
        #expect(!badA.success)
        #expect(badA.errorPos == 19)

        let badB = parser.parse("40.44.47] [45.49.52] [47.51.54] [49.52.56]")
        #expect(!badB.success)
        #expect(badB.errorPos == 2)

        let badC = parser.parse("40 [40] 45 47 [44.47.51]")
        #expect(!badC.success)
        #expect(badC.errorPos == 3)
    }

    @Test func factoryCategoryDrawTab_repeatBeginBarlinesAligned() throws {
        let factory = Factory(options: FactoryOptions(width: 500, height: 400))
        let ctx = SVGRenderContext(width: 500, height: 400)
        _ = factory.setContext(ctx)

        let system = factory.System(options: SystemOptions(width: 500))
        let stave = factory.Stave()
            .setClef(.treble)
            .setKeySignature("C#")
            .setBegBarType(.repeatBegin)
        let voices = [factory.Voice().addTickables([factory.GhostNote(duration: .whole)])]
        _ = system.addStave(SystemStave(voices: voices, stave: stave))

        let tabStave = factory.TabStave()
            .setClef(.tab)
            .setBegBarType(.repeatBegin)
        let tabVoices = [factory.Voice().addTickables([factory.GhostNote(duration: .whole)])]
        _ = system.addStave(SystemStave(voices: tabVoices, stave: tabStave))

        try factory.draw()

        let staveRepeat = stave.getModifiers(position: .begin, category: Barline.category)
            .compactMap { $0 as? Barline }
            .first { $0.getBarlineType() == .repeatBegin }
        let tabRepeat = tabStave.getModifiers(position: .begin, category: Barline.category)
            .compactMap { $0 as? Barline }
            .first { $0.getBarlineType() == .repeatBegin }

        #expect(staveRepeat != nil)
        #expect(tabRepeat != nil)
        if let staveX = staveRepeat?.getModifierX(), let tabX = tabRepeat?.getModifierX() {
            #expect(abs(staveX - tabX) < 0.001)
        }
    }

    @Test func easyscoreCategoryBasic_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "c4", "c#4", "c4/r", "c#5", "c3/m", "c3//m", "c3//h", "c3/s", "c3//s", "c3/g", "c3//g",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func easyscoreCategoryAccidentals_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "c3",
            "c##3, cb3",
            "cn3",
            "(c##3 cbb3 cn3), cb3",
            "cbb7",
            "c#7",
            "cn7",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func easyscoreCategoryDurations_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "c3/4",
            "c##3/w, cb3",
            "c##3/w, cb3/q",
            "c##3/q, cb3/32",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func easyscoreCategoryChords_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "(c5)",
            "(c3 e0 g9)",
            "(c##4 cbb4 cn4)/w, (c#5 cb2 a3)/32",
            "(d##4 cbb4 cn4)/w/r, (c#5 cb2 a3)",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func easyscoreCategoryDots_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "c3/4.",
            "c##3/w.., cb3",
            "c##3/q, cb3/32",
            "(c##3 cbb3 cn3)., cb3",
            "(c5).",
            "(c##4 cbb4 cn4)/w.., (c#5 cb2 a3)/32",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func easyscoreCategoryTypes_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "c3/4/m.",
            "c##3//r.., cb3",
            "c##3/m.., cb3",
            "c##3/r.., cb3",
            "fb4",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func easyscoreCategoryOptions_mustPassSamples() throws {
        let score = makeEasyScore()
        let mustPass = [
            "c3/4.[foo=\"bar\"]",
            "c##3/w.., cb3[id=\"blah\"]",
            "(c##3 cbb3 cn3).[blah=\"bod4o\"], cb3",
            "(c5)[fooooo=\"booo\"]",
            "c#5[id=\"foobar\"]",
        ]
        assertAllPass(mustPass, score: score)
    }

    @Test func registryCategoryDefaultRegistry_matchesUpstreamBehavior() throws {
        Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            let registry = Registry()
            let factory = Factory()
            let score = factory.EasyScore()

            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }

            _ = score.notes("C4[id=\"foobar\"]")
            let note = registry.getElementById("foobar")
            #expect(note != nil)

            _ = note?.setAttribute("id", "boobar")
            #expect(registry.getElementById("boobar") != nil)
            #expect(registry.getElementById("foobar") == nil)

            _ = registry.clear()
            #expect(registry.getElementsByType(StaveNote.category).count == 0)

            _ = score.notes("C5")
            #expect(registry.getElementsByType(StaveNote.category).count == 1)
        }
    }
}
