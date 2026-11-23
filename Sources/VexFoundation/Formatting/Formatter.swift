// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/formatter.ts` (VexFlow 5.2.0).
// Engraving layout and opt-in placement on a strict musical-time grid.

import Foundation

public enum FormatterError: Error, LocalizedError, Equatable, Sendable {
    case noVoicesToFormat
    case noVoicesToFormatRests
    case tickMismatch
    case incompleteVoice
    case minTotalWidthUnavailable
    case missingFromTickable

    public var errorDescription: String? {
        switch self {
        case .noVoicesToFormat:
            return "No voices to format"
        case .noVoicesToFormatRests:
            return "No voices to format rests"
        case .tickMismatch:
            return "Voices should have same total note duration in ticks."
        case .incompleteVoice:
            return "Voice does not have enough notes."
        case .minTotalWidthUnavailable:
            return "Call 'preCalculateMinTotalWidth' or 'preFormat' before calling 'getMinTotalWidth'"
        case .missingFromTickable:
            return "No tickable in the same voice before this tick context."
        }
    }
}

// MARK: - Formatter Options

/// Options for the Formatter layout engine.
public struct FormatterOptions {
    /// Omit (`nil`) to use the default engraving layout. (VexFlow 5.2.0)
    public var spacing: ProportionalSpacing?
    public var softmaxFactor: Double = Tables.SOFTMAX_FACTOR
    public var globalSoftmax: Bool = false
    public var maxIterations: Int = 5

    public init(softmaxFactor: Double = Tables.SOFTMAX_FACTOR,
                globalSoftmax: Bool = false,
                maxIterations: Int = 5,
                spacing: ProportionalSpacing? = nil) {
        self.spacing = spacing
        self.softmaxFactor = softmaxFactor
        self.globalSoftmax = globalSoftmax
        self.maxIterations = maxIterations
    }
}

/// Parameters for format operations.
public struct FormatParams {
    /// Align rests vertically with neighboring notes.
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

    public init(list: [Int] = [], map: [Int: TickContext] = [:], array: [TickContext] = [], resolutionMultiplier: Int = 0) {
        self.list = list
        self.map = map
        self.array = array
        self.resolutionMultiplier = resolutionMultiplier
    }
}

/// Modifier contexts created by one `joinVoices` call.
/// The map key is the stave identity (`nil` for tickables without a stave).
public struct AlignmentModifierContexts {
    public var map: [ObjectIdentifier?: [Int: ModifierContext]] = [:]
    public var array: [ModifierContext] = []
    public var resolutionMultiplier: Int = 0
}

/// Distance between tick contexts (internal to `preFormat`).
struct FormatterDistance {
    var maxNegativeShiftPx: Double
    var expectedDistance: Double
    var fromTickable: Tickable?
}

private func getRestLineForNextNoteGroup(
    _ notes: [Tickable],
    _ currRestLine: Double,
    _ currNoteIndex: Int,
    _ compare: Bool
) -> Double {
    // If no valid next note group, nextRestLine is same as current.
    var nextRestLine = currRestLine

    // Start with the next note and keep going until we find a valid non-rest note group.
    var noteIndex = currNoteIndex + 1
    while noteIndex < notes.count {
        if let note = notes[noteIndex] as? Note, !note.isRest(), !note.shouldIgnoreTicks() {
            nextRestLine = note.getLineForRest()
            break
        }
        noteIndex += 1
    }

    // Locate the midpoint between two lines.
    if compare && currRestLine != nextRestLine {
        let top = max(currRestLine, nextRestLine)
        let bot = min(currRestLine, nextRestLine)
        nextRestLine = midLine(top, bot)
    }
    return nextRestLine
}

/// JavaScript `Math.round`.
private func jsRound(_ value: Double) -> Double {
    (value + 0.5).rounded(.down)
}

// MARK: - Formatter

/// The layout engine that positions notes horizontally on a stave.
/// Breaks up voices into a grid of rational-valued ticks,
/// assigns minimum widths, and distributes space using softmax.
public final class Formatter {

    // MARK: - Properties

    public var hasMinTotalWidth: Bool = false
    public var minTotalWidth: Double = 0
    public var contextGaps: (total: Double, gaps: [(x1: Double, x2: Double)]) = (0, [])
    public var justifyWidth: Double = 0
    public var totalCost: Double = 0
    public var totalShift: Double = 0
    public var tickContexts = AlignmentContexts()
    public var formatterOptions: FormatterOptions
    /// Present only for the opt-in rational timeline. (VexFlow 5.2.0)
    private var proportional: ProportionalFormatter?
    public var modifierContexts: [AlignmentModifierContexts] = []
    public var voices: [Voice] = []
    public var lossHistory: [Double] = []
    public var durationStats: [String: (mean: Double, count: Int, total: Double)] = [:]
    /// Swift-native: the last error caught by a non-throwing variant.
    public private(set) var lastError: Error?

    // MARK: - Init

