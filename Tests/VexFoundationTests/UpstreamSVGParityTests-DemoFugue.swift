import Foundation
import Testing
@testable import VexFoundation

// Port of upstream `tests/demos/fugue.ts` and its shared data `tests/scores/fugue.js` (VexFlow 5.6.1).
// J. S. Bach, BWV 851. Source: Bach-Gesellschaft (1866), public-domain engraving by Stelios Samelis
// for Mutopia, no. 988. Each bar lists treble then bass. Parallel voices on a staff are ordered high
// to low. A nil staff has a whole-measure rest. Spacers let a voice enter partway through a bar.
private enum BachFugue {
    enum Staff {
        case rest
        case one(String)
        case many([String])
    }

    // Only the opening bars that the demo engraves are kept (upstream `fugueBars.slice(0, count)`).
    static let bars: [(Staff, Staff)] = [
        // Bar 1
        (.one(#"B4/8/r, D4/8[dynamic="mp"], E4/8, F4/8, G4/8, E4/8"#), .rest),
        // Bar 2
        (
            .one(#"F4/16[id="r2-0-0"], D4/16, C#4/16, D4/16[id="r2-3-0"], Bb4/q[id="r2-4-0",articulations="staccatissimo.above"], G4/q[ornament="tr.above"]"#),
            .rest
        ),
        // Bar 3
        (
            .one(#"A4/q[id="r3-0-0",dynamic="p"], A4/16[id="r3-4-0"], G4/16, F4/16, E4/16, G4/16, F4/16, E4/16, D4/16"#),
            .one("C4/8/r, A3/8, B3/8, C4/8, D4/8, B3/8")
        ),
        // Bar 4
        (
            .many([
                #"E4/8, C5/8[id="r4-2-0"], C5/16[id="r4-4-0"], B4/16, A4/16, B4/16, B4/16, A4/16, G#4/16, A4/16"#,
                #"B4/q/r[spacer="yes"], F4/q, D4/q[ornament="tr.below"]"#,
            ]),
            .one(#"C4/16, A3/16, G#3/16, A3/16, D3/h/r[spacer="yes"]"#)
        ),
        // Bar 5
        (
            .many([
                #"A4/16[id="r5-0-0"], G4/16, F#4/16, G4/16, E5/q[articulations="staccatissimo.above"], G4/q[id="r5-8-0"]"#,
                #"E4/q[id="r5-0-1"], E4/16[id="r5-4-1"], D4/16, C#4/16, B3/16, D4/16, C#4/16, B3/16, A3/16"#,
            ]),
            .rest
        ),
        // Bar 6
        (
            .many([
                #"F4/8, D5/8[id="r6-2-0"], D5/16[id="r6-4-0"], C5/16, Bb4/16, A4/16, C5/16, Bb4/16, A4/16, G4/16"#,
                #"D4/q[dynamic="mf"], D4/q/r, D4/q/r"#,
            ]),
            .one("D3/8/r, D3/8, E3/8, F3/8, G3/8, E3/8")
        ),
        // Bar 7
        (
            .many([
                #"A4/q, G4/h[id="r7-4-0"]"#,
                #"C4/8/r, F4/8[id="r7-2-1"], F4/16[id="r7-4-1"], E4/16, D4/16, E4/16, E4/16, D4/16, C#4/16, D4/16"#,
            ]),
            .one(#"F3/16, D3/16, C#3/16, D3/16, Bb3/q[articulations="staccatissimo.above"], G3/q[ornament="tr.above"]"#)
        ),
        // Bar 8
        (
            .many([#"G4/8[id="r8-0-0"], E4/8, F4/8, G4/8, A4/8, F4/8"#, "C#4/q, D4/8, E4/8, C#4/8, D4/8"]),
            .one(#"A3/q[id="l8-0-0"], A3/16[id="l8-4-0"], G3/16, F3/16, E3/16, G3/16, F3/16, E3/16, D3/16"#)
        ),
    ]

    // Named endpoints keep sustained notes connected when the music wraps to a new system.
    static let phrases: [(ContinuousSpanKind, String, String, ContinuousSpanSide)] = [
        (.crescendo, "r5-0-0", "r5-8-0", .below),
        (.crescendo, "r38-0-0", "r38-11-0", .below),
        (.diminuendo, "r2-0-0", "r2-4-0", .below),
        (.slur, "r2-0-0", "r2-3-0", .above),
        (.tie, "r3-0-0", "r3-4-0", .above),
        (.tie, "r4-2-0", "r4-4-0", .above),
        (.tie, "r6-2-0", "r6-4-0", .above),
        (.tie, "r7-4-0", "r8-0-0", .above),
        (.tie, "r12-0-0", "r13-0-0", .above),
        (.tie, "r15-2-0", "r15-4-0", .above),
        (.tie, "r5-0-1", "r5-4-1", .below),
        (.tie, "r7-2-1", "r7-4-1", .below),
        (.tie, "r16-8-1", "r17-0-1", .below),
        (.tie, "r18-0-0", "r18-4-0", .above),
        (.tie, "r19-0-0", "r20-0-0", .above),
        (.tie, "r20-0-0", "r20-4-0", .above),
        (.tie, "r21-0-0", "r21-4-0", .above),
        (.tie, "r23-8-0", "r24-0-0", .above),
        (.tie, "r25-0-0", "r25-4-0", .above),
        (.tie, "r28-8-0", "r29-0-0", .above),
        (.tie, "r29-8-0", "r30-0-0", .above),
        (.tie, "r30-2-0", "r30-4-0", .above),
        (.tie, "r34-0-0", "r34-4-0", .above),
        (.tie, "r36-2-0", "r36-4-0", .above),
        (.tie, "r37-2-0", "r37-4-0", .above),
        (.tie, "r38-2-0", "r38-4-0", .above),
        (.tie, "r40-0-0", "r40-4-0", .above),
        (.tie, "r41-0-0", "r42-0-0", .above),
        (.tie, "r42-0-0", "r42-4-0", .above),
        (.tie, "l8-0-0", "l8-4-0", .above),
        (.tie, "l9-2-0", "l9-4-0", .above),
        (.tie, "l13-0-0", "l13-4-0", .above),
        (.tie, "l27-0-1", "l27-4-1", .below),
    ]

    /// Format the ornaments on their own voice's side of the staff. Spacers carry time through a hand change.
    static func noteMarks(_ options: [String: String], _ note: StemmableNote, _ builder: Builder) {
        if let dynamic = options["dynamic"] {
            let text = dynamic.map { TextDynamics.GLYPHS[$0] ?? "" }.joined()
            _ = note.addModifier(
                builder.getFactory()
                    .Annotation(text: text, vJustify: .bottom, font: FontInfo(family: "Bravura", size: 23))
                    .setYShift(5)
            )
        }
        if let ornament = options["ornament"] {
            let parts = ornament.split(separator: ".").map(String.init)
            let position: ModifierPosition? = parts.count > 1 ? (parts[1] == "above" ? .above : .below) : nil
            _ = note.addModifier(builder.getFactory().Ornament(parts[0], position: position))
        }
        if options["spacer"] != nil {
            _ = note.setStyle(ElementStyle(fillStyle: "transparent", strokeStyle: "transparent"))
        }
    }

    /// Share the music through the requested bar, omitting ties that end beyond the excerpt.
    static func music(_ count: Int) throws -> EasyScoreCompositionSpec {
        let bars = Array(bars.prefix(count))
        let staves = try [ClefName.treble, ClefName.bass].enumerated().map { hand, clef in
            EasyScoreStaveSpec(
                id: clef == .treble ? "treble" : "bass",
                clef: clef,
                key: "Dm",
                time: .meter(3, 4),
                measures: try bars.enumerated().map { index, bar -> EasyScoreMeasureSpec in
                    let music = hand == 0 ? bar.0 : bar.1
                    switch music {
                    case .rest:
                        // A centered whole rest fills this silent 3/4 bar before the next subject entry.
                        let rest = try StaveNoteStruct(
                            parsingKeys: ["d/3"],
                            duration: "wr",
                            alignCenter: true,
                            durationOverride: Fraction(3, 4),
                            clef: clef
                        )
                        return EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [.note(rest)])])
                    case .one(let notes):
                        // Beam the five eighths of the opening subject and its two answers as a single gesture.
                        let entrance = hand == 0 ? index == 0 : (index == 2 || index == 5)
                        let autoBeam = entrance
                            ? EasyScoreAutoBeamOptions(groups: [Fraction(3, 4)])
                            : EasyScoreAutoBeamOptions()
                        return EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes, autoBeam: autoBeam)])
                    case .many(let voices):
                        return EasyScoreMeasureSpec(voices: voices.enumerated().map { i, notes in
                            EasyScoreVoiceSpec(
                                notes,
                                stem: i == 0 ? "up" : "down",
                                autoBeam: EasyScoreAutoBeamOptions(autoStem: false)
                            )
                        })
                    }
                },
                name: hand == 0 ? "Piano" : nil,
                shortName: hand == 0 ? "Pno." : nil
            )
        }
        // Give the moving voices room. Catch only the held bass and release at the next attack.
        let pedal: [(Int, String, String)] = [
            (8, "l8-0-0", "l8-4-0"),
            (21, "l21-0-1", "l21-4-1"),
            (28, "l28-0-0", "l28-4-0"),
            (43, "l43-2-0", "l43-4-0"),
        ]
        let sections: [(Int, String)] = [
            (1, "Subject"),
            (3, "Answer"),
            (6, "Bass entry"),
            (22, "Inversion"),
            (34, "Stretto"),
            (43, "Cadence"),
        ]
        var spans = phrases
            .filter { _, _, to, _ in
                Int(to.dropFirst().split(separator: "-")[0]).map { $0 <= count } ?? false
            }
            .map { kind, from, to, side in
                ContinuousSpan(id: "\(kind.rawValue)-\(from)", kind: kind, from: from, to: to, side: side)
            }
        for (bar, from, to) in pedal where bar <= count {
            spans.append(ContinuousSpan(id: "pedal-\(bar)", kind: .pedal, from: from, to: to, text: "Ped."))
        }
        return EasyScoreCompositionSpec(
            staves: staves,
            sheet: SheetOptions(measurePadding: 15),
            system: SystemOptions(spaceBetweenStaves: 9, details: SystemFormatterOptions(spacing: .optical)),
            accidentals: .keyAware,
            continuous: ContinuousOptions(
                boundaries: sections
                    .filter { measure, _ in measure <= count }
                    .map { measure, rehearsal in ContinuousBoundary(measure: measure, rehearsal: rehearsal) },
                spans: spans,
                measureNumbers: true,
                groups: [ContinuousGroup(first: "treble", last: "bass", type: .brace, barlines: true)]
            )
        )
    }
}

extension UpstreamSVGParityTests {

    // MARK: - Fugue No. 6 in D minor (tests/demos/fugue.ts)

    /// The excerpt includes the subject, answer, and third entrance in the bass.
    @Test("Demo___Fugue_No__6_in_D_minor.Fugue_No__6_in_D_minor")
    func demoFugueMatchesUpstream() throws {
        let width = 1300.0
        try runCategorySVGParityCase(
            module: "Demo___Fugue_No__6_in_D_minor",
            test: "Fugue_No__6_in_D_minor",
            width: width,
            height: 640
        ) { factory, context in
            let score = factory.EasyScore(options: EasyScoreOptions(
                factory: factory, throwOnError: true, extensions: ["spacer", "ornament", "dynamic"]
            ))
            score.addCommitHook(BachFugue.noteMarks)
            var music = try BachFugue.music(8)
            music.system.spaceBetweenStaves = 6
            music.sheet = SheetOptions(width: width - 36, x: 18, y: 18, rowGap: 18, measurePadding: 18)
            let composition = try score.compose(music)
            _ = try composition.sheet.format()
            _ = context.resize(width, (composition.sheet.getHeight() + 24).rounded(.up))
            try factory.draw()
            #expect(composition.systems.count == 8, "Eight complete measures")
            #expect(composition.staves.allSatisfy { $0.count == 2 }, "Both hands share the grand staff throughout")
        }
    }
}
