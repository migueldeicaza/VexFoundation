import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Curve.Simple_Curve")
    func curveSimpleMatchesUpstream() throws {
        try runCurveParityCase(testName: "Simple_Curve", noteGroup1: ("c4/8, f5, d5, g5", ["stem": "up"]), noteGroup2: ("d6/8, f5, d5, g5", ["stem": "down"])) { factory, notes in
            _ = factory.Curve(
                from: notes[0],
                to: notes[3],
                options: CurveOptions(
                    cps: [(x: 0, y: 10), (x: 0, y: 50)]
                )
            )
            _ = factory.Curve(
                from: notes[4],
                to: notes[7],
                options: CurveOptions(
                    cps: [(x: 0, y: 10), (x: 0, y: 20)]
                )
            )
        }
    }

    @Test("Curve.Rounded_Curve")
    func curveRoundedMatchesUpstream() throws {
        try runCurveParityCase(testName: "Rounded_Curve", noteGroup1: ("c5/8, f4, d4, g5", ["stem": "up"]), noteGroup2: ("d5/8, d6, d6, g5", ["stem": "down"])) { factory, notes in
            _ = factory.Curve(
                from: notes[0],
                to: notes[3],
                options: CurveOptions(
                    cps: [(x: 0, y: 20), (x: 0, y: 50)],
                    xShift: -10,
                    yShift: 30
                )
            )
            _ = factory.Curve(
                from: notes[4],
                to: notes[7],
                options: CurveOptions(
                    cps: [(x: 0, y: 50), (x: 0, y: 50)]
                )
            )
        }
    }

    @Test("Curve.Thick_Thin_Curves")
    func curveThickThinMatchesUpstream() throws {
        try runCurveParityCase(testName: "Thick_Thin_Curves", noteGroup1: ("c5/8, f4, d4, g5", ["stem": "up"]), noteGroup2: ("d5/8, d6, d6, g5", ["stem": "down"])) { factory, notes in
            _ = factory.Curve(
                from: notes[0],
                to: notes[3],
                options: CurveOptions(
                    cps: [(x: 0, y: 20), (x: 0, y: 50)],
                    thickness: 10,
                    xShift: -10,
                    yShift: 30
                )
            )
            _ = factory.Curve(
                from: notes[4],
                to: notes[7],
                options: CurveOptions(
                    cps: [(x: 0, y: 50), (x: 0, y: 50)],
                    thickness: 0
                )
            )
        }
    }

    @Test("Curve.Top_Curve")
    func curveTopMatchesUpstream() throws {
        try runCurveParityCase(testName: "Top_Curve", noteGroup1: ("c5/8, f4, d4, g5", ["stem": "up"]), noteGroup2: ("d5/8, d6, d6, g5", ["stem": "down"])) { factory, notes in
            _ = factory.Curve(
                from: notes[0],
                to: notes[7],
                options: CurveOptions(
                    cps: [(x: 0, y: 20), (x: 40, y: 80)],
                    xShift: -3,
                    yShift: 10,
                    position: .nearTop,
                    positionEnd: .nearHead
                )
            )
        }
    }

    private func runCurveParityCase(
        testName: String,
        noteGroup1: (notes: String, options: [String: String]),
        noteGroup2: (notes: String, options: [String: String]),
        setupCurves: (Factory, [StemmableNote]) -> Void
    ) throws {
        try runCategorySVGParityCase(module: "Curve", test: testName, width: 350, height: 200) { factory, _ in
            let stave = factory.Stave(y: 50)
            let score = factory.EasyScore()

            let staveNotes: [StemmableNote] = [
                score.beam(score.notes(noteGroup1.notes, options: noteGroup1.options)),
                score.beam(score.notes(noteGroup2.notes, options: noteGroup2.options)),
            ].flatMap { $0 }

            setupCurves(factory, staveNotes)

            let voice = score.voice(staveNotes.map { $0 as Note }, time: .meter(4, 4))
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }
}
