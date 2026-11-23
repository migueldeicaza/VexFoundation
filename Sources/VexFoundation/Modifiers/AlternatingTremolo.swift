// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/alternatingtremolo.ts` (VexFlow 5.7.0).
// A measured two-note tremolo has two written endpoints and one shared span of musical time.

import Foundation

/// Engraved thickness and distance between consecutive stroke tops in staff spaces.
private let strokeThickness = 0.42
private let strokeStep = 0.68

/// The outer stroke follows the same maximum inclination as a native beam.
private let maxCrossStaffSlope = 0.25

/// The two upper corners describe the first stroke. Subsequent strokes run parallel to it.
private struct StrokeLayout {
    var x1: Double
    var x2: Double
    var y1: Double
    var y2: Double
    var direction: Double
    var insetY: Double
    var extensions: [(x: Double, y: Double, h: Double)] = []
}

/// Both the endpoint timing and the drawn relationship carry the same subdivision.
private func checkStrokes(_ strokes: Int) throws {
    if strokes < 1 || strokes > 4 {
        throw VexError("BadArguments", "Expected one to four tremolo strokes.")
    }
}

/// Alternating tremolo between adjacent whole, half or quarter notes or chords in one voice.
public final class AlternatingTremolo: VexElement {
    public let first: StaveNote
    public let last: StaveNote
    public let strokes: Int

    public init(first: StaveNote, last: StaveNote, strokes: Int) throws {
        try checkStrokes(strokes)
        self.first = first
        self.last = last
        self.strokes = strokes
        super.init()
    }

    /// Call before building the voice. Each endpoint consumes half its printed duration.
    public static func endpoint(_ note: StaveNoteStruct, strokes: Int) throws -> StaveNoteStruct {
        try checkStrokes(strokes)
        let value = note.duration.value
        let isRest = note.type == .rest || note.duration.type == .rest
        if ![.whole, .half, .quarter].contains(value) || (note.dots ?? 0) > 0 || note.duration.dots > 0
            || note.durationOverride != nil || isRest {
            throw VexError("BadArguments", "Expected an undotted whole, half or quarter tremolo endpoint.")
        }
        let denominator = value == .whole ? 1 : value == .half ? 2 : 4
        var result = note
        result.durationOverride = Fraction(1, denominator * 2)
        result.notation = note.notation + [NotationIdentity(
            kind: .tremolo,
            id: "alternating-\(strokes)",
            label: "Alternating tremolo, \(strokes)" + (strokes == 1 ? " stroke" : " strokes")
        )]
        return result
    }

    /// Read the voice and staff assignments after formatting so a retained score can change staff gaps.
    private func checkPair() throws {
        let voice = try first.getVoiceThrowing()
        let notes = voice.getTickables()
        let index = notes.firstIndex { $0 === first }
        let next = index.flatMap { $0 + 1 < notes.count ? notes[$0 + 1] : nil }
        let endpoints = [first, last].allSatisfy { n in
            !n.isRest()
                && n.getIntrinsicTicks() == Double(Tables.durationToTicks(n.getDuration()) ?? 0) / 2
                && n.notation.contains { $0.kind == .tremolo && $0.id == "alternating-\(strokes)" }
        }
        if index == nil
            || (try? last.getVoiceThrowing()) !== voice
            || next !== last
            || Tables.sanitizeDuration(first.getDuration()) != Tables.sanitizeDuration(last.getDuration())
            || !first.getTicks().equals(last.getTicks())
            || !endpoints {
            throw VexError("BadArguments", "Expected adjacent matching tremolo endpoints in one voice.")
        }
        let firstStave = try first.checkStaveThrowing()
        let lastStave = try last.checkStaveThrowing()
        if firstStave !== lastStave {
            let sharedLeft = max(firstStave.getX(), lastStave.getX())
            let sharedRight = min(firstStave.getX() + firstStave.getWidth(), lastStave.getX() + lastStave.getWidth())
            if first.getAbsoluteX() < sharedLeft || last.getAbsoluteX() > sharedRight {
                throw VexError("BadArguments", "Both tremolo notes must lie in the same cross-staff measure.")
            }
        }
        if first.getAbsoluteX() >= last.getAbsoluteX() {
            throw VexError("BadArguments", "A tremolo needs horizontally ordered endpoints on the same system.")
        }
        if first.hasStem() && firstStave === lastStave && first.getStemDirection() != last.getStemDirection() {
            throw VexError("BadArguments", "A same-staff tremolo needs parallel stems.")
        }
    }

