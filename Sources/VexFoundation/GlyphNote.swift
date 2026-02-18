// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Glyph Note Options

public struct GlyphNoteOptions {
    public var ignoreTicks: Bool
    public var line: Double

    public init(ignoreTicks: Bool = false, line: Double = 2) {
        self.ignoreTicks = ignoreTicks
        self.line = line
    }
}

// MARK: - GlyphNote

/// A note that renders a single glyph (e.g. repeat signs, segno, coda).
open class GlyphNote: Note {

    override open class var CATEGORY: String { "GlyphNote" }

    // MARK: - Properties

    public var glyphNoteOptions: GlyphNoteOptions
    public var noteGlyph: Glyph

    // MARK: - Init

    public init(glyph: Glyph, noteStruct: NoteStruct, options: GlyphNoteOptions = GlyphNoteOptions()) {
        self.glyphNoteOptions = options
        self.noteGlyph = glyph
        super.init(noteStruct)
        self.ignoreTicks = options.ignoreTicks
        setGlyph(glyph)
    }

    // MARK: - Glyph

    @discardableResult
    public func setGlyph(_ glyph: Glyph) -> Self {
        noteGlyph = glyph
        return self
    }

    override public func getGlyphWidth() -> Double {
        noteGlyph.getMetrics().width
    }

    override public func getMetrics() -> NoteMetrics {
        var m = super.getMetrics()
        m.glyphWidth = noteGlyph.getMetrics().width
        m.width = noteGlyph.getMetrics().width
        return m
    }

    override public func getBoundingBox() -> BoundingBox? {
        noteGlyph.bbox
    }

    // MARK: - PreFormat

    override public func preFormat() {
        if !preFormatted {
            if let mc = modifierContext {
                mc.preFormat()
            }
            preFormatted = true
        }
    }

    // MARK: - Draw

    public func drawModifiers() throws {
        let ctx = try checkContext()
        for modifier in getModifiers() {
            modifier.setContext(ctx)
            try modifier.draw()
        }
    }

    override public func draw() throws {
        let stave = checkStave()
        let ctx = try checkContext()
        setRendered()

        applyStyle(context: ctx, style: getStyle())
        _ = ctx.openGroup("glyphnote", getAttribute("id") ?? "")

        noteGlyph.setContext(ctx)
        _ = noteGlyph.setStave(stave)
        noteGlyph.yShift = stave.getYForLine(glyphNoteOptions.line)
            - stave.getYForGlyphs()

        let x: Double
        if isCenterAligned() {
            x = getAbsoluteX() + getCenterXShift()
        } else {
            x = getAbsoluteX()
        }

        noteGlyph.renderToStave(x: x)
        try drawModifiers()

        ctx.closeGroup()
        restoreStyle(context: ctx, style: getStyle())
    }
}
