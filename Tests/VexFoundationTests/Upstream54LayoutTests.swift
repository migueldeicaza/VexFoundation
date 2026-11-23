// Logic-level tests for the behaviors ported from VexFlow 5.3.0 → 5.4.0 (part 2).
// Ported from tests/node/continuous-score-tests.mjs, tests/node/publication-tests.mjs, the publication part of
// tests/node/instrument-profile-tests.mjs and the reading-order part of tests/web/navigation.mjs at 5.4.0.
// The upstream tests draw on a node canvas or in a browser; these tests use the SVG string context and the
// CoreText measurement of the bundled fonts. Pixel comparisons become comparisons of the SVG output.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func factory(width: Double = 960, height: Double = 1100) -> (f: Factory, ctx: SVGRenderContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = SVGRenderContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func note(
    _ keys: [String], _ duration: String, id: String? = nil, stave: String? = nil, clef: ClefName? = nil,
    stem: StemDirection? = nil
) -> EasyScoreContent {
    // The test inputs are valid literals.
    let value = StaveNoteStruct(parsingDuration: duration, keys: keys, stemDirection: stem, clef: clef)!
    return .note(value, id: id, stave: stave)
}

private func measure(_ notes: [EasyScoreContent], key: String? = nil, clef: ClefName? = nil, time: String? = nil) -> EasyScoreMeasureSpec {
    EasyScoreMeasureSpec(clef: clef, key: key, time: time.flatMap { TimeSignatureSpec(parsing: $0) }, voices: [EasyScoreVoiceSpec(notes: notes)])
}

// MARK: - Continuous studies (tests/engraving/continuous-studies.mjs)

enum ContinuousStudy {
    case choir, keyboard, chord, ensemble, breaks
}

/// `makeContinuousStudy(VF, factory, kind, width, mode)`.
private func makeContinuousStudy(_ f: Factory, _ kind: ContinuousStudy, _ width: Double, _ mode: SystemBreakMode = .balanced) throws -> EasyScoreComposition {
    let score = f.EasyScore()
    let event = { (key: String, duration: String, id: String?) in note([key], duration, id: id) }
    var staves: [EasyScoreStaveSpec] = []
    var spans: [ContinuousSpan] = []
    var boundaries: [ContinuousBoundary] = []
    var groups: [ContinuousGroup] = []
    switch kind {
    case .choir:
        let pitches = [["g/4", "a/4"], ["b/4", "a/4"], ["g/4", "e/4"], ["a/4", "b/4"], ["a/4", "g/4"], ["f#/4", "g/4"]]
        staves = [EasyScoreStaveSpec(
            id: "voice",
            measures: pitches.enumerated().map { i, p in
                measure(p.enumerated().map { j, k in event(k, "h", "v\(i)\(j)") }, key: i == 2 ? "D" : nil)
            },
            name: "Voice", shortName: "V."
        )]
        spans = [
            ContinuousSpan(id: "sung-word", kind: .lyric, from: "v00", to: "v51", text: "Sing"),
            ContinuousSpan(id: "phrase", kind: .slur, from: "v00", to: "v51", side: .above),
        ]
    case .keyboard:
        let upper = [["e/5", "d/5"], ["c/5", "b/4"], ["a/4", "g/4"], ["f/4", "e/4"]]
        let lower = ["c/3", "e/3", "f/3", "c/3"]
        var right = EasyScoreStaveSpec(
            id: "right",
            measures: upper.enumerated().map { i, p in measure(p.enumerated().map { j, k in event(k, "h", "r\(i)\(j)") }) },
            name: "Piano", shortName: "Pno."
        )
        let left = EasyScoreStaveSpec(
            id: "left", clef: .bass,
            measures: lower.enumerated().map { i, k in measure([event(k, "w", "l\(i)")]) }
        )
        // A beamed figure changes staves inside the first measure.
        right.measures[0].voices = [EasyScoreVoiceSpec(
            notes: [
                event("e/5", "8", "r00"),
                note(["b/3"], "8", id: "cross", stave: "left", clef: .bass),
                event("d/5", "q", "r01"),
                event("c/5", "h", "rch"),
            ],
            stem: "down",
            autoBeam: EasyScoreAutoBeamOptions()
        )]
        staves = [right, left]
        spans = [
            ContinuousSpan(id: "swell", kind: .crescendo, from: "r01", to: "r31"),
            ContinuousSpan(id: "sustain", kind: .pedal, from: "l0", to: "l3"),
        ]
        groups = [ContinuousGroup(first: "right", last: "left", type: .brace, barlines: true)]
        boundaries = [ContinuousBoundary(measure: 3, breakBefore: .force, rehearsal: "B")]
    case .chord:
        let part = { (staff: String, clef: ClefName, pitches: [[String]]) in
            EasyScoreStaveSpec(id: staff, clef: clef, measures: pitches.enumerated().map { i, pair in
                measure(pair.enumerated().map { k, key in note([key], "h", id: "\(staff)\(i)\(k)", stem: .up) })
            })
        }
        staves = [
            part("rh", .treble, [["e/4", "g/4"], ["a/4", "b/4"]]),
            part("lh", .bass, [["c/3", "e/3"], ["f/3", "g/3"]]),
        ]
        groups = [ContinuousGroup(first: "rh", last: "lh", type: .brace, barlines: true)]
    case .ensemble:
        let rest = { measure([event("b/4", "wr", nil)]) }
        let make = { (staff: String, pitches: [String?]) in
            pitches.enumerated().map { i, p in p.map { measure([event($0, "w", "\(staff)\(i)")]) } ?? rest() }
        }
        staves = [
            EasyScoreStaveSpec(id: "fl", measures: make("fl", ["e/5", nil, nil, nil, "d/5", "e/5"]), name: "Flute", shortName: "Fl."),
            EasyScoreStaveSpec(id: "vc", clef: .bass, measures: make("vc", [nil, nil, nil, nil, "g/2", "c/3"]), name: "Cello", shortName: "Vc."),
        ]
        boundaries = [
            ContinuousBoundary(measure: 5, breakBefore: .force, rehearsal: "B", repeatStart: true),
            ContinuousBoundary(measure: 6, repeatEnd: true),
        ]
        groups = [ContinuousGroup(first: "fl", last: "vc", type: .bracket)]
    case .breaks:
        let content = ["C4/q, D4/q, E4/q, F4/q", "G4/w", "F4/w", "E4/w", "D4/w", "C4/w", "G4/w"]
        staves = [EasyScoreStaveSpec(id: "line", measures: content.map {
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec($0)])
        })]
    }
    let result = try score.compose(EasyScoreCompositionSpec(
        staves: staves,
        sheet: SheetOptions(width: width, x: 12, y: 8, rowGap: 14, measurePadding: 14),
        system: SystemOptions(spaceBetweenStaves: 8),
        accidentals: .keyAware,
        continuous: ContinuousOptions(
            mode: mode,
            boundaries: boundaries,
            spans: spans,
            hideEmptyStaves: kind == .ensemble,
            compressRests: kind == .ensemble,
            measureNumbers: true,
            splitChords: kind == .chord ? [ContinuousSplitChord(id: "split", upper: "rh00", lower: "lh00")] : [],
            groups: groups
        )
    ))
    if kind == .chord {
        let arpeggio = f.Stroke(.arpeggioDirectionless, allVoices: false).addEndNote(try result.getNote("lh00"))
        _ = try result.getNote("rh00").addModifier(arpeggio, index: 0)
    }
    if kind == .keyboard, let cross = try result.getNote("cross") as? StemmableNote, let beam = cross.getBeam() {
        _ = cross.setStemDirection(.up).setBeam(beam)
    }
    return result
}

