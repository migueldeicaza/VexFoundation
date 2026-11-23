// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tabtiefit.ts` (VexFlow 5.8.0).
// Fit every fragment of a TAB tie to the same side of its string, using the actual fret text on each row.

import Foundation

/// Evaluate both sides from the same string anchors. Prefer the shallower clear fit. When the two fits are
/// equal, keep the default side. Returns the fragments that still collide. (VexFlow 5.8.0)
@discardableResult
public func fitTabTie(_ fragments: inout [SpanFragment], _ obstacles: [[BoundingBox]], _ automatic: Bool) -> [SpanFragment] {
    func candidate(_ reverse: Bool) -> (curves: [SpanFragment], missed: [Int], lift: Double) {
        var missed: [Int] = []
        var lift = 0.0
        let curves = fragments.enumerated().map { i, fragment -> SpanFragment in
            var curve = fragment
            if reverse {
                curve.above = !curve.above
                // The authored endpoints sit 0.3 staff spaces on either side of their string.
                let shift = (curve.above ? -1.0 : 1.0) * curve.space * 0.6
                curve.y1 += shift
                curve.y2 += shift
            }
            if !fitSpan(&curve, i < obstacles.count ? obstacles[i] : []) { missed.append(i) }
            lift += curve.rise ?? 0
            return curve
        }
        return (curves, missed, lift)
    }
    var best = candidate(false)
    if automatic && obstacles.contains(where: { !$0.isEmpty }) {
        let other = candidate(true)
        if other.missed.count < best.missed.count
            || (other.missed.count == best.missed.count && other.lift < best.lift) {
            best = other
        }
    }
    fragments = best.curves
    return best.missed.map { fragments[$0] }
}
