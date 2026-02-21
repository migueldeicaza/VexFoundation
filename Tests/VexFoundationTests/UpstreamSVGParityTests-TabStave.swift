import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("TabStave.TabStave_Draw_Test")
    func tabStaveDrawTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TabStave", test: "TabStave_Draw_Test", width: 400, height: 160) { _, context in
            let stave = TabStave(x: 10, y: 10, width: 300)
            _ = stave.setNumLines(6).setContext(context)
            try stave.draw()
        }
    }
}
