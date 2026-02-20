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

    // MARK: - Configuration

    /// Fallback average character width in em units when no rendering context is available.
    public var fallbackAverageCharacterWidthInEm: Double

    // MARK: - State

    public private(set) var fontInfo: FontInfo
    public weak var context: RenderContext?

    private var widthCachePx: [String: Double] = [:]
    private var extentCache: [String: TextExtent] = [:]

    // MARK: - Init

    public init(
        fontInfo: FontInfo = FontInfo(),
        context: RenderContext? = nil,
        fallbackAverageCharacterWidthInEm: Double = 0.6
    ) {
        self.fontInfo = VexFont.validate(fontInfo: fontInfo)
        self.context = context
        self.fallbackAverageCharacterWidthInEm = fallbackAverageCharacterWidthInEm
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

        let px = fontSizeInPixels
        let width = Double(text.count) * fallbackAverageCharacterWidthInEm * px
        let yMin = -px * 0.8
        return TextMeasure(x: 0, y: yMin, width: width, height: px)
    }

    /// Text width in pixels.
    public func getWidthForTextInPx(_ text: String) -> Double {
        if let cached = widthCachePx[text] { return cached }
        let value = measure(text).width
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
        let m = measure(text)
        let extent = TextExtent(yMin: m.y, yMax: m.y + m.height, height: m.height)
        extentCache[text] = extent
        return extent
    }

    // MARK: - Cache

    public func clearCache() {
        widthCachePx.removeAll(keepingCapacity: true)
        extentCache.removeAll(keepingCapacity: true)
    }
}
