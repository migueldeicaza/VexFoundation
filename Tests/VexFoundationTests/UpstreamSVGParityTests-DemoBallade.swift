import Foundation
import Testing
@testable import VexFoundation

// Port of upstream `tests/demos/ballade.ts` and `tests/scores/ballade.js` (VexFlow 5.6.1).
// Frédéric Chopin, Ballade No. 3, Op. 47. A reading of the supplied opening page.
// Each pair is one 6/8 measure, right hand then left. A hand with more than one string holds
// independently stemmed voices.

private enum UpstreamBalladeDemoError: Error {
    case notStaveNote(Int)
    case missingNote(bar: Int, hand: Int, voice: Int, index: Int)
}

private struct BalladeVoice {
    var notes: [StemmableNote]
    var voice: Voice
}

private struct BalladeHand {
    var stave: Stave
    var voices: [BalladeVoice]
}

private struct BalladeRow {
    var first: Int
    var top: Double
    var bass: Double
    var edges: [Double]
}

private let balladeBars: [[[String]]] = [
    // First system. The F and D in the two hands lead into the first crescendo.
    [["Eb4/q, F4/8, (Eb4 G4)/8, (Eb4 Ab4)/8, (Eb4 Bb4)/8"], ["D3/q/r, D4/8, Db4/8, C4/8, G3/8"]],
    [["(Eb4 C5)/q, (F4 Ab4 F5)/8, (Eb4 Ab4 Eb5)/q."], ["Ab3/q, (Eb3 B3 D4)/8, (Eb3 C4)/q."]],
    [["Eb5/h.", "(Eb4 G4)/q., (Eb4 G4 Db5)/q."], ["Db4/8, C4/8, Bb3/8, Bb3/8, A3/8, Bb3/8"]],
    [["(Eb4 Ab4 C5 Eb5)/h."], ["C4/8, Ab3/8., Eb3/16, Eb3/q."]],
    [["Eb4/h.", "G3/q, Ab3/8, Bb3/8, C4/8, G3/8", #"Db4/q., B4/q/r.[quiet="yes"]"#], ["Eb2/q, F2/8, G2/8, Ab2/8, Bb2/8"]],
    [["(Ab3 Eb4)/q, (Ab3 B3 D4)/8, (Ab3 C4 Eb4)/q."], ["C3/q, F3/8, Eb3/q."]],
    // Second system. Small inline clefs keep the high left-hand chords on the lower staff.
    [["(Ab3 C4 Eb4)/8, (C4 Eb4 Ab4)/8, (Db4 Eb4 Bb4)/8, (Eb4 Ab4 C5)/q, (Db4 Eb4 Bb4)/8"], ["Eb3/q., Eb3/q, Eb2/8"]],
    [["(Eb4 Ab4 C5)/q, (C4 Eb4 Ab4)/8, (C4 Eb4 Ab4)/q, B4/8/r"], ["Ab2/q, Eb3/8, Ab3/q, D3/8/r"]],
    [["(Ab5 Ab6)/q., B4/q/r, B4/8/r"], ["(Ab1 Ab2)/8, D3/8/r ;treble; (Gb4 Ab4 Eb5)/8, (F4 Ab4 D5)/q, B4/8/r"]],
    [["(Ab4 Ab5)/q., B4/8/r., (C4 C5)/16, (F4 F5)/8"], ["(Ab1 Ab2)/8, D3/8/r, (Fb3 Ab3 Db4)/8, (Eb3 Ab3 C4)/q, D3/8/r"]],
    [
        ["B4/8/r., (Eb4 Eb5)/16, (Eb4 Eb5)/8, B4/8/r., (Eb4 Eb5)/16, (Eb4 Eb5)/8"],
        ["(Eb1 Eb2)/8, D3/8/r, (Eb3 C4)/8, (D3 F3 B3)/q, D3/8/r"],
    ],
    [
        ["B4/8/r., (Eb4 Eb5)/16, (Eb4 Eb5)/8, B4/8/r., (Eb4 Eb5)/16, (Eb4 Eb5)/8"],
        ["Eb2/8, D3/8/r, (D3 F3 B3)/8, (Db3 G3 Bb3)/q, D3/8/r"],
    ],
    // Third system. Bar 14 compresses the chromatic octave flourish into the second dotted beat.
    [
        ["(Ab5 Ab6)/q., B4/q/r, B4/8/r"],
        ["(Ab1 Ab2)/8, D3/16/r ;treble; (Gb4 Ab4 Eb5)/16, (Gb4 Ab4 Eb5)/8, (F4 Ab4 D5)/q, B4/8/r"],
    ],
    [
        ["(Ab4 Ab5)/q., B4/16/r, (C4 C5)/16, (Db4 Db5)/16, (D4 D5)/16, (Eb4 Eb5)/16, (E4 E5)/16, (G4 G5)/16, B4/32/r, (F4 F5)/32"],
        ["(Ab1 Ab2)/8, D3/16/r, (Fb3 Ab3 Db4)/16, (Fb3 Ab3 Db4)/8, (Eb3 Ab3 C4)/8, D3/q/r"],
    ],
    [
        ["(F4 F5)/8., (Eb4 Eb5)/16, (Eb4 Eb5)/8, B4/8/r., (Eb4 Eb5)/16, (Eb4 Eb5)/8"],
        ["(Eb1 Eb2)/8, D3/8/r, (Eb3 C4)/8, (D3 F3 B3)/q, D3/8/r"],
    ],
    [
        ["(Eb4 Eb5)/8., (Eb4 Eb5)/16, (Eb4 Eb5)/8, B4/8/r., (Eb4 Eb5)/16, (Eb4 Eb5)/8"],
        ["Eb2/8, D3/8/r, (D3 F3 B3)/8, (Db3 G3 Bb3)/q, D3/8/r"],
    ],
    // Fourth system. Keep the long upper notes sounding over the repeated chords in bars 19-20.
    [
        ["(Eb4 Eb5)/8., Ab4/16, (F4 F5)/8, (F4 F5)/8., (Eb4 Eb5)/16, (D4 D5)/8"],
        ["(Ab1 Ab2)/8, D3/8/r, (C3 Gb3 Ab3)/8, (B2 F3 Ab3)/q."],
    ],
    [
        ["B4/8/r., Db5/16, (Db4 G4 Db5)/8, B4/8/r., (C4 Ab4 C5)/16, (Db4 Ab4 Db5)/8"],
        ["(Ab1 Ab2)/8, D3/8/r, (Ab2 Eb3 Bb3)/8, (Ab2 Eb3 Ab3)/q."],
    ],
    [
        ["(Ab4 C5)/8., Bb4/16, Bb4/8, Bb4/q.", "C4/8, E4/8/r, (Bb3 D4 Ab4)/8, E4/8/r., (Bb3 D4 Ab4)/16, (Bb3 D4 Ab4)/8"],
        ["(F1 F2)/8, D3/8/r, (G2 G3)/8, (F2 F3)/q, D3/8/r"],
    ],
    [
        [
            #"Bb4/q., B4/q/r.[quiet="yes"]"#,
            "E4/8/r., (Bb3 Db4 G4)/16, (Bb3 Db4 G4)/8, E4/8/r., (G3 Db4 Eb4)/16, (G3 Db4 Eb4)/8",
        ],
        ["(Eb1 Eb2)/8, D3/8/r, (F2 F3)/8, (Eb2 Eb3)/q, D3/8/r"],
    ],
    // Fifth system. The same figure returns an octave higher, with a little grace chord in bar 22.
    [
        ["(Ab3 C4 Ab4)/8, B4/16/r, (Eb5 Ab5 Eb6)/16, (Eb5 Ab5 Eb6)/8, (Eb5 Ab5 Eb6)/8., (D5 D6)/16, (Ab5 Ab6)/8"],
        ["(Ab1 Ab2)/8, D3/16/r, (Gb3 Ab3 Gb4)/16, (Gb3 Ab3 Gb4)/8, (F3 Ab3 F4)/q, D3/8/r"],
    ],
    [
        ["B4/8/r., (Db5 Ab5 Db6)/16, (Db5 Ab5 Db6)/8, (Db5 Ab5 Db6)/8., (C5 C6)/16, (Db5 Ab5 Db6)/8"],
        ["(Ab1 Ab2)/8, D3/16/r, (Fb3 Ab3 Fb4)/16, (Fb3 Ab3 Fb4)/8, (Eb3 Ab3 Eb4)/q, D3/8/r"],
    ],
    [
        [
            #"B4/q/r[quiet="yes"], Bb5/8, Bb5/q."#,
            "(C5 Ab5 C6)/8., (Bb4 D5 Ab5 Bb5)/16, (Bb4 D5 Ab5)/8, E5/8/r., (Bb4 D5 Ab5)/16, (Bb4 D5 Ab5)/8",
        ],
        ["(F1 F2)/8, D3/16/r, (G3 G4)/16, (G3 G4)/8, (F3 F4)/q, D3/8/r"],
    ],
    [
        [
            #"Bb5/q., B4/q/r.[quiet="yes"]"#,
            "E5/8/r., (Bb4 Db5 G5)/16, (Bb4 Db5 G5)/8, E5/8/r., (G4 Db5 Eb5)/16, (G4 Db5 Eb5)/8",
        ],
        ["(Eb1 Eb2)/8, D3/16/r, (F3 F4)/16, (F3 F4)/8, (Eb3 Eb4)/q, D3/8/r"],
    ],
]

// Barline positions follow the five systems of the scan. Only the first system is indented.
// Coordinates use the reference page at 888 units wide; the staves are drawn at normal VexFlow size.
private let balladeRows: [BalladeRow] = [
    BalladeRow(first: 1, top: 164, bass: 242, edges: [102, 288, 380, 506, 600, 721, 828]),
    BalladeRow(first: 7, top: 358, bass: 428, edges: [55, 242, 340, 480, 589, 707, 830]),
    BalladeRow(first: 13, top: 545, bass: 614, edges: [55, 285, 546, 690, 832]),
    BalladeRow(first: 17, top: 732, bass: 811, edges: [55, 302, 467, 645, 833]),
    BalladeRow(first: 21, top: 942, bass: 1010, edges: [55, 311, 504, 658, 837]),
]
private let balladeScale = 1.5
private let balladeWidth = 1332.0
private let balladeHeight = (balladeWidth * 11) / 8.5

private func balladeRow(forBar bar: Int) -> BalladeRow {
    balladeRows.last { $0.first <= bar } ?? balladeRows[0]
}

extension UpstreamSVGParityTests {

    // MARK: - Ballade No. 3 in A flat major (tests/demos/ballade.ts, tests/scores/ballade.js)

    @Test("Demo___Ballade_No__3_in_A_flat_major.Ballade_No__3_in_A_flat_major")
    func demoBalladeMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Demo___Ballade_No__3_in_A_flat_major",
            test: "Ballade_No__3_in_A_flat_major",
            width: balladeWidth,
            height: balladeHeight.rounded(.up)
        ) { factory, context in
            try drawChopinBallade(factory: factory, ctx: context)
        }
    }
}

