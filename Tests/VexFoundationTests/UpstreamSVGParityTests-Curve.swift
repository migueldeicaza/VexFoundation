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
            ).setStyle(ElementStyle(lineDash: "10 10"))
        }
    }

    @Test("Curve.Opening_Direction___up")
    func curveOpeningDirectionUpMatchesUpstream() throws {
        try runCurveParityCase(testName: "Opening_Direction___up", noteGroup1: ("c4/8, f5, d5, g5", ["stem": "up"]), noteGroup2: ("d6/8, f5, d5, g5", ["stem": "down"])) { factory, notes in
            _ = factory.Curve(from: notes[0], to: notes[3], options: CurveOptions(openingDirection: .up))
            _ = factory.Curve(from: notes[4], to: notes[7], options: CurveOptions(openingDirection: .up))
        }
    }

    @Test("Curve.Opening_Direction___down")
    func curveOpeningDirectionDownMatchesUpstream() throws {
        try runCurveParityCase(testName: "Opening_Direction___down", noteGroup1: ("c4/8, f5, d5, g5", ["stem": "up"]), noteGroup2: ("d6/8, f5, d5, g5", ["stem": "down"])) { factory, notes in
            _ = factory.Curve(from: notes[0], to: notes[3], options: CurveOptions(openingDirection: .down))
            _ = factory.Curve(from: notes[4], to: notes[7], options: CurveOptions(openingDirection: .down))
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
            ).setStyle(ElementStyle(lineDash: "20"))
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

    // VexFlow 5.1.0: Curve.getBoundingBox().
    @Test("Curve.Bounding_Box")
    func curveBoundingBoxMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Curve", test: "Bounding_Box", width: 350, height: 200) { factory, context in
            let stave = factory.Stave(y: 50)
            let score = factory.EasyScore()
            let notes = score.notes("c4/8, f5, d5, g5, d6, f5, d5, g5", options: ["stem": "up"])

            let curves: [Curve] = [
                factory.Curve(from: notes[0], to: notes[3], options: CurveOptions(cps: [(x: 0, y: 10), (x: 0, y: 50)])),
                factory.Curve(from: notes[4], to: notes[7], options: CurveOptions(thickness: 5, xShift: -10, invert: true)),
                factory.Curve(from: notes[4], to: notes[7], options: CurveOptions(cps: [(x: 20, y: 30), (x: -20, y: -30)]))
                    .setStyle(ElementStyle(lineDash: "10 10")),
                factory.Curve(from: notes[1], to: nil), // partial curve
                factory.Curve(from: notes[5], to: notes[6], options: CurveOptions(position: .nearTop, positionEnd: .nearTop)),
            ]

            let voices = [score.voice(notes.map { $0 as Note }, time: .meter(4, 4))]
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()

            for curve in curves {
                let bb = try #require(curve.getBoundingBox())
                context.beginPath()
                context.rect(bb.x, bb.y, bb.w, bb.h)
                context.stroke()
            }
        }
    }
}
