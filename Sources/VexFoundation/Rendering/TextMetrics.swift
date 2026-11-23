// VexFoundation - Text measurement and layout with CoreText.
//
// VexFlow 5 measures every element (music glyphs included) with the canvas
// `measureText()` API. This file gives the same `TextMetrics` semantics:
// - `width` is the sum of glyph advances.
// - `actualBoundingBox*` are the ink bounds relative to the alignment point
//   (ascent up and descent down are positive).
// Each character uses the first family in the CSS family list that has a glyph
// for it, which is how browsers resolve `font-family: Bravura,Academico`.

import CoreGraphics
import CoreText
import Foundation

/// Port of the browser `TextMetrics` dictionary.
public struct TextMetrics: Sendable, Equatable {
    public var width: Double = 0
    public var actualBoundingBoxLeft: Double = 0
    public var actualBoundingBoxRight: Double = 0
    public var actualBoundingBoxAscent: Double = 0
    public var actualBoundingBoxDescent: Double = 0
    public var fontBoundingBoxAscent: Double = 0
    public var fontBoundingBoxDescent: Double = 0

    public init(
        width: Double = 0,
        actualBoundingBoxLeft: Double = 0,
        actualBoundingBoxRight: Double = 0,
        actualBoundingBoxAscent: Double = 0,
        actualBoundingBoxDescent: Double = 0,
        fontBoundingBoxAscent: Double = 0,
        fontBoundingBoxDescent: Double = 0
    ) {
        self.width = width
        self.actualBoundingBoxLeft = actualBoundingBoxLeft
        self.actualBoundingBoxRight = actualBoundingBoxRight
        self.actualBoundingBoxAscent = actualBoundingBoxAscent
        self.actualBoundingBoxDescent = actualBoundingBoxDescent
        self.fontBoundingBoxAscent = fontBoundingBoxAscent
        self.fontBoundingBoxDescent = fontBoundingBoxDescent
    }
}

/// One run of glyphs in one font. Positions are relative to the text origin
/// on the baseline, with y up (CoreText convention).
public struct TextGlyphRun: @unchecked Sendable {
    public let font: CTFont
    public let glyphs: [CGGlyph]
    public let positions: [CGPoint]
}

/// A laid-out piece of text.
public struct TextLayout: @unchecked Sendable {
    public let runs: [TextGlyphRun]
    public let metrics: TextMetrics

    /// A path of the text outlines, with the origin at (`x`, `y`) in a y-down
    /// coordinate space (SVG / canvas convention).
    public func path(x: Double, y: Double) -> CGPath {
        let path = CGMutablePath()
        for run in runs {
            for (i, glyph) in run.glyphs.enumerated() {
                let p = run.positions[i]
                var t = CGAffineTransform(translationX: CGFloat(x) + p.x, y: CGFloat(y) - p.y).scaledBy(x: 1, y: -1)
                if let glyphPath = CTFontCreatePathForGlyph(run.font, glyph, &t) {
                    path.addPath(glyphPath)
                }
            }
        }
        return path
    }
}

