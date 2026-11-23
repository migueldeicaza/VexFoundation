// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/stemmablenote.ts` (VexFlow 5.2.0).
// `StemmableNote` is an abstract interface for notes with optional stems.
// Examples of stemmable notes are `StaveNote` and `TabNote`.
// Retains whether stem direction is automatic or explicitly chosen.

import Foundation

public enum StemmableNoteError: Error, LocalizedError, Equatable, Sendable {
    case noStem
    case noStemDirection

    public var errorDescription: String? {
        switch self {
        case .noStem:
            return "No stem attached to this note."
        case .noStemDirection:
            return "No stem direction set on this note."
        }
    }
}

// MARK: - StemmableNote

/// Abstract interface for notes with optional stems.
open class StemmableNote: Note {

    override open class var category: String { "StemmableNote" }

    public var stemDirection: StemDirection?
    public var stem: Stem?
    /// The flag. Created after the note (upstream field initializer order), so
    /// the element ids are generated in the upstream order.
    public var flag: Flag!
    public var stemExtensionOverride: Double?
    /// Automatic stems may be resolved again when notes are grouped into a beam. (VexFlow 5.2.0)
    var autoStemEnabled = false

    public override init(_ noteStruct: NoteStruct) {
        super.init(noteStruct)
        flag = Flag()
    }

    // MARK: - Stem

    /// The note stem.
    public func getStem() -> Stem? { stem }

    public func checkStem() -> Stem {
        (try? checkStemThrowing()) ?? Stem()
    }

    public func checkStemThrowing() throws -> Stem {
        guard let stem else {
            throw StemmableNoteError.noStem
        }
        return stem
    }

    @discardableResult
    public func setStem(_ stem: Stem) -> Self {
        self.stem = stem
        addChild(stem)
        return self
    }

    /// Build and set a new stem.
    @discardableResult
    open func buildStem() -> Self {
        setStem(Stem())
    }

    /// Set the flag glyph from the glyph properties and the stem direction.
    open func buildFlag() {
        if hasFlag() {
            let flagCode: String
            if getStemDirection() == Stem.DOWN {
                // codeFlagDown = codeFlagUp + 1.
                // If codeFlagUp is undefined, the code point is 0.
                let codeFlagUp = Int(glyphProps.codeFlagUp?.unicodeScalars.first?.value ?? 0)
                let base = glyphProps.codeFlagUp == nil ? -1 : codeFlagUp
                flagCode = UnicodeScalar(UInt32(base + 1)).map { String(Character($0)) } ?? Glyphs.null
            } else {
                flagCode = glyphProps.codeFlagUp ?? Glyphs.null
            }

            flag.setText(flagCode)
            flag.fontInfo = fontInfo
        }
    }

    /// The custom glyph of the outer notehead at the base of the stem.
    public func getBaseCustomNoteHeadGlyphProps() -> GlyphProps? {
        guard !customGlyphs.isEmpty else { return nil }
        return getStemDirection() == Stem.DOWN ? customGlyphs.last : customGlyphs.first
    }

    // MARK: - Stem Length

    /// The full length of the stem.
    public func getStemLength() -> Double {
        Stem.HEIGHT + getStemExtension()
    }

    /// The number of beams for this duration.
    public func getBeamCount() -> Int {
        glyphProps.beamCount
    }

    /// The minimum length of the stem.
    public func getStemMinimumLength() -> Double {
        let frac = Tables.durationToFraction(duration)
        let beamIsUndefined = beam == nil
        var length: Double = frac.value() <= 1 ? 0 : 20
        // If the note is flagged, the beam cannot be shorter.
        switch duration {
        case "8", "16":
            length = beamIsUndefined ? 35 : 25
        case "32":
            length = beamIsUndefined ? 45 : 35
        case "64":
            length = beamIsUndefined ? 50 : 40
        case "128":
            length = beamIsUndefined ? 55 : 45
        case "256":
            length = beamIsUndefined ? 60 : 55
        case "512":
            length = beamIsUndefined ? 65 : 60
        case "1024":
            length = beamIsUndefined ? 70 : 65
        default:
            break
        }
        return length
    }

    // MARK: - Stem Direction

