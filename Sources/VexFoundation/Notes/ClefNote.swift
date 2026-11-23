// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/clefnote.ts` (VexFlow 5.2.0).

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
        setWidth(clef.getWidth())
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
        let stave = checkStave()
        let ctx = try checkContext()

        setRendered()
        clef.setX(getAbsoluteX())
        clef.setY(stave.getYForLine(clef.line))
        clef.renderText(ctx, xPos: 0, yPos: 0)
    }

    override public func getBoundingBox() -> BoundingBox? {
        guard var box = clef.getBoundingBox() else { return nil }
        if let stave = getStave() {
            box.y = stave.getYForLine(clef.line) + clef.getYShift() - clef.getTextMetrics().actualBoundingBoxAscent
        }
        return box
    }
}
