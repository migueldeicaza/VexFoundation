// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/note.ts` (VexFlow 5.1.0).

import Foundation

public enum NoteError: Error, LocalizedError, Equatable, Sendable {
    case invalidInitializationData(String)
    case noStave
    case noYValues
    case unformattedMetrics
    case unformattedNote
    case noStem
    case noBeam

    public var errorDescription: String? {
        switch self {
        case .invalidInitializationData(let duration):
            return "Invalid note initialization object: \(duration)"
        case .noStave:
            return "No stave attached to instance."
        case .noYValues:
            return "No Y-values calculated for this note."
        case .unformattedMetrics:
            return "Can't call getMetrics on an unformatted note."
        case .unformattedNote:
            return "Can't call GetModifierStartXY on an unformatted note"
        case .noStem:
            return "No stem attached to this note."
        case .noBeam:
            return "No beam attached to instance"
        }
    }
}

// MARK: - Glyph Properties

/// Properties for a note glyph at a given duration (upstream `GlyphProps` in `note.ts`).
public struct GlyphProps: Sendable, Equatable {
    public var codeHead: String
    public var stemBeamExtension: Double
    public var stem: Bool
    public var codeFlagUp: String?
    public var beamCount: Int

    public init(
        codeHead: String = "",
        stemBeamExtension: Double = 0,
        stem: Bool = false,
        codeFlagUp: String? = nil,
        beamCount: Int = 0
    ) {
        self.codeHead = codeHead
        self.stemBeamExtension = stemBeamExtension
        self.stem = stem
        self.codeFlagUp = codeFlagUp
        self.beamCount = beamCount
    }
}

// MARK: - Key Properties

/// Properties for a note key (pitch/octave) on a staff (upstream `KeyProps` in `note.ts`).
public struct KeyProps: Sendable, Equatable {
    public var key: String
    public var octave: Int
    public var line: Double
    public var intValue: Int?
    public var code: String?
    public var displaced: Bool
    /// VexFlowPatch: notehead shifts independent of stem length (see `docs/local-deviations.md`).
    public var stemDownXOffset: Double = 0
    public var stemUpXOffset: Double = 0
    public var stemUpYShift: Double = 0
    public var stemDownYShift: Double = 0

    public init(
        key: String,
        octave: Int,
        line: Double,
        intValue: Int? = nil,
        code: String? = nil,
        displaced: Bool = false
    ) {
        self.key = key
        self.octave = octave
        self.line = line
        self.intValue = intValue
        self.code = code
        self.displaced = displaced
    }
}

// MARK: - Note Metrics

/// Metrics for a rendered note.
public struct NoteMetrics {
    /// The total width of the note (including modifiers).
    public var width: Double = 0
    public var glyphWidth: Double?
    /// The width of the note head only.
    public var notePx: Double = 0
    /// Start `X` for left modifiers.
    public var modLeftPx: Double = 0
    /// Start `X` for right modifiers.
    public var modRightPx: Double = 0
    /// Extra space on left of note.
    public var leftDisplacedHeadPx: Double = 0
    /// Extra space on right of note.
    public var rightDisplacedHeadPx: Double = 0
    public var glyphPx: Double = 0

    public init(
        width: Double = 0,
        glyphWidth: Double? = nil,
        notePx: Double = 0,
        modLeftPx: Double = 0,
        modRightPx: Double = 0,
        leftDisplacedHeadPx: Double = 0,
        rightDisplacedHeadPx: Double = 0,
        glyphPx: Double = 0
    ) {
        self.width = width
        self.glyphWidth = glyphWidth
        self.notePx = notePx
        self.modLeftPx = modLeftPx
        self.modRightPx = modRightPx
        self.leftDisplacedHeadPx = leftDisplacedHeadPx
        self.rightDisplacedHeadPx = rightDisplacedHeadPx
        self.glyphPx = glyphPx
    }
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
    /// The duration token as the caller wrote it (upstream `Note.parseDuration(...).duration`,
    /// for example `"w"`, `"h"`, `"8"`). `nil` uses the canonical value (`duration.value.rawValue`).
    /// Upstream keeps this string as `Note.duration` and compares it as a string in
    /// `StaveNote.format()`.
    public var durationToken: String?

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
        self.durationToken = Note.durationToken(of: duration)
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
/// Upstream optional flags (`draw`, `drawDots`, `drawStem`, `drawStemThroughStave`)
/// are `Bool` with the default that upstream `undefined` has at the use sites.
public struct NoteRenderOptions {
    public var drawStemThroughStave: Bool = false
    public var draw: Bool = true
    public var drawDots: Bool = true
    public var drawStem: Bool = true
    public var yShift: Double = 0
    public var extendLeft: Double?
    public var extendRight: Double?
    public var annotationSpacing: Double = 5
    public var strokePx: Double = 1
    /// VexFlowPatch: use classical-style X notehead glyph for tab notes
    public var useAlternativeXNoteheadGlyph: Bool = false

