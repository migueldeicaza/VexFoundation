import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    /// Mirrors upstream 5.9.0 `tests/accordionregister_tests.ts` (`registerEntrances`).
    /// The asserts are in Upstream59InstrumentsTests.
    @Test("AccordionRegister.Active_reed_ranks_follow_their_entrances")
    func accordionRegisterActiveReedRanksMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "AccordionRegister",
            test: "Active_reed_ranks_follow_their_entrances",
            width: 470,
            height: 205
        ) { f, _ in
            let stave = f.Stave(x: 10, y: 65, width: 440).addClef(.treble)
            let notes = try ["c/5", "a/4", "b/4"].map {
                f.StaveNote(try StaveNoteStruct(parsingKeys: [$0], duration: "q"))
            }
            let voice = f.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables(notes)
            let marks = [
                try f.AccordionRegister(AccordionRanks(middle: 1)),
                try f.AccordionRegister(AccordionRanks(high: true, low: true)),
                try f.AccordionRegister(AccordionRanks(middle: 2)),
            ]
            let fingering = f.Fingering(number: "2", position: .above)
            _ = notes[1].addModifier(fingering, index: 0)
            for (i, note) in notes.enumerated() { _ = note.addModifier(marks[i], index: 0) }
            for width in [260.0, 440] {
                _ = stave.setWidth(width)
                _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                for mark in marks { _ = try measureEngraving(mark) }
            }
            try f.draw()
        }
    }
}
