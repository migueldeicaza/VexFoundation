// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/publication.ts` (VexFlow 5.4.0).
// Print-ready SVG pages over independent EasyScore views. Public dimensions are millimeters.
//
// Swift: upstream draws into a hidden DOM host and reads `getBBox()`, canvas `measureText()` and computed
// styles. Here each page is an `SVGNode` tree built with `SVGRenderContext`; ink and font boxes come from
// `TextMeasurer` (CoreText) and the path data (`SVGInk.swift`). The page-breaking and pagination
// algorithms are unchanged. There is no DOM target: `render(_:)` returns the pages.
//
// PDF: upstream prints `toPrintHTML()` in a browser. A native PDF writer fits next to `toPrintHTML()`:
// a `CGContext(consumer:mediaBox:)` PDF context with one page per `PublicationPage` (media box
// `paper` × 72 / 25.4 points), drawing each page's SVG tree with a CoreGraphics `RenderContext`
// (scale 72 / 25.4 from millimeters). It is not part of this port.

import Foundation

/// Paper size. Dimensions are in millimeters. (VexFlow 5.4.0)
public enum PublicationPaper: Sendable, Equatable {
    case a4
    case letter
    case custom(width: Double, height: Double)
}

/// Page margins in millimeters. Missing values use the defaults (15 top and bottom, 16 left and right).
public struct PublicationMargins: Sendable, Equatable {
    public var top: Double?
    public var right: Double?
    public var bottom: Double?
    public var left: Double?

    public init(top: Double? = nil, right: Double? = nil, bottom: Double? = nil, left: Double? = nil) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }
}

/// Paper, staff height (four spaces), margins, and inter-system gaps are measured in millimeters.
/// The view fields (`staves`, breaks, turns, regions) are those of `PublicationView`. (VexFlow 5.4.0)
public struct PublicationOptions: Sendable, Equatable {
    public var staves: [String]?
    public var systemBreaks: [Int]
    public var pageBreaks: [Int]
    public var preferredTurns: [Int]
    public var forbiddenTurns: [Int]
    public var regions: [PublicationRegion]
    public var paper: PublicationPaper
    public var staffSize: Double?
    public var margins: PublicationMargins
    public var title: String?
    public var subtitle: String?
    public var header: String?
    public var footer: String?
    public var pageNumbers: Bool
    public var systemGap: Double?
    public var maxExtraGap: Double?
    public var justifyLast: Bool

    public init(
        staves: [String]? = nil, systemBreaks: [Int] = [], pageBreaks: [Int] = [], preferredTurns: [Int] = [],
        forbiddenTurns: [Int] = [], regions: [PublicationRegion] = [], paper: PublicationPaper = .a4,
        staffSize: Double? = nil, margins: PublicationMargins = PublicationMargins(), title: String? = nil,
        subtitle: String? = nil, header: String? = nil, footer: String? = nil, pageNumbers: Bool = true,
        systemGap: Double? = nil, maxExtraGap: Double? = nil, justifyLast: Bool = false
    ) {
        self.staves = staves
        self.systemBreaks = systemBreaks
        self.pageBreaks = pageBreaks
        self.preferredTurns = preferredTurns
        self.forbiddenTurns = forbiddenTurns
        self.regions = regions
        self.paper = paper
        self.staffSize = staffSize
        self.margins = margins
        self.title = title
        self.subtitle = subtitle
        self.header = header
        self.footer = footer
        self.pageNumbers = pageNumbers
        self.systemGap = systemGap
        self.maxExtraGap = maxExtraGap
        self.justifyLast = justifyLast
    }

    /// The view fields.
    public var view: PublicationView {
        PublicationView(
            staves: staves, systemBreaks: systemBreaks, pageBreaks: pageBreaks, preferredTurns: preferredTurns,
            forbiddenTurns: forbiddenTurns, regions: regions
        )
    }
}

/// A publication problem. Measures are one-based. (VexFlow 5.4.0)
public struct PublicationDiagnostic: Sendable, Equatable {
    public enum Code: String, Sendable {
        case pageOverflow = "PageOverflow"
        case systemOverflow = "SystemOverflow"
        case textOverflow = "TextOverflow"
        case forbiddenTurn = "ForbiddenTurn"
        case excludedAnchor = "ExcludedAnchor"
        case engraving = "Engraving"
    }

