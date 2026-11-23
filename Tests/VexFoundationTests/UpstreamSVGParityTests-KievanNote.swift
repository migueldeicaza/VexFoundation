import Testing
@testable import VexFoundation

// VexFlow 5.9.0 cases. The drawing code is in `Upstream59Scenes`; the asserts are in `Upstream59NotationTests`.
extension UpstreamSVGParityTests {
    @Test("KievanNote.Synodal_half_notes_on_lines_and_spaces")
    func kievanNoteSynodalPhraseMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "KievanNote", test: "Synodal_half_notes_on_lines_and_spaces", width: 510, height: 140,
            referenceFontsOverride: ["Bravura"]
        ) { factory, context in
            _ = try Upstream59Scenes.kievanSynodalPhrase(factory, context)
        }
    }
}
