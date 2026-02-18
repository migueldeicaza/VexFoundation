// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Voice Time

/// Time signature specification for a voice.
public struct VoiceTime {
    public var numBeats: Int
    public var beatValue: Int
    public var resolution: Int

    public init(numBeats: Int = 4, beatValue: Int = 4, resolution: Int = Tables.RESOLUTION) {
        self.numBeats = numBeats
        self.beatValue = beatValue
        self.resolution = resolution
    }
}

// MARK: - Voice Mode

/// Modes for tick validation within a voice.
public enum VoiceMode: Int {
    case strict = 1
    case soft = 2
    case full = 3
}

// MARK: - Voice

/// Container object to group Tickables for formatting.
public final class Voice: VexElement {

    override public class var CATEGORY: String { "Voice" }

    // MARK: - Properties

    public var resolutionMultiplier: Int = 1
    public var smallestTickCount: Fraction
    public weak var voiceStave: Stave?
    public var mode: VoiceMode = .strict
    public var expTicksUsed: Double?
    public var voicePreFormatted: Bool = false
    public var options: (softmaxFactor: Double, Void) = (Tables.SOFTMAX_FACTOR, ())

    public let totalTicks: Fraction
    public let ticksUsed: Fraction = Fraction(0, 1)
    public private(set) var largestTickWidth: Double = 0
    public private(set) var tickables: [Tickable] = []
    public let time: VoiceTime

    // MARK: - Init

    public init(time: VoiceTime? = nil) {
        let t = time ?? VoiceTime()
        self.time = t
        self.totalTicks = Fraction(t.numBeats * (t.resolution / t.beatValue), 1)
        self.smallestTickCount = totalTicks.clone()
        super.init()
    }

    /// Convenience init from a time signature string like "4/4".
    public convenience init(timeSpec: String) {
        let parts = timeSpec.split(separator: "/")
        if parts.count == 2, let num = Int(parts[0]), let beat = Int(parts[1]) {
            self.init(time: VoiceTime(numBeats: num, beatValue: beat))
        } else {
            self.init()
        }
    }

    // MARK: - Accessors

    public func getTotalTicks() -> Fraction { totalTicks }
    public func getTicksUsed() -> Fraction { ticksUsed }
    public func getLargestTickWidth() -> Double { largestTickWidth }
    public func getSmallestTickCount() -> Fraction { smallestTickCount }
    public func getTickables() -> [Tickable] { tickables }
    public func getMode() -> VoiceMode { mode }

    @discardableResult
    public func setMode(_ mode: VoiceMode) -> Self {
        self.mode = mode
        return self
    }

    public func getResolutionMultiplier() -> Int { resolutionMultiplier }

    public func getActualResolution() -> Int {
        resolutionMultiplier * time.resolution
    }

    // MARK: - Stave

    @discardableResult
    public func setStave(_ stave: Stave) -> Self {
        voiceStave = stave
        boundingBox = nil
        return self
    }

    public func getStave() -> Stave? { voiceStave }

    public func checkStave() -> Stave {
        guard let voiceStave else {
            fatalError("[VexError] NoStave: No stave attached to instance.")
        }
        return voiceStave
    }

    // MARK: - Strict / Complete

    @discardableResult
    public func setStrict(_ strict: Bool) -> Self {
        mode = strict ? .strict : .soft
        return self
    }

    public func isComplete() -> Bool {
        if mode == .strict || mode == .full {
            return ticksUsed == totalTicks
        }
        return true
    }

    // MARK: - Softmax

    @discardableResult
    public func setSoftmaxFactor(_ factor: Double) -> Self {
        options.softmaxFactor = factor
        expTicksUsed = nil
        return self
    }

    private func reCalculateExpTicksUsed() -> Double {
        let total = ticksUsed.value()
        let result = tickables.reduce(0.0) { sum, tickable in
            sum + pow(options.softmaxFactor, tickable.getTicks().value() / total)
        }
        expTicksUsed = result
        return result
    }

    public func softmax(_ tickValue: Double) -> Double {
        let expTicks = expTicksUsed ?? reCalculateExpTicksUsed()
        let total = ticksUsed.value()
        return pow(options.softmaxFactor, tickValue / total) / expTicks
    }

    // MARK: - Add Tickables

    @discardableResult
    public func addTickable(_ tickable: Tickable) -> Self {
        if !tickable.shouldIgnoreTicks() {
            let ticks = tickable.getTicks()
            ticksUsed.add(ticks)
            expTicksUsed = nil

            if (mode == .strict || mode == .full) && ticksUsed > totalTicks {
                ticksUsed.subtract(ticks)
                fatalError("[VexError] BadArgument: Too many ticks.")
            }

            if ticks < smallestTickCount {
                smallestTickCount = ticks.clone()
            }

            resolutionMultiplier = ticksUsed.denominator
            totalTicks.add(0, ticksUsed.denominator)
        }

        tickables.append(tickable)
        tickable.setVoice(self)
        return self
    }

    @discardableResult
    public func addTickables(_ tickables: [Tickable]) -> Self {
        for t in tickables { _ = addTickable(t) }
        return self
    }

    // MARK: - PreFormat

    @discardableResult
    public func preFormat() -> Self {
        if voicePreFormatted { return self }
        let stave = checkStave()
        for tickable in tickables {
            if tickable.getStave() == nil {
                tickable.setStave(stave)
            }
        }
        voicePreFormatted = true
        return self
    }

    // MARK: - Draw

    public func draw(context: RenderContext? = nil, stave: Stave? = nil) throws {
        let ctx = try context ?? checkContext()
        let drawStave = stave ?? voiceStave
        setRendered()

        var bb: BoundingBox?
        for tickable in tickables {
            if let s = drawStave {
                tickable.setStave(s)
            }
            if let tbb = tickable.getBoundingBox() {
                if bb != nil {
                    bb!.mergeWith(tbb)
                } else {
                    bb = tbb
                }
            }
            tickable.setContext(ctx)
            try tickable.drawWithStyle()
        }
        boundingBox = bb
    }
}
