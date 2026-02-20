// VexFoundation - Dedicated parity tests for `bach` topic (integration-style scenario).

import Testing
@testable import VexFoundation

@Suite("Bach Demo")
struct BachDemoParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    @Test func minuetStyleSystemBuildsFormatsAndSupportsRegistryLookups() {
        Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
            let registry = Registry()
            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }

            let factory = Factory(options: FactoryOptions(width: 900, height: 700))
            let score = factory.EasyScore(options: EasyScoreOptions(factory: factory, throwOnError: true))
            _ = score.set(defaults: EasyScoreDefaults(time: .meter(3, 4)))

            var x = 120.0
            let y = 80.0
            func appendSystem(_ width: Double) -> System {
                let system = factory.System(options: SystemOptions(
                    factory: factory,
                    spaceBetweenStaves: 10,
                    x: x,
                    width: width,
                    y: y
                ))
                x += width
                return system
            }

            let system1 = appendSystem(260)

            let upper1 = score.notes("D5/q[id=\"m1a\"], G4/8, A4/8, B4/8, C5/8", options: ["stem": "up"])
            let lower1 = score.notes("(G3 B3 D4)/h, A3/q", options: ["stem": "down"])

            _ = system1.addStave(SystemStave(voices: [score.voice(upper1.map { $0 as Note })]))
                .addClef(.treble)
                .addKeySignature("G")
                .addTimeSignature(.meter(3, 4))

            _ = system1.addStave(SystemStave(voices: [score.voice(lower1.map { $0 as Note })]))
                .addClef(.bass)
                .addKeySignature("G")
                .addTimeSignature(.meter(3, 4))

            let brace = system1.addConnector(type: .brace)
            let left = system1.addConnector(type: .singleLeft)
            let right = system1.addConnector(type: .singleRight)

            #expect(brace.getType() == .brace)
            #expect(left.getType() == .singleLeft)
            #expect(right.getType() == .singleRight)

            let m1a = registry.getElementById("m1a") as? StaveNote
            #expect(m1a != nil)
            guard let m1a else { return }
            _ = m1a.addModifier(factory.Fingering(number: "5"), index: 0)

            let system2 = appendSystem(220)
            let upper2 = score.notes("D5/q[id=\"m2a\"], G4, G4", options: ["stem": "up"])
            let lower2 = score.notes("B3/h.", options: ["stem": "down"])

            _ = system2.addStave(SystemStave(voices: [score.voice(upper2.map { $0 as Note })]))
            _ = system2.addStave(SystemStave(voices: [score.voice(lower2.map { $0 as Note })]))
            _ = system2.addConnector(type: .singleRight)

            let m2a = registry.getElementById("m2a") as? StaveNote
            #expect(m2a != nil)
            guard let m2a else { return }

            _ = factory.Curve(from: m1a, to: m2a)
            _ = factory.StaveTie(notes: TieNotes(firstNote: m1a, lastNote: m2a))

            system1.format()
            system2.format()

            #expect(system1.boundingBox != nil)
            #expect(system2.boundingBox != nil)
            #expect(m1a.getModifiers().count >= 1)
        }
    }
}
