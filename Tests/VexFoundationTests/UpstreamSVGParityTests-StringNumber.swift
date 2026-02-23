import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("StringNumber.String_Number_In_Notation")
    func stringNumberInNotationMatchesUpstream() throws {
        try runStringNumberInNotationCase(
            testName: "String_Number_In_Notation",
            drawCircle: true
        )
    }

    @Test("StringNumber.String_Number_In_Notation___no_circle")
    func stringNumberInNotationNoCircleMatchesUpstream() throws {
        try runStringNumberInNotationCase(
            testName: "String_Number_In_Notation___no_circle",
            drawCircle: false
        )
    }

    @Test("StringNumber.Fret_Hand_Finger_In_Notation")
    func fretHandFingerInNotationMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StringNumber", test: "Fret_Hand_Finger_In_Notation", width: 725, height: 200) {
            factory,
            _ in
            let score = factory.EasyScore()

            let stave1 = factory.Stave(width: 350).setEndBarType(.double).addClef(.treble)
            let notes1 = score.notes("(c4 e4 g4)/4, (c5 e5 g5), (c4 f4 g4), (c4 f4 g4)", options: ["stem": "down"])
            _ = notes1[0]
                .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 2)
            _ = notes1[1]
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 2)
            _ = notes1[2]
                .addModifier(factory.Fingering(number: "3", position: .below), index: 0)
                .addModifier(factory.Fingering(number: "4", position: .left), index: 1)
                .addModifier(factory.StringNumber(number: "4", position: .left), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .above), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
            _ = notes1[3]
                .addModifier(factory.Fingering(number: "3", position: .right), index: 0)
                .addModifier(factory.StringNumber(number: "5", position: .right).setOffsetY(7), index: 0)
                .addModifier(factory.Fingering(number: "4", position: .right), index: 1)
                .addModifier(factory.StringNumber(number: "4", position: .right).setOffsetY(6), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .right).setOffsetY(-5), index: 2)
                .addModifier(factory.StringNumber(number: "3", position: .right).setOffsetY(-6), index: 2)
            let voice1 = score.voice(notes1)
            _ = factory.Formatter().joinVoices([voice1]).formatToStave([voice1], stave: stave1)

            let stave2 = factory
                .Stave(x: stave1.getWidth() + stave1.getX(), y: stave1.getY(), width: 350)
                .setEndBarType(.end)
            let notes2 = score.notes("(c4 e4 g4)/4., (c5 e5 g5)/8, (c4 f4 g4)/8, (c4 f4 g4)/4.[stem=\"down\"]", options: [
                "stem": "up",
            ])
            _ = notes2[0]
                .addModifier(factory.Fingering(number: "3", position: .right), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.StringNumber(number: "4", position: .right), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .above), index: 2)
            _ = notes2[1]
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Fingering(number: "3", position: .right), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 2)
            _ = notes2[2]
                .addModifier(factory.Fingering(number: "3", position: .below), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.StringNumber(number: "4", position: .left), index: 1)
                .addModifier(factory.Fingering(number: "1", position: .right), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
            _ = notes2[3]
                .addModifier(factory.Fingering(number: "3", position: .right), index: 0)
                .addModifier(factory.StringNumber(number: "5", position: .right).setOffsetY(7), index: 0)
                .addModifier(factory.Fingering(number: "4", position: .right), index: 1)
                .addModifier(factory.StringNumber(number: "4", position: .right).setOffsetY(6), index: 1)
                .addModifier(factory.Fingering(number: "1", position: .right).setOffsetY(-6), index: 2)
                .addModifier(factory.StringNumber(number: "3", position: .right).setOffsetY(-6), index: 2)
            let voice2 = score.voice(notes2)
            _ = factory.Formatter().joinVoices([voice2]).formatToStave([voice2], stave: stave2)

            try factory.draw()
        }
    }

    @Test("StringNumber.Multi_Voice_With_Strokes__String___Finger_Numbers")
    func stringNumberMultiVoiceWithStrokesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StringNumber",
            test: "Multi_Voice_With_Strokes__String___Finger_Numbers",
            width: 700,
            height: 200
        ) { factory, _ in
            let score = factory.EasyScore()
            let stave = factory.Stave()

            let notes1 = score.notes("(c4 e4 g4)/4, (a3 e4 g4), (c4 d4 a4), (c4 d4 a4)", options: ["stem": "up"])
            _ = notes1[0]
                .addModifier(Stroke(type: .rasquedoDown), index: 0)
                .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 2)
                .addModifier(factory.StringNumber(number: "4", position: .left), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .above), index: 2)
            _ = notes1[1]
                .addModifier(Stroke(type: .rasquedoUp), index: 0)
                .addModifier(factory.StringNumber(number: "4", position: .right), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .above), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
            _ = notes1[2]
                .addModifier(Stroke(type: .brushUp), index: 0)
                .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
                .addModifier(factory.Fingering(number: "0", position: .right), index: 1)
                .addModifier(factory.StringNumber(number: "4", position: .right), index: 1)
                .addModifier(factory.Fingering(number: "1", position: .left), index: 2)
                .addModifier(factory.StringNumber(number: "3", position: .right), index: 2)
            _ = notes1[3]
                .addModifier(Stroke(type: .brushDown), index: 0)
                .addModifier(factory.StringNumber(number: "3", position: .left), index: 2)
                .addModifier(factory.StringNumber(number: "4", position: .right), index: 1)

            let notes2 = score.notes("e3/8, e3, e3, e3, e3, e3, e3, e3", options: ["stem": "down"])
            _ = notes2[0]
                .addModifier(factory.Fingering(number: "0", position: .left), index: 0)
                .addModifier(factory.StringNumber(number: "6", position: .below), index: 0)
            _ = notes2[2].addModifier(factory.Accidental(type: .sharp), index: 0)
            _ = notes2[4].addModifier(factory.Fingering(number: "0", position: .left), index: 0)
            _ = notes2[4].addModifier(
                factory.StringNumber(number: "6", position: .left).setOffsetX(15).setOffsetY(18),
                index: 0
            )

            let voices = [score.voice(notes2), score.voice(notes1)]
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            _ = factory.Beam(notes: Array(notes2[0..<4]))
            _ = factory.Beam(notes: Array(notes2[4..<8]))

            try factory.draw()
        }
    }

    @Test("StringNumber.Complex_Measure_With_String___Finger_Numbers")
    func stringNumberComplexMeasureWithStringAndFingerNumbersMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StringNumber",
            test: "Complex_Measure_With_String___Finger_Numbers",
            width: 750,
            height: 140
        ) { factory, context in
            let glyphScale = 39.0
            let clefWidth = Glyph.getWidth(code: "gClef", point: glyphScale)

            let notes: [StaveNote] = [
                factory.StaveNote(StaveNoteStruct(
                    keys: NonEmptyArray(
                        StaffKeySpec(letter: .c, octave: 4),
                        StaffKeySpec(letter: .e, octave: 4),
                        StaffKeySpec(letter: .g, octave: 4),
                        StaffKeySpec(letter: .c, octave: 5),
                        StaffKeySpec(letter: .e, octave: 5),
                        StaffKeySpec(letter: .g, octave: 5)
                    ),
                    duration: .quarter,
                    stemDirection: .up
                )),
                factory.StaveNote(StaveNoteStruct(
                    keys: NonEmptyArray(
                        StaffKeySpec(letter: .c, octave: 4),
                        StaffKeySpec(letter: .e, octave: 4),
                        StaffKeySpec(letter: .g, octave: 4),
                        StaffKeySpec(letter: .d, octave: 5),
                        StaffKeySpec(letter: .e, octave: 5),
                        StaffKeySpec(letter: .g, octave: 5)
                    ),
                    duration: .quarter,
                    stemDirection: .up
                )),
                factory.StaveNote(StaveNoteStruct(
                    keys: NonEmptyArray(
                        StaffKeySpec(letter: .c, octave: 4),
                        StaffKeySpec(letter: .e, octave: 4),
                        StaffKeySpec(letter: .g, octave: 4),
                        StaffKeySpec(letter: .d, octave: 5),
                        StaffKeySpec(letter: .e, octave: 5),
                        StaffKeySpec(letter: .g, octave: 5)
                    ),
                    duration: .quarter,
                    stemDirection: .down
                )),
                factory.StaveNote(StaveNoteStruct(
                    keys: NonEmptyArray(
                        StaffKeySpec(letter: .c, octave: 4),
                        StaffKeySpec(letter: .e, octave: 4),
                        StaffKeySpec(letter: .g, octave: 4),
                        StaffKeySpec(letter: .d, octave: 5),
                        StaffKeySpec(letter: .e, octave: 5),
                        StaffKeySpec(letter: .g, octave: 5)
                    ),
                    duration: .quarter,
                    stemDirection: .down
                )),
            ]

            _ = notes[0]
                .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.StringNumber(number: "2", position: .left), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
                .addModifier(factory.Fingering(number: "3", position: .left), index: 3)
                .addModifier(factory.Accidental(type: .sharp), index: 3)
                .addModifier(factory.Fingering(number: "2", position: .right), index: 4)
                .addModifier(factory.StringNumber(number: "3", position: .right), index: 4)
                .addModifier(factory.Accidental(type: .sharp), index: 4)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 5)
                .addModifier(factory.Accidental(type: .sharp), index: 5)

            _ = notes[1]
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 3)
                .addModifier(factory.Accidental(type: .sharp), index: 4)
                .addModifier(factory.Accidental(type: .sharp), index: 5)

            _ = notes[2]
                .addModifier(factory.Fingering(number: "3", position: .left), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Fingering(number: "2", position: .left), index: 1)
                .addModifier(factory.StringNumber(number: "2", position: .left), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
                .addModifier(factory.Fingering(number: "3", position: .left), index: 3)
                .addModifier(factory.Accidental(type: .sharp), index: 3)
                .addModifier(factory.Fingering(number: "2", position: .right), index: 4)
                .addModifier(factory.StringNumber(number: "3", position: .right), index: 4)
                .addModifier(factory.Accidental(type: .sharp), index: 4)
                .addModifier(factory.Fingering(number: "0", position: .left), index: 5)
                .addModifier(factory.Accidental(type: .sharp), index: 5)

            _ = notes[3]
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(factory.Accidental(type: .sharp), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 3)
                .addModifier(factory.Accidental(type: .sharp), index: 4)
                .addModifier(factory.Accidental(type: .sharp), index: 5)

            let voice = factory.Voice().addTickables(notes.map { $0 as Tickable })
            let formatter = factory.Formatter().joinVoices([voice])
            let stavePadding = clefWidth + Stave.defaultPadding + 10
            let nwidth = max(formatter.preCalculateMinTotalWidth([voice]), 490 - stavePadding)
            _ = formatter.format([voice], justifyWidth: nwidth)

            let stave = factory
                .Stave(x: 0, y: 0, width: nwidth + stavePadding)
                .setContext(context)
                .setEndBarType(.double)
                .addClef(.treble)
            try stave.draw()
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("StringNumber.Shifted_Notehead__Multiple_Modifiers")
    func stringNumberShiftedNoteheadMultipleModifiersMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StringNumber",
            test: "Shifted_Notehead__Multiple_Modifiers",
            width: 900,
            height: 150
        ) { factory, _ in
            let score = factory.EasyScore()
            _ = score.set(defaults: EasyScoreDefaults(time: .meter(6, 4)))

            let stave = factory.Stave(width: 900).setEndBarType(.end).addClef(.treble)
            let noteSpecs = [
                "A4 B4",
                "B4 C5",
                "A4 B#4",
                "B4 C#5",
                "A#4 B#4",
                "B#4 C#5",
            ]
            let notes = noteSpecs.flatMap { score.notes("(\($0))/q") }
            for note in notes {
                _ = note
                    .addModifier(factory.StringNumber(number: "2", position: .left, drawCircle: true), index: 1)
                    .addModifier(factory.StringNumber(number: "2", position: .right, drawCircle: true), index: 1)
            }

            let voice = score.voice(notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    private func runStringNumberInNotationCase(testName: String, drawCircle: Bool) throws {
        try runCategorySVGParityCase(module: "StringNumber", test: testName, width: 775, height: 200) { factory, _ in
            let score = factory.EasyScore()

            let stave1 = factory.Stave(width: 300).setEndBarType(.double).addClef(.treble)
            let notes1 = score.notes("(c4 e4 g4)/4., (c5 e5 g5)/8, (c4 f4 g4)/4, (c4 f4 g4)/4", options: ["stem": "down"])
            _ = notes1[0]
                .addModifier(factory.StringNumber(number: "5", position: .right, drawCircle: drawCircle), index: 0)
                .addModifier(factory.StringNumber(number: "4", position: .left, drawCircle: drawCircle), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .right, drawCircle: drawCircle), index: 2)
            _ = notes1[1]
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.StringNumber(number: "5", position: .below, drawCircle: drawCircle), index: 0)
                .addModifier(factory.Accidental(type: .sharp).setAsCautionary(), index: 1)
                .addModifier(
                    factory.StringNumber(number: "3", position: .above, drawCircle: drawCircle)
                        .setLastNote(notes1[3])
                        .setLineEndType(.down),
                    index: 2
                )
            _ = notes1[2]
                .addModifier(factory.StringNumber(number: "5", position: .left, drawCircle: drawCircle), index: 0)
                .addModifier(factory.StringNumber(number: "3", position: .left, drawCircle: drawCircle), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
            _ = notes1[3]
                .addModifier(factory.StringNumber(number: "5", position: .right, drawCircle: drawCircle).setOffsetY(7), index: 0)
                .addModifier(factory.StringNumber(number: "4", position: .right, drawCircle: drawCircle).setOffsetY(6), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .right, drawCircle: drawCircle).setOffsetY(-6), index: 2)
            let voice1 = score.voice(notes1)
            _ = factory.Formatter().joinVoices([voice1]).formatToStave([voice1], stave: stave1)

            let stave2 = factory
                .Stave(x: stave1.getWidth() + stave1.getX(), y: stave1.getY(), width: 300)
                .setEndBarType(.double)
            let notes2 = score.notes("(c4 e4 g4)/4, (c5 e5 g5), (c4 f4 g4), (c4 f4 g4)", options: ["stem": "up"])
            _ = notes2[0]
                .addModifier(factory.StringNumber(number: "5", position: .right, drawCircle: drawCircle), index: 0)
                .addModifier(factory.StringNumber(number: "4", position: .left, drawCircle: drawCircle), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .right, drawCircle: drawCircle), index: 2)
            _ = notes2[1]
                .addModifier(factory.Accidental(type: .sharp), index: 0)
                .addModifier(factory.StringNumber(number: "5", position: .below, drawCircle: drawCircle), index: 0)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
                .addModifier(
                    factory.StringNumber(number: "3", position: .above, drawCircle: drawCircle)
                        .setLastNote(notes2[3])
                        .setDashed(false),
                    index: 2
                )
            _ = notes2[2]
                .addModifier(factory.StringNumber(number: "3", position: .left, drawCircle: drawCircle), index: 2)
                .addModifier(factory.Accidental(type: .sharp), index: 1)
            _ = notes2[3]
                .addModifier(factory.StringNumber(number: "5", position: .right, drawCircle: drawCircle).setOffsetY(7), index: 0)
                .addModifier(factory.StringNumber(number: "4", position: .right, drawCircle: drawCircle).setOffsetY(6), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .right, drawCircle: drawCircle).setOffsetY(-6), index: 2)
            let voice2 = score.voice(notes2)
            _ = factory.Formatter().joinVoices([voice2]).formatToStave([voice2], stave: stave2)

            let stave3 = factory
                .Stave(x: stave2.getWidth() + stave2.getX(), y: stave2.getY(), width: 150)
                .setEndBarType(.end)
            let notes3 = score.notes("(c4 e4 g4 a4)/1.")
            _ = notes3[0]
                .addModifier(factory.StringNumber(number: "5", position: .below, drawCircle: drawCircle), index: 0)
                .addModifier(factory.StringNumber(number: "4", position: .right, drawCircle: drawCircle), index: 1)
                .addModifier(factory.StringNumber(number: "3", position: .left, drawCircle: drawCircle), index: 2)
                .addModifier(factory.StringNumber(number: "2", position: .above, drawCircle: drawCircle), index: 3)
            let voice3 = score.voice(notes3, time: .meter(6, 4))
            _ = factory.Formatter().joinVoices([voice3]).formatToStave([voice3], stave: stave3)

            try factory.draw()
        }
    }
}
