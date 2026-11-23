import Testing
@testable import VexFoundation

// VexFlow 5.9.0 cases. The drawing code is in `Upstream59Scenes`; the asserts are in `Upstream59NotationTests`.
extension UpstreamSVGParityTests {
    @Test("FrenchLuteNote.French_fret_letters_and_open_bass_courses")
    func frenchLuteNoteExerciseMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "FrenchLuteNote", test: "French_fret_letters_and_open_bass_courses", width: 520, height: 320,
            referenceFontsOverride: ["Bravura"]
        ) { factory, context in
            _ = try Upstream59Scenes.frenchLuteExercise(factory, context)
        }
    }
}
