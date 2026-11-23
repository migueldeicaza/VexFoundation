// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/figuredbass.ts` (VexFlow 5.8.0).
// Engrave figured-bass rows and their note-anchored continuation lines beneath a staff.

import Foundation

/// One written interval, with an optional attack through which the interval is held.
public struct FiguredBassFigure {
    public var note: StaveNote
    public var figure: String
    public var extendTo: StaveNote?

    public init(note: StaveNote, figure: String, extendTo: StaveNote? = nil) {
        self.note = note
        self.figure = figure
        self.extendTo = extendTo
    }
}

/// Rows read from top to bottom. Within each row, list only the written figures in musical order.
public struct FiguredBassSpec {
    public var rows: [[FiguredBassFigure]]

    public init(rows: [[FiguredBassFigure]]) {
        self.rows = rows
    }
}

/// A passage of independent figured-bass rows on a formatted staff.
public final class FiguredBass: VexElement {
    override public class var category: String { "FiguredBass" }

    /// SMuFL includes altered figures between its ordinary digits.
    private static let digits = [
        Glyphs.figbass0,
        Glyphs.figbass1,
        Glyphs.figbass2,
        Glyphs.figbass3,
        Glyphs.figbass4,
        Glyphs.figbass5,
        Glyphs.figbass6,
        Glyphs.figbass7,
        Glyphs.figbass8,
        Glyphs.figbass9,
    ]

    /// A drawn figure and its continuation share their ink geometry with measurements.
    private struct PlacedFigure {
        var glyph: VexElement
        var x: Double
        var baseline: Double
        var ink: BoundingBox
        var line: BoundingBox?
    }

    private struct Entry {
        var note: StaveNote
        var extendTo: StaveNote?
        var glyph: VexElement
    }

    private let rows: [[Entry]]
    /// Upstream keeps a `Set` in insertion order. This array keeps each note one time, in the same order.
    private var anchors: [StaveNote] = []

    public init(_ spec: FiguredBassSpec) throws {
        let rows = spec.rows
        if rows.isEmpty || rows.contains(where: { $0.isEmpty }) {
            throw VexError("BadArguments", "Each figured-bass row needs a written figure.")
        }
        var anchors: [StaveNote] = []
        func addAnchor(_ note: StaveNote) {
            if !anchors.contains(where: { $0 === note }) { anchors.append(note) }
        }
        self.rows = try rows.map { row in
            try row.map { item in
                if item.figure.isEmpty || !item.figure.unicodeScalars.allSatisfy({ $0.value >= 48 && $0.value <= 57 }) {
                    throw VexError("BadArguments", "Expected decimal digits for the figured-bass interval.")
                }
                addAnchor(item.note)
                if let extendTo = item.extendTo { addAnchor(extendTo) }
                let text = item.figure.unicodeScalars.map { FiguredBass.digits[Int($0.value) - 48] }.joined()
                return Entry(note: item.note, extendTo: item.extendTo, glyph: VexElement().setText(text))
            }
        }
        self.anchors = anchors
        super.init()
    }

    /// Use current notehead positions so spacing edits move every digit and endpoint together.
    private func layout() throws -> [PlacedFigure] {
        let stave = try rows[0][0].note.checkStaveThrowing()
        let gap = stave.space(0.3)
        var top = stave.getBottomLineY()
        var centers: [ObjectIdentifier: Double] = [:]
        for note in anchors {
            if try note.checkStaveThrowing().getYForLine(0) != stave.getYForLine(0) {
                throw VexError("BadArguments", "Figured-bass anchors must share a staff line on one system.")
            }
            if let ink = note.getBoundingBox(includeModifiers: false) {
                top = max(top, ink.y + ink.h + gap)
            }
            centers[ObjectIdentifier(note)] = (note.getNoteHeadBeginX() + note.getNoteHeadEndX()) / 2
        }
        func center(_ note: StaveNote) -> Double { centers[ObjectIdentifier(note)] ?? .nan }

        var placed: [PlacedFigure] = []
        for row in rows {
            struct Measured {
                var glyph: VexElement
                var center: Double
                var ink: BoundingBox
                var x: Double
            }
            let figures: [Measured] = row.map { entry in
                let ink = entry.glyph.setFont(fontInfo).getTextInk(0, 0)
                let c = center(entry.note)
                return Measured(glyph: entry.glyph, center: c, ink: ink, x: c - (ink.x + ink.w / 2))
            }
            // Accents and descenders in the music font must share a baseline within the row.
            let ascent = figures.map { -$0.ink.y }.max() ?? 0
            let descent = figures.map { $0.ink.y + $0.ink.h }.max() ?? 0
            let baseline = top + ascent
            let thickness = getStyle()?.lineWidth ?? 1
            let lineY = top + (ascent + descent - thickness) / 2
            for (i, measured) in figures.enumerated() {
                let next = i + 1 < figures.count ? figures[i + 1] : nil
                if let next, next.center <= measured.center {
                    throw VexError("BadArguments", "Order each figured-bass row from left to right.")
                }
                var ink = measured.ink
                ink.move(measured.x, baseline)
                var figure = PlacedFigure(glyph: measured.glyph, x: measured.x, baseline: baseline, ink: ink)
                if let stop = row[i].extendTo {
                    let end = center(stop)
                    if end <= measured.center || (next.map { end > $0.center } ?? false) {
                        throw VexError(
                            "BadArguments", "A figure may extend only up to the next written figure in its row."
                        )
                    }
                    let start = ink.x + ink.w + gap
                    // A resolving digit at the endpoint needs room for its own ink.
                    let right = next.map { min(end, $0.center - $0.ink.w / 2 - gap) } ?? end
                    if right > start {
                        figure.line = BoundingBox(x: start, y: lineY, w: right - start, h: thickness)
                    }
                }
                placed.append(figure)
            }
            top = baseline + descent + gap
        }
        return placed
    }

    /// Individual digit groups and continuation strokes in drawing order.
    public func getInkParts() throws -> [BoundingBox] {
        try layout().flatMap { figure in figure.line.map { [figure.ink, $0] } ?? [figure.ink] }
    }

    /// The union of all ink parts, or `nil` when the layout is not valid (upstream throws).
    override public func getBoundingBox() -> BoundingBox? {
        guard let parts = try? getInkParts(), var bounds = parts.first else { return nil }
        for part in parts.dropFirst() { bounds.mergeWith(part) }
        return bounds
    }

    override public func draw() throws {
        let ctx = try checkContext()
        let figures = try layout()
        ctx.save()
        _ = ctx.openGroup("figured-bass", getAttribute("id"))
        for figure in figures {
            figure.glyph.renderText(ctx, xPos: figure.x, yPos: figure.baseline)
            if let line = figure.line {
                let y = line.y + line.h / 2
                ctx.setLineWidth(line.h)
                ctx.beginPath()
                ctx.moveTo(line.x, y)
                ctx.lineTo(line.x + line.w, y)
                ctx.stroke()
            }
        }
        ctx.closeGroup()
        ctx.restore()
        setRendered()
    }
}
