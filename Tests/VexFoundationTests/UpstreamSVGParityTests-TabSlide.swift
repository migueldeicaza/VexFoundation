import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TabSlide.Simple_TabSlide")
    func tabSlideSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabSlide", test: "Simple_TabSlide", width: 350, height: 140) { _, context in
            let stave = try makeTabSlideStave(context: context, width: 350)
            let notes: [TabNote] = [
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 4)], duration: .half)),
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 6)], duration: .half)),
            ]

            let voice = Voice(timeSignature: .meter(4, 4)).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 100)
            try voice.draw(context: context, stave: stave)

            let slide = TabSlide(
                notes: TieNotes(firstNote: notes[0], lastNote: notes[1], firstIndices: [0], lastIndices: [0]),
                direction: TabSlide.SLIDE_UP
            )
            _ = slide.setContext(context)
            try slide.draw()
        }
    }

    @Test("TabSlide.Slide_Up")
    func tabSlideUpMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabSlide", test: "Slide_Up", width: 350, height: 140) { _, context in
            let stave = try makeTabSlideStave(context: context, width: 440)
            let notes = makeTabSlideMultiTestNotes()
            let voice = Voice(timeSignature: .meter(4, 4)).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 300)
            try voice.draw(context: context, stave: stave)

            try drawTabSlideGroups(
                context: context,
                notes: notes,
                builder: { tieNotes in TabSlide.createSlideUp(notes: tieNotes) }
            )
        }
    }

    @Test("TabSlide.Slide_Down")
    func tabSlideDownMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabSlide", test: "Slide_Down", width: 350, height: 140) { _, context in
            let stave = try makeTabSlideStave(context: context, width: 440)
            let notes = makeTabSlideMultiTestNotes()
            let voice = Voice(timeSignature: .meter(4, 4)).addTickables(notes.map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 300)
            try voice.draw(context: context, stave: stave)

            try drawTabSlideGroups(
                context: context,
                notes: notes,
                builder: { tieNotes in TabSlide.createSlideDown(notes: tieNotes) }
            )
        }
    }

    private func makeTabSlideStave(context: RenderContext, width: Double) throws -> TabStave {
        _ = context.scale(0.9, 0.9)
        _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

        let stave = TabStave(x: 10, y: 10, width: width).addTabGlyph()
        _ = stave.setContext(context)
        try stave.draw()
        return stave
    }

    private func makeTabSlideMultiTestNotes() -> [TabNote] {
        [
            TabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 4)], duration: .eighth)),
            TabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 4)], duration: .eighth)),
            TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 4), TabNotePosition(str: 5, fret: 4)],
                duration: .eighth
            )),
            TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 6), TabNotePosition(str: 5, fret: 6)],
                duration: .eighth
            )),
            TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 14)], duration: .eighth)),
            TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 16)], duration: .eighth)),
            TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 2, fret: 14), TabNotePosition(str: 3, fret: 14)],
                duration: .eighth
            )),
            TabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 2, fret: 16), TabNotePosition(str: 3, fret: 16)],
                duration: .eighth
            )),
        ]
    }

    private func drawTabSlideGroups(
        context: RenderContext,
        notes: [TabNote],
        builder: (TieNotes) -> TabSlide
    ) throws {
        let pairs: [([Int], Int, Int)] = [
            ([0], 0, 1),
            ([0, 1], 2, 3),
            ([0], 4, 5),
            ([0, 1], 6, 7),
        ]

        for (indices, first, last) in pairs {
            let tieNotes = TieNotes(
                firstNote: notes[first],
                lastNote: notes[last],
                firstIndices: indices,
                lastIndices: indices
            )
            let slide = builder(tieNotes)
            _ = slide.setContext(context)
            try slide.draw()
        }
    }
}
