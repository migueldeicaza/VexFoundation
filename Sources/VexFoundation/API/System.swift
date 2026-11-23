// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/system.ts` (VexFlow 5.9.0).

import Foundation

public enum SystemError: Error, LocalizedError, Equatable, Sendable {
    case missingFactory
    case drawRequiresFormat

    public var errorDescription: String? {
        switch self {
        case .missingFactory:
            return "System requires a factory."
        case .drawRequiresFormat:
            return "format() must be called before draw()."
        }
    }
}

// MARK: - System Types

/// Formatter options extended with alpha for tuning.
public struct SystemFormatterOptions {
    public var alpha: Double = 0.5
    public var softmaxFactor: Double = Tables.SOFTMAX_FACTOR
    /// Proportional or optical spacing (VexFlow 5.3.0 `FormatterOptions.spacing`). `nil` keeps engraving layout.
    public var spacing: MeasuredSpacing?

    public init(alpha: Double = 0.5, softmaxFactor: Double = Tables.SOFTMAX_FACTOR,
                spacing: MeasuredSpacing? = nil) {
        self.alpha = alpha
        self.softmaxFactor = softmaxFactor
        self.spacing = spacing
    }

    /// Source compatibility with the 5.2.0 port: strict proportional spacing.
    public init(alpha: Double = 0.5, softmaxFactor: Double = Tables.SOFTMAX_FACTOR,
                spacing: ProportionalSpacing) {
        self.init(alpha: alpha, softmaxFactor: softmaxFactor, spacing: .proportional(spacing))
    }
}

/// A stave within a system with its associated voices.
public struct SystemStave {
    public var voices: [Voice]
    public var stave: Stave?
    public var noJustification: Bool = false
    public var options: StaveOptions?
    public var spaceAbove: Double = 0
    public var spaceBelow: Double = 0
    public var debugNoteMetrics: Bool = false

    public init(voices: [Voice], stave: Stave? = nil,
                noJustification: Bool = false, options: StaveOptions? = nil,
                spaceAbove: Double = 0, spaceBelow: Double = 0,
                debugNoteMetrics: Bool = false) {
        self.voices = voices
        self.stave = stave
        self.noJustification = noJustification
        self.options = options
        self.spaceAbove = spaceAbove
        self.spaceBelow = spaceBelow
        self.debugNoteMetrics = debugNoteMetrics
    }
}

/// Internal stave info for formatting.
private struct StaveInfo {
    var noJustification: Bool
    var options: StaveOptions
    var spaceAbove: Double
    var spaceBelow: Double
    var debugNoteMetrics: Bool
}

/// Options for System creation.
public struct SystemOptions {
    public var factory: Factory?
    public var runtimeContext: VexRuntimeContext?
    public var noPadding: Bool = false
    public var debugFormatter: Bool = false
    public var spaceBetweenStaves: Double = 12
    public var formatIterations: Int = 0
    public var autoWidth: Bool = false
    public var x: Double = 10
    public var width: Double = 500
    public var y: Double = 10
    public var details: SystemFormatterOptions = SystemFormatterOptions()
    public var formatOptions: FormatParams = FormatParams()
    public var noJustification: Bool = false

    /// When width is not provided (nil), autoWidth is enabled and the system
    /// auto-sizes to fit content — matching JS VexFlow's behavior.
    public init(factory: Factory? = nil, runtimeContext: VexRuntimeContext? = nil, noPadding: Bool = false,
                debugFormatter: Bool = false, spaceBetweenStaves: Double = 12,
                formatIterations: Int = 0, autoWidth: Bool = false,
                x: Double = 10, width: Double? = nil, y: Double = 10,
                details: SystemFormatterOptions = SystemFormatterOptions(),
                formatOptions: FormatParams = FormatParams(),
                noJustification: Bool = false) {
        self.factory = factory
        self.runtimeContext = runtimeContext
        self.noPadding = noPadding
        self.debugFormatter = debugFormatter
        self.spaceBetweenStaves = spaceBetweenStaves
        self.formatIterations = formatIterations
        // Preserve Swift convenience: when width is omitted, default to auto-width
        // unless explicitly disabled by `noJustification` with no autoWidth request.
        if width == nil {
            self.autoWidth = autoWidth || !noJustification
        } else {
            self.autoWidth = autoWidth
        }
        self.x = x
        self.width = width ?? 500
        self.y = y
        self.details = details
        self.formatOptions = formatOptions
        self.noJustification = noJustification
    }
}