/// Mirrors `ChopinBallade.draw` in upstream `tests/scores/ballade.js`.
private func drawChopinBallade(factory: Factory, ctx: SVGRenderContext) throws {
    let scale = balladeScale
    let rows = balladeRows
    let score = factory.EasyScore(options: EasyScoreOptions(throwOnError: true, extensions: ["quiet"]))
    _ = score.set(defaults: EasyScoreDefaults(time: .meter(6, 8)))
    score.addCommitHook { options, note, _ in
        // An inaudible gap lets a secondary voice enter at its written rhythmic position.
        if options["quiet"] != nil {
            _ = note.setStyle(ElementStyle(fillStyle: "transparent", strokeStyle: "transparent"))
        }
    }

    /// Make each voice in order; inline clefs take no time. The source does not number its octave flourish.
    func makeVoice(_ music: String, clef: String, stem: String, flourish: Bool) throws -> BalladeVoice {
        let split = music.components(separatedBy: " ;treble; ")
        let first = split[0]
        var notes = try score.notesThrowing(first, options: ["clef": clef, "stem": stem])
        var items: [Note] = notes.map { $0 as Note }
        if split.count > 1 {
            let high = try score.notesThrowing(split[1], options: ["clef": "treble", "stem": stem])
            items.append(factory.ClefNote(type: .treble, size: .small))
            items.append(contentsOf: high.map { $0 as Note })
            notes.append(contentsOf: high)
        }
        // The low bass octaves have a short downward stem, leaving room for the pedal glyph below.
        if clef == "bass" && (first.hasPrefix("(") || first.hasPrefix("Eb2/8,")) {
            _ = notes[0].setStemLength(16).setStemDirection(.down)
        }
        if flourish {
            _ = notes[0].setStemDirection(.down)
            let run = Array(notes[2...])
            _ = try Tuplet(notes: run.map { $0 as Note }, options: TupletOptions(numNotes: 7, notesOccupied: 5))
            _ = try score.beamThrowing(run, autoStem: false)
        } else {
            _ = try score.autoBeam(notes, options: EasyScoreAutoBeamOptions(groups: [Fraction(3, 8)]))
        }
        return BalladeVoice(notes: notes, voice: try score.voiceThrowing(items, time: .meter(6, 8)))
    }

    /// Engrave both hands on a common rhythmic grid. Spelling is reset at each barline.
    func measure(_ row: BalladeRow, _ offset: Int) throws -> [BalladeHand] {
        let bar = row.first + offset
        let system = factory.System(options: SystemOptions(
            spaceBetweenStaves: ((row.bass - row.top) * scale) / 10,
            x: row.edges[offset] * scale,
            width: (row.edges[offset + 1] - row.edges[offset]) * scale,
            y: row.top * scale - 40
        ))
        var hands: [BalladeHand] = []
        for (hand, parts) in balladeBars[bar - 1].enumerated() {
            let clef = hand != 0 ? "bass" : "treble"
            var voices: [BalladeVoice] = []
            for (i, part) in parts.enumerated() {
                let stem: String
                if parts.count > 1 {
                    stem = i != 0 ? "down" : "up"
                } else if (hand != 0 && bar >= 9 && bar <= 20) || (hand == 0 && bar == 14) {
                    stem = "up"
                } else {
                    stem = "auto"
                }
                voices.append(try makeVoice(part, clef: clef, stem: stem, flourish: bar == 14 && hand == 0))
            }
            let stave = system.addStave(SystemStave(voices: voices.map(\.voice)))
            if offset == 0 {
                _ = stave.addClef(hand != 0 ? .bass : .treble).addKeySignature("Ab")
                if bar == 1 { _ = stave.addTimeSignature(.meter(6, 8)) }
            }
            if hand != 0 && (bar == 9 || bar == 13) { _ = stave.addEndClef(.bass, size: .small) }
            try Accidental.applyAccidentals(voices.map(\.voice), keySignature: "Ab")
            hands.append(BalladeHand(stave: stave, voices: voices))
        }
        if offset == 0 { _ = system.addConnector(type: .brace) }
        _ = system.addConnector(type: .singleRight)
        return hands
    }

    var measures: [[BalladeHand]] = []
    for row in rows {
        for offset in 0..<(row.edges.count - 1) {
            measures.append(try measure(row, offset))
        }
    }

    // Phrase endpoints are written as (bar, note, voice), all notes counted from zero.
    func note(_ hand: Int, _ bar: Int, _ index: Int, _ voice: Int = 0) throws -> StemmableNote {
        let notes = measures[bar - 1][hand].voices[voice].notes
        guard index < notes.count else {
            throw UpstreamBalladeDemoError.missingNote(bar: bar, hand: hand, voice: voice, index: index)
        }
        return notes[index]
    }
    func right(_ bar: Int, _ i: Int, _ v: Int = 0) throws -> StemmableNote { try note(0, bar, i, v) }
    func left(_ bar: Int, _ i: Int) throws -> StemmableNote { try note(1, bar, i) }

    // MARK: decorate

    func slur(
        _ hand: Int, _ start: (Int, Int, Int), _ end: (Int, Int, Int), _ above: Bool, _ rise: Double,
        _ clearance: Double = 5
    ) throws {
        _ = factory.Curve(
            from: try note(hand, start.0, start.1, start.2),
            to: try note(hand, end.0, end.1, end.2),
            options: CurveOptions(
                cps: [(x: 0, y: rise), (x: 0, y: rise)],
                // Widen short two-note slurs to reach over the stems of a beamed octave pair.
                xShift: rise <= 6 ? -6 : 0,
                yShift: clearance,
                position: .auto,
                positionEnd: .auto,
                openingDirection: above ? .down : .up
            )
        )
    }

    func tie(_ from: Note?, _ to: Note?, _ heads: [Int], _ endHeads: [Int]? = nil, _ direction: TieDirection = .up) {
        _ = factory.StaveTie(
            notes: TieNotes(firstNote: from, lastNote: to, firstIndexes: heads, lastIndexes: endHeads ?? heads),
            direction: direction
        )
    }

    // Where a phrase turns the line, use partial ties at the two actual system edges.
    func chordTie(_ bar: Int, _ a: Int, _ b: Int, _ heads: [Int]) throws {
        let last = try right(bar, a)
        let next = try right(bar + 1, b)
        if rows.contains(where: { $0.first == bar + 1 }) {
            tie(last, nil, heads)
            tie(nil, next, heads)
        } else {
            tie(last, next, heads)
        }
    }

    func decorate() throws {
        try slur(0, (1, 0, 0), (2, 2, 0), true, 20)
        try slur(1, (1, 0, 0), (2, 2, 0), false, 24)
        tie(try right(2, 2), try right(3, 0), [2], [0], .down)
        tie(try right(3, 0), try right(4, 0), [0], [3], .down)
        try slur(1, (3, 0, 0), (4, 3, 0), true, 18)
        try slur(0, (5, 0, 0), (6, 2, 0), true, 15)
        tie(try right(5, 0), try right(6, 0), [0], [1], .down)
        try slur(1, (5, 0, 0), (6, 2, 0), false, 18)
        try chordTie(6, 2, 0, [0, 1, 2])
        tie(try left(6, 2), nil, [0], [0], .down)
        tie(nil, try left(7, 0), [0], [0], .down)
        tie(try left(7, 0), try left(7, 1), [0], [0], .down)
        try slur(0, (7, 0, 0), (8, 2, 0), true, 19)
        try slur(1, (7, 2, 0), (8, 2, 0), true, 25)
        for bar in 9...24 {
            if bar <= 16 {
                try slur(1, (bar, 2, 0), (bar, bar == 13 || bar == 14 ? 4 : 3, 0), true, 6)
            } else if bar <= 20 {
                try slur(1, (bar, 2, 0), (bar, 3, 0), false, 8)
            } else {
                try slur(1, (bar, 3, 0), (bar, 4, 0), true, 7)
            }
            _ = try left(bar, 0).addModifier(factory.Articulation(type: "a.", position: .above))
        }
        for bar in [9, 10, 13, 14] {
            _ = try right(bar, 0).addModifier(factory.Articulation(type: "a^", position: .above))
        }
        _ = try left(2, 2).addModifier(factory.Stroke(.arpeggioDirectionless, allVoices: false))
        for (bar, index, voice) in [(6, 2, 0), (15, 0, 0), (19, 2, 1)] {
            _ = try right(bar, index, voice).addModifier(factory.Stroke(.arpeggioDirectionless, allVoices: false))
        }
        try slur(0, (10, 0, 0), (10, 3, 0), true, 15)
        try slur(0, (11, 1, 0), (12, 5, 0), true, 22)
        try slur(0, (14, 0, 0), (14, 9, 0), true, 17)
        try slur(0, (15, 0, 0), (16, 5, 0), true, 12, 1)
        try slur(0, (17, 2, 0), (18, 4, 0), true, 34)
        try slur(0, (19, 0, 0), (20, 5, 1), true, 22, 18)
        try slur(0, (21, 3, 0), (21, 6, 0), true, 16)
        try slur(0, (22, 2, 0), (22, 5, 0), true, 15)
        try slur(0, (23, 0, 1), (24, 5, 1), true, 40, 17)
        for (bar, last) in [(15, 5), (16, 5)] {
            try chordTie(bar, last, 0, [0, 1])
        }
        // Short paired articulations inside the longer octave phrases.
        for (bar, a, b) in [(10, 2, 3), (11, 1, 2), (11, 4, 5), (12, 1, 2), (12, 4, 5), (18, 1, 2), (21, 5, 6)] {
            try slur(0, (bar, a, 0), (bar, b, 0), true, 5)
        }
        try chordTie(14, 9, 0, [0, 1])
        tie(try right(17, 2), try right(17, 3), [0, 1])
        tie(try right(19, 2), try right(19, 3), [0], [0], .down)
        tie(try right(21, 3), try right(21, 4), [0, 1, 2])
        tie(try right(22, 2), try right(22, 3), [0, 1, 2])
        tie(try right(23, 1), try right(23, 2), [0], [0], .down)

        func grace(_ host: StemmableNote, _ keys: [String], _ clef: ClefName) throws {
            let graceNote = factory.GraceNote(
                try GraceNoteStruct(parsingKeys: keys, duration: "8", slash: true, clef: clef)
            )
            _ = host.addModifier(factory.GraceNoteGroup(notes: [graceNote], slur: true))
        }
        try grace(try left(3, 3), ["c/4"], .bass)
        try grace(try right(22, 5), ["eb/5", "ab/5", "eb/6"], .treble)

        try fingerings()
        try hairpins()
    }

    // Fingerings apply to specific chord heads. Keep the alternating fingers of each octave pair together.
    func fingerings() throws {
        func mark(_ note: StemmableNote, _ number: String, _ position: ModifierPosition, _ head: Int = 0) {
            let fingering = factory.Fingering(number: number, position: position)
                .setFont(family: "Times New Roman", size: "10pt", weight: "bold")
            _ = note.addModifier(fingering, index: head)
        }
        let upper: [(Int, Int, String, Int)] = [
            (1, 0, "3", 0), (1, 3, "5", 0), (1, 4, "3", 0), (2, 2, "45", 0), (5, 0, "5", 0), (7, 1, "5", 0),
            (7, 2, "5", 0), (7, 4, "4", 0), (8, 1, "4", 0),
            (10, 2, "4", 0), (10, 3, "5", 0), (11, 1, "4", 0), (11, 2, "5", 0), (11, 4, "4", 0), (11, 5, "5", 0),
            (12, 1, "4", 0), (12, 2, "5", 0), (12, 4, "4", 0), (12, 5, "5", 0),
            (14, 2, "5", 0), (14, 3, "4", 0), (14, 5, "3", 0), (14, 9, "5", 0), (15, 1, "4", 0), (15, 2, "5", 0),
            (15, 4, "4", 0), (15, 5, "5", 0),
            (16, 1, "4", 0), (16, 2, "5", 0), (16, 4, "4", 0), (16, 5, "5", 0), (17, 1, "2", 0), (17, 4, "4", 0),
            (18, 1, "4", 0), (18, 2, "5", 0),
            (19, 0, "5", 0), (19, 1, "4", 0), (19, 2, "5", 0), (20, 1, "4", 1), (20, 4, "4", 1), (20, 5, "3", 1),
            (21, 5, "4", 0), (22, 5, "4", 0), (23, 0, "5", 1), (23, 4, "3", 1), (23, 5, "4", 1), (24, 4, "4", 1),
            (24, 5, "3", 1),
        ]
        for (bar, i, finger, voice) in upper {
            let n = try right(bar, i, voice)
            mark(n, finger, .above, n.keys.count - 1)
        }
        let lower: [(Int, Int, String)] = [
            (1, 1, "1"), (1, 3, "1"), (1, 4, "4"), (3, 0, "2"), (4, 2, "4"), (5, 0, "3"), (6, 2, "21"), (8, 0, "4"),
            (9, 2, "3"), (10, 2, "4"), (11, 2, "4"), (12, 2, "5"), (13, 2, "4"), (17, 2, "4"), (19, 2, "4"),
            (20, 2, "4"),
        ]
        for (bar, i, finger) in lower { mark(try left(bar, i), finger, .below) }
    }

    // Wedges sit between the hands, except for the left hand's rising entry in measure 5.
    func hairpins() throws {
        let entries: [(Note, Note, Double)] = [
            (try left(5, 1), try left(6, 0), 281),
            (try right(10, 2), try right(10, 3), 386),
            (try right(18, 4), try right(19, 1), 788),
            (try right(22, 4), try right(23, 1, 1), 977),
        ]
        for (from, to, baseline) in entries {
            factory
                .StaveHairpin(from: from, to: to, type: .crescendo, options: HairpinRenderOptions(height: 9))
                .setLayoutBaseline(baseline * scale)
        }

        // Wedges use the same between-staff baselines as the edition's expression words.
        let wedges: [(Int, Int, Int, Bool, Int)] = [
            (1, 0, 4, true, 0),
            (2, 0, 2, false, 0),
            (7, 0, 4, true, 0),
            (8, 0, 2, false, 0),
            (14, 2, 7, true, 0),
            (15, 0, 2, false, 0),
            (16, 0, 2, false, 0),
            (17, 1, 3, true, 0),
            (19, 2, 3, false, 0),
            (20, 4, 5, true, 1),
            (21, 5, 6, true, 0),
        ]
        for (bar, a, b, growing, voice) in wedges {
            let row = balladeRow(forBar: bar)
            factory
                .StaveHairpin(
                    from: try right(bar, a, voice),
                    to: try right(bar, b, voice),
                    type: growing ? .crescendo : .decrescendo,
                    options: HairpinRenderOptions(leftShiftPx: bar == 1 ? 32 : 0, height: 8)
                )
                .setLayoutBaseline((row.top + 45) * scale)
        }
    }

    // MARK: pedals

    // Place the pedal glyph below the actual low-octave stem after the music has been formatted.
    func pedals() throws {
        for bar in 9...24 {
            let bass = measures[bar - 1][1].voices[0].notes
            let row = balladeRow(forBar: bar)
            // A text-style release is anchored to the end of the preceding note.
            let beforeRelease = bar == 13 || bar == 14 || bar >= 21 ? 3 : 2
            guard let press = bass[0] as? StaveNote else { throw UpstreamBalladeDemoError.notStaveNote(bar) }
            guard let release = bass[beforeRelease] as? StaveNote else { throw UpstreamBalladeDemoError.notStaveNote(bar) }
            let pedal = PedalMarking(notes: [press, release]).setContext(ctx).setFontSize(27)
            pedal.setLayoutBaseline(max((row.bass + 66) * scale, bass[0].getStemExtents().topY + 23))
            try pedal.drawWithStyle()
        }
    }

    // MARK: lettering

    // Use the same physical page coordinates for the scan's title, dedication, tempo, and dynamic words.
    func text(
        _ label: String, _ x: Double, _ y: Double, _ size: Double, _ weight: String = "normal",
        _ style: String = "normal", _ align: String = "left", _ family: String = "Times New Roman"
    ) {
        _ = ctx.save().setFont(family, size, weight, style)
        let advance = ctx.measureText(label).width
        _ = ctx.fillText(label, x - (align == "center" ? advance / 2 : align == "right" ? advance : 0), y)
        _ = ctx.restore()
    }

    func lettering() {
        text("3ᵐᵉ Ballade.", balladeWidth / 2, 132, 34, "bold", "normal", "center")
        text("À Mˡˡᵉ Pauline de Noailles.", 82, 171, 18, "bold", "italic")
        text("Allegretto.", 243, 207, 23, "bold")
        text("Fr. Chopin, Op. 47.", 1237, 214, 19, "bold", "normal", "right")
        let labels: [(Int, String)] = [
            (1, "m. v."),
            (3, "dolce"),
            (9, "f"),
            (10, "meno f"),
            (11, "p"),
            (13, "f"),
            (14, "meno f"),
            (15, "p"),
            (18, "poco cresc."),
            (20, "dim."),
            (21, "rf"),
            (24, "poco dim."),
        ]
        for (bar, label) in labels {
            let row = balladeRow(forBar: bar)
            let n = measures[bar - 1][0].voices[0].notes[0]
            let x = n.getAbsoluteX()
            let y = (row.top + (bar == 21 ? 62 : bar == 24 ? 45 : 52)) * scale
            if ["f", "p", "rf", "meno f"].contains(label) {
                let letters = label == "meno f" ? "f" : label
                let glyphs = letters.map { TextDynamics.GLYPHS[$0] ?? "" }.joined()
                if label == "meno f" { text("meno", x + 3, y - 3, 17, "normal", "italic", "right") }
                text(glyphs, x + (label == "meno f" ? 11 : 0), y, 30, "normal", "normal", "left", "Bravura")
            } else {
                text(label, x - 4, y, 18, "normal", "italic")
            }
        }
    }

    // MARK: ossia

    // The small alternative in measure 3 replaces the grace note with a mordent on B-flat.
    func ossia(_ bar: [BalladeHand]) throws {
        let small = 0.63
        let x = bar[1].voices[0].notes[3].getAbsoluteX() - 8
        let y = bar[1].stave.getYForLine(6.2)
        _ = ctx.save()
        let group = ctx.openGroup("ossia")
        if let group = group as? SVGNode {
            group.setAttribute("transform", "scale(\(formatJSNumber(small)))")
        } else {
            _ = ctx.scale(small, small)
        }
        let f = Factory(options: FactoryOptions())
        _ = f.setContext(ctx)
        let score = f.EasyScore()
        let notes = try score.notesThrowing("Bb3/8, A3/8, Bb3/8", options: ["clef": "bass", "stem": "down"])
        _ = notes[0].addModifier(f.Ornament("mordent", position: .above))
        _ = try score.beamThrowing(notes, autoStem: false)
        let system = f.System(options: SystemOptions(x: x / small, width: 125, y: y / small - 40))
        let voice = try score.voiceThrowing(notes.map { $0 as Note }, time: .meter(3, 8))
        try Accidental.applyAccidentals([voice], keySignature: "Ab")
        _ = system.addStave(SystemStave(voices: [voice]))
        try f.draw()
        _ = ctx.setFont("Times New Roman", 21, "bold", nil).fillText("Ossia.", x / small - 75, y / small + 30)
        ctx.closeGroup()
        _ = ctx.restore()
    }

    // MARK: draw

    try decorate()
    try factory.draw()
    try pedals()
    lettering()
    try ossia(measures[2])
}
