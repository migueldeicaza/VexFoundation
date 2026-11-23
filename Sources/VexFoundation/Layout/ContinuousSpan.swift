// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/continuousspan.ts` (VexFlow 5.6.0).
// Logical event anchors and renderer-independent drawing of continuous-score span fragments.

import Foundation

/// The kinds of relationship that a continuous score splits at system breaks. (VexFlow 5.4.0)
public enum ContinuousSpanKind: String, Sendable, CaseIterable {
    case tie
    case slur
    case crescendo
    case diminuendo
    case pedal
    case lyric
    case hyphen
    case volta
    case ottava
    case trill
    case tuplet
    case palmMute
}

/// The side of the staff for a span. (VexFlow 5.4.0)
public enum ContinuousSpanSide: String, Sendable {
    case above
    case below
}

/// A relationship between two composition notes, named by their IDs. (VexFlow 5.4.0)
public struct ContinuousSpan: Sendable, Equatable {
    public var kind: ContinuousSpanKind
    /// One-based string of a tab tie. Defaults to the string of the selected chord position. (VexFlow 5.6.0)
    public var string: Int?
    /// Required for `palmMute`. String numbers are one-based.
    public var strings: [Int]?
    public var id: String
    public var from: String
    public var to: String
    /// Optional zero-based chord-head indices. On a tab tie these index the positions arrays.
    public var fromHead: Int?
    public var toHead: Int?
    public var side: ContinuousSpanSide?
    /// Syllable, ending number, tuplet ratio or octave label, according to kind.
    public var text: String?
    /// Optional type size for this label, in points. Measured before system breaks are chosen. (VexFlow 5.5.0)
    public var labelFontSize: Double?
    /// For a lyric extender, take the baseline and ink edge from this Annotation on the source note.
    /// (VexFlow 5.6.0)
    public var syllableId: String?

    public init(
        id: String, kind: ContinuousSpanKind, from: String, to: String, fromHead: Int? = nil, toHead: Int? = nil,
        side: ContinuousSpanSide? = nil, text: String? = nil, strings: [Int]? = nil, string: Int? = nil,
        labelFontSize: Double? = nil, syllableId: String? = nil
    ) {
        self.string = string
        self.labelFontSize = labelFontSize
        self.syllableId = syllableId
        self.id = id
        self.kind = kind
        self.from = from
        self.to = to
        self.fromHead = fromHead
        self.toHead = toHead
        self.side = side
        self.text = text
        self.strings = strings
    }
}

/// A span end: the source measure (from zero), the staff index and the note. (VexFlow 5.4.0)
public struct SpanAnchor {
    public var measure: Int
    public var staff: Int
    public var note: Note
}

/// A validated span with its anchors and its measured label. (VexFlow 5.4.0)
public struct ResolvedSpan {
    public var spec: ContinuousSpan
    public var first: SpanAnchor
    public var last: SpanAnchor
    public var label: VexElement?
    /// The source lyric annotation of an anchored extender. (VexFlow 5.6.0)
    public var syllable: Annotation?
}

/// The part of a span that a fragment draws. (VexFlow 5.4.0)
public enum SpanFragmentPart: String, Sendable {
    case single
    case first
    case middle
    case last
}

/// The part of a span on one row. (VexFlow 5.4.0)
public struct SpanFragment: Sendable, Equatable {
    public var id: String
    public var kind: ContinuousSpanKind
    public var row: Int
    public var part: SpanFragmentPart
    public var x1: Double
    public var x2: Double
    public var y1: Double
    public var y2: Double
    /// Fraction of the drawn span used to interpolate the aperture across a system break.
    public var progress: (Double, Double)
    /// String numbers covered by a tab tie or palm-mute fragment.
    public var strings: [Int]?
    /// Authored TAB endpoints appear on the fragments containing them.
    public var from: String?
    public var to: String?
    public var rise: Double?
    public var above: Bool
    public var space: Double

    public static func == (a: SpanFragment, b: SpanFragment) -> Bool {
        a.id == b.id && a.kind == b.kind && a.row == b.row && a.part == b.part && a.x1 == b.x1 && a.x2 == b.x2
            && a.y1 == b.y1 && a.y2 == b.y2 && a.progress == b.progress && a.strings == b.strings && a.from == b.from
            && a.to == b.to && a.rise == b.rise && a.above == b.above && a.space == b.space
    }
}

