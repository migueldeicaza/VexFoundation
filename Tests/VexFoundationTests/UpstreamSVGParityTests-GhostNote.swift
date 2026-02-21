import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("GhostNote.GhostNote_Basic")
    func ghostNoteBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "GhostNote", test: "GhostNote_Basic", width: 550, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let topVoice = score.voice(
                score.notes(
                    "f#5/4, f5, db5, c5, c5/8, d5, fn5, e5, d5, c5",
                    options: ["stem": "up"]
                ),
                time: .meter(7, 4)
            )
            let topNotes = topVoice.getTickables().compactMap { $0 as? StemmableNote }
            _ = factory.Beam(notes: Array(topNotes[4..<8]))
            _ = factory.Beam(notes: Array(topNotes[8..<10]))

            _ = score.voice(
                [
                    factory.GhostNote(NoteStruct(duration: try NoteDurationSpec(parsing: "2"))) as Note,
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "4", stemDirection: .down)),
                    factory.GhostNote(NoteStruct(duration: try NoteDurationSpec(parsing: "4"))) as Note,
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "4", stemDirection: .down)),
                    factory.GhostNote(NoteStruct(duration: try NoteDurationSpec(parsing: "8"))) as Note,
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4"], duration: "8", stemDirection: .down))
                        .addModifier(factory.Accidental(type: .doubleSharp), index: 0),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "8", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "8", stemDirection: .down)),
                ],
                time: .meter(7, 4)
            )

            let voices = factory.getVoices()
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }

    @Test("GhostNote.GhostNote_Dotted")
    func ghostNoteDottedMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "GhostNote", test: "GhostNote_Dotted", width: 550, height: 140) { factory, _ in
            let stave = factory.Stave()
            let score = factory.EasyScore()

            let voice1 = score.voice(
                [
                    factory.GhostNote(NoteStruct(duration: try NoteDurationSpec(parsing: "4d"))),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "8", stemDirection: .up)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/5"], duration: "4", stemDirection: .up)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8", stemDirection: .up)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "16", stemDirection: .up)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/5"], duration: "16", stemDirection: .up)),
                    factory.GhostNote(NoteStruct(duration: try NoteDurationSpec(parsing: "2dd"))),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["f/5"], duration: "8", stemDirection: .up)),
                ],
                time: .meter(8, 4)
            )

            let voice2 = score.voice(
                [
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "4", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "8", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4"], duration: "8", stemDirection: .down)),
                    factory.GhostNote(NoteStruct(duration: try NoteDurationSpec(parsing: "4dd"))),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "16", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "2", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["d/4"], duration: "4", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "8", stemDirection: .down)),
                    factory.StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "8", stemDirection: .down)),
                ],
                time: .meter(8, 4)
            )

            let notes1 = voice1.getTickables().compactMap { $0 as? StemmableNote }
            let notes2 = voice2.getTickables().compactMap { $0 as? StemmableNote }

            _ = (notes1[1] as! StaveNote).addModifier(factory.Accidental(type: .doubleFlat), index: 0)
            _ = (notes1[4] as! StaveNote).addModifier(factory.Accidental(type: .sharp), index: 0)
            _ = (notes1[7] as! StaveNote).addModifier(factory.Accidental(type: .natural), index: 0)

            _ = (notes2[0] as! StaveNote).addModifier(factory.Accidental(type: .sharp), index: 0)
            _ = (notes2[4] as! StaveNote).addModifier(factory.Accidental(type: .flat), index: 0)
            _ = (notes2[5] as! StaveNote).addModifier(factory.Accidental(type: .sharp), index: 0)
            _ = (notes2[7] as! StaveNote).addModifier(factory.Accidental(type: .natural), index: 0)

            _ = factory.Beam(notes: Array(notes1[3..<6]))
            _ = factory.Beam(notes: Array(notes2[1..<3]))
            _ = factory.Beam(notes: Array(notes2[7..<9]))

            let voices = factory.getVoices()
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
        }
    }
}
