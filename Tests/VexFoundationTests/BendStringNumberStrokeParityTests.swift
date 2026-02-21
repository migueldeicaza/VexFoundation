import Testing
@testable import VexFoundation

@Suite("Bend, StringNumber, Stroke Parity")
struct BendStringNumberStrokeParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeFactory(width: Double = 600, height: Double = 240) -> (Factory, SVGRenderContext) {
        let factory = Factory(options: FactoryOptions(width: width, height: height))
        let context = SVGRenderContext(width: width, height: height)
        _ = factory.setContext(context)
        return (factory, context)
    }

    private func makeTabNote(_ factory: Factory, positions: [TabNotePosition], duration: NoteValue = .quarter) -> TabNote {
        factory.TabNote(TabNoteStruct(positions: positions, duration: duration))
    }

    private func makeStaveNote(_ factory: Factory, key: StaffKeySpec, duration: NoteDurationSpec = .quarter) -> StaveNote {
        factory.StaveNote(StaveNoteStruct(keys: NonEmptyArray(key), duration: duration))
    }

    @Test func bendCategoryDoubleBends_draw() throws {
        let (factory, context) = makeFactory(width: 500, height: 240)
        let stave = factory.TabStave(x: 10, y: 10, width: 450).addTabGlyph()

        let note1 = makeTabNote(factory, positions: [
            TabNotePosition(str: 2, fret: 10),
            TabNotePosition(str: 4, fret: 9),
        ], duration: .quarter)
        _ = note1.addModifier(Bend("Full"), index: 0)
        _ = note1.addModifier(Bend("1/2"), index: 1)

        let note2 = makeTabNote(factory, positions: [
            TabNotePosition(str: 2, fret: 5),
            TabNotePosition(str: 3, fret: 5),
        ], duration: .quarter)
        _ = note2.addModifier(Bend("1/4"), index: 0)
        _ = note2.addModifier(Bend("1/4"), index: 1)

        let note3 = makeTabNote(factory, positions: [TabNotePosition(str: 4, fret: 7)], duration: .half)
        let voice = factory.Voice()
        _ = voice.addTickables([note1, note2, note3])
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

        try factory.draw()

        #expect(note1.getModifiersByType(Bend.category).count == 2)
        #expect(note2.getModifiersByType(Bend.category).count == 2)
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func bendCategoryReverseBends_draw() throws {
        let (factory, _) = makeFactory(width: 500, height: 240)
        let stave = factory.TabStave(x: 10, y: 10, width: 450).addTabGlyph()

        let note1 = makeTabNote(factory, positions: [
            TabNotePosition(str: 2, fret: 10),
            TabNotePosition(str: 4, fret: 9),
        ], duration: .whole)
        _ = note1.addModifier(Bend("Full"), index: 1)
        _ = note1.addModifier(Bend("1/2"), index: 0)

        let voice = factory.Voice(timeSignature: .meter(4, 4))
        _ = voice.addTickables([note1])
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

        try factory.draw()

        let bends = note1.getModifiersByType(Bend.category)
        #expect(bends.count == 2)
        #expect(bends[0].getIndex() == 1)
        #expect(bends[1].getIndex() == 0)
    }

    @Test func bendCategoryBendPhraseAndRelease_draw() throws {
        let (factory, context) = makeFactory(width: 550, height: 240)
        let stave = factory.TabStave(x: 10, y: 10, width: 530).addTabGlyph()

        let phrase1 = [
            BendPhrase(type: Bend.UP, text: "Full"),
            BendPhrase(type: Bend.DOWN, text: "Monstrous"),
            BendPhrase(type: Bend.UP, text: "1/2"),
            BendPhrase(type: Bend.DOWN, text: ""),
        ]
        let phrase2 = [
            BendPhrase(type: Bend.UP, text: "Full"),
            BendPhrase(type: Bend.UP, text: "Full"),
            BendPhrase(type: Bend.DOWN, text: ""),
        ]

        let note1 = makeTabNote(factory, positions: [
            TabNotePosition(str: 1, fret: 10),
            TabNotePosition(str: 4, fret: 9),
        ], duration: .quarter)
        _ = note1.addModifier(Bend("1/2", release: true), index: 0)
        _ = note1.addModifier(Bend("Full", release: true), index: 1)

        let note2 = makeTabNote(factory, positions: [
            TabNotePosition(str: 2, fret: 5),
            TabNotePosition(str: 3, fret: 5),
        ], duration: .quarter)
        _ = note2.addModifier(Bend("", phrase: phrase1), index: 0)
        _ = note2.addModifier(Bend("", phrase: phrase2), index: 1)

        let note3 = makeTabNote(factory, positions: [TabNotePosition(str: 4, fret: 7)], duration: .half)
        let voice = factory.Voice()
        _ = voice.addTickables([note1, note2, note3])
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

        try factory.draw()

        #expect(note2.getModifiersByType(Bend.category).count == 2)
        #expect(context.getSVG().contains("path"))
    }

    @Test func stringNumberCategoryInNotation_drawCircleToggle() throws {
        let (factory, _) = makeFactory(width: 700, height: 220)
        _ = factory.Stave(x: 10, y: 30, width: 650).addClef(.treble)

        let n0 = makeStaveNote(factory, key: StaffKeySpec(letter: .c, octave: 4))
        let n1 = makeStaveNote(factory, key: StaffKeySpec(letter: .d, octave: 4))
        let n2 = makeStaveNote(factory, key: StaffKeySpec(letter: .e, octave: 4))
        let n3 = makeStaveNote(factory, key: StaffKeySpec(letter: .f, octave: 4))

        let a = factory.StringNumber(number: "5", position: .right, drawCircle: true)
        let b = factory.StringNumber(number: "4", position: .left, drawCircle: false)
        let c = factory.StringNumber(number: "3", position: .right, drawCircle: true)
        let linked = factory.StringNumber(number: "3", position: .above, drawCircle: true)
            .setLastNote(n3)
            .setLineEndType(.down)
        let d = factory.StringNumber(number: "5", position: .left, drawCircle: false)

        _ = n0.addModifier(a, index: 0)
        _ = n0.addModifier(b, index: 0)
        _ = n0.addModifier(c, index: 0)
        _ = n1.addModifier(linked, index: 0)
        _ = n2.addModifier(d, index: 0)

        var state = ModifierContextState()
        #expect(StringNumber.format([a, b, c, linked, d], state: &state))
        #expect(state.leftShift > 0 || state.rightShift > 0)
        #expect(!b.drawCircle)
        #expect(!d.drawCircle)
    }

    @Test func stringNumberCategoryMultiVoiceWithStrokes_draw() throws {
        let (factory, _) = makeFactory(width: 700, height: 220)
        _ = factory.Stave(x: 10, y: 30, width: 650).addClef(.treble)

        let upperA = makeStaveNote(factory, key: StaffKeySpec(letter: .c, octave: 4))
        let upperB = makeStaveNote(factory, key: StaffKeySpec(letter: .d, octave: 4))
        let upperC = makeStaveNote(factory, key: StaffKeySpec(letter: .e, octave: 4))
        let upperD = makeStaveNote(factory, key: StaffKeySpec(letter: .f, octave: 4))

        let strokeA = Stroke(type: .rasquedoDown)
        let strokeB = Stroke(type: .rasquedoUp)
        let strokeC = Stroke(type: .brushUp)
        let snA = factory.StringNumber(number: "4", position: .left)
        let snB = factory.StringNumber(number: "3", position: .left)

        _ = upperA.addModifier(strokeA, index: 0)
        _ = upperB.addModifier(strokeB, index: 0)
        _ = upperC.addModifier(strokeC, index: 0)
        _ = upperA.addModifier(snA, index: 0)
        _ = upperD.addModifier(snB, index: 0)

        var strokeState = ModifierContextState()
        #expect(Stroke.format([strokeA, strokeB, strokeC], state: &strokeState))
        var stringState = ModifierContextState()
        #expect(StringNumber.format([snA, snB], state: &stringState))

        #expect(strokeState.leftShift > 0)
        #expect(stringState.leftShift > 0 || stringState.rightShift > 0)
    }

    @Test func strokeCategoryBrushRollRasquedo_draw() throws {
        let (factory, _) = makeFactory(width: 600, height: 220)
        let stave = factory.Stave(x: 10, y: 30, width: 560)
        let score = factory.EasyScore()

        let notes = score.notes("(a3 e4 a4)/4, (c4 e4 g4), (c4 e4 g4), (c4 e4 g4)", options: ["stem": "up"])
        _ = notes[0].addModifier(Stroke(type: .brushDown), index: 0)
        _ = notes[1].addModifier(Stroke(type: .brushUp), index: 0)
        _ = notes[2].addModifier(Stroke(type: .rollDown), index: 0)
        _ = notes[3].addModifier(Stroke(type: .rollUp), index: 0)

        let voice = score.voice(notes)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        try factory.draw()

        let strokes = notes.flatMap { $0.getModifiersByType(Stroke.category) }
        #expect(strokes.count == 4)
    }

    @Test func strokeCategoryArpeggioDirectionless_draw() throws {
        let (factory, context) = makeFactory(width: 700, height: 220)
        let stave = factory.Stave(x: 100, y: 30, width: 560)
        let score = factory.EasyScore()

        let notes = score.notes("(g4 b4 d5)/4, (g4 b4 d5 g5), (g4 b4 d5 g5), (g4 b4 d5)", options: ["stem": "up"])
        for note in notes {
            _ = note.addModifier(Stroke(type: .arpeggioDirectionless), index: 0)
        }

        let voice = score.voice(notes)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        try factory.draw()

        #expect(notes.flatMap { $0.getModifiersByType(Stroke.category) }.count == 4)
        #expect(context.getSVG().contains("<path"))
    }
}