    public init() {}
}

// MARK: - Note

/// Note implements an abstract interface for notes and chords that
/// are rendered on a stave. Notes have some common properties: All of them
/// have a value (e.g., pitch, fret, etc.) and a duration (quarter, half, etc.)
///
/// Some notes have stems, heads, dots, etc. Most notational elements that
/// surround a note are called *modifiers*, and every note has an associated
/// array of them. All notes also have a rendering context and belong to a stave.
open class Note: Tickable {

    override open class var category: String { "Note" }

    // MARK: - Static

    /// Return a glyph given duration and type. The type can be a custom glyph code from customNoteHeads.
    /// The default type is a regular note ('n').
    public static func getGlyphProps(_ duration: String, _ type: String = "n") -> GlyphProps {
        let duration = Tables.sanitizeDuration(duration)

        // Lookup duration for default glyph head code
        var code = Tables.durationCodes[duration] ?? Tables.durationCodes["4"] ?? GlyphProps(stem: true)

        // Try and get the note head
        let codeNoteHead = Tables.codeNoteHead(type.uppercased(), duration: duration)
        // Merge duration props for 'duration' with the note head properties.
        if codeNoteHead != Glyphs.null {
            code.codeHead = codeNoteHead
        }

        return code
    }

    /// Typed variant of `getGlyphProps(_:_:)`.
    public static func getGlyphProps(_ duration: NoteValue, _ type: NoteType = .note) -> GlyphProps {
        getGlyphProps(duration.rawValue, type.rawValue)
    }

    private static func jsRound(_ value: Double) -> Int {
        Int((value + 0.5).rounded(.down))
    }

    /// Debug helper. Displays various note metrics for the given note.
    public static func plotMetrics(_ ctx: RenderContext, _ note: Tickable, _ yPos: Double) {
        let metrics = note.getMetrics()
        let xStart = note.getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let xPre1 = note.getAbsoluteX() - metrics.leftDisplacedHeadPx
        let xAbs = note.getAbsoluteX()
        let xPost1 = note.getAbsoluteX() + metrics.notePx
        let xPost2 = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx
        let xEnd = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx + metrics.modRightPx
        let xFreedomRight = xEnd + note.getFormatterMetrics().freedom.right

        let xWidth = xEnd - xStart
        ctx.save()
        ctx.setFont(Metrics.getString("fontFamily"), 8, nil, nil)
        ctx.fillText("\(jsRound(xWidth))px", xStart + note.getXShift(), yPos)

        let y = yPos + 7
        func stroke(_ x1: Double, _ x2: Double, _ color: String, _ yy: Double = y) {
            ctx.beginPath()
            ctx.setStrokeStyle(color)
            ctx.setFillStyle(color)
            ctx.setLineWidth(3)
            ctx.moveTo(x1 + note.getXShift(), yy)
            ctx.lineTo(x2 + note.getXShift(), yy)
            ctx.stroke()
        }

        stroke(xStart, xPre1, "red")
        stroke(xPre1, xAbs, "#999")
        stroke(xAbs, xPost1, "green")
        stroke(xPost1, xPost2, "#999")
        stroke(xPost2, xEnd, "red")
        stroke(xEnd, xFreedomRight, "#DD0")
        stroke(xStart - note.getXShift(), xStart, "#BBB") // Shift
        drawDot(ctx, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let spaceDeviation = formatterMetrics.space.deviation
            let prefix = spaceDeviation >= 0 ? "+" : ""
            ctx.setFillStyle("red")
            ctx.fillText("\(prefix)\(jsRound(spaceDeviation))", xAbs + note.getXShift(), yPos - 10)
        }
        ctx.restore()
    }

