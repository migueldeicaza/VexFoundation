// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TimeSignatureGlyph

/// A composite glyph for numeric time signatures (e.g. "3/4", "6/8").
/// Uses composition: wraps a base Glyph and manages top/bottom digit glyphs.
public final class TimeSignatureGlyph {

    public var topGlyphs: [Glyph] = []
    public var botGlyphs: [Glyph] = []
    public var topStartX: Double = 0
    public var botStartX: Double = 0
    public var tsWidth: Double = 0
    public var lineShift: Double = 0
    public var tsXMin: Double = 0

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
        tsWidth = max(topWidth, botWidth)
        tsXMin = glyph.getMetrics().xMin
        topStartX = (tsWidth - topWidth) / 2.0
        botStartX = (tsWidth - botWidth) / 2.0
    }

    public func getMetrics() -> GlyphMetrics {
        var m = glyph.getMetrics()
        m.xMin = tsXMin
        m.xMax = tsXMin + tsWidth
        m.width = tsWidth
        return m
    }

    /// Render top and bottom digit glyphs to the stave.
    public func renderToStave(ctx: RenderContext, x: Double, stave: Stave) {
        guard let ts = timeSignature else { return }

        var startX = x + topStartX
        var y: Double
        if !botGlyphs.isEmpty {
            y = stave.getYForLine(ts.topLine - lineShift)
        } else {
            y = (stave.getYForLine(ts.topLine) + stave.getYForLine(ts.bottomLine)) / 2
        }

        for glyph in topGlyphs {
            let m = glyph.getMetrics()
            Glyph.renderOutline(ctx: ctx, outline: m.outline, scale: m.scale, xPos: startX, yPos: y)
            startX += m.width
        }

        startX = x + botStartX
        y = stave.getYForLine(ts.bottomLine + lineShift)
        for glyph in botGlyphs {
            let m = glyph.getMetrics()
            Glyph.renderOutline(ctx: ctx, outline: m.outline, scale: m.scale, xPos: startX, yPos: y)
            startX += m.width
        }
    }
}

// MARK: - TimeSignature

/// Renders time signatures on a stave.
public final class TimeSignature: StaveModifier {

    override public class var CATEGORY: String { "TimeSignature" }

    /// Special symbol time signatures.
    public static let symbolGlyphs: [String: (code: String, line: Double)] = [
        "C": (code: "timeSigCommon", line: 2),
        "C|": (code: "timeSigCutCommon", line: 2),
    ]

    // MARK: - Properties

    public var tsPoint: Double
    public var bottomLine: Double
    public var topLine: Double
    public var timeSpec: String = "4/4"
    public var tsLine: Double = 0
    public var isNumeric: Bool = true
    public var validateArgs: Bool

    /// The glyph used to render this time signature.
    /// For symbol time (C, C|), this is a regular Glyph.
    /// For numeric time, we store a TimeSignatureGlyph alongside.
    private var tsGlyph: Glyph!
    private var tsGlyphComposite: TimeSignatureGlyph?

    // MARK: - Init

    public init(timeSpec: String = "4/4", customPadding: Double = 15, validateArgs: Bool = true) {
        self.validateArgs = validateArgs

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
    public func setTimeSig(_ timeSpec: String) -> Self {
        self.timeSpec = timeSpec
        let info = parseTimeSpec(timeSpec)
        self.tsGlyph = info.glyph
        self.tsGlyphComposite = info.composite
        self.modifierWidth = info.composite?.getMetrics().width ?? info.glyph.getMetrics().width
        self.isNumeric = info.num
        self.tsLine = info.line
        return self
    }

    public func getTimeSpec() -> String { timeSpec }

    public func getGlyph() -> Glyph { tsGlyph }

    public func getLine() -> Double { tsLine }
    public func setLine(_ line: Double) { tsLine = line }

    public func getIsNumeric() -> Bool { isNumeric }
    public func setIsNumeric(_ val: Bool) { isNumeric = val }

    // MARK: - Parsing

    private struct ParseResult {
        var glyph: Glyph
        var composite: TimeSignatureGlyph?
        var line: Double
        var num: Bool
    }

    private func parseTimeSpec(_ spec: String) -> ParseResult {
        if spec == "C" || spec == "C|" {
            let sym = TimeSignature.symbolGlyphs[spec]!
            return ParseResult(
                glyph: Glyph(code: sym.code, point: Tables.NOTATION_FONT_SCALE),
                composite: nil,
                line: sym.line,
                num: false
            )
        }

        if validateArgs {
            assertValidTimeSig(spec)
        }

        let parts = spec.split(separator: "/", maxSplits: 1)
        let top = parts.count > 0 ? String(parts[0]) : ""
        let bot = parts.count > 1 ? String(parts[1]) : ""

        let composite = TimeSignatureGlyph(
            timeSignature: self,
            topDigits: top,
            botDigits: bot,
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

    private func assertValidTimeSig(_ spec: String) {
        let parts = spec.split(separator: "/")
        guard parts.count == 2 else {
            fatalError("[VexError] BadTimeSignature: Invalid time spec: \(spec)")
        }
        let validChars = CharacterSet(charactersIn: "0123456789+-() ")
        for part in parts {
            if part.unicodeScalars.contains(where: { !validChars.contains($0) }) {
                fatalError("[VexError] BadTimeSignature: Invalid time spec: \(spec)")
            }
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
            glyphToRender.render(ctx: ctx, x: modifierX, y: stave.getYForGlyphs())
        }

        ctx.closeGroup()
        restoreStyle(context: ctx)
    }
}
