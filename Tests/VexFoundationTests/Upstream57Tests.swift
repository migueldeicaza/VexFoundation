// Logic-level tests for the behaviors ported from VexFlow 5.6.1 → 5.7.0.
// Ported from the 5.7.0 assertions in tests/node/continuous-score-tests.mjs, tests/node/instrument-profile-tests.mjs,
// tests/node/engraving-layout-tests.mjs, tests/node/phrase-layout-tests.mjs and tests/node/sheet-tests.mjs, with
// the studies of tests/engraving/*-studies.mjs. The upstream tests draw on a node canvas or in a browser; these
// tests use the SVG string context. Pixel comparisons become comparisons of the SVG output or of the geometry.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func makeFactory(width: Double = 960, height: Double = 900) -> (f: Factory, ctx: SVGRenderContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = SVGRenderContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func note(
    _ keys: [String], _ duration: String, id: String? = nil, stem: StemDirection? = nil, dots: Int? = nil
) -> EasyScoreContent {
    // The test inputs are valid literals.
    let value = StaveNoteStruct(parsingDuration: duration, keys: keys, dots: dots, stemDirection: stem)!
    return .note(value, id: id)
}

private func occurrences(_ text: String, _ needle: String) -> Int {
    text.components(separatedBy: needle).count - 1
}

/// `spec(count, continuous)` from continuous-score-tests.mjs: one whole note per measure.
private func spec(_ count: Int, _ continuous: ContinuousOptions = ContinuousOptions()) -> EasyScoreCompositionSpec {
    EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "staff", measures: (0..<count).map { i in
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [note(["c/5"], "w", id: "n\(i)")])])
        })],
        continuous: continuous
    )
}

// MARK: - Studies (tests/engraving/*-studies.mjs at 5.7.0)

/// `beamedSplitChordStudy(VF, stemDirection, spaceBetweenStaves, beamStaff)`.
private func beamedSplitChordStudy(
    _ stem: StemDirection, _ spaceBetweenStaves: Double, _ beamStaff: String = "upper", beams: [String]? = nil
) -> EasyScoreCompositionSpec {
    let staves = ["upper", "lower"].map { id -> EasyScoreStaveSpec in
        let octave = id == "upper" ? 4 : 3
        let notes = ["e", "f", "g", "a"].enumerated().map { index, pitch in
            note(["\(pitch)/\(octave)"], "8", id: id + String(index), stem: stem)
        }
        let beamed = beams.map { $0.contains(id) } ?? (id == beamStaff)
        return EasyScoreStaveSpec(
            id: id, clef: id == "upper" ? .treble : .bass, time: .meter(2, 4),
            measures: [EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(
                notes: notes, autoBeam: beamed ? EasyScoreAutoBeamOptions(groups: [Fraction(1, 2)]) : nil
            )])]
        )
    }
    return EasyScoreCompositionSpec(
        staves: staves,
        sheet: SheetOptions(width: 280, x: 12, y: 8),
        system: SystemOptions(spaceBetweenStaves: spaceBetweenStaves),
        continuous: ContinuousOptions(
            splitChords: (0..<4).map { ContinuousSplitChord(id: "split\($0)", upper: "upper\($0)", lower: "lower\($0)") },
            groups: [ContinuousGroup(first: "upper", last: "lower", type: .brace, barlines: true)]
        )
    )
}

/// `continuousBeamStudy(boundaries)`: four eighths straddling the barline.
private func continuousBeamStudy(_ boundaries: [ContinuousBoundary] = []) -> EasyScoreCompositionSpec {
    let event = { (id: String, pitch: String, duration: String) in note([pitch], duration, id: id, stem: .down) }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "melody", time: .meter(2, 4), measures: [
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                event("g", "g/4", "q"), event("b", "b/4", "8"), event("c", "c/5", "8"),
            ])]),
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                event("d", "d/5", "8"), event("e", "e/5", "8"), event("f", "f/5", "q"),
            ])]),
        ])],
        sheet: SheetOptions(width: 450, rowGap: 22, measurePadding: 12),
        continuous: ContinuousOptions(
            boundaries: boundaries,
            spans: [ContinuousSpan(id: "phrase-beam", kind: .beam, from: "b", to: "e")]
        )
    )
}

/// `glissandoStudy(descending, forceBreak)`.
private func glissandoStudy(_ descending: Bool = false, _ forceBreak: Bool = false) -> EasyScoreCompositionSpec {
    let low = ["a/4", "b/4"], high = ["e/5", "f/5"]
    let event = { (id: String, keys: [String]) in note(keys, "q", id: id, stem: .up) }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "violin", time: .meter(2, 4), measures: [
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                event("lead", ["g/4"]), event("from", descending ? high : low),
            ])]),
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                event("to", descending ? low : high), event("end", ["a/4"]),
            ])]),
        ])],
        sheet: SheetOptions(width: 430),
        continuous: ContinuousOptions(
            boundaries: forceBreak ? [ContinuousBoundary(measure: 2, breakBefore: .force)] : [],
            spans: [ContinuousSpan(id: "slide", kind: .glissando, from: "from", to: "to", fromHead: 1, toHead: 0)]
        )
    )
}

/// `tiedBendStudy(VF, boundaries)`: string three rises in bar one and releases during the tied quarter.
private func tiedBendStudy(
    _ boundaries: [ContinuousBoundary] = [], bend: TiedBend = TiedBend(semitones: 2, rise: (1, 2), hold: (1, 2), release: (1, 1)),
    from: String = "tabrise", to: String = "tabrelease", lastTab: Bool = false
) throws -> EasyScoreCompositionSpec {
    let guitar = try FrettedInstrument()
    let grip: [FrettedPosition] = [.fret(str: 3, fret: 7), .fret(str: 2, fret: 5)]
    let pair = try guitar.attack(grip, duration: "q")
    let continued = try guitar.attack(grip.reversed(), duration: "q")
    let neighbor = try guitar.attack([.fret(str: 4, fret: 5)], duration: "q")
    let staves = ["note", "tab"].map { view -> EasyScoreStaveSpec in
        let event = { (data: FrettedAttack, id: String) -> EasyScoreContent in
            view == "tab" ? .tab(data.tab, id: view + id) : .note(data.note, id: view + id)
        }
        let last = lastTab && view == "tab" ? continued : neighbor
        return EasyScoreStaveSpec(
            id: view, kind: view == "tab" ? .tab : .stave, time: .meter(2, 4),
            measures: [
                [event(neighbor, "lead"), event(pair, "rise")],
                [event(continued, "release"), event(last, "last")],
            ].map { EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: $0)]) }
        )
    }
    return EasyScoreCompositionSpec(
        staves: staves,
        sheet: SheetOptions(width: 520, rowGap: 22, measurePadding: 28),
        continuous: ContinuousOptions(boundaries: boundaries, spans: [
            ContinuousSpan(
                id: "written-tie", kind: .tie, from: "noterise", to: "noterelease", fromHead: 0, toHead: 1, side: .below
            ),
            ContinuousSpan(id: "tied-bend", kind: .tie, from: from, to: to, string: 3, bend: bend),
        ])
    )
}

