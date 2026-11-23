// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/sheet.ts` (VexFlow 5.2.0).
// Optional continuous-sheet layout for existing Systems. No music data model or pagination.

import Foundation

/// Options for a `Sheet`. Dimensions are in rendering units (normally pixels).
public struct SheetOptions: Sendable {
    /// Available row width.
    public var width: Double
    public var x: Double
    public var y: Double
    /// Vertical space between rows.
    public var rowGap: Double
    /// Horizontal space between measures in a row.
    public var measureGap: Double
    /// Space added to the intrinsic width of each measure.
    public var measurePadding: Double
    /// Distribute the leftover row width over the measures of the row.
    public var justify: Bool

    public init(
        width: Double = 500,
        x: Double = 10,
        y: Double = 10,
        rowGap: Double = 40,
        measureGap: Double = 0,
        measurePadding: Double = 20,
        justify: Bool = true
    ) {
        self.width = width
        self.x = x
        self.y = y
        self.rowGap = rowGap
        self.measureGap = measureGap
        self.measurePadding = measurePadding
        self.justify = justify
    }
}

/// Layout result for one row. Oversized measures occupy their own row and remain readable.
public struct SheetRow {
    public var systems: [System]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    /// Width beyond the sheet width (only for a row with one oversized measure).
    public var overflow: Double
}

/// Arrange measure-sized Systems left to right, wrapping at a requested width.
public final class Sheet {
    private var options: SheetOptions
    private unowned let factory: Factory
    private var systems: [System] = []
    private var rows: [SheetRow] = []

    /// Create a sheet. Usually created with `Factory.Sheet(options:)`.
    /// Throws when the width is not positive and finite, or when another dimension
    /// is negative or not finite.
    public init(factory: Factory, options: SheetOptions = SheetOptions()) throws {
        self.factory = factory
        self.options = options
        try setWidth(options.width)
        let checks: [(String, Double)] = [
            ("x", options.x), ("y", options.y), ("rowGap", options.rowGap),
            ("measureGap", options.measureGap), ("measurePadding", options.measurePadding),
        ]
        for (key, value) in checks where !value.isFinite || value < 0 {
            throw VexError("BadArgument", "Sheet \(key) must be a nonnegative finite number.")
        }
    }

    /// Create a measure. Add its staves and voices with the existing System API.
    /// The `factory`, `width`, `autoWidth` and `noJustification` options are set by the sheet.
    @discardableResult
    public func addSystem(_ options: SystemOptions = SystemOptions()) -> System {
        var opts = options
        opts.autoWidth = true
        opts.noJustification = false
        let system = factory.System(options: opts)
        systems.append(system)
        return system
    }

    /// Update the available row width. Call `format()` or `Factory.draw()` to reflow.
    @discardableResult
    public func setWidth(_ width: Double) throws -> Self {
        guard width.isFinite, width > 0 else {
            throw VexError("BadArgument", "Sheet width must be a positive finite number.")
        }
        options.width = width
        return self
    }

    /// The available row width.
    public func getWidth() -> Double { options.width }

    /// The measures (a copy of the membership array).
    public func getSystems() -> [System] { systems }

    /// Row bounds and overflow after formatting.
    public func getRows() -> [SheetRow] { rows }

    /// Required drawing height, including the top inset.
    public func getHeight() -> Double {
        guard let last = rows.last else { return options.y }
        return last.y + last.height
    }

    /// Measure and pack rows. Always recompute, so repeated resize is deterministic.
    @discardableResult
    public func format() throws -> Self {
        let widths = try measureSystems()
        rows = []
        var y = options.y
        for indices in packRows(widths) {
            let row = try formatRow(indices, widths, y)
            rows.append(row)
            y += row.height + options.rowGap
        }
        return self
    }

    /// Measure intrinsic widths without carrying coordinates over from a prior layout.
    private func measureSystems() throws -> [Double] {
        try systems.map { system in
            system.setX(0).setY(0).setWidth()
            try system.formatThrowing()
            return system.getWidth() + options.measurePadding
        }
    }

    /// Greedy packing keeps measure order and gives oversized measures their own rows.
    private func packRows(_ widths: [Double]) -> [[Int]] {
        var groups: [[Int]] = []
        var group: [Int] = []
        var used: Double = 0
        for (index, width) in widths.enumerated() {
            let gap = group.isEmpty ? 0 : options.measureGap
            if !group.isEmpty && used + gap + width > options.width {
                groups.append(group)
                group = []
                used = 0
            }
            used += (group.isEmpty ? 0 : options.measureGap) + width
            group.append(index)
        }
        if !group.isEmpty { groups.append(group) }
        return groups
    }

    /// Include staff envelopes and note bounds in the ordinary vertical layout.
    private func verticalBounds(_ system: System) -> (top: Double, bottom: Double) {
        var top: Double = 0
        var bottom = system.getBoundingBox()?.h ?? 0
        // Spanning marks and arbitrary annotations still need caller-supplied rowGap.
        for voice in system.getVoices() {
            for note in voice.getTickables() {
                // Modifier and generic text bounds may still contain coordinates from the last draw.
                // Measure pitched heads/stems and inline clefs from current layout only. Other notes use
                // their stave-relative Y positions; arbitrary labels and spans still need explicit rowGap.
                if note is StaveNote || note is ClefNote {
                    let box = (note as? StaveNote)?.getBoundingBox(includeModifiers: false) ?? note.getBoundingBox()
                    guard let box else { continue }
                    top = min(top, box.y)
                    bottom = max(bottom, box.y + box.h)
                } else if let note = note as? Note {
                    let padding = note.checkStave().getSpacingBetweenLines()
                    for y in note.getYs() {
                        top = min(top, y - padding)
                        bottom = max(bottom, y + padding)
                    }
                    if let stemmable = note as? StemmableNote, stemmable.hasStem() {
                        let extents = stemmable.getStemExtents()
                        top = min(top, extents.topY, extents.baseY)
                        bottom = max(bottom, extents.topY, extents.baseY)
                    }
                }
            }
        }
        return (top, bottom)
    }

    /// Justify a row horizontally, then place every measure on a shared baseline.
    private func formatRow(_ indices: [Int], _ widths: [Double], _ y: Double) throws -> SheetRow {
        let minimum = indices.reduce(0) { $0 + widths[$1] } + options.measureGap * Double(indices.count - 1)
        let extra = options.justify ? max(0, options.width - minimum) / Double(indices.count) : 0
        var x = options.x
        var top: Double = 0
        var bottom: Double = 0
        let rowSystems = indices.map { systems[$0] }
        for index in indices {
            let system = systems[index]
            try system.setX(x).setY(0).setWidthThrowing(widths[index] + extra)
            try system.formatThrowing()
            let bounds = verticalBounds(system)
            top = min(top, bounds.top)
            bottom = max(bottom, bounds.bottom)
            x += system.getWidth() + options.measureGap
        }
        for system in rowSystems {
            system.setY(y - top)
            try system.formatThrowing()
        }
        let width = x - options.x - options.measureGap
        return SheetRow(
            systems: rowSystems,
            x: options.x,
            y: y,
            width: width,
            height: bottom - top,
            overflow: max(0, width - options.width)
        )
    }
}
