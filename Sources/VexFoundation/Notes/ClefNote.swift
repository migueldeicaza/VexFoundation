// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - ClefNote

/// A note that renders a clef change inline with other notes.
public final class ClefNote: Note {

    override public class var category: String { "ClefNote" }

    // MARK: - Properties

    public var clefDef: ClefType
    public var clefAnnotation: ClefAnnotationType?
    public var clefTypeName: ClefName
    public var clefSize: ClefSize

    // MARK: - Init

    public init(type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) {
        self.clefTypeName = type
        self.clefSize = size

        let clef = Clef(type: type, size: size, annotation: annotation)
        self.clefDef = clef.clefDef
        self.clefAnnotation = clef.annotation

        super.init(NoteStruct(duration: "b"))
        ignoreTicks = true
    }

    // MARK: - Setters

    @discardableResult
    public func setType(_ type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        clefTypeName = type
        clefSize = size
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
                                        category: "clefNote_\(clefSize.rawValue)")
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
            category: "clefNote_\(clefSize.rawValue)"
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

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("ClefNote", traits: .sizeThatFitsLayout) {
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
            voices: [score.voice(score.notes("C5/q, D5, E5, F5"))]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