    /// Center a compact horizontal stack in the clear space between two stemless whole-note chords.
    private func floatingStrokes(_ space: Double) throws -> StrokeLayout {
        let firstInk = first.getHeadInk()
        let lastInk = last.getHeadInk()
        let gapLeft = firstInk.map { $0.x + $0.w }.max() ?? -Double.infinity
        let gapRight = lastInk.map { $0.x }.min() ?? Double.infinity
        if gapRight <= gapLeft { throw VexError("BadArguments", "No room between whole-note tremolo heads.") }
        let center = (gapLeft + gapRight) / 2
        let halfWidth = min(space, (gapRight - gapLeft) * 0.4)
        let direction = -first.calculateOptimalStemDirection().signDouble
        let ys = first.getYs() + last.getYs()
        let y = ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2 + direction * space
        return StrokeLayout(x1: center - halfWidth, x2: center + halfWidth, y1: y, y2: y, direction: direction, insetY: 0)
    }

    /// Fit a cross-staff stack to both stem tips. Extensions keep widely separated staves readable.
    private func crossStaffStrokes(_ space: Double) throws -> StrokeLayout {
        guard let left = first.getStemSegment(), let right = last.getStemSegment() else {
            throw VexError("BadArguments", "A cross-staff tremolo needs two visible stems.")
        }
        let height = space * (Double(strokes - 1) * strokeStep + strokeThickness)
        let leftDown = first.getStemDirection() == Stem.DOWN
        let rightDown = last.getStemDirection() == Stem.DOWN
        let leftTop = left.tipY - (leftDown ? height : 0)
        let rightTop = right.tipY - (rightDown ? height : 0)
        let limit = (right.x - left.x) * maxCrossStaffSlope
        let rise = max(-limit, min(limit, rightTop - leftTop))
        // A stem can grow toward the tremolo. It cannot retract after its note has printed.
        let minTop = max(leftDown ? leftTop : -Double.infinity, rightDown ? rightTop - rise : -Double.infinity)
        let maxTop = min(leftDown ? Double.infinity : leftTop, rightDown ? Double.infinity : rightTop - rise)
        var y1 = leftTop
        var y2 = rightTop
        if minTop <= maxTop {
            y1 = max(minTop, min(maxTop, (leftTop + rightTop - rise) / 2))
            y2 = y1 + rise
        }
        func extension_(_ x: Double, _ tip: Double, _ growth: Double) -> (x: Double, y: Double, h: Double) {
            (x: x - Stem.WIDTH / 2, y: min(tip, tip + growth), h: abs(growth))
        }
        return StrokeLayout(
            x1: left.x,
            x2: right.x,
            y1: y1,
            y2: y2,
            direction: 1,
            insetY: 0,
            extensions: [extension_(left.x, left.tipY, y1 - leftTop), extension_(right.x, right.tipY, y2 - rightTop)]
        )
    }

    /// The same-staff strokes follow the native stem slope and retain the original engraving.
    private func stemStrokes(_ space: Double) throws -> StrokeLayout {
        let x1 = first.getStemX()
        let x2 = last.getStemX()
        if x2 <= x1 { throw VexError("BadArguments", "A tremolo needs space between the stems.") }
        if try first.checkStaveThrowing() !== (try last.checkStaveThrowing()) { return try crossStaffStrokes(space) }
        let direction = first.getStemDirection().signDouble
        // The original same-staff engraving leaves a small gap between the strokes and stems.
        let inset = min(space * 0.4, (x2 - x1) / 5)
        let y1 = first.getStemExtents().topY
        let y2 = last.getStemExtents().topY
        let slopeInset = ((y2 - y1) * inset) / (x2 - x1)
        return StrokeLayout(
            x1: x1 + inset, x2: x2 - inset, y1: y1 + slopeInset, y2: y2 - slopeInset, direction: direction, insetY: 0.2
        )
    }

    /// Draw from final note positions without changing note timing or stem directions.
    override public func draw() throws {
        try checkPair()
        let ctx = try checkContext()
        let space = try first.checkStaveThrowing().getSpacingBetweenLines()
        let whole = Tables.sanitizeDuration(first.getDuration()) == "1"
        let layout = whole ? try floatingStrokes(space) : try stemStrokes(space)
        _ = ctx.openGroup("alternating-tremolo", getAttribute("id"))
        for stem in layout.extensions where stem.h > 0 {
            ctx.fillRect(stem.x, stem.y, Stem.WIDTH, stem.h)
        }
        for i in 0..<strokes {
            let offset = layout.direction * space * (layout.insetY + Double(i) * strokeStep)
            let thickness = layout.direction * space * strokeThickness
            ctx.beginPath()
            ctx.moveTo(layout.x1, layout.y1 + offset)
            ctx.lineTo(layout.x2, layout.y2 + offset)
            ctx.lineTo(layout.x2, layout.y2 + offset + thickness)
            ctx.lineTo(layout.x1, layout.y1 + offset + thickness)
            ctx.closePath()
            ctx.fill()
        }
        ctx.closeGroup()
        setRendered()
    }
}