/// CoreText text measurement with a bounded cache.
public enum TextMeasurer {
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var entries: [String: TextLayout] = [:]
        var order: [String] = []
        var generation = -1
        let capacity = 4096
    }

    private static let cache = Cache()

    /// Clear the measurement cache.
    public static func clearCache() {
        cache.lock.lock()
        cache.entries.removeAll()
        cache.order.removeAll()
        cache.lock.unlock()
    }

    /// Measure `text` with `fontInfo`.
    public static func measure(_ text: String, fontInfo: FontInfo) -> TextMetrics {
        layout(text, fontInfo: fontInfo).metrics
    }

    /// Lay out `text` with `fontInfo`.
    public static func layout(_ text: String, fontInfo: FontInfo) -> TextLayout {
        let key = "\(fontInfo.style)|\(fontInfo.weight)|\(fontInfo.size)|\(fontInfo.family)|\(text)"
        let generation = FontRegistry.shared.currentGeneration
        cache.lock.lock()
        if cache.generation != generation {
            cache.entries.removeAll()
            cache.order.removeAll()
            cache.generation = generation
        }
        if let hit = cache.entries[key] {
            cache.lock.unlock()
            return hit
        }
        cache.lock.unlock()

        let result = computeLayout(text, fontInfo: fontInfo)

        cache.lock.lock()
        if cache.entries[key] == nil {
            cache.entries[key] = result
            cache.order.append(key)
            if cache.order.count > cache.capacity {
                let drop = cache.order.count - cache.capacity
                for k in cache.order.prefix(drop) { cache.entries.removeValue(forKey: k) }
                cache.order.removeFirst(drop)
            }
        }
        cache.lock.unlock()
        return result
    }

    /// Resolve the CSS family list of `fontInfo` to fonts, in order.
    public static func fonts(for fontInfo: FontInfo) -> [CTFont] {
        let sizePx = VexFont.convertSizeToPixelValue(fontInfo.size)
        let bold = VexFont.isBold(fontInfo.weight)
        let italic = VexFont.isItalic(fontInfo.style)
        var result: [CTFont] = []
        for family in FontRegistry.splitFamilies(fontInfo.family) {
            if let font = FontRegistry.shared.font(family: family, sizePx: sizePx, bold: bold, italic: italic) {
                result.append(font)
            }
        }
        if result.isEmpty, let fallback = FontRegistry.shared.font(family: "serif", sizePx: sizePx, bold: bold, italic: italic) {
            // Browsers default to a serif face (Times) when nothing matches.
            result.append(fallback)
        }
        return result
    }

    private static func fontIndex(for character: Character, in fonts: [CTFont]) -> Int? {
        let utf16 = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        for (i, font) in fonts.enumerated() {
            if CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count), glyphs.allSatisfy({ $0 != 0 }) {
                return i
            }
        }
        return nil
    }

    private static func computeLayout(_ text: String, fontInfo: FontInfo) -> TextLayout {
        let fonts = fonts(for: fontInfo)
        guard !text.isEmpty, let primary = fonts.first else {
            var m = TextMetrics()
            if let primary = fonts.first {
                m.fontBoundingBoxAscent = Double(CTFontGetAscent(primary))
                m.fontBoundingBoxDescent = Double(CTFontGetDescent(primary))
            }
            return TextLayout(runs: [], metrics: m)
        }

        // Implicit last fallback: bundled Bravura, so SMuFL glyphs that the
        // chosen music font lacks still render (browsers would use an
        // arbitrary system font here). See docs/local-deviations.md.
        var searchFonts = fonts
        if let bravura = FontRegistry.shared.font(
            family: "Bravura",
            sizePx: VexFont.convertSizeToPixelValue(fontInfo.size),
            bold: false,
            italic: false
        ) {
            searchFonts.append(bravura)
        }

        // Segment text by the first family that covers each character.
        var segments: [(fontIndex: Int?, text: String)] = []
        for ch in text {
            let idx = fontIndex(for: ch, in: searchFonts)
            if let last = segments.last, last.fontIndex == idx {
                segments[segments.count - 1].text.append(ch)
            } else {
                segments.append((idx, String(ch)))
            }
        }

        var runs: [TextGlyphRun] = []
        var penX: CGFloat = 0
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity

        for segment in segments {
            guard let fontIndex = segment.fontIndex else {
                // No font in the stack has these characters. Browsers then draw
                // the `.notdef` glyph of the first font (they do not fall back to
                // other web fonts), so do the same instead of using LastResort.
                var notdef: [CGGlyph] = [0]
                var advance = CGSize.zero
                CTFontGetAdvancesForGlyphs(primary, .default, &notdef, &advance, 1)
                var rect = CGRect.zero
                CTFontGetBoundingRectsForGlyphs(primary, .default, &notdef, &rect, 1)
                var glyphs: [CGGlyph] = []
                var positions: [CGPoint] = []
                for _ in segment.text {
                    if !rect.isEmpty && !rect.isNull {
                        let r = rect.offsetBy(dx: penX, dy: 0)
                        minX = min(minX, r.minX); maxX = max(maxX, r.maxX)
                        minY = min(minY, r.minY); maxY = max(maxY, r.maxY)
                    }
                    glyphs.append(0)
                    positions.append(CGPoint(x: penX, y: 0))
                    penX += advance.width
                }
                runs.append(TextGlyphRun(font: primary, glyphs: glyphs, positions: positions))
                continue
            }
            let font = searchFonts[fontIndex]
            // Match browser shaping: kerning applies only when the font has a
            // legacy `kern` table or a GPOS script that matches the text
            // (`latn` for Latin, `DFLT` for symbols). See `FontKerning`.
            var attributes: [CFString: Any] = [kCTFontAttributeName: font]
            if !FontKerning.appliesKerning(font: font, text: segment.text) {
                attributes[kCTKernAttributeName] = 0.0
            }
            guard let attributed = CFAttributedStringCreate(nil, segment.text as CFString, attributes as CFDictionary) else { continue }
            let line = CTLineCreateWithAttributedString(attributed)
            let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)

            let ctRuns = (CTLineGetGlyphRuns(line) as? [CTRun]) ?? []
            for ctRun in ctRuns {
                let count = CTRunGetGlyphCount(ctRun)
                guard count > 0 else { continue }
                let runAttributes = CTRunGetAttributes(ctRun) as NSDictionary
                let runFontRef = runAttributes[kCTFontAttributeName as String]
                let runFont: CTFont = runFontRef.map { $0 as! CTFont } ?? font
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(ctRun, CFRange(location: 0, length: count), &glyphs)
                CTRunGetPositions(ctRun, CFRange(location: 0, length: count), &positions)
                for i in 0..<count { positions[i].x += penX }

                var rects = [CGRect](repeating: .zero, count: count)
                CTFontGetBoundingRectsForGlyphs(runFont, .default, glyphs, &rects, count)
                for i in 0..<count where !rects[i].isEmpty && !rects[i].isNull {
                    let r = rects[i].offsetBy(dx: positions[i].x, dy: positions[i].y)
                    minX = min(minX, r.minX); maxX = max(maxX, r.maxX)
                    minY = min(minY, r.minY); maxY = max(maxY, r.maxY)
                }
                runs.append(TextGlyphRun(font: runFont, glyphs: glyphs, positions: positions))
            }
            penX += CGFloat(lineWidth)
        }

        var metrics = TextMetrics()
        metrics.width = Double(penX)
        metrics.fontBoundingBoxAscent = Double(CTFontGetAscent(primary))
        metrics.fontBoundingBoxDescent = Double(CTFontGetDescent(primary))
        if minX.isFinite {
            metrics.actualBoundingBoxLeft = Double(-minX)
            metrics.actualBoundingBoxRight = Double(maxX)
            metrics.actualBoundingBoxAscent = Double(maxY)
            metrics.actualBoundingBoxDescent = Double(-minY)
        }
        return TextLayout(runs: runs, metrics: metrics)
    }
}

