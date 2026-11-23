import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    /// Mirrors upstream 5.8.0 `tests/figuredbass_tests.ts` (`independentRows`). The asserts are in Upstream58GuitarTests.
    @Test("FiguredBass.Independent_figured_bass_continuations")
    func figuredBassIndependentContinuationsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "FiguredBass",
            test: "Independent_figured_bass_continuations",
            width: 580,
            height: 185
        ) { factory, _ in
            let stave = factory.Stave(x: 10, y: 10, width: 300).addClef(.bass)
            let notes = try (0..<4).map { _ in
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["g/2"], duration: "q", clef: .bass))
            }
            let voice = factory.Voice().addTickables(notes)
            let bass = try factory.FiguredBass(FiguredBassSpec(rows: [
                [
                    FiguredBassFigure(note: notes[0], figure: "6", extendTo: notes[2]),
                    FiguredBassFigure(note: notes[3], figure: "5"),
                ],
                [
                    FiguredBassFigure(note: notes[0], figure: "4"),
                    FiguredBassFigure(note: notes[1], figure: "3", extendTo: notes[3]),
                ],
            ]))
            // Upstream formats at 300, 550 and 300 again, and measures each time.
            for width in [300.0, 550, 300] {
                _ = stave.setWidth(width)
                _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                _ = try measureEngraving(bass)
            }
            try factory.draw()
        }
    }
}
