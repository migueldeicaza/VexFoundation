// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/phraseribbon.ts` (VexFlow 5.8.0).
// Bézier subdivision for engraving ribbon bounds and mixed dashed/solid slur strokes.

import Foundation

public struct RibbonPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// De Casteljau subdivision preserves both the original curve and its tangent at the join. (VexFlow 5.8.0)
func splitBezier(_ points: [RibbonPoint], _ t: Double = 0.5) -> ([RibbonPoint], [RibbonPoint]) {
    var left = [points[0]]
    var right = [points[points.count - 1]]
    var row = points
    while row.count > 1 {
        let previous = row
        row = (1..<previous.count).map { i in
            RibbonPoint(
                x: (1 - t) * previous[i - 1].x + t * previous[i].x,
                y: (1 - t) * previous[i - 1].y + t * previous[i].y
            )
        }
        left.append(row[0])
        right.insert(row[row.count - 1], at: 0)
    }
    return (left, right)
}

/// Stroke the dashed opening and solid ending of a single fitted slur, including any system fragments.
/// `points` are the four points of a cubic Bézier. `range` is the part of the whole slur that the
/// fragment covers (upstream `[start, end]`). (VexFlow 5.8.0)
public func drawHalfDashedSlur(
    _ ctx: RenderContext,
    _ points: [RibbonPoint],
    _ range: (start: Double, end: Double) = (0, 1),
    dash: [Double] = [4, 3]
) {
    func stroke(_ p: [RibbonPoint], _ pattern: [Double]) {
        ctx.setLineDash(pattern)
        ctx.beginPath()
        ctx.moveTo(p[0].x, p[0].y)
        ctx.bezierCurveTo(p[1].x, p[1].y, p[2].x, p[2].y, p[3].x, p[3].y)
        ctx.stroke()
    }
    guard points.count == 4 else { return }
    let (start, end) = range
    ctx.save()
    defer { ctx.restore() }
    if end <= 0.5 {
        stroke(points, dash)
    } else if start >= 0.5 {
        stroke(points, [])
    } else {
        let (opening, ending) = splitBezier(points, (0.5 - start) / (end - start))
        stroke(opening, dash)
        stroke(ending, [])
    }
}

/// Both boundaries run from the first attachment to the last. Never sample past a thin obstacle.
public func ribbonParts(_ upper: [RibbonPoint], _ lower: [RibbonPoint], padding: Double = 0) -> [BoundingBox] {
    var parts: [BoundingBox] = []
    func divide(_ a: [RibbonPoint], _ b: [RibbonPoint], _ depth: Int) {
        let hull = a + b
        let xs = hull.map(\.x)
        let ys = hull.map(\.y)
        // JavaScript `Math.min()` of an empty list is `Infinity`; the hull is never empty here.
        let x = xs.min() ?? .infinity
        let y = ys.min() ?? .infinity
        let w = (xs.max() ?? -.infinity) - x
        if depth == 6 || w <= 6 {
            parts.append(BoundingBox(x - padding, y - padding, w + 2 * padding, (ys.max() ?? -.infinity) - y + 2 * padding))
            return
        }
        let (a1, a2) = splitBezier(a)
        let (b1, b2) = splitBezier(b)
        divide(a1, b1, depth + 1)
        divide(a2, b2, depth + 1)
    }
    divide(upper, lower, 0)
    return parts
}