    public init(options: FormatterOptions = FormatterOptions()) {
        self.formatterOptions = options
        self.justifyWidth = 0
        self.totalCost = 0
        self.totalShift = 0
        self.durationStats = [:]

        // Minimum width required to render all the notes in the voices.
        self.minTotalWidth = 0

        // This is set to `true` after `minTotalWidth` is calculated.
        self.hasMinTotalWidth = false

        // Arrays of tick and modifier contexts.
        self.tickContexts = AlignmentContexts()
        self.modifierContexts = []

        // Gaps between contexts, for free movement of notes post formatting.
        self.contextGaps = (total: 0, gaps: [])

        self.voices = []
        self.lossHistory = []
    }

    // MARK: - Static: SimpleFormat

    /// Helper function to layout "notes" one after the other without
    /// regard for proportions. Useful for tests and debugging.
    public static func SimpleFormat(_ notes: [Tickable], x: Double = 0, paddingBetween: Double = 10) {
        var accumulator = x
        for note in notes {
            _ = note.addToModifierContext(ModifierContext())
            let tickContext = TickContext().addTickable(note).preFormat()
            let metrics = tickContext.getMetrics()
            tickContext.setX(accumulator + metrics.totalLeftPx)

            accumulator = accumulator + tickContext.getWidth() + metrics.totalRightPx + paddingBetween
        }
    }

    /// Helper function to plot formatter debug info.
    public static func plotDebugging(
        ctx: RenderContext,
        formatter: Formatter,
        xPos: Double,
        y1: Double,
        y2: Double,
        stavePadding: Double? = nil
    ) {
        let stavePadding = stavePadding ?? Metrics.getDouble("Stave.padding")

        let x = xPos + stavePadding
        let contextGaps = formatter.contextGaps

        func stroke(_ x1: Double, _ x2: Double, _ color: String) {
            ctx.beginPath()
            ctx.setStrokeStyle(color)
            ctx.setFillStyle(color)
            ctx.setLineWidth(1)
            ctx.fillRect(x1, y1, max(x2 - x1, 0), y2 - y1)
        }

        ctx.save()
        ctx.setFont(Metrics.getString("fontFamily"), 8, nil, nil)

        for gap in contextGaps.gaps {
            stroke(x + gap.x1, x + gap.x2, "rgba(100,200,100,0.4)")
            ctx.setFillStyle("green")
            ctx.fillText(formatJSNumber(jsRound(gap.x2 - gap.x1)), x + gap.x1, y2 + 12)
        }

        ctx.setFillStyle("red")
        ctx.fillText(
            String(
                format: "Loss: %.2f Shift: %.2f Gap: %.2f",
                formatter.totalCost,
                formatter.totalShift,
                contextGaps.total
            ),
            x - 20,
            y2 + 27
        )
        ctx.restore()
    }

    // MARK: - Static: FormatAndDraw

    /// Helper function to format and draw a single voice. Returns a bounding box for the notation.
    /// - Parameters:
    ///   - ctx: the rendering context
    ///   - stave: the stave to which to draw
    ///   - notes: notes to draw
    ///   - params: `autoBeam` to autobeam the notes, `alignRests` to align rests with notes
    @discardableResult
    public static func FormatAndDraw(
        ctx: RenderContext,
        stave: Stave,
        notes: [StemmableNote],
        params: FormatParams = FormatParams()
    ) throws -> BoundingBox? {
        let options = params

        // Start by creating a voice and adding all the notes to it.
        let voice = Voice(time: VoiceTime(
            numBeats: Tables.TIME4_4.numBeats,
            beatValue: Tables.TIME4_4.beatValue,
            resolution: Tables.TIME4_4.resolution
        ))
        voice.setMode(.soft)
        try voice.addTickablesThrowing(notes)

        // Then create beams, if requested.
        let beams = options.autoBeam ? try Beam.applyAndGetBeams(voice) : []

        // Instantiate a `Formatter` and format the notes.
        try Formatter()
            .joinVoicesThrowing([voice])
            .formatToStaveThrowing([voice], stave: stave, options: FormatParams(alignRests: options.alignRests, stave: stave))

        // Render the voice and beams to the stave.
        try voice.setContext(ctx).setStave(stave).drawWithStyle()
        for beam in beams {
            try beam.setContext(ctx).drawWithStyle()
        }

        // Return the bounding box of the voice.
        return voice.getBoundingBox()
    }

    /// Helper function to format and draw aligned tab and stave notes in two separate staves.
    public static func FormatAndDrawTab(
        ctx: RenderContext,
        tabstave: TabStave,
        stave: Stave,
        tabnotes: [TabNote],
        notes: [Tickable],
        autoBeam: Bool,
        params: FormatParams = FormatParams()
    ) throws {
        let autoBeam = autoBeam || params.autoBeam
        let alignRests = params.alignRests

        // Create a `4/4` voice for `notes`.
        let time = VoiceTime(
            numBeats: Tables.TIME4_4.numBeats,
            beatValue: Tables.TIME4_4.beatValue,
            resolution: Tables.TIME4_4.resolution
        )
        let notevoice = Voice(time: time)
        notevoice.setMode(.soft)
        try notevoice.addTickablesThrowing(notes)

        // Create a `4/4` voice for `tabnotes`.
        let tabvoice = Voice(time: time)
        tabvoice.setMode(.soft)
        try tabvoice.addTickablesThrowing(tabnotes)

        // Then create beams, if requested.
        let beams = autoBeam ? try Beam.applyAndGetBeams(notevoice) : []

        // Instantiate a `Formatter` and align tab and stave notes.
        try Formatter()
            .joinVoicesThrowing([notevoice])
            .joinVoicesThrowing([tabvoice])
            .formatToStaveThrowing([notevoice, tabvoice], stave: stave, options: FormatParams(alignRests: alignRests))

        // Render voices and beams to staves.
        try notevoice.draw(context: ctx, stave: stave)
        try tabvoice.draw(context: ctx, stave: tabstave)
        for beam in beams {
            try beam.setContext(ctx).drawWithStyle()
        }

        // Draw a connector between tab and note staves.
        try StaveConnector(topStave: stave, bottomStave: tabstave).setContext(ctx).drawWithStyle()
    }