    public var code: Code
    public var measures: [Int]
    public var detail: String
    public var page: Int?
}

/// A placed system on a page, in millimeters. (VexFlow 5.4.0)
public struct PublicationSystem: Sendable, Equatable {
    public var measures: [Int]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
}

/// One physical page. (VexFlow 5.4.0)
public struct PublicationPage {
    /// The page drawing. Serialize it with `PublicationResult.toSVG(_:portable:)`.
    public let svg: SVGNode
    public let number: Int
    public let systems: [PublicationSystem]

    /// The JSON text of the page `<metadata>` element.
    public var metadata: String? {
        svg.children.first { $0.name == "metadata" }?.textContent
    }
}

// MARK: - JSON metadata

/// A JSON value that keeps key order, as `JSON.stringify` does.
private indirect enum JSON {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSON])
    case object([(String, JSON)])

    func write(into out: inout String) {
        switch self {
        case .string(let s):
            out += "\""
            for scalar in s.unicodeScalars {
                switch scalar {
                case "\"": out += "\\\""
                case "\\": out += "\\\\"
                case "\n": out += "\\n"
                case "\r": out += "\\r"
                case "\t": out += "\\t"
                default:
                    if scalar.value < 0x20 {
                        out += String(format: "\\u%04x", scalar.value)
                    } else {
                        out.unicodeScalars.append(scalar)
                    }
                }
            }
            out += "\""
        case .number(let n):
            out += n.isFinite ? formatJSNumber(n) : "null"
        case .bool(let b):
            out += b ? "true" : "false"
        case .array(let items):
            out += "["
            for (i, item) in items.enumerated() {
                if i > 0 { out += "," }
                item.write(into: &out)
            }
            out += "]"
        case .object(let pairs):
            out += "{"
            for (i, (k, v)) in pairs.enumerated() {
                if i > 0 { out += "," }
                JSON.string(k).write(into: &out)
                out += ":"
                v.write(into: &out)
            }
            out += "}"
        }
    }

    var text: String {
        var out = ""
        write(into: &out)
        return out
    }
}

/// Staff, source measure, voice and timed event position survive independent part projection.
private struct SemanticEvent {
    var id: String
    var measure: Int
    var staff: String
    var voice: Int
    var event: Int
    var keys: [String]
    var notation: [NotationIdentity]
    var ticks: String
    var rest: Bool

    var json: JSON {
        var pairs: [(String, JSON)] = [
            ("id", .string(id)),
            ("measure", .number(Double(measure))),
            ("staff", .string(staff)),
            ("voice", .number(Double(voice))),
            ("event", .number(Double(event))),
            ("keys", .array(keys.map { .string($0) })),
        ]
        if !notation.isEmpty {
            pairs.append(("notation", .array(notation.map { n in
                var entry: [(String, JSON)] = [("kind", .string(n.kind.rawValue)), ("id", .string(n.id)), ("label", .string(n.label))]
                if let index = n.index { entry.append(("index", .number(Double(index)))) }
                return .object(entry)
            })))
        }
        pairs.append(("ticks", .string(ticks)))
        pairs.append(("rest", .bool(rest)))
        return .object(pairs)
    }
}

private func semanticEvents(_ score: EasyScoreComposition, _ spec: EasyScoreCompositionSpec, _ measure: Int) -> [SemanticEvent] {
    score.notes[measure - 1].enumerated().flatMap { j, voices in
        voices.enumerated().flatMap { voice, ticks in
            ticks.filter { !$0.shouldIgnoreTicks() }.enumerated().compactMap { event, n -> SemanticEvent? in
                guard let n = n as? Note else { return nil }
                return SemanticEvent(
                    id: n.getAttribute("id") ?? "",
                    measure: measure,
                    staff: spec.staves[j].id,
                    voice: voice,
                    event: event,
                    keys: n.getKeys(),
                    notation: n.notation,
                    ticks: n.getTicks().toString(),
                    rest: n.isRest()
                )
            }
        }
    }
}

