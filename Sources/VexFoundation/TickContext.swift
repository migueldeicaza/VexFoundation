// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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

// MARK: - TickContext

/// Formats abstract tickable objects at a specific tick position.
/// Groups notes, tabs, chords, etc. that occur at the same time.
public final class TickContext {

    // MARK: - Static

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

    public var preFormatted: Bool = false
    public var postFormatted: Bool = false
    public var width: Double = 0
    public var formatterMetrics: (freedom: (left: Double, right: Double), Void) = ((0, 0), ())

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

    public func getTickableForVoice(_ voiceIndex: Int) -> Tickable? {
        tickablesByVoice[voiceIndex]
    }

    public func getTickablesByVoice() -> [Int: Tickable] { tickablesByVoice }

    public func getCenterAlignedTickables() -> [Tickable] {
        tickables.filter { $0.isCenterAligned() }
    }

    // MARK: - Metrics

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

            if ticks > maxTicks {
                maxTicks = ticks.clone()
                maxTickable = tickable
            }

            if minTicks == nil {
                minTicks = ticks.clone()
                minTickable = tickable
            } else if ticks < minTicks! {
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

            leftDisplacedHeadPx = max(leftDisplacedHeadPx, metrics.leftDisplacedHeadPx)
            rightDisplacedHeadPx = max(rightDisplacedHeadPx, metrics.rightDisplacedHeadPx)
            notePx = max(notePx, metrics.notePx)
            glyphPx = max(glyphPx, metrics.glyphWidth ?? 0)
            modLeftPx = max(modLeftPx, metrics.modLeftPx)
            modRightPx = max(modRightPx, metrics.modRightPx)
            totalLeftPx = max(totalLeftPx, metrics.modLeftPx + metrics.leftDisplacedHeadPx)
            totalRightPx = max(totalRightPx, metrics.modRightPx + metrics.rightDisplacedHeadPx)

            width = notePx + totalLeftPx + totalRightPx
        }

        preFormatted = true
        return self
    }

    // MARK: - PostFormat

    @discardableResult
    public func postFormat() -> Self {
        if postFormatted { return self }
        postFormatted = true
        return self
    }

    public func getFormatterMetrics() -> (freedom: (left: Double, right: Double), Void) {
        formatterMetrics
    }
}
