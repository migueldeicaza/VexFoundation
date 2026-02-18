// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - ClefNote

/// A note that renders a clef change inline with other notes.
public final class ClefNote: Note {

    override public class var CATEGORY: String { "ClefNote" }

    // MARK: - Properties

    public var clefDef: ClefType
    public var clefAnnotation: ClefAnnotationType?
    public var clefTypeName: String
    public var clefSize: String

    // MARK: - Init

    public init(type: String, size: String? = nil, annotation: String? = nil) {
        self.clefTypeName = type
        self.clefSize = size ?? "default"

        let clef = Clef(type: type, size: size, annotation: annotation)
        self.clefDef = clef.clefDef
        self.clefAnnotation = clef.annotation

        super.init(NoteStruct(duration: "b"))
        ignoreTicks = true
    }

    // MARK: - Setters

    @discardableResult
    public func setType(_ type: String, size: String? = nil, annotation: String? = nil) -> Self {
        clefTypeName = type
        clefSize = size ?? "default"
        let clef = Clef(type: type, size: size, annotation: annotation)
        clefDef = clef.clefDef
        clefAnnotation = clef.annotation
        return self
    }

    public func getClef() -> ClefType { clefDef }

    // MARK: - PreFormat

    override public func preFormat() {
        preFormatted = true
        let point = Clef.getPoint(clefSize)
        tickableWidth = Glyph.getWidth(code: clefDef.code, point: point,
                                        category: "clefNote_\(clefSize)")
    }

    // MARK: - Draw

    override public func draw() throws {
        let stave = checkStave()
        let ctx = try checkContext()
        setRendered()

        let absX = getAbsoluteX()
        let point = Clef.getPoint(clefSize)

        Glyph.renderGlyph(
            ctx: ctx,
            xPos: absX,
            yPos: stave.getYForLine(clefDef.line),
            point: point,
            code: clefDef.code,
            category: "clefNote_\(clefSize)"
        )

        // Render annotation (8va/8vb) if present
        if let annotation = clefAnnotation {
            let annotGlyph = Glyph(code: annotation.code, point: annotation.point)
            annotGlyph.setContext(ctx)
            _ = annotGlyph.setStave(stave)
            annotGlyph.yShift = stave.getYForLine(annotation.line)
                - stave.getYForGlyphs()
            annotGlyph.xShift = annotation.xShift
            annotGlyph.renderToStave(x: absX)
        }
    }
}
