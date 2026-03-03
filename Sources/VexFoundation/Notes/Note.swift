// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Note Metrics

public enum NoteError: Error, LocalizedError, Equatable, Sendable {
    case invalidInitializationData(String)
    case noStave
    case noYValues
    case unformattedMetrics
    case noStem

    public var errorDescription: String? {
        switch self {
        case .invalidInitializationData(let duration):
            return "Invalid note initialization data: \(duration)"
        case .noStave:
            return "No stave attached to note."
        case .noYValues:
            return "No Y-values calculated for note."
        case .unformattedMetrics:
            return "Can't call getMetrics on an unformatted note."
        case .noStem:
            return "No stem attached to this note."
        }
    }
}

/// Metrics for a rendered note.
public struct NoteMetrics {
    public var width: Double = 0
    public var glyphWidth: Double?
    public var notePx: Double = 0
    public var modLeftPx: Double = 0
    public var modRightPx: Double = 0
    public var leftDisplacedHeadPx: Double = 0
    public var rightDisplacedHeadPx: Double = 0
    public var glyphPx: Double = 0
}

// MARK: - Note Duration

/// Parsed duration components.
public struct NoteDuration {
    public var value: NoteValue
    public var dots: Int
    public var type: NoteType
}

// MARK: - Parsed Note

/// Result of parsing a note struct.
public struct ParsedNote {
    public var duration: NoteValue
    public var type: NoteType
    public var customTypes: [String]
    public var dots: Int
    public var ticks: Int
}

// MARK: - Note Struct

/// Input structure for creating a note.
public struct NoteStruct {
    public var keys: [String]
    public var duration: NoteDurationSpec
    public var line: Double?
    public var dots: Int?
    public var type: NoteType?
    public var alignCenter: Bool?
    public var durationOverride: Fraction?

    public init(
        keys: [String] = [],
        duration: NoteDurationSpec,
        line: Double? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil
    ) {
        self.keys = keys
        self.duration = duration
        self.line = line
        self.dots = dots
        self.type = type
        self.alignCenter = alignCenter
        self.durationOverride = durationOverride
    }

    /// String-based parser for API boundaries and external input.
    public init(
        keys: [String] = [],
        duration: String,
        line: Double? = nil,
        dots: Int? = nil,
        type: String? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil
    ) throws {
        let parsed = try NoteDurationSpec(parsing: duration)
        let parsedType: NoteType?
        if let type {
            guard let explicitType = NoteType(parsing: type) else {
                throw NoteDurationParseError.invalidType(type)
            }
            parsedType = explicitType
        } else if parsed.type == .note {
            parsedType = nil
        } else {
            parsedType = parsed.type
        }

        self.init(
            keys: keys,
            duration: parsed,
            line: line,
            dots: dots ?? parsed.dots,
            type: parsedType,
            alignCenter: alignCenter,
            durationOverride: durationOverride
        )
    }

    /// Failable parser for convenience at call sites that don't want `throw`.
    public init?(
        parsingDuration duration: String,
        keys: [String] = [],
        line: Double? = nil,
        dots: Int? = nil,
        type: String? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil
    ) {
        guard let parsed = try? NoteStruct(
            keys: keys,
            duration: duration,
            line: line,
            dots: dots,
            type: type,
            alignCenter: alignCenter,
            durationOverride: durationOverride
        ) else { return nil }
        self = parsed
    }
}

// MARK: - Note Render Options

/// Rendering options for a note.
public struct NoteRenderOptions {
    public var drawStemThroughStave: Bool = false
    public var draw: Bool = true
    public var drawDots: Bool = true
    public var drawStem: Bool = true
    public var yShift: Double = 0
    public var extendLeft: Double?
    public var extendRight: Double?
    public var glyphFontScale: Double = 1
    public var annotationSpacing: Double = 5
    public var scale: Double = 1
    public var strokePx: Double = 1
    public var font: String?
    /// VexFlowPatch: use classical-style X notehead glyph for tab notes
    public var useAlternativeXNoteheadGlyph: Bool = false
}

// MARK: - Note

/// Abstract base class for notes and chords rendered on a stave.
/// Notes have a value (pitch, fret, etc.) and a duration (quarter, half, etc.).
open class Note: Tickable {

    override open class var category: String { "Note" }

    // MARK: - Static Parsing

    /// Parse a duration string like "4d", "8", "qr" into components.
    public static func parseDuration(_ durationString: String?) -> NoteDuration? {
        guard let durationString, !durationString.isEmpty else { return nil }
        guard let parsed = try? NoteDurationSpec(parsing: durationString) else { return nil }
        return NoteDuration(value: parsed.value, dots: parsed.dots, type: parsed.type)
    }

