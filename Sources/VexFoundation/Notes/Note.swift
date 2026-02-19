// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Note Metrics

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

    // MARK: - Instance Properties

    public var glyphProps: GlyphProps!
    public var keys: [String]
    public var keyProps: [KeyProps] = []
    public weak var noteStave: Stave?
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

    // MARK: - Init

    public init(_ noteStruct: NoteStruct) {
        guard let parsed = Note.parseNoteStruct(noteStruct) else {
            fatalError("[VexError] BadArguments: Invalid note initialization data: \(noteStruct.duration.rawValue)")
        }

        self.keys = noteStruct.keys
        self.noteValue = parsed.duration
        self.noteTypeValue = parsed.type
        self.noteDuration = parsed.duration.rawValue
        self.noteType = parsed.type.rawValue
        self.customTypes = parsed.customTypes

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
        guard let noteStave else {
            fatalError("[VexError] NoStave: No stave attached to instance.")
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
        Glyph.getWidth(code: glyphProps.codeHead, point: renderOptions.glyphFontScale)
    }

    // MARK: - Y Values

    @discardableResult
    public func setYs(_ ys: [Double]) -> Self {
        self.ys = ys
        return self
    }

    public func getYs() -> [Double] {
        guard !ys.isEmpty else {
            fatalError("[VexError] NoYValues: No Y-values calculated for this note.")
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
        guard preFormatted else {
            fatalError("[VexError] UnformattedNote: Can't call getMetrics on an unformatted note.")
        }

        let modLeftPx = modifierContext?.getState().leftShift ?? 0
        let modRightPx = modifierContext?.getState().rightShift ?? 0
        let width = getTickableWidth()
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
            let musicFont = Glyph.MUSIC_FONT_STACK.first!
            let padding = (musicFont.lookupMetric("stave.padding") as? Double) ?? 0
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
        fatalError("[VexError] NoStem: No stem attached to this note.")
    }

    open func getStemExtents() -> (topY: Double, baseY: Double) {
        fatalError("[VexError] NoStem: No stem attached to this note.")
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
