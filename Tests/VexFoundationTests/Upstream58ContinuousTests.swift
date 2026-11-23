// Logic-level tests for the continuous-layout behaviors ported from VexFlow 5.7.0 → 5.8.0 (group "Continuous").
// Ported from the 5.8.0 assertions in tests/node/continuous-score-tests.mjs and tests/node/phrase-layout-tests.mjs,
// with the studies of tests/engraving/continuous-studies.mjs and tests/engraving/phrase-studies.mjs.
// The upstream tests replace methods of a node-canvas context or run in a browser. These tests use a recording
// context that forwards to the SVG string context. Pixel comparisons become comparisons of the recorded paths
// and of the geometry. Text metrics come from CoreText, not node-canvas.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

/// A context that records path calls, the active dash pattern of each stroke and the text, and forwards all
/// calls to an SVG context.
private final class RecordingContext: RenderContext {
    enum Call: Equatable {
        case beginPath
        case moveTo(Double, Double)
        case lineTo(Double, Double)
        case quadraticCurveTo(Double, Double, Double, Double)
        case bezierCurveTo(Double, Double, Double, Double, Double, Double)
        case closePath
        case stroke([Double])
        case fill
    }

    let inner: SVGRenderContext
    var calls: [Call] = []
    var texts: [(text: String, x: Double, y: Double)] = []
    private var dash: [Double] = []
    private var dashStack: [[Double]] = []

    init(width: Double = 900, height: Double = 700) {
        inner = SVGRenderContext(width: width, height: height)
    }

    func reset() {
        calls = []
        texts = []
    }

    /// The current dash pattern (upstream `ctx.getLineDash()`).
    var lineDash: [Double] { dash }

    var fillStyle: String {
        get { inner.fillStyle }
        set { inner.fillStyle = newValue }
    }
    var strokeStyle: String {
        get { inner.strokeStyle }
        set { inner.strokeStyle = newValue }
    }
    func clear() { inner.clear() }
    func setDefaultStyle(_ style: ElementStyle) -> Self { inner.setDefaultStyle(style); return self }
    func getDefaultStyle() -> ElementStyle { inner.getDefaultStyle() }
    func save() -> Self { dashStack.append(dash); inner.save(); return self }
    func restore() -> Self { dash = dashStack.popLast() ?? []; inner.restore(); return self }
    func setFillStyle(_ style: String) -> Self { inner.setFillStyle(style); return self }
    func setBackgroundFillStyle(_ style: String) -> Self { inner.setBackgroundFillStyle(style); return self }
    func setStrokeStyle(_ style: String) -> Self { inner.setStrokeStyle(style); return self }
    func setShadowColor(_ color: String) -> Self { inner.setShadowColor(color); return self }
    func setShadowBlur(_ blur: Double) -> Self { inner.setShadowBlur(blur); return self }
    func setLineWidth(_ width: Double) -> Self { inner.setLineWidth(width); return self }
    func setLineCap(_ capType: VexLineCap) -> Self { inner.setLineCap(capType); return self }
    func setLineDash(_ dashPattern: [Double]) -> Self {
        dash = dashPattern
        inner.setLineDash(dashPattern)
        return self
    }
    func scale(_ x: Double, _ y: Double) -> Self { inner.scale(x, y); return self }
    func resize(_ width: Double, _ height: Double) -> Self { inner.resize(width, height); return self }
    func beginPath() -> Self { calls.append(.beginPath); inner.beginPath(); return self }
    func moveTo(_ x: Double, _ y: Double) -> Self { calls.append(.moveTo(x, y)); inner.moveTo(x, y); return self }
    func lineTo(_ x: Double, _ y: Double) -> Self { calls.append(.lineTo(x, y)); inner.lineTo(x, y); return self }
    func bezierCurveTo(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double, _ y: Double) -> Self {
        calls.append(.bezierCurveTo(a, b, c, d, x, y))
        inner.bezierCurveTo(a, b, c, d, x, y)
        return self
    }
    func quadraticCurveTo(_ a: Double, _ b: Double, _ x: Double, _ y: Double) -> Self {
        calls.append(.quadraticCurveTo(a, b, x, y))
        inner.quadraticCurveTo(a, b, x, y)
        return self
    }
    func arc(_ x: Double, _ y: Double, _ r: Double, _ s: Double, _ e: Double, _ ccw: Bool) -> Self {
        inner.arc(x, y, r, s, e, ccw)
        return self
    }
    func closePath() -> Self { calls.append(.closePath); inner.closePath(); return self }
    func fill() -> Self { calls.append(.fill); inner.fill(); return self }
    func stroke() -> Self { calls.append(.stroke(dash)); inner.stroke(); return self }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.rect(x, y, w, h); return self }
    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.fillRect(x, y, w, h); return self }
    func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.clearRect(x, y, w, h); return self }
    func pointerRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.pointerRect(x, y, w, h); return self }
    func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double) { inner.openRotation(angleDegrees, x, y) }
    func closeRotation() { inner.closeRotation() }
    func fillText(_ text: String, _ x: Double, _ y: Double) -> Self {
        texts.append((text, x, y))
        inner.fillText(text, x, y)
        return self
    }
    func measureText(_ text: String) -> TextMeasure { inner.measureText(text) }
    func setFont(_ family: String?, _ size: Double?, _ weight: String?, _ style: String?) -> Self {
        inner.setFont(family, size, weight, style)
        return self
    }
    func setFont(_ fontInfo: FontInfo) -> Self { inner.setFont(fontInfo); return self }
    func getFont() -> String { inner.getFont() }
    func openGroup(_ cls: String?, _ id: String?) -> Any? { inner.openGroup(cls, id) }
    func closeGroup() { inner.closeGroup() }
    func add(_ child: Any) { inner.add(child) }

    /// Quadratic arms as `[start, control, end]`, with the start taken from the latest `moveTo`.
    var quadraticArms: [[(Double, Double)]] {
        var start = (0.0, 0.0)
        var arms: [[(Double, Double)]] = []
        for call in calls {
            if case .moveTo(let x, let y) = call { start = (x, y) }
            if case .quadraticCurveTo(let cx, let cy, let x, let y) = call {
                arms.append([start, (cx, cy), (x, y)])
                start = (x, y)
            }
        }
        return arms
    }
}

