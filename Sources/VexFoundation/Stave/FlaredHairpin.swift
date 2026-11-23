// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/flaredhairpin.ts` (VexFlow 5.8.0).
// Draw smooth flared hairpins, including the portion visible on a single system.

import Foundation

/// Position on the centerline. Progress runs from zero at the closed tip to one at the loud end.
public struct HairpinPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var progress: Double

    public init(x: Double, y: Double, progress: Double) {
        self.x = x
        self.y = y
        self.progress = progress
    }
}

/// The aperture grows with the square of progress. Each fragment is an exact section of the same parabola.
public func drawFlaredHairpin(
    _ ctx: RenderContext,
    _ start: HairpinPoint,
    _ end: HairpinPoint,
    _ halfHeight: Double
) {
    let midX = (start.x + end.x) / 2
    let midY = (start.y + end.y) / 2
    // For t² on [a, b], the quadratic Bézier ordinates are a², ab and b².
    let left = halfHeight * pow(start.progress, 2)
    let control = halfHeight * start.progress * end.progress
    let right = halfHeight * pow(end.progress, 2)
    ctx.beginPath()
    for side in [-1.0, 1.0] {
        ctx.moveTo(start.x, start.y + side * left)
        ctx.quadraticCurveTo(midX, midY + side * control, end.x, end.y + side * right)
    }
    ctx.stroke()
}
