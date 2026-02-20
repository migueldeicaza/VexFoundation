// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

private func drawSlashNoteHead(
    ctx: RenderContext,
    duration: String,
    x: Double,
    y: Double,
    stemDirection: StemDirection,
    staveSpace: Double
) {
    let width = Tables.SLASH_NOTEHEAD_WIDTH
    _ = ctx.save()
    _ = ctx.setLineWidth(Tables.STEM_WIDTH)

    let fill = Tables.durationToNumber(duration) > 2
    let drawX: Double = fill ? x : x - (Tables.STEM_WIDTH / 2) * stemDirection.signDouble

    _ = ctx.beginPath()
    _ = ctx.moveTo(drawX, y + staveSpace)
    _ = ctx.lineTo(drawX, y + 1)
    _ = ctx.lineTo(drawX + width, y - staveSpace)
    _ = ctx.lineTo(drawX + width, y)
    _ = ctx.lineTo(drawX, y + staveSpace)
    _ = ctx.closePath()

    if fill {
        _ = ctx.fill()
    } else {
        _ = ctx.stroke()
    }

    if duration == NoteValue.doubleWhole.rawValue {
        let breveLines: [Double] = [-3, -1, width + 1, width + 3]
        for offset in breveLines {
            _ = ctx.beginPath()
            _ = ctx.moveTo(drawX + offset, y - 10)
            _ = ctx.lineTo(drawX + offset, y + 11)
            _ = ctx.stroke()
        }
    }

    _ = ctx.restore()
}

// MARK: - NoteHead Struct

/// Input structure for creating a NoteHead.
public struct NoteHeadStruct {
    public var duration: NoteValue
    public var line: Double
    public var glyphFontScale: Double?
    public var slashed: Bool
    public var style: ElementStyle?
    public var stemDownXOffset: Double
    public var stemUpXOffset: Double
    public var customGlyphCode: String?
    public var xShift: Double
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
        glyphFontScale: Double? = nil,
        slashed: Bool = false,
        style: ElementStyle? = nil,
        stemDownXOffset: Double = 0,
        stemUpXOffset: Double = 0,
        customGlyphCode: String? = nil,
        xShift: Double = 0,
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
        self.glyphFontScale = glyphFontScale
        self.slashed = slashed
        self.style = style
        self.stemDownXOffset = stemDownXOffset
        self.stemUpXOffset = stemUpXOffset
        self.customGlyphCode = customGlyphCode
        self.xShift = xShift
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
        glyphFontScale: Double? = nil,
        slashed: Bool = false,
        style: ElementStyle? = nil,
        stemDownXOffset: Double = 0,
        stemUpXOffset: Double = 0,
        customGlyphCode: String? = nil,
        xShift: Double = 0,
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
            glyphFontScale: glyphFontScale,
            slashed: slashed,
            style: style,
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            customGlyphCode: customGlyphCode,
            xShift: xShift,
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
        glyphFontScale: Double? = nil,
        slashed: Bool = false,
        style: ElementStyle? = nil,
        stemDownXOffset: Double = 0,
        stemUpXOffset: Double = 0,
        customGlyphCode: String? = nil,
        xShift: Double = 0,
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
            glyphFontScale: glyphFontScale,
            slashed: slashed,
            style: style,
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            customGlyphCode: customGlyphCode,
            xShift: xShift,
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

/// Renders note heads. Typically managed internally by StaveNote.
public final class NoteHead: Note {

    override public class var category: String { "NoteHead" }

    public var glyphCode: String
    public var customGlyph: Bool = false
    public var stemUpXOffset: Double = 0
    public var stemDownXOffset: Double = 0
    public var displaced: Bool
    public var headStemDirection: StemDirection
    public var headX: Double
    public var headY: Double
    public var line: Double
    public var headIndex: Int?
    public var slashed: Bool

    // MARK: - Init

