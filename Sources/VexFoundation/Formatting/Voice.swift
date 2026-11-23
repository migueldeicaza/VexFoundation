// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/voice.ts` (VexFlow 5.4.0).

import Foundation

// MARK: - Voice Time

public enum VoiceTimeError: Error, LocalizedError, Equatable, Sendable {
    case nonMetricalTimeSignature(String)

    public var errorDescription: String? {
        switch self {
        case .nonMetricalTimeSignature(let raw):
            return "Voice requires a metrical time signature. Got \(raw)."
        }
    }
}

public enum VoiceError: Error, LocalizedError, Equatable, Sendable {
    case noStave
    case tooManyTicks
    case missingStave

    public var errorDescription: String? {
        switch self {
        case .noStave:
            return "No stave attached to voice."
        case .tooManyTicks:
            return "Too many ticks."
        case .missingStave:
            return "The voice cannot draw tickables without staves."
        }
    }
}

/// Time signature specification for a voice.
public struct VoiceTime {
    public var numBeats: Int
    public var beatValue: Int
    /// Defaults to `Tables.RESOLUTION` if not provided.
    public var resolution: Int

    public init(numBeats: Int = 4, beatValue: Int = 4, resolution: Int = Tables.RESOLUTION) {
        self.numBeats = numBeats
        self.beatValue = beatValue
        self.resolution = resolution
    }

    public init(timeSignature: TimeSignatureSpec, resolution: Int = Tables.RESOLUTION) throws {
        guard let meter = timeSignature.meter else {
            throw VoiceTimeError.nonMetricalTimeSignature(timeSignature.rawValue)
        }
        self.init(numBeats: meter.numerator, beatValue: meter.denominator, resolution: resolution)
    }
}

// MARK: - Voice Mode

/// Modes allow the addition of ticks in three different ways:
/// - strict: This is the default. Ticks must fill the voice.
/// - soft: Ticks can be added without restrictions.
/// - full: Ticks do not need to fill the voice, but can't exceed the maximum tick length.
public enum VoiceMode: Int, Sendable {
    case strict = 1
    case soft = 2
    case full = 3
}

// MARK: - Voice

/// `Voice` is mainly a container object to group `Tickables` for formatting.
public final class Voice: VexElement {

    override public class var category: String { "Voice" }

    public typealias Mode = VoiceMode

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
    /// Durations can change after insertion, for example when attaching tuplets.
    private var ticksDirty = false

    // MARK: - Init

    /// Reject invalid meters before they can introduce overflow or division by zero
    /// into tick arithmetic. (VexFlow 5.1.0)
    public static func validate(_ time: VoiceTime) throws {
        guard time.numBeats > 0, time.beatValue > 0, time.resolution > 0 else {
            throw VexError("BadArgument", "Meter and resolution must be positive safe integers.")
        }
        let (perBeat, _) = (time.resolution / time.beatValue, 0)
        let (total, overflow) = time.numBeats.multipliedReportingOverflow(by: perBeat)
        guard !overflow, total > 0, total <= 9_007_199_254_740_991 else {
            throw VexError("BadArgument", "Meter exceeds the supported tick range.")
        }
    }

    /// Strict parse of a time signature shortcut such as `"4/4"` or `"3/8"`. (VexFlow 5.1.0)
    public static func parseTime(_ time: String) throws -> VoiceTime {
        guard time.count <= 64,
              let regex = try? NSRegularExpression(pattern: "^(\\d+)/(\\d+)$"),
              let match = regex.firstMatch(in: time, range: NSRange(time.startIndex..., in: time)),
              let r1 = Range(match.range(at: 1), in: time),
              let r2 = Range(match.range(at: 2), in: time),
              let numBeats = Int(time[r1]),
              let beatValue = Int(time[r2])
        else {
            throw VexError("BadArgument", "Invalid time signature. Expected positive integers such as 4/4.")
        }
        let voiceTime = VoiceTime(numBeats: numBeats, beatValue: beatValue)
        try validate(voiceTime)
        return voiceTime
    }

    /// Throwing initializer: invalid meters throw, as upstream 5.1.0 does.
    public convenience init(validating time: VoiceTime) throws {
        try Voice.validate(time)
        self.init(time: time)
    }

    /// Throwing initializer from a time signature string such as `"4/4"`.
    public convenience init(parsingTime time: String) throws {
        self.init(time: try Voice.parseTime(time))
    }

    /// Default time signature is 4/4. An invalid meter (see `validate(_:)`) gives 4/4;
    /// use `init(validating:)` to get an error instead.
    public init(time: VoiceTime? = nil) {
        var t = time ?? VoiceTime()
        if (try? Voice.validate(t)) == nil { t = VoiceTime() }
        self.time = t
        // Recalculate total ticks.
        self.totalTicks = Fraction(t.numBeats * (t.resolution / t.beatValue), 1)
        // until tickables are added, the smallestTickCount is the same as the stated totalTicks duration.
        self.smallestTickCount = totalTicks.clone()
        super.init()
        self.options = (Tables.SOFTMAX_FACTOR, ())
    }

    /// Time signature shortcut: "4/4", "3/8", etc. A string that does not
    /// match `<n>/<n>` gives 4/4 (upstream 5.1.0 throws: see `init(parsingTime:)`).
    public convenience init(time: String) {
        self.init(time: (try? Voice.parseTime(time)) ?? VoiceTime())
    }

    /// Convenience init from a typed time signature.
    public convenience init(timeSignature: TimeSignatureSpec) {
        let time = (try? VoiceTime(timeSignature: timeSignature)) ?? VoiceTime()
        self.init(time: time)
    }