/// `makeTremoloStudy(VF, ctx, duration, strokes, crossStaff)`: one measured tremolo.
private struct TremoloStudy {
    let upper: Stave
    let lower: Stave
    let voice: Voice
    let notes: [StaveNote]
    let tremolo: AlternatingTremolo
    let ctx: SVGRenderContext
    let crossStaff: Bool

    init(_ duration: String, _ strokes: Int, crossStaff: Bool = false) throws {
        let beats = ["w": 4, "h": 2, "q": 1][duration] ?? 1
        ctx = SVGRenderContext(width: 300, height: 260)
        upper = Stave(x: 12, y: 2, width: 235)
        upper.addClef(.treble).addTimeSignature(.meter(beats, 4))
        _ = upper.setContext(ctx)
        lower = crossStaff ? Stave(x: 12, y: 100, width: 235) : upper
        if crossStaff {
            lower.addClef(.bass)
            _ = lower.setContext(ctx)
        }
        let first = try StaveNoteStruct(parsingKeys: ["c/5"], duration: try NoteDurationSpec(parsing: duration), stemDirection: .down, clef: .treble)
        let second = try StaveNoteStruct(
            parsingKeys: [crossStaff ? "c/3" : "g/4"], duration: try NoteDurationSpec(parsing: duration),
            stemDirection: crossStaff ? .up : .down, clef: crossStaff ? .bass : .treble
        )
        notes = try [first, second].map { StaveNote(try AlternatingTremolo.endpoint($0, strokes: strokes)) }
        voice = VexFoundation.Voice(time: VoiceTime(numBeats: beats, beatValue: 4)).addTickables(notes as [Tickable]).setStave(upper)
        voice.preserveStaveAssignments = true
        tremolo = try AlternatingTremolo(first: notes[0], last: notes[1], strokes: strokes)
        _ = tremolo.setContext(ctx)
        self.crossStaff = crossStaff
    }

    func draw(_ gap: Double = 82) throws -> String {
        ctx.clear()
        if crossStaff {
            lower.setY(upper.getY() + gap)
            _ = lower.setNoteStartX(upper.getNoteStartX())
        }
        _ = notes[0].setStave(upper)
        _ = notes[1].setStave(lower)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: upper)
        try upper.draw()
        if crossStaff { try lower.draw() }
        try voice.draw(context: ctx)
        try tremolo.draw()
        return ctx.getSVG()
    }

    /// The tremolo strokes as their four corners: `(x1, y1, x2, y2, bottom2, bottom1)`.
    static func bars(_ svg: String) -> [[Double]] {
        guard let start = svg.range(of: "class=\"vf-alternating-tremolo\"") else { return [] }
        let group = svg[start.upperBound...].components(separatedBy: "</g>")[0]
        return group.components(separatedBy: "<path").dropFirst().compactMap { path in
            guard let d = path.components(separatedBy: "d=\"").dropFirst().first?.components(separatedBy: "\"").first
            else { return nil }
            let numbers = d.split(whereSeparator: { !"-.0123456789".contains($0) }).compactMap { Double($0) }
            return numbers.count >= 8 ? [numbers[0], numbers[1], numbers[2], numbers[3], numbers[5], numbers[7]] : nil
        }
    }
}

@Suite("Upstream 5.7.0 port")
struct Upstream57Tests {

    // MARK: - Niente hairpins (continuous-score-tests.mjs)

    @Test func nienteCirclesTouchTheWedgeAndFitTheMeasuredBounds() throws {
        try isolated {
            for space in [8.0, 12.0] {
                let (f, ctx) = makeFactory()
                var source = spec(2)
                source.staves[0].options = StaveOptions(spacingBetweenLinesPx: space)
                let c = try f.EasyScore().compose(source)
                try c.sheet.setWidth(500).format()
                let from = try c.getNote("n0"), to = try c.getNote("n1")
                for type in [HairpinType.crescendo, .decrescendo] {
                    let hairpin = f.StaveHairpin(from: from, to: to, type: type, options: HairpinRenderOptions(height: 2))
                    hairpin.setStyle(ElementStyle(lineWidth: 2))
                    _ = hairpin.setContext(ctx)
                    ctx.clear()
                    try hairpin.drawWithStyle()
                    #expect(occurrences(ctx.getSVG(), " A") == 0)
                    let plain = try #require(hairpin.getBoundingBox())
                    var options = hairpin.renderOptions
                    options.niente = true
                    hairpin.setRenderOptions(options)
                    ctx.clear()
                    try hairpin.drawWithStyle()
                    #expect(occurrences(ctx.getSVG(), " A") == 2)
                    let radius = space * 0.35
                    let grows = type == .crescendo
                    let tipX = (grows ? from : to).getModifierStartXY(position: .below, index: 0).x
                    let edges = try hairpin.getLayoutEdges()
                    let outer = grows ? edges.left : edges.right
                    #expect(abs(outer - (grows ? tipX - 2 * radius : tipX + 2 * radius)) < 1e-6)
                    let box = try #require(hairpin.getBoundingBox())
                    #expect(abs(box.w - plain.w - 2 * radius) < 1e-6)
                    #expect(abs(box.h - 2 * (radius + 1)) < 1e-6)
                }
            }
        }
    }

