import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Style.Basic_Style")
    func styleBasicStyleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Style", test: "Basic_Style", width: 600, height: 150) { factory, _ in
            let stave = factory.Stave(x: 25, y: 20, width: 500)

            let keySignature = KeySignature(keySpec: "D")
            _ = keySignature.addToStave(stave)
            _ = keySignature.setStyle(upstreamStyle(fillStyle: "blue"))

            _ = stave.addTimeSignature(.meter(4, 4))
            let timeSignatures = stave.getModifiers(position: .begin, category: TimeSignature.category)
            _ = timeSignatures.first?.setStyle(upstreamStyle(fillStyle: "brown"))

            let note0 = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["c/4", "e/4", "a/4"],
                duration: "4",
                stemDirection: .up
            ))
            _ = note0.addModifier(try factory.Accidental(parsing: "b"), index: 0)
            _ = note0.addModifier(try factory.Accidental(parsing: "#"), index: 1)

            let note1 = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["c/4", "e/4", "a/4"],
                duration: "4",
                stemDirection: .up
            ))
            _ = note1.addModifier(try factory.Accidental(parsing: "b"), index: 0)
            _ = note1.addModifier(try factory.Accidental(parsing: "#"), index: 1)

            let note2 = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["e/4"], duration: "4", stemDirection: .up))
            let note3 = try factory.StaveNote(StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .up))

            let textDynamics = factory.TextDynamics(try TextNoteStruct(duration: "16", text: "sfz"))
            _ = textDynamics.setStyle(upstreamStyle(fillStyle: "blue"))

            let ghostNote = try factory.GhostNote(duration: "16")
            _ = ghostNote.addModifier(
                Annotation("GhostNote green text").setStyle(upstreamStyle(fillStyle: "green")),
                index: 0
            )

            _ = note0.setKeyStyle(0, style: upstreamStyle(fillStyle: "red"))
            _ = note1.setKeyStyle(0, style: upstreamStyle(fillStyle: "red"))

            let note1Modifiers = note1.getModifiers()
            _ = note1Modifiers.first?.setStyle(upstreamStyle(fillStyle: "green"))

            _ = note0.addModifier(
                Articulation("a.")
                    .setPosition(.below)
                    .setStyle(upstreamStyle(fillStyle: "green")),
                index: 0
            )
            _ = note0.addModifier(Ornament("mordent").setStyle(upstreamStyle(fillStyle: "lightgreen")), index: 0)
            _ = note1.addModifier(Annotation("blue").setStyle(upstreamStyle(fillStyle: "blue")), index: 0)

            let subgroupClef = factory.ClefNote(size: .small)
            _ = subgroupClef.setStyle(upstreamStyle(fillStyle: "blue"))
            _ = note1.addModifier(NoteSubGroup(subNotes: [subgroupClef]), index: 0)

            let voice = factory.Voice()
            _ = voice.addTickables([
                note0,
                note1,
                note2,
                note3,
                textDynamics,
                ghostNote,
            ])

            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Style.TabNote_modifiers_Style")
    func styleTabNoteModifiersStyleMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Style", test: "TabNote_modifiers_Style", width: 500, height: 140) { _, context in
            _ = context.setFont(FontInfo(family: "Arial", size: "10pt"))

            let stave = TabStave(x: 10, y: 10, width: 450).addTabGlyph()
            let staveModifiers = stave.getModifiers()
            if staveModifiers.indices.contains(2) {
                _ = staveModifiers[2].setStyle(upstreamStyle(fillStyle: "blue"))
            }
            _ = stave.setContext(context)
            try stave.draw()

            let firstNote = TabNote(TabNoteStruct(
                positions: [
                    TabNotePosition(str: 2, fret: 10),
                    TabNotePosition(str: 4, fret: 9),
                ],
                duration: .half
            ))
            _ = firstNote.addModifier(Annotation("green text").setStyle(upstreamStyle(fillStyle: "green")), index: 0)

            let secondNote = TabNote(TabNoteStruct(
                positions: [
                    TabNotePosition(str: 2, fret: 10),
                    TabNotePosition(str: 4, fret: 9),
                ],
                duration: .half
            ))
            _ = secondNote.addModifier(Bend("Full").setStyle(upstreamStyle(fillStyle: "brown")), index: 0)
            _ = secondNote.addModifier(
                Stroke(type: .brushDown, allVoices: false).setStyle(upstreamStyle(fillStyle: "blue")),
                index: 0
            )

            try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: [firstNote, secondNote])
        }
    }

    private func upstreamStyle(fillStyle: String, strokeStyle: String? = nil) -> ElementStyle {
        ElementStyle(fillStyle: fillStyle, strokeStyle: strokeStyle)
    }
}
