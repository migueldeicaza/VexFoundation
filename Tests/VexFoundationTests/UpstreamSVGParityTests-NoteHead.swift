import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("NoteHead.Basic")
    func noteHeadBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "NoteHead", test: "Basic", width: 450, height: 250) { _, context in
            applyUpstreamNoteHeadContextStyle(context)

            let stave = Stave(x: 10, y: 0, width: 250).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let formatter = Formatter()
            let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).setStrict(false)

            let noteHead1 = NoteHead(noteHeadStruct: try NoteHeadStruct(duration: "4", line: 3))
            let noteHead2 = NoteHead(noteHeadStruct: try NoteHeadStruct(duration: "1", line: 2.5))
            let noteHead3 = NoteHead(noteHeadStruct: try NoteHeadStruct(duration: "2", line: 0))

            _ = voice.addTickables([noteHead1, noteHead2, noteHead3])
            _ = formatter.joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("NoteHead.Various_Note_Heads_1")
    func noteHeadVariousNoteHeads1MatchesUpstream() throws {
        let specs: [UpstreamNoteHeadSpec] = [
            .init(keys: ["g/5/d"], duration: "1/2"),
            .init(keys: ["g/5/d"], duration: "1"),
            .init(keys: ["g/5/d"], duration: "2"),
            .init(keys: ["g/5/d"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/x"], duration: "1/2"),
            .init(keys: ["g/5/x"], duration: "1"),
            .init(keys: ["g/5/x"], duration: "2"),
            .init(keys: ["g/5/x"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/cx"], duration: "1/2"),
            .init(keys: ["g/5/cx"], duration: "1"),
            .init(keys: ["g/5/cx"], duration: "2"),
            .init(keys: ["g/5/cx"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/tu"], duration: "1/2"),
            .init(keys: ["g/5/tu"], duration: "1"),
            .init(keys: ["g/5/tu"], duration: "2"),
            .init(keys: ["g/5/tu"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/td"], duration: "1/2"),
            .init(keys: ["g/5/td"], duration: "1"),
            .init(keys: ["g/5/td"], duration: "2"),
            .init(keys: ["g/5/td"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/sf"], duration: "1/2"),
            .init(keys: ["g/5/sf"], duration: "1"),
            .init(keys: ["g/5/sf"], duration: "2"),
            .init(keys: ["g/5/sf"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/sb"], duration: "1/2"),
            .init(keys: ["g/5/sb"], duration: "1"),
            .init(keys: ["g/5/sb"], duration: "2"),
            .init(keys: ["g/5/sb"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/ci"], duration: "1/2"),
            .init(keys: ["g/5/ci"], duration: "1"),
            .init(keys: ["g/5/ci"], duration: "2"),
            .init(keys: ["g/5/ci"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/sq"], duration: "1/2"),
            .init(keys: ["g/5/sq"], duration: "1"),
            .init(keys: ["g/5/sq"], duration: "2"),
            .init(keys: ["g/5/sq"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
        ]

        let width = Double(specs.count) * 25 + 100
        try runCategorySVGParityCase(module: "NoteHead", test: "Various_Note_Heads_1", width: width, height: 240) { _, context in
            for row in 0..<2 {
                let stave = Stave(x: 10, y: 10 + Double(row) * 120, width: Double(specs.count) * 25 + 75)
                    .addClef(.percussion)
                _ = stave.setContext(context)
                try stave.draw()

                for (index, spec) in specs.enumerated() {
                    let stemDirection: StemDirection = row == 0 ? .down : .up
                    let note = try drawUpstreamNoteHeadStaveNote(
                        spec: spec,
                        stemDirection: stemDirection,
                        stave: stave,
                        context: context,
                        x: Double(index + 1) * 25
                    )
                    #expect(note.getX() > 0)
                    #expect(!note.getYs().isEmpty)
                }
            }
        }
    }

    @Test("NoteHead.Various_Note_Heads_2")
    func noteHeadVariousNoteHeads2MatchesUpstream() throws {
        let specs: [UpstreamNoteHeadSpec] = [
            .init(keys: ["g/5/do"], duration: "4", autoStem: true),
            .init(keys: ["g/5/re"], duration: "4", autoStem: true),
            .init(keys: ["g/5/mi"], duration: "4", autoStem: true),
            .init(keys: ["g/5/fa"], duration: "4", autoStem: true),
            .init(keys: ["e/4/faup"], duration: "4", autoStem: true),
            .init(keys: ["g/5/so"], duration: "4", autoStem: true),
            .init(keys: ["g/5/la"], duration: "4", autoStem: true),
            .init(keys: ["g/5/ti"], duration: "4", autoStem: true),
        ]

        let width = Double(specs.count) * 25 + 100
        try runCategorySVGParityCase(module: "NoteHead", test: "Various_Note_Heads_2", width: width, height: 240) { _, context in
            let stave = Stave(x: 10, y: 10, width: Double(specs.count) * 25 + 75)
                .addClef(.percussion)
            _ = stave.setContext(context)
            try stave.draw()

            for (index, spec) in specs.enumerated() {
                let note = try drawUpstreamNoteHeadStaveNote(
                    spec: spec,
                    stemDirection: nil,
                    stave: stave,
                    context: context,
                    x: Double(index + 1) * 25
                )
                #expect(note.getX() > 0)
                #expect(!note.getYs().isEmpty)
            }
        }
    }

    @Test("NoteHead.Various_Heads")
    func noteHeadVariousHeadsMatchesUpstream() throws {
        let specs: [UpstreamNoteHeadSpec] = [
            .init(keys: ["g/5/d0"], duration: "4"),
            .init(keys: ["g/5/d1"], duration: "4"),
            .init(keys: ["g/5/d2"], duration: "4"),
            .init(keys: ["g/5/d3"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/t0"], duration: "1"),
            .init(keys: ["g/5/t1"], duration: "4"),
            .init(keys: ["g/5/t2"], duration: "4"),
            .init(keys: ["g/5/t3"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/x0"], duration: "1"),
            .init(keys: ["g/5/x1"], duration: "4"),
            .init(keys: ["g/5/x2"], duration: "4"),
            .init(keys: ["g/5/x3"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/s1"], duration: "4"),
            .init(keys: ["g/5/s2"], duration: "4"),
            .init(keys: ["x/"], duration: "1"),
            .init(keys: ["g/5/r1"], duration: "4"),
            .init(keys: ["g/5/r2"], duration: "4"),
        ]

        let width = Double(specs.count) * 25 + 100
        try runCategorySVGParityCase(module: "NoteHead", test: "Various_Heads", width: width, height: 240) { _, context in
            for row in 0..<2 {
                let stave = Stave(x: 10, y: 10 + Double(row) * 120, width: Double(specs.count) * 25 + 75)
                    .addClef(.percussion)
                _ = stave.setContext(context)
                try stave.draw()

                for (index, spec) in specs.enumerated() {
                    let stemDirection: StemDirection = row == 0 ? .down : .up
                    let note = try drawUpstreamNoteHeadStaveNote(
                        spec: spec,
                        stemDirection: stemDirection,
                        stave: stave,
                        context: context,
                        x: Double(index + 1) * 25
                    )
                    #expect(note.getX() > 0)
                    #expect(!note.getYs().isEmpty)
                }
            }
        }
    }

    @Test("NoteHead.Drum_Chord_Heads")
    func noteHeadDrumChordHeadsMatchesUpstream() throws {
        let specs: [UpstreamNoteHeadSpec] = [
            .init(keys: ["a/4/d0", "g/5/x3"], duration: "4"),
            .init(keys: ["a/4/x3", "g/5/d0"], duration: "4"),
            .init(keys: ["a/4/d1", "g/5/x2"], duration: "4"),
            .init(keys: ["a/4/x2", "g/5/d1"], duration: "4"),
            .init(keys: ["a/4/d2", "g/5/x1"], duration: "4"),
            .init(keys: ["a/4/x1", "g/5/d2"], duration: "4"),
            .init(keys: ["a/4/d3", "g/5/x0"], duration: "4"),
            .init(keys: ["a/4/x0", "g/5/d3"], duration: "4"),
            .init(keys: ["a/4", "g/5/d0"], duration: "4"),
            .init(keys: ["a/4/x3", "g/5"], duration: "4"),
            .init(keys: ["a/4/t0", "g/5/s1"], duration: "4"),
            .init(keys: ["a/4/s1", "g/5/t0"], duration: "4"),
            .init(keys: ["a/4/t1", "g/5/s2"], duration: "4"),
            .init(keys: ["a/4/s2", "g/5/t1"], duration: "4"),
            .init(keys: ["a/4/t2", "g/5/r1"], duration: "4"),
            .init(keys: ["a/4/r1", "g/5/t2"], duration: "4"),
            .init(keys: ["a/4/t3", "g/5/r2"], duration: "4"),
            .init(keys: ["a/4/r2", "g/5/t3"], duration: "4"),
        ]

        let width = Double(specs.count) * 25 + 100
        try runCategorySVGParityCase(module: "NoteHead", test: "Drum_Chord_Heads", width: width, height: 240) { _, context in
            for row in 0..<2 {
                let stave = Stave(x: 10, y: 10 + Double(row) * 120, width: Double(specs.count) * 25 + 75)
                    .addClef(.percussion)
                _ = stave.setContext(context)
                try stave.draw()

                for (index, spec) in specs.enumerated() {
                    let stemDirection: StemDirection = row == 0 ? .down : .up
                    let note = try drawUpstreamNoteHeadStaveNote(
                        spec: spec,
                        stemDirection: stemDirection,
                        stave: stave,
                        context: context,
                        x: Double(index + 1) * 25
                    )
                    #expect(note.getX() > 0)
                    #expect(!note.getYs().isEmpty)
                }
            }
        }
    }

    @Test("NoteHead.Bounding_Boxes")
    func noteHeadBoundingBoxesMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "NoteHead", test: "Bounding_Boxes", width: 450, height: 250) { _, context in
            applyUpstreamNoteHeadContextStyle(context)

            let stave = Stave(x: 10, y: 0, width: 250).addClef(.treble)
            _ = stave.setContext(context)
            try stave.draw()

            let formatter = Formatter()
            let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).setStrict(false)

            let nh1 = StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "4"))
            let nh2 = StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "2"))
            let nh3 = NoteHead(noteHeadStruct: try NoteHeadStruct(duration: "1", line: 0))

            _ = voice.addTickables([nh1, nh2, nh3])
            _ = formatter.joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)

            let boxes = [
                nh1.noteHeads.first?.getBoundingBox(),
                nh2.noteHeads.first?.getBoundingBox(),
                nh3.getBoundingBox(),
            ].compactMap { $0 }

            for box in boxes {
                _ = context.rect(box.x, box.y, box.w, box.h)
            }
            _ = context.stroke()
        }
    }

    private func applyUpstreamNoteHeadContextStyle(_ context: SVGRenderContext) {
        _ = context.scale(0.9, 0.9)
        _ = context.scale(2.0, 2.0)
        _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
    }

    @discardableResult
    private func drawUpstreamNoteHeadStaveNote(
        spec: UpstreamNoteHeadSpec,
        stemDirection: StemDirection?,
        stave: Stave,
        context: RenderContext,
        x: Double
    ) throws -> StaveNote {
        let note = StaveNote(try StaveNoteStruct(
            parsingKeys: spec.keys,
            duration: spec.duration,
            stemDirection: stemDirection,
            autoStem: spec.autoStem
        ))
        _ = note.setStave(stave)
        _ = TickContext().addTickable(note).preFormat().setX(x)
        _ = note.setContext(context)
        try note.draw()
        return note
    }
}

private struct UpstreamNoteHeadSpec {
    let keys: [String]
    let duration: String
    let autoStem: Bool?

    init(keys: [String], duration: String, autoStem: Bool? = nil) {
        self.keys = keys
        self.duration = duration
        self.autoStem = autoStem
    }
}