    @Test func aWrappedNienteCircleBelongsOnlyToItsClosedEndpointAndHitRegion() throws {
        try isolated {
            for space in [8.0, 12.0] {
                let (f, ctx) = makeFactory()
                let spans = [ContinuousSpanKind.crescendo, .diminuendo].map {
                    ContinuousSpan(id: $0.rawValue, kind: $0, from: "n0", to: "n4", niente: true)
                }
                var source = spec(5, ContinuousOptions(spans: spans + [
                    ContinuousSpan(id: "plain", kind: .crescendo, from: "n0", to: "n4", niente: false),
                ]))
                source.staves[0].options = StaveOptions(spacingBetweenLinesPx: space)
                let c = try f.EasyScore().compose(source)
                let layout = try #require(c.sheet.getContinuousLayout())
                for width in [600.0, 120, 600] {
                    try c.sheet.setWidth(width).format()
                    let marked = layout.fragments.filter { $0.nienteTip != nil }
                    #expect(marked.map(\.id) == ["crescendo", "diminuendo"])
                    #expect(marked.map(\.part) == (width == 120 ? [.first, .last] : [.single, .single]))
                    if width == 120 { #expect(layout.fragments.contains { $0.part == .middle }) }
                    ctx.clear()
                    try layout.draw(ctx)
                    #expect(occurrences(ctx.getSVG(), " A") == 2 * marked.count)
                    let nav = try ScoreNavigation(c, staves: source.staves)
                    for fragment in marked {
                        let tip = try #require(fragment.nienteTip)
                        let side: Double = fragment.kind == .crescendo ? -1 : 1
                        let vertex = side < 0 ? fragment.x1 : fragment.x2
                        #expect(abs(tip.x - side * tip.radius - vertex) < 1e-6)
                        #expect(nav.hitTest(tip.x + side * tip.radius, tip.y)?.id == fragment.id)
                    }
                }
            }
        }
    }

    // MARK: - Beamed split chords (continuous-score-tests.mjs)

    @Test(arguments: [StemDirection.up, .down])
    func beamedSplitChordsKeepOneStemAndOneBeamAttachmentPerAttack(_ direction: StemDirection) throws {
        try isolated {
            for beamStaff in ["upper", "lower"] {
                let (f, ctx) = makeFactory(width: 320, height: 300)
                let c = try f.EasyScore().compose(beamedSplitChordStudy(direction, 8, beamStaff))
                let beam = try #require(try c.getNote(beamStaff + "0").getBeam())
                func frame() throws -> String {
                    ctx.clear()
                    try f.draw(retain: true)
                    let svg = ctx.getSVG()
                    #expect(c.systems[0].getPhraseLayout().diagnostics == [])
                    #expect(occurrences(svg, "class=\"vf-stem\"") == 4)
                    #expect(occurrences(svg, "class=\"vf-stavenote\"") == 8)
                    #expect(c.sheet.getContinuousLayout()?.diagnostics == [])
                    #expect(beam.getNotes().count == 4)
                    for i in 0..<4 {
                        let upper = try #require(try c.getNote("upper\(i)") as? StaveNote)
                        let lower = try #require(try c.getNote("lower\(i)") as? StaveNote)
                        let member = beamStaff == "upper" ? upper : lower
                        let other = member === upper ? lower : upper
                        #expect(beam.getNotes()[i] === member)
                        #expect(other.getStemSegment() == nil)
                        #expect(!member.shouldDrawFlag() && !other.shouldDrawFlag())
                        #expect(upper.checkTickContext() === lower.checkTickContext())
                        #expect(upper.checkTickContext().getTickID() == i * Tables.RESOLUTION / 8)
                        let segment = try #require(member.getStemSegment())
                        #expect(segment.x == other.getStemX())
                        let (near, far) = direction == .up ? (upper, lower) : (lower, upper)
                        #expect(segment.baseY == far.getYs()[0])
                        #expect(direction.signDouble * (near.getYs()[0] - segment.tipY) > 0, "the stem crosses both heads")
                        #expect(beam.getStripBounds().contains { b in
                            segment.x >= b.x && segment.x <= b.x + b.w && segment.tipY >= b.y && segment.tipY <= b.y + b.h
                        }, "the visible tip meets the beam at its own x")
                    }
                    return svg
                }
                let first = try frame()
                #expect(try frame() == first)
            }
        }
    }

    @Test func aSplitEighthNeedsExactlyOneBeamOwnerAndAUniquePair() throws {
        try isolated {
            for beams in [[String](), ["upper", "lower"]] {
                let (f, _) = makeFactory()
                let c = try f.EasyScore().compose(beamedSplitChordStudy(.up, 8, beams: beams))
                #expect(throws: (any Error).self) { try c.sheet.format() }
                do {
                    try c.sheet.format()
                } catch {
                    #expect("\(error)".contains("beam on exactly one"))
                }
            }
            let (f, _) = makeFactory()
            var source = beamedSplitChordStudy(.up, 8, beams: [])
            let c = try f.EasyScore().compose(source)
            let upperNotes = try (0..<4).map { try #require(try c.getNote("upper\($0)") as? StemmableNote) }
            _ = try f.BeamThrowing(notes: upperNotes)
            try c.sheet.format()
            #expect(try #require(try c.getNote("lower0") as? StaveNote).shouldDrawFlag() == false)
            source.continuous?.splitChords.append(ContinuousSplitChord(id: "again", upper: "upper0", lower: "lower0"))
            do {
                _ = try makeFactory().f.EasyScore().compose(source)
                Issue.record("Expected a duplicate split-chord error.")
            } catch {
                #expect("\(error)".contains("only one split chord"))
            }
        }
    }

    // MARK: - Continuous beams (continuous-score-tests.mjs)

    @Test func aCrossBarBeamRefitsTheSameFourAttacksOnOneRowOrTwo() throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let c = try f.EasyScore().compose(continuousBeamStudy())
            let l = try #require(c.sheet.getContinuousLayout())
            let members = try ["b", "c", "d", "e"].map { try #require(try c.getNote($0) as? StaveNote) }
            let beam = try #require(members[0].getBeam())
            func timeline() -> [[String]] {
                c.voices.flatMap { $0.flatMap { $0 } }.map { voice in
                    var onset = 0.0
                    return voice.getTickables().map { t in
                        defer { onset += t.getTicks().value() }
                        return "\(t.getAttribute("id") ?? "") \(onset) \(t.getTicks().value())"
                    }
                }
            }
            let original = timeline()
            func frame(_ width: Double, _ roles: [SpanFragmentPart]) throws -> String {
                ctx.clear()
                try c.sheet.setWidth(width)
                try f.draw(retain: true)
                let svg = ctx.getSVG()
                #expect(l.fragments.map(\.part) == roles)
                #expect(occurrences(svg, "class=\"vf-beam\"") == roles.count)
                #expect(occurrences(svg, "class=\"vf-stem\"") == 6)
                #expect(beam.getNotes().map { ObjectIdentifier($0) } == members.map { ObjectIdentifier($0) })
                #expect(timeline() == original)
                #expect(try c.getNote("g").hasBeam() == false)
                #expect(try c.getNote("f").hasBeam() == false)
                #expect(l.diagnostics == [])
                for n in members {
                    #expect(n.getBeam() === beam)
                    #expect(!n.shouldDrawFlag())
                    let row = try #require(l.rows.firstIndex { r in
                        r.systems.contains { s in s.getStaves().contains { $0 === n.getStave() } }
                    })
                    let line = l.fragments[row], x = n.getStemX()
                    let y = line.y1 + ((line.y2 - line.y1) * (x - line.x1)) / (line.x2 - line.x1)
                    #expect(abs(y - n.getStemExtents().topY) < 0.001, "stem touches the local beam edge")
                }
                return svg
            }
            let wide = try frame(450, [.single])
            _ = try frame(160, [.first, .last])
            #expect(l.fragments[0].x2 > members[1].getStemX())
            #expect(l.fragments[1].x1 < members[2].getStemX())
            #expect(try frame(450, [.single]) == wide)
            let forced = try makeFactory().f.EasyScore().compose(
                continuousBeamStudy([ContinuousBoundary(measure: 2, breakBefore: .force)])
            )
            try forced.sheet.setWidth(450).format()
            #expect(forced.sheet.getContinuousLayout()?.fragments.map(\.part) == [.first, .last])
        }
    }

    @Test func aSystemBreakCanLeaveASingleBeamedAttack() throws {
        try isolated {
            let (f, _) = makeFactory()
            var source = continuousBeamStudy([ContinuousBoundary(measure: 2, breakBefore: .force)])
            source.staves[0].measures[0].voices[0].notes = [
                note(["g/4"], "q", id: "g", dots: 1),
                note(["b/4"], "16", id: "b", stem: .down),
                note(["c/5"], "16", id: "c", stem: .down),
            ]
            source.continuous?.spans[0].from = "c"
            let c = try f.EasyScore().compose(source)
            try f.draw(retain: true)
            let fragments = try #require(c.sheet.getContinuousLayout()?.fragments)
            #expect(fragments.count == 2)
            let outgoing = fragments[0], incoming = fragments[1]
            let n = try #require(try c.getNote("c") as? StemmableNote)
            #expect(outgoing.x1 <= n.getStemX() && outgoing.x2 > n.getStemX())
            #expect(outgoing.y1 == outgoing.y2)
            #expect(incoming.x1 < (try #require(try c.getNote("d") as? StemmableNote)).getStemX())
            #expect(try #require(n.getBeam()).getStripBounds().allSatisfy { ($0.x + $0.y + $0.w + $0.h).isFinite })
            for bad in ["g", "f"] {
                var input = continuousBeamStudy()
                if bad == "g" { input.continuous?.spans[0].from = bad } else { input.continuous?.spans[0].to = bad }
                do {
                    _ = try makeFactory().f.EasyScore().compose(input)
                    Issue.record("Expected an unbeamable anchor error.")
                } catch {
                    #expect("\(error)".contains("beamable pitched notes"))
                }
            }
        }
    }

    @Test func aSameMeasureContinuousBeamMatchesNativeBeamInk() throws {
        func render(_ continuous: Bool) throws -> [String] {
            try isolated {
                let (f, ctx) = makeFactory()
                var source = continuousBeamStudy()
                source.staves[0].measures.removeLast()
                source.staves[0].measures[0].voices[0].notes = [
                    note(["g/4"], "q", id: "g", stem: .up), note(["b/4"], "8", id: "b", stem: .up),
                    note(["c/5"], "8", id: "c", stem: .up),
                ]
                source.continuous?.spans = continuous ? [ContinuousSpan(id: "local", kind: .beam, from: "b", to: "c")] : []
                let c = try f.EasyScore().compose(source)
                if !continuous {
                    _ = try f.BeamThrowing(notes: try ["b", "c"].map { try #require(try c.getNote($0) as? StemmableNote) })
                }
                try f.draw()
                // Compare the drawn geometry: the paths and rectangles without element IDs.
                let svg = ctx.getSVG()
                return svg.components(separatedBy: "<").filter { $0.hasPrefix("path") || $0.hasPrefix("rect") }
                    .map { $0.replacingOccurrences(of: #"id="[^"]*""#, with: "", options: .regularExpression) }
                    .sorted()
            }
        }
        #expect(try render(true) == render(false))
    }

    // MARK: - Glissandi (continuous-score-tests.mjs)

    @Test(arguments: [false, true])
    func straightGlissandiPreserveDirectionAndHeadClearanceThroughABreak(_ descending: Bool) throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let score = try f.EasyScore().compose(glissandoStudy(descending))
            let from = try #require(try score.getNote("from") as? StaveNote)
            let to = try #require(try score.getNote("to") as? StaveNote)
            let layout = try #require(score.sheet.getContinuousLayout())
            func render(_ width: Double, _ parts: [SpanFragmentPart]) throws -> (segments: [SpanFragment], svg: String) {
                ctx.clear()
                try score.sheet.setWidth(width)
                try f.draw(retain: true)
                let segments = layout.fragments
                // This study has only glissando spans: one stroked path per fragment.
                let lines = SVGRenderContext(width: 960, height: 900)
                try layout.draw(lines)
                #expect(occurrences(lines.getSVG(), "<path") == segments.count)
                #expect(segments.map(\.part) == parts)
                #expect(layout.diagnostics == [])
                let first = segments[0], last = segments[segments.count - 1]
                let a = from.getHeadInk()[1], b = to.getHeadInk()[0]
                #expect(first.x1 > a.x + a.w && last.x2 < b.x)
                #expect(first.y1 == from.getYs()[1])
                #expect(last.y2 == to.getYs()[0])
                for s in segments {
                    #expect(s.x2 > s.x1)
                    #expect((s.y2 - s.y1).sign == (descending ? .plus : .minus))
                    let row = layout.rows[s.row]
                    #expect(min(s.y1, s.y2) >= row.y && max(s.y1, s.y2) < row.y + row.height)
                }
                return (segments, ctx.getSVG())
            }
            let wide = try render(430, [.single])
            let split = try render(150, [.first, .last])
            let left = split.segments[0], right = split.segments[1]
            #expect(abs((left.y2 - left.y1) / (left.x2 - left.x1) - (right.y2 - right.y1) / (right.x2 - right.x1)) < 0.00001)
            let restored = try render(430, [.single])
            #expect(restored.segments == wide.segments && restored.svg == wide.svg)
            let forced = try makeFactory().f.EasyScore().compose(glissandoStudy(descending, true))
            try forced.sheet.setWidth(430).format()
            #expect(forced.sheet.getContinuousLayout()?.fragments.map(\.part) == [.first, .last])
        }
    }

    @Test func aGlissandoRetainsItsPitchProgressionThroughAnIntermediateRow() throws {
        try isolated {
            var source = glissandoStudy()
            source.staves[0].measures.insert(
                EasyScoreMeasureSpec(clef: .bass, voices: [EasyScoreVoiceSpec(notes: [note(["g/3"], "h")])]), at: 1
            )
            source.continuous?.boundaries = [2, 3].map { ContinuousBoundary(measure: $0, breakBefore: .force) }
            let (f, _) = makeFactory()
            let c = try f.EasyScore().compose(source)
            try f.draw(retain: true)
            let fragments = try #require(c.sheet.getContinuousLayout()?.fragments)
            #expect(fragments.map(\.part) == [.first, .middle, .last])
            #expect(fragments.allSatisfy { $0.y2 < $0.y1 })
            // On the last two rows the same clef projects the shared boundary pitch onto the same staff line.
            #expect(abs(fragments[1].y2 - c.staves[1][0].getY() - (fragments[2].y1 - c.staves[2][0].getY())) < 0.00001)
        }
    }

    // MARK: - Tied bends (instrument-profile-tests.mjs)

    @Test func aTiedTabBendRisesOnceAndReleasesOnItsOwnStringAfterReflow() throws {
        try isolated {
            let source = try tiedBendStudy()
            let (f, ctx) = makeFactory(width: 600, height: 720)
            let score = try f.EasyScore().compose(source)
            let layout = try #require(score.sheet.getContinuousLayout())
            struct Frame: Equatable {
                var parts: [SpanFragmentPart]
                var phases: [[Bool]]
                var strings: [[Int]?]
                var ratios: [Double]
                var labels: [String]
                var svg: String
            }
            func frame(_ width: Double) throws -> Frame {
                ctx.clear()
                try score.sheet.setWidth(width)
                try f.draw(retain: true)
                let nav = try ScoreNavigation(score, staves: source.staves)
                let fragments = layout.fragments.filter { $0.id == "tied-bend" }
                let first = try score.getNote("tabrise"), last = try score.getNote("tabrelease")
                let space = first.checkStave().space(1)
                let rise = try #require(fragments[0].bend), release = try #require(fragments[fragments.count - 1].bend)
                for f in fragments {
                    let bend = try #require(f.bend)
                    #expect(bend.stringY == score.staves[layout.rows[f.row].measures[0] - 1][1].getYForLine(2))
                }
                // Upstream runs this in a browser. With node-canvas metrics, upstream 5.9.0 also overflows the first
                // narrow row by 14.5 px (169.4987 against 155), as here (169.4999). Only that overflow is accepted.
                #expect(layout.diagnostics.allSatisfy { $0.code == .rowOverflow && width == 155 })
                for tab in [first, last] { #expect(!tab.getModifiers().contains { $0 is Bend }) }
                let events = nav.events.filter { $0.id == "tabrise" || $0.id == "tabrelease" }
                #expect(events.map { [$0.id, $0.onset, $0.duration] } == [["tabrise", "1/4", "1/4"], ["tabrelease", "0/1", "1/4"]])
                #expect(events[0].label.contains("Bend 2 semitones on string 3"))
                #expect(events[1].label.contains("Sustain and release tied string 3"))
                let svg = ctx.getSVG()
                let groups = svg.components(separatedBy: "class=\"vf-tied-bend\"").dropFirst()
                let labels = groups.compactMap { g -> String? in
                    let body = g.components(separatedBy: "</g>")[0]
                    guard let text = body.components(separatedBy: "<text").dropFirst().first else { return nil }
                    return text.components(separatedBy: ">").dropFirst().first?.components(separatedBy: "<").first
                }
                return Frame(
                    parts: fragments.map(\.part),
                    phases: fragments.map { [$0.bend?.peakX != nil, $0.bend?.releaseX != nil] },
                    strings: fragments.map(\.strings),
                    ratios: [
                        (try #require(rise.peakX) - rise.left) / (first.checkStave().getNoteEndX() - space * 0.35 - rise.left),
                        (try #require(release.releaseX) - last.getTieRightX()) / (release.right - last.getTieRightX()),
                    ],
                    labels: labels,
                    svg: svg
                )
            }
            let wide = try frame(520), narrow = try frame(155), restored = try frame(520)
            #expect(restored == wide)
            #expect(wide.parts == [.single])
            #expect(narrow.parts == [.first, .last])
            #expect(wide.phases == [[true, true]])
            #expect(narrow.phases == [[true, false], [false, true]])
            for frame in [wide, narrow] {
                #expect(frame.strings.allSatisfy { $0 == [3] })
                #expect(frame.ratios.allSatisfy { abs($0 - 0.5) < 1e-9 })
                #expect(frame.labels == ["full"])
            }
            let book = try Publication(source).render(PublicationOptions(staves: ["tab"], systemBreaks: [2]))
            let spans = try book.pages.flatMap { page -> [[String: Any]] in
                let text = try #require(page.metadata)
                let json = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
                return json["spans"] as? [[String: Any]] ?? []
            }
            #expect(spans.map { "\($0["id"] ?? "") \($0["part"] ?? "") \($0["strings"] ?? "")" } == [
                "tied-bend first (\n    3\n)", "tied-bend last (\n    3\n)",
            ])
            #expect(spans.map { ($0["bend"] as? [String: Any])?["semitones"] as? Double } == [2, 2])
        }
    }

    @Test func invalidTiedBendsAreRejected() throws {
        try isolated {
            let cases: [(String, () throws -> EasyScoreCompositionSpec)] = [
                ("BadArguments", { try tiedBendStudy(bend: TiedBend(semitones: 2, rise: (1, 2), hold: (0, 1), release: (1, 1))) }),
                ("BadArguments", { try tiedBendStudy(bend: TiedBend(semitones: 2, rise: (1, 2), hold: (1, 2), release: (1, 3))) }),
                ("BadContinuousScore", { try tiedBendStudy(to: "tablead") }),
                ("BadContinuousScore", { try tiedBendStudy(to: "tablast", lastTab: true) }),
                ("BadContinuousScore", { try tiedBendStudy(from: "noterise") }),
            ]
            for (code, make) in cases {
                do {
                    _ = try makeFactory().f.EasyScore().compose(try make())
                    Issue.record("Expected \(code).")
                } catch let error as VexError {
                    #expect(error.code == code)
                }
            }
        }
    }

    // MARK: - Chord harmony (instrument-profile-tests.mjs)

    @Test func writtenHarmoniesTransposeRootsAndBassesWithTheMelody() throws {
        try isolated {
            let slash = ChordHarmony(root: "G", quality: "7", bass: "B")
            let raised = try NotationSpelling.transposeChord(slash, semitones: 2, steps: 1)
            #expect(raised == ChordHarmony(root: "A", quality: "7", bass: "C#"))
            #expect(try NotationSpelling.transposeChord(raised, semitones: -2, steps: -1) == slash)
            let altered = ChordHarmony(root: "Bb", quality: "7(b9,#11)", bass: "Db")
            let flat = try NotationSpelling.transposeChord(ChordHarmony(root: "C"), semitones: 1, steps: 1)
            let sharp = try NotationSpelling.transposeChord(ChordHarmony(root: "C"), semitones: 1, steps: 0)
            #expect(try [flat, sharp].map { try NotationSpelling.chordText($0) } == ["D\u{266D}", "C\u{266F}"])
            let (f, ctx) = makeFactory(width: 700, height: 190)
            let melody = try ["b/3", "d/4", "f/4", "g/4"].map { try NotationSpelling.transpose($0, semitones: 2, steps: 1) }
            let notes = melody.enumerated().map { i, key in note([key], "q", id: "n\(i)") }
            let chords = [
                EasyScoreLeadMark(note: "n0", harmony: raised),
                EasyScoreLeadMark(note: "n1", harmony: try NotationSpelling.transposeChord(altered, semitones: 2, steps: 1)),
                EasyScoreLeadMark(note: "n2", harmony: flat),
                EasyScoreLeadMark(note: "n3", text: "N.C."),
            ]
            let score = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "lead", measures: [EasyScoreMeasureSpec(
                    voices: [EasyScoreVoiceSpec(notes: notes)], chords: chords
                )])],
                sheet: SheetOptions(width: 670)
            ))
            try f.draw()
            #expect(try (0..<4).map { try score.getNote("n\($0)").getKeys()[0] } == ["c#/4", "e/4", "g/4", "a/4"])
            let labels = ctx.getSVG().components(separatedBy: "class=\"vf-annotation\"").dropFirst().compactMap { g in
                g.components(separatedBy: "<text").dropFirst().first?.components(separatedBy: ">").dropFirst().first?
                    .components(separatedBy: "<").first
            }
            #expect(labels == ["A7/C\u{266F}", "C7(b9,#11)/E\u{266D}", "D\u{266D}", "N.C."])
            expectBadArguments { _ = try NotationSpelling.transposeChord(ChordHarmony(root: "H"), semitones: 2, steps: 1) }
            expectBadArguments { _ = try NotationSpelling.transposeChord(ChordHarmony(root: "C", bass: "B/3"), semitones: 2, steps: 1) }
            expectBadArguments { _ = try NotationSpelling.transposeChord(ChordHarmony(root: "C"), semitones: 9, steps: 0) }
        }
    }

    // MARK: - Alternating tremolos (instrument-profile-tests.mjs)

    @Test func wholeFourStrokeAndCrossStaffTremolosRetainTimeAndJoinTheirEndpoints() throws {
        try isolated {
            Flow.setFonts("Bravura", "Academico")
            let wholeStudy = try TremoloStudy("w", 3)
            let wholeSVG = try wholeStudy.draw()
            let whole = TremoloStudy.bars(wholeSVG)
            #expect(occurrences(wholeSVG, "class=\"vf-stem\"") == 0)
            #expect(whole.count == 3)
            #expect(wholeStudy.notes.map { $0.getTicks().value() / Double(Tables.RESOLUTION) } == [0.5, 0.5])
            let heads = wholeStudy.notes.map { $0.getHeadInk()[0] }
            #expect(whole.allSatisfy { $0[0] > heads[0].x + heads[0].w && $0[2] < heads[1].x && $0[1] == $0[3] })

            let fourStudy = try TremoloStudy("h", 4)
            let four = TremoloStudy.bars(try fourStudy.draw())
            let three = TremoloStudy.bars(try TremoloStudy("h", 3).draw())
            let quarterStudy = try TremoloStudy("q", 3)
            #expect(TremoloStudy.bars(try quarterStudy.draw()).count == 3)
            #expect(fourStudy.notes.map { $0.getTicks().value() / Double(Tables.RESOLUTION) } == [0.25, 0.25])
            #expect(quarterStudy.notes.map { $0.getTicks().value() / Double(Tables.RESOLUTION) } == [0.125, 0.125])
            #expect(four.count == 4)
            #expect(Array(four.prefix(3)) == three)
            let step = four[1][1] - four[0][1]
            #expect(abs(step) > abs(four[0][5] - four[0][1]))
            #expect(abs(four[3][1] - four[2][1] - step) < 0.01)

            let cross = try TremoloStudy("h", 3, crossStaff: true)
            var tips: [Double] = []
            var frames: [String] = []
            for gap in [82.0, 132, 82] {
                let svg = try cross.draw(gap)
                frames.append(svg)
                let bars = TremoloStudy.bars(svg)
                #expect(bars.count == 3)
                #expect(cross.notes.map { $0.getTicks().value() / Double(Tables.RESOLUTION) } == [0.25, 0.25])
                let left = try #require(cross.notes[0].getStemSegment())
                let right = try #require(cross.notes[1].getStemSegment())
                tips.append(right.tipY)
                for bar in bars {
                    #expect(abs((bar[3] - bar[1]) / (bar[2] - bar[0])) <= 0.251)
                    #expect(abs(bar[0] - left.x) < 0.01 && abs(bar[2] - right.x) < 0.01)
                }
                #expect(occurrences(svg, "<rect") >= 2)
            }
            #expect(tips[1] - tips[0] == 50)
            #expect(frames[2] == frames[0])
            #expect(cross.voice.isComplete())

            // Moving one stave away from the shared measure is an error.
            let disjoint = try TremoloStudy("h", 3, crossStaff: true)
            _ = try disjoint.draw()
            _ = disjoint.lower.setX(400)
            expectBadArguments { try disjoint.tremolo.draw() }
        }
    }

    // MARK: - Feathered beams (engraving-layout-tests.mjs)

    @Test func theTwoSidesOfABrokenFeatheredBeamShareTheSameSecondarySpacing() throws {
        try isolated {
            let (f, _) = makeFactory()
            let notes = { (bar: Int) in
                (0..<4).map { i in note(["c/5"], "16", id: "s\(bar)\(i)", stem: .down) }
            }
            let c = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "solo", time: .meter(1, 4), measures: [0, 1].map { bar in
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: notes(bar))])
                })],
                continuous: ContinuousOptions(
                    boundaries: [ContinuousBoundary(measure: 2, breakBefore: .force)],
                    spans: [ContinuousSpan(id: "fan", kind: .beam, from: "s00", to: "s13")]
                )
            ))
            let beam = try #require(try c.getNote("s00").getBeam())
            func spreads(_ direction: FeatheredBeamDirection?) throws -> [Double] {
                beam.renderOptions.feathered = direction
                try c.sheet.format()
                let ctx = SVGRenderContext(width: 960, height: 900)
                try beam.setContext(ctx).draw()
                let paths = ctx.getSVG().components(separatedBy: "<path").dropFirst().compactMap { path -> [Double]? in
                    guard let d = path.components(separatedBy: "d=\"").dropFirst().first?.components(separatedBy: "\"").first,
                          d.hasSuffix("Z") else { return nil }
                    return d.split(whereSeparator: { !"-.0123456789".contains($0) }).compactMap { Double($0) }
                }
                #expect(paths.count == 4)
                // Each strip: (x1, y1), (x1, y1 + t), (x2, y2 + t), (x2, y2).
                return [0, 2].flatMap { i in [1, 7].map { j in abs(paths[i][j] - paths[i + 1][j]) } }
            }
            for direction in [FeatheredBeamDirection.left, .right] {
                let s = try spreads(direction)
                let first = s[0], outgoing = s[1], incoming = s[2], last = s[3]
                #expect(abs(incoming - outgoing) < 0.01)
                #expect(outgoing > min(first, last) && outgoing < max(first, last))
                #expect((first > last) == (direction == .left))
            }
            #expect(Set(try spreads(nil)) == [7.5])
        }
    }

    @Test func generatedFeatheredBeamsFanTheirSecondaries() throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let measures = [0, 1].map { bar in
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(
                    notes: ["16", "16", "16", "16", "q"].enumerated().map { i, d in
                        note([i == 4 ? "d/5" : "c/5"], d, id: "lead-\(bar)-\(i)", stem: .down)
                    },
                    autoBeam: EasyScoreAutoBeamOptions(
                        groups: [Fraction(1, 4)], stemDirection: .down, feathered: bar == 1 ? .left : .right
                    )
                )])
            }
            let c = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "lead", time: .meter(2, 4), measures: measures)],
                sheet: SheetOptions(width: 620, x: 16, y: 12, rowGap: 15, measurePadding: 12)
            ))
            try f.draw()
            _ = ctx
            for bar in [0, 1] {
                let notes = try (0..<5).map { try #require(try c.getNote("lead-\(bar)-\($0)") as? StemmableNote) }
                let beam = try #require(notes[0].getBeam())
                #expect(beam.renderOptions.feathered == (bar == 1 ? .left : .right))
                let primary = beam.getBeamYToDraw()
                let firstX = notes[0].getStemX()
                for n in notes.prefix(4) {
                    let y: Double = beam.getSlopeY(n.getStemX(), firstX, primary, beam.slope)
                    let distance: Double = abs(n.getStemExtents().topY - y)
                    #expect(distance < 0.02)
                }
                let ticks: [Double] = notes.map { $0.getTicks().value() / Double(Tables.RESOLUTION) }
                let expected: [Double] = [0.0625, 0.0625, 0.0625, 0.0625, 0.25]
                #expect(ticks == expected)
                let strips = try beam.getStrips()
                #expect(strips.count == 2)
                let spread = [abs(strips[1].y1 - strips[0].y1), abs(strips[1].y2 - strips[0].y2)]
                #expect(spread[bar] < 0.03 && spread[1 - bar] > 5)
            }
        }
    }

    // MARK: - Lyric elision (phrase-layout-tests.mjs)

    @Test func twoElidedSyllablesShareOneCenteredAnchor() throws {
        try isolated {
            let measures = [0, 1].map { bar -> EasyScoreMeasureSpec in
                let ids = (0..<3).map { "word-\(bar)-\($0)" }
                return EasyScoreMeasureSpec(
                    voices: [EasyScoreVoiceSpec(notes: ["e/4", "f/4", "g/4"].enumerated().map { i, k in note([k], "q", id: ids[i]) })],
                    verses: [
                        [
                            EasyScoreLyricMark(note: ids[0], text: "la", hyphenAfter: bar == 1, elideWith: "mi"),
                            EasyScoreLyricMark(note: ids[1], text: "fa"),
                            EasyScoreLyricMark(note: ids[2], text: "sol"),
                        ],
                        bar == 0
                            ? ids.enumerated().map { i, id in EasyScoreLyricMark(note: id, text: ["do", "re", "mi"][i]) }
                            : [EasyScoreLyricMark(note: ids[0], text: "do", extendTo: ids[2])],
                    ]
                )
            }
            let (f, ctx) = makeFactory(width: 660, height: 530)
            let music = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "voice", time: .meter(3, 4), measures: measures)],
                sheet: SheetOptions(width: 620, x: 10, y: 8),
                continuous: ContinuousOptions()
            ))
            let note = try music.getNote("word-1-0")
            let annotations = note.getModifiers().compactMap { $0 as? Annotation }
            let group = annotations[0], plain = annotations[1]
            struct Frame: Equatable {
                var rows: Int
                var x: Double
                var baseline: Double
                var width: Double
            }
            var frames: [Frame] = []
            for width in [620.0, 220, 620] {
                try music.sheet.setWidth(width)
                ctx.clear()
                try f.draw(retain: true)
                let baseline = try group.computeY().y
                let (x, textWidth) = try group.computeX()
                let geometry = group.getTextInk(x, baseline)
                let connectors = music.systems[1].getPhraseLayout().getLyricConnectors()
                #expect(connectors.count == 2)
                #expect(group.getText() == "la" + Glyphs.lyricsElision + "mi")
                #expect(group.checkAttachedNote() === note && plain.checkAttachedNote() === note)
                #expect(abs(x + textWidth / 2 - (try plain.computeX().x) - plain.getWidth() / 2) < 1e-6)
                #expect(plain.getText() == "do")
                #expect(baseline < (try plain.computeY().y))
                #expect(textWidth > VexElement.measureWidth("lami", key: "Annotation.lyric"))
                #expect(geometry.x + geometry.w < connectors[0].x)
                let last = try #require(try music.getNote("word-1-2") as? StaveNote)
                #expect(connectors[1].x + connectors[1].w == last.getNoteHeadBeginX() + last.getGlyphWidth())
                #expect(music.systems[1].getPhraseLayout().diagnostics == [])
                frames.append(Frame(rows: music.sheet.getRows().count, x: x, baseline: baseline, width: textWidth))
            }
            #expect(frames.map(\.rows) == [1, 2, 1])
            #expect(frames[2] == frames[0])
        }
    }

    @Test func anEmptyElisionIsRejected() throws {
        try isolated {
            let system = Factory(options: FactoryOptions(width: 400)).System(options: SystemOptions(width: 400))
            let n = StaveNote(StaveNoteStruct(parsingDuration: "q", keys: ["c/4"])!)
            let stave = Stave(x: 0, y: 0, width: 300)
            _ = n.setStave(stave)
            #expect(throws: PhraseLayoutError.invalidElision) {
                try system.getPhraseLayout().addVerse(stave, [PhraseSyllable(note: n, text: "la", elideWith: " ")])
            }
        }
    }

    // MARK: - Chord spacing (sheet-tests.mjs)

    @Test(arguments: [false, true])
    func chordInkClearsTheNextMeasureAndStaysAttachedThroughReflow(_ continuous: Bool) throws {
        try isolated {
            Flow.setFonts("Bravura", "Academico")
            func frames(_ labels: [String], literal: Bool = false, below: Bool = false, keep: Bool = false)
                throws -> [(gap: Double, offsets: [Double], positions: [Double], rows: [Int], overflow: [Double])] {
                let (f, _) = makeFactory(width: 860, height: 450)
                let anchors = ["last", "first"]
                let measures = ["C4/q, D4, E4, F4[id=\"last\"]", "C4/q[id=\"first\"], D4, E4, F4"].enumerated().map { i, notes in
                    EasyScoreMeasureSpec(
                        voices: [EasyScoreVoiceSpec(notes)],
                        chords: literal && i == 1 ? [EasyScoreLeadMark(note: anchors[i], text: labels[i])] : []
                    )
                }
                let music = try f.EasyScore().compose(EasyScoreCompositionSpec(
                    staves: [EasyScoreStaveSpec(id: "melody", measures: measures)],
                    sheet: SheetOptions(width: 800, measurePadding: 0),
                    continuous: continuous
                        ? ContinuousOptions(boundaries: keep ? [ContinuousBoundary(measure: 2, breakBefore: .keep)] : [])
                        : nil
                ))
                let notes = try anchors.map { try music.getNote($0) }
                let marks: [Modifier] = try notes.enumerated().map { i, n in
                    if literal && i == 1, let mark = n.getModifiers().first(where: { $0 is Annotation }) { return mark }
                    let symbol = ChordSymbol().addText(labels[i]).setReportWidth(false)
                    if below && i == 1 { symbol.setVertical(.bottom) }
                    _ = try n.addModifier(symbol, index: 0)
                    return symbol
                }
                func ink(_ mark: Modifier) throws -> (left: Double, right: Double) {
                    if let symbol = mark as? ChordSymbol { return try symbol.getHorizontalInk() }
                    let annotation = try #require(mark as? Annotation)
                    let box = annotation.getTextInk(try annotation.computeX().x, 0)
                    return (box.x, box.x + box.w)
                }
                return try [800.0, 190, 800].map { width in
                    try music.sheet.setWidth(width)
                    try f.draw(retain: true)
                    let boxes = try marks.map(ink)
                    let positions = notes.map { $0.getModifierStartXY(position: .above, index: 0).x }
                    return (
                        boxes[1].left - boxes[0].right,
                        boxes.enumerated().map { $1.left - positions[$0] },
                        positions,
                        music.sheet.getRows().map { $0.systems.count },
                        music.sheet.getRows().map { $0.overflow }
                    )
                }
            }
            let long = ["C#maj13(#11,b9)/G", "Dbmaj13(#11,b9)/Gb"]
            for literal in [false, true] {
                let result = try frames(long, literal: literal)
                let wide = result[0], narrow = result[1], restored = result[2]
                #expect(wide.rows == [2] && wide.overflow == [0])
                #expect(wide.gap > 0, "rendered labels clear the barline")
                #expect(narrow.rows.count == 2, "the narrow row breaks between measures")
                for i in 0..<2 { #expect(abs(wide.offsets[i] - narrow.offsets[i]) < 0.01) }
                #expect(restored.positions == wide.positions && restored.gap == wide.gap)
            }
            if !continuous {
                #expect(try frames(["C", "G"])[0].positions == frames(long, below: true)[0].positions,
                        "short labels and labels on opposite sides of the staff consume no boundary space")
            } else {
                let kept = try frames(long, keep: true)
                #expect(kept[1].overflow[0] > 0 && kept[1].rows[0] == 2)
                #expect(kept[1].gap > 0, "an unbreakable group reports overflow and still clears the labels")
            }
        }
    }
}

private func expectBadArguments(_ body: () throws -> Void) {
    do {
        try body()
        Issue.record("Expected BadArguments.")
    } catch let error as VexError {
        #expect(error.code == "BadArguments")
    } catch {
        Issue.record("Unexpected error \(error).")
    }
}