// MARK: - System

/// A musical system: a collection of staves with voices, formatted together.
public final class System: VexElement {

    override public class var category: String { "System" }

    // MARK: - Properties

    private var options: SystemOptions
    private var factory: Factory
    private let runtimeContext: VexRuntimeContext
    private var formatter: Formatter?
    private var startX: Double?
    private var lastY: Double?
    private var partStaves: [Stave] = []
    private var partStaveInfos: [StaveInfo] = []
    private var partVoices: [Voice] = []
    private var debugNoteMetricsYs: [(y: Double, stave: Stave)] = []
    private var connector: StaveConnector?

    // MARK: - Init

    public convenience init(options: SystemOptions = SystemOptions()) throws {
        guard let factory = options.factory else {
            throw SystemError.missingFactory
        }
        let runtimeContext = options.runtimeContext ?? factory.getRuntimeContext()
        self.init(factory: factory, runtimeContext: runtimeContext, options: options)
    }

    init(factory: Factory, runtimeContext: VexRuntimeContext, options: SystemOptions) {
        var resolvedOptions = options
        resolvedOptions.runtimeContext = runtimeContext
        self.factory = factory
        self.options = resolvedOptions
        self.runtimeContext = runtimeContext
        super.init(runtimeContext: runtimeContext)
    }

    // MARK: - Accessors

    /// Replace the formatting options (upstream `setOptions`). The factory must be set; the runtime
    /// context stays the one of this system. Throws `NoFactory` without a factory.
    public func setOptions(_ options: SystemOptions) throws {
        guard let factory = options.factory else {
            throw VexError("NoFactory", "System.setOptions(options) requires a factory.")
        }
        var resolvedOptions = options
        resolvedOptions.runtimeContext = runtimeContext
        self.factory = factory
        self.options = resolvedOptions
    }

    /// Get origin x.
    override public func getX() -> Double { options.x }

    /// Set origin x.
    @discardableResult
    override public func setX(_ x: Double) -> Self {
        options.x = x
        partStaves.forEach { $0.setX(x) }
        return self
    }

    /// Get origin y.
    override public func getY() -> Double { options.y }

    /// Set origin y.
    @discardableResult
    override public func setY(_ y: Double) -> Self {
        options.y = y
        partStaves.forEach { $0.setY(y) }
        return self
    }

    /// Set a fixed layout width. A width that is not positive and finite is ignored;
    /// see `setWidthThrowing(_:)`. (VexFlow 5.1.0)
    @discardableResult
    override public func setWidth(_ width: Double) -> Self {
        (try? setWidthThrowing(width)) ?? self
    }

    /// Request the minimum width (auto width). Upstream `setWidth()` with no argument.
    @discardableResult
    public func setWidth() -> Self {
        options.autoWidth = true
        return self
    }

    /// Set a fixed layout width, or request the minimum width when `width` is `nil`.
    /// Throws when the width is not positive and finite. (VexFlow 5.1.0)
    @discardableResult
    public func setWidthThrowing(_ width: Double?) throws -> Self {
        if let width, !width.isFinite || width <= 0 {
            throw VexError("BadArgument", "System width must be a positive finite number.")
        }
        options.autoWidth = width == nil
        if let width {
            options.width = width
            partStaves.forEach { $0.setWidth(width) }
        }
        return self
    }

    /// Width assigned by the latest layout. (VexFlow 5.1.0)
    override public func getWidth() -> Double { options.width }

    public func getRuntimeContext() -> VexRuntimeContext { runtimeContext }

    /// Get the staves of the system.
    public func getStaves() -> [Stave] { partStaves }

    /// Get the voices of the system.
    public func getVoices() -> [Voice] { partVoices }

    @available(*, deprecated, renamed: "getVoices()")
    public func getSystemVoices() -> [Voice] { partVoices }

    // MARK: - Context

    @discardableResult
    override public func setContext(_ context: RenderContext?) -> Self {
        super.setContext(context)
        if let context { _ = factory.setContext(context) }
        return self
    }

    // MARK: - Connector