private struct Frame: Equatable {
    struct Row: Equatable {
        var m: [Int]
        var v: [String]
        var w: Double
        var h: Double
        var rest: [[Int]]
    }

    var rows: [Row]
    var fragments: [SpanFragment]
    var diagnostics: [ContinuousDiagnostic]
    var svg: String
}

private struct Scene {
    let f: Factory
    let ctx: SVGRenderContext
    let c: EasyScoreComposition
    let l: ContinuousLayout

    /// Draw at `width` and capture the layout and the drawing (upstream compares canvas pixels).
    func frame(_ width: Double) throws -> Frame {
        ctx.clear()
        try c.sheet.setWidth(width)
        try f.draw(retain: true)
        return Frame(
            rows: l.rows.map { Frame.Row(m: $0.measures, v: $0.visibleStaves, w: $0.width, h: $0.height, rest: $0.restGroups) },
            fragments: l.fragments,
            diagnostics: l.diagnostics,
            svg: ctx.getSVG()
        )
    }
}

private func scene(_ kind: ContinuousStudy, _ width: Double, _ mode: SystemBreakMode = .balanced) throws -> Scene {
    let (f, ctx) = factory()
    let c = try makeContinuousStudy(f, kind, width, mode)
    let l = try #require(c.sheet.getContinuousLayout())
    return Scene(f: f, ctx: ctx, c: c, l: l)
}

private func spec(
    _ count: Int, _ continuous: ContinuousOptions,
    _ notes: (Int) -> [EasyScoreContent] = { i in [note(["c/5"], "w", id: "n\(i)")] }
) -> EasyScoreCompositionSpec {
    EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "staff", measures: (0..<count).map { i in EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: notes(i))]) })],
        continuous: continuous
    )
}

