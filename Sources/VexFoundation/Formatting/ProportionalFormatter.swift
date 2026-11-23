// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/proportionalformatter.ts` (VexFlow 5.2.0).
// Strict musical-time placement, with measured bounds and separate zero-time prefixes.

import Foundation

/// Equal durations occupy equal horizontal distances. (VexFlow 5.2.0)
public struct ProportionalSpacing: Sendable, Equatable {
    /// Omit to fit the available width, or choose the minimum scale when no width is supplied.
    public var pixelsPerQuarter: Double?

    public init(pixelsPerQuarter: Double? = nil) {
        self.pixelsPerQuarter = pixelsPerQuarter
    }

    /// Upstream `{ mode: 'proportional', pixelsPerQuarter }`.
    public static func proportional(pixelsPerQuarter: Double? = nil) -> ProportionalSpacing {
        ProportionalSpacing(pixelsPerQuarter: pixelsPerQuarter)
    }
}

/// Build a common rational timeline without advancing time for clefs or barlines.
final class ProportionalFormatter {
    /// One voice's non-rhythmic objects immediately before an anchor.
    private struct Prefix {
        var contexts: [TickContext] = []
    }

    /// Measured extents on one stave, relative to the rhythmic anchor.
    private struct Extent {
        var left: Double = 0
        var right: Double = 0
    }

    /// Notes at one musical time, plus independently positioned inline objects.
    private final class Anchor {
        let tick: Int
        let context: TickContext
        /// Indexed by voice. `nil` when a voice has no prefix at this anchor.
        var prefixes: [Prefix?] = []
        /// Insertion-ordered extents keyed by stave.
        var extentKeys: [ObjectIdentifier?] = []
        var extents: [ObjectIdentifier?: Extent] = [:]

        init(tick: Int) {
            self.tick = tick
            self.context = TickContext(tickID: tick)
        }

        func setExtent(_ key: ObjectIdentifier?, _ extent: Extent) {
            if extents[key] == nil { extentKeys.append(key) }
            extents[key] = extent
        }

        func clearExtents() {
            extentKeys = []
            extents = [:]
        }
    }

    /// Pixel allowance between measured boxes, including the two outer boundaries.
    private static let PADDING: Double = 2
    /// Ignore floating-point noise when comparing computed pixel widths.
    private static let EPSILON: Double = 1e-7

    let contexts: AlignmentContexts
    private let anchors: [Anchor]
    private let quarterTicks: Double
    private let duration: Double
    private var origin: Double = 0
    private var tail: Double = PADDING
    private var minimumScale: Double = 0
    private var centeredWidth: Double = 0

    /// Round required dimensions up so copying an error's suggestion is sufficient.
    private static func required(_ value: Double) -> String {
        String(format: "%.2f", (value * 100).rounded(.up) / 100)
    }

    private static func staveKey(_ tickable: Tickable) -> ObjectIdentifier? {
        tickable.getStave().map { ObjectIdentifier($0) }
    }

    /// LCM that reports an overflow instead of trapping.
    private static func safeLCM(_ a: Int, _ b: Int) -> Int? {
        guard a > 0, b > 0 else { return nil }
        var x = a, y = b
        while y != 0 { (x, y) = (y, x % y) }
        let (product, overflow) = (a / x).multipliedReportingOverflow(by: b)
        return overflow ? nil : product
    }

