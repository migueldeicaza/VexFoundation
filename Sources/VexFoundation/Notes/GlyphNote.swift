// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/glyphnote.ts` (VexFlow 5.0.0).

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
/// The glyph is the element `text`.
open class GlyphNote: Note {

    override open class var category: String { "GlyphNote" }

    // MARK: - Properties

    public var options: GlyphNoteOptions

    // MARK: - Init

    /// - Parameter glyph: the glyph code (for example `Glyphs.coda`).
    public init(glyph: String, noteStruct: NoteStruct, options: GlyphNoteOptions = GlyphNoteOptions()) {
        self.options = options
        super.init(noteStruct)

        // Note properties
        ignoreTicks = self.options.ignoreTicks
        setGlyph(glyph)
    }

    // MARK: - Glyph

    @discardableResult
    public func setGlyph(_ glyph: String) -> Self {
        text = glyph
        return self
    }

    // MARK: - PreFormat

    override open func preFormat() {
        if !preFormatted, let mc = modifierContext {
            mc.preFormat()
        }
        preFormatted = true
    }

    // MARK: - Draw

    public func drawModifiers() throws {
        let ctx = try checkContext()
        for modifier in modifiers {
            modifier.setContext(ctx)
            try modifier.drawWithStyle()
        }
    }

    override open func draw() throws {
        let stave = checkStave()
        let ctx = try stave.checkContext()
        setRendered()
        _ = ctx.openGroup("glyphNote", getAttribute("id"))

        x = isCenterAligned() ? getAbsoluteX() - getWidth() / 2 : getAbsoluteX()
        y = stave.getYForLine(options.line)
        renderText(ctx, xPos: 0, yPos: 0)
        try drawModifiers()
        ctx.closeGroup()
    }
}