    public init(noteHeadStruct: NoteHeadStruct) {
        let ns = NoteStruct(
            keys: noteHeadStruct.keys,
            duration: NoteDurationSpec(uncheckedValue: noteHeadStruct.duration),
            dots: noteHeadStruct.dots
        )

        self.headIndex = noteHeadStruct.index
        self.headX = noteHeadStruct.x
        self.headY = noteHeadStruct.y
        self.displaced = noteHeadStruct.displaced
        self.headStemDirection = noteHeadStruct.stemDirection
        self.line = noteHeadStruct.line
        self.slashed = noteHeadStruct.slashed
        self.glyphCode = ""

        super.init(ns)

        if let noteType = noteHeadStruct.noteType {
            self.noteTypeValue = noteType
            self.noteType = noteType.rawValue
        }

        self.glyphProps = Tables.getGlyphProps(duration: noteValue, type: noteTypeValue)!

        self.glyphCode = glyphProps.codeHead
        self.xShift = noteHeadStruct.xShift

        if let customCode = noteHeadStruct.customGlyphCode {
            customGlyph = true
            glyphCode = customCode
            stemUpXOffset = noteHeadStruct.stemUpXOffset
            stemDownXOffset = noteHeadStruct.stemDownXOffset
        }

        if let style = noteHeadStruct.style {
            setStyle(style)
        }

        renderOptions.glyphFontScale = noteHeadStruct.glyphFontScale ?? Tables.NOTATION_FONT_SCALE

        let w: Double
        if noteTypeValue == .slash {
            w = Tables.SLASH_NOTEHEAD_WIDTH
        } else if customGlyph && !glyphCode.hasPrefix("noteheadSlashed") && !glyphCode.hasPrefix("noteheadCircled") {
            w = Glyph.getWidth(code: glyphCode, point: renderOptions.glyphFontScale)
        } else {
            w = Glyph.getWidth(code: glyphProps.codeHead, point: renderOptions.glyphFontScale)
        }
        setTickableWidth(w)
    }

    // MARK: - Width

    public func getWidth() -> Double { tickableWidth }

    // MARK: - Displaced

    public func isDisplaced() -> Bool { displaced }

    // MARK: - Position

    public func setHeadX(_ x: Double) {
        headX = x
    }

    public func getHeadY() -> Double { headY }

    public func setHeadY(_ y: Double) {
        headY = y
    }

    public func getLine() -> Double { line }

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    // MARK: - Absolute X

    override public func getAbsoluteX() -> Double {
        let x = !preFormatted ? headX : super.getAbsoluteX()
        let displacementStemAdjustment = Stem.WIDTH / 2
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        let fontShift = ((musicFont.lookupMetric("notehead.shiftX") as? Double) ?? 0) * headStemDirection.signDouble
        let displacedFontShift =
            ((musicFont.lookupMetric("noteHead.displacedShiftX") as? Double) ?? 0) * headStemDirection.signDouble

        return x + fontShift + (displaced
            ? (tickableWidth - displacementStemAdjustment) * headStemDirection.signDouble + displacedFontShift
            : 0)
    }

    // MARK: - Bounding Box

    override public func getBoundingBox() -> BoundingBox? {
        let spacing = checkStave().getSpacingBetweenLines()
        let halfSpacing = spacing / 2
        let minY = headY - halfSpacing
        return BoundingBox(x: getAbsoluteX(), y: minY, w: tickableWidth, h: spacing)
    }

    // MARK: - Stave

    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        noteStave = stave
        setHeadY(stave.getYForNote(line))
        if let ctx = stave.getContext() {
            setContext(ctx)
        }
        return self
    }

    // MARK: - PreFormat

    override public func preFormat() {
        if preFormatted { return }
        let width = getWidth() + leftDisplacedHeadPx + rightDisplacedHeadPx
        setTickableWidth(width)
        preFormatted = true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        var drawX = getAbsoluteX()
        if customGlyph {
            drawX += headStemDirection == Stem.UP
                ? stemUpXOffset + (glyphProps.stem
                    ? (noteTypeValue == .slash
                        ? Tables.SLASH_NOTEHEAD_WIDTH
                        : Glyph.getWidth(code: glyphProps.codeHead, point: renderOptions.glyphFontScale)) - tickableWidth
                    : 0)
                : stemDownXOffset
        }

        let categorySuffix = "\(glyphCode)Stem\(headStemDirection == Stem.UP ? "Up" : "Down")"

        if noteType == NoteType.slash.rawValue {
            let staveSpace = checkStave().getSpacingBetweenLines()
            drawSlashNoteHead(
                ctx: ctx,
                duration: noteDuration,
                x: drawX,
                y: headY,
                stemDirection: headStemDirection,
                staveSpace: staveSpace
            )
        } else {
            Glyph.renderGlyph(
                ctx: ctx,
                xPos: drawX,
                yPos: headY,
                point: renderOptions.glyphFontScale,
                code: glyphCode,
                category: "noteHead.\(categorySuffix)"
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("NoteHead", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/w, D5/h, E5/q, F5/8"))]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