    @available(*, deprecated, renamed: "plotMetrics(_:_:_:)")
    public static func plotMetrics(ctx: RenderContext, note: Tickable, yPos: Double) {
        plotMetrics(ctx, note, yPos)
    }

    /// Parse a duration string like "4d", "8", "qr" into components.
    /// The duration part of a duration string, as upstream `Note.parseDuration()` returns it
    /// (5.1.0: `/^(\d+(?:\/\d+)?|[a-z])(d*)([nrhms]?)$/`, group 1). For example `"hd"` gives `"h"`
    /// and `"8r"` gives `"8"`. Durations are short tokens: longer strings give `nil`.
    public static func durationToken(of durationString: String) -> String? {
        guard durationString.count <= 64,
              let regex = try? NSRegularExpression(pattern: "^(\\d+(?:\\/\\d+)?|[a-z])(d*)([nrhms]?)$")
        else {
            return nil
        }
        let range = NSRange(durationString.startIndex..., in: durationString)
        guard let match = regex.firstMatch(in: durationString, range: range),
              let tokenRange = Range(match.range(at: 1), in: durationString)
        else { return nil }
        return String(durationString[tokenRange])
    }

    public static func parseDuration(_ durationString: String?) -> NoteDuration? {
        // Durations are short tokens. Bound work before parsing untrusted score text.
        guard let durationString, !durationString.isEmpty, durationString.count <= 64 else { return nil }
        guard let parsed = try? NoteDurationSpec(parsing: durationString) else { return nil }
        return NoteDuration(value: parsed.value, dots: parsed.dots, type: parsed.type)
    }

    /// Parse a NoteStruct into a ParsedNote.
    public static func parseNoteStruct(_ noteStruct: NoteStruct) -> ParsedNote? {
        // If no type specified, check duration or custom types
        var customTypes: [String] = []
        let type: NoteType
        if let explicitType = noteStruct.type {
            type = explicitType
        } else {
            type = noteStruct.duration.type

            // If we have keys, try and check if we've got a custom glyph
            for k in noteStruct.keys {
                let result = k.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                // We have a custom glyph specified after the note eg. /X2
                customTypes.append(result.count == 3 ? result[2] : type.rawValue)
            }
        }

        // Calculate the tick duration of the note
        var ticks = Tables.durationToTicks(noteStruct.duration.value)
        if ticks == 0 { return nil }

        // Are there any dots?
        let dots = noteStruct.dots ?? noteStruct.duration.dots

        // Add ticks as necessary depending on the number of dots
        var currentTicks = ticks
        for _ in 0..<max(0, dots) {
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
            customTypes: noteStruct.type == nil
                ? Array(repeating: resolvedType.rawValue, count: noteStruct.keys.count)
                : [],
            dots: 0,
            ticks: tickBase
        )
    }

    // MARK: - Instance Properties

    public var glyphProps: GlyphProps
    public var keys: [String]
    /// Per-pitch properties.
    public var keyProps: [KeyProps] = []

    public var stave: Stave?
    public var renderOptions = NoteRenderOptions()
    /// The duration (sanitized, e.g. "4", "8", "1/2").
    public var duration: String
    /// The duration token as the caller wrote it (upstream `this.duration`, for example `"w"`).
    /// Upstream `StaveNote.format()` compares this string.
    public var durationToken: String
    public var leftDisplacedHeadPx: Double = 0
    public var rightDisplacedHeadPx: Double = 0
    public var noteType: String
    public var customGlyphs: [GlyphProps] = []
    public var ys: [Double] = []
    public var customTypes: [String] = []
    public weak var playNote: Note?
    public weak var beam: Beam?

    /// Swift typed views of `duration` and `noteType`.
    public var noteValue: NoteValue
    public var noteTypeValue: NoteType
    /// Set when the note struct did not parse (the note uses fallback values).
    public private(set) var initError: NoteError?

    // MARK: - Source compatibility

    @available(*, deprecated, renamed: "stave")
    public var noteStave: Stave? {
        get { stave }
        set { stave = newValue }
    }

    @available(*, deprecated, renamed: "duration")
    public var noteDuration: String {
        get { duration }
        set { duration = newValue }
    }

    // MARK: - Init