    /// Parse a NoteStruct into a ParsedNote.
    public static func parseNoteStruct(_ noteStruct: NoteStruct) -> ParsedNote? {
        let type = noteStruct.type ?? noteStruct.duration.type

        var customTypes: [String] = []
        for (i, k) in noteStruct.keys.enumerated() {
            let result = k.split(separator: "/").map(String.init)
            if result.count == 3 {
                customTypes.append(result[2])
            } else {
                customTypes.append(contentsOf: Array(repeating: type.rawValue, count: max(0, i + 1 - customTypes.count)))
            }
        }

        var ticks = Tables.durationToTicks(noteStruct.duration.value)

        let dots = noteStruct.dots ?? noteStruct.duration.dots

        var currentTicks = ticks
        for _ in 0..<dots {
            if currentTicks <= 1 { return nil }
            currentTicks = currentTicks / 2
            ticks += currentTicks
        }

        return ParsedNote(
            duration: noteStruct.duration.value,
            type: type,
            customTypes: customTypes,
            dots: dots,
            ticks: ticks
        )
    }

    private static func jsRound(_ value: Double) -> Int {
        if value >= 0 {
            return Int(floor(value + 0.5))
        }
        return Int(ceil(value - 0.5))
    }

    /// Debug helper. Displays formatter metrics for a tickable.
    public static func plotMetrics(ctx: RenderContext, note: Tickable, yPos: Double) {
        let metrics = note.getMetrics()
        let xStart = note.getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let xPre1 = note.getAbsoluteX() - metrics.leftDisplacedHeadPx
        let xAbs = note.getAbsoluteX()
        let xPost1 = note.getAbsoluteX() + metrics.notePx
        let xPost2 = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx
        let xEnd = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx + metrics.modRightPx
        let xFreedomRight = xEnd + note.getFormatterMetrics().freedom.right
        let xWidth = xEnd - xStart

        _ = ctx.save()
        _ = ctx.setFont(VexFont.SANS_SERIF, 8, nil, nil)
        _ = ctx.fillText("\(jsRound(xWidth))px", xStart + note.getXShift(), yPos)

        let y = yPos + 7
        func stroke(_ x1: Double, _ x2: Double, _ color: String, _ yy: Double = y) {
            _ = ctx.beginPath()
            _ = ctx.setStrokeStyle(color)
            _ = ctx.setFillStyle(color)
            _ = ctx.setLineWidth(3)
            _ = ctx.moveTo(x1 + note.getXShift(), yy)
            _ = ctx.lineTo(x2 + note.getXShift(), yy)
            _ = ctx.stroke()
        }

        stroke(xStart, xPre1, "red")
        stroke(xPre1, xAbs, "#999")
        stroke(xAbs, xPost1, "green")
        stroke(xPost1, xPost2, "#999")
        stroke(xPost2, xEnd, "red")
        stroke(xEnd, xFreedomRight, "#DD0")
        stroke(xStart - note.getXShift(), xStart, "#BBB")
        drawDot(ctx, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let deviation = formatterMetrics.space.deviation
            let prefix = deviation >= 0 ? "+" : ""
            _ = ctx.setFillStyle("red")
            _ = ctx.fillText("\(prefix)\(jsRound(deviation))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = ctx.restore()
    }

    /// Strict parse variant that throws when the input is invalid.
    public static func parseNoteStructThrowing(_ noteStruct: NoteStruct) throws -> ParsedNote {
        guard let parsed = parseNoteStruct(noteStruct) else {
            throw NoteError.invalidInitializationData(noteStruct.duration.rawValue)
        }
        return parsed
    }

    private static func fallbackParsedNote(for noteStruct: NoteStruct) -> ParsedNote {
        let resolvedType = noteStruct.type ?? noteStruct.duration.type
        let tickBase = Tables.durationToTicks(noteStruct.duration.value)
        return ParsedNote(
            duration: noteStruct.duration.value,
            type: resolvedType,
            customTypes: Array(repeating: resolvedType.rawValue, count: noteStruct.keys.count),
            dots: 0,
            ticks: tickBase
        )
    }

    // MARK: - Instance Properties

    public var glyphProps: GlyphProps!
    public var keys: [String]
    public var keyProps: [KeyProps] = []
    public var noteStave: Stave?
    public var renderOptions = NoteRenderOptions()
    public var noteValue: NoteValue
    public var noteTypeValue: NoteType
    public var noteDuration: String
    public var leftDisplacedHeadPx: Double = 0
    public var rightDisplacedHeadPx: Double = 0
    public var noteType: String
    public var customGlyphs: [GlyphProps] = []
    public var ys: [Double] = []
    public var customTypes: [String] = []
    public weak var playNote: Note?
    public weak var beam: Beam?
    public private(set) var initError: NoteError?

    // MARK: - Init

    public init(_ noteStruct: NoteStruct) {
        let parsed: ParsedNote
        let parsedError: NoteError?
        if let strict = try? Note.parseNoteStructThrowing(noteStruct) {
            parsed = strict
            parsedError = nil
        } else {
            parsed = Note.fallbackParsedNote(for: noteStruct)
            parsedError = .invalidInitializationData(noteStruct.duration.rawValue)
        }

        self.keys = noteStruct.keys
        self.noteValue = parsed.duration
        self.noteTypeValue = parsed.type
        self.noteDuration = parsed.duration.rawValue
        self.noteType = parsed.type.rawValue
        self.customTypes = parsed.customTypes
        self.initError = parsedError

        super.init()

        if let override = noteStruct.durationOverride {
            setDuration(override)
        } else {
            setIntrinsicTicks(Double(parsed.ticks))
        }

        noteModifiers = []

        self.glyphProps = Tables.getGlyphProps(duration: noteDuration, type: noteType)
        self.customGlyphs = customTypes.compactMap { Tables.getGlyphProps(duration: noteDuration, type: $0) }

        ignoreTicks = false
        tickableWidth = 0
        leftDisplacedHeadPx = 0
        rightDisplacedHeadPx = 0
        xShift = 0

        if noteStruct.alignCenter == true {
            setCenterAlignment(true)
        }
    }

    /// Strict validation initializer for call sites that require parse failures as errors.
    public convenience init(validating noteStruct: NoteStruct) throws {
        _ = try Note.parseNoteStructThrowing(noteStruct)
        self.init(noteStruct)
    }

    // MARK: - Play Note

    public func getPlayNote() -> Note? { playNote }

    @discardableResult
    public func setPlayNote(_ note: Note) -> Self {
        playNote = note
        return self
    }

    // MARK: - Rest

    open func isRest() -> Bool { false }

    // MARK: - Stave

    override public func getStave() -> Stave? { noteStave }

    public func checkStave() -> Stave {
        (try? checkStaveThrowing()) ?? Stave(x: 0, y: 0, width: 0)
    }

    public func checkStaveThrowing() throws -> Stave {
        guard let noteStave else {
            throw NoteError.noStave
        }
        return noteStave
    }

    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        noteStave = stave
        setYs([stave.getYForLine(0)])
        if let ctx = stave.getContext() {
            setContext(ctx)
        }
        return self
    }

    // MARK: - Displaced Head Pixels

    public func getLeftDisplacedHeadPx() -> Double { leftDisplacedHeadPx }
    public func getRightDisplacedHeadPx() -> Double { rightDisplacedHeadPx }

    @discardableResult
    public func setLeftDisplacedHeadPx(_ x: Double) -> Self {
        leftDisplacedHeadPx = x
        return self
    }

    @discardableResult
    public func setRightDisplacedHeadPx(_ x: Double) -> Self {
        rightDisplacedHeadPx = x
        return self
    }

    // MARK: - Parenthesis Positioning

    public func getRightParenthesisPx(index: Int) -> Double {
        let props = getKeyProps()[index]
        return props.displaced ? getRightDisplacedHeadPx() : 0
    }

    public func getLeftParenthesisPx(index: Int) -> Double {
        let props = getKeyProps()[index]
        return props.displaced ? getLeftDisplacedHeadPx() - xShift : -xShift
    }

    // MARK: - Line Numbers

    open func getLineNumber(isTopNote: Bool = false) -> Double { 0 }

    open func getLineForRest() -> Double { 0 }

    // MARK: - Glyph Properties

    public func getGlyphProps() -> GlyphProps { glyphProps }

    public func getGlyphWidth() -> Double {
        if noteTypeValue == .slash {
            return Tables.SLASH_NOTEHEAD_WIDTH
        }
        return Glyph.getWidth(code: glyphProps.codeHead, point: renderOptions.glyphFontScale)
    }

    // MARK: - Y Values

    @discardableResult
    public func setYs(_ ys: [Double]) -> Self {
        self.ys = ys
        return self
    }

    public func getYs() -> [Double] {
        (try? getYsThrowing()) ?? [0]
    }

    public func getYsThrowing() throws -> [Double] {
        guard !ys.isEmpty else {
            throw NoteError.noYValues
        }
        return ys
    }

    public func getYForTopText(_ textLine: Double) -> Double {
        checkStave().getYForTopText(textLine)
    }

    // MARK: - Duration

    public func getDuration() -> String { noteDuration }
    public func getNoteValue() -> NoteValue { noteValue }

    public func getNoteType() -> String { noteType }
    public func getNoteTypeValue() -> NoteType { noteTypeValue }

    open func hasStem() -> Bool { false }

    // MARK: - Beam

    public func hasBeam() -> Bool { beam != nil }

    @discardableResult
    public func setBeam(_ beam: Beam) -> Self {
        self.beam = beam
        return self
    }

    // MARK: - Modifiers

    @discardableResult
    override public func addModifier(_ modifier: Modifier, index: Int = 0) -> Self {
        modifier.setNote(self)
        modifier.setIndex(index)
        _ = super.addModifier(modifier)
        return self
    }

    public func getModifiersByType(_ type: String) -> [Modifier] {
        noteModifiers.filter { $0.getCategory() == type }
    }

    // MARK: - Metrics

    override open func getMetrics() -> NoteMetrics {
        (try? getMetricsThrowing()) ?? NoteMetrics(
            width: tickableWidth,
            glyphWidth: getGlyphWidth(),
            notePx: tickableWidth,
            modLeftPx: 0,
            modRightPx: 0,
            leftDisplacedHeadPx: leftDisplacedHeadPx,
            rightDisplacedHeadPx: rightDisplacedHeadPx,
            glyphPx: 0
        )
    }

    open func getMetricsThrowing() throws -> NoteMetrics {
        guard preFormatted else {
            throw NoteError.unformattedMetrics
        }

        let modLeftPx = modifierContext?.getState().leftShift ?? 0
        let modRightPx = modifierContext?.getState().rightShift ?? 0
        let width = try getTickableWidthThrowing()
        let glyphWidth = getGlyphWidth()
        let notePx = width - modLeftPx - modRightPx - leftDisplacedHeadPx - rightDisplacedHeadPx

        return NoteMetrics(
            width: width,
            glyphWidth: glyphWidth,
            notePx: notePx,
            modLeftPx: modLeftPx,
            modRightPx: modRightPx,
            leftDisplacedHeadPx: leftDisplacedHeadPx,
            rightDisplacedHeadPx: rightDisplacedHeadPx,
            glyphPx: 0
        )
    }

    // MARK: - Absolute X

    override public func getAbsoluteX() -> Double {
        let tc = checkTickContext("Can't getAbsoluteX() without a TickContext.")
        var x = tc.getX()
        if let stave = noteStave {
            let padding = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("stave.padding") as? Double) ?? 0
            x += stave.getNoteStartX() + padding
        }
        if isCenterAligned() {
            x += getCenterXShift()
        }
        return x
    }

