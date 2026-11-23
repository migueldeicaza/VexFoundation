import Testing
@testable import VexFoundation

// VexFlow 5.9.0 cases. The drawing code is in `Upstream59Scenes`; the asserts are in `Upstream59NotationTests`.
extension UpstreamSVGParityTests {
    @Test("ChantPhrase.Lu_mi_na_keeps_each_neume_with_its_syllable")
    func chantPhraseLuminaMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "ChantPhrase", test: "Lu_mi_na_keeps_each_neume_with_its_syllable", width: 400, height: 370,
            referenceFontsOverride: ["Bravura"]
        ) { _, context in
            _ = try Upstream59Scenes.lumina(context)
        }
    }
}
