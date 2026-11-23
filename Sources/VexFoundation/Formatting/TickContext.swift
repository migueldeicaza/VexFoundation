// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tickcontext.ts` (VexFlow 5.3.0).
// A formatter for abstract tickable objects, such as notes, chords,
// tabs, etc.

import Foundation

// MARK: - TickContext Metrics

/// Metrics returned by TickContext for formatting.
public struct TickContextMetrics {
    public var width: Double = 0
    public var glyphPx: Double = 0
    public var notePx: Double = 0
    public var leftDisplacedHeadPx: Double = 0
    public var rightDisplacedHeadPx: Double = 0
    public var modLeftPx: Double = 0
    public var modRightPx: Double = 0
    public var totalLeftPx: Double = 0
    public var totalRightPx: Double = 0
}

/// Formatter metrics of a `TickContext`. A reference type, so that formatters
/// can change `getFormatterMetrics().freedom` in place, as upstream does.
public final class TickContextFormatterMetrics {
    /// The freedom of a tickcontext is the distance it can move without colliding
    /// with neighboring elements. A formatter can set these values during its
    /// formatting pass, which a different formatter can then use to fine tune.
    public var freedom: (left: Double, right: Double) = (0, 0)

    public init() {}
}

// MARK: - TickContext

/// TickContext formats abstract tickable objects, such as notes, chords, tabs, etc.
///
/// It has a public attribute of `tContexts` which is a parent array of the TickContexts
/// in which this TickContext belongs.
public final class TickContext {

    // MARK: - Static

    /// Get the next TickContext from another TickContext, from the `.tContexts` array.
    public static func getNextContext(_ tContext: TickContext) -> TickContext? {
        let contexts = tContext.tContexts
        guard let index = contexts.firstIndex(where: { $0 === tContext }) else { return nil }
        let next = index + 1
        return next < contexts.count ? contexts[next] : nil
    }

    // MARK: - Properties

    public let tickID: Int
    public var tickables: [Tickable] = []
    public var tickablesByVoice: [Int: Tickable] = [:]
    public var currentTick: Fraction = Fraction(0, 1)
    public var maxTicks: Fraction = Fraction(0, 1)
    public var padding: Double = 1
    public var xBase: Double = 0
    public var x: Double = 0
    public var xOffset: Double = 0
    public var notePx: Double = 0
    public var glyphPx: Double = 0
    public var leftDisplacedHeadPx: Double = 0
    public var rightDisplacedHeadPx: Double = 0
    public var modLeftPx: Double = 0
    public var modRightPx: Double = 0
    public var totalLeftPx: Double = 0
    public var totalRightPx: Double = 0
    public var maxTickable: Tickable?
    public var minTicks: Fraction?
    public var minTickable: Tickable?
    public var tContexts: [TickContext] = []
    /// Next attack in musical order (VexFlow 5.3.0). Weak, so the timeline does not retain itself.
    private weak var nextAttack: TickContext?

    /// Link musical order independently of the legacy per-voice insertion order. (VexFlow 5.3.0)
    public static func linkTimeline(_ contexts: [TickContext]) {
        for (i, context) in contexts.enumerated() {
            context.nextAttack = i + 1 < contexts.count ? contexts[i + 1] : nil
        }
    }

    /// Visit only the attacks inside this beam, including interleaved voices. (VexFlow 5.3.0)
    public func through(_ last: TickContext) -> [TickContext] {
        if tickID > last.tickID { return [] }
        var result: [TickContext] = [self]
        if self === last { return result }
        var context = nextAttack
        while let current = context, current.tickID <= last.tickID {
            result.append(current)
            if current === last { return result }
            context = current.nextAttack
        }
        return result
    }

    public var preFormatted: Bool = false
    public var postFormatted: Bool = false
    public var width: Double = 0
    public var formatterMetrics = TickContextFormatterMetrics()

    // MARK: - Init

    public init(tickID: Int = 0) {
        self.tickID = tickID
    }

    // MARK: - X Position

    public func getTickID() -> Int { tickID }

    public func getX() -> Double { x }

    @discardableResult
    public func setX(_ x: Double) -> Self {
        self.x = x
        self.xBase = x
        self.xOffset = 0
        return self
    }

    public func getXBase() -> Double { xBase }

    public func setXBase(_ xBase: Double) {
        self.xBase = xBase
        self.x = xBase + xOffset
    }

    public func getXOffset() -> Double { xOffset }

    public func setXOffset(_ xOffset: Double) {
        self.xOffset = xOffset
        self.x = xBase + xOffset
    }

    // MARK: - Width / Padding

    public func getWidth() -> Double { width + padding * 2 }

    @discardableResult
    public func setPadding(_ padding: Double) -> Self {
        self.padding = padding
        return self
    }

    // MARK: - Ticks

    public func getMaxTicks() -> Fraction { maxTicks }
    public func getMinTicks() -> Fraction? { minTicks }
    public func getMaxTickable() -> Tickable? { maxTickable }
    public func getMinTickable() -> Tickable? { minTickable }
    public func getTickables() -> [Tickable] { tickables }