/// Decides whether a browser (HarfBuzz in Chromium) would apply kerning.
///
/// HarfBuzz selects the GPOS script by tag. A font that registers its Latin
/// kerning under an invalid tag (Academico uses `LATN`) is not kerned for Latin
/// text, while CoreText kerns it anyway.
enum FontKerning {
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var scripts: [String: (hasKernTable: Bool, gposScripts: Set<String>)] = [:]
    }
    private static let cache = Cache()

    static func appliesKerning(font: CTFont, text: String) -> Bool {
        let info = tables(for: font)
        if info.hasKernTable { return true }
        let isSymbolText = text.unicodeScalars.allSatisfy { !$0.properties.isAlphabetic || (0xE000...0xF8FF).contains($0.value) }
        if isSymbolText {
            return info.gposScripts.contains("DFLT")
        }
        return info.gposScripts.contains("latn")
    }

    private static func tables(for font: CTFont) -> (hasKernTable: Bool, gposScripts: Set<String>) {
        let key = CTFontCopyPostScriptName(font) as String
        cache.lock.lock()
        if let hit = cache.scripts[key] { cache.lock.unlock(); return hit }
        cache.lock.unlock()

        let kernTag = CTFontTableTag(0x6B65_726E) // 'kern'
        let gposTag = CTFontTableTag(0x4750_4F53) // 'GPOS'
        let hasKern = CTFontCopyTable(font, kernTag, []) != nil
        var scripts = Set<String>()
        if let data = CTFontCopyTable(font, gposTag, []) as Data?, data.count >= 10 {
            let bytes = [UInt8](data)
            func u16(_ o: Int) -> Int { o + 1 < bytes.count ? Int(bytes[o]) << 8 | Int(bytes[o + 1]) : 0 }
            let scriptList = u16(4)
            let count = u16(scriptList)
            for i in 0..<count {
                let rec = scriptList + 2 + i * 6
                guard rec + 4 <= bytes.count else { break }
                if let tag = String(bytes: bytes[rec..<rec + 4], encoding: .ascii) {
                    scripts.insert(tag)
                }
            }
        }
        let result = (hasKern, scripts)
        cache.lock.lock()
        cache.scripts[key] = result
        cache.lock.unlock()
        return result
    }
}
