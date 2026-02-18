// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Formatter Options

/// Options for the Formatter layout engine.
public struct FormatterOptions {
    public var softmaxFactor: Double = Tables.SOFTMAX_FACTOR
    public var globalSoftmax: Bool = false
    public var maxIterations: Int = 5

    public init(softmaxFactor: Double = Tables.SOFTMAX_FACTOR,
                globalSoftmax: Bool = false,
                maxIterations: Int = 5) {
        self.softmaxFactor = softmaxFactor
        self.globalSoftmax = globalSoftmax
        self.maxIterations = maxIterations
    }
}

/// Parameters for format operations.
public struct FormatParams {
    public var alignRests: Bool = false
    public var stave: Stave?
    public var context: RenderContext?
    public var autoBeam: Bool = false

    public init(alignRests: Bool = false, stave: Stave? = nil,
                context: RenderContext? = nil, autoBeam: Bool = false) {
        self.alignRests = alignRests
        self.stave = stave
        self.context = context
        self.autoBeam = autoBeam
    }
}

// MARK: - Alignment Contexts

/// Tick-aligned context mapping for formatting.
public struct AlignmentContexts {
    public var list: [Int] = []
    public var map: [Int: TickContext] = [:]
    public var array: [TickContext] = []
    public var resolutionMultiplier: Int = 0
}

// MARK: - Formatter

/// The layout engine that positions notes horizontally on a stave.
/// Breaks up voices into a grid of rational-valued ticks,
/// assigns minimum widths, and distributes space using softmax.
public final class Formatter {

    // MARK: - Properties

    public var hasMinTotalWidth: Bool = false
    public var minTotalWidth: Double = 0
    public var justifyWidth: Double = 0
    public var totalCost: Double = 0
    public var totalShift: Double = 0
    public var tickContexts = AlignmentContexts()
    public var formatterOptions: FormatterOptions
    public var voices: [Voice] = []
    public var lossHistory: [Double] = []
    public var contextGaps: (total: Double, gaps: [(x1: Double, x2: Double)]) = (0, [])

    // MARK: - Init

    public init(options: FormatterOptions = FormatterOptions()) {
        self.formatterOptions = options
    }

    // MARK: - Static: SimpleFormat

    /// Layout notes sequentially without proportional spacing.
    /// Useful for tests and debugging.
    public static func SimpleFormat(_ notes: [Tickable], x: Double = 0, paddingBetween: Double = 10) {
        var accumulator = x
        for note in notes {
            _ = note.addToModifierContext(ModifierContext())
            let tick = TickContext().addTickable(note).preFormat()
            let metrics = tick.getMetrics()
            tick.setX(accumulator + metrics.totalLeftPx)
            accumulator += tick.getWidth() + metrics.totalRightPx + paddingBetween
        }
    }

    // MARK: - Static: FormatAndDraw

    /// Format and draw a single voice. Returns a bounding box.
    @discardableResult
    public static func FormatAndDraw(
        ctx: RenderContext,
        stave: Stave,
        notes: [StemmableNote],
        params: FormatParams = FormatParams()
    ) throws -> BoundingBox? {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = voice.setMode(.soft)
        _ = voice.addTickables(notes)

        let formatter = Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.formatToStave([voice], stave: stave, options: params)

        try voice.draw(context: ctx, stave: stave)
        return voice.boundingBox
    }

    // MARK: - Static: Resolution Multiplier

    /// Calculate the resolution multiplier for voices.
    public static func getResolutionMultiplier(_ voices: [Voice]) -> Int {
        guard !voices.isEmpty else {
            fatalError("[VexError] BadArgument: No voices to format.")
        }

        let totalTicks = voices[0].getTotalTicks()
        var resolutionMultiplier = 1
        for voice in voices {
            guard voice.getTotalTicks() == totalTicks else {
                fatalError("[VexError] TickMismatch: Voices should have same total note duration in ticks.")
            }
            if voice.getMode() == .strict && !voice.isComplete() {
                fatalError("[VexError] IncompleteVoice: Voice does not have enough notes.")
            }
            resolutionMultiplier = Fraction.lcm(resolutionMultiplier, voice.getResolutionMultiplier())
        }
        return resolutionMultiplier
    }

    // MARK: - Join Voices

    /// Create modifier contexts for voices. Must be called before format().
    @discardableResult
    public func joinVoices(_ voices: [Voice]) -> Self {
        createModifierContexts(voices)
        hasMinTotalWidth = false
        return self
    }

    // MARK: - Create Modifier Contexts

