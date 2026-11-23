// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/hairpintip.ts` (VexFlow 5.7.0).
// Geometry shared by measured hairpins and their open niente circles at system boundaries.

import Foundation

/// Center and radius of the open circle in score coordinates.
public struct NienteTip: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var radius: Double

    public init(x: Double, y: Double, radius: Double) {
        self.x = x
        self.y = y
        self.radius = radius
    }
}

/// The side of the closed vertex where the circle sits.
public enum NienteSide: Sendable {
    case left
    case right
}

/// Seat the circle just outside the closed vertex so the wedge cannot cross its interior.
public func nienteTip(_ closedX: Double, _ y: Double, _ space: Double, _ side: NienteSide) -> NienteTip {
    let radius = space * 0.35
    return NienteTip(x: closedX + (side == .left ? -radius : radius), y: y, radius: radius)
}

/// Include the outer half of the circle's stroke.
public func nienteBounds(_ tip: NienteTip, _ halfStroke: Double) -> BoundingBox {
    let r = tip.radius + halfStroke
    return BoundingBox(tip.x - r, tip.y - r, 2 * r, 2 * r)
}

/// Stroke a separate path so the center remains transparent on any background.
public func drawNienteTip(_ ctx: RenderContext, _ tip: NienteTip) {
    ctx.beginPath()
    ctx.arc(tip.x, tip.y, tip.radius, 0, 2 * Double.pi, false)
    ctx.closePath()
    ctx.stroke()
}