    init(voices: [Voice], resolutionMultiplier initialMultiplier: Int) throws {
        guard let first = voices.first else { throw VexError("BadArgument", "No voices to format") }
        let resolution = Double(first.getActualResolution()) / Double(first.getResolutionMultiplier())
        quarterTicks = resolution / 4
        var durationTicks = first.getTotalTicks().value()
        var resolutionMultiplier: Int? = initialMultiplier
        // Inspect every duration, not only the final voice total. Tuplet denominators can cancel.
        for voice in voices {
            if Double(voice.getActualResolution()) / Double(voice.getResolutionMultiplier()) != resolution {
                throw VexError("BadArgument", "Proportional voices must use the same tick resolution.")
            }
            durationTicks = max(durationTicks, voice.getTicksUsed().value())
            for note in voice.getTickables() {
                if note.shouldIgnoreTicks() { continue }
                let ticks = note.getTicks()
                if ticks.value() <= 0 { throw VexError("BadArgument", "Rhythmic durations must be positive.") }
                resolutionMultiplier = resolutionMultiplier.flatMap { Self.safeLCM($0, ticks.denominator) }
            }
        }
        guard let resolutionMultiplier, resolutionMultiplier > 0, resolutionMultiplier <= (1 << 53) else {
            throw VexError("BadArgument", "Proportional timeline exceeds the supported rational tick range.")
        }
        duration = durationTicks / quarterTicks
        var byTick: [Int: Anchor] = [:]
        for (voiceIndex, voice) in voices.enumerated() {
            let elapsed = Fraction(0, resolutionMultiplier)
            for note in voice.getTickables() {
                let tick = elapsed.numerator
                if abs(tick) > (1 << 53) {
                    throw VexError("BadArgument", "Proportional timeline exceeds the supported rational tick range.")
                }
                let anchor: Anchor
                if let existing = byTick[tick] {
                    anchor = existing
                } else {
                    anchor = Anchor(tick: tick)
                    byTick[tick] = anchor
                }
                if note.shouldIgnoreTicks() {
                    // Each voice retains its inline sequence. Different voices may share the same time.
                    while anchor.prefixes.count <= voiceIndex { anchor.prefixes.append(nil) }
                    var prefix = anchor.prefixes[voiceIndex] ?? Prefix()
                    prefix.contexts.append(TickContext(tickID: tick).addTickable(note, voiceIndex: voiceIndex))
                    anchor.prefixes[voiceIndex] = prefix
                } else {
                    _ = anchor.context.addTickable(note, voiceIndex: voiceIndex)
                    elapsed.add(note.getTicks())
                }
            }
        }
        anchors = byTick.values.sorted { $0.tick < $1.tick }
        var map: [Int: TickContext] = [:]
        var array: [TickContext] = []
        for anchor in anchors {
            map[anchor.tick] = anchor.context
            for prefix in anchor.prefixes.compactMap({ $0 }) { array.append(contentsOf: prefix.contexts) }
            array.append(anchor.context)
        }
        for context in array { context.tContexts = array }
        contexts = AlignmentContexts(
            list: anchors.map { $0.tick }, map: map, array: array, resolutionMultiplier: resolutionMultiplier
        )
    }

    /// Convert an exact timeline key once, at the point where pixels are needed.
    private func quarters(_ anchor: Anchor) -> Double {
        Double(anchor.tick) / Double(contexts.resolutionMultiplier) / quarterTicks
    }

    /// Measure each stave independently so unrelated onsets on other staves do not compete.
    private func measure() {
        let padding = Self.PADDING
        origin = padding
        tail = padding
        minimumScale = 0
        centeredWidth = 0
        for anchor in anchors {
            anchor.clearExtents()
            _ = anchor.context.preFormat()
            for note in anchor.context.getTickables() {
                let metrics = note.getMetrics()
                let left = metrics.modLeftPx + metrics.leftDisplacedHeadPx
                let right = metrics.notePx + metrics.modRightPx + metrics.rightDisplacedHeadPx
                if note.isCenterAligned() {
                    centeredWidth = max(centeredWidth, 2 * max(left, right))
                    continue
                }
                let key = Self.staveKey(note)
                var extent = anchor.extents[key] ?? Extent()
                extent.left = max(extent.left, left)
                extent.right = max(extent.right, right)
                anchor.setExtent(key, extent)
            }
            // Prefix widths are measured before placement. Keep the largest sequence on each stave.
            var prefixKeys: [ObjectIdentifier?] = []
            var prefixWidths: [ObjectIdentifier?: Double] = [:]
            for prefix in anchor.prefixes.compactMap({ $0 }) {
                var width: Double = 0
                for context in prefix.contexts { width += context.preFormat().getWidth() }
                let key = prefix.contexts.first?.getTickables().first.flatMap { Self.staveKey($0) }
                if prefixWidths[key] == nil { prefixKeys.append(key) }
                prefixWidths[key] = max(prefixWidths[key] ?? 0, width)
            }
            for key in prefixKeys {
                var extent = anchor.extents[key] ?? Extent()
                extent.left += prefixWidths[key] ?? 0
                anchor.setExtent(key, extent)
            }
            for key in anchor.extentKeys {
                guard let extent = anchor.extents[key] else { continue }
                if quarters(anchor) == 0 { origin = max(origin, extent.left + padding) }
                if quarters(anchor) == duration { tail = max(tail, extent.right + padding) }
            }
        }
        // All pairs also cover a wide earlier object extending past an intervening narrow one.
        var previous: [ObjectIdentifier?: [(time: Double, extent: Extent)]] = [:]
        for anchor in anchors {
            let time = quarters(anchor)
            for key in anchor.extentKeys {
                guard let extent = anchor.extents[key] else { continue }
                for before in previous[key] ?? [] {
                    minimumScale = max(minimumScale, (before.extent.right + extent.left + padding) / (time - before.time))
                }
                if time > 0 { minimumScale = max(minimumScale, (extent.left + padding - origin) / time) }
                if time < duration {
                    minimumScale = max(minimumScale, (extent.right + padding - tail) / (duration - time))
                }
                previous[key, default: []].append((time, extent))
            }
        }
        minimumScale = max(minimumScale, centeredWidth / duration)
    }