    @discardableResult
    public func addConnector(type: ConnectorType = .double) -> StaveConnector {
        if type == .mensurstrich {
            // Upstream throws for a group that does not have exactly two staves; see `addConnectorThrowing`.
            if let conn = try? addConnectorThrowing(type: type) { return conn }
            let conn = factory.StaveConnector(
                topStave: partStaves[0], bottomStave: partStaves[partStaves.count - 1], type: .none
            )
            connector = conn
            return conn
        }
        let conn = factory.StaveConnector(
            topStave: partStaves[0],
            bottomStave: partStaves[partStaves.count - 1],
            type: type
        )
        connector = conn
        return conn
    }

    /// Add a connector. A Mensurstrich requires exactly two staves; use `addMensurstriche()` for a
    /// group. (VexFlow 5.9.0)
    @discardableResult
    public func addConnectorThrowing(type: ConnectorType = .double) throws -> StaveConnector {
        if type == .mensurstrich {
            if partStaves.count != 2 {
                throw VexError(
                    "BadArgument", "A single Mensurstrich requires two staves. Use addMensurstriche() for a group."
                )
            }
            let conn = try addMensurstriche()[0]
            connector = conn
            return conn
        }
        return addConnector(type: type)
    }

    /// Replace this measure's ending bars with one Mensurstrich per gap. Call after adding all staves.
    /// (VexFlow 5.9.0)
    @discardableResult
    public func addMensurstriche() throws -> [StaveConnector] {
        if partStaves.count < 2 {
            throw VexError("BadArgument", "Mensurstriche require at least two staves.")
        }
        partStaves.forEach { $0.setEndBarType(.none) }
        return partStaves.indices.dropFirst().map { index in
            factory.StaveConnector(topStave: partStaves[index - 1], bottomStave: partStaves[index], type: .mensurstrich)
        }
    }

    // MARK: - Add Stave

    /// Add a stave to the system with its voices.
    @discardableResult
    public func addStave(_ params: SystemStave) -> Stave {
        var staveOptions = params.options ?? StaveOptions()
        staveOptions.leftBar = false

        let stave = params.stave ?? factory.Stave(
            x: options.x, y: options.y,
            width: options.width, options: staveOptions
        )

        let ctx = getContext()

        for voice in params.voices {
            voice.setContext(ctx)
            _ = voice.setStave(stave)
            for tickable in voice.getTickables() {
                _ = tickable.setStave(stave)
            }
            partVoices.append(voice)
        }

        partStaves.append(stave)
        partStaveInfos.append(StaveInfo(
            noJustification: params.noJustification,
            options: staveOptions,
            spaceAbove: params.spaceAbove,
            spaceBelow: params.spaceBelow,
            debugNoteMetrics: params.debugNoteMetrics
        ))
        return stave
    }

    /// Add voices to the system (stave already assigned).
    public func addVoices(_ voices: [Voice]) {
        let ctx = getContext()
        for voice in voices {
            voice.setContext(ctx)
            partVoices.append(voice)
        }
    }

    // MARK: - Format

    private var phrase: PhraseLayout?

    /// Opt in to local phrase placement on this system and register its verses and spans. (VexFlow 5.4.0)
    public func getPhraseLayout() -> PhraseLayout {
        if let phrase { return phrase }
        let layout = PhraseLayout()
        phrase = layout
        return layout
    }

    /// Format the system: layout all staves and voices.
    /// `row` places the staves at fixed offsets and reserves end padding (continuous layout). (VexFlow 5.4.0)
    public func format(row: SystemRowLayout? = nil) {
        _ = try? formatThrowing(row: row)
    }

