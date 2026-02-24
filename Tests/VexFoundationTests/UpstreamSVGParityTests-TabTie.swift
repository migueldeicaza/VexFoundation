import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TabTie.Simple_TabTie")
    func tabTieSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TabTie",
            test: "Simple_TabTie",
            width: 350,
            height: 160,
            signatureEpsilonOverride: 0.0015
        ) { _, context in
            let stave = try makeTabTieStave(context: context, width: 350)
            let note1 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 4)],
                duration: "h"
            ))
            let note2 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 6)],
                duration: "h"
            ))

            try drawUpstreamTabTieNotes(
                notes: [note1, note2],
                indices: [0],
                stave: stave,
                context: context
            )
        }
    }

    @Test("TabTie.Hammerons")
    func tabTieHammeronsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TabTie",
            test: "Hammerons",
            width: 440,
            height: 140,
            signatureEpsilonOverride: 0.0015
        ) { _, context in
            let stave = try makeTabTieStave(context: context, width: 440)
            let notes = try makeTabTieMultiTestNotes()
            let voice = Voice(timeSignature: .meter(4, 4)).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 300)
            try voice.draw(context: context, stave: stave)

            try drawTabTieGroups(context: context, notes: notes, builder: { tieNotes in
                TabTie.createHammeron(notes: tieNotes)
            })
        }
    }

    @Test("TabTie.Pulloffs")
    func tabTiePulloffsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TabTie",
            test: "Pulloffs",
            width: 440,
            height: 140,
            signatureEpsilonOverride: 0.0015
        ) { _, context in
            let stave = try makeTabTieStave(context: context, width: 440)
            let notes = try makeTabTieMultiTestNotes()
            let voice = Voice(timeSignature: .meter(4, 4)).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 300)
            try voice.draw(context: context, stave: stave)

            try drawTabTieGroups(context: context, notes: notes, builder: { tieNotes in
                TabTie.createPulloff(notes: tieNotes)
            })
        }
    }

    @Test("TabTie.Tapping")
    func tabTieTappingMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TabTie",
            test: "Tapping",
            width: 350,
            height: 160,
            signatureEpsilonOverride: 0.0015
        ) { _, context in
            let stave = try makeTabTieStave(context: context, width: 350)
            let note1 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 12)],
                duration: "h"
            )).addModifier(Annotation("T"), index: 0)
            let note2 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 10)],
                duration: "h"
            ))

            try drawUpstreamTabTieNotes(
                notes: [note1, note2],
                indices: [0],
                stave: stave,
                context: context,
                tieText: "P"
            )
        }
    }

    @Test("TabTie.Continuous")
    func tabTieContinuousMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "TabTie",
            test: "Continuous",
            width: 440,
            height: 140,
            signatureEpsilonOverride: 0.0015
        ) { _, context in
            let stave = try makeTabTieStave(context: context, width: 440)
            let notes: [TabNote] = try [
                TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 4)], duration: "q")),
                TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 5)], duration: "q")),
                TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 6)], duration: "h")),
            ]

            let voice = Voice(timeSignature: .meter(4, 4)).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 300)
            try voice.draw(context: context, stave: stave)

            let hammeron = TabTie.createHammeron(notes: TieNotes(
                firstNote: notes[0],
                lastNote: notes[1],
                firstIndices: [0],
                lastIndices: [0]
            ))
            _ = hammeron.setContext(context)
            try hammeron.draw()

            let pulloff = TabTie.createPulloff(notes: TieNotes(
                firstNote: notes[1],
                lastNote: notes[2],
                firstIndices: [0],
                lastIndices: [0]
            ))
            _ = pulloff.setContext(context)
            try pulloff.draw()
        }
    }

    private func makeTabTieStave(context: RenderContext, width: Double) throws -> TabStave {
        _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
        let stave = TabStave(x: 10, y: 10, width: width).addTabGlyph()
        _ = stave.setContext(context)
        try stave.draw()
        return stave
    }

    private func makeTabTieMultiTestNotes() throws -> [TabNote] {
        try [
            TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 4)], duration: "8")),
            TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 4)], duration: "8")),
            TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 4), TabNotePosition(str: 5, fret: 4)],
                duration: "8"
            )),
            TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 6), TabNotePosition(str: 5, fret: 6)],
                duration: "8"
            )),
            TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 14)], duration: "8")),
            TabNote(validating: TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 16)], duration: "8")),
            TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 2, fret: 14), TabNotePosition(str: 3, fret: 14)],
                duration: "8"
            )),
            TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 2, fret: 16), TabNotePosition(str: 3, fret: 16)],
                duration: "8"
            )),
        ]
    }

    private func drawUpstreamTabTieNotes(
        notes: [TabNote],
        indices: [Int],
        stave: TabStave,
        context: RenderContext,
        tieText: String = "Annotation"
    ) throws {
        let voice = Voice(timeSignature: .meter(4, 4))
        _ = voice.addTickables(notes.map { $0 as Tickable })
        _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 100)
        try voice.draw(context: context, stave: stave)

        let tie = TabTie(
            notes: TieNotes(
                firstNote: notes[0],
                lastNote: notes[1],
                firstIndices: indices,
                lastIndices: indices
            ),
            text: tieText
        )
        _ = tie.setContext(context)
        try tie.draw()
    }

    private func drawTabTieGroups(
        context: RenderContext,
        notes: [TabNote],
        builder: (TieNotes) -> TabTie
    ) throws {
        let pairs: [([Int], Int, Int)] = [
            ([0], 0, 1),
            ([0, 1], 2, 3),
            ([0], 4, 5),
            ([0, 1], 6, 7),
        ]

        for (indices, first, last) in pairs {
            let tie = builder(TieNotes(
                firstNote: notes[first],
                lastNote: notes[last],
                firstIndices: indices,
                lastIndices: indices
            ))
            _ = tie.setContext(context)
            try tie.draw()
        }
    }
}