private func makeFactory(width: Double = 900, height: Double = 700) -> (f: Factory, ctx: RecordingContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = RecordingContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func note(_ keys: [String], _ duration: String, id: String? = nil, stem: StemDirection? = nil) -> EasyScoreContent {
    // The test inputs are valid literals.
    let value = StaveNoteStruct(parsingDuration: duration, keys: keys, stemDirection: stem)!
    return .note(value, id: id)
}

private func tab(_ id: String, _ str: Int, _ fret: Int, _ duration: String) -> EasyScoreContent {
    // The test inputs are valid literals.
    .tab(TabNoteStruct(parsingDuration: duration, positions: [TabNotePosition(str: str, fret: fret)])!, id: id)
}

private func errorMessage(_ body: () throws -> Void) -> String? {
    do {
        try body()
        return nil
    } catch let error as VexError {
        return error.message
    } catch {
        return error.localizedDescription
    }
}

private let quarter = Double(Tables.RESOLUTION / 4)

/// `spec(count, continuous)` from continuous-score-tests.mjs: one whole note for each measure.
private func spec(_ count: Int, _ continuous: ContinuousOptions = ContinuousOptions()) -> EasyScoreCompositionSpec {
    EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "staff", measures: (0..<count).map { i in
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [note(["c/5"], "w", id: "n\(i)")])])
        })],
        continuous: continuous
    )
}

// MARK: - Studies (tests/engraving/*-studies.mjs at 5.8.0)

/// `glissandoStudy(descending)` (5.7.0).
private func glissandoStudy(_ descending: Bool = false) -> EasyScoreCompositionSpec {
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
            spans: [ContinuousSpan(id: "slide", kind: .glissando, from: "from", to: "to", fromHead: 1, toHead: 0)]
        )
    )
}

/// `sextupletStudy()`: six written eighths on beat four and the following downbeat.
private func sextupletStudy() -> EasyScoreCompositionSpec {
    let pitches = ["g/4", "a/4", "b/4", "c/5", "b/4", "a/4"]
    let member = { (i: Int) in note([pitches[i]], "8", id: "t\(i)") }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "flute", time: .meter(4, 4), measures: [
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [.notation("G4/q, A4/q, B4/q")] + (0...2).map(member))]),
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(
                notes: (3...5).map(member) + [note(["g/4"], "q", id: "next"), .notation("F4/q, G4/q")]
            )]),
        ])],
        sheet: SheetOptions(width: 530, rowGap: 18),
        continuous: ContinuousOptions(
            tuplets: [ContinuousTuplet(id: "six", members: (0...5).map { "t\($0)" }, numNotes: 6, notesOccupied: 4)]
        )
    )
}

/// `tieStudy(side, split, crowded)`: two simultaneous TAB voices; a string-five tie crosses a string-four fret.
private func tieStudy(_ side: ContinuousSpanSide?, split: Bool = false, crowded: Bool = false) -> EasyScoreCompositionSpec {
    let measures = (0..<2).map { m -> EasyScoreMeasureSpec in
        let half = split && m == 1 ? 2 : 5
        let quarterString = split && m == 0 ? 2 : 5
        let upper = [2, 2, 4, 2, 2, 2].enumerated().map { i, str -> EasyScoreContent in
            if crowded {
                let positions = (1...6).map { TabNotePosition(str: $0, fret: 38) }
                return .tab(TabNoteStruct(parsingDuration: "8", positions: positions)!, id: "upper\(m)\(i)")
            }
            return tab("upper\(m)\(i)", str, 3, "8")
        }
        return EasyScoreMeasureSpec(voices: [
            EasyScoreVoiceSpec(notes: [tab("bassHalf\(m)", half, 2, "h"), tab("bassQuarter\(m)", quarterString, 2, "q")]),
            EasyScoreVoiceSpec(notes: upper),
        ])
    }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "guitar", kind: .tab, time: .meter(3, 4), measures: measures)],
        sheet: SheetOptions(width: 480, rowGap: 0),
        continuous: ContinuousOptions(spans: [
            ContinuousSpan(id: "hold", kind: .tie, from: "bassHalf0", to: split ? "bassQuarter1" : "bassQuarter0", side: side),
        ])
    )
}