    /// Return the tickable of voice `voiceIndex`.
    public func getTickableForVoice(_ voiceIndex: Int) -> Tickable? {
        tickablesByVoice[voiceIndex]
    }

    public func getTickablesByVoice() -> [Int: Tickable] { tickablesByVoice }

    public func getCenterAlignedTickables() -> [Tickable] {
        tickables.filter { $0.isCenterAligned() }
    }

    // MARK: - Metrics

    /// Gets widths context, note and left/right modifiers for formatting.
    public func getMetrics() -> TickContextMetrics {
        TickContextMetrics(
            width: width, glyphPx: glyphPx, notePx: notePx,
            leftDisplacedHeadPx: leftDisplacedHeadPx,
            rightDisplacedHeadPx: rightDisplacedHeadPx,
            modLeftPx: modLeftPx, modRightPx: modRightPx,
            totalLeftPx: totalLeftPx, totalRightPx: totalRightPx
        )
    }

    // MARK: - Current Tick

    public func getCurrentTick() -> Fraction { currentTick }

    public func setCurrentTick(_ tick: Fraction) {
        currentTick = tick
        preFormatted = false
    }

    // MARK: - Add Tickable

    @discardableResult
    public func addTickable(_ tickable: Tickable, voiceIndex: Int = 0) -> Self {
        if !tickable.shouldIgnoreTicks() {
            let ticks = tickable.getTicks()

            if ticks.greaterThan(maxTicks) {
                maxTicks = ticks.clone()
                maxTickable = tickable
            }

            if minTicks == nil {
                minTicks = ticks.clone()
                minTickable = tickable
            } else if let currentMin = minTicks, ticks.lessThan(currentMin) {
                minTicks = ticks.clone()
                minTickable = tickable
            }
        }

        tickable.setTickContext(self)
        tickables.append(tickable)
        tickablesByVoice[voiceIndex] = tickable
        preFormatted = false
        return self
    }

    // MARK: - PreFormat

    @discardableResult
    public func preFormat() -> Self {
        if preFormatted { return self }

        for tickable in tickables {
            tickable.preFormat()
            let metrics = tickable.getMetrics()

            // Maintain max displaced head pixels from all tickables in the context
            leftDisplacedHeadPx = max(leftDisplacedHeadPx, metrics.leftDisplacedHeadPx)
            rightDisplacedHeadPx = max(rightDisplacedHeadPx, metrics.rightDisplacedHeadPx)
            notePx = max(notePx, metrics.notePx)
            glyphPx = max(glyphPx, metrics.glyphWidth ?? 0)
            modLeftPx = max(modLeftPx, metrics.modLeftPx)
            modRightPx = max(modRightPx, metrics.modRightPx)
            totalLeftPx = max(totalLeftPx, metrics.modLeftPx + metrics.leftDisplacedHeadPx)
            totalRightPx = max(totalRightPx, metrics.modRightPx + metrics.rightDisplacedHeadPx)

            // Recalculate the tick context total width
            width = notePx + totalLeftPx + totalRightPx
        }

        return self
    }

    // MARK: - PostFormat

    @discardableResult
    public func postFormat() -> Self {
        if postFormatted { return self }
        postFormatted = true
        return self
    }

    public func getFormatterMetrics() -> TickContextFormatterMetrics {
        formatterMetrics
    }

    /// Move this tick context by `shift` pixels rightward, and adjust the
    /// freedom on adjacent tickcontexts.
    /// - Parameters:
    ///   - shift: pixels to shift rightward.
    ///   - prev: the previous TickContext, whose right freedom will be increased by `shift`.
    ///   - next: the next TickContext, whose left freedom will be decreased by `shift`.
    public func move(_ shift: Double, _ prev: TickContext? = nil, _ next: TickContext? = nil) {
        setX(getX() + shift)
        getFormatterMetrics().freedom.left += shift
        getFormatterMetrics().freedom.right -= shift

        if let prev { prev.getFormatterMetrics().freedom.right += shift }
        if let next { next.getFormatterMetrics().freedom.left -= shift }
    }

    /// Return the total cost of space deviations from formatter metrics for
    /// each tickable in the context. Used by formatters.
    ///
    /// Since `FormatterMetrics.space.deviation` is the amount each tickable is smaller
    /// (negative) or wider (positive) than the mean amount of space allocated to that
    /// duration, a negative return value means the tickables at this position are on average
    /// getting less space than they should, while a positive number means they are getting
    /// more space than they should.
    public func getDeviationCost() -> Double {
        sumArray(tickables.map { $0.getFormatterMetrics().space.deviation })
    }

    /// Like getDeviationCost, but averages the cost of space deviations so that TickContexts
    /// with more Tickables are not weighted more heavily.
    public func getAverageDeviationCost() -> Double {
        if tickables.isEmpty { return 0 }
        return getDeviationCost() / Double(tickables.count)
    }
}
