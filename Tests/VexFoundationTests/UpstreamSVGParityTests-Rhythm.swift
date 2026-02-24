import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Rhythm.Rhythm_Draw___slash_notes")
    func rhythmDrawSlashNotesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Rhythm", test: "Rhythm_Draw___slash_notes", width: 800, height: 150) { _, context in
            let staveBar1 = Stave(x: 10, y: 30, width: 150)
            _ = staveBar1
                .setBegBarType(.double)
                .setEndBarType(.single)
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("C")
                .setContext(context)
            try staveBar1.draw()

            let notesBar1: [StaveNote] = [try makeRhythmStaveNote(duration: "1s", stemDirection: .down)]
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: notesBar1)

            let staveBar2 = Stave(
                x: staveBar1.getWidth() + staveBar1.getX(),
                y: staveBar1.getY(),
                width: 120
            )
            _ = staveBar2
                .setBegBarType(.single)
                .setEndBarType(.single)
                .setContext(context)
            try staveBar2.draw()

            let notesBar2: [StaveNote] = [
                try makeRhythmStaveNote(duration: "2s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "2s", stemDirection: .down),
            ]
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar2, notes: notesBar2)

            let staveBar3 = Stave(
                x: staveBar2.getWidth() + staveBar2.getX(),
                y: staveBar2.getY(),
                width: 170
            )
            _ = staveBar3.setContext(context)
            try staveBar3.draw()

            let notesBar3: [StaveNote] = try (0..<4).map { _ in
                try makeRhythmStaveNote(duration: "4s", stemDirection: .down)
            }
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar3, notes: notesBar3)

            let staveBar4 = Stave(
                x: staveBar3.getWidth() + staveBar3.getX(),
                y: staveBar3.getY(),
                width: 200
            )
            _ = staveBar4.setContext(context)
            try staveBar4.draw()

            let notesBar4: [StaveNote] = try (0..<8).map { _ in
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down)
            }
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar4, notes: notesBar4)
        }
    }

    @Test("Rhythm.Rhythm_Draw___beamed_slash_notes")
    func rhythmDrawBeamedSlashNotesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Rhythm", test: "Rhythm_Draw___beamed_slash_notes", width: 800, height: 150) { _, context in
            let staveBar1 = Stave(x: 10, y: 30, width: 300)
            _ = staveBar1
                .setBegBarType(.double)
                .setEndBarType(.single)
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("C")
                .setContext(context)
            try staveBar1.draw()

            let notesBar1Part1: [StaveNote] = try (0..<4).map { _ in
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down)
            }
            let notesBar1Part2: [StaveNote] = try (0..<4).map { _ in
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down)
            }
            let beam1 = try Beam(notesBar1Part1.map { $0 as StemmableNote })
            let beam2 = try Beam(notesBar1Part2.map { $0 as StemmableNote })
            let notesBar1 = notesBar1Part1 + notesBar1Part2

            try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: notesBar1)
            _ = beam1.setContext(context)
            try beam1.draw()
            _ = beam2.setContext(context)
            try beam2.draw()
        }
    }

    @Test("Rhythm.Rhythm_Draw___beamed_slash_notes__some_rests")
    func rhythmDrawBeamedSlashNotesSomeRestsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rhythm",
            test: "Rhythm_Draw___beamed_slash_notes__some_rests",
            width: 800,
            height: 150
        ) { _, context in
            let staveBar1 = Stave(x: 10, y: 30, width: 300)
            _ = staveBar1
                .setBegBarType(.double)
                .setEndBarType(.single)
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("F")
                .setContext(context)
            try staveBar1.draw()

            let notesBar1Part1: [StaveNote] = [
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down),
            ]
            _ = notesBar1Part1[0].addModifier(makeRhythmAnnotation("C7", sizeOffset: 2), index: 0)

            let notesBar1Part2: [StaveNote] = [
                try makeRhythmStaveNote(duration: "8r", stemDirection: .down),
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "8r", stemDirection: .down),
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "8r", stemDirection: .down),
                try makeRhythmStaveNote(duration: "8s", stemDirection: .down),
            ]

            let beam1 = try Beam(notesBar1Part1.map { $0 as StemmableNote })
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: notesBar1Part1 + notesBar1Part2)
            _ = beam1.setContext(context)
            try beam1.draw()

            let staveBar2 = Stave(
                x: staveBar1.getWidth() + staveBar1.getX(),
                y: staveBar1.getY(),
                width: 220
            )
            _ = staveBar2.setContext(context)
            try staveBar2.draw()

            let notesBar2 = [try makeRhythmStaveNote(duration: "1s", stemDirection: .down)]
            _ = notesBar2[0].addModifier(makeRhythmAnnotation("F", sizeOffset: 2), index: 0)
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar2, notes: notesBar2)
        }
    }

    @Test("Rhythm.Rhythm_Draw___16th_note_rhythm_with_scratches")
    func rhythmDraw16thWithScratchesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rhythm",
            test: "Rhythm_Draw___16th_note_rhythm_with_scratches",
            width: 800,
            height: 150
        ) { _, context in
            let staveBar1 = Stave(x: 10, y: 30, width: 300)
            _ = staveBar1
                .setBegBarType(.double)
                .setEndBarType(.single)
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("F")
                .setContext(context)
            try staveBar1.draw()

            let notesBar1Part1: [StaveNote] = [
                try makeRhythmStaveNote(duration: "16s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "16s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "16m", stemDirection: .down),
                try makeRhythmStaveNote(duration: "16s", stemDirection: .down),
            ]
            let notesBar1Part2: [StaveNote] = [
                try makeRhythmStaveNote(duration: "16m", stemDirection: .down),
                try makeRhythmStaveNote(duration: "16s", stemDirection: .down),
                try makeRhythmStaveNote(duration: "16r", stemDirection: .down),
                try makeRhythmStaveNote(duration: "16s", stemDirection: .down),
            ]
            _ = notesBar1Part1[0].addModifier(makeRhythmAnnotation("C7", sizeOffset: 3), index: 0)

            let beam1 = try Beam(notesBar1Part1.map { $0 as StemmableNote })
            let beam2 = try Beam(notesBar1Part2.map { $0 as StemmableNote })

            try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: notesBar1Part1 + notesBar1Part2)
            _ = beam1.setContext(context)
            try beam1.draw()
            _ = beam2.setContext(context)
            try beam2.draw()
        }
    }

    @Test("Rhythm.Rhythm_Draw___32nd_note_rhythm_with_scratches")
    func rhythmDraw32ndWithScratchesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Rhythm",
            test: "Rhythm_Draw___32nd_note_rhythm_with_scratches",
            width: 800,
            height: 150
        ) { _, context in
            let staveBar1 = Stave(x: 10, y: 30, width: 300)
            _ = staveBar1
                .setBegBarType(.double)
                .setEndBarType(.single)
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))
                .addKeySignature("F")
                .setContext(context)
            try staveBar1.draw()

            let notesBar1Part1: [StaveNote] = [
                try makeRhythmStaveNote(duration: "32s", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32s", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32m", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32s", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32m", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32s", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32r", stemDirection: .up),
                try makeRhythmStaveNote(duration: "32s", stemDirection: .up),
            ]
            _ = notesBar1Part1[0].addModifier(makeRhythmAnnotation("C7", sizeOffset: 3), index: 0)

            let beam1 = try Beam(notesBar1Part1.map { $0 as StemmableNote })
            try Formatter.FormatAndDraw(ctx: context, stave: staveBar1, notes: notesBar1Part1)
            _ = beam1.setContext(context)
            try beam1.draw()
        }
    }

    private func makeRhythmStaveNote(duration: String, stemDirection: StemDirection) throws -> StaveNote {
        try StaveNote(validating: StaveNoteStruct(
            parsingKeys: ["b/4"],
            duration: duration,
            stemDirection: stemDirection
        ))
    }

    private func makeRhythmAnnotation(_ text: String, sizeOffset: Double) -> Annotation {
        Annotation(text).setFont(
            FontInfo(family: "Times", size: VexFont.SIZE + sizeOffset)
        )
    }
}
