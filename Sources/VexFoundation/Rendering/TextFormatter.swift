// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original concept: textformatter.ts. Swift replacement contract.

import Foundation

/// Vertical text extent relative to the baseline.
/// `yMin` is typically negative (ascender region), `yMax` positive (descender region).
public struct TextExtent: Sendable, Equatable {
    public var yMin: Double
    public var yMax: Double
    public var height: Double

    public init(yMin: Double = 0, yMax: Double = 0, height: Double? = nil) {
        self.yMin = yMin
        self.yMax = yMax
        self.height = height ?? (yMax - yMin)
    }
}

/// Swift-native text formatting helper built on top of `RenderContext.measureText`.
///
/// This is an explicit replacement contract for VexFlow's text formatter module:
/// - if a `RenderContext` is available, measurements come from `measureText`
/// - if no context is available, deterministic fallback heuristics are used
public final class TextFormatter {
    private struct TextFontGlyphMetrics: Decodable {
        let yMin: Double?
        let yMax: Double?
        let ha: Double
        let advanceWidth: Double?

        private enum CodingKeys: String, CodingKey {
            case yMin = "y_min"
            case yMax = "y_max"
            case ha
            case advanceWidth
        }
    }

    private struct TextFontMetricsFile: Decodable {
        let fontFamily: String
        let resolution: Double
        let glyphs: [String: TextFontGlyphMetrics]
    }

    private struct RegisteredTextFontMetrics {
        let family: String
        let resolution: Double
        let glyphs: [String: TextFontGlyphMetrics]
        let maxSizeGlyph: String
        let bold: Bool
        let italic: Bool
    }

    // MARK: - Configuration

    /// Fallback average character width in em units when no rendering context is available.
    public var fallbackAverageCharacterWidthInEm: Double

    // MARK: - State

    public private(set) var fontInfo: FontInfo
    public weak var context: RenderContext?

    private var widthCachePx: [String: Double] = [:]
    private var extentCache: [String: TextExtent] = [:]
    private var registeredMetrics: RegisteredTextFontMetrics?

    // MARK: - Init

    public init(
        fontInfo: FontInfo = FontInfo(),
        context: RenderContext? = nil,
        fallbackAverageCharacterWidthInEm: Double = 0.6
    ) {
        self.fontInfo = VexFont.validate(fontInfo: fontInfo)
        self.context = context
        self.fallbackAverageCharacterWidthInEm = fallbackAverageCharacterWidthInEm
        refreshRegisteredMetrics()
    }

    /// Convenience constructor matching VexFlow's `TextFormatter.create(...)` intent.
    public static func create(
        font: FontInfo = FontInfo(),
        context: RenderContext? = nil
    ) -> TextFormatter {
        TextFormatter(fontInfo: font, context: context)
    }

    // MARK: - Font

    @discardableResult
    public func setFont(_ font: FontInfo) -> Self {
        fontInfo = VexFont.validate(fontInfo: font)
        refreshRegisteredMetrics()
        clearCache()
        return self
    }

    /// Set font size in points.
    @discardableResult
    public func setFontSize(_ size: Double) -> Self {
        fontInfo.size = "\(size)pt"
        clearCache()
        return self
    }

    public var fontSizeInPixels: Double {
        VexFont.convertSizeToPixelValue(fontInfo.size)
    }

    /// Approximate VexFlow's `TextFormatter.maxHeight` behavior for common text families.
    /// This is used by modifiers such as Bend/Vibrato in formatting paths.
    public var maxHeight: Double {
        if let registeredMetrics {
            let maxGlyph = glyphMetrics(for: registeredMetrics.maxSizeGlyph, in: registeredMetrics)
            if let maxGlyph {
                return (maxGlyph.ha / registeredMetrics.resolution) * fontSizeInPixels
            }
        }

        if let scale = Self.maxHeightScale(for: fontInfo.family) {
            return fontSizeInPixels * scale
        }
        return getYForStringInPx("M").height
    }

