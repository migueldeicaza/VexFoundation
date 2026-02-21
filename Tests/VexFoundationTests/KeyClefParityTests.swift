import Testing
@testable import VexFoundation

@Suite("Key Signature & Clef Parity")
struct KeyClefParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeFactory(width: Double = 900, height: Double = 260) -> (Factory, SVGRenderContext) {
        let factory = Factory(options: FactoryOptions(width: width, height: height))
        let context = SVGRenderContext(width: width, height: height)
        _ = factory.setContext(context)
        return (factory, context)
    }

    private func firstKeySigGlyphYShift(
        clef: ClefName,
        key: String,
        position: StaveModifierPosition = .begin,
        endClef: ClefName? = nil
    ) -> Double? {
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = stave.addClef(clef)
        if let endClef {
            _ = stave.setEndClef(endClef)
        }
        _ = stave.addKeySignature(key, position: position)

        let keySig = stave.getModifiers(position: position, category: KeySignature.category).first as? KeySignature
        keySig?.format()
        return keySig?.getGlyphs().first?.getYShift()
    }

    private func makeQuarterC4(
        _ factory: Factory,
        clef: ClefName,
        octaveShift: Int? = nil
    ) -> StaveNote {
        factory.StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)),
            duration: .quarter,
            octaveShift: octaveShift,
            clef: clef
        ))
    }

    @Test func keySignatureParserParity() {
        let invalidSpecs = ["asdf", "D!", "E#", "D#", "#", "b", "Kb", "Fb", "Dbm", "B#m"]
        for spec in invalidSpecs {
            do {
                _ = try Tables.keySignature(spec)
                #expect(Bool(false))
            } catch {
                #expect(Bool(true))
            }
        }

        let validSpecs = ["B", "C", "Fm", "Ab", "Abm", "F#", "G#m"]
        for spec in validSpecs {
            #expect((try? Tables.keySignature(spec)) != nil)
        }
    }

    @Test func keySignatureMajorMinorGlyphCountParity() {
        let majorKeys = ["C", "F", "Bb", "Eb", "Ab", "Db", "Gb", "Cb", "G", "D", "A", "E", "B", "F#", "C#"]
        let minorKeys = ["Am", "Dm", "Gm", "Cm", "Fm", "Bbm", "Ebm", "Abm", "Em", "Bm", "F#m", "C#m", "G#m", "D#m", "A#m"]

        let stave = Stave(x: 10, y: 40, width: 320)
        _ = stave.addClef(.treble)

        for key in majorKeys + minorKeys {
            let ks = KeySignature(keySpec: key)
            _ = ks.setStave(stave)
            ks.format()

            let expected = Tables.keySignatures[key]?.num ?? 0
            #expect(ks.getGlyphs().count == expected)
        }
    }

    @Test func keySignaturePlacementDependsOnClef() {
        let trebleY = firstKeySigGlyphYShift(clef: .treble, key: "G")
        let bassY = firstKeySigGlyphYShift(clef: .bass, key: "G")

        #expect(trebleY != nil)
        #expect(bassY != nil)
        #expect(trebleY != bassY)
    }

    @Test func endKeySignatureUsesEndClefContext() {
        let trebleEndY = firstKeySigGlyphYShift(clef: .treble, key: "G", position: .end, endClef: .treble)
        let bassEndY = firstKeySigGlyphYShift(clef: .treble, key: "G", position: .end, endClef: .bass)

        #expect(trebleEndY != nil)
        #expect(bassEndY != nil)
        #expect(trebleEndY != bassEndY)
    }

    @Test func keySignatureCancelAlterAndEndKeyDrawParity() throws {
        let (factory, context) = makeFactory(width: 520, height: 220)

        let top = factory.Stave(x: 10, y: 20, width: 460)
        _ = top.setKeySignature("G")
            .setClef(.treble)
            .addTimeSignature(.meter(4, 4))
            .setEndClef(.bass)
            .setEndKeySignature("Cb")

        let bottom = factory.Stave(x: 10, y: 110, width: 460)
        _ = bottom.setKeySignature("Cb")
            .setClef(.bass)
            .setEndClef(.treble)
            .setEndKeySignature("G")

        let altered = KeySignature(keySpec: "D", cancelKeySpec: "Bb", alterKeySpec: ["b", "n"])
        _ = altered.setStave(top)
        altered.format()
        #expect(altered.getGlyphs().count == 4)

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func clefDrawVariantsParity_defaultAndSmall() throws {
        let (factory, context) = makeFactory(width: 1200, height: 220)
        let stave = factory.Stave(x: 10, y: 40, width: 1160)

        _ = stave
            .addClef(.treble)
            .addClef(.treble, size: .default, annotation: .octaveUp)
            .addClef(.treble, size: .default, annotation: .octaveDown)
            .addClef(.alto)
            .addClef(.tenor)
            .addClef(.soprano)
            .addClef(.bass)
            .addClef(.bass, size: .default, annotation: .octaveDown)
            .addClef(.mezzoSoprano)
            .addClef(.baritoneC)
            .addClef(.baritoneF)
            .addClef(.subbass)
            .addClef(.percussion)
            .addClef(.french)
            .addEndClef(.treble, size: .small)
            .addEndClef(.treble, size: .small, annotation: .octaveUp)
            .addEndClef(.treble, size: .small, annotation: .octaveDown)
            .addEndClef(.alto, size: .small)
            .addEndClef(.tenor, size: .small)
            .addEndClef(.soprano, size: .small)
            .addEndClef(.bass, size: .small)
            .addEndClef(.bass, size: .small, annotation: .octaveDown)
            .addEndClef(.mezzoSoprano, size: .small)
            .addEndClef(.baritoneC, size: .small)
            .addEndClef(.baritoneF, size: .small)
            .addEndClef(.subbass, size: .small)
            .addEndClef(.percussion, size: .small)
            .addEndClef(.french, size: .small)

        #expect(stave.getModifiers(position: .begin, category: Clef.category).count == 14)
        #expect(stave.getModifiers(position: .end, category: Clef.category).count == 14)

        let smallTreble = Clef(type: .treble, size: .small, annotation: .octaveUp)
        let defaultTreble = Clef(type: .treble, size: .default, annotation: .octaveUp)
        #expect(Clef.getPoint(.small) < Clef.getPoint(.default))
        #expect(smallTreble.annotation != nil)
        #expect(defaultTreble.annotation != nil)

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func clefChangeInlineParity_draw() throws {
        let (factory, context) = makeFactory(width: 820, height: 200)
        let stave = factory.Stave(x: 10, y: 20, width: 780).addClef(.treble)

        var tickables: [Tickable] = []
        tickables.append(makeQuarterC4(factory, clef: .treble))
        tickables.append(factory.ClefNote(type: .alto, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .alto))
        tickables.append(factory.ClefNote(type: .tenor, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .tenor))
        tickables.append(factory.ClefNote(type: .soprano, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .soprano))
        tickables.append(factory.ClefNote(type: .bass, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .bass))
        tickables.append(factory.ClefNote(type: .mezzoSoprano, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .mezzoSoprano))
        tickables.append(factory.ClefNote(type: .baritoneC, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .baritoneC))
        tickables.append(factory.ClefNote(type: .baritoneF, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .baritoneF))
        tickables.append(factory.ClefNote(type: .subbass, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .subbass))
        tickables.append(factory.ClefNote(type: .french, size: .small))
        tickables.append(makeQuarterC4(factory, clef: .french))
        tickables.append(factory.ClefNote(type: .treble, size: .small, annotation: .octaveDown))
        tickables.append(makeQuarterC4(factory, clef: .treble, octaveShift: -1))
        tickables.append(factory.ClefNote(type: .treble, size: .small, annotation: .octaveUp))
        tickables.append(makeQuarterC4(factory, clef: .treble, octaveShift: 1))

        let voice = factory.Voice(timeSignature: .meter(12, 4))
        _ = voice.addTickables(tickables)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        try factory.draw()

        #expect(tickables.filter { $0.getCategory() == ClefNote.category }.count == 11)
        #expect(context.getSVG().contains("<svg"))
    }
}