// MARK: - Page geometry

private struct Size {
    var width: Double
    var height: Double
    var margin: (top: Double, bottom: Double, left: Double, right: Double)
    var musicWidth: Double
    var scale: Double
    var gap: Double
    var extra: Double
}

/// Page area is physical. Scale only the score, so titles and margins retain their print size.
private func dimensions(_ o: PublicationOptions) throws -> Size {
    let paper: (width: Double, height: Double)
    switch o.paper {
    case .a4: paper = (210, 297)
    case .letter: paper = (215.9, 279.4)
    case .custom(let width, let height): paper = (width, height)
    }
    let margin = (
        top: o.margins.top ?? 15, bottom: o.margins.bottom ?? 15,
        left: o.margins.left ?? 16, right: o.margins.right ?? 16
    )
    let staff = o.staffSize ?? 7, gap = o.systemGap ?? 6, extra = o.maxExtraGap ?? 12
    if [margin.top, margin.bottom, margin.left, margin.right, gap, extra].contains(where: { !$0.isFinite || $0 < 0 })
        || [staff, paper.width, paper.height].contains(where: { !$0.isFinite || $0 <= 0 }) {
        throw invalidPage("Invalid print dimensions.")
    }
    let width = paper.width - margin.left - margin.right
    if width <= 0 || paper.height <= margin.top + margin.bottom { throw invalidPage("Margins consume the paper.") }
    return Size(
        width: paper.width, height: paper.height, margin: margin, musicWidth: width,
        scale: staff / (4 * Tables.STAVE_LINE_DISTANCE), gap: gap, extra: extra
    )
}

private struct Composed {
    var ctx: SVGRenderContext
    var factory: Factory
    var score: EasyScoreComposition
}

/// Compose a view on its own SVG context.
private func compose(_ spec: EasyScoreCompositionSpec) throws -> Composed {
    let ctx = SVGRenderContext(width: 1, height: 1)
    let factory = Factory(options: FactoryOptions(width: 1, height: 1))
    _ = factory.setContext(ctx)
    let score = try factory.EasyScore().compose(spec)
    return Composed(ctx: ctx, factory: factory, score: score)
}

private struct Reference {
    var kind: PublicationRegion.Kind
    var staff: String
    var measure: Int
    var label: String
    var events: [SemanticEvent]

    var json: JSON {
        .object([
            ("kind", .string(kind.rawValue)), ("staff", .string(staff)), ("measure", .number(Double(measure))),
            ("label", .string(label)), ("events", .array(events.map { $0.json })),
        ])
    }
}

private final class RowDrawing {
    var measures: [Int]
    var music: SVGNode
    var top: Double
    var bottom: Double
    var left: Double
    var right: Double
    var restAtEnd: Bool
    var insetHeight: Double = 0
    var insets = SVGNode.make("g")
    var references: [Reference] = []
    /// Millimeters, set after the insets.
    var height: Double = 0

    init(measures: [Int], music: SVGNode, top: Double, bottom: Double, left: Double, right: Double, restAtEnd: Bool) {
        self.measures = measures
        self.music = music
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.restAtEnd = restAtEnd
    }
}

/// Preserve inherited renderer styles while moving actual graphics to their owning system.
private func musicGroup(_ svg: SVGNode) -> SVGNode {
    let g = SVGNode.make("g")
    for (name, value) in svg.attributes
    where !["width", "height", "style", "viewBox", "xmlns", "id", "pointer-events"].contains(name) {
        g.setAttribute(name, value)
    }
    return g
}

