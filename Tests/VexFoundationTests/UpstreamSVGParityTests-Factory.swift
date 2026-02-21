import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Factory.Draw")
    func factoryDrawMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Factory", test: "Draw", width: 500, height: 200) { factory, _ in
            _ = factory.Stave().setClef(.treble)
            try factory.draw()
        }
    }

    @Test("Factory.Draw_Tab__repeat_barlines_must_be_aligned_")
    func factoryDrawTabRepeatBarlinesMustBeAlignedMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Factory",
            test: "Draw_Tab__repeat_barlines_must_be_aligned_",
            width: 500,
            height: 400
        ) { factory, _ in
            let system = factory.System(options: SystemOptions(width: 500))
            let stave = factory.Stave()
                .setClef(.treble)
                .setKeySignature("C#")
                .setBegBarType(.repeatBegin)
            let voices = [factory.Voice().addTickables([factory.GhostNote(duration: .whole)])]
            _ = system.addStave(SystemStave(voices: voices, stave: stave))

            let tabStave = factory.TabStave()
                .setClef(.tab)
                .setBegBarType(.repeatBegin)
            let tabVoices = [factory.Voice().addTickables([factory.GhostNote(duration: .whole)])]
            _ = system.addStave(SystemStave(voices: tabVoices, stave: tabStave))

            try factory.draw()
        }
    }
}
