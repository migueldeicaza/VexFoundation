// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - StemmableNote

/// Abstract interface for notes with optional stems.
/// Examples: StaveNote, TabNote.
open class StemmableNote: Note {

    override open class var CATEGORY: String { "StemmableNote" }

    public var stemDirection: Int?
    public var stem: Stem?
    public var flag: Glyph?
    public var stemExtensionOverride: Double?

    // MARK: - Stem

    public func getStem() -> Stem? { stem }

    public func checkStem() -> Stem {
        guard let stem else {
            fatalError("[VexError] NoStem: No stem attached to instance")
        }
        return stem
    }

    @discardableResult
    public func setStem(_ stem: Stem) -> Self {
        self.stem = stem
        addChildElement(stem)
        return self
    }

    @discardableResult
    public func buildStem() -> Self {
        setStem(Stem())
    }

    public func buildFlag(category: String = "flag") {
        if hasFlag() {
            let flagCode = getStemDirection() == Stem.DOWN
                ? glyphProps.codeFlagDownstem
                : glyphProps.codeFlagUpstem
            if let flagCode {
                flag = Glyph(code: flagCode, point: renderOptions.glyphFontScale,
                             options: GlyphOptions(category: category))
            }
        }
    }

    public func getBaseCustomNoteHeadGlyphProps() -> GlyphProps? {
        guard !customGlyphs.isEmpty else { return nil }
        return getStemDirection() == Stem.DOWN ? customGlyphs.last : customGlyphs.first
    }

    // MARK: - Stem Length

    public func getStemLength() -> Double {
        Stem.HEIGHT + getStemExtension()
    }

    public func getBeamCount() -> Int {
        glyphProps?.beamCount ?? 0
    }

    public func getStemMinimumLength() -> Double {
        let frac = Tables.durationToFraction(noteDuration)
        var length: Double = frac.value() <= 1 ? 0 : 20

        switch noteDuration {
        case "8": if beam == nil { length = 35 }
        case "16": length = beam == nil ? 35 : 25
        case "32": length = beam == nil ? 45 : 35
        case "64": length = beam == nil ? 50 : 40
        case "128": length = beam == nil ? 55 : 45
        default: break
        }
        return length
    }

    // MARK: - Stem Direction

    override public func getStemDirection() -> Int {
        guard let stemDirection else {
            fatalError("[VexError] NoStem: No stem attached to this note.")
        }
        return stemDirection
    }

    @discardableResult
    public func setStemDirection(_ direction: Int? = nil) -> Self {
        let dir = direction ?? Stem.UP
        guard dir == Stem.UP || dir == Stem.DOWN else {
            fatalError("[VexError] BadArgument: Invalid stem direction: \(String(describing: direction))")
        }

        stemDirection = dir

        if hasFlag() {
            buildFlag()
        }
        beam = nil

        if let stem {
            stem.setDirection(dir)
            stem.setExtension(getStemExtension())

            let glyphP = getBaseCustomNoteHeadGlyphProps() ?? glyphProps!
            guard let musicFont = Glyph.MUSIC_FONT_STACK.first else { return self }
            let key = "stem.noteHead.\(glyphP.codeHead)"
            let offsets = musicFont.lookupMetric(key)
            let offsetYBaseStemUp = (offsets as? [String: Any])?["offsetYBaseStemUp"] as? Double ?? 0
            let offsetYTopStemUp = (offsets as? [String: Any])?["offsetYTopStemUp"] as? Double ?? 0
            let offsetYBaseStemDown = (offsets as? [String: Any])?["offsetYBaseStemDown"] as? Double ?? 0
            let offsetYTopStemDown = (offsets as? [String: Any])?["offsetYTopStemDown"] as? Double ?? 0

            stem.setOptions(StemOptions(
                stemDownYBaseOffset: offsetYBaseStemDown,
                stemUpYBaseOffset: offsetYBaseStemUp,
                stemDownYOffset: offsetYTopStemDown,
                stemUpYOffset: offsetYTopStemUp
            ))
        }

        if preFormatted {
            preFormat()
        }
        return self
    }

    // MARK: - Stem X

    public func getStemX() -> Double {
        let xBegin = getAbsoluteX() + xShift
        let xEnd = getAbsoluteX() + xShift + getGlyphWidth()
        return stemDirection == Stem.DOWN ? xBegin : xEnd
    }

    public func getCenterGlyphX() -> Double {
        getAbsoluteX() + xShift + getGlyphWidth() / 2
    }

    // MARK: - Stem Extension

    public func getStemExtension() -> Double {
        if let override = stemExtensionOverride {
            return override
        }

        if beam != nil {
            return glyphProps.stemBeamExtension
        }

        return getStemDirection() == Stem.UP ? glyphProps.stemUpExtension : glyphProps.stemDownExtension
    }

    @discardableResult
    public func setStemLength(_ height: Double) -> Self {
        stemExtensionOverride = height - Stem.HEIGHT
        return self
    }

    // MARK: - Stem Extents

    override public func getStemExtents() -> (topY: Double, baseY: Double) {
        guard let stem else {
            fatalError("[VexError] NoStem: No stem attached to this note.")
        }
        return stem.getExtents()
    }

    // MARK: - Y for Text

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

    public func getYForBottomText(_ textLine: Double) -> Double {
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
        guard let gp = Tables.getGlyphProps(duration: noteDuration) else { return false }
        return gp.flag && beam == nil
    }

    // MARK: - Post Format

    @discardableResult
    override public func postFormat() -> Self {
        postFormatted = true
        return self
    }

    // MARK: - Draw Stem

    public func drawStem(_ stemOptions: StemOptions) throws {
        _ = try checkContext()
        setRendered()
        setStem(Stem(options: stemOptions))
        stem?.setContext(getContext())
        try stem?.draw()
    }
}