/// SVG glyphs can extend beyond a formatter envelope. Include both before breaking pages.
private func splitRows(_ svg: SVGNode, _ rows: [ContinuousRow], _ score: EasyScoreComposition) throws -> [RowDrawing] {
    let result = rows.map { row in
        RowDrawing(
            measures: row.measures, music: musicGroup(svg), top: row.y, bottom: row.y + row.height,
            left: row.x, right: row.x + row.width, restAtEnd: restingMeasure(score, row.measures[row.measures.count - 1])
        )
    }
    let edges = rows.indices.dropFirst().map { i in (rows[i].y + rows[i - 1].y + rows[i - 1].height) / 2 }
    // Read ink while the whole drawing is mounted.
    let elements = try svg.children.map { (el: $0, box: try svgInkBox($0)) }
    for (el, box) in elements {
        guard let box else { continue }
        let top = box.y, bottom = box.y + box.h
        // Binary search matters on orchestral scores with thousands of glyph groups.
        var low = 0, high = edges.count
        while low < high {
            let mid = (low + high) / 2
            if (top + bottom) / 2 < edges[mid] { high = mid } else { low = mid + 1 }
        }
        let row = result[low]
        row.top = min(row.top, top)
        row.bottom = max(row.bottom, bottom)
        row.left = min(row.left, box.x)
        row.right = max(row.right, box.x + box.w)
        row.music.appendMoving(el)
    }
    return result
}

/// Page text is positioned from its actual font box, also when exported as outlines.
private func label(_ host: SVGNode, _ text: String, _ size: Double) -> (el: SVGNode, box: BoundingBox) {
    let family = Metrics.getFontInfo("Annotation").family
    let el = SVGNode.make("text", [
        ("font-family", family.isEmpty ? "Academico" : family),
        ("font-size", formatJSNumber(size) + "px"),
        ("fill", "black"),
        ("stroke", "none"),
        ("x", "0"),
        ("y", "0"),
    ])
    el.textContent = text
    host.append(el)
    return (el, svgTextBox(el))
}

private struct Furniture {
    var group: SVGNode
    var top: Double
    var height: Double
    var overflow: Bool
}

/// Measure and place title, running furniture and page numbers before allocating music space.
private func furniture(_ host: SVGNode, _ size: Size, _ o: PublicationOptions, _ number: Int) throws -> Furniture {
    let group = SVGNode.make("g", [("data-page-furniture", "")])
    host.append(group)
    let margin = size.margin, musicWidth = size.musicWidth
    var y = margin.top
    var overflow = false
    enum Align { case left, center, right }
    func place(_ text: String, _ font: Double, _ top: Double, _ align: Align) -> BoundingBox {
        let (el, box) = label(group, text, font)
        let x = margin.left + (align == .center ? (musicWidth - box.w) / 2 : align == .right ? musicWidth - box.w : 0)
        el.setAttribute("x", formatJSNumber(x - box.x))
        el.setAttribute("y", formatJSNumber(top - box.y))
        overflow = overflow || box.w > musicWidth
        return box
    }
    if number == 1, let title = o.title, !title.isEmpty { y += place(title, 7, y, .center).h + 2 }
    if number == 1, let subtitle = o.subtitle, !subtitle.isEmpty { y += place(subtitle, 4, y, .center).h + 2 }
    if number > 1, let header = o.header, !header.isEmpty { y += place(header, 3.5, y, .left).h + 2 }
    if y != margin.top { y += 3 }
    var end = size.height - margin.bottom
    let footer = o.footer.flatMap { $0.isEmpty ? nil : $0 }
    if footer != nil || o.pageNumbers {
        var items: [BoundingBox] = []
        if let footer { items.append(place(footer, 3.3, 0, .left)) }
        if o.pageNumbers { items.append(place(String(number), 3.3, 0, .right)) }
        let h = items.map { $0.h }.max() ?? 0
        if items.count > 1 && items[0].w + items[1].w + 2 > musicWidth { overflow = true }
        for el in group.children.suffix(items.count) {
            el.setAttribute("y", formatJSNumber((Double(el.getAttribute("y") ?? "0") ?? 0) + end - h))
        }
        end -= h + 4
    }
    if end <= y { throw invalidPage("Title, margins and running furniture leave no music area.") }
    return Furniture(group: group, top: y, height: end - y, overflow: overflow)
}

