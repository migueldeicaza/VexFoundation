import Foundation
import Testing
@testable import VexFoundation

// Ports of upstream `tests/demo_repertoire_tests.ts` and `tests/demos/*.ts` (VexFlow 5.6.1).
// Upstream registers each demo as the QUnit module `Demo - <title>` with the test name `<title>`.
// Upstream uses `EasyScore({ throwOnError: true })`. These ports use the throwing Swift methods
// (`notesThrowing`, `voiceThrowing`) so that an error stops the case.
extension UpstreamSVGParityTests {

    // MARK: - When the Saints Go Marching In (tests/demos/saints.ts)

    /// Upstream runs this demo only with the "Petaluma with Academico" font stack (VexFlow 5.6.0).
    @Test("Demo___When_the_Saints_Go_Marching_In.When_the_Saints_Go_Marching_In")
    func demoSaintsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___When_the_Saints_Go_Marching_In",
            test: "When_the_Saints_Go_Marching_In",
            width: 900,
            height: 540,
            referenceFontsOverride: ["Petaluma_with_Academico"]
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            let lyricFont = Metrics.getFontInfo("Annotation.lyric")
            // Use the same baseline throughout each row, below the pickup's low C.
            func word(_ text: String, _ rowY: Double) throws -> Annotation {
                try factory.Annotation(text: text, vJustify: .bottom, font: lyricFont)
                    .setTextBaseline(rowY + 116)
                    .setConnectorPadding(2)
            }
            let bars: [(String, String, String)] = [
                ("G4/w", "saints", "C:6/9"),
                ("B4/q/r, C4/q, E4, F4", "|go|march-|ing", "Am:7"),
                ("G4/w", "in", "Dm:11"),
                ("B4/q/r, C4/q, E4, F4", "|Oh|when|the", "G:13"),
                ("G4/q, E4, C4, E4", "saints|go|march-|ing", "C:maj9"),
                ("D4/w", "in", "Am:11"),
                ("D4/w", "", "D:9"),
                ("B4/q/r, E4/q, E4, D4", "|Oh|Lord,|I", "G:13"),
                ("C4/h, C4/q, E4", "want|to|be", "Gm:13"),
                ("G4/h, G4/q, G4", "in|that|num-", "C:9"),
                ("F4/w", "ber", "F:maj9"),
                ("B4/q/r, C4/q, E4, F4", "|Oh|when|the", "Fm:maj7"),
                ("G4/h, E4/q, C4", "saints|go|march-", "Em:7"),
                ("D4/w", "ing", "Db:7b9"),
                ("C4/w", "in", "C:6/9"),
                ("C4/q", "", ""),
            ]
            // The first system includes a short anacrusis before its four complete measures.
            let pickup = try score.notesThrowing("C4/q, E4, F4")
            let pickupLabels = ["Oh", "when", "the"]
            for (i, note) in pickup.enumerated() {
                _ = note.addModifier(try word(pickupLabels[i], 16))
            }
            let pickupWidth = 210.0
            _ = factory
                .System(options: SystemOptions(x: 10, width: pickupWidth, y: 16))
                .addStave(SystemStave(voices: [try score.voiceThrowing(pickup.map { $0 as Note }, time: .meter(3, 4))]))
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))

            // The first row shares space between the pickup, two single-word bars and two busier bars.
            let openingWidths: [Double] = [120, 212, 122, 212]
            var x = 10 + pickupWidth
            var sustained: StemmableNote?
            for (i, bar) in bars.enumerated() {
                let (music, words, harmony) = bar
                let row = i / 4
                let column = i % 4
                let y = Double(16 + row * 130)
                if column == 0 && row > 0 { x = 10 }
                let width = row == 0 ? openingWidths[column] : 219
                let notes = try score.notesThrowing(music)
                // Carry the sustained D and the final tonic across the barline without repeating a syllable.
                if i == 5 || i == 14 { sustained = notes[0] }
                if (i == 6 || i == 15), let sustained { _ = try score.make.tie(from: sustained, to: notes[0]) }
                for (n, text) in words.split(separator: "|", omittingEmptySubsequences: false).enumerated()
                where !text.isEmpty {
                    _ = notes[n].addModifier(try word(String(text), y))
                }
                // Split the chord into root and extension so Petaluma supplies proper accidental glyphs.
                if !harmony.isEmpty {
                    let parts = harmony.split(separator: ":", maxSplits: 1).map(String.init)
                    let chord = factory
                        .ChordSymbol()
                        .addGlyphOrText(parts[0])
                        .addGlyphOrText(parts[1], symbolModifier: .sup)
                    _ = notes[0].addModifier(chord)
                }
                let stave = factory
                    .System(options: SystemOptions(x: x, width: width, y: y))
                    .addStave(SystemStave(voices: [
                        try score.voiceThrowing(notes.map { $0 as Note }, time: i == 15 ? .meter(1, 4) : .meter(4, 4)),
                    ]))
                x += width
                if column == 0 && row > 0 { _ = stave.addClef(.treble) }
                if i == bars.count - 1 { _ = stave.setEndBarType(.end) }
            }
            try factory.draw()
        }
    }

    // MARK: - Greensleeves (tests/demos/greensleeves.ts)

    @Test("Demo___Greensleeves.Greensleeves")
    func demoGreensleevesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___Greensleeves",
            test: "Greensleeves",
            width: 900,
            height: 486
        ) { factory, _ in
            // Written guitar pitches sound an octave lower. Each pair is [string, fret], counting from high E.
            let positions: [String: (Int, Int)] = [
                "E3": (6, 0), "F3": (6, 1), "G3": (6, 3), "A3": (5, 0), "B3": (5, 2), "C4": (5, 3),
                "D4": (4, 0), "E4": (4, 2), "F4": (4, 3), "G4": (3, 0), "G#4": (3, 1), "A4": (3, 2),
                "B4": (2, 0), "C5": (2, 1), "D5": (2, 3), "E5": (1, 0), "F5": (1, 1),
            ]
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            let bars: [(String, String)] = [
                ("", "A4/q"),
                ("Am", "A3+E4+A4+C5/h D5/q"),
                ("C", "C4+G4+C5+E5/q. F5/8 E5/q"),
                ("G", "G3+D4+G4+D5/h B4/q"),
                ("Em", "E3+B3+G4/q. A4/8 B4/q"),
                ("Am", "A3+E4+A4+C5/h A4/q"),
                ("Dm/F", "F3+D4+A4/q. G#4/8 A4/q"),
                ("E", "E3+E4+B4/h G#4/q"),
                ("E5", "E3+B3+E4/h"),
            ]
            for (i, bar) in bars.enumerated() {
                let (chordName, barText) = bar
                let row = i >= 5 ? 1 : 0
                let width = Double(row != 0 ? 218 : i == 0 ? 112 : 190)
                let x = row != 0 ? 12 + Double(i - 5) * width : i == 0 ? 12 : 124 + Double(i - 1) * width
                let y = Double(28 + row * 230)
                // Read each voicing low to high so chord indexes agree on the staff and tab.
                let events: [(pitches: [String], duration: String)] = barText.split(separator: " ").map { token in
                    let parts = token.split(separator: "/").map(String.init)
                    return (parts[0].split(separator: "+").map(String.init), parts[1])
                }
                let music = events.map { event -> String in
                    let chord = event.pitches.count == 1 ? event.pitches[0] : "(\(event.pitches.joined(separator: " ")))"
                    return "\(chord)/\(event.duration)"
                }
                let notes = try score.notesThrowing(music.joined(separator: ", "))
                if !chordName.isEmpty {
                    _ = notes[0].addModifier(
                        try score.make.chordSymbol().addText(chordName)
                    )
                }
                let tab: [TabNote] = try events.map { event in
                    try score.make.tabNote(TabNoteStruct(
                        positions: event.pitches.map { pitch in
                            let (str, fret) = positions[pitch]!
                            return TabNotePosition(str: str, fret: fret)
                        },
                        duration: event.duration.replacingOccurrences(of: ".", with: ""),
                        dots: event.duration.contains(".") ? 1 : 0
                    ))
                }
                if i == 1 || i == 5 {
                    _ = notes[0].addModifier(try score.make.fingering(number: "1", position: .left), index: 3)
                    _ = notes[0].addModifier(try score.make.fingering(number: "2", position: .left), index: 1)
                }
                if i == 2 || i == 8 { _ = notes[0].addModifier(try score.make.stroke(.arpeggioDirectionless)) }
                if i == 2 || i == 6 { _ = try score.make.curve(from: notes[1], to: notes[2]) }
                // The opening pickup and the shortened closing bar together fill a measure.
                let time: TimeSignatureSpec = i == 0 ? .meter(1, 4) : i == bars.count - 1 ? .meter(2, 4) : .meter(3, 4)
                let system = factory.System(options: SystemOptions(spaceBetweenStaves: 8, x: x, width: width, y: y))
                let stave = system.addStave(SystemStave(
                    voices: [try score.voiceThrowing(notes.map { $0 as Note }, time: time)],
                    options: StaveOptions(topTextPosition: 3.5)
                ))
                let tablature = system.addStave(SystemStave(
                    voices: [try score.voiceThrowing(tab.map { $0 as Note }, time: time)],
                    stave: try score.make.tabStave(x: x, y: y, width: width)
                ))
                if i == 0 || i == 5 {
                    _ = stave.addClef(.treble, size: .default, annotation: .octaveDown)
                    if i == 0 { _ = stave.addTimeSignature(.meter(3, 4)) }
                    _ = tablature.addClef(.tab)
                    system.addConnector(type: .bracket)
                }
                if i == bars.count - 1 {
                    _ = stave.setEndBarType(.end)
                    _ = tablature.setEndBarType(.end)
                }
            }
            try factory.draw()
        }
    }

    // MARK: - Prelude in C major (tests/demos/prelude.ts)

    @Test("Demo___Prelude_in_C_major.Prelude_in_C_major")
    func demoPreludeMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___Prelude_in_C_major",
            test: "Prelude_in_C_major",
            width: 900,
            height: 525
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            let harmonies = [
                ["C4", "E4", "G4", "C5", "E5"],
                ["C4", "D4", "A4", "D5", "F5"],
                ["B3", "D4", "G4", "D5", "F5"],
                ["C4", "E4", "G4", "C5", "E5"],
            ]
            for (i, harmony) in harmonies.enumerated() {
                let (bass, inner, a, b, c) = (harmony[0], harmony[1], harmony[2], harmony[3], harmony[4])
                let system = factory.System(options: SystemOptions(
                    spaceBetweenStaves: 9,
                    x: 24 + Double(i % 2) * 428,
                    width: 428,
                    y: 40 + Double(i / 2) * 250
                ))
                let treble = system.addStave(SystemStave(voices: []))
                // Dynamics sit below the bass stave, leaving the space between the hands clear for the beams.
                let dynamic = ["p", "", "mf", "p"][i]
                let lower = system.addStave(SystemStave(
                    voices: dynamic.isEmpty ? [] : [
                        try score.voiceThrowing([
                            try score.make.textDynamics(TextNoteStruct(duration: "w", text: dynamic, line: 10)),
                        ]),
                    ]
                ))
                if i % 2 == 0 {
                    _ = treble.addClef(.treble)
                    _ = lower.addClef(.bass)
                    system.addConnector(type: .brace)
                    if i == 0 {
                        _ = try treble.addTimeSignature(.commonTime)
                            .setTempo(parsingDuration: "q", bpm: 72, name: "Andante, legato", y: -9)
                        _ = lower.addTimeSignature(.commonTime)
                    }
                }
                var arpeggio: [StemmableNote] = []
                for half in 0..<2 {
                    let left = try score.notesThrowing("\(bass)/16, \(inner)", options: ["clef": "bass", "stem": "up"])
                    let right = try score.notesThrowing("\(a)/16, \(b)", options: ["stem": "down"])
                    let answer = try score.notesThrowing("\(c)/16, \(a), \(b), \(c)", options: ["stem": "down"])
                    left.forEach { _ = $0.setStave(lower) }
                    (right + answer).forEach { _ = $0.setStave(treble) }
                    _ = try score.beamThrowing(left + right)
                    _ = try score.beamThrowing(answer)
                    // Lean into the upper F at the dominant, then give the resolving E its full length.
                    if half == 0 && i >= 2 {
                        _ = answer[0].addModifier(
                            try score.make.articulation(type: i == 2 ? "accent" : "tenuto", position: .above)
                        )
                    }
                    arpeggio.append(contentsOf: left + right + answer)
                }
                if i == 1 || i == 2 {
                    _ = try score.make.hairpin(
                        from: arpeggio[0],
                        to: arpeggio[8],
                        type: i == 1 ? .crescendo : .decrescendo,
                        options: HairpinRenderOptions(leftShiftPx: i == 2 ? 30 : 0, height: 7, yShift: -6)
                    )
                }
                system.addVoices([try score.voiceThrowing(arpeggio.map { $0 as Note })])
                system.addConnector(type: .singleRight)
            }
            try factory.draw()
        }
    }

    // MARK: - The Kesh Jig (tests/demos/kesh.ts)

    @Test("Demo___The_Kesh_Jig.The_Kesh_Jig")
    func demoKeshMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___The_Kesh_Jig",
            test: "The_Kesh_Jig",
            width: 900,
            height: 580
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            _ = score.set(time: .meter(6, 8))
            // Each bar is [firstBeat, secondBeat, chord, nextChord]. An empty string means no chord.
            let strains: [[(String, String, String, String)]] = [
                [
                    ("G4/q, G4/8", "G4/8, A4, B4", "G", ""),
                    ("A4/q, A4/8", "A4/8, B4, D5", "D", ""),
                    ("E5/8, D5, D5", "G5/8, D5, D5", "G", ""),
                    ("E5/8, D5, B4", "D5/8, B4, A4", "", "D"),
                    ("G4/q, G4/8", "G4/8, A4, B4", "G", ""),
                    ("A4/q, A4/8", "A4/8, B4, D5", "D", ""),
                    ("E5/8, D5, D5", "G5/8, D5, B4", "G", ""),
                    ("A4/8, G4, F4", "G4/q, D4/8", "D", "G"),
                    ("A4/8, G4, F4", "G4/q, A4/8", "D", "G"),
                ],
                [
                    ("B4/q, B4/8", "D5/8, B4, D5", "G", ""),
                    ("E5/8, G5, E5", "D5/8, B4, G4", "C", "G"),
                    ("B4/q, B4/8", "D5/8, B4, G4", "", ""),
                    ("A4/8, B4, A4", "A4/8, G4, A4", "Am", ""),
                    ("B4/8, A4, B4", "D5/8, B4, D5", "G", ""),
                    ("E5/8, G5, E5", "D5/8, B4, D5", "C", "G"),
                    ("E5/q.", "A5/8, G5, A5", "C", "D"),
                    ("B5/8, G5, G5", "G5/q, A4/8", "G", ""),
                    ("B5/8, G5, G5", "G5/q", "G", ""),
                ],
            ]

            // The upbeat precedes the first repeat and shares a full measure with the shortened final bar.
            let pickupWidth = 130.0
            let firstY = 36.0
            _ = factory.System(options: SystemOptions(x: 16, width: pickupWidth, y: firstY))
                .addStave(SystemStave(voices: [
                    try score.voiceThrowing(try score.notesThrowing("D4/8").map { $0 as Note }, time: .meter(1, 8)),
                ]))
                .addClef(.treble)
                .addKeySignature("G")
                .addTimeSignature(.meter(6, 8))
            for (part, bars) in strains.enumerated() {
                for (i, bar) in bars.enumerated() {
                    let (firstBeat, secondBeat, chord, nextChord) = bar
                    let beats = [try score.notesThrowing(firstBeat), try score.notesThrowing(secondBeat)]
                    let notes = beats.flatMap { $0 }
                    for beat in beats where beat.count == 3 {
                        _ = try score.beamThrowing(beat)
                    }
                    if !chord.isEmpty {
                        _ = beats[0][0].addModifier(
                            try score.make.chordSymbol().addText(chord)
                        )
                    }
                    if !nextChord.isEmpty {
                        _ = beats[1][0].addModifier(
                            try score.make.chordSymbol().addText(nextChord)
                        )
                    }
                    if i == 0 || i == 4 {
                        let grace = try score.make.graceNote(
                            try GraceNoteStruct(parsingKeys: [part != 0 ? "d/5" : "b/4"], duration: "8", slash: true)
                        )
                        _ = notes[1].addModifier(try score.make.graceNoteGroup(notes: [grace], slur: true))
                    }
                    if i == 2 || i == 6 {
                        let bow = beats[0].count == 3 ? beats[0] : beats[1]
                        _ = try score.make.curve(from: bow[0], to: bow[2])
                    }

                    let firstLine = i < 4
                    let pickup = part == 0 && firstLine ? pickupWidth : 0
                    let width = (868 - pickup) / (firstLine ? 4 : 5)
                    let x = 16 + pickup + Double(firstLine ? i : i - 4) * width
                    let row = part * 2 + (firstLine ? 0 : 1)
                    let lastBar = part == 1 && i == 8
                    let stave = factory
                        .System(options: SystemOptions(x: x, width: width, y: firstY + Double(row) * 142))
                        .addStave(SystemStave(
                            voices: [try score.voiceThrowing(notes.map { $0 as Note }, time: lastBar ? .meter(5, 8) : .meter(6, 8))],
                            options: StaveOptions(topTextPosition: 2)
                        ))
                    if i == 4 || (part == 1 && i == 0) { _ = stave.addClef(.treble).addKeySignature("G") }
                    if i == 0 { _ = stave.setBegBarType(.repeatBegin).setSection(part != 0 ? "B" : "A", y: 0) }
                    if i == 7 { _ = stave.setVoltaType(.beginEnd, number: "1.", yShift: 0).setEndBarType(.repeatEnd) }
                    if i == 8 { _ = stave.setVoltaType(.begin, number: "2.", yShift: 0) }
                    if lastBar { _ = stave.setEndBarType(.end) }
                }
            }
            try factory.draw()
        }
    }

    // MARK: - Ode to Joy (tests/demos/joy.ts)

    @Test("Demo___Ode_to_Joy.Ode_to_Joy")
    func demoJoyMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___Ode_to_Joy",
            test: "Ode_to_Joy",
            width: 900,
            height: 435
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            _ = score.set(clef: .bass, time: .meter(4, 4))
            // F and C are sharp throughout, as indicated by the D major key signature.
            let duet: [(String, String)] = [
                ("F3/q, F3, G3, A3", "D3/h, A2"),
                ("A3/q, G3, F3, E3", "F2/h, A2"),
                ("D3/q, D3, E3, F3", "B2/h, G2"),
                ("F3/q., E3/8, E3/h", "A2/w"),
                ("F3/q, F3, G3, A3", "D3/h, A2"),
                ("A3/q, G3, F3, E3", "F2/h, A2"),
                ("D3/q, D3, E3, F3", "G2/h, A2"),
                ("E3/q., D3/8, D3/h", "A2/h, D2"),
            ]
            for (i, pair) in duet.enumerated() {
                let (tune, bass) = pair
                let notes = try score.notesThrowing(tune)
                let system = factory.System(options: SystemOptions(
                    spaceBetweenStaves: 10,
                    x: 24 + Double(i % 4) * 213,
                    width: 213,
                    y: 10 + Double(i / 4) * 210
                ))
                var voices = [try score.voiceThrowing(notes.map { $0 as Note })]
                // Give the two phrases different starting colors and a written destination for each swell.
                if i % 2 == 0 {
                    let dynamic = ["p", "mf", "mp", "f"][i / 2]
                    voices.append(try score.voiceThrowing([
                        try score.make.textDynamics(TextNoteStruct(duration: "w", text: dynamic, line: 10)),
                    ]))
                }
                let first = system.addStave(SystemStave(voices: voices))
                let second = system.addStave(SystemStave(voices: [
                    try score.voiceThrowing(try score.notesThrowing(bass).map { $0 as Note }),
                ]))
                if i % 4 == 0 {
                    _ = first.addClef(.bass).addKeySignature("D")
                    _ = second.addClef(.bass).addKeySignature("D")
                    if i == 0 {
                        _ = first.addTimeSignature(.meter(4, 4))
                        _ = second.addTimeSignature(.meter(4, 4))
                    }
                    system.addConnector(type: .bracket)
                }
                if i == 1 || i == 5 {
                    _ = try score.make.hairpin(
                        from: notes[0],
                        to: notes[3],
                        type: .crescendo,
                        options: HairpinRenderOptions(height: 8, yShift: -21)
                    )
                }
                if i == 0 || i == 4 {
                    _ = notes[0].addModifier(try score.make.articulation(type: "tenuto", position: .above))
                }
                if i == 3 || i == 7 { _ = try score.make.curve(from: notes[0], to: notes[1]) }
                if i == 7 {
                    _ = first.setEndBarType(.end)
                    _ = second.setEndBarType(.end)
                }
                system.addConnector(type: .singleRight)
            }
            try factory.draw()
        }
    }

    // MARK: - High Wire (tests/demos/electric.ts)

    @Test("Demo___High_Wire.High_Wire")
    func demoElectricMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___High_Wire",
            test: "High_Wire",
            width: 900,
            height: 380
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            func makeNote(_ duration: String, _ frets: (Int, Int)...) throws -> TabNote {
                try score.make.tabNote(
                    TabNoteStruct(
                        positions: frets.map { TabNotePosition(str: $0.0, fret: $0.1) },
                        duration: duration,
                        stemDirection: .down
                    ),
                    drawStem: true
                )
            }
            // A5 power chord, then a single-string call. The second bar answers with a bend up to E.
            let bars: [[TabNote]] = [
                [
                    try makeNote("q", (6, 5), (5, 7), (4, 7)),
                    try makeNote("8", (3, 5)),
                    try makeNote("8", (3, 7)),
                    try makeNote("q", (2, 5)),
                    try makeNote("q", (2, 8)),
                ],
                [try makeNote("h", (3, 7)), try makeNote("8", (3, 5)), try makeNote("8", (3, 7)), try makeNote("q", (4, 7))],
                try [5, 8, 12, 8, 5, 8, 12, 8].map { fret in try makeNote("8", (1, fret)) },
                [
                    try makeNote("q", (1, 5)), try makeNote("8", (2, 8)), try makeNote("8", (2, 5)),
                    try makeNote("h", (4, 7), (3, 9), (2, 10)),
                ],
            ]
            for (i, notes) in bars.enumerated() {
                let x = 16 + Double(i % 2) * 432
                let y = 35 + Double(i / 2) * 176
                let stave = try score.make.tabStave(x: x, y: y, width: 432)
                if i % 2 == 0 { _ = stave.addClef(.tab) }
                if i == 0 { _ = try stave.addTimeSignature(.meter(4, 4)).setTempo(parsingDuration: "q", bpm: 96, y: -8) }
                if i == 3 { _ = stave.setEndBarType(.end) }
                func legato(_ start: Int, _ label: String) throws {
                    _ = try score.make.tabTie(TieNotes(firstNote: notes[start], lastNote: notes[start + 1]), text: label)
                }
                if i == 0 {
                    _ = try score.beamThrowing(Array(notes[1..<3]))
                    try legato(1, "H")
                    _ = notes[4].addModifier(try score.make.vibrato().setVibratoWidth(30))
                } else if i == 1 {
                    _ = notes[0].addModifier(
                        try score.make.bend([
                            BendPhrase(type: Bend.UP, text: "Full"),
                            BendPhrase(type: Bend.DOWN, text: ""),
                        ])
                    )
                    _ = try score.beamThrowing(Array(notes[1..<3]))
                    _ = try score.make.tabSlide(TieNotes(firstNote: notes[1], lastNote: notes[2]))
                } else if i == 2 {
                    // Fret 12 is tapped by the picking hand. Pull off to 8, then to the held fret 5.
                    _ = try score.beamThrowing(Array(notes[0..<4]))
                    _ = try score.beamThrowing(Array(notes[4...]))
                    for start in [0, 4] {
                        try legato(start, "H")
                        try legato(start + 1, "T")
                        try legato(start + 2, "P")
                    }
                    try legato(3, "P")
                } else {
                    _ = try score.beamThrowing(Array(notes[1..<3]))
                    try legato(1, "P")
                }
                _ = factory.System(options: SystemOptions(x: x, width: 432, y: y))
                    .addStave(SystemStave(voices: [try score.voiceThrowing(notes.map { $0 as Note })], stave: stave))
            }
            try factory.draw()
        }
    }

    // MARK: - Pocket Change (tests/demos/drums.ts)

    @Test("Demo___Pocket_Change.Pocket_Change")
    func demoDrumsMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___Pocket_Change",
            test: "Pocket_Change",
            width: 900,
            height: 350
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            let hat = "g/5/x2"
            let snare = "c/5"
            func hand(_ keys: String...) throws -> StemmableNote {
                try score.make.note(StaveNoteStruct(parsingKeys: keys, duration: "8", stemDirection: .up))
            }
            let kicks = [
                "F4/q, D4/q/r, F4/8, F4, D4/q/r",
                "F4/q., F4/8, F4/q, D4/q/r",
                "F4/q, D4/q/r, F4/8, F4, D4/q/r",
                "F4/q, D4/q/r, F4/q, F4",
            ]
            for (i, kick) in kicks.enumerated() {
                let fill = i == 3
                var hands = [try hand(hat), try hand(hat), try hand(snare, hat), try hand(hat)]
                _ = hands[2].addModifier(try score.make.articulation(type: "accent", position: .above))
                _ = try score.beamThrowing(hands)
                if fill {
                    // Three strokes per quarter, descending from snare through the rack and floor toms.
                    for run in [[snare, snare, "e/5"], ["d/5", "a/4", "a/4"]] {
                        let triplet = try run.map { drum in try hand(drum) }
                        _ = try score.beamThrowing(triplet)
                        _ = try score.make.tuplet(
                            notes: triplet.map { $0 as Note },
                            options: TupletOptions(numNotes: 3, notesOccupied: 2)
                        )
                        hands.append(contentsOf: triplet)
                    }
                } else {
                    let answer = [try hand(hat), try hand(snare, hat), try hand(snare, hat), try hand(hat)]
                    // Parenthesize only the quiet snare head. The hi-hat still plays its ordinary eighth.
                    _ = answer[1].addModifier(try score.make.parenthesis(.left), index: 0)
                    _ = answer[1].addModifier(try score.make.parenthesis(.right), index: 0)
                    _ = answer[2].addModifier(try score.make.articulation(type: "accent", position: .above))
                    _ = try score.beamThrowing(answer)
                    hands.append(contentsOf: answer)
                }
                let feet = try score.notesThrowing(kick, options: ["stem": "down"])
                if i == 0 || i == 2 { _ = try score.beamThrowing(Array(feet[2..<4])) }
                let stave = factory
                    .System(options: SystemOptions(x: 16 + Double(i % 2) * 432, width: 432, y: 56 + Double(i / 2) * 148))
                    .addStave(SystemStave(voices: [
                        try score.voiceThrowing(hands.map { $0 as Note }),
                        try score.voiceThrowing(feet.map { $0 as Note }),
                    ]))
                if i % 2 == 0 { _ = stave.addClef(.percussion) }
                if i == 0 {
                    _ = try stave.addTimeSignature(.meter(4, 4))
                        .setTempo(parsingDuration: "q", bpm: 92, name: "In the pocket", y: -43)
                }
                if fill { _ = stave.setEndBarType(.repeatEnd) }
            }
            try factory.draw()
        }
    }

    // MARK: - Narrow Steps (tests/demos/quartertones.ts)

    @Test("Demo___Narrow_Steps.Narrow_Steps")
    func demoQuartertonesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___Narrow_Steps",
            test: "Narrow_Steps",
            width: 900,
            height: 340
        ) { factory, _ in
            let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true))
            _ = score.set(clef: .alto, time: .meter(5, 8))
            // Each mark belongs to one attack. Stein's half-sharp (+) and half-flat (d) are 50 cents.
            let bars: [(music: String, signs: [String])] = [
                ("D4/8, D4, E4, F4/q", ["", "+", "d", ""]),
                ("F4/8, F4, G4, A4/q", ["", "+", "", "d"]),
                ("A4/q., G4/q", ["n", "+"]),
                ("G4/8, G4, F4, E4/q", ["", "d", "+", ""]),
                ("E4/8, E4, D4, C4/q", ["", "d", "+", "++"]),
                ("D4/q., D4/q", ["d", "n"]),
            ]
            for (i, bar) in bars.enumerated() {
                let notes = try score.notesThrowing(bar.music)
                for (n, type) in bar.signs.enumerated() where !type.isEmpty {
                    let mark = try score.make.accidental(type: type)
                    if i == 2 && n == 0 { _ = mark.setAsCautionary() }
                    _ = notes[n].addModifier(mark)
                }
                if notes.count == 4 {
                    _ = try score.beamThrowing(Array(notes[0..<3]))
                    _ = try score.make.curve(from: notes[0], to: notes[2])
                }
                if i == 0 || i == 4 {
                    _ = try score.make.hairpin(
                        from: notes[0],
                        to: notes[3],
                        type: i == 0 ? .crescendo : .decrescendo,
                        options: HairpinRenderOptions(height: 7, yShift: -4)
                    )
                }
                let stave = factory
                    .System(options: SystemOptions(x: 16 + Double(i % 3) * 288, width: 288, y: 24 + Double(i / 3) * 154))
                    .addStave(SystemStave(voices: [try score.voiceThrowing(notes.map { $0 as Note })]))
                if i % 3 == 0 { _ = stave.addClef(.alto) }
                if i == 0 {
                    _ = try stave.addTimeSignature(.meter(5, 8))
                        .setTempo(parsingDuration: "8", bpm: 108, name: "Sotto voce", y: -4)
                }
                if i == 5 {
                    _ = notes[1].addModifier(try score.make.articulation(type: "fermata", position: .above))
                    _ = stave.setEndBarType(.end)
                }
            }
            try factory.draw()
        }
    }
}