    /// Every note is a tickable, i.e., it can be mutated by the `Formatter` class for
    /// positioning and layout.
    public init(_ noteStruct: NoteStruct) {
        // Parses `noteStruct` and get note properties.
        let parsed: ParsedNote
        let parsedError: NoteError?
        if let strict = Note.parseNoteStruct(noteStruct) {
            parsed = strict
            parsedError = nil
        } else {
            parsed = Note.fallbackParsedNote(for: noteStruct)
            parsedError = .invalidInitializationData(noteStruct.duration.rawValue)
        }

        // Set note properties from parameters.
        self.keys = noteStruct.keys
        self.duration = parsed.duration.rawValue
        self.durationToken = noteStruct.durationToken ?? parsed.duration.rawValue
        self.noteType = parsed.type.rawValue
        self.noteValue = parsed.duration
        self.noteTypeValue = parsed.type
        self.customTypes = parsed.customTypes
        self.initError = parsedError

        // Get the glyph code for this note from the font.
        self.glyphProps = Note.getGlyphProps(parsed.duration.rawValue, parsed.type.rawValue)

        super.init()

        if let durationOverride = noteStruct.durationOverride {
            // Custom duration
            setDuration(durationOverride)
        } else {
            // Default duration
            setIntrinsicTicks(Double(parsed.ticks))
        }

        modifiers = []

        customGlyphs = customTypes.map { Note.getGlyphProps(duration, $0) }

        // Note to play for audio players.
        playNote = nil

        // Positioning contexts used by the Formatter.
        ignoreTicks = false

        // Positioning variables
        width = 0 // Width in pixels calculated after preFormat
        leftDisplacedHeadPx = 0 // Extra room on left for displaced note head
        rightDisplacedHeadPx = 0 // Extra room on right for displaced note head
        xShift = 0 // X shift from tick context X
        ys = [] // list of y coordinates for each note
        // we need to hold on to these for ties and beams.

        if noteStruct.alignCenter == true {
            setCenterAlignment(true)
        }

        // The render surface.
        renderOptions = NoteRenderOptions()
    }

    /// Strict validation initializer for call sites that require parse failures as errors.
    public convenience init(validating noteStruct: NoteStruct) throws {
        _ = try Note.parseNoteStructThrowing(noteStruct)
        self.init(noteStruct)
    }

    // MARK: - Play Note

    /// Get the play note, which is arbitrary data that can be used by an audio player.
    public func getPlayNote() -> Note? { playNote }

    /// Set the play note, which is arbitrary data that can be used by an audio player.
    @discardableResult
    public func setPlayNote(_ note: Note) -> Self {
        playNote = note
        return self
    }

    // MARK: - Rest

    /// Return true if this note is a type of rest.
    ///
    /// Rests don't have pitches, but take up space in the score.
    /// Subclasses should override this default implementation.
    open func isRest() -> Bool { false }

    // MARK: - Stroke

    /// Add stroke.
    @discardableResult
    open func addStroke(_ index: Int, _ stroke: Stroke) -> Self {
        stroke.setNote(self)
        stroke.setIndex(index)
        modifiers.append(stroke)
        preFormatted = false
        return self
    }

    // MARK: - Stave

    /// Get the target stave.
    override open func getStave() -> Stave? { stave }

    /// Check and get the target stave.
    public func checkStave() -> Stave {
        (try? checkStaveThrowing()) ?? Stave(x: 0, y: 0, width: 0)
    }

    public func checkStaveThrowing() throws -> Stave {
        guard let stave else {
            throw NoteError.noStave
        }
        return stave
    }

    /// Set the target stave.
    @discardableResult
    override open func setStave(_ stave: Stave) -> Self {
        self.stave = stave
        setYs([stave.getYForLine(0)]) // Update Y values if the stave is changed.
        setContext(stave.getContext())
        return self
    }

    // MARK: - Displaced Head Pixels

    /// Get spacing to the left of the notes.
    public func getLeftDisplacedHeadPx() -> Double { leftDisplacedHeadPx }

    /// Get spacing to the right of the notes.
    public func getRightDisplacedHeadPx() -> Double { rightDisplacedHeadPx }

    /// Set spacing to the left of the notes.
    @discardableResult
    public func setLeftDisplacedHeadPx(_ x: Double) -> Self {
        leftDisplacedHeadPx = x
        return self
    }