    /// Create a ModifierContext for each tick in voices.
    public func createModifierContexts(_ voices: [Voice]) {
        if voices.isEmpty { return }
        let resolutionMultiplier = Formatter.getResolutionMultiplier(voices)

        var staveTickMap: [ObjectIdentifier?: [Int: ModifierContext]] = [:]
        var contexts: [ModifierContext] = []

        for voice in voices {
            let ticksUsed = Fraction(0, resolutionMultiplier)

            for tickable in voice.getTickables() {
                let integerTicks = ticksUsed.numerator
                let staveKey: ObjectIdentifier? = tickable.getStave().map { ObjectIdentifier($0) }

                if staveTickMap[staveKey] == nil {
                    staveTickMap[staveKey] = [:]
                }

                if staveTickMap[staveKey]![integerTicks] == nil {
                    let newContext = ModifierContext()
                    contexts.append(newContext)
                    staveTickMap[staveKey]![integerTicks] = newContext
                }

                _ = tickable.addToModifierContext(staveTickMap[staveKey]![integerTicks]!)
                ticksUsed.add(tickable.getTicks())
            }
        }
    }

    // MARK: - Create Tick Contexts

    /// Create a TickContext for each tick in voices.
    @discardableResult
    public func createTickContexts(_ voices: [Voice]) -> AlignmentContexts {
        if voices.isEmpty {
            tickContexts = AlignmentContexts()
            return tickContexts
        }

        var tickToContextMap: [Int: TickContext] = [:]
        var tickList: [Int] = []
        var contexts: [TickContext] = []
        let resolutionMultiplier = Formatter.getResolutionMultiplier(voices)

        for (voiceIndex, voice) in voices.enumerated() {
            let ticksUsed = Fraction(0, resolutionMultiplier)

            for tickable in voice.getTickables() {
                let integerTicks = ticksUsed.numerator

                if tickToContextMap[integerTicks] == nil {
                    let newContext = TickContext(tickID: integerTicks)
                    contexts.append(newContext)
                    tickToContextMap[integerTicks] = newContext
                    tickList.append(integerTicks)
                }

                _ = tickToContextMap[integerTicks]!.addTickable(tickable, voiceIndex: voiceIndex)
                ticksUsed.add(tickable.getTicks())
            }
        }

        tickList.sort()

        tickContexts = AlignmentContexts(
            list: tickList,
            map: tickToContextMap,
            array: contexts,
            resolutionMultiplier: resolutionMultiplier
        )

        for context in contexts {
            context.tContexts = contexts
        }

        return tickContexts
    }

    // MARK: - PreFormat