/// `stanzaStudy(stanza)`: two hymn verses start in the first bar and continue as plain syllable lists.
private func stanzaStudy(_ stanza: String = "1.") -> EasyScoreCompositionSpec {
    let words = [
        ["Bright", "stars", "are", "still", "be", "yond", "the", "hill"],
        ["The", "dawn", "draws", "near", "a", "cross", "the", "field"],
    ]
    let bars = [["g/4", "a/4", "b/4", "a/4"], ["g/4", "e/4", "d/4", "c/4"]]
    let measures = bars.enumerated().map { bar, keys -> EasyScoreMeasureSpec in
        let ids = keys.indices.map { "g\(bar * 4 + $0)" }
        let notes = keys.enumerated().map { beat, key in note([key], "q", id: ids[beat]) }
        let verses = words.enumerated().map { i, row -> EasyScoreVerse in
            let syllables = ids.enumerated().map { beat, id in
                EasyScoreLyricMark(note: id, text: row[bar * 4 + beat], hyphenAfter: bar == 1 && beat == 0)
            }
            return EasyScoreVerse(stanza: bar == 0 ? (i == 0 ? stanza : "12.") : nil, syllables: syllables)
        }
        return EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: notes)], verses: verses)
    }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "voice", time: .meter(4, 4), measures: measures)],
        sheet: SheetOptions(width: 620, x: 10, y: 8),
        continuous: ContinuousOptions()
    )
}

@Suite("Upstream 5.8.0 port: Continuous")
struct Upstream58ContinuousTests {
    // MARK: - Flared hairpins, half-dashed slurs, dashed ties and wavy glissandi

    @Test func flaredHairpinFragmentsDrawMatchingAperturesAtASystemBreak() throws {
        try isolated {
            for kind in [ContinuousSpanKind.crescendo, .diminuendo] {
                let (f, ctx) = makeFactory()
                let span = ContinuousSpan(id: "flare", kind: kind, from: "n0", to: "n4", niente: true, flared: true)
                let score = try f.EasyScore().compose(spec(5, ContinuousOptions(spans: [span])))
                let layout = try #require(score.sheet.getContinuousLayout())
                for width in [600.0, 120, 600] {
                    try score.sheet.setWidth(width).format()
                    ctx.reset()
                    try layout.draw(ctx)
                    let arms = ctx.quadraticArms
                    #expect(arms.count == 2 * layout.fragments.count)
                    #expect(layout.fragments.filter { $0.nienteTip != nil }.count == 1)
                    #expect((layout.fragments.count == 1) == (width == 600))
                    for (i, fragment) in layout.fragments.enumerated() {
                        #expect(fragment.flared == true)
                        let open = { (p: Double) in kind == .crescendo ? p : 1 - p }
                        let a = open(fragment.progress.0), b = open(fragment.progress.1)
                        let top = arms[2 * i], bottom = arms[2 * i + 1]
                        // The end ordinates are the aperture at each break. The control ordinate keeps the tangent.
                        for (j, ratio) in [a * a, a * b, b * b].enumerated() {
                            #expect(abs(bottom[j].1 - top[j].1 - fragment.space * 1.1 * ratio) < 1e-8)
                        }
                        #expect(abs(top[1].0 - (fragment.x1 + fragment.x2) / 2) < 1e-8)
                    }
                }
            }
        }
    }

