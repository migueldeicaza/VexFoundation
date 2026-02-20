// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// A composite glyph for numeric time signatures (e.g. "3/4", "6/8").
/// Uses composition: wraps a base Glyph and manages top/bottom digit glyphs.
public final class TimeSigGlyph {

    public var topGlyphs: [Glyph] = []
    public var botGlyphs: [Glyph] = []
    public var topStartX: Double = 0
    public var botStartX: Double = 0
    public var width: Double = 0
    public var lineShift: Double = 0
    public var xMin: Double = 0

    /// The underlying glyph (for metrics/width compatibility).
    public var glyph: Glyph

    private weak var timeSignature: TimeSignature?

    public init(timeSignature: TimeSignature, topDigits: String, botDigits: String, code: String, point: Double) {
        self.timeSignature = timeSignature
        self.glyph = Glyph(code: code, point: point)

        var topWidth: Double = 0
        var height: Double = 0

        for ch in topDigits {
            let timeSigType: String
            switch ch {
            case "-": timeSigType = "Minus"
            case "+": timeSigType = botDigits.isEmpty ? "Plus" : "PlusSmall"
            case "(": timeSigType = botDigits.isEmpty ? "ParensLeft" : "ParensLeftSmall"
            case ")": timeSigType = botDigits.isEmpty ? "ParensRight" : "ParensRightSmall"
            default: timeSigType = String(ch)
            }
            let topGlyph = Glyph(code: "timeSig\(timeSigType)", point: timeSignature.tsPoint)
            topGlyphs.append(topGlyph)
            topWidth += topGlyph.getMetrics().width
            height = max(height, topGlyph.getMetrics().height)
        }

        var botWidth: Double = 0
        for ch in botDigits {
            let timeSigType: String
            switch ch {
            case "+": timeSigType = "PlusSmall"
            case "(": timeSigType = "ParensLeftSmall"
            case ")": timeSigType = "ParensRightSmall"
            default: timeSigType = String(ch)
            }
            let botGlyph = Glyph(code: "timeSig\(timeSigType)", point: timeSignature.tsPoint)
            botGlyphs.append(botGlyph)
            botWidth += botGlyph.getMetrics().width
            height = max(height, botGlyph.getMetrics().height)
        }

        lineShift = height > 22 ? 1 : 0
        width = max(topWidth, botWidth)
        xMin = glyph.getMetrics().xMin
        topStartX = (width - topWidth) / 2.0
        botStartX = (width - botWidth) / 2.0
    }

    public func getMetrics() -> GlyphMetrics {
        var metrics = glyph.getMetrics()
        metrics.xMin = xMin
        metrics.xMax = xMin + width
        metrics.width = width
        return metrics
    }

    /// Render top and bottom digit glyphs to the stave.
    public func renderToStave(ctx: RenderContext, x: Double, stave: Stave) {
        guard let timeSignature else { return }

        var startX = x + topStartX
        var y: Double
        if !botGlyphs.isEmpty {
            y = stave.getYForLine(timeSignature.topLine - lineShift)
        } else {
            y = (stave.getYForLine(timeSignature.topLine) + stave.getYForLine(timeSignature.bottomLine)) / 2
        }

        for glyph in topGlyphs {
            let metrics = glyph.getMetrics()
            Glyph.renderOutline(ctx: ctx, outline: metrics.outline, scale: metrics.scale, xPos: startX, yPos: y)
            startX += metrics.width
        }

        startX = x + botStartX
        y = stave.getYForLine(timeSignature.bottomLine + lineShift)
        for glyph in botGlyphs {
            let metrics = glyph.getMetrics()
            Glyph.renderOutline(ctx: ctx, outline: metrics.outline, scale: metrics.scale, xPos: startX, yPos: y)
            startX += metrics.width
        }
    }
}

/// Backward-compatible alias for callers using the upstream class name.
public typealias TimeSignatureGlyph = TimeSigGlyph