    /// Compute one scale and validate it before changing any anchor positions.
    private func dimensions(_ spacing: ProportionalSpacing, _ width: Double) throws -> (scale: Double, width: Double) {
        if !width.isFinite || width < 0 {
            throw VexError("BadArgument", "Width must be finite and nonnegative.")
        }
        let requested = spacing.pixelsPerQuarter
        if let requested, !requested.isFinite || requested <= 0 {
            throw VexError("BadArgument", "pixelsPerQuarter must be positive and finite.")
        }
        measure()
        let minimumWidth = origin + duration * minimumScale + tail
        let scale = requested ?? (width > 0 ? (width - origin - tail) / duration : minimumScale)
        let neededWidth = origin + duration * scale + tail
        if !neededWidth.isFinite || !minimumScale.isFinite {
            throw VexError("BadArgument", "Proportional dimensions exceed the supported pixel range.")
        }
        if scale + Self.EPSILON < minimumScale || (width > 0 && width + Self.EPSILON < neededWidth) {
            throw VexError(
                "InsufficientProportionalSpace",
                "Proportional spacing requires at least \(Self.required(minimumScale)) px/quarter and "
                    + "\(Self.required(max(minimumWidth, neededWidth))) px width; received "
                    + String(format: "%.2f", scale) + " px/quarter"
                    + (width > 0 ? " and " + String(format: "%.2f", width) + " px width." : ".")
            )
        }
        return (scale, neededWidth)
    }

    /// Minimum total width for autoWidth, honoring a supplied exact scale.
    func minimumWidth(_ spacing: ProportionalSpacing) throws -> Double {
        try dimensions(spacing, 0).width
    }

    /// Place anchors and prefixes, retaining the established centering exception for measure rests.
    func format(_ spacing: ProportionalSpacing, _ width: Double) throws -> Double {
        let dimensions = try dimensions(spacing, width)
        for anchor in anchors {
            let x = origin + quarters(anchor) * dimensions.scale
            _ = anchor.context.setX(x)
            for note in anchor.context.getCenterAlignedTickables() {
                _ = note.setCenterXShift(origin + (duration * dimensions.scale) / 2 - x)
            }
            for prefix in anchor.prefixes.compactMap({ $0 }) {
                // Right-align each sequence just before the rhythmic note's left modifiers.
                let key = prefix.contexts.first?.getTickables().first.flatMap { Self.staveKey($0) }
                let notes = anchor.context.getTickables().filter { Self.staveKey($0) == key }
                var right = x - max(0, notes.map { note -> Double in
                    let metrics = note.getMetrics()
                    return metrics.modLeftPx + metrics.leftDisplacedHeadPx
                }.max() ?? 0)
                for context in prefix.contexts.reversed() {
                    let metrics = context.getMetrics()
                    _ = context.setX(right - Self.PADDING / 2 - metrics.notePx - metrics.totalRightPx)
                    right -= context.getWidth()
                }
            }
        }
        return dimensions.width
    }
}
