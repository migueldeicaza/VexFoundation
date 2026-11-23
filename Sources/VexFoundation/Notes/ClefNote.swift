// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/clefnote.ts` (VexFlow 5.6.1).
// Inline clef changes participate in note spacing using the attached stave's glyph.

import Foundation

// MARK: - ClefNote

/// Clef annotations in measures.
public final class ClefNote: Note {

    override public class var category: String { "ClefNote" }

    // MARK: - Properties

    public private(set) var clef: Clef!

    // MARK: - Init

    public init(type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) {
        super.init(NoteStruct(duration: .twoFiftySixth))
        setType(type, size: size, annotation: annotation)
        ignoreTicks = true
    }

    // MARK: - Type

    /// Set clef type, size and annotation.
    @discardableResult
    public func setType(_ type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        clef = Clef(type: type, size: size, annotation: annotation)
        if let stave { clef.setStave(stave) }
        setWidth(clef.getWidth())
        return self
    }

    /// Resolve tablature glyphs before the formatter reserves their width. (VexFlow 5.6.1)
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        clef.setStave(stave)
        if clef.getType() == .tab { setWidth(clef.getWidth()) }
        return self
    }

    /// The clef of the note.
    public func getClef() -> Clef { clef }

    // MARK: - PreFormat

    override public func preFormat() {
        preFormatted = true
    }

    // MARK: - Draw

    /// Render the clef note.
    override public func draw() throws {
        let ctx = try checkContext()

        setRendered()
        clef.setX(getAbsoluteX())
        clef.setY(try clef.getGlyphY())
        clef.renderText(ctx, xPos: 0, yPos: 0)
    }

    override public func getBoundingBox() -> BoundingBox? {
        guard var box = clef.getBoundingBox() else { return nil }
        if getStave() != nil, let glyphY = try? clef.getGlyphY() {
            box.y = glyphY + clef.getYShift() - clef.getTextMetrics().actualBoundingBoxAscent
        }
        return box
    }
}