    /// Set spacing to the right of the notes.
    @discardableResult
    public func setRightDisplacedHeadPx(_ x: Double) -> Self {
        rightDisplacedHeadPx = x
        return self
    }

    // MARK: - Line Numbers

    /// Get the stave line number for the note.
    open func getLineNumber(isTopNote: Bool = false) -> Double { 0 }

    /// Get the stave line number for rest.
    open func getLineForRest() -> Double { 0 }

    // MARK: - Glyph Properties

    /// Get the glyph associated with this note.
    public func getGlyphProps() -> GlyphProps { glyphProps }

    /// Get the glyph width.
    open func getGlyphWidth() -> Double { 0 }

    // MARK: - Y Values

    /// Set Y positions for this note. Each Y value is associated with
    /// an individual pitch/key within the note/chord.
    @discardableResult
    open func setYs(_ ys: [Double]) -> Self {
        self.ys = ys
        return self
    }

    /// Get Y positions for this note. Each Y value is associated with
    /// an individual pitch/key within the note/chord.
    /// Returns `[0]` when there are no Y values; see `getYsThrowing()`.
    open func getYs() -> [Double] {
        (try? getYsThrowing()) ?? [0]
    }

    public func getYsThrowing() throws -> [Double] {
        guard !ys.isEmpty else {
            throw NoteError.noYValues
        }
        return ys
    }

    /// Get the Y position of the space above the stave onto which text can
    /// be rendered.
    open func getYForTopText(_ textLine: Double) -> Double {
        checkStave().getYForTopText(textLine)
    }

    // MARK: - Voice / Tick Context

    /// Attach this note to `voice`.
    @discardableResult
    override open func setVoice(_ voice: Voice) -> Self {
        self.voice = voice
        preFormatted = false
        return self
    }

    /// Get the `TickContext` for this note.
    public func getTickContext() -> TickContext {
        checkTickContext()
    }

    // MARK: - Duration

    /// Accessor to duration.
    public func getDuration() -> String { duration }
    public func getNoteValue() -> NoteValue { noteValue }

    /// Accessor to isDotted.
    public func isDotted() -> Bool {
        !getModifiersByType("Dot").isEmpty
    }

    /// Accessor to hasStem.
    open func hasStem() -> Bool { false }

    /// Accessor to note type.
    public func getNoteType() -> String { noteType }
    public func getNoteTypeValue() -> NoteType { noteTypeValue }

    // MARK: - Beam

    /// Get the beam.
    public func getBeam() -> Beam? { beam }

    /// Check and get the beam.
    public func checkBeam() throws -> Beam {
        guard let beam else {
            throw NoteError.noBeam
        }
        return beam
    }

    /// Check it has a beam.
    public func hasBeam() -> Bool { beam != nil }

    /// Set the beam.
    @discardableResult
    open func setBeam(_ beam: Beam) -> Self {
        self.beam = beam
        return self
    }

    // MARK: - Modifiers

    /// Attach a modifier to this note.
    /// - Parameters:
    ///   - modifier: the Modifier to add.
    ///   - index: of the key to modify.
    @discardableResult
    override open func addModifier(_ modifier: Modifier, index: Int = 0) -> Self {
        modifier.setNote(self)
        modifier.setIndex(index)
        super.addModifier(modifier, index: index)
        return self
    }

    /// Get all modifiers of a specific type in `modifiers`.
    public func getModifiersByType(_ type: String) -> [Modifier] {
        modifiers.filter { $0.getCategory() == type }
    }

    /// Get the coordinates for where modifiers begin.
    /// `forceFlagRight` is upstream `options.forceFlagRight` (used by `StaveNote`).
    /// Does not throw for an unformatted note; see `getModifierStartXYThrowing`.
    open func getModifierStartXY(
        position: ModifierPosition,
        index: Int,
        forceFlagRight: Bool = false
    ) -> (x: Double, y: Double) {
        (x: getAbsoluteX(), y: ys.first ?? 0)
    }