// MARK: - Continuous score (continuous-score-tests.mjs)

@Suite("Upstream 5.4.0 port: continuous score")
struct Upstream54ContinuousTests {

    /// Also with `upstreamParityMode`, which turns off the gated stave alignment patch.
    @Test(arguments: [false, true])
    func vocalPhraseRetainsIdsAndFragmentsReuniteAtTheOriginalWidth(_ parity: Bool) throws {
        try isolated {
            VexRuntime.getCurrentContext().upstreamParityMode = parity
            let s = try scene(.choir, 740)
            let head = try s.c.getNote("v00")
            let wide = try s.frame(740)
            #expect(wide.rows.count == 1)
            let narrow = try s.frame(260)
            #expect(narrow.rows.map { $0.m } == [[1, 2], [3, 4], [5, 6]])
            for id in ["sung-word", "phrase"] {
                #expect(s.l.fragments.filter { $0.id == id }.map { $0.part } == [.first, .middle, .last], "\(id)")
            }
            let endSigns = s.c.staves[1][0].getModifiers(position: .end, category: KeySignature.category)
            #expect(endSigns.count == 1)
            #expect(narrow.diagnostics == [])
            #expect(try s.c.getNote("v00") === head)
            #expect(try s.frame(740) == wide)
            #expect(s.c.staves[1][0].getModifiers(position: .end, category: KeySignature.category).isEmpty)
        }
    }

    @Test func balancedWidthAvoidsTheGreedyLastMeasureRow() throws {
        try isolated {
            let greedy = try scene(.breaks, 415, .greedy).frame(415)
            let balanced = try scene(.breaks, 415, .balanced).frame(415)
            #expect(greedy.rows.map { $0.m.count } == [6, 1])
            #expect(balanced.rows.map { $0.m.count } == [3, 4])
            #expect(balanced.rows.flatMap { $0.m } == greedy.rows.flatMap { $0.m })
        }
    }

    @Test func grandStaffPreservesCrossStaffStemsAndWedgeApertureAcrossRedraw() throws {
        try isolated {
            let s = try scene(.keyboard, 490)
            let wide = try s.frame(490)
            let n = try s.c.getNote("cross")
            let staff = s.c.staves[0][1]
            let beam = try #require(n.getBeam())
            #expect(n.getStave() === staff)
            #expect(beam.getStripBounds().allSatisfy { $0.y.isFinite })
            let parts = wide.fragments.filter { $0.kind == .crescendo }
            #expect(parts.map { $0.part } == [.first, .last])
            #expect(parts[0].progress.1 == parts[1].progress.0)
            #expect(parts[0].progress.0 == 0)
            #expect(parts[1].progress.1 == 1)
            #expect(s.c.staves[0].map { $0.getY() } == s.c.staves[1].map { $0.getY() })
            _ = try s.frame(300)
            #expect(try s.frame(490) == wide)
            #expect(n.getStave() === staff)
        }
    }

    @Test func silentStavesReturnWithTheirNamesAndCompressedRunsKeepMeasureIdentities() throws {
        try isolated {
            let s = try scene(.ensemble, 430)
            let frame = try s.frame(430)
            #expect(frame.diagnostics == [])
            #expect(frame.rows.map { $0.v } == [["fl"], ["fl", "vc"]])
            #expect(frame.rows[0].rest == [[2, 3, 4]])
            #expect(s.c.notes.count == 6)
            #expect((s.c.notes[2][1][0][0] as? Note)?.isRest() == true)
            #expect((s.c.staves[4][1].getModifiers()[0] as? Barline)?.getType() == .repeatBegin)
            #expect((s.c.staves[5][0].getModifiers()[1] as? Barline)?.getType() == .repeatEnd)
        }
    }

    @Test func keepHoldsOverflowTogetherAndForcedBreaksWinOverSpareSpace() throws {
        try isolated {
            let (f, _) = factory()
            let c = try f.EasyScore().compose(spec(4, ContinuousOptions(boundaries: [
                ContinuousBoundary(measure: 2, breakBefore: .keep),
                ContinuousBoundary(measure: 3, breakBefore: .force),
                ContinuousBoundary(measure: 4, breakBefore: .keep),
            ])))
            let l = try #require(c.sheet.getContinuousLayout())
            try c.sheet.setWidth(12).format()
            #expect(l.rows.map { $0.measures } == [[1, 2], [3, 4]])
            #expect(l.diagnostics.map { $0.code } == [.rowOverflow, .rowOverflow])
            #expect(l.rows.allSatisfy { $0.overflow > 0 })
            try c.sheet.setWidth(800).format()
            #expect(l.rows.map { $0.measures } == [[1, 2], [3, 4]])
            #expect(l.diagnostics == [])
        }
    }