    /// Core formatter logic. Positions tick contexts with optional justification.
    @discardableResult
    public func preFormat(justifyWidth: Double = 0,
                          renderingContext: RenderContext? = nil,
                          voices: [Voice]? = nil,
                          stave: Stave? = nil) -> Double {
        let contextList = tickContexts.list
        let contextMap = tickContexts.map

        lossHistory = []

        // Set stave and preFormat voices
        if let voices, let stave {
            for voice in voices {
                _ = voice.setStave(stave).preFormat()
            }
        }

        // Pass 1: Give each context its maximum requested width
        var x: Double = 0
        var shift: Double = 0
        minTotalWidth = 0
        var totalTicks: Double = 0

        for tick in contextList {
            guard let context = contextMap[tick] else { continue }
            _ = context.preFormat()

            let width = context.getWidth()
            minTotalWidth += width

            let maxTicks = context.getMaxTicks().value()
            totalTicks += maxTicks

            let metrics = context.getMetrics()
            x = x + shift + metrics.totalLeftPx
            context.setX(x)

            shift = width - metrics.totalLeftPx
        }

        let softmaxFactor = formatterOptions.softmaxFactor
        let globalSoftmax = formatterOptions.globalSoftmax
        let maxIterations = formatterOptions.maxIterations

        // Softmax exponent for each tick
        let expForTick: (Int) -> Double = { tick in
            guard let ctx = contextMap[tick] else { return 1 }
            return pow(softmaxFactor, ctx.getMaxTicks().value() / max(totalTicks, 1))
        }
        let expTicksUsed = contextList.map(expForTick).reduce(0, +)

        minTotalWidth = x + shift
        hasMinTotalWidth = true

        // No justification needed
        if justifyWidth <= 0 { return evaluate() }

        guard contextList.count > 1 else { return 0 }

        let firstContext = contextMap[contextList[0]]!
        let lastContext = contextMap[contextList[contextList.count - 1]]!

        let adjustedJustifyWidth =
            justifyWidth
            - lastContext.getMetrics().notePx
            - lastContext.getMetrics().totalRightPx
            - firstContext.getMetrics().totalLeftPx

        // Calculate ideal distances between tick contexts
        func calculateIdealDistances(_ targetWidth: Double) -> [(expectedDistance: Double, maxNegativeShiftPx: Double, fromTickable: Tickable?)] {
            return contextList.enumerated().map { (i, tick) in
                guard let context = contextMap[tick] else {
                    return (0, 0, nil)
                }
                let voices = context.getTickablesByVoice()

                if i > 0 {
                    // Search backwards for matching voice
                    for j in stride(from: i - 1, through: 0, by: -1) {
                        let backTick = contextList[j]
                        guard let backCtx = contextMap[backTick] else { continue }
                        let backVoices = backCtx.getTickablesByVoice()
                        let prevContext = contextMap[contextList[i - 1]]!

                        // Find matching voices
                        let matchingKeys = voices.keys.filter { backVoices[$0] != nil }
                        if !matchingKeys.isEmpty {
                            var maxTicksVal: Double = 0
                            var maxNegativeShiftPx = Double.infinity
                            var backTickable: Tickable?

                            for v in matchingKeys {
                                let ticks = backVoices[v]!.getTicks().value()
                                if ticks > maxTicksVal {
                                    backTickable = backVoices[v]
                                    maxTicksVal = ticks
                                }

                                let thisTickable = voices[v]!
                                let thisMetrics = thisTickable.getMetrics()
                                let insideLeftEdge = thisTickable.getX() - (thisMetrics.modLeftPx + thisMetrics.leftDisplacedHeadPx)

                                let backMetrics = backVoices[v]!.getMetrics()
                                let insideRightEdge = backVoices[v]!.getX() + backMetrics.notePx + backMetrics.modRightPx + backMetrics.rightDisplacedHeadPx

                                maxNegativeShiftPx = min(maxNegativeShiftPx, insideLeftEdge - insideRightEdge)
                            }

                            maxNegativeShiftPx = min(maxNegativeShiftPx, context.getX() - (prevContext.getX() + targetWidth * 0.05))

                            let expectedDistance: Double
                            if globalSoftmax {
                                expectedDistance = (pow(softmaxFactor, maxTicksVal / max(totalTicks, 1)) / max(expTicksUsed, 1)) * targetWidth
                            } else if let bt = backTickable {
                                expectedDistance = bt.getVoice().softmax(maxTicksVal) * targetWidth
                            } else {
                                expectedDistance = 0
                            }

                            return (expectedDistance, maxNegativeShiftPx, backTickable)
                        }
                    }
                }
                return (0, 0, nil)
            }
        }

        // Shift contexts to their ideal distances
        func shiftToIdealDistances(_ idealDistances: [(expectedDistance: Double, maxNegativeShiftPx: Double, fromTickable: Tickable?)]) -> Double {
            let centerX = adjustedJustifyWidth / 2
            var spaceAccum: Double = 0

            for (index, tick) in contextList.enumerated() {
                guard let context = contextMap[tick] else { continue }
                if index > 0 {
                    let contextX = context.getX()
                    let ideal = idealDistances[index]

                    if let fromTickable = ideal.fromTickable {
                        let errorPx = fromTickable.getX() + ideal.expectedDistance - (contextX + spaceAccum)

                        if errorPx > 0 {
                            spaceAccum += errorPx
                        } else if errorPx < 0 {
                            let negativeShiftPx = min(ideal.maxNegativeShiftPx, abs(errorPx))
                            spaceAccum -= negativeShiftPx
                        }
                    }
                    context.setX(contextX + spaceAccum)
                }

                for tickable in context.getCenterAlignedTickables() {
                    tickable.setCenterXShift(centerX - context.getX())
                }
            }

            return lastContext.getX() - firstContext.getX()
        }

        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        let configMinPadding = (musicFont.lookupMetric("stave.endPaddingMin") as? Double) ?? 8
        let configMaxPadding = (musicFont.lookupMetric("stave.endPaddingMax") as? Double) ?? 20
        let leftPadding = (musicFont.lookupMetric("stave.padding") as? Double) ?? 12

        var targetWidth = adjustedJustifyWidth
        var distances = calculateIdealDistances(targetWidth)
        var actualWidth = shiftToIdealDistances(distances)

        // Calculate min distance for padding
        var mdCalc = targetWidth / 2
        if distances.count > 1 {
            for di in 1..<distances.count {
                mdCalc = min(distances[di].expectedDistance / 2, mdCalc)
            }
        }
        let minDistance = mdCalc

        // Right-justify padding calculation
        func paddingMaxCalc(_ curTargetWidth: Double) -> Double {
            var lastTickablePadding: Double = 0
            if let lastTickable = lastContext.getMaxTickable() {
                let voice = lastTickable.getVoice()
                if voice.getTicksUsed().value() > voice.getTotalTicks().value() {
                    return configMaxPadding * 2 < minDistance ? minDistance : configMaxPadding
                }
                let tickWidth = lastTickable.getMetrics().width
                lastTickablePadding = voice.softmax(lastContext.getMaxTicks().value()) * curTargetWidth - (tickWidth + leftPadding)
            }
            return configMaxPadding * 2 < lastTickablePadding ? lastTickablePadding : configMaxPadding
        }

        var paddingMax = paddingMaxCalc(targetWidth)
        var paddingMin = paddingMax - (configMaxPadding - configMinPadding)
        let maxX = adjustedJustifyWidth - paddingMin

        var iterations = maxIterations
        while (actualWidth > maxX && iterations > 0) || (actualWidth + paddingMax < maxX && iterations > 1) {
            targetWidth -= actualWidth - maxX
            paddingMax = paddingMaxCalc(targetWidth)
            paddingMin = paddingMax - (configMaxPadding - configMinPadding)
            distances = calculateIdealDistances(targetWidth)
            actualWidth = shiftToIdealDistances(distances)
            iterations -= 1
        }

        self.justifyWidth = justifyWidth
        return evaluate()
    }

