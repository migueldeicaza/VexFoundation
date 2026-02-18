// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - NoteHead Struct

/// Input structure for creating a NoteHead.
public struct NoteHeadStruct {
    public var duration: String
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
    public var noteType: String?
    public var x: Double
    public var y: Double
    public var index: Int?
    public var keys: [String]
    public var dots: Int?

    public init(
        duration: String = "4",
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
            duration: noteHeadStruct.duration,
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
            self.noteType = noteType
        }

        self.glyphProps = Tables.getGlyphProps(duration: noteDuration, type: noteType)!

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
        if customGlyph && !glyphCode.hasPrefix("noteheadSlashed") && !glyphCode.hasPrefix("noteheadCircled") {
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
                    ? Glyph.getWidth(code: glyphProps.codeHead, point: renderOptions.glyphFontScale) - tickableWidth
                    : 0)
                : stemDownXOffset
        }

        let categorySuffix = "\(glyphCode)Stem\(headStemDirection == Stem.UP ? "Up" : "Down")"

        if noteType == "s" {
            // Slash noteheads would be drawn here
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
