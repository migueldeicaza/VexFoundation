// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/phraseribbon.ts` (VexFlow 5.4.0).
// Small conservative collision bounds for a filled quadratic or cubic engraving ribbon.

import Foundation

public struct RibbonPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Split a Bézier at its midpoint. The control hull of each half encloses that half of the ink.
private func halves(_ points: [RibbonPoint]) -> ([RibbonPoint], [RibbonPoint]) {
    var left = [points[0]]
    var right = [points[points.count - 1]]
    var row = points
    while row.count > 1 {
        let previous = row
        row = (1..<previous.count).map { i in
            RibbonPoint(x: (previous[i].x + previous[i - 1].x) / 2, y: (previous[i].y + previous[i - 1].y) / 2)
        }
        left.append(row[0])
        right.insert(row[row.count - 1], at: 0)
    }
    return (left, right)
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
        let (a1, a2) = halves(a)
        let (b1, b2) = halves(b)
        divide(a1, b1, depth + 1)
        divide(a2, b2, depth + 1)
    }
    divide(upper, lower, 0)
    return parts
}
