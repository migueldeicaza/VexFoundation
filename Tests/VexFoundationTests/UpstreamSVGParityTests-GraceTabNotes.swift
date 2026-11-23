import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    /// Both sides of a wide host must leave visible space around the smaller fret. (VexFlow 5.6.0)
    @Test("Grace_Tab_Notes.Grace_frets_beside_a_two_digit_host")
    func graceTabNotesBesideTwoDigitHostMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Grace_Tab_Notes",
            test: "Grace_frets_beside_a_two_digit_host",
            width: 350,
            height: 140,
            referenceFontsOverride: ["Bravura"]
        ) { _, context in
            let stave = try makeUpstreamGraceTabStave(context: context)
            let positions = [TabNotePosition(str: 2, fret: 12)]
            let host = TabNote(TabNoteStruct(positions: positions, duration: .whole))
            let before = GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 2)], duration: .eighth))
            let after = GraceTabNote(TabNoteStruct(positions: positions, duration: .eighth))
            _ = host.addModifier(GraceNoteGroup(graceNotes: [before]), index: 0)
            _ = host.addModifier(GraceNoteGroup(graceNotes: [after]).setPosition(.right), index: 0)
            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: [host])
            let hostHalfWidth = TabNote.tabToElement("12").getWidth() / 2
            // The before-grace edge meets the host edge exactly; allow for floating-point rounding.
            #expect(before.getAbsoluteX() + before.getWidth() / 2 + 2 <= host.getAbsoluteX() - hostHalfWidth + 1e-9)
            #expect(after.getAbsoluteX() - after.getWidth() / 2 - 2 >= host.getAbsoluteX() + hostHalfWidth - 1e-9)
        }
    }

    @Test("Grace_Tab_Notes.Grace_Tab_Note_Simple")
    func graceTabNotesSimpleMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Grace_Tab_Notes",
            test: "Grace_Tab_Note_Simple",
            width: 350,
            height: 140
        ) { _, context in
            let stave = try makeUpstreamGraceTabStave(context: context)

            let note0 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 6)],
                duration: "4"
            ))
            let note1 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 12)],
                duration: "4"
            ))
            let note2 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 10)],
                duration: "4"
            ))
            let note3 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 10)],
                duration: "4"
            ))

            let graceNotes0 = [GraceTabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: "x")],
                duration: .eighth
            ))]
            let graceNotes1 = [
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 9)], duration: .sixteenth)),
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 10)], duration: .sixteenth)),
            ]
            let graceNotes2 = [GraceTabNote(TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 9)],
                duration: .eighth
            )).setGhost(true)]
            let graceNotes3 = [
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 5, fret: 10)], duration: .eighth)),
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 9)], duration: .eighth)),
            ]

            _ = note0.addModifier(GraceNoteGroup(graceNotes: graceNotes0), index: 0)
            _ = note1.addModifier(GraceNoteGroup(graceNotes: graceNotes1), index: 0)
            _ = note2.addModifier(GraceNoteGroup(graceNotes: graceNotes2), index: 0)
            _ = note3.addModifier(GraceNoteGroup(graceNotes: graceNotes3), index: 0)

            let voice = Voice(timeSignature: .meter(4, 4))
            _ = voice.addTickables([note0, note1, note2, note3].map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 250)
            try voice.draw(context: context, stave: stave)
        }
    }

    @Test("Grace_Tab_Notes.Grace_Tab_Note_Slurred")
    func graceTabNotesSlurredMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Grace_Tab_Notes",
            test: "Grace_Tab_Note_Slurred",
            width: 350,
            height: 140
        ) { _, context in
            let stave = try makeUpstreamGraceTabStave(context: context)

            let note0 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 12)],
                duration: "h"
            ))
            let note1 = try TabNote(validating: TabNoteStruct(
                positions: [TabNotePosition(str: 4, fret: 10)],
                duration: "h"
            ))

            let graceNotes0 = [
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 9)], duration: .eighth)),
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 10)], duration: .eighth)),
            ]
            let graceNotes1 = [
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 7)], duration: .sixteenth)),
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 8)], duration: .sixteenth)),
                GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 4, fret: 9)], duration: .sixteenth)),
            ]

            _ = note0.addModifier(GraceNoteGroup(graceNotes: graceNotes0, showSlur: true), index: 0)
            _ = note1.addModifier(GraceNoteGroup(graceNotes: graceNotes1, showSlur: true), index: 0)

            let voice = Voice(timeSignature: .meter(4, 4))
            _ = voice.addTickables([note0, note1].map { $0 as Tickable })
            _ = Formatter().joinVoices([voice]).format([voice], justifyWidth: 200)
            try voice.draw(context: context, stave: stave)
        }
    }

    private func makeUpstreamGraceTabStave(context: SVGRenderContext) throws -> TabStave {
        _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))
        let stave = TabStave(x: 10, y: 10, width: 350).addTabGlyph()
        _ = stave.setContext(context)
        try stave.drawWithStyle()
        return stave
    }
}