    @Test func spanFamiliesKeepTheirAnchorsAndContinuousProgressAcrossFragments() throws {
        try isolated {
            let kinds: [ContinuousSpanKind] = [.tie, .slur, .crescendo, .diminuendo, .pedal, .lyric, .hyphen, .volta, .ottava, .trill, .tuplet]
            for kind in kinds {
                let (f, _) = factory()
                let c = try f.EasyScore().compose(spec(3, ContinuousOptions(
                    boundaries: [ContinuousBoundary(measure: 2, breakBefore: .force), ContinuousBoundary(measure: 3, breakBefore: .force)],
                    spans: [ContinuousSpan(id: "s", kind: kind, from: "n0", to: "n2")]
                )))
                try f.draw(retain: true)
                let l = try #require(c.sheet.getContinuousLayout())
                let fs = l.fragments
                #expect(l.diagnostics == [], "\(kind)")
                #expect(fs.map { $0.part } == [.first, .middle, .last], "\(kind)")
                #expect(fs.allSatisfy { $0.id == "s" && $0.x1 < $0.x2 && ($0.y1 + $0.y2).isFinite }, "\(kind)")
                for i in 1..<fs.count { #expect(fs[i - 1].progress.1 == fs[i].progress.0, "\(kind)") }
            }
        }
    }

    @Test func boundarySignsMoveTogetherAndReturnedTiedAccidentalsReflow() throws {
        try isolated {
            let (f, _) = factory()
            let es = f.EasyScore()
            var s = spec(2, ContinuousOptions(spans: [ContinuousSpan(id: "tie", kind: .tie, from: "n0", to: "n1")])) { i in
                [note(["f#/4"], "w", id: "n\(i)")]
            }
            s.accidentals = .keyAware
            let c = try es.compose(s)
            let n = try c.getNote("n1")
            let l = try #require(c.sheet.getContinuousLayout())
            let mods = { n.getModifiers().compactMap { $0 as? Accidental } }
            try c.sheet.setWidth(680).format()
            #expect(mods().count == 0)
            try c.sheet.setWidth(128).format()
            #expect(l.rows.count == 2)
            #expect(mods().count == 1)
            let explicit = f.Accidental(type: .natural).setAsCautionary()
            _ = n.addModifier(explicit, index: 0)
            try c.sheet.setWidth(680).format()
            #expect(mods().map { ObjectIdentifier($0) } == [ObjectIdentifier(explicit)])

            let other = factory().f.EasyScore()
            var boundary = spec(2, ContinuousOptions())
            boundary.staves[0].measures[0].key = "D"
            boundary.staves[0].measures[1].key = "F"
            boundary.staves[0].measures[1].clef = .bass
            boundary.staves[0].measures[1].time = TimeSignatureSpec(parsing: "2/2")
            let b = try other.compose(boundary)
            try b.sheet.setWidth(145).format()
            let signs = { (position: StaveModifierPosition) in b.staves[0][0].getModifiers(position: position).map { $0.getCategory() } }
            for category in [Clef.category, KeySignature.category, TimeSignature.category] {
                #expect(signs(.end).contains(category), "\(category)")
            }
            try b.sheet.setWidth(800).format()
            #expect(signs(.end) == [Barline.category])
        }
    }

    @Test func structuralMarksInterruptRestCompressionAndInvalidSpecsRollBack() throws {
        try isolated {
            let (f, _) = factory()
            let c = try f.EasyScore().compose(spec(7, ContinuousOptions(
                boundaries: [
                    ContinuousBoundary(measure: 4, navigation: .segno(id: "sign")),
                    ContinuousBoundary(measure: 7, navigation: .dalSegno(target: "sign")),
                ],
                compressRests: true
            )) { _ in [note(["b/4"], "wr")] })
            try c.sheet.setWidth(850).format()
            #expect(c.sheet.getContinuousLayout()?.rows.flatMap { $0.restGroups } == [[2, 3], [5, 6]])
            let configs = [
                ContinuousOptions(spans: [ContinuousSpan(id: "s", kind: .tie, from: "n0", to: "n1", toHead: 5)]),
                ContinuousOptions(boundaries: [ContinuousBoundary(measure: 1, navigation: .toCoda(target: "missing"))]),
                ContinuousOptions(boundaries: [ContinuousBoundary(measure: 3)]),
            ]
            for config in configs {
                let fresh = factory().f.EasyScore()
                #expect(throws: (any Error).self) { _ = try fresh.compose(spec(2, config)) }
                #expect(fresh.getElement("n0") == nil)
            }
        }
    }

    @Test func sharedStemAndArpeggioFollowTheTwoHeadsAtEachWidth() throws {
        try isolated {
            let s = try scene(.chord, 375)
            let wide = try s.frame(375)
            #expect(wide.diagnostics == [])
            let top = try #require(try s.c.getNote("rh00") as? StaveNote)
            let bottom = try #require(try s.c.getNote("lh00") as? StaveNote)
            let stroke = try #require(top.getModifiers().compactMap { $0 as? Stroke }.first)
            #expect(top.getStemX() == bottom.getStemX())
            let ink = try #require(stroke.getBoundingBox())
            #expect(ink.y <= top.getYs()[0] && ink.y + ink.h >= bottom.getYs()[0])
            _ = try s.frame(160)
            #expect(try s.frame(375) == wide)
        }
    }

    @Test func instrumentChangesSurviveReflowAndTheFullNameReservesRowStartWidth() throws {
        try isolated {
            var s = spec(3, ContinuousOptions(boundaries: [ContinuousBoundary(measure: 2, breakBefore: .force)]))
            s.staves[0].name = "Flute"
            s.staves[0].shortName = "Fl."
            s.staves[0].measures[1].instrument = EasyScoreInstrumentName(name: "Bass clarinet in B-flat", shortName: "B. cl.")
            let c = try factory().f.EasyScore().compose(s)
            try c.sheet.setWidth(165).format()
            #expect(c.staves[1][0].getX() > c.staves[0][0].getX() + 30)
            #expect(c.staves[2][0].getX() < c.staves[1][0].getX())
        }
    }

    /// Swift: the layout keeps no reference to the composition, so a sheet can outlive it.
    @Test func sheetReflowsAfterTheCompositionIsReleased() throws {
        try isolated {
            let (f, ctx) = factory()
            var sheet: Sheet?
            do {
                let c = try makeContinuousStudy(f, .choir, 740)
                sheet = c.sheet
            }
            try sheet?.setWidth(260)
            try f.draw(retain: true)
            #expect(sheet?.getContinuousLayout()?.rows.map { $0.measures } == [[1, 2], [3, 4], [5, 6]])
            #expect(ctx.getSVG().contains("<path"))
        }
    }

    /// Part of the browser test "choir, piano and ensemble reflow in browser SVG and Canvas with two font
    /// pairs": the SVG backend with Bravura and Petaluma, at 740, 270 and 740.
    @Test(arguments: [ContinuousStudy.choir, .keyboard, .ensemble])
    func studiesReflowWithTwoFontPairs(_ kind: ContinuousStudy) throws {
        for (music, text) in [(MusicFontName.bravura, "Academico"), (.petaluma, "Petaluma Script")] {
            try isolated {
                Flow.setFonts([music.rawValue, text])
                let s = try scene(kind, 740)
                let output = try [740.0, 270, 740].map { try s.frame($0) }
                #expect(output[0] == output[2], "\(kind) \(music)")
                #expect(output[0].rows.map { [$0.m, $0.h, $0.w] as [AnyHashable] } != output[1].rows.map { [$0.m, $0.h, $0.w] as [AnyHashable] })
                for frame in output {
                    #expect(frame.svg.contains("<path") || frame.svg.contains("<text"))
                    #expect(frame.diagnostics == [], "\(kind) \(music)")
                }
            }
        }
    }
}


// MARK: - Publication studies (tests/engraving/publication-studies.mjs)

/// `publicationStudy(part, paper)`: a chamber score and a cello part share the same events.
private func publicationStudy(_ part: Bool, _ paper: PublicationPaper) -> (source: EasyScoreCompositionSpec, options: PublicationOptions) {
    let count = 26
    let melody = [
        ["g/4", "b/4", "d/5"], ["e/5", "d/5", "b/4"], ["a/4", "c/5", "b/4"], ["g/4", "a/4", "d/5"],
        ["d/5", "c/5", "a/4"], ["b/4", "a/4", "g/4"], ["e/4", "g/4", "a/4"], ["d/5", "b/4", "g/4"],
    ]
    let bass = ["g/2", "e/3", "a/2", "d/3", "b/2", "g/2", "c/3", "d/3"]
    let middle = ["b/3", "g/3", "e/4", "a/3", "d/4", "b/3", "c/4", "a/3"]
    func make(_ id: String, _ name: String, _ shortName: String, _ clef: ClefName) -> EasyScoreStaveSpec {
        EasyScoreStaveSpec(
            id: id, clef: clef, key: "G", time: TimeSignatureSpec(parsing: "3/4"),
            measures: (0..<count).map { i in
                var keys: [String]
                var ds: [String]
                if id == "fl" {
                    keys = melody[i % melody.count]
                    ds = i % 3 == 0 ? ["q", "8", "8", "q"] : ["q", "q", "q"]
                } else if id == "va" {
                    keys = [middle[i % 8], middle[(i + 2) % 8]]
                    ds = ["h", "q"]
                } else {
                    keys = [bass[i % 8], bass[(i + 3) % 8]]
                    ds = i == 15 || i == 17 ? ["hr", "qr"] : i % 3 == 0 ? ["q", "8", "8", "q"] : ["h", "q"]
                }
                if i == count - 1 {
                    keys = [id == "fl" ? "g/4" : id == "va" ? "b/3" : "g/2"]
                    ds = ["h", "q"]
                }
                let notes = ds.enumerated().map { j, d in note([keys[j % keys.count]], d, id: "\(id)-\(i + 1)-\(j + 1)") }
                return EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: notes, autoBeam: EasyScoreAutoBeamOptions())])
            },
            name: name, shortName: shortName
        )
    }
    let source = EasyScoreCompositionSpec(
        staves: [make("fl", "Flute", "Fl.", .treble), make("va", "Viola", "Va.", .alto), make("vc", "Violoncello", "Vc.", .bass)],
        accidentals: .keyAware,
        continuous: ContinuousOptions(
            boundaries: [ContinuousBoundary(measure: 9, rehearsal: "B"), ContinuousBoundary(measure: 19, rehearsal: "C")],
            spans: [
                ContinuousSpan(id: "opening", kind: .slur, from: "fl-1-1", to: "fl-2-3", side: .above),
                ContinuousSpan(id: "cello-swell", kind: .crescendo, from: "vc-9-1", to: "vc-12-2"),
            ],
            measureNumbers: true,
            groups: [ContinuousGroup(first: "fl", last: "vc", type: .bracket)]
        )
    )
    var options = PublicationOptions(
        systemBreaks: part
            ? [3, 6, 9, 12, 14, 17, 19, 21, 23, 25]
            : (1...count).filter { $0 > 1 && ($0 - 1) % 4 == 0 },
        paper: paper,
        staffSize: part ? 7.2 : 7.8,
        title: "Andante in G",
        subtitle: part ? "Violoncello" : "Flute, viola and violoncello",
        header: part ? "Andante in G · Violoncello" : "Andante in G · Score",
        footer: "Andante in G",
        systemGap: part ? 6 : 7,
        maxExtraGap: 8
    )
    if part {
        options.staves = ["vc"]
        options.preferredTurns = [16]
        options.forbiddenTurns = [13]
        options.regions = [
            PublicationRegion(kind: .cue, staff: "fl", measure: 16, label: "Flute cue"),
            PublicationRegion(kind: .ossia, staff: "va", measure: 21, label: "Ossia · viola"),
        ]
    }
    return (source, options)
}

