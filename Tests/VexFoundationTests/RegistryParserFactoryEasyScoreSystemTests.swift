// VexFoundation - Tests for Phase 15: Registry, Parser, Factory, EasyScore, System

import Testing
@testable import VexFoundation

@Suite("Registry, Parser, Factory, EasyScore, System")
struct RegistryParserFactoryEasyScoreSystemTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    // ============================================================
    // MARK: - Registry Tests
    // ============================================================

    @Test func registryCreation() {
        let reg = Registry()
        #expect(reg.getElementById("test") == nil)
    }

    @Test func registryRegisterElement() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        #expect(reg.getElementById("e1") != nil)
    }

    @Test func registryAutoId() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem)
        let id = elem.getAttribute("id")!
        #expect(reg.getElementById(id) != nil)
    }

    @Test func registryClear() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        _ = reg.clear()
        #expect(reg.getElementById("e1") == nil)
    }

    @Test func registryGetElementsByType() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        let elements = reg.getElementsByType("Element")
        #expect(elements.count == 1)
    }

    @Test func registryGetElementsByAttribute() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        let found = reg.getElementsByAttribute("id", value: "e1")
        #expect(found.count == 1)
    }

    @Test func registryDefaultRegistry() {
        Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            let reg = Registry()
            Registry.enableDefaultRegistry(reg)
            #expect(Registry.getDefaultRegistry() != nil)
            Registry.disableDefaultRegistry()
            #expect(Registry.getDefaultRegistry() == nil)
        }
    }

    @Test func registryDefaultRegistryAutoRegistersElements() {
        Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            let reg = Registry()
            Registry.enableDefaultRegistry(reg)
            defer { Registry.disableDefaultRegistry() }

            let elem = VexElement()
            let id = elem.getAttribute("id")!
            #expect(reg.getElementById(id) != nil)
        }
    }

    @Test func registryUpdateIndex() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        reg.updateIndex(RegistryUpdate(id: "e1", name: "type", value: "Note", oldValue: "Element"))
        let notes = reg.getElementsByType("Note")
        #expect(notes.count == 1)
    }

    @Test func registryOnUpdate() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        _ = reg.onUpdate(RegistryUpdate(id: "e1", name: "type", value: "Changed", oldValue: "Element"))
        let changed = reg.getElementsByType("Changed")
        #expect(changed.count == 1)
    }

    @Test func registryGetElementsByClass() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")
        _ = elem.addClass("highlight")
        let found = reg.getElementsByClass("highlight")
        #expect(found.count == 1)
    }

    @Test func registryTracksIdMutation() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")

        _ = elem.setAttribute("id", "e2")
        #expect(reg.getElementById("e1") == nil)
        #expect(reg.getElementById("e2") != nil)
    }

    @Test func registryTracksClassMutation() {
        let reg = Registry()
        let elem = VexElement()
        _ = reg.register(elem, id: "e1")

        _ = elem.addClass("foo")
        #expect(reg.getElementsByClass("foo").count == 1)

        _ = elem.addClass("bar")
        #expect(reg.getElementsByClass("bar").count == 1)

        _ = elem.removeClass("foo")
        #expect(reg.getElementsByClass("foo").count == 0)
        #expect(reg.getElementsByClass("bar").count == 1)
    }

    @Test func registryMultipleElements() {
        let reg = Registry()
        let e1 = VexElement()
        let e2 = VexElement()
        _ = reg.register(e1, id: "a")
        _ = reg.register(e2, id: "b")
        #expect(reg.getElementById("a") != nil)
        #expect(reg.getElementById("b") != nil)
        #expect(reg.getElementById("c") == nil)
    }

    // ============================================================
    // MARK: - Parser Tests
    // ============================================================

    @Test func parserMatchSuccess() {
        // Simple grammar: matches a single word
        class SimpleGrammar: Grammar {
            func begin() -> RuleFunction { WORD }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
        }
        let parser = Parser(grammar: SimpleGrammar())
        let result = parser.parse("hello")
        #expect(result.success == true)
    }

    @Test func parserMatchFailure() {
        class SimpleGrammar: Grammar {
            func begin() -> RuleFunction { WORD }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
        }
        let parser = Parser(grammar: SimpleGrammar())
        let result = parser.parse("123")
        #expect(result.success == false)
    }

    @Test func parserSequence() {
        class SeqGrammar: Grammar {
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule { Rule(expect: [WORD, NUMBER]) }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
            func NUMBER() -> Rule { Rule(token: "[0-9]+") }
        }
        let parser = Parser(grammar: SeqGrammar())
        let result = parser.parse("abc 123")
        #expect(result.success == true)
    }

    @Test func parserOr() {
        class OrGrammar: Grammar {
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule { Rule(expect: [NUMBER, WORD], or: true) }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
            func NUMBER() -> Rule { Rule(token: "[0-9]+") }
        }
        let parser = Parser(grammar: OrGrammar())
        let r1 = parser.parse("hello")
        #expect(r1.success == true)
        let r2 = parser.parse("42")
        #expect(r2.success == true)
    }

    @Test func parserMaybe() {
        class MaybeGrammar: Grammar {
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule { Rule(expect: [WORD, OPTNUM]) }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
            func OPTNUM() -> Rule { Rule(expect: [NUMBER], maybe: true) }
            func NUMBER() -> Rule { Rule(token: "[0-9]+") }
        }
        let parser = Parser(grammar: MaybeGrammar())
        let r1 = parser.parse("hello 42")
        #expect(r1.success == true)
        let r2 = parser.parse("hello")
        #expect(r2.success == true)
    }

    @Test func parserZeroOrMore() {
        class RepeatGrammar: Grammar {
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule { Rule(expect: [WORD, NUMBERS]) }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
            func NUMBERS() -> Rule { Rule(expect: [NUMBER], zeroOrMore: true) }
            func NUMBER() -> Rule { Rule(token: "[0-9]+") }
        }
        let parser = Parser(grammar: RepeatGrammar())
        let r1 = parser.parse("abc 1 2 3")
        #expect(r1.success == true)
        let r2 = parser.parse("abc")
        #expect(r2.success == true)
    }

    @Test func parserOneOrMore() {
        class RepeatGrammar: Grammar {
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule { Rule(expect: [NUMBERS]) }
            func NUMBERS() -> Rule { Rule(expect: [NUMBER], oneOrMore: true) }
            func NUMBER() -> Rule { Rule(token: "[0-9]+") }
        }
        let parser = Parser(grammar: RepeatGrammar())
        let r1 = parser.parse("1 2 3")
        #expect(r1.success == true)
    }

    @Test func parserTriggerFunction() {
        class TriggerGrammar: Grammar {
            var captured: String?
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule {
                Rule(expect: [WORD], run: { [weak self] matches in
                    self?.captured = matches.first?.stringValue
                })
            }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
        }
        let grammar = TriggerGrammar()
        let parser = Parser(grammar: grammar)
        let result = parser.parse("hello")
        #expect(result.success == true)
        #expect(grammar.captured == "hello")
    }

    @Test func parserErrorPosition() {
        class SimpleGrammar: Grammar {
            func begin() -> RuleFunction { LINE }
            func LINE() -> Rule { Rule(expect: [WORD, NUMBER]) }
            func WORD() -> Rule { Rule(token: "[a-z]+") }
            func NUMBER() -> Rule { Rule(token: "[0-9]+") }
        }
        let parser = Parser(grammar: SimpleGrammar())
        let result = parser.parse("abc xyz")
        #expect(result.success == false)
        #expect(result.errorPos != nil)
    }

    @Test func parserInvalidGrammarRuleFailsWithoutCrash() {
        class BadGrammar: Grammar {
            func begin() -> RuleFunction { BAD }
            func BAD() -> Rule { Rule() }
        }
        let parser = Parser(grammar: BadGrammar())
        let result = parser.parse("anything")
        #expect(result.success == false)
        #expect(result.parserError == .invalidGrammarRuleMissingTokenOrExpect)
    }

    @Test func parserParseThrowingReportsGrammarError() {
        class BadGrammar: Grammar {
            func begin() -> RuleFunction { BAD }
            func BAD() -> Rule { Rule() }
        }
        let parser = Parser(grammar: BadGrammar())
        do {
            _ = try parser.parseThrowing("anything")
            #expect(Bool(false))
        } catch {
            #expect(error is ParserParseError)
        }
    }

    @Test func matchStringValue() {
        let m: Match = .string("hello")
        #expect(m.stringValue == "hello")
    }

    @Test func matchNullValue() {
        let m: Match = .null
        #expect(m.stringValue == nil)
    }

    @Test func matchArrayValue() {
        let m: Match = .array([.string("a"), .string("b")])
        #expect(m.stringValue == nil) // arrays don't have stringValue
    }

    // ============================================================
    // MARK: - Factory Tests
    // ============================================================

    @Test func factoryCreation() {
        let factory = Factory()
        #expect(factory.getStave() == nil)
    }

    @Test func factoryStave() {
        let factory = Factory()
        let stave = factory.Stave(x: 10, y: 20, width: 300)
        #expect(stave.getX() == 10)
        #expect(stave.getY() == 20)
        #expect(factory.getStave() != nil)
    }

    @Test func factoryTabStave() {
        let factory = Factory()
        let ts = factory.TabStave(x: 10, y: 20, width: 300)
        #expect(ts is TabStave)
        #expect(ts.getWidth() == 300)
    }

    @Test func factoryStaveNote() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 300)
        let note = factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        #expect(note.getKeys().count == 1)
    }

    @Test func factoryGhostNote() {
        let factory = Factory()
        let ghost = factory.GhostNote(duration: .quarter)
        #expect(ghost.getDuration() == "4")
    }

    @Test func factoryGhostNoteParsingDuration() {
        let factory = Factory()
        let ghost = factory.GhostNote(parsingDuration: "8")
        #expect(ghost != nil)
        #expect(ghost?.getDuration() == "8")
        #expect(ghost?.isRest() == true)
    }

    @Test func factoryAccidental() {
        let factory = Factory()
        let accid = factory.Accidental(type: .sharp)
        #expect(accid.getCategory() == "Accidental")
    }

    @Test func factoryAccidentalParsing() throws {
        let factory = Factory()
        let accid = try factory.Accidental(parsing: "#")
        #expect(accid.accidentalType == .sharp)
    }

    @Test func factoryAccidentalParsingOrNil() {
        let factory = Factory()
        #expect(factory.Accidental(parsingOrNil: "invalid") == nil)
    }

    @Test func factoryAnnotation() {
        let factory = Factory()
        let ann = factory.Annotation(text: "test")
        #expect(ann.getCategory() == "Annotation")
    }

    @Test func factoryArticulation() {
        let factory = Factory()
        let art = factory.Articulation(type: "a.")
        #expect(art.getCategory() == "Articulation")
    }

    @Test func factoryVoice() {
        let factory = Factory()
        let voice = factory.Voice()
        // Voice defaults to strict mode
        #expect(voice.getMode() == .strict)
    }

    @Test func factoryVoiceTimeSpec() {
        let factory = Factory()
        let voice = factory.Voice(timeSignature: .meter(3, 4))
        // 3/4 time = 3 beats of quarter note resolution
        #expect(voice.getTotalTicks().value() > 0)
    }

    @Test func factoryBeam() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let notes: [StemmableNote] = [
            factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
        ]
        let beam = factory.Beam(notes: notes)
        #expect(beam is Beam)
    }

    @Test func factoryTuplet() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let notes: [Note] = [
            factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .eighth)),
            factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 4)), duration: .eighth)),
            factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .e, octave: 4)), duration: .eighth)),
        ]
        let tuplet = factory.Tuplet(notes: notes)
        #expect(tuplet.getNoteCount() == 3)
    }

    @Test func factoryReset() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 300)
        factory.reset()
        #expect(factory.getStave() == nil)
        #expect(factory.getVoices().isEmpty)
    }

    @Test func factoryChordSymbol() {
        let factory = Factory()
        let cs = factory.ChordSymbol()
        #expect(cs.getCategory() == "ChordSymbol")
    }

    @Test func factoryTabNote() {
        let factory = Factory()
        _ = factory.TabStave(x: 0, y: 0, width: 300)
        let tn = factory.TabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 1, fret: 5)]
        ))
        #expect(tn.getCategory() == "TabNote")
    }

    @Test func factoryFormatter() {
        let factory = Factory()
        let fmt = factory.Formatter()
        #expect(fmt.hasMinTotalWidth == false)
    }

    @Test func factoryTickContext() {
        let factory = Factory()
        let tc = factory.TickContext()
        #expect(tc is TickContext)
    }

    @Test func factoryModifierContext() {
        let factory = Factory()
        let mc = factory.ModifierContext()
        #expect(mc.preFormatted == false)
    }

    @Test func factoryStaveConnector() {
        let factory = Factory()
        let s1 = factory.Stave(x: 0, y: 0, width: 300)
        let s2 = factory.Stave(x: 0, y: 100, width: 300)
        let conn = factory.StaveConnector(topStave: s1, bottomStave: s2)
        #expect(conn.getType() == .double)
    }

    @Test func factoryStaveTie() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 300)
        let n1 = factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        let n2 = factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        let tie = factory.StaveTie(notes: TieNotes(firstNote: n1, lastNote: n2))
        #expect(tie.getCategory() == "StaveTie")
    }

    @Test func factoryOrnament() {
        let factory = Factory()
        let orn = factory.Ornament("mordent")
        #expect(orn.getCategory() == "Ornament")
    }

    @Test func factoryEasyScore() {
        let factory = Factory()
        let score = factory.EasyScore()
        #expect(score.defaults.clef == .treble)
    }

    @Test func factoryDrawWithoutContextThrows() {
        let factory = Factory()
        do {
            try factory.draw()
            #expect(Bool(false))
        } catch {
            #expect(error as? FactoryError == .missingRenderContext)
        }
    }

    // ============================================================
    // MARK: - EasyScore Tests
    // ============================================================

    @Test func easyScoreParseSimple() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q")
        #expect(notes.count == 1)
    }

    @Test func easyScoreDirectInitWithoutFactoryThrows() {
        do {
            _ = try EasyScore()
            #expect(Bool(false))
        } catch {
            #expect(error as? EasyScoreInitError == .missingFactory)
        }
    }

    @Test func easyScoreMultipleNotes() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q, D4, E4, F4")
        #expect(notes.count == 4)
    }

    @Test func easyScoreDurations() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/w, D4/h, E4/q, F4/8")
        #expect(notes.count == 4)
    }

    @Test func easyScoreChord() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("(C4 E4 G4)/q")
        #expect(notes.count == 1)
    }

    @Test func easyScoreAccidentals() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C#4/q, Bb4, En4")
        #expect(notes.count == 3)
    }

    @Test func easyScoreDots() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q., D4/h..")
        #expect(notes.count == 2)
    }

    @Test func easyScoreVoice() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)
        #expect(voice.getTickables().count == 4)
    }

    @Test func easyScoreSetDefaults() {
        let factory = Factory()
        let score = factory.EasyScore()
        _ = score.set(defaults: EasyScoreDefaults(clef: .bass, time: .meter(3, 4)))
        #expect(score.defaults.clef == .bass)
        #expect(score.defaults.time == .meter(3, 4))
    }

    @Test func easyScoreBeam() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/8, D4, E4, F4")
        let beamed = score.beam(notes)
        #expect(beamed.count == 4)
    }

    @Test func easyScoreParseResult() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let result = score.parse("C4/q")
        #expect(result.success == true)
    }

    @Test func easyScoreParseInvalidDurationFailsSemantically() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let result = score.parse("C4/3")
        #expect(result.success == false)
        #expect(score.lastParseError == .invalidDuration("3"))
        #expect(score.notes("C4/3").isEmpty)
    }

    @Test func easyScoreParseInvalidClefOptionFailsSemantically() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let result = score.parse("C4/q", options: ["clef": "badclef"])
        #expect(result.success == false)
        #expect(score.lastParseError == .invalidClef("badclef"))
    }

    @Test func easyScoreParseInvalidStemOptionFailsSemantically() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let result = score.parse("C4/q", options: ["stem": "sideways"])
        #expect(result.success == false)
        #expect(score.lastParseError == .invalidStemDirection("sideways"))
    }

    @Test func easyScoreParseThrowingHelpers() throws {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()

        let ok = try score.parseThrowing("C4/q")
        #expect(ok.success == true)
        #expect(try score.notesThrowing("C4/q").count == 1)

        do {
            _ = try score.parseThrowing("C4/3")
            #expect(Bool(false))
        } catch {
            #expect(error is EasyScoreParseError)
        }
    }

    @Test func easyScoreGhostNote() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q, D4/q/g, E4/q")
        // Ghost note is type 'g'
        #expect(notes.count == 3)
    }

    @Test func easyScoreStemUp() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q", options: ["stem": "up"])
        #expect(notes.count == 1)
        #expect(notes[0].getStemDirection() == Stem.UP)
    }

    @Test func easyScoreStemDown() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q", options: ["stem": "down"])
        #expect(notes.count == 1)
        #expect(notes[0].getStemDirection() == Stem.DOWN)
    }

    // ============================================================
    // MARK: - System Tests
    // ============================================================

    @Test func systemCategory() {
        #expect(System.category == "System")
    }

    @Test func systemCreation() {
        let factory = Factory()
        let system = factory.System()
        #expect(system.getX() == 10)
        #expect(system.getY() == 10)
    }

    @Test func systemDirectInitWithoutFactoryThrows() {
        do {
            _ = try System()
            #expect(Bool(false))
        } catch {
            #expect(error as? SystemError == .missingFactory)
        }
    }

    @Test func systemSetPosition() {
        let factory = Factory()
        let system = factory.System()
        system.setX(50)
        system.setY(100)
        #expect(system.getX() == 50)
        #expect(system.getY() == 100)
    }

    @Test func systemAddStave() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(width: 400))

        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)
        _ = system.addStave(SystemStave(voices: [voice]))
        #expect(system.getStaves().count == 1)
    }

    @Test func systemMultipleStaves() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(width: 400))

        let notes1 = score.notes("C4/q, D4, E4, F4")
        let notes2 = score.notes("E3/q, F3, G3, A3")
        let v1 = score.voice(notes1)
        let v2 = score.voice(notes2)
        _ = system.addStave(SystemStave(voices: [v1]))
        _ = system.addStave(SystemStave(voices: [v2]))
        #expect(system.getStaves().count == 2)
    }

    @Test func systemFormat() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(width: 400))

        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)
        _ = system.addStave(SystemStave(voices: [voice]))
        system.format()
        // format should set the bounding box
        #expect(system.boundingBox != nil)
    }

    @Test func systemDrawBeforeFormatThrows() {
        let factory = Factory()
        let system = factory.System()
        do {
            try system.draw()
            #expect(Bool(false))
        } catch {
            #expect(error as? SystemError == .drawRequiresFormat)
        }
    }

    @Test func systemAddConnector() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(width: 400))

        let notes1 = score.notes("C4/q, D4, E4, F4")
        let notes2 = score.notes("E3/q, F3, G3, A3")
        _ = system.addStave(SystemStave(voices: [score.voice(notes1)]))
        _ = system.addStave(SystemStave(voices: [score.voice(notes2)]))
        let conn = system.addConnector()
        #expect(conn.getType() == .double)
    }

    @Test func systemOptionsDefaults() {
        let opts = SystemOptions()
        #expect(opts.x == 10)
        #expect(opts.y == 10)
        #expect(opts.width == 500)
        #expect(opts.spaceBetweenStaves == 12)
        #expect(opts.formatIterations == 0)
    }

    // ============================================================
    // MARK: - Formatter Extensions Tests
    // ============================================================

    @Test func formatterPreCalculateMinTotalWidth() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)

        let fmt = Formatter()
        _ = fmt.joinVoices([voice])
        let width = fmt.preCalculateMinTotalWidth([voice])
        #expect(width > 0)
    }

    @Test func formatterTune() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)

        let fmt = Formatter()
        _ = fmt.joinVoices([voice])
        _ = fmt.format([voice], justifyWidth: 350)
        let cost = fmt.tune()
        #expect(cost >= 0)
    }

    // ============================================================
    // MARK: - Integration Tests
    // ============================================================

    @Test func easyScoreWithFactory() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 500)
        let score = factory.EasyScore()
        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)
        #expect(voice.getTickables().count == 4)
    }

    @Test func systemWithEasyScore() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 500)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(width: 500))

        let notes = score.notes("C4/q, D4, E4, F4")
        _ = system.addStave(SystemStave(voices: [score.voice(notes)]))
        system.format()
        #expect(system.boundingBox != nil)
        #expect(system.getStaves().count == 1)
    }

    @Test func registryWithElement() {
        let reg = Registry()
        let stave = Stave(x: 0, y: 0, width: 300)
        _ = reg.register(stave, id: "stave1")
        let found = reg.getElementById("stave1")
        #expect(found != nil)
        #expect(found?.getCategory() == "Stave")
    }

    @Test func parserWithEasyScoreGrammar() {
        let factory = Factory()
        let builder = Builder(factory: factory)
        let grammar = EasyScoreGrammar(builder: builder)
        let parser = Parser(grammar: grammar)
        let result = parser.parse("C4/q")
        #expect(result.success == true)
    }

    @Test func factoryContextPropagation() {
        let factory = Factory()
        let stave = factory.Stave(x: 0, y: 0, width: 400)
        // Without context, stave should still work
        #expect(stave.getWidth() == 400)
    }

    @Test func easyScoreChordWithAccidentals() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let notes = score.notes("(C#4 E4 G4)/q")
        #expect(notes.count == 1)
    }

    @Test func factoryMultipleNoteTypes() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let sn = factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)), duration: .quarter))
        let ghost = factory.GhostNote(duration: .quarter)
        let accid = factory.Accidental(type: .sharp)
        #expect(sn.getCategory() == "StaveNote")
        #expect(ghost.getCategory() == "GhostNote")
        #expect(accid.getCategory() == "Accidental")
    }

    @Test func systemGetVoices() {
        let factory = Factory()
        _ = factory.Stave(x: 0, y: 0, width: 400)
        let score = factory.EasyScore()
        let system = factory.System(options: SystemOptions(width: 400))
        let notes = score.notes("C4/q, D4, E4, F4")
        let voice = score.voice(notes)
        _ = system.addStave(SystemStave(voices: [voice]))
        #expect(system.getSystemVoices().count == 1)
    }
}