/// Unlike a glyph sized in a default font, labels contribute their actual current text width to reservations.
/// (VexFlow 5.4.0)
public func spanLabel(_ spec: ContinuousSpan) -> VexElement? {
    let defaults: [ContinuousSpanKind: String] = [.volta: "1.", .ottava: "8va", .trill: Glyphs.ornamentTrill, .tuplet: "3"]
    let text = spec.text
        ?? (spec.kind == .palmMute ? "P.M. " + (spec.strings ?? []).map(String.init).joined(separator: ",") : nil)
        ?? defaults[spec.kind]
    guard let text, !text.isEmpty else { return nil }
    var category = "Annotation"
    if spec.kind == .trill { category = "Ornament" }
    if spec.kind == .lyric || spec.kind == .hyphen { category = "Annotation.lyric" }
    let label = VexElement(category: category).setText(text)
    if let size = spec.labelFontSize { label.setFontSize(size) }
    return label
}

/// Slurs, voltas, ottavas, trills and tuplets go above unless the span names a side. (VexFlow 5.4.0)
public func spanAbove(_ span: ContinuousSpan) -> Bool {
    if let side = span.side { return side == .above }
    return [.slur, .volta, .ottava, .trill, .tuplet].contains(span.kind)
}

/// Retain the written pitch through a clef change at a continuation edge. (VexFlow 5.4.0)
public func continuationPitch(_ anchor: SpanAnchor, _ stave: Stave, _ index: Int = 0) -> Double {
    let source = anchor.note.checkStave()
    let key = anchor.note.getKeys()[index]
    let offset = (anchor.note.getYs()[index] - source.getYForLine(0)) / source.space(1)
    let from = (try? Tables.keyProperties(key, clef: source.getClef()).line) ?? 0
    let to = (try? Tables.keyProperties(key, clef: stave.getClef()).line) ?? 0
    return stave.getYForLine(0) + stave.space(offset + from - to)
}

/// Share control geometry between the clearance search and the renderer.
private func controls(_ f: SpanFragment) -> (dx: Double, a: Double, b: Double) {
    let lift = (f.above ? -1.0 : 1.0) * (f.rise ?? min(f.space * (f.kind == .tie ? 0.85 : 1.5), (f.x2 - f.x1) * 0.18))
    return (
        dx: (f.x2 - f.x1) / 3,
        a: f.y1 + lift * (f.part == .first || f.part == .single ? 1 : 0.35),
        b: f.y2 + lift * (f.part == .last || f.part == .single ? 1 : 0.35)
    )
}

/// Prefer the shallowest clear curve. Preserve the best finite candidate if the space is infeasible.
/// (VexFlow 5.4.0)
@discardableResult
public func fitSpan(_ f: inout SpanFragment, _ obstacles: [BoundingBox]) -> Bool {
    let thickness = (f.above ? -1.0 : 1.0) * f.space * 0.22
    let initial = min(f.space * (f.kind == .tie ? 0.85 : 1.5), (f.x2 - f.x1) * 0.18)
    var best = initial
    var cost = Int.max
    for step in 0...(f.kind == .tie ? 6 : 20) {
        f.rise = initial + Double(step) * f.space * 0.4
        let (dx, a, b) = controls(f)
        let left = RibbonPoint(x: f.x1, y: f.y1)
        let right = RibbonPoint(x: f.x2, y: f.y2)
        let cps = f.kind == .tie
            ? [RibbonPoint(x: (f.x1 + f.x2) / 2, y: (a + b) / 2)]
            : [RibbonPoint(x: f.x1 + dx, y: a), RibbonPoint(x: f.x2 - dx, y: b)]
        let parts = ribbonParts(
            [left] + cps + [right],
            [left] + cps.map { RibbonPoint(x: $0.x, y: $0.y + thickness) } + [right],
            padding: f.space * 0.15
        )
        let hits = parts.filter { p in
            obstacles.contains { o in p.x < o.x + o.w && o.x < p.x + p.w && p.y < o.y + o.h && o.y < p.y + p.h }
        }.count
        if hits < cost {
            best = f.rise ?? initial
            cost = hits
        }
        if hits == 0 { break }
    }
    f.rise = best
    return cost == 0
}