    // MARK: - Measurement

    /// Measure raw text bounds.
    public func measure(_ text: String) -> TextMeasure {
        if let context {
            context.save()
            context.setFont(fontInfo)
            let measure = context.measureText(text)
            context.restore()
            return measure
        }

        if let registeredMetrics {
            let extent = extentForTextUsingRegisteredMetrics(text, metrics: registeredMetrics)
            let width = widthForTextUsingRegisteredMetrics(text, metrics: registeredMetrics)
            return TextMeasure(x: 0, y: extent.yMin, width: width, height: extent.height)
        }

        let px = fontSizeInPixels
        let width = Double(text.count) * fallbackAverageCharacterWidthInEm * px
        let yMin = -px * 0.8
        return TextMeasure(x: 0, y: yMin, width: width, height: px)
    }

    /// Text width in pixels.
    public func getWidthForTextInPx(_ text: String) -> Double {
        if let cached = widthCachePx[text] { return cached }

        let value: Double
        if context != nil {
            value = measure(text).width
        } else if let registeredMetrics {
            value = widthForTextUsingRegisteredMetrics(text, metrics: registeredMetrics)
        } else {
            value = measure(text).width
        }

        widthCachePx[text] = value
        return value
    }

    /// Text width in em units.
    public func getWidthForTextInEm(_ text: String) -> Double {
        let px = max(fontSizeInPixels, 1)
        return getWidthForTextInPx(text) / px
    }

    /// Vertical extent for a single character.
    public func getYForCharacterInPx(_ character: Character) -> TextExtent {
        getYForStringInPx(String(character))
    }

    /// Vertical extent for a text string.
    public func getYForStringInPx(_ text: String) -> TextExtent {
        if let cached = extentCache[text] { return cached }

        let extent: TextExtent
        if context != nil {
            let m = measure(text)
            extent = TextExtent(yMin: m.y, yMax: m.y + m.height, height: m.height)
        } else if let registeredMetrics {
            extent = extentForTextUsingRegisteredMetrics(text, metrics: registeredMetrics)
        } else {
            let m = measure(text)
            extent = TextExtent(yMin: m.y, yMax: m.y + m.height, height: m.height)
        }

        extentCache[text] = extent
        return extent
    }

    // MARK: - Cache

    public func clearCache() {
        widthCachePx.removeAll(keepingCapacity: true)
        extentCache.removeAll(keepingCapacity: true)
    }

    private static let defaultRegisteredTextFontMetrics: [RegisteredTextFontMetrics] = {
        let specs: [(resource: String, bold: Bool, italic: Bool, maxSizeGlyph: String)] = [
            ("sans_bold_text_metrics", true, false, "@"),
            ("sans_text_metrics", false, false, "@"),
            ("serif_text_metrics", false, false, "@"),
            ("robotoslab_glyphs", false, false, "b"),
            ("petalumascript_glyphs", false, false, "b"),
        ]

        let decoder = JSONDecoder()
        var registered: [RegisteredTextFontMetrics] = []
        for spec in specs {
            let url = Bundle.module.url(forResource: spec.resource, withExtension: "json")
                ?? Bundle.module.url(forResource: spec.resource, withExtension: "json", subdirectory: "text_metrics")
            guard
                let url,
                let data = try? Data(contentsOf: url),
                let parsed = try? decoder.decode(TextFontMetricsFile.self, from: data)
            else { continue }

            registered.append(RegisteredTextFontMetrics(
                family: parsed.fontFamily,
                resolution: parsed.resolution,
                glyphs: parsed.glyphs,
                maxSizeGlyph: spec.maxSizeGlyph,
                bold: spec.bold,
                italic: spec.italic
            ))
        }
        return registered
    }()