    // MARK: - Rest Alignment

    /// Auto position rests based on previous/next note positions.
    /// - Parameters:
    ///   - tickables: an array of Tickables.
    ///   - alignAllNotes: if `false`, only align rests that are within a group of beamed notes.
    ///   - alignTuplets: if `false`, ignores tuplets.
    public static func AlignRestsToNotes(
        _ tickables: [Tickable],
        alignAllNotes: Bool,
        alignTuplets: Bool = false
    ) {
        for (index, currTickable) in tickables.enumerated() {
            guard let curr = currTickable as? StaveNote, curr.isRest() else { continue }

            if curr.getTuplet() != nil && !alignTuplets {
                continue
            }

            // If activated rests not on default can be rendered as specified.
            let line = curr.getLineForRest()
            if line != 3 {
                continue
            }

            if alignAllNotes || curr.getBeam() != nil {
                // Align rests with previous/next notes.
                let keyProps = curr.getKeyProps()
                guard !keyProps.isEmpty else { continue }
                var propsLine = keyProps[0].line
                if index == 0 {
                    propsLine = getRestLineForNextNoteGroup(tickables, propsLine, index, false)
                } else if index > 0 && index < tickables.count {
                    // If previous tickable is a rest, use its line number.
                    let prevTickable = tickables[index - 1]
                    // VexFlowPatch: guard against GhostNotes (no key props).
                    if let prev = prevTickable as? StaveNote {
                        if prev.isRest() {
                            if let prevLine = prev.getKeyProps().first?.line {
                                propsLine = prevLine
                            }
                        } else {
                            let restLine = prev.getLineForRest()
                            // Get the rest line for next valid non-rest note group.
                            propsLine = getRestLineForNextNoteGroup(tickables, restLine, index, true)
                        }
                    }
                }
                _ = curr.setKeyLine(0, line: propsLine)
            }
        }
    }

    /// Align rests in voices.
    public func alignRests(_ voices: [Voice], alignAllNotes: Bool) {
        do {
            try alignRestsThrowing(voices, alignAllNotes: alignAllNotes)
        } catch {
            lastError = error
        }
    }

    public func alignRestsThrowing(_ voices: [Voice], alignAllNotes: Bool) throws {
        if voices.isEmpty {
            throw FormatterError.noVoicesToFormatRests
        }

        for voice in voices {
            Formatter.AlignRestsToNotes(voice.getTickables(), alignAllNotes: alignAllNotes)
        }
    }

    // MARK: - Pre-Calculate Min Total Width

    /// Calculate the minimum width required to align and format `voices`.
    public func preCalculateMinTotalWidth(_ voices: [Voice]) -> Double {
        do {
            return try preCalculateMinTotalWidthThrowing(voices)
        } catch {
            lastError = error
            return minTotalWidth
        }
    }

