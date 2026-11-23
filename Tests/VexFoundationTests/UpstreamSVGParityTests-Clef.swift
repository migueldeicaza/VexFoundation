// Opt-in SVG parity cases for the clef tests added in VexFlow 5.8.0 (tests/clef_tests.ts).
// The older Clef cases are in UpstreamSVGParityTests.swift.

import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Clef.Double_octave_clefs")
    func clefDoubleOctaveClefsMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Clef", test: "Double_octave_clefs", width: 620, height: 270) { factory, context in
            let forms: [(ClefName, ClefAnnotation)] = [
                (.treble, .doubleOctaveUp),
                (.treble, .doubleOctaveDown),
                (.bass, .doubleOctaveUp),
                (.bass, .doubleOctaveDown),
            ]
            for (index, form) in forms.enumerated() {
                let (type, annotation) = form
                let stave = factory
                    .Stave(x: 15 + 290 * Double(index % 2), y: 12 + 120 * Double(index / 2), width: 270)
                    .addClef(type, size: .default, annotation: annotation)
                let inline = factory.ClefNote(type: type, size: .small, annotation: annotation)
                let key = type == .treble ? "g/4" : "f/3"
                let quarter = factory.StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: "q", clef: type))
                let voice = factory.Voice(time: VoiceTime(numBeats: 1, beatValue: 4)).addTickables([inline, quarter])
                _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                // Both clefs need their final drawn position for the bounds check.
                try stave.draw()
                try voice.draw(context: context, stave: stave)
            }
        }
    }
}