    public func formatThrowing(row: SystemRowLayout? = nil) throws {
        try VexRuntime.withContext(runtimeContext) {
            phrase?.resetPlacement()
            let alpha = options.details.alpha
            let fmtOptions = FormatterOptions(
                softmaxFactor: options.details.softmaxFactor,
                spacing: options.details.spacing
            )
            let formatter = Formatter(options: fmtOptions)
            self.formatter = formatter

            var y = options.y
            var startX: Double = 0
            var stanzaStartX: Double = 0
            var debugNoteMetricsYs: [(y: Double, stave: Stave)] = []

            for (index, part) in partStaves.enumerated() {
                y += part.space(partStaveInfos[index].spaceAbove)
                if let offsets = row?.staffOffsets, index < offsets.count { y = options.y + offsets[index] }
                part.setY(y)
                y += part.space(partStaveInfos[index].spaceBelow)
                y += part.space(options.spaceBetweenStaves)
                if partStaveInfos[index].debugNoteMetrics {
                    debugNoteMetricsYs.append((y: y, stave: part))
                    y += 15
                }
                // VexFlow 5.8.0: reserve a shared column for stanza labels.
                let column = phrase?.getStanzaColumnWidth(part) ?? 0
                if column != 0 { stanzaStartX = max(stanzaStartX, part.getX() + column) }
                startX = max(startX, part.getNoteStartX(), stanzaStartX)
            }

            // Re-assign stave for Y position update
            for voice in partVoices {
                for tickable in voice.getTickables() {
                    if let stave = tickable.getStave() {
                        _ = tickable.setStave(stave)
                    }
                }
            }

            _ = try formatter.joinVoicesThrowing(partVoices)

            // Update start position of all staves
            for part in partStaves {
                _ = part.setNoteStartX(startX)
            }

            var justifyWidth: Double
            if options.autoWidth && !partVoices.isEmpty {
                justifyWidth = try formatter.preCalculateMinTotalWidthThrowing(partVoices)
                options.width = justifyWidth + Stave.rightPadding + (startX - options.x) + (row?.endPadding ?? 0)
                for part in partStaves {
                    part.setWidth(options.width)
                    // Resizing invalidates the native prefix. Keep the space reserved for stanza labels.
                    if stanzaStartX != 0 { _ = part.setNoteStartX(startX) }
                }
            } else {
                if options.noPadding {
                    justifyWidth = options.width - (startX - options.x)
                } else {
                    justifyWidth = options.width - (startX - options.x) - Stave.defaultPadding
                }
            }

            if !partVoices.isEmpty {
                if !options.autoWidth { justifyWidth -= row?.endPadding ?? 0 }
                _ = try formatter.formatThrowing(
                    partVoices,
                    justifyWidth: options.noJustification ? 0 : justifyWidth,
                    options: options.formatOptions
                )
            }
            _ = formatter.postFormat()

            for _ in 0..<options.formatIterations {
                _ = formatter.tune(options: (alpha: alpha, ()))
            }

            self.startX = startX
            self.debugNoteMetricsYs = debugNoteMetricsYs
            self.lastY = y
            Stave.formatBegModifiers(partStaves)
            phrase?.format(partStaves, partVoices)
        }
    }

    // MARK: - Bounding Box

    /// Get the bounding box.
    override public func getBoundingBox() -> BoundingBox? {
        let box = BoundingBox(x: options.x, y: options.y, w: options.width, h: (lastY ?? 0) - options.y)
        if let bounds = phrase?.bounds { return box.merged(with: bounds) }
        return box
    }

    // MARK: - Draw

    /// Render the system. Draws debug information, if requested.
    override public func draw() throws {
        try VexRuntime.withContext(runtimeContext) {
            let ctx = try checkContext()
            guard let formatter, let startX, let lastY else {
                throw SystemError.drawRequiresFormat
            }
            setRendered()

            try phrase?.draw(ctx)
            if options.debugFormatter {
                Formatter.plotDebugging(
                    ctx: ctx,
                    formatter: formatter,
                    xPos: startX,
                    y1: options.y,
                    y2: lastY
                )
            }

            for debugRow in debugNoteMetricsYs {
                for voice in partVoices {
                    for tickable in voice.getTickables() {
                        guard let stave = tickable.getStave(), stave === debugRow.stave else { continue }
                        Note.plotMetrics(ctx: ctx, note: tickable, yPos: debugRow.y)
                    }
                }
            }
        }
    }
}

// MARK: - Row Layout

/// Fixed staff offsets from the system top and extra end padding for one row of a continuous score.
/// (VexFlow 5.4.0)
public struct SystemRowLayout: Sendable {
    public var staffOffsets: [Double]?
    public var endPadding: Double?

    public init(staffOffsets: [Double]? = nil, endPadding: Double? = nil) {
        self.staffOffsets = staffOffsets
        self.endPadding = endPadding
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("System", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 260) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))

        let treble = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/q, D5, E5, F5"))]
        ))
        _ = treble.addClef(.treble).addTimeSignature(.meter(4, 4))

        let bass = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C3/q, D3, E3, F3", options: ["clef": "bass"]))]
        ))
        _ = bass.addClef(.bass).addTimeSignature(.meter(4, 4))

        system.addConnector(type: .brace)
        system.addConnector(type: .singleLeft)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