    /// Get point size for notes.
    public static func getPoint(_ size: String? = nil) -> Double {
        size == "default" ? Tables.NOTATION_FONT_SCALE : (Tables.NOTATION_FONT_SCALE / 5) * 3
    }

    // MARK: - Stem (default - overridden by StemmableNote)

    open func getStemDirection() -> StemDirection {
        (try? getStemDirectionThrowing()) ?? Stem.UP
    }

    open func getStemDirectionThrowing() throws -> StemDirection {
        throw NoteError.noStem
    }

    open func getStemExtents() -> (topY: Double, baseY: Double) {
        (try? getStemExtentsThrowing()) ?? (topY: 0, baseY: 0)
    }

    open func getStemExtentsThrowing() throws -> (topY: Double, baseY: Double) {
        throw NoteError.noStem
    }

    // MARK: - Modifier Start Position

    /// Get the coordinates for where modifiers begin.
    /// Overridden by StaveNote with more precise positioning.
    open func getModifierStartXY(position: ModifierPosition, index: Int) -> (x: Double, y: Double) {
        let x = getAbsoluteX()
        let y = ys.isEmpty ? 0 : ys[0]
        return (x, y)
    }

    // MARK: - Tie Positions

    public func getTieRightX() -> Double {
        var tieStartX = getAbsoluteX()
        let noteGlyphWidth = getGlyphWidth()
        tieStartX += noteGlyphWidth / 2
        tieStartX += -tickableWidth / 2 + tickableWidth + 2
        return tieStartX
    }

    public func getTieLeftX() -> Double {
        var tieEndX = getAbsoluteX()
        let noteGlyphWidth = getGlyphWidth()
        tieEndX += noteGlyphWidth / 2
        tieEndX -= tickableWidth / 2 + 2
        return tieEndX
    }

    // MARK: - Keys

    public func getKeys() -> [String] { keys }
    public func getKeyProps() -> [KeyProps] { keyProps }
}
