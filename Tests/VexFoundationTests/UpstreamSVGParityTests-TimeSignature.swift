import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    // VexFlow 5.1.0: TimeSignature.getBoundingBox().
    @Test("TimeSignature.Bounding_Box_Test")
    func timeSignatureBoundingBoxTestMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "TimeSignature", test: "Bounding_Box_Test", width: 600, height: 120) { _, context in
            let stave = Stave(x: 10, y: 10, width: 500)
            for raw in ["(2+3)/16", "+", "3/8", "4/4", "C", "5322/3", "3/54444"] {
                _ = stave.addTimeSignature(try #require(TimeSignatureSpec(parsing: raw)))
            }
            _ = stave.setContext(context)
            try stave.drawWithStyle()

            for timeSignature in stave.getModifiers() {
                guard let bb = timeSignature.getBoundingBox() else { continue }
                context.beginPath()
                context.rect(bb.x, bb.y, bb.w, bb.h)
                context.stroke()
            }
        }
    }
}