    override public func getStemDirection() -> StemDirection {
        (try? getStemDirectionThrowing()) ?? Stem.UP
    }

    override public func getStemDirectionThrowing() throws -> StemDirection {
        guard let stemDirection else {
            throw StemmableNoteError.noStem
        }
        return stemDirection
    }

    /// True when layout, rather than the caller, chooses the stem direction. (VexFlow 5.2.0)
    public func isAutoStem() -> Bool { autoStemEnabled }

    /// Set direction; automatic layout passes `autoStem: true` to retain the automatic policy.
    @discardableResult
    public func setStemDirection(_ direction: StemDirection = .up, autoStem: Bool = false) -> Self {
        stemDirection = direction
        autoStemEnabled = autoStem

        // Reset and reformat everything. Build the flag before getStemExtension().
        reset()
        if hasFlag() {
            buildFlag()
        }
        beam = nil

        if let stem {
            stem.setDirection(direction)
            stem.setExtension(getStemExtension())
        }

        if preFormatted {
            preFormat()
        }
        return self
    }

    // MARK: - Stem X

    /// The `x` coordinate of the stem.
    open func getStemX() -> Double {
        let xBegin = getAbsoluteX() + xShift
        let xEnd = getAbsoluteX() + xShift + getGlyphWidth()
        return stemDirection == Stem.DOWN ? xBegin : xEnd
    }

    /// The `x` coordinate of the glyph center.
    /// Used for `TabNote` stems and stemlets over rests.
    public func getCenterGlyphX() -> Double {
        getAbsoluteX() + xShift + getGlyphWidth() / 2
    }

    // MARK: - Stem Extension

    /// The stem extension for the current duration.
    open func getStemExtension() -> Double {
        let flagHeight = flag.getHeight()
        let scale = getFontScale()

        if let override = stemExtensionOverride {
            return override
        }

        // Use stemBeamExtension with beams.
        if beam != nil {
            return glyphProps.stemBeamExtension * scale
        }

        // If the flag is longer than the stem, extend the stem by the difference.
        return flagHeight > Stem.HEIGHT * scale ? flagHeight - Stem.HEIGHT * scale : 0
    }

    /// Set the stem length to a specific value. This overrides the default length.
    @discardableResult
    public func setStemLength(_ height: Double) -> Self {
        stemExtensionOverride = height - Stem.HEIGHT
        return self
    }

    // MARK: - Stem Extents

    /// The top and bottom `y` values of the stem.
    override public func getStemExtents() -> (topY: Double, baseY: Double) {
        (try? getStemExtentsThrowing()) ?? (topY: 0, baseY: 0)
    }

    override public func getStemExtentsThrowing() throws -> (topY: Double, baseY: Double) {
        try checkStemThrowing().getExtents()
    }

    // MARK: - Y for Text

    /// The `y` value for the top modifiers at a `textLine`.
    override public func getYForTopText(_ textLine: Double) -> Double {
        let stave = checkStave()
        if hasStem() {
            let extents = getStemExtents()
            return min(
                stave.getYForTopText(textLine),
                extents.topY - renderOptions.annotationSpacing * (textLine + 1)
            )
        }
        return stave.getYForTopText(textLine)
    }

    /// The `y` value for the bottom modifiers at a `textLine`.
    open func getYForBottomText(_ textLine: Double) -> Double {
        let stave = checkStave()
        if hasStem() {
            let extents = getStemExtents()
            return max(
                stave.getYForTopText(textLine),
                extents.baseY + renderOptions.annotationSpacing * textLine
            )
        }
        return stave.getYForBottomText(textLine)
    }

    // MARK: - Flag

    open func hasFlag() -> Bool {
        glyphProps.codeFlagUp != nil && beam == nil && !isRest()
    }

    // MARK: - Post Format

    /// Post-format the note.
    @discardableResult
    override public func postFormat() -> Self {
        beam?.postFormat()
        postFormatted = true
        return self
    }

    // MARK: - Draw Stem

    /// Render the stem.
    open func drawStem(_ stemOptions: StemOptions? = nil) throws {
        _ = try checkContext()
        setRendered()

        setStem(Stem(options: stemOptions))
        try stem?.setContext(getContext()).drawWithStyle()
    }
}