    /// Throws when the note is not pre-formatted (upstream behavior).
    open func getModifierStartXYThrowing(
        position: ModifierPosition,
        index: Int,
        forceFlagRight: Bool = false
    ) throws -> (x: Double, y: Double) {
        guard preFormatted else {
            throw NoteError.unformattedNote
        }
        return getModifierStartXY(position: position, index: index, forceFlagRight: forceFlagRight)
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

    open func getFirstDotPx() -> Double {
        var px = getRightDisplacedHeadPx()
        let parentheses = checkModifierContext().getMembers("Parenthesis")

        // consider parentheses on noteheads, dots should be to the right of them
        if let first = parentheses.first {
            px += first.getWidth() + 1
        }
        return px
    }

    // MARK: - Metrics

    /// Get the metrics for this note.
    /// Does not throw for an unformatted note; see `getMetricsThrowing()`.
    override open func getMetrics() -> NoteMetrics {
        (try? getMetricsThrowing()) ?? computeMetrics()
    }

    open func getMetricsThrowing() throws -> NoteMetrics {
        guard preFormatted else {
            throw NoteError.unformattedMetrics
        }
        return computeMetrics()
    }

    private func computeMetrics() -> NoteMetrics {
        let modLeftPx = modifierContext?.getState().leftShift ?? 0
        let modRightPx = modifierContext?.getState().rightShift ?? 0
        let width = getWidth()
        let glyphWidth = getGlyphWidth()
        let notePx = width
            - modLeftPx // subtract left modifiers
            - modRightPx // subtract right modifiers
            - leftDisplacedHeadPx // subtract left displaced head
            - rightDisplacedHeadPx // subtract right displaced head

        return NoteMetrics(
            width: width,
            glyphWidth: glyphWidth,
            notePx: notePx,
            // Modifier spacing.
            modLeftPx: modLeftPx,
            modRightPx: modRightPx,
            // Displaced note head on left or right.
            leftDisplacedHeadPx: leftDisplacedHeadPx,
            rightDisplacedHeadPx: rightDisplacedHeadPx,
            glyphPx: 0
        )
    }

    // MARK: - Absolute X

    /// Get the absolute `X` position of this note's tick context. This
    /// excludes xShift, so you'll need to factor it in if you're
    /// looking for the post-formatted x-position.
    override open func getAbsoluteX() -> Double {
        let tickContext = checkTickContext("Can't getAbsoluteX() without a TickContext.")
        // Position note to left edge of tick context.
        var x = tickContext.getX()
        if let stave {
            x += stave.getNoteStartX() + Metrics.getDouble("Stave.padding", 0)
        }
        if isCenterAligned() {
            x += getCenterXShift()
        }
        return x
    }

    // MARK: - Stem (default - overridden by StemmableNote)

    /// Get the direction of the stem.
    open func getStemDirection() -> StemDirection {
        (try? getStemDirectionThrowing()) ?? Stem.UP
    }

    open func getStemDirectionThrowing() throws -> StemDirection {
        throw NoteError.noStem
    }

    /// Get the top and bottom `y` values of the stem.
    open func getStemExtents() -> (topY: Double, baseY: Double) {
        (try? getStemExtentsThrowing()) ?? (topY: 0, baseY: 0)
    }

    open func getStemExtentsThrowing() throws -> (topY: Double, baseY: Double) {
        throw NoteError.noStem
    }

    // MARK: - Tie Positions

    /// Get the `x` coordinate to the right of the note.
    open func getTieRightX() -> Double {
        var tieStartX = getAbsoluteX()
        let noteGlyphWidth = getGlyphWidth()
        tieStartX += noteGlyphWidth / 2
        tieStartX += -width / 2 + width + 2
        return tieStartX
    }

    /// Get the `x` coordinate to the left of the note.
    open func getTieLeftX() -> Double {
        var tieEndX = getAbsoluteX()
        let noteGlyphWidth = getGlyphWidth()
        tieEndX += noteGlyphWidth / 2
        tieEndX -= width / 2 + 2
        return tieEndX
    }

    // MARK: - Keys

    /// Get the pitches in the note.
    public func getKeys() -> [String] { keys }

    /// Get the properties for all the keys in the note.
    public func getKeyProps() -> [KeyProps] { keyProps }

    // MARK: - Bounding Box

    /// Get the `BoundingBox` for the entire note.
    override open func getBoundingBox() -> BoundingBox? {
        guard var boundingBox = super.getBoundingBox() else { return nil }
        for modifier in modifiers {
            if let bb = modifier.getBoundingBox() {
                boundingBox.mergeWith(bb)
            }
        }
        return boundingBox
    }
}
