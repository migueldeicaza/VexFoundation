import Foundation
import Testing
@testable import VexFoundation

@Suite("SVG Render Context")
struct SVGRenderContextTests {
    private static let regenerateEnvKey = "VEXFOUNDATION_REGENERATE_SVG_SNAPSHOTS"

    @Test func svgContextBasicPrimitives() {
        let ctx = SVGRenderContext(width: 120, height: 80)
        ctx.setFillStyle("#ff0000")
        ctx.beginPath()
        ctx.moveTo(10, 10)
        ctx.lineTo(50, 10)
        ctx.lineTo(30, 40)
        ctx.closePath()
        ctx.fill()

        _ = ctx.openGroup("debug", "g1")
        ctx.setStrokeStyle("#0000ff")
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.moveTo(5, 5)
        ctx.lineTo(115, 75)
        ctx.stroke()
        ctx.closeGroup()

        let svg = ctx.getSVG()
        #expect(svg.contains("<svg "))
        #expect(svg.contains("viewBox=\"0 0 120 80\""))
        // Upstream 5.0 svgcontext.ts serialization (checked against the jsdom output):
        // compact path data, attributes before 'd', and 'vf-' prefixed group class/id.
        #expect(svg.contains("<path fill=\"#ff0000\" stroke=\"none\" d=\"M10 10L50 10L30 40Z\"/>"))
        #expect(svg.contains("<g class=\"vf-debug\" id=\"vf-g1\" fill=\"#ff0000\">"))
        #expect(svg.contains("<path stroke-width=\"2\" fill=\"none\" stroke=\"#0000ff\" d=\"M5 5L115 75\"/>"))
        #expect(svg.contains("stroke=\"#0000ff\""))
    }

    @Test func svgContextScaleUsesViewBoxWithoutScalingGeometry() {
        let ctx = SVGRenderContext(width: 100, height: 50)
        _ = ctx.scale(0.5, 0.25)
        _ = ctx.setLineWidth(2)
        _ = ctx.beginPath()
            .moveTo(10, 10)
            .lineTo(20, 20)
            .stroke()

        let svg = ctx.getSVG()
        #expect(svg.contains("viewBox=\"0 0 200 200\""))
        #expect(svg.contains("d=\"M10 10L20 20\""))
        #expect(svg.contains("stroke-width=\"2\""))
    }

    @Test func svgSnapshotSimpleScore() throws {
        try Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            Flow.setFonts("Bravura", "Academico")

            let ctx = SVGRenderContext(width: 520, height: 180, options: SVGRenderOptions(precision: 3))
            let factory = Factory(options: FactoryOptions(width: 500, height: 160))
            _ = factory.setContext(ctx)
            let score = factory.EasyScore()

            let system = factory.System(options: SystemOptions(
                factory: factory,
                x: 10,
                width: 500,
                y: 10
            ))

            let notes = score.notes("C#5/q, B4, A4, G#4")
            _ = system.addStave(SystemStave(voices: [score.voice(notes)]))
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))

            system.format()
            try factory.draw()

            let svg = ctx.getSVG()
            let fixture = try fixturePath(named: "simple_score.svg")

            if shouldRegenerateSnapshots {
                try writeFixture(svg, to: fixture)
                return
            }

            guard FileManager.default.fileExists(atPath: fixture.path) else {
                Issue.record("Missing SVG fixture at \(fixture.path). Run tools/svg_snapshot.sh --regen.")
                return
            }

            let expected = try String(contentsOf: fixture, encoding: .utf8)
            #expect(svg == expected)
        }
    }

    private var shouldRegenerateSnapshots: Bool {
        ProcessInfo.processInfo.environment[Self.regenerateEnvKey] == "1"
    }

    private func fixturePath(named fileName: String) throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let testsDir = here.deletingLastPathComponent()
        let fixturesDir = testsDir.appendingPathComponent("Fixtures/svg", isDirectory: true)
        try FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
        return fixturesDir.appendingPathComponent(fileName)
    }

    private func writeFixture(_ contents: String, to url: URL) throws {
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
