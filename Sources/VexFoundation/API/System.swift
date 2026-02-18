// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - System Types

/// Formatter options extended with alpha for tuning.
public struct SystemFormatterOptions {
    public var alpha: Double = 0.5

    public init(alpha: Double = 0.5) {
        self.alpha = alpha
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

    public init(factory: Factory? = nil, noPadding: Bool = false,
                debugFormatter: Bool = false, spaceBetweenStaves: Double = 12,
                formatIterations: Int = 0, autoWidth: Bool = false,
                x: Double = 10, width: Double = 500, y: Double = 10,
                details: SystemFormatterOptions = SystemFormatterOptions(),
                formatOptions: FormatParams = FormatParams(),
                noJustification: Bool = false) {
        self.factory = factory
        self.noPadding = noPadding
        self.debugFormatter = debugFormatter
        self.spaceBetweenStaves = spaceBetweenStaves
        self.formatIterations = formatIterations
        self.autoWidth = autoWidth
        self.x = x
        self.width = width
        self.y = y
        self.details = details
        self.formatOptions = formatOptions
        self.noJustification = noJustification
    }
}

// MARK: - System

/// A musical system: a collection of staves with voices, formatted together.
public final class System: VexElement {

    override public class var CATEGORY: String { "System" }

    // MARK: - Properties

    private var options: SystemOptions
    private var factory: Factory
    private var formatter: Formatter?
    private var startX: Double?
    private var lastY: Double?
    private var partStaves: [Stave] = []
    private var partStaveInfos: [StaveInfo] = []
    private var partVoices: [Voice] = []
    private var connector: StaveConnector?

    // MARK: - Init

    public init(options: SystemOptions = SystemOptions()) {
        guard let factory = options.factory else {
            fatalError("[VexError] NoFactory: System requires a factory.")
        }
        self.factory = factory
        self.options = options
        if options.noJustification == false && options.width == 500 {
            self.options.autoWidth = true
        }
        super.init()
    }

    // MARK: - Accessors

    public func getX() -> Double { options.x }

    public func setX(_ x: Double) {
        options.x = x
        partStaves.forEach { _ = $0.setStaveX(x) }
    }

    public func getY() -> Double { options.y }

    public func setY(_ y: Double) {
        options.y = y
        partStaves.forEach { _ = $0.setStaveY(y) }
    }

    public func getStaves() -> [Stave] { partStaves }
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
        let conn = factory.StaveConnector(
            topStave: partStaves[0],
            bottomStave: partStaves[partStaves.count - 1],
            type: type
        )
        connector = conn
        return conn
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
            if let ctx { _ = voice.setContext(ctx) }
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
            if let ctx { _ = voice.setContext(ctx) }
            partVoices.append(voice)
        }
    }

    // MARK: - Format

    /// Format the system: layout all staves and voices.
    public func format() {
        let alpha = options.details.alpha
        let fmtOptions = FormatterOptions(softmaxFactor: Tables.SOFTMAX_FACTOR)
        let formatter = Formatter(options: fmtOptions)
        self.formatter = formatter

        var y = options.y
        var startX: Double = 0

        for (index, part) in partStaves.enumerated() {
            y += part.space(partStaveInfos[index].spaceAbove)
            _ = part.setStaveY(y)
            y += part.space(partStaveInfos[index].spaceBelow)
            y += part.space(options.spaceBetweenStaves)
            startX = max(startX, part.getNoteStartX())
        }

        // Re-assign stave for Y position update
        for voice in partVoices {
            for tickable in voice.getTickables() {
                if let stave = tickable.getStave() {
                    _ = tickable.setStave(stave)
                }
            }
        }

        _ = formatter.joinVoices(partVoices)

        // Update start position of all staves
        for part in partStaves {
            _ = part.setNoteStartX(startX)
        }

        var justifyWidth: Double
        if options.autoWidth && !partVoices.isEmpty {
            justifyWidth = formatter.preCalculateMinTotalWidth(partVoices)
            options.width = justifyWidth + Stave.rightPadding + (startX - options.x)
            for part in partStaves {
                _ = part.setStaveWidth(options.width)
            }
        } else {
            if options.noPadding {
                justifyWidth = options.width - (startX - options.x)
            } else {
                justifyWidth = options.width - (startX - options.x) - Stave.defaultPadding
            }
        }

        if !partVoices.isEmpty {
            _ = formatter.format(
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
        self.lastY = y
        self.boundingBox = BoundingBox(
            x: options.x, y: options.y,
            w: options.width, h: y - options.y
        )
        Stave.formatBegModifiers(partStaves)
    }

    // MARK: - Draw

    override public func draw() throws {
        guard formatter != nil, startX != nil, lastY != nil else {
            fatalError("[VexError] NoFormatter: format() must be called before draw()")
        }
        setRendered()
    }
}