    public func preCalculateMinTotalWidthThrowing(_ voices: [Voice]) throws -> Double {
        if let spacing = formatterOptions.spacing {
            try createTickContextsThrowing(voices)
            guard let proportional else { throw VexError("BadArgument", "No voices to format") }
            minTotalWidth = try proportional.minimumWidth(spacing)
            hasMinTotalWidth = true
            return minTotalWidth
        }
        let unalignedPadding = Metrics.getDouble("Stave.unalignedNotePadding")
        // Calculate additional padding based on 3 methods:
        // 1) unaligned beats in voices, 2) variance of width, 3) variance of durations
        var unalignedCtxCount = 0
        var wsum: Double = 0
        var dsum: Double = 0
        var widths: [Double] = []
        var durations: [Double] = []

        // Cache results.
        if hasMinTotalWidth { return minTotalWidth }

        // Create tick contexts.
        try createTickContextsThrowing(voices)

        let contextList = tickContexts.list
        let contextMap = tickContexts.map
        minTotalWidth = 0

        // Go through each tick context and calculate total width,
        // and also accumulate values used in padding hints
        for tick in contextList {
            guard let context = contextMap[tick] else { continue }
            context.preFormat()
            // If this TC doesn't have all the voices on it, it's unaligned.
            // so increment the unaligned padding accumulator
            if context.getTickables().count < voices.count {
                unalignedCtxCount += 1
            }
            // Calculate the 'width entropy' over all the Tickables.
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

        // Swift: avoid NaN when there are no tickables.
        guard !widths.isEmpty else { return minTotalWidth }

        // normalized (0-1) STDDEV of widths/durations gives us padding hints.
        let wavg = wsum > 0 ? wsum / Double(widths.count) : 1 / Double(widths.count)
        let wvar = sumArray(widths.map { pow($0 - wavg, 2) })
        let wpads = pow(wvar / Double(widths.count), 0.5) / wavg

        let davg = dsum / Double(durations.count)
        let dvar = sumArray(durations.map { pow($0 - davg, 2) })
        let dpads = pow(dvar / Double(durations.count), 0.5) / davg

        // Find max of 3 methods pad the width with that
        let padmax = max(dpads, wpads) * Double(contextList.count) * unalignedPadding
        let unalignedPad = unalignedPadding * Double(unalignedCtxCount)

        return minTotalWidth + max(unalignedPad, padmax)
    }

    /// Get minimum width required to render all voices. Either `format` or
    /// `preFormat` method has to be called prior to this method.
    public func getMinTotalWidth() -> Double {
        (try? getMinTotalWidthThrowing()) ?? minTotalWidth
    }

    public func getMinTotalWidthThrowing() throws -> Double {
        guard hasMinTotalWidth else {
            throw FormatterError.minTotalWidthUnavailable
        }
        return minTotalWidth
    }

    // MARK: - Static: Resolution Multiplier

    /// Calculate the resolution multiplier for `voices`.
    public static func getResolutionMultiplier(_ voices: [Voice]) -> Int {
        (try? getResolutionMultiplierThrowing(voices)) ?? 1
    }

    public static func getResolutionMultiplierThrowing(_ voices: [Voice]) throws -> Int {
        guard !voices.isEmpty else {
            throw FormatterError.noVoicesToFormat
        }

        var resolutionMultiplier = 1
        for voice in voices {
            // VexFlowPatch: removed tick mismatch error to allow voices with different
            // total ticks (e.g. whole measure rests alongside notes in 12/8).
            if voice.getMode() == .strict && !voice.isComplete() {
                throw FormatterError.incompleteVoice
            }
            resolutionMultiplier = max(resolutionMultiplier, Fraction.lcm(resolutionMultiplier, voice.getResolutionMultiplier()))
        }
        return resolutionMultiplier
    }

    // MARK: - Create Modifier Contexts

    /// Create a `ModifierContext` for each tick in `voices`.
    public func createModifierContexts(_ voices: [Voice]) {
        do {
            try createModifierContextsThrowing(voices)
        } catch {
            lastError = error
        }
    }

    public func createModifierContextsThrowing(_ voices: [Voice]) throws {
        if voices.isEmpty { return }
        let resolutionMultiplier = try Formatter.getResolutionMultiplierThrowing(voices)

        // Initialize tick maps.
        var tickToContextMap: [ObjectIdentifier?: [Int: ModifierContext]] = [:]
        var contexts: [ModifierContext] = []

        // For each voice, extract notes and create a context for every
        // new tick that hasn't been seen before.
        for voice in voices {
            // Use resolution multiplier as denominator so that no additional expansion
            // of fractional tick values is needed.
            let ticksUsed = Fraction(0, resolutionMultiplier)

            for tickable in voice.getTickables() {
                let integerTicks = ticksUsed.numerator
                let staveKey: ObjectIdentifier? = tickable.getStave().map { ObjectIdentifier($0) }
                var staveTickToContextMap = tickToContextMap[staveKey] ?? [:]

                // If we have no tick context for this tick, create one.
                let context: ModifierContext
                if let existing = staveTickToContextMap[integerTicks] {
                    context = existing
                } else {
                    context = ModifierContext()
                    contexts.append(context)
                    staveTickToContextMap[integerTicks] = context
                }
                tickToContextMap[staveKey] = staveTickToContextMap

                // Add this tickable to the TickContext.
                _ = tickable.addToModifierContext(context)
                if formatterOptions.spacing == nil || !tickable.shouldIgnoreTicks() {
                    ticksUsed.add(tickable.getTicks())
                }
            }
        }

        modifierContexts.append(AlignmentModifierContexts(
            map: tickToContextMap,
            array: contexts,
            resolutionMultiplier: resolutionMultiplier
        ))
    }

    // MARK: - Create Tick Contexts

    /// Create a `TickContext` for each tick in `voices`. Also calculate the
    /// total number of ticks in voices.
    @discardableResult
    public func createTickContexts(_ voices: [Voice]) -> AlignmentContexts {
        do {
            return try createTickContextsThrowing(voices)
        } catch {
            lastError = error
            return tickContexts
        }
    }

    @discardableResult
    public func createTickContextsThrowing(_ voices: [Voice]) throws -> AlignmentContexts {
        if voices.isEmpty {
            if formatterOptions.spacing != nil { throw VexError("BadArgument", "No voices to format") }
            tickContexts = AlignmentContexts(list: [], map: [:], array: [], resolutionMultiplier: 0)
            return tickContexts
        }

        if formatterOptions.spacing != nil {
            let proportional = try ProportionalFormatter(
                voices: voices,
                resolutionMultiplier: try Formatter.getResolutionMultiplierThrowing(voices)
            )
            self.proportional = proportional
            tickContexts = proportional.contexts
            return tickContexts
        }

        // Initialize tick maps.
        var tickToContextMap: [Int: TickContext] = [:]
        var tickList: [Int] = []
        var contexts: [TickContext] = []
        let resolutionMultiplier = try Formatter.getResolutionMultiplierThrowing(voices)
        // For each voice, extract notes and create a context for every
        // new tick that hasn't been seen before.
        for (voiceIndex, voice) in voices.enumerated() {
            // Use resolution multiplier as denominator so that no additional expansion
            // of fractional tick values is needed.
            let ticksUsed = Fraction(0, resolutionMultiplier)

            for tickable in voice.getTickables() {
                let integerTicks = ticksUsed.numerator

                // If we have no tick context for this tick, create one.
                if tickToContextMap[integerTicks] == nil {
                    let newContext = TickContext(tickID: integerTicks)
                    contexts.append(newContext)
                    tickToContextMap[integerTicks] = newContext
                    // Maintain a list of unique integerTicks.
                    tickList.append(integerTicks)
                }

                // Add this tickable to the TickContext.
                tickToContextMap[integerTicks]?.addTickable(tickable, voiceIndex: voiceIndex)
                ticksUsed.add(tickable.getTicks())
            }
        }

        tickContexts = AlignmentContexts(
            list: tickList.sorted(),
            map: tickToContextMap,
            array: contexts,
            resolutionMultiplier: resolutionMultiplier
        )

        for context in contexts {
            context.tContexts = contexts
        }
        return tickContexts
    }

    public func getTickContexts() -> AlignmentContexts { tickContexts }

    // MARK: - PreFormat

    /// Position all the tickables in the tick contexts and justify them to
    /// `justifyWidth`. Returns the formatting cost.
    @discardableResult
    public func preFormat(justifyWidth: Double = 0,
                          renderingContext: RenderContext? = nil,
                          voices: [Voice]? = nil,
                          stave: Stave? = nil) -> Double {
        do {
            return try preFormatThrowing(
                justifyWidth: justifyWidth,
                renderingContext: renderingContext,
                voices: voices,
                stave: stave
            )
        } catch {
            lastError = error
            return 0
        }
    }

    @discardableResult
    public func preFormatThrowing(justifyWidth: Double = 0,
                                  renderingContext: RenderContext? = nil,
                                  voices voicesParam: [Voice]? = nil,
                                  stave: Stave? = nil) throws -> Double {
        // Initialize context maps.
        let contextList = tickContexts.list
        let contextMap = tickContexts.map

        // Reset loss history for evaluator.
        lossHistory = []

        // If voices and a stave were provided, set the Stave for each voice
        // and preFormat to apply Y values to the notes;
        if let voicesParam, let stave {
            for voice in voicesParam {
                try voice.setStave(stave).preFormatThrowing()
            }
        }

        if let proportional, let spacing = formatterOptions.spacing {
            minTotalWidth = try proportional.minimumWidth(spacing)
            self.justifyWidth = try proportional.format(spacing, justifyWidth)
            hasMinTotalWidth = true
            return evaluate()
        }

        // Now distribute the ticks to each tick context, and assign them their
        // own X positions.
        var x: Double = 0
        var shift: Double = 0
        minTotalWidth = 0
        var totalTicks: Double = 0

        // Pass 1: Give each note maximum width requested by context.
        for tick in contextList {
            guard let context = contextMap[tick] else { continue }

            // Make sure that all tickables in this context have calculated their
            // space requirements.
            context.preFormat()

            let width = context.getWidth()
            minTotalWidth += width

            let maxTicks = context.getMaxTicks().value()
            totalTicks += maxTicks

            let metrics = context.getMetrics()
            x = x + shift + metrics.totalLeftPx
            context.setX(x)

            // Calculate shift for the next tick.
            shift = width - metrics.totalLeftPx
        }

        // VexFlowPatch: guard against zero totalTicks (e.g. faulty tab scores)
        // to prevent leftoverPxPerTick becoming Infinity and x being set to NaN.
        if totalTicks == 0 {
            totalTicks = 1
        }

        // Use softmax based on all notes across all staves. (options.globalSoftmax)
        let globalSoftmax = formatterOptions.globalSoftmax
        let softmaxFactor = formatterOptions.softmaxFactor
        let maxIterations = formatterOptions.maxIterations

        let exp: (Int) -> Double = { tick in
            pow(softmaxFactor, (contextMap[tick]?.getMaxTicks().value() ?? 0) / totalTicks)
        }
        let expTicksUsed = sumArray(contextList.map(exp))

        minTotalWidth = x + shift
        hasMinTotalWidth = true

        // No justification needed. End formatting.
        if justifyWidth <= 0 { return evaluate() }

        // Start justification. Subtract the right extra pixels of the final context because the formatter
        // justifies based on the context's X position, which is the left-most part of the note head.
        guard let firstTick = contextList.first, let lastTick = contextList.last,
              let firstContext = contextMap[firstTick], let lastContext = contextMap[lastTick] else {
            return evaluate()
        }

        // Calculate the "distance error" between the tick contexts. The expected distance is the spacing proportional to
        // the softmax of the ticks.
        func calculateIdealDistances(_ adjustedJustifyWidth: Double) throws -> [FormatterDistance] {
            try contextList.enumerated().map { (i, tick) -> FormatterDistance in
                guard let context = contextMap[tick] else {
                    return FormatterDistance(maxNegativeShiftPx: 0, expectedDistance: 0, fromTickable: nil)
                }
                let voices = context.getTickablesByVoice()
                var backTickable: Tickable?
                if i > 0, let prevContext = contextMap[contextList[i - 1]] {
                    // Go through each tickable and search backwards for another tickable
                    // in the same voice. If found, use that duration (ticks) to calculate
                    // the expected distance.
                    for j in stride(from: i - 1, through: 0, by: -1) {
                        guard let backTick = contextMap[contextList[j]] else { continue }
                        let backVoices = backTick.getTickablesByVoice()

                        // Look for matching voices between tick contexts.
                        // (Object.keys order: ascending integer keys.)
                        let matchingVoices = voices.keys.sorted().filter { backVoices[$0] != nil }

                        if !matchingVoices.isEmpty {
                            // Found matching voices, get largest duration
                            var maxTicks: Double = 0
                            var maxNegativeShiftPx = Double.infinity
                            var expectedDistance: Double = 0

                            for v in matchingVoices {
                                guard let backVoice = backVoices[v], let thisTickable = voices[v] else { continue }
                                let ticks = backVoice.getTicks().value()
                                if ticks > maxTicks {
                                    backTickable = backVoice
                                    maxTicks = ticks
                                }

                                // Calculate the limits of the shift based on modifiers, etc.
                                let insideLeftEdge =
                                    thisTickable.getX()
                                    - (thisTickable.getMetrics().modLeftPx + thisTickable.getMetrics().leftDisplacedHeadPx)

                                let backMetrics = backVoice.getMetrics()
                                let insideRightEdge =
                                    backVoice.getX() + backMetrics.notePx + backMetrics.modRightPx
                                    + backMetrics.rightDisplacedHeadPx

                                // Don't allow shifting if notes in the same voice can collide
                                maxNegativeShiftPx = min(maxNegativeShiftPx, insideLeftEdge - insideRightEdge)
                            }

                            // Don't shift further left than the notehead of the last context. Actually, stay at most 5% to the right
                            // so that two different tick contexts don't align across staves.
                            maxNegativeShiftPx = min(
                                maxNegativeShiftPx,
                                context.getX() - (prevContext.getX() + adjustedJustifyWidth * 0.05)
                            )

                            // Calculate the expected distance of the current context from the last matching tickable. The
                            // distance is scaled down by the softmax for the voice.
                            if globalSoftmax {
                                let t = totalTicks
                                expectedDistance = (pow(softmaxFactor, maxTicks / t) / expTicksUsed) * adjustedJustifyWidth
                            } else if let backTickable {
                                expectedDistance = try backTickable.getVoiceThrowing().softmax(maxTicks) * adjustedJustifyWidth
                            }
                            return FormatterDistance(
                                maxNegativeShiftPx: maxNegativeShiftPx,
                                expectedDistance: expectedDistance,
                                fromTickable: backTickable
                            )
                        }
                    }
                }

                return FormatterDistance(maxNegativeShiftPx: 0, expectedDistance: 0, fromTickable: nil)
            }
        }

        let adjustedJustifyWidth =
            justifyWidth
            - lastContext.getMetrics().notePx
            - lastContext.getMetrics().totalRightPx
            - firstContext.getMetrics().totalLeftPx

        func shiftToIdealDistances(_ idealDistances: [FormatterDistance]) throws -> Double {
            // Distribute ticks to the contexts based on the calculated distance error.
            let centerX = adjustedJustifyWidth / 2
            var spaceAccum: Double = 0

            for (index, tick) in contextList.enumerated() {
                guard let context = contextMap[tick] else { continue }
                if index > 0 {
                    let contextX = context.getX()
                    let ideal = idealDistances[index]
                    guard let fromTickable = ideal.fromTickable else {
                        throw FormatterError.missingFromTickable
                    }
                    let errorPx = fromTickable.getX() + ideal.expectedDistance - (contextX + spaceAccum)

                    var negativeShiftPx: Double = 0
                    if errorPx > 0 {
                        spaceAccum += errorPx
                    } else if errorPx < 0 {
                        negativeShiftPx = min(ideal.maxNegativeShiftPx, abs(errorPx))
                        spaceAccum += -negativeShiftPx
                    }
                    context.setX(contextX + spaceAccum)
                }
                // Move center aligned tickables to middle
                for tickable in context.getCenterAlignedTickables() {
                    tickable.setCenterXShift(centerX - context.getX())
                }
            }

            return lastContext.getX() - firstContext.getX()
        }

        let configMinPadding = Metrics.getDouble("Stave.endPaddingMin")
        let configMaxPadding = Metrics.getDouble("Stave.endPaddingMax")
        let leftPadding = Metrics.getDouble("Stave.padding")
        var targetWidth = adjustedJustifyWidth
        let distances = try calculateIdealDistances(targetWidth)
        var actualWidth = try shiftToIdealDistances(distances)

        // Just one context. Done formatting.
        if contextList.count == 1 { return 0 }

        func calcMinDistance(_ targetWidth: Double, _ distances: [FormatterDistance]) -> Double {
            var mdCalc = targetWidth / 2
            if distances.count > 1 {
                for di in 1..<distances.count {
                    mdCalc = min(distances[di].expectedDistance / 2, mdCalc)
                }
            }
            return mdCalc
        }
        let minDistance = calcMinDistance(targetWidth, distances)

        // right justify to either the configured padding, or the min distance between notes, whichever is greatest.
        // This * 2 keeps the existing formatting unless there is 'a lot' of extra whitespace, which won't break
        // existing visual regression tests.
        func paddingMaxCalc(_ curTargetWidth: Double) throws -> Double {
            var lastTickablePadding: Double = 0
            if let lastTickable = lastContext.getMaxTickable() {
                let voice = try lastTickable.getVoiceThrowing()
                // If the number of actual ticks in the measure <> configured ticks, right-justify
                // because the softmax won't yield the correct value
                if voice.getTicksUsed().value() > voice.getTotalTicks().value() {
                    return configMaxPadding * 2 < minDistance ? minDistance : configMaxPadding
                }
                let tickWidth = lastTickable.getWidth()
                lastTickablePadding =
                    voice.softmax(lastContext.getMaxTicks().value()) * curTargetWidth - (tickWidth + leftPadding)
            }
            return configMaxPadding * 2 < lastTickablePadding ? lastTickablePadding : configMaxPadding
        }
        var paddingMax = try paddingMaxCalc(targetWidth)
        var paddingMin = paddingMax - (configMaxPadding - configMinPadding)
        let maxX = adjustedJustifyWidth - paddingMin

        var iterations = maxIterations
        // Adjust justification width until the right margin is as close as possible to the calculated padding,
        // without going over
        while (actualWidth > maxX && iterations > 0) || (actualWidth + paddingMax < maxX && iterations > 1) {
            targetWidth -= actualWidth - maxX
            paddingMax = try paddingMaxCalc(targetWidth)
            paddingMin = paddingMax - (configMaxPadding - configMinPadding)
            actualWidth = try shiftToIdealDistances(calculateIdealDistances(targetWidth))
            iterations -= 1
        }

        self.justifyWidth = justifyWidth
        return evaluate()
    }

    // MARK: - Evaluate

    /// Calculate the total cost of this formatting decision.
    @discardableResult
    public func evaluate() -> Double {
        let contexts = tickContexts
        let justifyWidth = self.justifyWidth
        // Calculate available slack per tick context. This works out how much freedom
        // to move a context has in either direction, without affecting other notes.
        contextGaps = (total: 0, gaps: [])
        for (index, tick) in contexts.list.enumerated() {
            if index == 0 { continue }
            let prevTick = contexts.list[index - 1]
            guard let prevContext = contexts.map[prevTick], let context = contexts.map[tick] else { continue }
            let prevMetrics = prevContext.getMetrics()
            let currMetrics = context.getMetrics()

            // Calculate X position of right edge of previous note
            let insideRightEdge = prevContext.getX() + prevMetrics.notePx + prevMetrics.totalRightPx
            // Calculate X position of left edge of current note
            let insideLeftEdge = context.getX() - currMetrics.totalLeftPx
            let gap = insideLeftEdge - insideRightEdge
            contextGaps.total += gap
            contextGaps.gaps.append((x1: insideRightEdge, x2: insideLeftEdge))

            // Tell the tick contexts how much they can reposition themselves.
            context.getFormatterMetrics().freedom.left = gap
            prevContext.getFormatterMetrics().freedom.right = gap
        }

        // Calculate mean distance in each voice for each duration type, then calculate
        // how far each note is from the mean.
        durationStats = [:]

        func updateStats(_ duration: String, _ space: Double) {
            if var stats = durationStats[duration] {
                stats.count += 1
                stats.total += space
                stats.mean = stats.total / Double(stats.count)
                durationStats[duration] = stats
            } else {
                durationStats[duration] = (mean: space, count: 1, total: space)
            }
        }

        for voice in voices {
            let notes = voice.getTickables()
            for (i, note) in notes.enumerated() {
                let duration = note.getTicks().clone().simplify().toString()
                let metrics = note.getMetrics()
                let formatterMetrics = note.getFormatterMetrics()
                let leftNoteEdge = note.getX() + metrics.notePx + metrics.modRightPx + metrics.rightDisplacedHeadPx
                var space: Double = 0

                if i < notes.count - 1 {
                    let rightNote = notes[i + 1]
                    let rightMetrics = rightNote.getMetrics()
                    let rightNoteEdge = rightNote.getX() - rightMetrics.modLeftPx - rightMetrics.leftDisplacedHeadPx

                    space = rightNoteEdge - leftNoteEdge
                    formatterMetrics.space.used = rightNote.getX() - note.getX()
                    rightNote.getFormatterMetrics().freedom.left = space
                } else {
                    space = justifyWidth - leftNoteEdge
                    formatterMetrics.space.used = justifyWidth - note.getX()
                }

                formatterMetrics.freedom.right = space
                updateStats(duration, formatterMetrics.space.used)
            }
        }

        // Calculate how much each note deviates from the mean. Loss function is square
        // root of the sum of squared deviations.
        var totalDeviation: Double = 0
        for voice in voices {
            for note in voice.getTickables() {
                let duration = note.getTicks().clone().simplify().toString()
                let metrics = note.getFormatterMetrics()

                metrics.space.mean = durationStats[duration]?.mean ?? 0
                metrics.duration = duration
                metrics.iterations += 1
                metrics.space.deviation = metrics.space.used - metrics.space.mean

                totalDeviation += pow(metrics.space.deviation, 2)
            }
        }

        totalCost = sqrt(totalDeviation)
        lossHistory.append(totalCost)
        return totalCost
    }

    // MARK: - Tune

    /// Run a single iteration of rejustification. At a high level, this method
    /// calculates the overall "loss" (or cost) of this layout, and repositions
    /// tickcontexts in an attempt to reduce the cost. You can call this method
    /// multiple times until it finds an oscillating minimum.
    /// - Parameter options: `alpha` is the learning rate (default 0.5).
    @discardableResult
    public func tune(options: (alpha: Double, Void)? = nil) -> Double {
        // Tuning must never move strict rhythmic anchors, including when called by System.
        if proportional != nil { return totalCost }
        let contexts = tickContexts

        let alpha = options?.alpha ?? 0.5

        // function `move` moved to tickcontext.
        var shift: Double = 0
        totalShift = 0
        let list = contexts.list
        for (index, tick) in list.enumerated() {
            guard let context = contexts.map[tick] else { continue }
            let prevContext = index > 0 ? contexts.map[list[index - 1]] : nil
            let nextContext = index < list.count - 1 ? contexts.map[list[index + 1]] : nil

            context.move(shift, prevContext, nextContext)

            let cost = -context.getDeviationCost()
            if cost > 0 {
                shift = -min(context.getFormatterMetrics().freedom.right, abs(cost))
            } else if cost < 0 {
                if let nextContext {
                    shift = min(nextContext.getFormatterMetrics().freedom.right, abs(cost))
                } else {
                    shift = 0
                }
            }

            shift *= alpha
            totalShift += shift
        }

        return evaluate()
    }

    // MARK: - Post Format

    /// This is the top-level call for all formatting logic completed after `x` and `y` values have been computed
    /// for the notes in the voices.
    @discardableResult
    public func postFormat() -> Self {
        for modifierContexts in modifierContexts {
            for mc in modifierContexts.array {
                mc.postFormat()
            }
        }

        let contexts = proportional != nil
            ? tickContexts.array
            : tickContexts.list.compactMap { tickContexts.map[$0] }
        for context in contexts { context.postFormat() }

        return self
    }

    // MARK: - Join Voices

    /// Take all `voices` and create `ModifierContext`s out of them. This tells
    /// the formatters that the voices belong on a single stave.
    @discardableResult
    public func joinVoices(_ voices: [Voice]) -> Self {
        do {
            return try joinVoicesThrowing(voices)
        } catch {
            lastError = error
            return self
        }
    }

    @discardableResult
    public func joinVoicesThrowing(_ voices: [Voice]) throws -> Self {
        try createModifierContextsThrowing(voices)
        hasMinTotalWidth = false
        return self
    }

    // MARK: - Format

    /// Align rests in voices, justify the contexts, and position the notes
    /// so voices are aligned and ready to render onto the stave. This method
    /// mutates the `x` positions of all tickables in `voices`.
    ///
    /// Voices are full justified to fit in `justifyWidth` pixels.
    ///
    /// Set `options.context` to the rendering context. Set `options.alignRests`
    /// to `true` to enable rest alignment.
    @discardableResult
    public func format(_ voices: [Voice], justifyWidth: Double? = nil,
                       options: FormatParams = FormatParams()) -> Self {
        do {
            return try formatThrowing(voices, justifyWidth: justifyWidth, options: options)
        } catch {
            lastError = error
            return self
        }
    }

    @discardableResult
    public func formatThrowing(_ voices: [Voice], justifyWidth: Double? = nil,
                               options: FormatParams = FormatParams()) throws -> Self {
        let opts = options

        self.voices = voices
        let softmaxFactor = formatterOptions.softmaxFactor
        if softmaxFactor != 0 && !softmaxFactor.isNaN {
            for v in self.voices {
                v.setSoftmaxFactor(softmaxFactor)
            }
        }

        try alignRestsThrowing(voices, alignAllNotes: opts.alignRests)
        try createTickContextsThrowing(voices)
        try preFormatThrowing(
            justifyWidth: justifyWidth ?? 0,
            renderingContext: opts.context,
            voices: voices,
            stave: opts.stave
        )

        // Only postFormat if a stave was supplied for y value formatting
        if opts.stave != nil { postFormat() }

        return self
    }

    // MARK: - Format To Stave

    /// This method is just like `format` except that the `justifyWidth` is inferred from the `stave`.
    @discardableResult
    public func formatToStave(_ voices: [Voice], stave: Stave,
                              options: FormatParams = FormatParams()) -> Self {
        do {
            return try formatToStaveThrowing(voices, stave: stave, options: options)
        } catch {
            lastError = error
            return self
        }
    }

    @discardableResult
    public func formatToStaveThrowing(_ voices: [Voice], stave: Stave,
                                      options optionsParam: FormatParams = FormatParams()) throws -> Self {
        var options = optionsParam
        if options.context == nil {
            options.context = stave.getContext()
        }

        let justifyWidth = stave.getNoteEndX() - stave.getNoteStartX() - Stave.defaultPadding
        return try formatThrowing(voices, justifyWidth: justifyWidth, options: options)
    }

    public func getTickContext(_ tick: Int) -> TickContext? {
        tickContexts.map[tick]
    }
}
