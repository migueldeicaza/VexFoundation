import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TabNote.TabNote_Draw")
    func tabNoteDrawMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TabNote",
            test: "TabNote_Draw",
            width: 600,
            height: 140,
            signatureEpsilonOverride: 0.005
        ) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)
            try stave.draw()

            let specs: [UpstreamTabNoteSpec] = [
                .init(positions: [.init(str: 6, fret: 6)], duration: "4"),
                .init(positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 25)], duration: "4"),
                .init(positions: [.init(str: 2, fret: "x"), .init(str: 5, fret: 15)], duration: "4"),
                .init(positions: [.init(str: 2, fret: "x"), .init(str: 5, fret: 5)], duration: "4"),
                .init(positions: [.init(str: 2, fret: 10), .init(str: 5, fret: 12)], duration: "4"),
                .init(
                    positions: [
                        .init(str: 6, fret: 0),
                        .init(str: 5, fret: 5),
                        .init(str: 4, fret: 5),
                        .init(str: 3, fret: 4),
                        .init(str: 2, fret: 3),
                        .init(str: 1, fret: 0),
                    ],
                    duration: "4"
                ),
                .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "4"),
            ]

            for (index, spec) in specs.enumerated() {
                let note = try drawUpstreamTabNote(
                    spec,
                    stave: stave,
                    context: context,
                    x: Double(index + 1) * 25
                )
                #expect(note.getX() > 0)
                #expect(!note.getYs().isEmpty)
            }
        }
    }

    @Test("TabNote.TabNote_Stems_Up")
    func tabNoteStemsUpMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabNote", test: "TabNote_Stems_Up", width: 600, height: 200) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
            let stave = TabStave(x: 10, y: 30, width: 550)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = try makeUpstreamTabStemSequence().map { spec in
                let note = try TabNote(validating: spec)
                note.renderOptions.drawStem = true
                return note
            }

            let voice = Voice(timeSignature: .meter(4, 4))
                .setMode(.soft)
                .addTickables(notes.map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("TabNote.TabNote_Stems_Down")
    func tabNoteStemsDownMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabNote", test: "TabNote_Stems_Down", width: 600, height: 200) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
            let stave = TabStave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = try makeUpstreamTabStemSequence().map { spec in
                let note = try TabNote(validating: spec)
                note.renderOptions.drawStem = true
                _ = note.setStemDirection(.down)
                return note
            }

            let voice = Voice(timeSignature: .meter(4, 4))
                .setMode(.soft)
                .addTickables(notes.map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("TabNote.TabNote_Stems_Up_Through_Stave")
    func tabNoteStemsUpThroughStaveMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabNote", test: "TabNote_Stems_Up_Through_Stave", width: 600, height: 200) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
            let stave = TabStave(x: 10, y: 30, width: 550)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = try makeUpstreamTabStemSequence().map { spec in
                let note = try TabNote(validating: spec)
                note.renderOptions.drawStem = true
                note.renderOptions.drawStemThroughStave = true
                return note
            }

            _ = context.setFont(FontInfo(
                family: VexFont.SANS_SERIF,
                size: 10,
                weight: VexFontWeight.bold.rawValue
            ))

            let voice = Voice(timeSignature: .meter(4, 4))
                .setMode(.soft)
                .addTickables(notes.map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("TabNote.TabNote_Stems_Down_Through_Stave")
    func tabNoteStemsDownThroughStaveMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabNote", test: "TabNote_Stems_Down_Through_Stave", width: 600, height: 250) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
            let stave = TabStave(
                x: 10,
                y: 10,
                width: 550,
                options: StaveOptions(numLines: 8)
            )
            _ = stave.setContext(context)
            try stave.draw()

            let specs: [UpstreamTabNoteSpec] = [
                .init(positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 25)], duration: "4"),
                .init(positions: [.init(str: 2, fret: 10), .init(str: 5, fret: 12)], duration: "8"),
                .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "8"),
                .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "16"),
                .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5), .init(str: 6, fret: 10)], duration: "32"),
                .init(positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)], duration: "64"),
                .init(
                    positions: [.init(str: 1, fret: 6), .init(str: 3, fret: 5), .init(str: 5, fret: 5), .init(str: 7, fret: 5)],
                    duration: "128"
                ),
            ]

            let notes = try specs.map { spec in
                let note = try TabNote(validating: spec.toStruct())
                note.renderOptions.drawStem = true
                note.renderOptions.drawStemThroughStave = true
                _ = note.setStemDirection(.down)
                return note
            }

            _ = context.setFont(FontInfo(family: "Arial", size: 10, weight: VexFontWeight.bold.rawValue))

            let voice = Voice(timeSignature: .meter(4, 4))
                .setMode(.soft)
                .addTickables(notes.map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("TabNote.TabNote_Stems_with_Dots")
    func tabNoteStemsWithDotsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabNote", test: "TabNote_Stems_with_Dots", width: 600, height: 200) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
            let stave = TabStave(x: 10, y: 10, width: 550)
            _ = stave.setContext(context)
            try stave.draw()

            let specs: [TabNoteStruct] = try [
                TabNoteStruct(
                    positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 25)],
                    duration: "4d"
                ),
                TabNoteStruct(
                    positions: [.init(str: 2, fret: 10), .init(str: 5, fret: 12)],
                    duration: "8"
                ),
                TabNoteStruct(
                    positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                    duration: "4dd",
                    stemDirection: .down
                ),
                TabNoteStruct(
                    positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                    duration: "16",
                    stemDirection: .down
                ),
            ]

            let notes = try specs.map { try TabNote(validating: $0, drawStem: true) }
            Dot.buildAndAttach([notes[0], notes[2], notes[2]].map { $0 as Note })

            let voice = Voice(timeSignature: .meter(4, 4))
                .setMode(.soft)
                .addTickables(notes.map { $0 as Tickable })

            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try voice.draw(context: context, stave: stave)
        }
    }

    private func makeUpstreamTabStemSequence() throws -> [TabNoteStruct] {
        try [
            TabNoteStruct(
                positions: [.init(str: 3, fret: 6), .init(str: 4, fret: 25)],
                duration: "4"
            ),
            TabNoteStruct(
                positions: [.init(str: 2, fret: 10), .init(str: 5, fret: 12)],
                duration: "8"
            ),
            TabNoteStruct(
                positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                duration: "8"
            ),
            TabNoteStruct(
                positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                duration: "16"
            ),
            TabNoteStruct(
                positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                duration: "32"
            ),
            TabNoteStruct(
                positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                duration: "64"
            ),
            TabNoteStruct(
                positions: [.init(str: 1, fret: 6), .init(str: 4, fret: 5)],
                duration: "128"
            ),
        ]
    }

    @discardableResult
    private func drawUpstreamTabNote(
        _ spec: UpstreamTabNoteSpec,
        stave: TabStave,
        context: RenderContext,
        x: Double
    ) throws -> TabNote {
        let note = try TabNote(validating: spec.toStruct())
        _ = TickContext().addTickable(note).preFormat().setX(x)
        _ = note.setContext(context)
        _ = note.setStave(stave)
        try note.draw()
        return note
    }
}

private struct UpstreamTabNoteSpec {
    let positions: [TabNotePosition]
    let duration: String

    func toStruct() throws -> TabNoteStruct {
        try TabNoteStruct(positions: positions, duration: duration)
    }
}