    // MARK: - Evaluate

    /// Calculate the total cost of this formatting decision.
    public func evaluate() -> Double {
        let contextList = tickContexts.list
        let contextMap = tickContexts.map

        contextGaps = (total: 0, gaps: [])

        for (index, tick) in contextList.enumerated() {
            if index == 0 { continue }
            let prevTick = contextList[index - 1]
            guard let prevContext = contextMap[prevTick],
                  let context = contextMap[tick] else { continue }

            let prevMetrics = prevContext.getMetrics()
            let currMetrics = context.getMetrics()

            let insideRightEdge = prevContext.getX() + prevMetrics.notePx + prevMetrics.totalRightPx
            let insideLeftEdge = context.getX() - currMetrics.totalLeftPx
            let gap = insideLeftEdge - insideRightEdge
            contextGaps.total += gap
            contextGaps.gaps.append((x1: insideRightEdge, x2: insideLeftEdge))

            // Store freedom
            context.formatterMetrics.freedom.left = gap
            prevContext.formatterMetrics.freedom.right = gap
        }

        // Calculate total cost as sqrt of sum of squared deviations
        var durationStats: [String: (mean: Double, count: Int)] = [:]
        var totalSquaredDeviation: Double = 0

        for (index, tick) in contextList.enumerated() {
            guard let context = contextMap[tick] else { continue }
            for tickable in context.getTickables() {
                let duration = "\(tickable.getTicks())"
                let nextX: Double
                if index < contextList.count - 1 {
                    nextX = contextMap[contextList[index + 1]]?.getX() ?? justifyWidth
                } else {
                    nextX = justifyWidth
                }
                let space = nextX - context.getX()

                if let stat = durationStats[duration] {
                    let newMean = (stat.mean + space) / 2
                    durationStats[duration] = (mean: newMean, count: stat.count + 1)
                } else {
                    durationStats[duration] = (mean: space, count: 1)
                }
            }
        }

        for (_, tick) in contextList.enumerated() {
            guard let context = contextMap[tick] else { continue }
            for tickable in context.getTickables() {
                let duration = "\(tickable.getTicks())"
                let nextTick = contextList.first(where: { $0 > tick })
                let nextX = nextTick.flatMap { contextMap[$0]?.getX() } ?? justifyWidth
                let space = nextX - context.getX()
                if let stat = durationStats[duration] {
                    let deviation = space - stat.mean
                    totalSquaredDeviation += deviation * deviation
                }
            }
        }

        totalCost = sqrt(totalSquaredDeviation)
        lossHistory.append(totalCost)
        return totalCost
    }

    // MARK: - Post Format

    @discardableResult
    public func postFormat() -> Self {
        for context in tickContexts.array {
            _ = context.postFormat()
        }
        return self
    }

    // MARK: - Format

    /// Main public method: format voices and justify to width.
    @discardableResult
    public func format(_ voices: [Voice], justifyWidth: Double? = nil, options: FormatParams = FormatParams()) -> Self {
        self.voices = voices

        let factor = formatterOptions.softmaxFactor
        for voice in voices {
            _ = voice.setSoftmaxFactor(factor)
        }

        createTickContexts(voices)
        preFormat(justifyWidth: justifyWidth ?? 0, renderingContext: options.context, voices: voices, stave: options.stave)

        if options.stave != nil {
            _ = postFormat()
        }

        return self
    }