    /// Throwing variant for typed call sites that want explicit validation failures.
    public convenience init(validatingTimeSignature timeSignature: TimeSignatureSpec) throws {
        try self.init(time: VoiceTime(timeSignature: timeSignature))
    }

    // MARK: - Accessors

    public func getTotalTicks() -> Fraction {
        refreshTicks()
        return totalTicks
    }

    public func getTicksUsed() -> Fraction {
        refreshTicks()
        return ticksUsed
    }

    public func getLargestTickWidth() -> Double { largestTickWidth }

    public func getSmallestTickCount() -> Fraction {
        refreshTicks()
        return smallestTickCount
    }
    public func getTickables() -> [Tickable] { tickables }
    public func getMode() -> VoiceMode { mode }

    @discardableResult
    public func setMode(_ mode: VoiceMode) -> Self {
        self.mode = mode
        return self
    }

    public func getResolutionMultiplier() -> Int {
        refreshTicks()
        return resolutionMultiplier
    }

    public func getActualResolution() -> Int {
        getResolutionMultiplier() * time.resolution
    }

    // MARK: - Stave

    @discardableResult
    public func setStave(_ stave: Stave) -> Self {
        voiceStave = stave
        return self
    }

    public func getStave() -> Stave? { voiceStave }

    /// Get the bounding box for the voice.
    override public func getBoundingBox() -> BoundingBox? {
        guard let first = tickables.first else { return nil }
        var boundingBox = first.getBoundingBox()
        for tickable in tickables.dropFirst() {
            if tickable.getStave() == nil, let stave = voiceStave { tickable.setStave(stave) }
            if let bb = tickable.getBoundingBox() {
                if boundingBox == nil {
                    boundingBox = bb
                } else {
                    boundingBox?.mergeWith(bb)
                }
            }
        }
        return boundingBox
    }

    public func checkStave() throws -> Stave {
        guard let voiceStave else {
            throw VoiceError.noStave
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
        refreshTicks()
        if mode == .strict || mode == .full {
            return ticksUsed.equals(totalTicks)
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
        refreshTicks()
        let expTicks = expTicksUsed ?? reCalculateExpTicksUsed()
        let total = ticksUsed.value()
        return pow(options.softmaxFactor, tickValue / total) / expTicks
    }

    // MARK: - Tick invalidation (VexFlow 5.1.0)

    /// Invalidate cached duration totals when a member's duration changes.
    public func invalidateTicks() {
        ticksDirty = true
        expTicksUsed = nil
    }

    /// Recount once after a batch of duration edits; avoid partial-tuplet validation.
    private func refreshTicks() {
        guard ticksDirty else { return }
        ticksUsed.set(0, 1)
        totalTicks.set(time.numBeats * (time.resolution / time.beatValue), 1)
        smallestTickCount = totalTicks.clone()
        for tickable in tickables {
            if tickable.shouldIgnoreTicks() { continue }
            let ticks = tickable.getTicks()
            ticksUsed.add(ticks)
            if ticks.lessThan(smallestTickCount) { smallestTickCount = ticks.clone() }
        }
        resolutionMultiplier = ticksUsed.denominator
        totalTicks.add(0, resolutionMultiplier)
        ticksDirty = false
    }

    // MARK: - Add Tickables

    @discardableResult
    public func addTickable(_ tickable: Tickable) -> Self {
        do {
            return try addTickableThrowing(tickable)
        } catch {
            return self
        }
    }

    @discardableResult
    public func addTickableThrowing(_ tickable: Tickable) throws -> Self {
        refreshTicks()
        if !tickable.shouldIgnoreTicks() {
            let ticks = tickable.getTicks()
            ticksUsed.add(ticks)
            expTicksUsed = nil

            if (mode == .strict || mode == .full) && ticksUsed.greaterThan(totalTicks) {
                ticksUsed.subtract(ticks)
                throw VoiceError.tooManyTicks
            }

            if ticks.lessThan(smallestTickCount) {
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
        do {
            return try addTickablesThrowing(tickables)
        } catch {
            return self
        }
    }

    @discardableResult
    public func addTickablesThrowing(_ tickables: [Tickable]) throws -> Self {
        for t in tickables { _ = try addTickableThrowing(t) }
        return self
    }

    // MARK: - PreFormat

    @discardableResult
    public func preFormat() -> Self {
        do {
            return try preFormatThrowing()
        } catch {
            return self
        }
    }

    @discardableResult
    public func preFormatThrowing() throws -> Self {
        if voicePreFormatted { return self }
        let stave = try checkStave()
        for tickable in tickables {
            if tickable.getStave() == nil {
                tickable.setStave(stave)
            }
        }
        voicePreFormatted = true
        return self
    }

    // MARK: - Draw

    /// Preserve per-event cross-staff assignments when drawing a continuous score. (VexFlow 5.4.0)
    public var preserveStaveAssignments = false

    override public func draw() throws {
        try draw(context: nil, stave: nil)
    }

    /// Render the voice onto the canvas `context` and an optional `stave`.
    /// If `stave` is omitted, it is expected that the notes have staves
    /// already set.
    public func draw(context: RenderContext?, stave: Stave? = nil) throws {
        let ctx = try context ?? checkContext()
        let override = stave ?? (preserveStaveAssignments ? nil : voiceStave)
        setRendered()
        for tickable in tickables {
            // Set the stave if provided.
            if let override {
                tickable.setStave(override)
            } else if preserveStaveAssignments, tickable.getStave() == nil, let voiceStave {
                tickable.setStave(voiceStave)
            }
            guard tickable.getStave() != nil else {
                throw VoiceError.missingStave
            }

            tickable.setContext(ctx)
            try tickable.drawWithStyle()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Voice", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        _ = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/q, D5, E5, F5"))]
        )).addClef(.treble).addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