private func metadata(_ page: PublicationPage) throws -> [String: Any] {
    let text = try #require(page.metadata)
    return try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

private func nodes(_ root: SVGNode, _ name: String) -> [SVGNode] {
    root.descendants().filter { $0.name == name }
}

private func count(_ svg: String, _ tag: String) -> Int {
    svg.components(separatedBy: "<\(tag) ").count - 1 + svg.components(separatedBy: "<\(tag)>").count - 1
}

// MARK: - Publication (publication-tests.mjs)

@Suite("Upstream 5.4.0 port: publication")
struct Upstream54PublicationTests {

    @Test(arguments: [(PublicationPaper.a4, false), (.a4, true), (.letter, false), (.letter, true)])
    func viewsPaginationAndPortablePrinting(_ paper: PublicationPaper, _ part: Bool) throws {
        try isolated {
            let (source, options) = publicationStudy(part, paper)
            let result = try Publication(source).render(options)
            #expect(result.diagnostics == [])
            let ranges = result.pages.map { $0.systems.flatMap { $0.measures } }
            #expect(ranges.flatMap { $0 } == Array(1...26))
            #expect(ranges.map { $0.last ?? 0 } == (part ? [16, 26] : paper == .a4 ? [12, 24, 26] : [8, 20, 26]))
            let (w, h) = paper == .a4 ? (210.0, 297.0) : (215.9, 279.4)
            #expect(result.pages.allSatisfy {
                $0.svg.getAttribute("width") == formatJSNumber(w) + "mm" && $0.svg.getAttribute("height") == formatJSNumber(h) + "mm"
            })
            for page in result.pages {
                for (i, s) in page.systems.enumerated() {
                    #expect(s.x >= 16 && s.x + s.width <= w - 16 + 0.001, "\(s)")
                    #expect(s.y >= 15 && s.y + s.height < h - 15, "\(s)")
                    if i > 0 { #expect(s.y >= page.systems[i - 1].y + page.systems[i - 1].height + 5.99) }
                }
            }
            let ids = result.pages.flatMap { page in page.svg.descendants().compactMap { $0.getAttribute("id") } }
            #expect(ids.count == Set(ids).count)
            let xml = try result.toSVG(1)
            let outlined = try result.toSVG(1, portable: true)
            #expect(count(xml, "text") > 0)
            #expect(count(outlined, "text") == 0)
            #expect(outlined.contains(try #require(result.pages[0].metadata).replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")))
            let transforms = result.pages[0].svg.descendants().filter { $0.getAttribute("data-system") != nil }
                .compactMap { $0.getAttribute("transform") }
            #expect(!transforms.isEmpty)
            for transform in transforms { #expect(outlined.contains("transform=\"\(transform)\"")) }
            let meta = try result.pages.map(metadata)
            let events = meta.flatMap { $0["events"] as? [[String: Any]] ?? [] }
            #expect(events.contains { $0["id"] as? String == "vc-16-1" && $0["rest"] as? Bool == true })
            if part {
                let regions = meta.flatMap { $0["regions"] as? [[String: Any]] ?? [] }
                let cue = try #require(regions.first { $0["kind"] as? String == "cue" })
                let cueEvents = cue["events"] as? [[String: Any]] ?? []
                #expect(cueEvents.contains { $0["id"] as? String == "fl-16-1" && $0["measure"] as? Int == 16 && $0["staff"] as? String == "fl" })
                #expect(events.allSatisfy { $0["staff"] as? String == "vc" })
                #expect(regions.map { "\($0["kind"] ?? "") \($0["measure"] ?? "")" } == ["cue 16", "ossia 21"])
            }
            // Upstream prints the HTML to PDF in Chromium and counts the pages and media boxes.
            let printed = try result.toPrintHTML()
            #expect(count(printed, "svg") == ranges.count)
            #expect(printed.contains("@page{size:\(formatJSNumber(w))mm \(formatJSNumber(h))mm;margin:0}"))
        }
    }

    @Test func extractedCrossStaffVoiceKeepsItsNotesAndReportsAnExcludedSpanEnd() throws {
        try isolated {
            var (source, _) = publicationStudy(false, .a4)
            if case .note(var value, let id, _, let grace) = source.staves[0].measures[0].voices[0].notes[0] {
                value.clef = .alto
                source.staves[0].measures[0].voices[0].notes[0] = .note(value, id: id, stave: "va", grace: grace)
            }
            source.continuous?.spans.append(ContinuousSpan(id: "between", kind: .slur, from: "fl-1-1", to: "vc-2-2"))
            let registry = Registry()
            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }
            let r = try Publication(source).render(PublicationOptions(staves: ["fl"]))
            let events = try metadata(r.pages[0])["events"] as? [[String: Any]] ?? []
            let notes = events.filter { $0["id"] as? String == "fl-1-1" }
            #expect(notes.first?["staff"] as? String == "fl")
            #expect(r.diagnostics.filter { $0.code == .excludedAnchor }
                == [PublicationDiagnostic(code: .excludedAnchor, measures: [1, 2], detail: "between")])
            #expect(Registry.getDefaultRegistry() === registry)
            #expect(registry.getElementById("fl-1-1") == nil)
        }
    }

    @Test func partBreaksForcedAndForbiddenTurnsOversizeDiagnosticsAndTransactionalRedraw() throws {
        try isolated {
            let (source, options) = publicationStudy(false, .a4)
            var part = publicationStudy(true, .a4).options
            let publication = Publication(source)
            let score = try publication.render(options)
            let before = try score.toSVG(1)
            var forcedOptions = part
            forcedOptions.pageBreaks = [5]
            forcedOptions.forbiddenTurns = [4]
            let forced = try publication.render(forcedOptions)
            var invalidOptions = part
            invalidOptions.regions = [PublicationRegion(kind: .cue, staff: "missing", measure: 4, label: "Cue")]
            #expect(throws: (any Error).self) { _ = try publication.render(invalidOptions) }
            part.paper = .custom(width: 130, height: 68)
            part.title = String(repeating: "A ", count: 100)
            let narrow = try publication.render(part)
            #expect(throws: (any Error).self) { _ = try narrow.toPrintHTML() }
            // A rendering never changes an earlier result (upstream checks the DOM of both targets).
            #expect(try score.toSVG(1) == before)
            #expect(forced.pages[1].systems[0].measures[0] == 5)
            #expect(forced.diagnostics.filter { $0.code == .forbiddenTurn }.map { $0.measures } == [[4]])
            let codes = narrow.diagnostics.map { $0.code }
            #expect(codes.contains(.pageOverflow) && codes.contains(.textOverflow))
        }
    }

    @Test func equallyFeasiblePagesPreferARestAndRespectForbiddenTurnsAndLastPageSpacing() {
        let rows = (0..<5).map { i in PrintableSystem(measures: [i + 1], height: 10, restAtEnd: i == 1) }
        let rules = PageConstraints(firstHeight: 34, laterHeight: 34, gap: 1, maxExtraGap: 8, justifyLast: false, part: true)
        let natural = paginate(rows, rules)
        #expect(natural.map { $0.end } == [2, 5])
        #expect(natural[1].offsets == [0, 11, 22])
        var justified = rules
        justified.justifyLast = true
        #expect(paginate(rows, justified)[1].offsets == [0, 12, 24])
        var forbidden = rules
        forbidden.forbidAfter = [2]
        #expect(paginate(rows, forbidden).map { $0.end } == [3, 5])
    }

    /// The publication part of instrument-profile-tests.mjs: percussion identities survive an exported part.
    @Test func percussionIdentitiesSurviveAnExportedPart() throws {
        try isolated {
            let kit = try PercussionMap()
            let source = EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "drums", clef: .percussion, measures: [EasyScoreMeasureSpec(voices: [
                    EasyScoreVoiceSpec(notes: [
                        .note(try kit.note(["snare", "hat"], duration: "q"), id: "backbeat"),
                        .note(try kit.note(["kick"], duration: "q")),
                        .note(try kit.note(["hat"], duration: "h")),
                    ]),
                ])])],
                continuous: ContinuousOptions()
            )
            let result = try Publication(source).render(PublicationOptions(staves: ["drums"]))
            let events = try metadata(result.pages[0])["events"] as? [[String: Any]] ?? []
            let exported = try #require(events.first { $0["id"] as? String == "backbeat" }?["notation"] as? [[String: Any]])
            #expect(exported.map { "\($0["id"] ?? "") \($0["index"] ?? "")" } == ["snare 0", "hat 1"])
        }
    }
}

