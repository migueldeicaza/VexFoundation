// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/notehead.ts` (VexFlow 5.1.0).

import Foundation

// MARK: - NoteHead Struct

/// Input structure for creating a NoteHead (upstream `NoteHeadStruct extends NoteStruct`).
public struct NoteHeadStruct {
    public var duration: NoteValue
    public var line: Double
    public var slashed: Bool
    public var style: ElementStyle?
    /// VexFlowPatch: x shift of a custom notehead when the stem is down (TI notehead, gated in Tables).
    public var stemDownXOffset: Double
    /// VexFlowPatch: x shift of a custom notehead when the stem is up (TI notehead, gated in Tables).
    public var stemUpXOffset: Double
    /// VexFlowPatch: vertical shift for notehead when stem is up (independent of stem length)
    public var stemUpYShift: Double
    /// VexFlowPatch: vertical shift for notehead when stem is down (independent of stem length)
    public var stemDownYShift: Double
    public var customGlyphCode: String?
    public var stemDirection: StemDirection
    public var displaced: Bool
    public var noteType: NoteType?
    public var x: Double
    public var y: Double
    public var index: Int?
    public var keys: [String]
    public var dots: Int?

    public init(
        duration: NoteValue = .quarter,
        line: Double = 0,
        slashed: Bool = false,
        style: ElementStyle? = nil,
        stemDownXOffset: Double = 0,
        stemUpXOffset: Double = 0,
        stemUpYShift: Double = 0,
        stemDownYShift: Double = 0,
        customGlyphCode: String? = nil,
        stemDirection: StemDirection = .up,
        displaced: Bool = false,
        noteType: NoteType? = nil,
        x: Double = 0,
        y: Double = 0,
        index: Int? = nil,
        keys: [String] = [],
        dots: Int? = nil
    ) {
        self.duration = duration
        self.line = line
        self.slashed = slashed
        self.style = style
        self.stemDownXOffset = stemDownXOffset
        self.stemUpXOffset = stemUpXOffset
        self.stemUpYShift = stemUpYShift
        self.stemDownYShift = stemDownYShift
        self.customGlyphCode = customGlyphCode
        self.stemDirection = stemDirection
        self.displaced = displaced
        self.noteType = noteType
        self.x = x
        self.y = y
        self.index = index
        self.keys = keys
        self.dots = dots
    }

    /// String-based parser for compatibility with external text inputs.
    public init(
        duration: String,
        line: Double = 0,
        slashed: Bool = false,
        style: ElementStyle? = nil,
        stemDownXOffset: Double = 0,
        stemUpXOffset: Double = 0,
        stemUpYShift: Double = 0,
        stemDownYShift: Double = 0,
        customGlyphCode: String? = nil,
        stemDirection: StemDirection = .up,
        displaced: Bool = false,
        noteType: String? = nil,
        x: Double = 0,
        y: Double = 0,
        index: Int? = nil,
        keys: [String] = [],
        dots: Int? = nil
    ) throws {
        let parsedDuration = try NoteDurationSpec(parsing: duration)
        let parsedType: NoteType?
        if let noteType {
            guard let explicitType = NoteType(parsing: noteType) else {
                throw NoteDurationParseError.invalidType(noteType)
            }
            parsedType = explicitType
        } else if parsedDuration.type == .note {
            parsedType = nil
        } else {
            parsedType = parsedDuration.type
        }

        self.init(
            duration: parsedDuration.value,
            line: line,
            slashed: slashed,
            style: style,
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            stemUpYShift: stemUpYShift,
            stemDownYShift: stemDownYShift,
            customGlyphCode: customGlyphCode,
            stemDirection: stemDirection,
            displaced: displaced,
            noteType: parsedType,
            x: x,
            y: y,
            index: index,
            keys: keys,
            dots: dots ?? parsedDuration.dots
        )
    }

    /// Failable parser convenience for string-based duration / type inputs.
    public init?(
        parsingDuration duration: String,
        line: Double = 0,
        slashed: Bool = false,
        style: ElementStyle? = nil,
        stemDownXOffset: Double = 0,
        stemUpXOffset: Double = 0,
        stemUpYShift: Double = 0,
        stemDownYShift: Double = 0,
        customGlyphCode: String? = nil,
        stemDirection: StemDirection = .up,
        displaced: Bool = false,
        noteType: String? = nil,
        x: Double = 0,
        y: Double = 0,
        index: Int? = nil,
        keys: [String] = [],
        dots: Int? = nil
    ) {
        guard let parsed = try? NoteHeadStruct(
            duration: duration,
            line: line,
            slashed: slashed,
            style: style,
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            stemUpYShift: stemUpYShift,
            stemDownYShift: stemDownYShift,
            customGlyphCode: customGlyphCode,
            stemDirection: stemDirection,
            displaced: displaced,
            noteType: noteType,
            x: x,
            y: y,
            index: index,
            keys: keys,
            dots: dots
        ) else { return nil }
        self = parsed
    }
}

// MARK: - NoteHead

/// Renders a notehead. Noteheads are typically not manipulated directly,
/// but used internally in `StaveNote`.
public final class NoteHead: Note {

    override public class var category: String { "NoteHead" }

