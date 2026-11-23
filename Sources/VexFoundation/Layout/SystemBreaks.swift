// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/systembreaks.ts` (VexFlow 5.4.0).
// Select continuous-score rows from measured boundary costs and hard musical breaks.

import Foundation

/// A break constraint before a measure. (VexFlow 5.4.0)
public enum BreakConstraint: String, Sendable {
    /// Always start a new row at this measure.
    case force
    /// Never start a new row at this measure.
    case keep
}

/// Row break mode. Both modes use identical reservations. (VexFlow 5.4.0)
public enum SystemBreakMode: String, Sendable {
    case balanced
    case greedy
}

/// One drawable measure or one compressed rest, with its extra width at a row boundary. (VexFlow 5.4.0)
public struct BreakUnit: Sendable, Equatable {
    public var width: Double
    public var start: Double
    public var end: Double
    public var breakBefore: BreakConstraint?

    public init(width: Double, start: Double, end: Double, breakBefore: BreakConstraint? = nil) {
        self.width = width
        self.start = start
        self.end = end
        self.breakBefore = breakBefore
    }
}

/// Both modes use identical reservations. An inseparable oversized group occupies a row by itself.
/// Returns the unit indices of each row. (VexFlow 5.4.0)
public func chooseSystemBreaks(
    _ units: [BreakUnit],
    width: Double,
    gap: Double,
    indent: (Int) -> Double,
    mode: SystemBreakMode
) -> [[Int]] {
    let n = units.count
    var next = [Int](repeating: 0, count: n)
    var costs = [Double](repeating: .infinity, count: n + 1)
    var clipped = [Double](repeating: .infinity, count: n + 1)
    costs[n] = 0
    clipped[n] = 0
    var i = n - 1
    while i >= 0 {
        var body = indent(i) + units[i].start
        var found = false
        for j in i..<n {
            if j > i && units[j].breakBefore == .force { break }
            body += units[j].width + (j > i ? gap : 0)
            if j + 1 < n && units[j + 1].breakBefore == .keep { continue }
            let spare = width - body - units[j].end
            if spare < 0 && found {
                // A long courtesy ending can disappear if the following measure joins this row.
                if body >= width { break }
                continue
            }
            let overflow = max(0, -spare)
            // Squared unused width discourages a very short final row. Breaking costs keep tiny rows rare.
            let cost = costs[j + 1] + width * width * 0.12
                + (spare >= 0 ? spare * spare : width * width + 16 * overflow * overflow)
            let clippedWidth = overflow + clipped[j + 1]
            let improves = clippedWidth < clipped[i] || (clippedWidth == clipped[i] && cost <= costs[i])
            if !found || (mode == .greedy ? spare >= 0 : improves) {
                clipped[i] = clippedWidth
                next[i] = j + 1
                costs[i] = cost
            }
            found = true
            if body >= width { break }
        }
        i -= 1
    }
    var rows: [[Int]] = []
    var k = 0
    while k < n {
        rows.append(Array(k..<next[k]))
        k = next[k]
    }
    return rows
}
