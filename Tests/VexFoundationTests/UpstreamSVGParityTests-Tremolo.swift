import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Tremolo.Tremolo___Basic")
    func tremoloBasicMatchesUpstream() throws {
        try runTremoloParityCase(testName: "Tremolo___Basic", big: false)
    }

    @Test("Tremolo.Tremolo___Big")
    func tremoloBigMatchesUpstream() throws {
        try runTremoloParityCase(testName: "Tremolo___Big", big: true)
    }

    private func runTremoloParityCase(testName: String, big: Bool) throws {
        try runCategorySVGParityCase(module: "Tremolo", test: testName, width: 600, height: 200) { factory, _ in
            let score = factory.EasyScore()

            let stave1 = factory.Stave(width: 250).setEndBarType(.double)
            let notes1 = score.notes("e4/4, e4, e4, e4", options: ["stem": "up"])
            let upTremolos = [
                configuredTremolo(strokes: 3, big: big),
                configuredTremolo(strokes: 2, big: big),
                configuredTremolo(strokes: 1, big: big),
            ]
            _ = notes1[0].addModifier(upTremolos[0], index: 0)
            _ = notes1[1].addModifier(upTremolos[1], index: 0)
            _ = notes1[2].addModifier(upTremolos[2], index: 0)
            let voice1 = score.voice(notes1.map { $0 as Note })
            _ = factory.Formatter().joinVoices([voice1]).formatToStave([voice1], stave: stave1)

            let stave2 = factory
                .Stave(x: stave1.getWidth() + stave1.getX(), y: stave1.getY(), width: 300)
                .setEndBarType(.double)
            let notes2 = score.notes("e5/4, e5, e5, e5", options: ["stem": "down"])
            let downTremolos = [
                configuredTremolo(strokes: 1, big: big),
                configuredTremolo(strokes: 2, big: big),
                configuredTremolo(strokes: 3, big: big),
            ]
            _ = notes2[1].addModifier(downTremolos[0], index: 0)
            _ = notes2[2].addModifier(downTremolos[1], index: 0)
            _ = notes2[3].addModifier(downTremolos[2], index: 0)
            let voice2 = score.voice(notes2.map { $0 as Note })
            _ = factory.Formatter().joinVoices([voice2]).formatToStave([voice2], stave: stave2)

            try factory.draw()
        }
    }

    private func configuredTremolo(strokes: Int, big: Bool) -> Tremolo {
        let tremolo = Tremolo(strokes)
        if big {
            tremolo.extraStrokeScale = 1.7
            tremolo.ySpacingScale = 1.5
        }
        return tremolo
    }
}