    /// Map notehead SMuFL codes to the corresponding SMuFL code with a ledger line.
    public static let ledger: [String: String] = [
        Glyphs.restWhole: Glyphs.restWholeLegerLine,
        Glyphs.restHalf: Glyphs.restHalfLegerLine,
    ]

    public var customGlyph: Bool = false
    public var displaced: Bool
    public var stemDirection: StemDirection
    public var line: Double
    public var index: Int?
    public var slashed: Bool
    /// VexFlowPatch: x shift of a custom notehead when the stem is up (TI notehead)
    public var stemUpXOffset: Double = 0
    /// VexFlowPatch: x shift of a custom notehead when the stem is down (TI notehead)
    public var stemDownXOffset: Double = 0
    /// VexFlowPatch: vertical shift for notehead when stem is up
    public var stemUpYShift: Double = 0
    /// VexFlowPatch: vertical shift for notehead when stem is down
    public var stemDownYShift: Double = 0

    // MARK: - Init

    public init(noteHeadStruct: NoteHeadStruct) {
        self.index = noteHeadStruct.index
        self.displaced = noteHeadStruct.displaced
        self.stemDirection = noteHeadStruct.stemDirection
        // Upstream: `this.line = noteStruct.line || 0` (a NaN line becomes 0).
        self.line = noteHeadStruct.line.isNaN ? 0 : noteHeadStruct.line
        self.slashed = noteHeadStruct.slashed

        super.init(NoteStruct(
            keys: noteHeadStruct.keys,
            duration: NoteDurationSpec(uncheckedValue: noteHeadStruct.duration),
            dots: noteHeadStruct.dots
        ))

        self.x = noteHeadStruct.x
        self.y = noteHeadStruct.y
        if let noteType = noteHeadStruct.noteType {
            self.noteTypeValue = noteType
            self.noteType = noteType.rawValue
        }

        // Get the glyph code from the duration and note type. This can be a
        // regular note, a rest, or another custom code.
        glyphProps = Note.getGlyphProps(duration, noteType)

        // Swap out the glyph with ledger lines.
        if line > 5 || line < 0, let ledgerCode = NoteHead.ledger[glyphProps.codeHead] {
            glyphProps.codeHead = ledgerCode
        }
        text = glyphProps.codeHead
        if let customGlyphCode = noteHeadStruct.customGlyphCode {
            customGlyph = true
            text = customGlyphCode
        }

        // VexFlowPatch: store the custom notehead x offsets and the y-shift values
        stemUpXOffset = noteHeadStruct.stemUpXOffset
        stemDownXOffset = noteHeadStruct.stemDownXOffset
        stemUpYShift = noteHeadStruct.stemUpYShift
        stemDownYShift = noteHeadStruct.stemDownYShift

        setStyle(noteHeadStruct.style ?? ElementStyle())
    }

    // MARK: - Width

    /// The width of the notehead.
    override public func getWidth() -> Double { width }

    // MARK: - Displaced

    /// True if the notehead is displaced.
    public func isDisplaced() -> Bool { displaced }

    // MARK: - Line

    /// The stave line of the notehead.
    public func getLine() -> Double { line }

    /// Set the stave line of the notehead.
    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    // MARK: - Absolute X

    /// The canvas `x` coordinate of the notehead.
    override public func getAbsoluteX() -> Double {
        // If the note is not preformatted, use the static x value. Otherwise,
        // it is formatted: use its x value relative to its tick context.
        let x = !preFormatted ? self.x : super.getAbsoluteX()

        // For a more natural displaced notehead, adjust the displacement by
        // half the stem width to keep a slight overlap with the stem.
        let displacementStemAdjustment = Stem.WIDTH / 2

        return x + (displaced ? (width - displacementStemAdjustment) * stemDirection.signDouble : 0)
    }

    // MARK: - Stave

    /// Set the notehead to a stave.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        let line = getLine()

        self.stave = stave
        setY(stave.getYForNote(line))
        setContext(stave.getContext())
        return self
    }

    // MARK: - PreFormat

    /// Pre-render formatting.
    override public func preFormat() {
        if preFormatted { return }
        preFormatted = true
    }

    // MARK: - Draw

    /// Draw the notehead.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        _ = ctx.openGroup(groupClass("notehead"), getAttribute("id"))

        x = getAbsoluteX()

        // VexFlowPatch: notehead y-shift that does not depend on stem length.
        var yPatch: Double = 0
        if stemDirection == Stem.UP {
            yPatch = stemUpYShift
        } else if stemDirection == Stem.DOWN {
            yPatch = stemDownYShift
        }

        // VexFlowPatch: x offset of a custom notehead (TI notehead). Zero by default.
        var xPatch: Double = 0
        if customGlyph && (stemUpXOffset != 0 || stemDownXOffset != 0) {
            if stemDirection == Stem.UP {
                let defaultHeadWidth = TextMeasurer.measure(glyphProps.codeHead, fontInfo: fontInfo).width
                xPatch = stemUpXOffset + (glyphProps.stem ? defaultHeadWidth - width : 0)
            } else {
                xPatch = stemDownXOffset
            }
        }

        renderText(ctx, xPos: xPatch, yPos: yPatch)
        try (parent as? StaveNote)?.drawModifiers(self)
        drawPointerRect()
        ctx.closeGroup()
    }
}
