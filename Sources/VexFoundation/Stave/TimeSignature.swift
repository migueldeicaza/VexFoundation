// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TimeSignature

/// Renders time signatures on a stave.
public final class TimeSignature: StaveModifier {

    override public class var category: String { "TimeSignature" }

    /// Special symbol time signatures.
    public static let symbolGlyphs: [TimeSignatureSymbol: (code: String, line: Double)] = [
        .common: (code: "timeSigCommon", line: 2),
        .cutCommon: (code: "timeSigCutCommon", line: 2),
    ]

    // MARK: - Properties

    public var tsPoint: Double
    public var bottomLine: Double
    public var topLine: Double
    public var timeSpec: TimeSignatureSpec = .default
    public var tsLine: Double = 0
    public var isNumeric: Bool = true

    /// The glyph used to render this time signature.
    /// For symbol time (C, C|), this is a regular Glyph.
    /// For numeric time, we store a TimeSigGlyph alongside.
    private var tsGlyph: Glyph!
    private var tsGlyphComposite: TimeSigGlyph?

    // MARK: - Init

    public init(timeSpec: TimeSignatureSpec = .default, customPadding: Double = 15) {
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        self.tsPoint = (musicFont.lookupMetric("digits.point") as? Double) ?? Tables.NOTATION_FONT_SCALE
        let fontLineShift = (musicFont.lookupMetric("digits.shiftLine") as? Double) ?? 0
        self.topLine = 2 + fontLineShift
        self.bottomLine = 4 + fontLineShift

        super.init()
        setPosition(.begin)
        setTimeSig(timeSpec)
        setPadding(customPadding)
    }

    // MARK: - Methods

    @discardableResult
    public func setTimeSig(_ timeSpec: TimeSignatureSpec) -> Self {
        self.timeSpec = timeSpec
        let info = parseTimeSpec(timeSpec)
        self.tsGlyph = info.glyph
        self.tsGlyphComposite = info.composite
        self.modifierWidth = info.composite?.getMetrics().width ?? info.glyph.getMetrics().width
        self.isNumeric = info.num
        self.tsLine = info.line
        return self
    }

    public func getTimeSpec() -> TimeSignatureSpec { timeSpec }
    public func getTimeSpecString() -> String { timeSpec.rawValue }

    public func getGlyph() -> Glyph { tsGlyph }

    public func getLine() -> Double { tsLine }
    public func setLine(_ line: Double) { tsLine = line }

    public func getIsNumeric() -> Bool { isNumeric }
    public func setIsNumeric(_ val: Bool) { isNumeric = val }

    // MARK: - Parsing

    private struct ParseResult {
        var glyph: Glyph
        var composite: TimeSigGlyph?
        var line: Double
        var num: Bool
    }

    private func parseTimeSpec(_ spec: TimeSignatureSpec) -> ParseResult {
        switch spec {
        case .symbol(let symbol):
            let sym = TimeSignature.symbolGlyphs[symbol]!
            return ParseResult(
                glyph: Glyph(code: sym.code, point: Tables.NOTATION_FONT_SCALE),
                composite: nil,
                line: sym.line,
                num: false
            )
        case .numeric(let top, let bottom):
            let composite = TimeSigGlyph(
                timeSignature: self,
                topDigits: top.rawValue,
                botDigits: bottom.rawValue,
                code: "timeSig0",
                point: tsPoint
            )
            return ParseResult(
                glyph: composite.glyph,
                composite: composite,
                line: 0,
                num: true
            )
        case .topOnly(let top):
            let composite = TimeSigGlyph(
                timeSignature: self,
                topDigits: top.rawValue,
                botDigits: "",
                code: "timeSig0",
                point: tsPoint
            )
            return ParseResult(
                glyph: composite.glyph,
                composite: composite,
                line: 0,
                num: true
            )
        case .bottomOnly(let bottom):
            let composite = TimeSigGlyph(
                timeSignature: self,
                topDigits: "",
                botDigits: bottom.rawValue,
                code: "timeSig0",
                point: tsPoint
            )
            return ParseResult(
                glyph: composite.glyph,
                composite: composite,
                line: 0,
                num: true
            )
        }
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        applyStyle(context: ctx)
        _ = ctx.openGroup("timesignature", getAttribute("id"))

        if let composite = tsGlyphComposite {
            composite.renderToStave(ctx: ctx, x: modifierX, stave: stave)
        } else {
            // Symbol glyph (C or C|)
            let glyphToRender = tsGlyph!
            placeGlyphOnLine(glyphToRender, stave: stave, line: tsLine)
            glyphToRender.setStave(stave)
            glyphToRender.setContext(ctx)
            glyphToRender.renderToStave(x: modifierX)
        }

        ctx.closeGroup()
        restoreStyle(context: ctx)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TimeSignature", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 150)
        _ = s1.addClef(.treble).addTimeSignature(.meter(4, 4))

        let s2 = f.Stave(x: 170, y: 20, width: 150)
        _ = s2.addClef(.treble).addTimeSignature(.meter(3, 4))

        let s3 = f.Stave(x: 330, y: 20, width: 150)
        _ = s3.addClef(.treble).addTimeSignature(.meter(6, 8))

        try? f.draw()
    }
    .padding()
}
#endif
