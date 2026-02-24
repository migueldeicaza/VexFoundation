import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("StaveHairpin.Simple_StaveHairpin")
    func staveHairpinSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveHairpin", test: "Simple_StaveHairpin", width: 450, height: 140) {
            factory,
            context in
            try drawUpstreamStaveHairpinTest(factory: factory, context: context) { notes, context in
                try drawUpstreamStaveHairpin(
                    firstNote: notes[0],
                    lastNote: notes[2],
                    context: context,
                    type: .crescendo,
                    position: .below
                )
                try drawUpstreamStaveHairpin(
                    firstNote: notes[1],
                    lastNote: notes[3],
                    context: context,
                    type: .decrescendo,
                    position: .above
                )
            }
        }
    }

    @Test("StaveHairpin.Horizontal_Offset_StaveHairpin")
    func staveHairpinHorizontalOffsetMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveHairpin",
            test: "Horizontal_Offset_StaveHairpin",
            width: 450,
            height: 140
        ) { factory, context in
            try drawUpstreamStaveHairpinTest(factory: factory, context: context) { notes, context in
                try drawUpstreamStaveHairpin(
                    firstNote: notes[0],
                    lastNote: notes[2],
                    context: context,
                    type: .crescendo,
                    position: .above
                )
                try drawUpstreamStaveHairpin(
                    firstNote: notes[3],
                    lastNote: notes[3],
                    context: context,
                    type: .decrescendo,
                    position: .below,
                    options: HairpinRenderOptions(leftShiftPx: 0, rightShiftPx: 120, height: 10, yShift: 0)
                )
            }
        }
    }

    @Test("StaveHairpin.Vertical_Offset_StaveHairpin")
    func staveHairpinVerticalOffsetMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "StaveHairpin",
            test: "Vertical_Offset_StaveHairpin",
            width: 450,
            height: 140
        ) { factory, context in
            try drawUpstreamStaveHairpinTest(factory: factory, context: context) { notes, context in
                try drawUpstreamStaveHairpin(
                    firstNote: notes[0],
                    lastNote: notes[2],
                    context: context,
                    type: .crescendo,
                    position: .below,
                    options: HairpinRenderOptions(leftShiftPx: 0, rightShiftPx: 0, height: 10, yShift: 0)
                )
                try drawUpstreamStaveHairpin(
                    firstNote: notes[2],
                    lastNote: notes[3],
                    context: context,
                    type: .decrescendo,
                    position: .below,
                    options: HairpinRenderOptions(leftShiftPx: 2, rightShiftPx: 0, height: 10, yShift: -15)
                )
            }
        }
    }

    @Test("StaveHairpin.Height_StaveHairpin")
    func staveHairpinHeightMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "StaveHairpin", test: "Height_StaveHairpin", width: 450, height: 140) {
            factory,
            context in
            try drawUpstreamStaveHairpinTest(factory: factory, context: context) { notes, context in
                try drawUpstreamStaveHairpin(
                    firstNote: notes[0],
                    lastNote: notes[2],
                    context: context,
                    type: .crescendo,
                    position: .below,
                    options: HairpinRenderOptions(leftShiftPx: 0, rightShiftPx: 0, height: 10, yShift: 0)
                )
                try drawUpstreamStaveHairpin(
                    firstNote: notes[2],
                    lastNote: notes[3],
                    context: context,
                    type: .decrescendo,
                    position: .below,
                    options: HairpinRenderOptions(leftShiftPx: 2, rightShiftPx: 0, height: 15, yShift: 0)
                )
            }
        }
    }

    private func drawUpstreamStaveHairpinTest(
        factory: Factory,
        context: SVGRenderContext,
        drawHairpins: ([StaveNote], SVGRenderContext) throws -> Void
    ) throws {
        let stave = factory.Stave()
        let notes = try makeUpstreamStaveHairpinNotes(factory: factory)
        let voice = factory.Voice().addTickables(notes.map { $0 as Tickable })
        _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        try factory.draw()
        try drawHairpins(notes, context)
    }

    private func makeUpstreamStaveHairpinNotes(factory: Factory) throws -> [StaveNote] {
        let first = try factory.StaveNote(StaveNoteStruct(
            parsingKeys: ["c/4", "e/4", "a/4"],
            duration: "4",
            stemDirection: .up
        ))
        _ = first.addModifier(factory.Accidental(type: .flat), index: 0)
        _ = first.addModifier(factory.Accidental(type: .sharp), index: 1)

        let second = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["d/4"], duration: "4", stemDirection: .up))
        let third = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/4"], duration: "4", stemDirection: .up))
        let fourth = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "4", stemDirection: .up))
        return [first, second, third, fourth]
    }

    private func drawUpstreamStaveHairpin(
        firstNote: StaveNote,
        lastNote: StaveNote,
        context: SVGRenderContext,
        type: HairpinType,
        position: ModifierPosition,
        options: HairpinRenderOptions? = nil
    ) throws {
        let hairpin = StaveHairpin(firstNote: firstNote, lastNote: lastNote, type: type)
        _ = hairpin.setContext(context)
        _ = hairpin.setPosition(position)
        if let options {
            _ = hairpin.setRenderOptions(options)
        }
        try hairpin.draw()
    }
}
