import Testing
@testable import VexFoundation

private enum UpstreamBachDemoError: Error {
    case missingElementID(String)
}

extension UpstreamSVGParityTests {
    @Test("Bach_Demo.Minuet_1")
    func bachDemoMinuet1MatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Bach_Demo", test: "Minuet_1", width: 1100, height: 900) { factory, _ in
            let registry = Registry()
            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }

            let score = factory.EasyScore(options: EasyScoreOptions(factory: factory, throwOnError: true))

            func asNotes(_ input: [StemmableNote]) -> [Note] {
                input.map { $0 as Note }
            }

            func combine(_ groups: [[StemmableNote]]) -> [Note] {
                groups.flatMap { $0 }.map { $0 as Note }
            }

            func staveNote(byID id: String) throws -> StaveNote {
                guard let note = registry.getElementById(id) as? StaveNote else {
                    throw UpstreamBachDemoError.missingElementID(id)
                }
                return note
            }

            func addFingering(
                id: String,
                number: String,
                position: ModifierPosition? = nil
            ) throws {
                let note = try staveNote(byID: id)
                let fingering: FretHandFinger
                if let position {
                    fingering = factory.Fingering(number: number, position: position)
                } else {
                    fingering = factory.Fingering(number: number)
                }
                _ = note.addModifier(fingering, index: 0)
            }

            func addArticulation(id: String, position: ModifierPosition) throws {
                let note = try staveNote(byID: id)
                _ = note.addModifier(factory.Articulation(type: "a.").setPosition(position), index: 0)
            }

            func addCurve(
                fromID: String,
                toID: String,
                cps: [(Double, Double)],
                invert: Bool = false,
                position: CurvePosition = .nearHead,
                positionEnd: CurvePosition = .nearHead,
                yShift: Double = 10
            ) throws {
                _ = factory.Curve(
                    from: try staveNote(byID: fromID),
                    to: try staveNote(byID: toID),
                    options: CurveOptions(
                        cps: cps,
                        yShift: yShift,
                        position: position,
                        positionEnd: positionEnd,
                        invert: invert
                    )
                )
            }

            var x = 120.0
            var y = 80.0
            var systems: [System] = []
            func appendSystem(_ width: Double) -> System {
                let system = factory.System(options: SystemOptions(
                    factory: factory,
                    spaceBetweenStaves: 10,
                    x: x,
                    width: width,
                    y: y
                ))
                systems.append(system)
                x += width
                return system
            }

            _ = score.set(defaults: EasyScoreDefaults(time: .meter(3, 4)))

            var system = appendSystem(220)
            let system1Top = system
                .addStave(SystemStave(voices: [
                    score.voice(combine([
                        score.notes(#"D5/q[id="m1a"]"#),
                        score.beam(score.notes("G4/8, A4, B4, C5", options: ["stem": "up"])),
                    ])),
                    score.voice([
                        factory.TextDynamics(TextNoteStruct(
                            duration: NoteDurationSpec(uncheckedValue: .half, dots: 1),
                            text: "p",
                            line: 9
                        )),
                    ]),
                ]))
                .addClef(.treble)
                .addKeySignature("G")
                .addTimeSignature(.meter(3, 4))
            _ = try system1Top.setTempo(parsingDuration: "h", bpm: 66, dots: 1, name: "Allegretto", y: -30)
            _ = system
                .addStave(SystemStave(voices: [score.voice(asNotes(score.notes("(G3 B3 D4)/h, A3/q", options: ["clef": "bass"])))]))
                .addClef(.bass)
                .addKeySignature("G")
                .addTimeSignature(.meter(3, 4))
            _ = system.addConnector(type: .brace)
            _ = system.addConnector(type: .singleRight)
            _ = system.addConnector(type: .singleLeft)
            try addFingering(id: "m1a", number: "5")

            system = appendSystem(150)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"D5/q[id="m2a"], G4[id="m2b"], G4[id="m2c"]"#)))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("B3/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addArticulation(id: "m2a", position: .above)
            try addArticulation(id: "m2b", position: .below)
            try addArticulation(id: "m2c", position: .below)
            try addCurve(fromID: "m1a", toID: "m2a", cps: [(0, 40), (0, 40)])

            system = appendSystem(150)
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"E5/q[id="m3a"]"#),
                score.beam(score.notes("C5/8, D5, E5, F5", options: ["stem": "down"])),
            ]))]))
            try addFingering(id: "m3a", number: "3", position: .above)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("C4/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)

            system = appendSystem(150)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"G5/q[id="m4a"], G4[id="m4b"], G4[id="m4c"]"#)))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("B3/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addArticulation(id: "m4a", position: .above)
            try addArticulation(id: "m4b", position: .below)
            try addArticulation(id: "m4c", position: .below)
            try addCurve(fromID: "m3a", toID: "m4a", cps: [(0, 20), (0, 20)])

            system = appendSystem(150)
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"C5/q[id="m5a"]"#),
                score.beam(score.notes("D5/8, C5, B4, A4", options: ["stem": "down"])),
            ]))]))
            try addFingering(id: "m5a", number: "4", position: .above)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("A3/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)

            system = appendSystem(150)
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes("B4/q"),
                score.beam(score.notes(#"C5/8, B4, A4, G4[id="m6a"]"#, options: ["stem": "up"])),
            ]))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("G3/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addCurve(
                fromID: "m5a",
                toID: "m6a",
                cps: [(0, 20), (0, 20)],
                invert: true,
                positionEnd: .nearTop,
                yShift: 20
            )

            x = 20
            y += 230

            system = appendSystem(220)
            _ = system
                .addStave(SystemStave(voices: [score.voice(combine([
                    score.notes(#"F4/q[id="m7a"]"#),
                    score.beam(score.notes(#"G4/8[id="m7b"], A4, B4, G4"#, options: ["stem": "up"])),
                ]))]))
                .addClef(.treble)
                .addKeySignature("G")
            _ = system
                .addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"D4/q, B3[id="m7c"], G3"#, options: ["clef": "bass"])))]))
                .addClef(.bass)
                .addKeySignature("G")
            _ = system.addConnector(type: .brace)
            _ = system.addConnector(type: .singleRight)
            _ = system.addConnector(type: .singleLeft)
            try addFingering(id: "m7a", number: "2", position: .below)
            try addFingering(id: "m7b", number: "1")
            try addFingering(id: "m7c", number: "3", position: .above)

            system = appendSystem(180)
            let grace = factory.GraceNote(try GraceNoteStruct(
                parsingKeys: ["d/3"],
                duration: "4",
                slash: false,
                clef: .bass
            ))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"A4/h.[id="m8c"]"#)))]))
            _ = score.set(defaults: EasyScoreDefaults(clef: .bass, time: .meter(3, 4)))
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"D4/q[id="m8a"]"#),
                score.beam(score.notes(#"D3/8, C4, B3[id="m8b"], A3"#, options: ["stem": "down"])),
            ]))]))
            _ = system.addConnector(type: .singleRight)
            try addFingering(id: "m8b", number: "1", position: .above)
            _ = try staveNote(byID: "m8c").addModifier(factory.GraceNoteGroup(notes: [grace]), index: 0)
            try addCurve(
                fromID: "m7a",
                toID: "m8c",
                cps: [(0, 20), (0, 20)],
                invert: true,
                position: .nearTop,
                positionEnd: .nearTop
            )
            _ = factory.StaveTie(notes: TieNotes(firstNote: grace, lastNote: try staveNote(byID: "m8c")))

            system = appendSystem(180)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"D5/q[id="m9a"]"#),
                score.beam(score.notes("G4/8, A4, B4, C5", options: ["stem": "up"])),
            ]))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("B3/h, A3/q", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addFingering(id: "m9a", number: "5")

            system = appendSystem(170)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"D5/q[id="m10a"], G4[id="m10b"], G4[id="m10c"]"#)))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"G3/q[id="m10d"], B3, G3"#, options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addArticulation(id: "m10a", position: .above)
            try addArticulation(id: "m10b", position: .below)
            try addArticulation(id: "m10c", position: .below)
            try addFingering(id: "m10d", number: "4")
            try addCurve(fromID: "m9a", toID: "m10a", cps: [(0, 40), (0, 40)])

            system = appendSystem(150)
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"E5/q[id="m11a"]"#),
                score.beam(score.notes("C5/8, D5, E5, F5", options: ["stem": "down"])),
            ]))]))
            try addFingering(id: "m11a", number: "3", position: .above)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("C4/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)

            system = appendSystem(170)
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"G5/q[id="m12a"], G4[id="m12b"], G4[id="m12c"]"#)))]))
            _ = score.set(defaults: EasyScoreDefaults(clef: .bass, time: .meter(3, 4)))
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"B3/q[id="m12d"]"#),
                score.beam(score.notes(#"C4/8, B3, A3, G3[id="m12e"]"#, options: ["stem": "down"])),
            ]))]))
            _ = system.addConnector(type: .singleRight)
            try addArticulation(id: "m12a", position: .above)
            try addArticulation(id: "m12b", position: .below)
            try addArticulation(id: "m12c", position: .below)
            try addFingering(id: "m12d", number: "2", position: .above)
            try addFingering(id: "m12e", number: "4", position: .above)
            try addCurve(fromID: "m11a", toID: "m12a", cps: [(0, 20), (0, 20)])

            x = 20
            y += 230

            system = appendSystem(220)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system
                .addStave(SystemStave(voices: [score.voice(combine([
                    score.notes(#"c5/q[id="m13a"]"#),
                    score.beam(score.notes("d5/8, c5, b4, a4", options: ["stem": "down"])),
                ]))]))
                .addClef(.treble)
                .addKeySignature("G")
            _ = system
                .addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"a3/h[id="m13b"], f3/q[id="m13c"]"#, options: ["clef": "bass"])))]))
                .addClef(.bass)
                .addKeySignature("G")
            _ = system.addConnector(type: .brace)
            _ = system.addConnector(type: .singleRight)
            _ = system.addConnector(type: .singleLeft)
            try addFingering(id: "m13a", number: "4", position: .above)
            try addFingering(id: "m13b", number: "1")
            try addFingering(id: "m13c", number: "3", position: .above)

            system = appendSystem(180)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes("B4/q"),
                score.beam(score.notes("C5/8, b4, a4, g4", options: ["stem": "up"])),
            ]))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"g3/h[id="m14a"], b3/q[id="m14b"]"#, options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addFingering(id: "m14a", number: "2")
            try addFingering(id: "m14b", number: "1")

            system = appendSystem(180)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes("a4/q"),
                score.beam(score.notes(#"b4/8, a4, g4, f4[id="m15a"]"#, options: ["stem": "up"])),
            ]))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"c4/q[id="m15b"], d4, d3"#, options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addFingering(id: "m15a", number: "2")
            try addFingering(id: "m15b", number: "2")

            system = appendSystem(130)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system
                .addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"g4/h.[id="m16a"]"#)))]))
                .setEndBarType(.repeatEnd)
            _ = system
                .addStave(SystemStave(voices: [score.voice(asNotes(score.notes(#"g3/h[id="m16b"], g2/q"#, options: ["clef": "bass"])))]))
                .setEndBarType(.repeatEnd)
            _ = system.addConnector(type: .boldDoubleRight)
            try addFingering(id: "m16a", number: "1")
            try addFingering(id: "m16b", number: "1")
            try addCurve(
                fromID: "m13a",
                toID: "m16a",
                cps: [(0, 50), (0, 20)],
                invert: true,
                positionEnd: .nearTop
            )

            system = appendSystem(180)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system
                .addStave(SystemStave(voices: [
                    score.voice(combine([
                        score.notes(#"b5/q[id="m17a"]"#),
                        score.beam(score.notes("g5/8, a5, b5, g5", options: ["stem": "down"])),
                    ])),
                    score.voice([
                        factory.TextDynamics(TextNoteStruct(
                            duration: NoteDurationSpec(uncheckedValue: .half, dots: 1),
                            text: "mf",
                            line: 10
                        )),
                    ]),
                ]))
                .setBegBarType(.repeatBegin)
            _ = system
                .addStave(SystemStave(voices: [score.voice(asNotes(score.notes("g3/h.", options: ["clef": "bass"])))]))
                .setBegBarType(.repeatBegin)
            _ = system.addConnector(type: .boldDoubleLeft)
            _ = system.addConnector(type: .singleRight)
            try addFingering(id: "m17a", number: "5", position: .above)

            system = appendSystem(180)
            _ = score.set(defaults: EasyScoreDefaults(clef: .treble, time: .meter(3, 4)))
            _ = system.addStave(SystemStave(voices: [score.voice(combine([
                score.notes(#"a5/q[id="m18a"]"#),
                score.beam(score.notes(#"d5/8, e5, f5, d5[id="m18b"]"#, options: ["stem": "down"])),
            ]))]))
            _ = system.addStave(SystemStave(voices: [score.voice(asNotes(score.notes("f3/h.", options: ["clef": "bass"])))]))
            _ = system.addConnector(type: .singleRight)
            try addFingering(id: "m18a", number: "4", position: .above)
            try addCurve(fromID: "m17a", toID: "m18b", cps: [(0, 20), (0, 30)])

            try factory.draw()
        }
    }
}
