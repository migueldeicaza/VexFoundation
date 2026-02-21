import Testing
@testable import VexFoundation

@Suite("Time Signature Parity")
struct TimeSignatureParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func makeFactory(width: Double = 920, height: Double = 260) -> (Factory, SVGRenderContext) {
        let factory = Factory(options: FactoryOptions(width: width, height: height))
        let context = SVGRenderContext(width: width, height: height)
        _ = factory.setContext(context)
        return (factory, context)
    }

    private func digits(_ raw: String) -> TimeSignatureDigits {
        TimeSignatureDigits(rawValue: raw)!
    }

    private func numeric(_ top: String, _ bottom: String) -> TimeSignatureSpec {
        .numeric(top: digits(top), bottom: digits(bottom))
    }

    private func topOnly(_ token: String) -> TimeSignatureSpec {
        .topOnly(digits(token))
    }

    private func makeQuarterNote(
        _ factory: Factory,
        letter: NoteLetter,
        octave: Int,
        clef: ClefName,
        type: NoteType = .note
    ) -> StaveNote {
        factory.StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: letter, octave: octave)),
            duration: NoteDurationSpec(uncheckedValue: .quarter, type: type),
            clef: clef
        ))
    }

    @Test func parserParity() {
        let timeSig = TimeSignature()
        #expect(timeSig.getTimeSpec() == .default)
        #expect(timeSig.getTimeSpecString() == "4/4")

        let mustFail = ["asdf", "123/", "/10", "/", "4567", "C+", "1+", "+1", "(3+", "+3)", "()", "(+)"]
        for invalid in mustFail {
            #expect(TimeSignatureSpec(parsing: invalid, validate: true) == nil)
        }

        let mustPass = ["4/4", "10/12", "1/8", "1234567890/1234567890", "C", "C|", "+", "-"]
        for valid in mustPass {
            #expect(TimeSignatureSpec(parsing: valid, validate: true) != nil)
        }

        _ = timeSig.setTimeSig(.meter(4, 4))
        #expect(timeSig.getIsNumeric() == true)
        #expect(timeSig.getLine() == 0)

        _ = timeSig.setTimeSig(.cutTime)
        #expect(timeSig.getTimeSpec() == .cutTime)
        #expect(timeSig.getIsNumeric() == false)
        #expect(timeSig.getLine() == 2)
    }

    @Test func basicTimeSignaturesDrawParity() throws {
        let (factory, context) = makeFactory(width: 980, height: 180)
        let stave = factory.Stave(x: 10, y: 20, width: 940)
            .addTimeSignature(.meter(2, 2))
            .addTimeSignature(.meter(3, 4))
            .addTimeSignature(.meter(4, 4))
            .addTimeSignature(.meter(6, 8))
            .addTimeSignature(.commonTime)
            .addTimeSignature(.cutTime)
            .addTimeSignature(.meter(2, 2), position: .end)
            .addTimeSignature(.meter(3, 4), position: .end)
            .addTimeSignature(.meter(4, 4), position: .end)
            .addEndClef(.treble)
            .addTimeSignature(.meter(6, 8), position: .end)
            .addTimeSignature(.commonTime, position: .end)
            .addTimeSignature(.cutTime, position: .end)

        #expect(stave.getModifiers(position: .begin, category: TimeSignature.category).count == 6)
        #expect(stave.getModifiers(position: .end, category: TimeSignature.category).count == 6)

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func bigSignaturesDrawParity() throws {
        let (factory, context) = makeFactory(width: 620, height: 160)
        _ = factory.Stave(x: 10, y: 20, width: 580)
            .addTimeSignature(numeric("12", "8"))
            .addTimeSignature(numeric("7", "16"))
            .addTimeSignature(numeric("1234567", "890"))
            .addTimeSignature(numeric("987", "654321"))

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func additiveSignatureDrawParity() throws {
        let (factory, context) = makeFactory(width: 440, height: 160)
        _ = factory.Stave(x: 10, y: 20, width: 400)
            .addTimeSignature(numeric("2+3+2", "8"))

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func alternatingSignatureDrawParity() throws {
        let (factory, context) = makeFactory(width: 460, height: 160)
        _ = factory.Stave(x: 10, y: 20, width: 420)
            .addTimeSignature(.meter(6, 8))
            .addTimeSignature(topOnly("+"))
            .addTimeSignature(.meter(3, 4))

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func interchangeableAndAggregateAndComplexDrawParity() throws {
        let (factory, context) = makeFactory(width: 980, height: 220)

        _ = factory.Stave(x: 10, y: 20, width: 300)
            .addTimeSignature(.meter(3, 4))
            .addTimeSignature(topOnly("-"))
            .addTimeSignature(.meter(2, 4))

        _ = factory.Stave(x: 320, y: 20, width: 320)
            .addTimeSignature(.meter(2, 4))
            .addTimeSignature(topOnly("+"))
            .addTimeSignature(.meter(3, 8))
            .addTimeSignature(topOnly("+"))
            .addTimeSignature(.meter(5, 4))

        _ = factory.Stave(x: 650, y: 20, width: 320)
            .addTimeSignature(numeric("(2+3)", "16"))
            .addTimeSignature(topOnly("+"))
            .addTimeSignature(.meter(3, 8))

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func multipleStavesAlignmentParity() throws {
        let (factory, context) = makeFactory(width: 420, height: 380)
        let percussionConfig = [false, false, true, false, false].map { StaveLineConfig(visible: $0) }

        let stave1 = factory.Stave(x: 15, y: 0, width: 300)
            .setConfigForLines(percussionConfig)
            .addClef(.percussion)
            .addTimeSignature(.meter(4, 4), customPadding: 25)
        let stave2 = factory.Stave(x: 15, y: 110, width: 300)
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))
        let stave3 = factory.Stave(x: 15, y: 220, width: 300)
            .addClef(.bass)
            .addTimeSignature(.meter(4, 4))

        Stave.formatBegModifiers([stave1, stave2, stave3])
        _ = factory.StaveConnector(topStave: stave1, bottomStave: stave2, type: .singleLeft)
        _ = factory.StaveConnector(topStave: stave2, bottomStave: stave3, type: .singleLeft)
        _ = factory.StaveConnector(topStave: stave2, bottomStave: stave3, type: .brace)

        let x1 = stave1.getNoteStartX()
        let x2 = stave2.getNoteStartX()
        let x3 = stave3.getNoteStartX()
        #expect(abs(x1 - x2) < 0.001)
        #expect(abs(x2 - x3) < 0.001)

        try factory.draw()
        #expect(context.getSVG().contains("<svg"))
    }

    @Test func timeSignatureChangeInlineParityDraw() throws {
        let (factory, context) = makeFactory(width: 920, height: 220)
        let stave = factory.Stave(x: 10, y: 20, width: 880)
            .addClef(.treble)
            .addTimeSignature(.cutTime)

        let tickables: [Tickable] = [
            makeQuarterNote(factory, letter: .c, octave: 4, clef: .treble),
            factory.TimeSigNote(time: .meter(3, 4)),
            makeQuarterNote(factory, letter: .d, octave: 4, clef: .alto),
            makeQuarterNote(factory, letter: .b, octave: 3, clef: .alto, type: .rest),
            factory.TimeSigNote(time: .commonTime),
            factory.StaveNote(StaveNoteStruct(
                keys: NonEmptyArray(
                    StaffKeySpec(letter: .c, octave: 3),
                    StaffKeySpec(letter: .e, octave: 3),
                    StaffKeySpec(letter: .g, octave: 3)
                ),
                duration: .quarter,
                clef: .bass
            )),
            factory.TimeSigNote(time: .meter(9, 8)),
            makeQuarterNote(factory, letter: .c, octave: 4, clef: .treble),
        ]

        let voice = factory.Voice().setStrict(false)
        _ = voice.addTickables(tickables)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

        try factory.draw()
        #expect(tickables.filter { $0.getCategory() == TimeSigNote.category }.count == 3)
        #expect(context.getSVG().contains("<svg"))
    }
}
