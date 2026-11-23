// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tiedbend.ts` (VexFlow 5.7.0).
// Layout and painting for a string bend sustained into a second written TAB event.

import Foundation

/// A single system's portion of the bend. Only the attack owns a rise and only the arrival owns a release.
public struct TiedBendDrawing: Sendable, Equatable {
    public var envelope: TiedBend
    public var left: Double
    public var right: Double
    public var targetY: Double
    public var stringY: Double
    public var peakX: Double?
    public var releaseX: Double?
    public var bounds: BoundingBox
}

/// End of the space occupied by a written event. Leave ink clearance at the following fret or barline.
private func eventEnd(_ note: Note, _ space: Double) -> Double {
    let ticks = note.getVoice().getTickables()
    let index = ticks.firstIndex { $0 === note } ?? -1
    let following = ticks.dropFirst(index + 1).first { !$0.shouldIgnoreTicks() }
    if let following = following as? Note { return following.getTieLeftX() - space * 0.25 }
    return note.checkStave().getNoteEndX() - space * 0.35
}

/// Place each phase against its owner's duration, independently of how the available row widths change.
func layoutTiedBend(
    _ envelope: TiedBend,
    _ first: Note?,
    _ last: Note?,
    _ left: Double,
    _ rowEnd: Double,
    _ stringY: Double,
    _ targetY: Double,
    _ space: Double,
    _ label: VexElement
) -> TiedBendDrawing {
    func phase(_ start: Double, _ end: Double, _ ratio: GesturePhase) -> Double {
        start + ((end - start) * Double(ratio.0)) / Double(ratio.1)
    }
    let peakX = first.map { phase(left, eventEnd($0, space), envelope.rise) }
    let arrival = last?.getTieRightX() ?? 0
    let extent = last.map { eventEnd($0, space) } ?? rowEnd
    let releaseX = last != nil ? phase(arrival, extent, envelope.hold) : nil
    let right = last != nil ? phase(arrival, extent, envelope.release) : rowEnd
    let arrowWidth = space * 0.3
    let minX = min(left, peakX.map { $0 - arrowWidth } ?? left) - 1
    let maxX = max(right + (last != nil ? arrowWidth : 0), (peakX ?? left) + arrowWidth) + 1
    var box = BoundingBox(minX, targetY - 1, maxX - minX, stringY - targetY + 2)
    if let peakX {
        let ink = label.getTextInk(peakX - label.getWidth() / 2, targetY - space * 0.3)
        box.mergeWith(BoundingBox(ink.x, ink.y, ink.w, ink.h))
    }
    return TiedBendDrawing(
        envelope: envelope, left: left, right: right, targetY: targetY, stringY: stringY,
        peakX: peakX, releaseX: releaseX, bounds: box
    )
}

/// Mark the direction once at the rise or release. The continuation at the row edge is horizontal.
private func arrow(_ ctx: RenderContext, _ x: Double, _ y: Double, _ size: Double) {
    ctx.beginPath()
    ctx.moveTo(x, y)
    ctx.lineTo(x - abs(size), y + size)
    ctx.lineTo(x + abs(size), y + size)
    ctx.closePath()
    ctx.fill()
}

/// The same curves, arrows and target label are used by SVG and Canvas.
func drawTiedBend(_ ctx: RenderContext, _ drawing: TiedBendDrawing, _ space: Double, _ label: VexElement) {
    let left = drawing.left, right = drawing.right, stringY = drawing.stringY, targetY = drawing.targetY
    _ = ctx.openGroup("tied-bend", nil)
    ctx.beginPath()
    if let peakX = drawing.peakX {
        ctx.moveTo(left, stringY)
        ctx.quadraticCurveTo(peakX, stringY, peakX, targetY)
    } else {
        ctx.moveTo(left, targetY)
    }
    ctx.lineTo(drawing.releaseX ?? right, targetY)
    if drawing.releaseX != nil { ctx.quadraticCurveTo(right, targetY, right, stringY) }
    ctx.stroke()
    if let peakX = drawing.peakX {
        arrow(ctx, peakX, targetY, space * 0.3)
        label.renderText(ctx, xPos: peakX - label.getWidth() / 2, yPos: targetY - space * 0.3)
    }
    if drawing.releaseX != nil { arrow(ctx, right, stringY, -space * 0.3) }
    ctx.closeGroup()
}
