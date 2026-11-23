import Testing
@testable import VexFoundation

// VexFlow 5.9.0 cases. The drawing code is in `Upstream59Scenes`; the asserts are in `Upstream59NotationTests`.
extension UpstreamSVGParityTests {
    @Test("KeySignature.Written_key_signs_follow_the_active_clef")
    func keySignatureWrittenKeySignsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "KeySignature", test: "Written_key_signs_follow_the_active_clef", width: 560, height: 155
        ) { factory, context in
            _ = try Upstream59Scenes.writtenKeySigns(factory, context)
        }
    }

    @Test("KeySignature.Edition_defined_Sab__signatures")
    func keySignatureEditionDefinedSabaMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "KeySignature", test: "Edition_defined_Sab__signatures", width: 690, height: 150
        ) { factory, context in
            _ = try Upstream59Scenes.namedMakam(factory, context)
        }
    }
}