    // MARK: - Format To Stave

    /// Like format(), but infers justifyWidth from the stave.
    @discardableResult
    public func formatToStave(_ voices: [Voice], stave: Stave, options: FormatParams = FormatParams()) -> Self {
        var opts = options
        opts.context = opts.context ?? stave.getContext()
        opts.stave = stave
        let jw = stave.getNoteEndX() - stave.getNoteStartX() - Stave.defaultPadding
        return format(voices, justifyWidth: jw, options: opts)
    }

    // MARK: - Pre-Calculate Min Total Width

    /// Pre-calculate the minimum total width needed for all voices.
    /// `joinVoices` must be called before this method.
    public func preCalculateMinTotalWidth(_ voices: [Voice]) -> Double {
        let unalignedPadding = (Glyph.MUSIC_FONT_STACK.first!
            .lookupMetric("stave.unalignedNotePadding") as? Double) ?? 10

        var unalignedCtxCount = 0
        var wsum: Double = 0
        var dsum: Double = 0
        var widths: [Double] = []
        var durations: [Double] = []

        if hasMinTotalWidth { return minTotalWidth }

        createTickContexts(voices)

        let contextList = tickContexts.list
        let contextMap = tickContexts.map
        minTotalWidth = 0

        for tick in contextList {
            guard let context = contextMap[tick] else { continue }
            _ = context.preFormat()

            if context.getTickables().count < voices.count {
                unalignedCtxCount += 1
            }

            for t in context.getTickables() {
                wsum += t.getMetrics().width
                dsum += t.getTicks().value()
                widths.append(t.getMetrics().width)
                durations.append(t.getTicks().value())
            }

            let width = context.getWidth()
            minTotalWidth += width
        }

        hasMinTotalWidth = true

        guard !widths.isEmpty else { return minTotalWidth }

        let wavg = wsum > 0 ? wsum / Double(widths.count) : 1.0 / Double(widths.count)
        let wvar = widths.map { pow($0 - wavg, 2) }.reduce(0, +)
        let wpads = pow(wvar / Double(widths.count), 0.5) / wavg

        let davg = dsum / Double(durations.count)
        let dvar = durations.map { pow($0 - davg, 2) }.reduce(0, +)
        let dpads = pow(dvar / Double(durations.count), 0.5) / davg

        let padmax = max(dpads, wpads) * Double(contextList.count) * unalignedPadding
        let unalignedPad = unalignedPadding * Double(unalignedCtxCount)

        return minTotalWidth + max(unalignedPad, padmax)
    }

    // MARK: - Tune

    /// Run a single iteration of rejustification to reduce layout cost.
    @discardableResult
    public func tune(options: (alpha: Double, Void)? = nil) -> Double {
        let contextList = tickContexts.list
        let contextMap = tickContexts.map

        guard !contextList.isEmpty else { return 0 }

        let alpha = options?.alpha ?? 0.5

        func move(_ current: TickContext, _ shift: Double,
                  _ prev: TickContext?, _ next: TickContext?) {
            current.setX(current.getX() + shift)
            current.formatterMetrics.freedom.left += shift
            current.formatterMetrics.freedom.right -= shift
            if let prev { prev.formatterMetrics.freedom.right += shift }
            if let next { next.formatterMetrics.freedom.left -= shift }
        }

        var shift: Double = 0
        totalShift = 0

        for (index, tick) in contextList.enumerated() {
            guard let context = contextMap[tick] else { continue }
            let prevContext = index > 0 ? contextMap[contextList[index - 1]] : nil
            let nextContext = index < contextList.count - 1 ? contextMap[contextList[index + 1]] : nil

            move(context, shift, prevContext, nextContext)

            let cost = -context.getTickables()
                .map { $0.formatterMetrics.space.deviation }
                .reduce(0, +)

            if cost > 0 {
                shift = -min(context.formatterMetrics.freedom.right, abs(cost))
            } else if cost < 0 {
                if let nextContext {
                    shift = min(nextContext.formatterMetrics.freedom.right, abs(cost))
                } else {
                    shift = 0
                }
            }

            shift *= alpha
            totalShift += shift
        }

        return evaluate()
    }

    // MARK: - Accessors

    public func getMinTotalWidth() -> Double {
        guard hasMinTotalWidth else {
            fatalError("[VexError] NoMinTotalWidth: Call preFormat before calling getMinTotalWidth.")
        }
        return minTotalWidth
    }

    public func getTickContexts() -> AlignmentContexts { tickContexts }

    public func getTickContext(_ tick: Int) -> TickContext? {
        tickContexts.map[tick]
    }
}