/// A cue or ossia gets its own native rendering at the anchor bar's width and written clef.
private func addInsets(
    _ spec: EasyScoreCompositionSpec, _ o: PublicationOptions, _ score: EasyScoreComposition, _ rows: [RowDrawing],
    _ diagnostics: inout [PublicationDiagnostic]
) throws {
    for r in o.regions {
        guard let row = rows.first(where: { $0.measures.contains(r.measure) }),
              let source = spec.staves.first(where: { $0.id == r.staff }) else { continue }
        let stave = score.staves[r.measure - 1][0]
        let scale = r.scale ?? 0.7
        let staff = insetStaff(source, r.measure)
        let insetSpec = EasyScoreCompositionSpec(
            staves: [staff],
            sheet: SheetOptions(width: stave.getWidth() / scale, x: 0, y: 0, measurePadding: 4),
            accidentals: spec.accidentals,
            graceAccidentals: spec.graceAccidentals,
            continuous: ContinuousOptions()
        )
        let inset = try compose(insetSpec)
        try inset.factory.draw()
        row.references.append(Reference(
            kind: r.kind, staff: r.staff, measure: r.measure, label: r.label,
            events: semanticEvents(inset.score, insetSpec, 1).map { var e = $0; e.measure = r.measure; return e }
        ))
        let svg = inset.ctx.svg
        let g = musicGroup(svg)
        for child in svg.children { g.appendMoving(child) }
        svg.append(g)
        guard let ink = try svgInkBox(g) else { continue }
        let caption = label(svg, r.label, 12)
        let wrap = SVGNode.make("g", [
            ("data-region", r.kind.rawValue), ("data-source-staff", r.staff), ("data-measure", String(r.measure)),
        ])
        wrap.setAttribute("transform", "translate(\(formatJSNumber(stave.getX())),\(formatJSNumber(row.insetHeight)))")
        caption.el.setAttribute("y", formatJSNumber(-caption.box.y))
        g.setAttribute(
            "transform",
            "translate(0,\(formatJSNumber(caption.box.h + 2 - ink.y * scale))) scale(\(formatJSNumber(scale)))"
        )
        let right = max(ink.w * scale, caption.box.w)
        if right > stave.getWidth() + 1 {
            diagnostics.append(PublicationDiagnostic(
                code: .systemOverflow, measures: [r.measure], detail: r.kind.rawValue + " exceeds its measure width."
            ))
        }
        wrap.appendMoving(caption.el)
        wrap.appendMoving(g)
        row.insets.append(wrap)
        row.insetHeight += caption.box.h + ink.h * scale + 8
    }
}

/// Keep page markup unique when a full score and a part containing the same notes share a document.
private let viewCounter = ViewCounter()

private final class ViewCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

private func scopeIds(_ root: SVGNode, _ prefix: String) {
    for (index, e) in root.descendants().filter({ $0.getAttribute("id") != nil }).enumerated() {
        e.setAttribute("data-vf-id", e.getAttribute("id") ?? "")
        e.setAttribute("id", prefix + "-" + String(index))
    }
}

/// The pages of one rendering. (VexFlow 5.4.0)
public final class PublicationResult {
    public let pages: [PublicationPage]
    public let diagnostics: [PublicationDiagnostic]
    /// Paper size in millimeters.
    public let paper: (width: Double, height: Double)

    init(pages: [PublicationPage], diagnostics: [PublicationDiagnostic], paper: (width: Double, height: Double)) {
        self.pages = pages
        self.diagnostics = diagnostics
        self.paper = paper
    }

    /// Serialize one page (numbered from one). With `portable: true`, text becomes outlines of the fonts
    /// that laid out the page (upstream passes `fonts`). Semantic metadata is retained.
    public func toSVG(_ pageNumber: Int, portable: Bool = false) throws -> String {
        guard pageNumber >= 1 && pageNumber <= pages.count else { throw invalidPage("Unknown publication page.") }
        return try SVGRenderContext.toSVG(pages[pageNumber - 1].svg, portable: portable)
    }

    /// A separate print document with portable pages. Upstream requires outline fonts; here the outlines
    /// come from the fonts that laid out the pages. Throws while overflow diagnostics remain.
    public func toPrintHTML() throws -> String {
        if diagnostics.contains(where: { [.pageOverflow, .textOverflow, .systemOverflow].contains($0.code) }) {
            throw invalidPage("Resolve publication overflow before printing.")
        }
        let css = "@page{size:\(formatJSNumber(paper.width))mm \(formatJSNumber(paper.height))mm;margin:0}"
            + "html,body{margin:0}svg{display:block;break-after:page}svg:last-child{break-after:auto}"
        return "<!doctype html><html><head><meta charset=\"utf-8\"><title>Score</title><style>" + css
            + "</style></head><body>" + (try pages.map { try toSVG($0.number, portable: true) }.joined())
            + "</body></html>"
    }
}