/// Draw only the hooks, labels and wedge apertures belonging to this particular segment. (VexFlow 5.4.0)
public func drawSpan(_ ctx: RenderContext, _ f: SpanFragment, label: VexElement? = nil) {
    let kind = f.kind, space = f.space, x1 = f.x1, x2 = f.x2, y1 = f.y1, y2 = f.y2, above = f.above
    let start = f.part == .single || f.part == .first
    let end = f.part == .single || f.part == .last
    let sign: Double = above ? -1 : 1
    func line(_ a: Double, _ b: Double, _ c: Double, _ d: Double) {
        ctx.beginPath()
        ctx.moveTo(a, b)
        ctx.lineTo(c, d)
        ctx.stroke()
    }
    ctx.save()
    defer { ctx.restore() }
    if kind == .slur || kind == .tie {
        let (dx, a, b) = controls(f)
        ctx.beginPath()
        ctx.moveTo(x1, y1)
        if kind == .tie {
            let x = (x1 + x2) / 2, y = (a + b) / 2
            ctx.quadraticCurveTo(x, y, x2, y2)
            ctx.quadraticCurveTo(x, y + sign * space * 0.22, x1, y1)
        } else {
            ctx.bezierCurveTo(x1 + dx, a, x2 - dx, b, x2, y2)
            ctx.bezierCurveTo(x2 - dx, b + sign * space * 0.22, x1 + dx, a + sign * space * 0.22, x1, y1)
        }
        ctx.closePath()
        ctx.fill()
        return
    }
    if kind == .crescendo || kind == .diminuendo {
        let aperture = { (t: Double) in space * 0.55 * (kind == .crescendo ? t : 1 - t) }
        let left = aperture(f.progress.0), right = aperture(f.progress.1)
        line(x1, y1 - left, x2, y2 - right)
        line(x1, y1 + left, x2, y2 + right)
        return
    }
    if kind == .tuplet {
        let mid = (x1 + x2) / 2
        let width = start && label != nil ? label!.getWidth() : 0
        let y = y1 + sign * space * 0.5
        if start, let label { label.renderText(ctx, xPos: mid - width / 2, yPos: y1) }
        if width != 0 {
            line(x1, y, mid - width / 2 - 2, y)
            line(mid + width / 2 + 2, y, x2, y)
        } else {
            line(x1, y, x2, y)
        }
        if start { line(x1, y, x1, y - sign * space * 0.65) }
        if end { line(x2, y, x2, y - sign * space * 0.65) }
        return
    }
    let shown = start ? label : nil
    if let shown { shown.renderText(ctx, xPos: x1, yPos: y1) }
    let left = shown.map { x1 + $0.getWidth() + space * 0.35 } ?? x1
    if kind == .hyphen {
        if x2 - left >= space * 0.5 {
            let mid = (left + x2) / 2
            line(mid - space * 0.25, y1 - space * 0.35, mid + space * 0.25, y1 - space * 0.35)
        }
        return
    }
    if kind == .lyric {
        if x2 > left { line(left, y1 + 1, x2, y2 + 1) }
        return
    }
    if kind == .trill {
        let period = space * 0.65
        ctx.beginPath()
        ctx.moveTo(left, y1 - 3)
        var x = left
        while x < x2 {
            let stop = min(x + period, x2), d = stop - x
            ctx.bezierCurveTo(x + d / 3, y1 - space * 0.8, x + (2 * d) / 3, y1 + space * 0.2, stop, y1 - 3)
            x = stop
        }
        ctx.stroke()
        return
    }
    if kind == .ottava || kind == .palmMute { ctx.setLineDash([space * 0.45, space * 0.35]) }
    let y = kind == .ottava ? y1 - space * 0.5 : kind == .volta ? y1 - space * 1.35 : y1
    if x2 > left { line(kind == .volta ? x1 : left, y, x2, y) }
    ctx.setLineDash([])
    if kind == .pedal {
        if start { line(x1, y, x1, y - space * 0.8) }
        if end { line(x2, y, x2, y - space * 0.8) }
    } else if kind == .volta {
        if start { line(x1, y, x1, y + space * 0.65) }
        if end { line(x2, y, x2, y + space * 0.65) }
    } else if (kind == .ottava || kind == .palmMute) && end {
        line(x2, y, x2, y - sign * space * 0.6)
    }
}