// MARK: - Score navigation (tests/web/navigation.mjs)

@Suite("Upstream 5.4.0 port: score navigation")
struct Upstream54NavigationTests {

    @Test func readingOrderCoversSimultaneousVoicesTabAndSilentPlaceholders() throws {
        try isolated {
            let (f, _) = factory(width: 720, height: 460)
            let staves = [
                EasyScoreStaveSpec(id: "rh", clef: .treble, measures: [EasyScoreMeasureSpec(voices: [
                    EasyScoreVoiceSpec(notes: [note(["c/5"], "h", id: "upper1"), note(["c/5"], "h", id: "upper2")], stem: "up"),
                    EasyScoreVoiceSpec(notes: [
                        note(["e/4"], "q", id: "low1"),
                        .tickable(try f.GhostNote(duration: "q")),
                        note(["e/4"], "h", id: "low3"),
                    ], stem: "down"),
                ])], name: "Piano"),
                EasyScoreStaveSpec(id: "tab", kind: .tab, clef: .tab, measures: [EasyScoreMeasureSpec(voices: [
                    EasyScoreVoiceSpec(notes: [.tab(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 3)], duration: .whole), id: "tab1")]),
                ])]),
            ]
            let score = try f.EasyScore().compose(EasyScoreCompositionSpec(staves: staves, sheet: SheetOptions(width: 680)))
            _ = try score.getNote("upper1").addModifier(Accidental(.sharp), index: 0)
            try f.draw(retain: true)
            let snapshot = try ScoreNavigation(score, staves: staves, sources: ["tab1": "source/strings/1"])
            let r = try #require(snapshot.regions.first { $0.id == "tab1" })
            #expect(snapshot.events.map { [$0.id, $0.onset] } == [
                ["upper1", "0/1"], ["low1", "0/1"], ["tab1", "0/1"], ["upper2", "1/2"], ["low3", "1/2"],
            ])
            #expect(snapshot.events[0].label.contains("C sharp 5"))
            #expect(snapshot.events[2].label.contains("string 2 fret 3"))
            #expect(snapshot.hitTest(r.x + r.w / 2, r.y + r.h / 2)?.source == "source/strings/1")
            #expect(snapshot.hitTest(.nan, 0) == nil)
            #expect(snapshot.diagnostics == [])
        }
    }

    @Test func continuousSpansBecomeRowRegionsAndEventsPrecedeSpans() throws {
        try isolated {
            let s = try scene(.choir, 260)
            _ = try s.frame(260)
            let staves = [EasyScoreStaveSpec(id: "voice", measures: [], name: "Voice")]
            let snapshot = try ScoreNavigation(s.c, staves: staves)
            let spans = snapshot.regions.filter { $0.kind == .span && $0.id == "phrase" }
            #expect(spans.map { $0.row } == [0, 1, 2])
            #expect(snapshot.events.count == 12)
            #expect(snapshot.events[0].label == "Measure 1, Voice, voice 1, G 4, half note")
            let head = try #require(snapshot.regions.first { $0.id == "v00" })
            #expect(snapshot.hitTest(head.x + head.w / 2, head.y + head.h / 2)?.id == "v00")
        }
    }
}