/// Measure running text at the same physical scale and with the same SVG styles used for the printed page.
private func pageSurface(_ size: Size) -> SVGNode {
    SVGNode.make("svg", [
        ("width", formatJSNumber(size.width) + "mm"),
        ("height", formatJSNumber(size.height) + "mm"),
        ("viewBox", "0 0 \(formatJSNumber(size.width)) \(formatJSNumber(size.height))"),
        ("role", "img"),
    ])
}

/// Mount measured systems at the page planner's offsets and preserve their text and source identity.
private func buildPages(
    _ size: Size, _ options: PublicationOptions, _ spec: EasyScoreCompositionSpec, _ score: EasyScoreComposition,
    _ measured: [RowDrawing], _ breaks: [PageBreak], _ diagnostics: inout [PublicationDiagnostic]
) throws -> [PublicationPage] {
    let uid = viewCounter.next()
    let fragments = score.sheet.getContinuousLayout()?.fragments ?? []
    var pages: [PublicationPage] = []
    for (index, b) in breaks.enumerated() {
        let number = index + 1
        let svg = pageSurface(size)
        svg.append(SVGNode.make("rect", [
            ("width", formatJSNumber(size.width)), ("height", formatJSNumber(size.height)), ("fill", "white"),
        ]))
        let title = SVGNode.make("title")
        title.textContent = (options.title ?? "Score") + " · " + String(number)
        svg.append(title)
        let f = try furniture(svg, size, options, number)
        var systems: [PublicationSystem] = []
        for (i, offset) in b.offsets.enumerated() {
            let r = measured[b.first + i]
            let x = size.margin.left + size.scale, y = f.top + offset
            let group = SVGNode.make("g", [
                ("transform", "translate(\(formatJSNumber(x)),\(formatJSNumber(y))) scale(\(formatJSNumber(size.scale)))"),
                ("data-system", String(r.measures[0])),
            ])
            r.music.setAttribute("transform", "translate(0,\(formatJSNumber(r.insetHeight - r.top)))")
            group.appendMoving(r.insets)
            group.appendMoving(r.music)
            svg.append(group)
            if r.left < -1.001 || x + r.right * size.scale > size.width - size.margin.right + 0.001 {
                diagnostics.append(PublicationDiagnostic(
                    code: .systemOverflow, measures: r.measures, detail: "Ink outside the music width.", page: number
                ))
            }
            systems.append(PublicationSystem(
                measures: r.measures, x: x, y: y, width: (r.right - r.left) * size.scale, height: r.height
            ))
        }
        let measures = systems.flatMap { $0.measures }
        if f.overflow {
            diagnostics.append(PublicationDiagnostic(
                code: .textOverflow, measures: measures, detail: "Page furniture exceeds the margin.", page: number
            ))
        }
        if b.overflow > 0.00001 {
            diagnostics.append(PublicationDiagnostic(
                code: .pageOverflow, measures: measures,
                detail: "System exceeds music area by \(String(format: "%.2f", b.overflow)) mm.", page: number
            ))
        }
        if b.forbiddenTurn {
            diagnostics.append(PublicationDiagnostic(
                code: .forbiddenTurn, measures: [measures[measures.count - 1]],
                detail: "No feasible pagination avoids this turn.", page: number
            ))
        }
        let metadata = SVGNode.make("metadata")
        let spans: [JSON] = fragments.filter { $0.row >= b.first && $0.row < b.end }.map { f in
            var pairs: [(String, JSON)] = [("id", .string(f.id)), ("kind", .string(f.kind.rawValue)), ("part", .string(f.part.rawValue))]
            if let strings = f.strings {
                pairs.append(("strings", .array(strings.map { .number(Double($0)) })))
                if let from = f.from { pairs.append(("from", .string(from))) }
                if let to = f.to { pairs.append(("to", .string(to))) }
            }
            return .object(pairs)
        }
        let text = svg.descendants().filter { $0.name == "text" }.map { JSON.string($0.textContent ?? "") }
        metadata.textContent = JSON.object([
            ("page", .number(Double(number))),
            ("measures", .array(measures.map { .number(Double($0)) })),
            ("staves", .array(spec.staves.map { .string($0.id) })),
            ("events", .array(measures.flatMap { semanticEvents(score, spec, $0) }.map { $0.json })),
            ("regions", .array(measured[b.first..<b.end].flatMap { $0.references }.map { $0.json })),
            ("spans", .array(spans)),
            ("text", .array(text)),
        ]).text
        svg.append(metadata)
        scopeIds(svg, "vf-pub-\(uid)-\(number)")
        pages.append(PublicationPage(svg: svg, number: number, systems: systems))
    }
    return pages
}

