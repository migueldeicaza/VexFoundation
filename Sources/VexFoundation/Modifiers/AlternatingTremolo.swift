// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/alternatingtremolo.ts` (VexFlow 5.4.0).
// A measured two-note tremolo has two written endpoints and one shared span of musical time.

import Foundation

/// Same-staff alternating tremolo between adjacent quarter or half notes or chords.
public final class AlternatingTremolo: VexElement {
    public let first: StaveNote
    public let last: StaveNote
    public let strokes: Int

    public init(first: StaveNote, last: StaveNote, strokes: Int) throws {
        if strokes < 1 || strokes > 3 {
            throw VexError("BadArguments", "Expected one to three tremolo strokes.")
        }
        self.first = first
        self.last = last
        self.strokes = strokes
        super.init()
    }

    /// Call before building the voice. Each endpoint consumes half its printed duration.
    public static func endpoint(_ note: StaveNoteStruct, strokes: Int) throws -> StaveNoteStruct {
        let value = note.duration.value
        let isRest = note.type == .rest || note.duration.type == .rest
        if ![.half, .quarter].contains(value) || (note.dots ?? 0) > 0 || note.duration.dots > 0
            || note.durationOverride != nil || isRest || strokes < 1 || strokes > 3 {
            throw VexError("BadArguments", "Expected an undotted half or quarter tremolo endpoint.")
        }
        let denominator = value == .half ? 2 : 4
        var result = note
        result.durationOverride = Fraction(1, denominator * 2)
        result.notation = note.notation + [NotationIdentity(
            kind: .tremolo,
            id: "alternating-\(strokes)",
            label: "Alternating tremolo, \(strokes)" + (strokes == 1 ? " stroke" : " strokes")
        )]
        return result
    }

    /// Draw between stems after formatting. A change of staff or unsupported pair is an explicit error.
    override public func draw() throws {
        let voice = try first.getVoiceThrowing()
        let notes = voice.getTickables()
        let firstIndex = notes.firstIndex { $0 === first }
        let next = firstIndex.flatMap { $0 + 1 < notes.count ? notes[$0 + 1] : nil }
        let endpoints = [first, last].allSatisfy { n in
            n.getIntrinsicTicks() == Double(Tables.durationToTicks(n.getDuration()) ?? 0) / 2
                && n.notation.contains { $0.kind == .tremolo && $0.id == "alternating-\(strokes)" }
        }
        if try first.checkStaveThrowing() !== (try last.checkStaveThrowing())
            || (try? last.getVoiceThrowing()) !== voice
            || next !== last
            || first.getDuration() != last.getDuration()
            || first.getStemDirection() != last.getStemDirection()
            || !endpoints {
            throw VexError(
                "BadArguments",
                "Expected adjacent matching tremolo endpoints with parallel stems on one staff."
            )
        }
        let ctx = try checkContext()
        let spacing = first.checkStave().getSpacingBetweenLines()
        let x1 = first.getStemX()
        let x2 = last.getStemX()
        let inset = min(spacing * 0.4, (x2 - x1) / 5)
        let direction = first.getStemDirection().signDouble
        let y1 = first.getStemExtents().topY
        let y2 = last.getStemExtents().topY
        let slopeInset = ((y2 - y1) * inset) / (x2 - x1)
        _ = ctx.openGroup("alternating-tremolo", getAttribute("id"))
        for i in 0..<strokes {
            let offset = direction * spacing * (0.2 + Double(i) * 0.68)
            let thickness = direction * spacing * 0.42
            ctx.beginPath()
            ctx.moveTo(x1 + inset, y1 + slopeInset + offset)
            ctx.lineTo(x2 - inset, y2 - slopeInset + offset)
            ctx.lineTo(x2 - inset, y2 - slopeInset + offset + thickness)
            ctx.lineTo(x1 + inset, y1 + slopeInset + offset + thickness)
            ctx.closePath()
            ctx.fill()
        }
        ctx.closeGroup()
        setRendered()
    }
}
