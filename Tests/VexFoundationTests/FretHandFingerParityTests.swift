import Testing
@testable import VexFoundation

@Suite("FretHandFinger Parity")
struct FretHandFingerParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeFactory(width: Double = 760, height: Double = 240) -> (Factory, SVGRenderContext) {
        let factory = Factory(options: FactoryOptions(width: width, height: height))
        let context = SVGRenderContext(width: width, height: height)
        _ = factory.setContext(context)
        return (factory, context)
    }

    private func makeStandaloneNote(
        keys: NonEmptyArray<StaffKeySpec> = NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)),
        duration: NoteDurationSpec = .quarter
    ) -> StaveNote {
        let note = StaveNote(StaveNoteStruct(keys: keys, duration: duration))
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = note.setStave(stave)
        _ = note.setStemDirection(Stem.UP)
        _ = note.buildStem()
        return note
    }

    @Test func fretHandFingerBasicMutatorsAndFormat() {
        #expect(FretHandFinger.category == "FretHandFinger")

        let finger = FretHandFinger("1")
        #expect(finger.getFretHandFinger() == "1")
        #expect(finger.position == .left)
        #expect(finger.getWidth() == 7)

        _ = finger.setFretHandFinger("3")
        _ = finger.setOffsetX(5)
        _ = finger.setOffsetY(10)
        #expect(finger.getFretHandFinger() == "3")
        #expect(finger.xOffset == 5)
        #expect(finger.yOffset == 10)

        let note = makeStandaloneNote()
        _ = note.addModifier(finger, index: 0)
        var state = ModifierContextState()
        #expect(FretHandFinger.format([finger], state: &state))

        var emptyState = ModifierContextState()
        #expect(!FretHandFinger.format([], state: &emptyState))
    }

    @Test func fretHandFingerInNotation_draw() throws {
        let (factory, context) = makeFactory()
        let score = factory.EasyScore()

        let stave1 = factory.Stave(x: 10, y: 30, width: 350).addClef(.treble)
        let notes1 = score.notes("(c4 e4 g4)/4, (c5 e5 g5), (c4 f4 g4), (c4 f4 g4)", options: ["stem": "down"])

        _ = notes1[0].addModifier(factory.Fingering(number: "3", position: .left), index: 0)
        _ = notes1[0].addModifier(factory.Fingering(number: "2", position: .left), index: 1)
        _ = notes1[0].addModifier(factory.Fingering(number: "0", position: .left), index: 2)

        _ = notes1[1].addModifier(factory.Accidental(type: .sharp), index: 0)
        _ = notes1[1].addModifier(factory.Fingering(number: "3", position: .left), index: 0)
        _ = notes1[1].addModifier(factory.Fingering(number: "2", position: .left), index: 1)
        _ = notes1[1].addModifier(factory.Accidental(type: .sharp), index: 1)
        _ = notes1[1].addModifier(factory.Fingering(number: "0", position: .left), index: 2)

        _ = notes1[2].addModifier(factory.Fingering(number: "3", position: .below), index: 0)
        _ = notes1[2].addModifier(factory.Fingering(number: "4", position: .left), index: 1)
        _ = notes1[2].addModifier(factory.StringNumber(number: "4", position: .left), index: 1)
        _ = notes1[2].addModifier(factory.Fingering(number: "0", position: .above), index: 2)
        _ = notes1[2].addModifier(factory.Accidental(type: .sharp), index: 1)

        _ = notes1[3].addModifier(factory.Fingering(number: "3", position: .right), index: 0)
        _ = notes1[3].addModifier(factory.StringNumber(number: "5", position: .right).setOffsetY(7), index: 0)
        _ = notes1[3].addModifier(factory.Fingering(number: "4", position: .right), index: 1)
        _ = notes1[3].addModifier(factory.StringNumber(number: "4", position: .right).setOffsetY(6), index: 1)
        _ = notes1[3].addModifier(factory.Fingering(number: "0", position: .right).setOffsetY(-5), index: 2)
        _ = notes1[3].addModifier(factory.StringNumber(number: "3", position: .right).setOffsetY(-6), index: 2)

        let voice1 = score.voice(notes1)
        _ = Formatter().joinVoices([voice1]).formatToStave([voice1], stave: stave1)

        let stave2 = factory.Stave(x: stave1.getWidth() + stave1.getX(), y: stave1.getY(), width: 350)
        let notes2 = score.notes("(c4 e4 g4)/4., (c5 e5 g5)/8, (c4 f4 g4)/8, (c4 f4 g4)/4", options: ["stem": "up"])

        _ = notes2[0].addModifier(factory.Fingering(number: "3", position: .right), index: 0)
        _ = notes2[0].addModifier(factory.Fingering(number: "2", position: .left), index: 1)
        _ = notes2[0].addModifier(factory.StringNumber(number: "4", position: .right), index: 1)
        _ = notes2[0].addModifier(factory.Fingering(number: "0", position: .above), index: 2)

        _ = notes2[1].addModifier(factory.Accidental(type: .sharp), index: 0)
        _ = notes2[1].addModifier(factory.Fingering(number: "3", position: .right), index: 0)
        _ = notes2[1].addModifier(factory.Fingering(number: "2", position: .left), index: 1)
        _ = notes2[1].addModifier(factory.Accidental(type: .sharp), index: 1)
        _ = notes2[1].addModifier(factory.Fingering(number: "0", position: .left), index: 2)

        _ = notes2[2].addModifier(factory.Fingering(number: "3", position: .below), index: 0)
        _ = notes2[2].addModifier(factory.Fingering(number: "2", position: .left), index: 1)
        _ = notes2[2].addModifier(factory.StringNumber(number: "4", position: .left), index: 1)
        _ = notes2[2].addModifier(factory.Fingering(number: "1", position: .right), index: 2)
        _ = notes2[2].addModifier(factory.Accidental(type: .sharp), index: 2)

        _ = notes2[3].addModifier(factory.Fingering(number: "3", position: .right), index: 0)
        _ = notes2[3].addModifier(factory.StringNumber(number: "5", position: .right).setOffsetY(7), index: 0)
        _ = notes2[3].addModifier(factory.Fingering(number: "4", position: .right), index: 1)
        _ = notes2[3].addModifier(factory.StringNumber(number: "4", position: .right).setOffsetY(6), index: 1)
        _ = notes2[3].addModifier(factory.Fingering(number: "1", position: .right).setOffsetY(-6), index: 2)
        _ = notes2[3].addModifier(factory.StringNumber(number: "3", position: .right).setOffsetY(-6), index: 2)

        let voice2 = score.voice(notes2)
        _ = Formatter().joinVoices([voice2]).formatToStave([voice2], stave: stave2)
        try factory.draw()

        let fingerCount1 = notes1.reduce(0) { $0 + $1.getModifiersByType(FretHandFinger.category).count }
        let fingerCount2 = notes2.reduce(0) { $0 + $1.getModifiersByType(FretHandFinger.category).count }
        #expect(fingerCount1 == 12)
        #expect(fingerCount2 == 12)
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func fretHandFingerMultiVoiceWithStrokesAndStringNumbers_draw() throws {
        let (factory, context) = makeFactory(width: 720, height: 220)
        let score = factory.EasyScore()
        let stave = factory.Stave(x: 10, y: 30, width: 680)

        let notes1 = score.notes("(c4 e4 g4)/4, (a3 e4 g4), (c4 d4 a4), (c4 d4 a4)", options: ["stem": "up"])

        _ = notes1[0].addModifier(Stroke(type: .rasquedoDown), index: 0)
        _ = notes1[0].addModifier(factory.Fingering(number: "3", position: .left), index: 0)
        _ = notes1[0].addModifier(factory.Fingering(number: "2", position: .left), index: 1)
        _ = notes1[0].addModifier(factory.Fingering(number: "0", position: .left), index: 2)
        _ = notes1[0].addModifier(factory.StringNumber(number: "4", position: .left), index: 1)
        _ = notes1[0].addModifier(factory.StringNumber(number: "3", position: .above), index: 2)

        _ = notes1[1].addModifier(Stroke(type: .rasquedoUp), index: 0)
        _ = notes1[1].addModifier(factory.StringNumber(number: "4", position: .right), index: 1)
        _ = notes1[1].addModifier(factory.StringNumber(number: "3", position: .above), index: 2)
        _ = notes1[1].addModifier(factory.Accidental(type: .sharp), index: 0)
        _ = notes1[1].addModifier(factory.Accidental(type: .sharp), index: 1)
        _ = notes1[1].addModifier(factory.Accidental(type: .sharp), index: 2)

        _ = notes1[2].addModifier(Stroke(type: .brushUp), index: 0)
        _ = notes1[2].addModifier(factory.Fingering(number: "3", position: .left), index: 0)
        _ = notes1[2].addModifier(factory.Fingering(number: "0", position: .right), index: 1)
        _ = notes1[2].addModifier(factory.StringNumber(number: "4", position: .right), index: 1)
        _ = notes1[2].addModifier(factory.Fingering(number: "1", position: .left), index: 2)
        _ = notes1[2].addModifier(factory.StringNumber(number: "3", position: .right), index: 2)

        _ = notes1[3].addModifier(Stroke(type: .brushDown), index: 0)
        _ = notes1[3].addModifier(factory.StringNumber(number: "3", position: .left), index: 2)
        _ = notes1[3].addModifier(factory.StringNumber(number: "4", position: .right), index: 1)

        let notes2 = score.notes("e3/8, e3, e3, e3, e3, e3, e3, e3", options: ["stem": "down"])
        _ = notes2[0].addModifier(factory.Fingering(number: "0", position: .left), index: 0)
        _ = notes2[0].addModifier(factory.StringNumber(number: "6", position: .below), index: 0)
        _ = notes2[2].addModifier(factory.Accidental(type: .sharp), index: 0)
        _ = notes2[4].addModifier(factory.Fingering(number: "0", position: .left), index: 0)
        _ = notes2[4].addModifier(factory.StringNumber(number: "6", position: .left).setOffsetX(15).setOffsetY(18), index: 0)

        let voices = [score.voice(notes2), score.voice(notes1)]
        _ = Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
        try factory.draw()

        let fingerCount = notes1.reduce(0) { $0 + $1.getModifiersByType(FretHandFinger.category).count } +
            notes2.reduce(0) { $0 + $1.getModifiersByType(FretHandFinger.category).count }
        let stringCount = notes1.reduce(0) { $0 + $1.getModifiersByType(StringNumber.category).count } +
            notes2.reduce(0) { $0 + $1.getModifiersByType(StringNumber.category).count }
        let strokeCount = notes1.reduce(0) { $0 + $1.getModifiersByType(Stroke.category).count }

        #expect(fingerCount == 8)
        #expect(stringCount == 10)
        #expect(strokeCount == 4)
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func fretHandFingerModifierContextAndTypeRelationship() {
        let finger = FretHandFinger("1")
        let note = makeStandaloneNote()
        _ = note.addModifier(finger, index: 0)
        let mc = ModifierContext()
        _ = mc.addMember(finger)
        mc.preFormat()
        #expect(finger.getCategory() == FretHandFinger.category)
    }
}