    private static func matchingRegisteredMetrics(for requestedFont: FontInfo) -> RegisteredTextFontMetrics? {
        let normalized = VexFont.validate(fontInfo: requestedFont)
        let families = normalized.family
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidatesSource = defaultRegisteredTextFontMetrics
        guard !candidatesSource.isEmpty else { return nil }

        var candidates: [RegisteredTextFontMetrics] = []
        for requestedFamily in families {
            let matching = candidatesSource.filter {
                $0.family.lowercased().hasPrefix(requestedFamily.lowercased())
            }
            if !matching.isEmpty {
                candidates = matching
                break
            }
        }

        if candidates.isEmpty {
            candidates = [candidatesSource[0]]
        }

        if candidates.count == 1 {
            return candidates[0]
        }

        let wantsBold = VexFont.isBold(normalized.weight)
        let wantsItalic = VexFont.isItalic(normalized.style)
        if let perfect = candidates.first(where: { $0.bold == wantsBold && $0.italic == wantsItalic }) {
            return perfect
        }
        if let partial = candidates.first(where: { $0.bold == wantsBold || $0.italic == wantsItalic }) {
            return partial
        }
        return candidates[0]
    }

    private func refreshRegisteredMetrics() {
        registeredMetrics = Self.matchingRegisteredMetrics(for: fontInfo)
    }

    private func widthForTextUsingRegisteredMetrics(_ text: String, metrics: RegisteredTextFontMetrics) -> Double {
        var widthInEm = 0.0
        for character in text {
            let glyph = glyphMetrics(for: String(character), in: metrics)
            if let advanceWidth = glyph?.advanceWidth {
                widthInEm += advanceWidth / metrics.resolution
            } else {
                widthInEm += fallbackAverageCharacterWidthInEm
            }
        }
        return widthInEm * fontSizeInPixels
    }

    private func extentForTextUsingRegisteredMetrics(_ text: String, metrics: RegisteredTextFontMetrics) -> TextExtent {
        var yMin = 0.0
        var yMax = maxHeightForRegisteredMetrics(metrics)

        for character in text {
            guard let glyph = glyphMetrics(for: String(character), in: metrics) else { continue }
            if let glyphMin = glyph.yMin {
                yMin = min(yMin, (glyphMin / metrics.resolution) * fontSizeInPixels)
            }
            if let glyphMax = glyph.yMax {
                yMax = max(yMax, (glyphMax / metrics.resolution) * fontSizeInPixels)
            }
        }

        return TextExtent(yMin: yMin, yMax: yMax, height: yMax - yMin)
    }

    private func maxHeightForRegisteredMetrics(_ metrics: RegisteredTextFontMetrics) -> Double {
        guard let glyph = glyphMetrics(for: metrics.maxSizeGlyph, in: metrics) else {
            return fontSizeInPixels
        }
        return (glyph.ha / metrics.resolution) * fontSizeInPixels
    }

    private func glyphMetrics(for character: String, in metrics: RegisteredTextFontMetrics) -> TextFontGlyphMetrics? {
        if let glyph = metrics.glyphs[character] {
            return glyph
        }
        return metrics.glyphs[metrics.maxSizeGlyph]
    }

    private static func maxHeightScale(for family: String) -> Double? {
        let normalized = family.lowercased()
        // From upstream text font metrics:
        // Arial ('@'.ha=1923, resolution=2048)
        if normalized.contains("arial") {
            return 1923.0 / 2048.0
        }
        // sans-serif ('@'.ha=1924, resolution=2048)
        if normalized.contains("sans-serif") {
            return 1924.0 / 2048.0
        }
        // serif / Times-like fallback ('@'.ha=1415, resolution=2048)
        if normalized.contains("times") || normalized.contains("serif") {
            return 1415.0 / 2048.0
        }
        // Roboto Slab ('b'.ha=1581, resolution=2048)
        if normalized.contains("roboto slab") {
            return 1581.0 / 2048.0
        }
        return nil
    }
}
