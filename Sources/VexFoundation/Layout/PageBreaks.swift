// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/pagebreaks.ts` (VexFlow 5.4.0).
// Choose page turns on measured system boundaries. Dimensions are in millimeters.

import Foundation

/// One measured system. (VexFlow 5.4.0)
public struct PrintableSystem: Sendable, Equatable {
    public var measures: [Int]
    public var height: Double
    public var restAtEnd: Bool

    public init(measures: [Int], height: Double, restAtEnd: Bool) {
        self.measures = measures
        self.height = height
        self.restAtEnd = restAtEnd
    }
}

/// Page capacity and page-turn rules. (VexFlow 5.4.0)
public struct PageConstraints: Sendable, Equatable {
    public var firstHeight: Double
    public var laterHeight: Double
    public var gap: Double
    public var maxExtraGap: Double
    public var justifyLast: Bool
    public var part: Bool
    public var forceBefore: Set<Int>
    public var preferAfter: Set<Int>
    public var forbidAfter: Set<Int>

    public init(
        firstHeight: Double, laterHeight: Double, gap: Double, maxExtraGap: Double, justifyLast: Bool = false,
        part: Bool = false, forceBefore: Set<Int> = [], preferAfter: Set<Int> = [], forbidAfter: Set<Int> = []
    ) {
        self.firstHeight = firstHeight
        self.laterHeight = laterHeight
        self.gap = gap
        self.maxExtraGap = maxExtraGap
        self.justifyLast = justifyLast
        self.part = part
        self.forceBefore = forceBefore
        self.preferAfter = preferAfter
        self.forbidAfter = forbidAfter
    }
}

/// System indices and offsets from the top of the page's music area. (VexFlow 5.4.0)
public struct PageBreak: Sendable, Equatable {
    public var first: Int
    public var end: Int
    public var offsets: [Double]
    public var overflow: Double
    public var forbiddenTurn: Bool
}

/// Minimize forbidden turns, then pages, then turn difficulty and unused space. (VexFlow 5.4.0)
public func paginate(_ systems: [PrintableSystem], _ rules: PageConstraints) -> [PageBreak] {
    struct Cost {
        var conflicts: Int
        var pages: Int
        var penalty: Double
    }
    let count = systems.count
    var costs = [Cost?](repeating: nil, count: count + 1)
    var ends = [Int](repeating: 0, count: count)
    costs[count] = Cost(conflicts: 0, pages: 0, penalty: 0)
    var first = count - 1
    while first >= 0 {
        let capacity = first == 0 ? rules.firstHeight : rules.laterHeight
        var used: Double = 0
        for i in first..<count {
            let row = systems[i]
            if i > first, let m = row.measures.first, rules.forceBefore.contains(m) { break }
            used += row.height + (i == first ? 0 : rules.gap)
            if i > first && used > capacity + 1e-7 { break }
            let after = row.measures.last ?? 0
            let turn = i + 1 < count
            // Every later start was solved, so its cost exists.
            guard let rest = costs[i + 1] else { continue }
            let conflicts = rest.conflicts + (turn && rules.forbidAfter.contains(after) ? 1 : 0)
            let pages = rest.pages + 1
            let difficulty: Double = !turn || rules.preferAfter.contains(after) ? 0 : rules.part && !row.restAtEnd ? 4 : 1
            let unused = max(0, capacity - used) / capacity
            let penalty = rest.penalty + difficulty + (turn ? unused * unused : 0)
            let best = costs[first]
            if best == nil
                || conflicts < best!.conflicts
                || (conflicts == best!.conflicts
                    && (pages < best!.pages || (pages == best!.pages && penalty <= best!.penalty))) {
                costs[first] = Cost(conflicts: conflicts, pages: pages, penalty: penalty)
                ends[first] = i + 1
            }
        }
        first -= 1
    }

    var pages: [PageBreak] = []
    var start = 0
    while start < count {
        let end = ends[start]
        let rows = Array(systems[start..<end])
        let capacity = start == 0 ? rules.firstHeight : rules.laterHeight
        let spare = capacity - rows.reduce(0) { $0 + $1.height } - rules.gap * Double(rows.count - 1)
        let extra = rows.count > 1 && (end < count || rules.justifyLast)
            ? min(rules.maxExtraGap, max(0, spare) / Double(rows.count - 1))
            : 0
        var y: Double = 0
        let offsets = rows.map { row -> Double in
            let top = y
            y += row.height + rules.gap + extra
            return top
        }
        let last = rows[rows.count - 1].measures.last ?? 0
        pages.append(PageBreak(
            first: start,
            end: end,
            offsets: offsets,
            overflow: max(0, -spare),
            forbiddenTurn: end < count && rules.forbidAfter.contains(last)
        ))
        start = end
    }
    return pages
}