    @Test func halfDashedSlursChangeStrokeOnceAtTheMidpointOfTheWholePhrase() throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let span = ContinuousSpan(id: "editorial", kind: .slur, from: "n0", to: "n4", halfDashed: true)
            let score = try f.EasyScore().compose(spec(5, ContinuousOptions(spans: [span])))
            let layout = try #require(score.sheet.getContinuousLayout())
            for width in [600.0, 120, 600] {
                try score.sheet.setWidth(width).format()
                #expect((layout.fragments.count == 1) == (width == 600))
                ctx.reset()
                try layout.draw(ctx)
                // Pair each cubic with its start point and with the dash of the stroke that paints it.
                var paths: [(start: (Double, Double), left: (Double, Double), right: (Double, Double),
                             end: (Double, Double), dash: [Double])] = []
                var start = (0.0, 0.0)
                var pending: [(start: (Double, Double), left: (Double, Double), right: (Double, Double), end: (Double, Double))] = []
                for call in ctx.calls {
                    switch call {
                    case .moveTo(let x, let y): start = (x, y)
                    case .bezierCurveTo(let a, let b, let c, let d, let x, let y):
                        pending.append((start, (a, b), (c, d), (x, y)))
                    case .stroke(let dash):
                        paths += pending.map { ($0.start, $0.left, $0.right, $0.end, dash) }
                        pending = []
                    default: break
                    }
                }
                #expect(pending.isEmpty)
                for frag in layout.fragments {
                    let (a, b) = frag.progress
                    if a < 0.5 && b > 0.5 {
                        let opening = paths.removeFirst(), ending = paths.removeFirst()
                        #expect(opening.dash == [4, 3])
                        #expect(ending.dash == [])
                        #expect(opening.end == ending.start)
                        let (x, y) = ending.start
                        let expectedX = frag.x1 + ((frag.x2 - frag.x1) * (0.5 - a)) / (b - a)
                        #expect(abs(x - expectedX) < 1e-7)
                        let slopeIn = (y - opening.right.1) / (x - opening.right.0)
                        let slopeOut = (ending.left.1 - y) / (ending.left.0 - x)
                        #expect(abs(slopeIn - slopeOut) < 1e-7, "the tangent is continuous at the join")
                    } else {
                        #expect(paths.removeFirst().dash == (b <= 0.5 ? [4, 3] : []))
                    }
                }
                #expect(paths.isEmpty)
                #expect(ctx.lineDash == [], "the slur restores the drawing style")
            }
        }
    }

    @Test func aDashedLowerHeadTieKeepsItsStrokeThroughAWrap() throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let event = { (id: String, keys: [String]) in note(keys, "q", id: id, stem: .up) }
            let score = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "staff", time: .meter(2, 4), measures: [
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [event("lead", ["g/4"]), event("from", ["e/4", "b/4"])])]),
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [event("to", ["e/4", "b/4"]), event("end", ["g/4"])])]),
                ])],
                sheet: SheetOptions(width: 430),
                continuous: ContinuousOptions(spans: [ContinuousSpan(
                    id: "editorial", kind: .tie, from: "from", to: "to", fromHead: 0, toHead: 0, side: .below, dashed: true
                )])
            ))
            let layout = try #require(score.sheet.getContinuousLayout())
            func frame(_ width: Double, _ parts: [SpanFragmentPart]) throws -> [RecordingContext.Call] {
                try score.sheet.setWidth(width)
                try f.draw(retain: true)
                let segments = layout.fragments
                #expect(segments.map(\.part) == parts)
                #expect(segments.allSatisfy { $0.dashed == true })
                #expect(segments[0].y1 == (try score.getNote("from")).getYs()[0] + segments[0].space / 2)
                let last = try #require(segments.last)
                #expect(last.y2 == (try score.getNote("to")).getYs()[0] + last.space / 2)
                ctx.reset()
                try layout.draw(ctx)
                #expect(!ctx.calls.contains(.fill), "a dashed arc must have open gaps")
                let strokes = ctx.calls.compactMap { call -> [Double]? in
                    if case .stroke(let dash) = call { return dash }
                    return nil
                }
                #expect(strokes == parts.map { _ in [4, 3] })
                return ctx.calls
            }
            let wide = try frame(430, [.single])
            _ = try frame(125, [.first, .last])
            #expect(try frame(430, [.single]) == wide)
        }
    }

    @Test func wavyGlissandiFitWholeWavesNormalToThePitchLine() throws {
        try isolated {
            for descending in [false, true] {
                var source = glissandoStudy(descending)
                source.continuous?.spans[0].wavy = true
                let (f, ctx) = makeFactory()
                let score = try f.EasyScore().compose(source)
                let layout = try #require(score.sheet.getContinuousLayout())
                func render(_ width: Double, _ parts: [SpanFragmentPart]) throws -> [[[Double]]] {
                    try score.sheet.setWidth(width)
                    try f.draw(retain: true)
                    #expect(layout.fragments.map(\.part) == parts)
                    #expect(layout.diagnostics == [])
                    ctx.reset()
                    try layout.draw(ctx)
                    var paths: [[[Double]]] = []
                    for call in ctx.calls {
                        if case .moveTo(let x, let y) = call { paths.append([[x, y]]) }
                        if case .quadraticCurveTo(let a, let b, let c, let d) = call { paths[paths.count - 1].append([a, b, c, d]) }
                    }
                    #expect(paths.count == parts.count)
                    for (i, segment) in layout.fragments.enumerated() where i < paths.count {
                        let (x1, x2, y1, y2, space) = (segment.x1, segment.x2, segment.y1, segment.y2, segment.space)
                        let start = paths[i][0], halves = Array(paths[i].dropFirst())
                        #expect(segment.wavy == true)
                        #expect(start == [x1, y1])
                        // Upstream compares the last point exactly. Here the sum `x1 + dx * 1` can differ by one ulp.
                        let tip = try #require(halves.last)
                        #expect(abs(tip[2] - x2) < 1e-9 && abs(tip[3] - y2) < 1e-9)
                        #expect(halves.count >= 2 && halves.count % 2 == 0)
                        let length = hypot(x2 - x1, y2 - y1)
                        let tx = (x2 - x1) / length, ty = (y2 - y1) / length
                        #expect((ty > 0 ? 1 : -1) == (descending ? 1 : -1))
                        var previous = start
                        for (index, h) in halves.enumerated() {
                            // At the middle of a quadratic the crest is halfway to the control point from the chord.
                            let ox = (h[0] - (previous[0] + h[2]) / 2) / 2
                            let oy = (h[1] - (previous[1] + h[3]) / 2) / 2
                            #expect(abs(ox * tx + oy * ty) < 1e-8)
                            #expect(hypot(ox, oy) > space * 0.1 && hypot(ox, oy) <= space * 0.19)
                            #expect((tx * oy - ty * ox > 0 ? 1 : -1) == (index % 2 == 0 ? -1 : 1))
                            previous = [h[2], h[3]]
                        }
                    }
                    let first = try #require(layout.fragments.first), last = try #require(layout.fragments.last)
                    let from = try #require(try score.getNote("from") as? StaveNote)
                    let to = try #require(try score.getNote("to") as? StaveNote)
                    let head = from.getHeadInk()[1]
                    #expect(first.x1 > head.x + head.w && last.x2 < to.getHeadInk()[0].x)
                    #expect(first.y1 == from.getYs()[1])
                    #expect(last.y2 == to.getYs()[0])
                    return paths
                }
                let wide = try render(520, [.single])
                let compact = try render(320, [.single])
                #expect(wide[0].count > compact[0].count)
                _ = try render(150, [.first, .last])
                #expect(try render(520, [.single]) == wide)
            }
        }
    }

    @Test func spanStyleFlagsNeedTheirSpanKind() throws {
        try isolated {
            let cases: [(ContinuousSpan, String)] = [
                (ContinuousSpan(id: "a", kind: .slur, from: "n0", to: "n1", wavy: true), "A wavy slide needs a glissando span."),
                (ContinuousSpan(id: "a", kind: .slur, from: "n0", to: "n1", flared: true),
                 "A flared profile needs a crescendo or diminuendo span."),
                (ContinuousSpan(id: "a", kind: .tie, from: "n0", to: "n1", halfDashed: true), "A half-dashed curve needs a slur span."),
                (ContinuousSpan(id: "a", kind: .slur, from: "n0", to: "n1", dashed: true), "A dashed tie needs a tie span."),
            ]
            for (span, message) in cases {
                let (f, _) = makeFactory()
                #expect(errorMessage { _ = try f.EasyScore().compose(spec(2, ContinuousOptions(spans: [span]))) } == message)
            }
        }
    }

    // MARK: - TAB tie fitting

    @Test func tabTiesMeasureOtherVoicesFretInkAndKeepOneSideAcrossABreak() throws {
        try isolated {
            func draw(_ side: ContinuousSpanSide?, split: Bool = false, crowded: Bool = false) throws
                -> (c: EasyScoreComposition, frame: (Double) throws -> (parts: [SpanFragment], errors: [ContinuousDiagnostic])) {
                let (f, _) = makeFactory()
                let c = try f.EasyScore().compose(tieStudy(side, split: split, crowded: crowded))
                let layout = try #require(c.sheet.getContinuousLayout())
                return (c, { width in
                    try c.sheet.setWidth(width)
                    try f.draw(retain: true)
                    return (layout.fragments, layout.diagnostics)
                })
            }
            for side in [nil, ContinuousSpanSide.above, .below] {
                let (c, frame) = try draw(side)
                let (parts, errors) = try frame(480)
                #expect(errors == [])
                let f = try #require(parts.first)
                #expect(f.above == (side == .above))
                #expect(f.strings == [5])
                let sign: Double = f.above ? -1 : 1
                let fretNote = try #require(try c.getNote("upper02") as? TabNote)
                let obstacle = try #require(fretNote.getFretInk().first)
                // Sample the visible quadratic ribbon through the fret box, independently of the fitter's bounds.
                var x = obstacle.x
                while x <= obstacle.x + obstacle.w {
                    let t = (x - f.x1) / (f.x2 - f.x1), base = (1 - t) * f.y1 + t * f.y2
                    for edge in [0, f.space * 0.22] {
                        let y = base + sign * 2 * t * (1 - t) * ((f.rise ?? 0) + edge)
                        #expect(y < obstacle.y || y > obstacle.y + obstacle.h)
                    }
                    x += 0.2
                }
            }
            let split = try draw(nil, split: true)
            let wide = try split.frame(480)
            let narrow = try split.frame(245)
            #expect(narrow.errors == [])
            #expect(narrow.parts.map(\.part) == [.first, .last])
            #expect(narrow.parts.map(\.above) == [false, false])
            #expect(narrow.parts.map(\.strings) == [[5], [5]])
            let again = try split.frame(480)
            #expect(again.parts == wide.parts && again.errors == wide.errors)
            let crowded = try draw(.above, crowded: true).frame(480)
            #expect(crowded.parts.first?.above == true)
            #expect(crowded.errors.contains { $0.code == .curveCollision && $0.source == "hold" })
        }
    }

    @Test func fitTabTieKeepsTheDefaultSideWithoutObstacles() {
        var fragments = [SpanFragment(
            id: "t", kind: .tie, row: 0, part: .single, x1: 0, x2: 60, y1: 10, y2: 10, progress: (0, 1),
            strings: [5], above: true, space: 10
        )]
        let missed = fitTabTie(&fragments, [[]], true)
        #expect(missed.isEmpty)
        #expect(fragments[0].above)
        #expect(fragments[0].y1 == 10)
        // An obstacle above the string moves an automatic tie below it, 0.6 spaces lower.
        let ink = [BoundingBox(x: 20, y: 0, w: 20, h: 9)]
        let missedBelow = fitTabTie(&fragments, [ink], true)
        #expect(missedBelow.isEmpty)
        #expect(!fragments[0].above)
        #expect(fragments[0].y1 == 16)
    }

    // MARK: - Cross-measure tuplets

    @Test func oneRhythmicSextupletTimesBothMeasuresAndReflowsItsOwnBracket() throws {
        try isolated {
            let source = sextupletStudy()
            let (f, ctx) = makeFactory()
            let score = try f.EasyScore().compose(source)
            let layout = try #require(score.sheet.getContinuousLayout())
            let notes = try (source.continuous?.tuplets[0].members ?? []).map { try score.getNote($0) }
            let group = try #require(notes[0].getTuplet())
            let next = try score.getNote("next")
            func draw(_ width: Double, _ parts: [SpanFragmentPart]) throws -> [SpanFragment] {
                ctx.reset()
                try score.sheet.setWidth(width)
                try f.draw(retain: true)
                #expect(ctx.texts.filter { $0.text == "6" }.count == 1)
                #expect(layout.fragments.map(\.id) == parts.map { _ in "six" })
                #expect(layout.fragments.map(\.part) == parts)
                #expect(layout.diagnostics == [])
                #expect(group.notes.map { ObjectIdentifier($0) } == notes.map { ObjectIdentifier($0) })
                #expect(notes.allSatisfy { $0.getTuplet() === group && $0.getDuration() == "8" })
                #expect(notes.allSatisfy { $0.getTicks().equals(Fraction(Int(quarter), 3)) })
                let total = notes.reduce(Fraction(0, 1)) { $0.add($1.getTicks()) }
                #expect(total.equals(Int(quarter) * 2))
                for (m, measures) in score.notes.enumerated() {
                    let at = Fraction(0, 1)
                    for n in measures[0][0] {
                        if let i = notes.firstIndex(where: { $0 === n }) {
                            #expect(at.equals(Fraction((m == 0 ? 9 + i : i - 3) * Int(quarter), 3)))
                        }
                        if n === next { #expect(at.equals(Int(quarter))) }
                        at.add(n.getTicks())
                    }
                    #expect(at.equals(4 * Int(quarter)))
                }
                #expect(layout.fragments.first?.x1 == notes[0].getAbsoluteX())
                #expect(layout.fragments.last?.x2 == notes[5].getAbsoluteX() + notes[5].getGlyphWidth())
                return layout.fragments
            }
            let wide = try draw(530, [.single])
            _ = try draw(290, [.first, .last])
            #expect(try draw(530, [.single]) == wide)
        }
    }

    @Test func rhythmicTupletMembershipRejectsGapsReversalsDuplicatesAndInvalidRatios() throws {
        try isolated {
            // Upstream also rejects `numNotes: 2.5`. The Swift `Int` field cannot hold it.
            let overrides: [(inout ContinuousTuplet) -> Void] = [
                { $0.members = ["t0", "t2"] },
                { $0.members = ["t3", "t2"] },
                { $0.members = ["t0", "t0"] },
                { $0.members = [] },
                { $0.notesOccupied = 0 },
                { $0.numNotes = -1 },
            ]
            for override in overrides {
                var source = sextupletStudy()
                override(&source.continuous!.tuplets[0])
                let message = errorMessage { _ = try makeFactory().f.EasyScore().compose(source) }
                #expect(message?.lowercased().contains("continuous tuplet") == true, "\(message ?? "no error")")
            }
        }
    }

    // MARK: - Independent meters

    private func meterStaves() -> [EasyScoreStaveSpec] {
        [3, 4].enumerated().map { s, beats in
            EasyScoreStaveSpec(
                id: "part\(s)", time: .meter(beats, 4),
                measures: (0..<(12 / beats)).map { m in
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: (0..<beats).map { i in
                        note([["g/4", "a/4", "b/4"][i % 3]], "q", id: "\(s)-\(beats * m + i)")
                    })])
                }
            )
        }
    }

    @Test func independentMetersKeepEachStaffsPulseLocalBarsAndSourcePositionsThroughAWrap() throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let staves = meterStaves()
            let score = try f.EasyScore().compose(
                EasyScoreCompositionSpec(staves: staves, continuous: ContinuousOptions(independentMeters: true))
            )
            let notes = try (0..<2).map { s in try (0..<12).map { try score.getNote("\(s)-\($0)") } }
            func render(_ width: Double) throws -> String {
                try score.sheet.setWidth(width)
                ctx.clear()
                try f.draw(retain: true)
                var bars: [[Int]] = [[], []]
                var pulses = 0
                for (i, parts) in score.notes.enumerated() {
                    pulses += parts[0][0].count
                    for s in 0..<2 {
                        let bar = score.staves[i][s].getModifiers(position: .end, category: Barline.category).first as? Barline
                        if bar?.getType() != BarlineType.none { bars[s].append(pulses) }
                    }
                }
                #expect(bars == [[3, 6, 9, 12], [4, 8, 12]])
                for (i, top) in notes[0].enumerated() {
                    #expect(top.getAbsoluteX() == notes[1][i].getAbsoluteX())
                    for (s, group) in notes.enumerated() {
                        let n = group[i], beats = 3 + s
                        let pos = try #require(score.getMeterPosition(n))
                        #expect(n.getTicks().value() == quarter)
                        #expect(pos.staff == "part\(s)")
                        #expect(pos.measure == 1 + i / beats)
                        #expect(pos.event == i % beats)
                        #expect(pos.onset.value() == Double(i % beats) * quarter)
                    }
                }
                return ctx.inner.getSVG()
            }
            let wide = try render(900)
            #expect(score.sheet.getRows().count == 1)
            #expect(try render(330) != wide)
            #expect(score.sheet.getRows().count == 2)
            #expect(notes[0][5].checkStave().getY() != notes[0][6].checkStave().getY())
            #expect(try render(900) == wide)
            #expect(errorMessage {
                _ = try makeFactory().f.EasyScore().compose(EasyScoreCompositionSpec(staves: staves, continuous: ContinuousOptions()))
            } == "All staves need the same number of measures.")
            var short = staves
            short[1].measures.removeFirst()
            #expect(errorMessage {
                _ = try makeFactory().f.EasyScore().compose(
                    EasyScoreCompositionSpec(staves: short, continuous: ContinuousOptions(independentMeters: true))
                )
            } == "Independent staves must cover the same total duration.")
        }
    }

    @Test func aHeldNoteSurvivesALocalBarlineOnAnotherStaff() throws {
        try isolated {
            let (f, ctx) = makeFactory()
            let score = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [
                    EasyScoreStaveSpec(id: "upper", time: .meter(2, 4), measures: [
                        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("C5/h")]),
                        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("D5/h")]),
                    ]),
                    EasyScoreStaveSpec(id: "lower", time: .meter(4, 4), measures: [
                        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [note(["g/4"], "w", id: "held")])]),
                    ]),
                ],
                continuous: ContinuousOptions(independentMeters: true)
            ))
            try f.draw(retain: true)
            #expect(score.systems.count == 1)
            #expect((try score.getNote("held")).getTicks().value() == Double(Tables.RESOLUTION))
            #expect(score.getMeterPosition(score.notes[0][0][0][1])?.measure == 2)
            // The local barline of the upper staff is drawn before its next attack.
            let d5 = try #require(score.notes[0][0][0][1] as? Note)
            #expect(ctx.inner.getSVG().contains("stavebarline"))
            #expect(d5.getAbsoluteX() > d5.checkStave().getNoteStartX())
        }
    }

    @Test func crossBarTupletTimingPrecedesAlignmentToAnIndependentlyMeteredStaff() throws {
        try isolated {
            var source = sextupletStudy()
            source.continuous?.independentMeters = true
            source.staves.append(EasyScoreStaveSpec(
                id: "pulse", time: .meter(2, 4),
                measures: (0..<4).map { _ in EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("G4/q, G4/q")]) }
            ))
            let (f, _) = makeFactory()
            let score = try f.EasyScore().compose(source)
            let written = try (source.continuous?.tuplets[0].members ?? []).map { try score.getNote($0) }
            for width in [530.0, 290, 530] {
                try score.sheet.setWidth(width)
                try f.draw(retain: true)
                #expect(written.map { $0.getTupletStack().count } == Array(repeating: 1, count: 6))
                #expect(written.map { score.getMeterPosition($0)?.measure } == [1, 1, 1, 2, 2, 2])
                #expect(written.allSatisfy { $0.getTicks().equals(Fraction(Tables.RESOLUTION / 4, 3)) })
                #expect(score.getMeterPosition(try score.getNote("next"))?.onset.equals(Tables.RESOLUTION / 4) == true)
            }
        }
    }

    @Test func alignedScoresHaveNoMeterPositions() throws {
        try isolated {
            let score = try makeFactory().f.EasyScore().compose(spec(2))
            #expect(score.meterPositions == nil)
        }
    }

    // MARK: - Stanza labels

    @Test func aStanzaColumnFitsInsideAnUnsignedStaffAtFixedAndIntrinsicWidths() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 720, height: 420)
            let es = f.EasyScore()
            let notes = es.notes("G4/q, A4/q, B4/q, A4/q, G4/q", options: ["stem": "down"])
            let system = f.System(options: SystemOptions(spaceBetweenStaves: 4, width: 510, y: 30))
            let staff = system.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
            let layout = system.getPhraseLayout()
            let first = try #require(notes[0] as? StaveNote)
            let label = "112."
            let words = try layout.addVerse(staff, [PhraseSyllable(note: first, text: "Light")], options: PhraseVerseOptions(stanza: label))
            // Rejecting an empty label must leave the existing syllable and lane intact.
            #expect(throws: PhraseLayoutError.invalidStanza) {
                try layout.addVerse(staff, [PhraseSyllable(note: first, text: "word")], options: PhraseVerseOptions(stanza: " "))
            }
            let font = words[0].fontInfo
            let metrics = Annotation(label).setFont(FontInfo(family: font.family, size: font.size, weight: "bold", style: font.style))
            for width in [nil, 420.0, nil] {
                if let width { system.setWidth(width) } else { system.setWidth() }
                ctx.reset()
                try f.draw(retain: true)
                let painted = ctx.texts.filter { $0.text == label }
                #expect(painted.count == 1)
                let origin = try #require(painted.first)
                let ink = metrics.getTextInk(origin.x, origin.y)
                let word = try #require(try measureEngraving(words[0]).ink)
                #expect(ink.x >= staff.getX() && ink.x + ink.w + 3 < word.x)
                #expect(layout.diagnostics == [])
            }
        }
    }

    @Test func stanzaNumbersShareALeftMarginAndStayOnTheirWordBaselinesThroughABreak() throws {
        try isolated {
            for stanza in ["1.", "10."] {
                let (f, ctx) = makeFactory(width: 680, height: 480)
                let music = try f.EasyScore().compose(stanzaStudy(stanza))
                let first = try #require(try music.getNote("g0") as? StaveNote)
                let font = try #require(first.getModifiers().first as? Annotation).fontInfo
                func ink(_ text: String, _ x: Double) -> (left: Double, right: Double) {
                    let weight = text.hasSuffix(".") ? "bold" : font.weight
                    let m = Annotation(text).setFont(FontInfo(family: font.family, size: font.size, weight: weight, style: font.style))
                        .textMetrics
                    return (x - m.actualBoundingBoxLeft, x + m.actualBoundingBoxRight)
                }
                struct Frame: Equatable {
                    var painted: [String]
                    var bars: [Int]
                    var wordCenters: [Double]
                    var anchor: Double
                }
                var frames: [Frame] = []
                for width in [620.0, 350, 620] {
                    try music.sheet.setWidth(width)
                    ctx.reset()
                    try f.draw(retain: true)
                    let painted = ctx.texts.filter { [stanza, "12.", "Bright", "The"].contains($0.text) }
                    #expect(painted.count == 4)
                    let find = { (text: String) in painted.first { $0.text == text } }
                    let upper = try #require(find(stanza)), lower = try #require(find("12."))
                    let bright = try #require(find("Bright")), the = try #require(find("The"))
                    let (ul, ur) = ink(stanza, upper.x), (ll, lr) = ink("12.", lower.x)
                    let (bl, _) = ink("Bright", bright.x), (tl, _) = ink("The", the.x)
                    #expect(abs(ul - ll) < 0.01 && ul >= first.checkStave().getX())
                    #expect(max(ur, lr) + 3 < min(bl, tl))
                    #expect(upper.y == bright.y)
                    #expect(lower.y == the.y)
                    #expect(upper.y < lower.y)
                    #expect(music.systems.flatMap { $0.getPhraseLayout().diagnostics } == [])
                    let anchor = try first.getModifierStartXYThrowing(position: .above, index: 0).x
                    let centers = try first.getModifiers().compactMap { $0 as? Annotation }
                        .map { try $0.computeX().x + $0.getWidth() / 2 }
                    // Upstream compares exactly. With CoreText widths, `x + w / 2` can differ from the anchor by one ulp.
                    #expect(centers.count == 2 && centers.allSatisfy { abs($0 - anchor) < 1e-9 })
                    frames.append(Frame(
                        painted: painted.map { "\($0.text)@\($0.x),\($0.y)" },
                        bars: music.sheet.getRows().map { $0.systems.count },
                        wordCenters: centers, anchor: anchor
                    ))
                }
                #expect(frames[0] == frames[2])
                #expect(frames.map(\.bars) == [[2], [1, 1], [2]])
            }
        }
    }

    @Test func aBlankStanzaInACompositionIsRejected() throws {
        try isolated {
            var source = stanzaStudy()
            source.staves[0].measures[0].verses[0].stanza = "  "
            #expect(throws: PhraseLayoutError.invalidStanza) { _ = try makeFactory().f.EasyScore().compose(source) }
        }
    }
}