/// Print-ready pages of a declarative EasyScore composition. Render again with different options to build
/// an independent part. (VexFlow 5.4.0)
public final class Publication {
    private let source: EasyScoreCompositionSpec

    public init(_ source: EasyScoreCompositionSpec) {
        self.source = source
    }

    /// Lay out the score or part and return one SVG page per printed page. Throws for an invalid view
    /// or invalid dimensions; layout problems are diagnostics.
    public func render(_ options: PublicationOptions = PublicationOptions()) throws -> PublicationResult {
        try checkView(source, options.view)
        let size = try dimensions(options)
        // Temporary native objects have source IDs that may already exist in the application's registry.
        let registry = Registry.getDefaultRegistry()
        Registry.disableDefaultRegistry()
        defer { if let registry { Registry.enableDefaultRegistry(registry) } }
        var diagnostics: [PublicationDiagnostic] = []
        let needsReference = options.staves != nil
            && (!source.spans.isEmpty || !(source.continuous?.spans.isEmpty ?? true)
                || !(source.continuous?.splitChords.isEmpty ?? true))
        let ref = needsReference ? try compose(source).score : nil
        // A one-unit inset keeps edge strokes inside the requested margin.
        let width = size.musicWidth / size.scale - 2
        var omitted: [PublicationDiagnostic] = []
        let spec = try projectScore(source, options.view, width: width, reference: ref) { id, measures in
            omitted.append(PublicationDiagnostic(code: .excludedAnchor, measures: measures, detail: id))
        }
        diagnostics += omitted
        let composed = try compose(spec)
        try composed.factory.draw()
        guard let layout = composed.score.sheet.getContinuousLayout() else {
            throw invalidPage("Expected a continuous layout.")
        }
        for d in layout.diagnostics {
            diagnostics.append(PublicationDiagnostic(
                code: d.code == .rowOverflow ? .systemOverflow : .engraving,
                measures: d.measures,
                detail: d.source.map { d.code.rawValue + " " + $0 } ?? d.code.rawValue
            ))
        }
        let rows = try splitRows(composed.ctx.svg, layout.rows, composed.score)
        try addInsets(source, options, composed.score, rows, &diagnostics)
        for r in rows { r.height = (r.bottom - r.top + r.insetHeight) * size.scale }
        let surface = pageSurface(size)
        let first = try furniture(surface, size, options, 1)
        first.group.removeFromParent()
        let later = try furniture(surface, size, options, 2)
        let breaks = paginate(
            rows.map { PrintableSystem(measures: $0.measures, height: $0.height, restAtEnd: $0.restAtEnd) },
            PageConstraints(
                firstHeight: first.height,
                laterHeight: later.height,
                gap: size.gap,
                maxExtraGap: size.extra,
                justifyLast: options.justifyLast,
                part: options.staves != nil,
                forceBefore: Set(options.pageBreaks),
                preferAfter: Set(options.preferredTurns),
                forbidAfter: Set(options.forbiddenTurns)
            )
        )
        let pages = try buildPages(size, options, spec, composed.score, rows, breaks, &diagnostics)
        return PublicationResult(pages: pages, diagnostics: diagnostics, paper: (size.width, size.height))
    }
}
