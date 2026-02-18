// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna Cheppudira 2013. Co-author: Benjamin W. Bohl. MIT License.

import Foundation

// MARK: - Clef Type Definition

/// Defines a clef's glyph code and default staff line.
public struct ClefType: Sendable {
    public var code: String
    public var line: Double
}

/// Annotation for 8va/8vb clef markings.
public struct ClefAnnotationType: Sendable {
    public var code: String
    public var point: Double
    public var line: Double
    public var xShift: Double
}

// MARK: - Clef

/// Renders clefs (treble, bass, alto, tenor, percussion, tab, etc.) on a stave.
public final class Clef: StaveModifier {

    override public class var category: String { "Clef" }

    // MARK: - Clef Types

    /// Maps clef name to glyph code and default line.
    public static let types: [String: ClefType] = [
        "treble": ClefType(code: "gClef", line: 3),
        "bass": ClefType(code: "fClef", line: 1),
        "alto": ClefType(code: "cClef", line: 2),
        "tenor": ClefType(code: "cClef", line: 1),
        "percussion": ClefType(code: "unpitchedPercussionClef1", line: 2),
        "soprano": ClefType(code: "cClef", line: 4),
        "mezzo-soprano": ClefType(code: "cClef", line: 3),
        "baritone-c": ClefType(code: "cClef", line: 0),
        "baritone-f": ClefType(code: "fClef", line: 2),
        "subbass": ClefType(code: "fClef", line: 0),
        "french": ClefType(code: "gClef", line: 4),
        "tab": ClefType(code: "6stringTabClef", line: 2.5),
    ]

    /// Maps annotation names to SMuFL glyph codes.
    public static let annotationSmufl: [String: String] = [
        "8va": "timeSig8",
        "8vb": "timeSig8",
    ]

    /// Get font point size for a clef size.
    public static func getPoint(_ size: String?) -> Double {
        size == "default"
            ? Tables.NOTATION_FONT_SCALE
            : (Tables.NOTATION_FONT_SCALE / 3) * 2
    }

    // MARK: - Properties

    public var clefDef: ClefType
    public var annotation: ClefAnnotationType?
    public var attachment: Glyph?
    public var size: String?
    public var clefTypeName: String?

    // MARK: - Init

    public init(type: String, size: String? = nil, annotation: String? = nil) {
        self.clefDef = Clef.types["treble"]!
        super.init()
        setPosition(.begin)
        setClefType(type, size: size, annotation: annotation)
        self.modifierWidth = Glyph.getWidth(
            code: clefDef.code,
            point: Clef.getPoint(self.size),
            category: "clef_\(self.size ?? "default")"
        )
    }

    // MARK: - Methods

    /// Set clef type, size, and optional annotation (e.g. "8va").
    @discardableResult
    public func setClefType(_ type: String, size: String? = nil, annotation: String? = nil) -> Self {
        self.clefTypeName = type
        self.clefDef = Clef.types[type] ?? Clef.types["treble"]!
        self.size = size ?? "default"

        if let annotation {
            let code = Clef.annotationSmufl[annotation] ?? "timeSig8"
            let point = (Clef.getPoint(self.size) / 5) * 3

            // Look up annotation positioning from font metrics
            let musicFont = Glyph.MUSIC_FONT_STACK.first!
            let lineKey = "clef_\(self.size!).annotations.\(annotation).\(type).line"
            let shiftKey = "clef_\(self.size!).annotations.\(annotation).\(type).shiftX"
            let line = (musicFont.lookupMetric(lineKey) as? Double) ?? 0
            let xShift = (musicFont.lookupMetric(shiftKey) as? Double) ?? 0

            self.annotation = ClefAnnotationType(code: code, point: point, line: line, xShift: xShift)
            self.attachment = Glyph(code: code, point: point)
            self.attachment?.setXShift(xShift)
        } else {
            self.annotation = nil
            self.attachment = nil
        }

        return self
    }

    override public func getModifierWidth() -> Double {
        if clefTypeName == "tab" {
            _ = checkStave()
        }
        return modifierWidth
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        applyStyle(context: ctx)
        _ = ctx.openGroup("clef", getAttribute("id"))

        Glyph.renderGlyph(
            ctx: ctx,
            xPos: modifierX,
            yPos: stave.getYForLine(clefDef.line),
            point: Clef.getPoint(size),
            code: clefDef.code,
            category: "clef_\(size ?? "default")"
        )

        if let ann = annotation, let attach = attachment {
            placeGlyphOnLine(attach, stave: stave, line: ann.line)
            attach.setContext(ctx)
            attach.render(ctx: ctx, x: modifierX, y: stave.getYForGlyphs())
        }

        ctx.closeGroup()
        restoreStyle(context: ctx)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Clef", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 150)
        _ = s1.addClef("treble")

        let s2 = f.Stave(x: 170, y: 20, width: 150)
        _ = s2.addClef("bass")

        let s3 = f.Stave(x: 330, y: 20, width: 150)
        _ = s3.addClef("alto")

        try? f.draw()
    }
    .padding()
}
#endif
