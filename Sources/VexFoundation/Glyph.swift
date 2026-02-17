// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Glyph Types

/// Glyph outline command opcodes.
public enum OutlineCode: Int {
    case move = 0
    case line = 1
    case quadratic = 2
    case bezier = 3
}

/// Metrics computed for a glyph.
public struct GlyphMetrics {
    public var width: Double
    public var height: Double
    public var xMin: Double
    public var xMax: Double
    public var xShift: Double
    public var yShift: Double
    public var scale: Double
    public var ha: Double
    public var outline: [Double]
    public var font: VexFont
}

/// Options for glyph rendering.
public struct GlyphOptions {
    public var category: String?
    public init(category: String? = nil) {
        self.category = category
    }
}

// MARK: - GlyphOutline (Outline Iterator)

/// Iterates over a parsed glyph outline, applying scale and position transformations.
struct GlyphOutline {
    private let outline: [Double]
    private let originX: Double
    private let originY: Double
    private let scale: Double
    private let precision: Double
    private var i: Int = 0

    init(outline: [Double], originX: Double, originY: Double, scale: Double) {
        self.outline = outline
        self.originX = originX
        self.originY = originY
        self.scale = scale
        self.precision = pow(10, Double(Tables.RENDER_PRECISION_PLACES))
    }

    var done: Bool { i >= outline.count }

    mutating func next() -> Int {
        let val = outline[i]
        i += 1
        return Int((val * precision).rounded() / precision)
    }

    mutating func nextX() -> Double {
        let val = outline[i]
        i += 1
        return ((originX + val * scale) * precision).rounded() / precision
    }

    mutating func nextY() -> Double {
        let val = outline[i]
        i += 1
        return ((originY - val * scale) * precision).rounded() / precision
    }

    /// Parse an outline string ("m 0 0 l 100 200 q ...") into a numeric array.
    static func parse(_ str: String) -> [Double] {
        var result: [Double] = []
        let parts = str.split(separator: " ")
        var i = 0
        while i < parts.count {
            let cmd = parts[i]
            i += 1
            switch cmd {
            case "m":
                result.append(Double(OutlineCode.move.rawValue))
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
            case "l":
                result.append(Double(OutlineCode.line.rawValue))
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
            case "q":
                result.append(Double(OutlineCode.quadratic.rawValue))
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
            case "b":
                result.append(Double(OutlineCode.bezier.rawValue))
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
                result.append(Double(parts[i]) ?? 0); i += 1
            case "z":
                break // close path, implicit in fill
            default:
                break
            }
        }
        return result
    }
}

// MARK: - Glyph Cache

/// Cache entry storing computed glyph metrics and bounding box.
final class GlyphCacheEntry {
    let metrics: GlyphMetrics
    let bbox: BoundingBox
    let point: Double

    init(fontStack: [VexFont], code: String, category: String?) {
        self.metrics = Glyph.loadMetrics(fontStack: fontStack, code: code, category: category)
        self.bbox = Glyph.getOutlineBoundingBox(
            outline: metrics.outline,
            scale: metrics.scale,
            xPos: metrics.xShift,
            yPos: metrics.yShift
        )
        if let category {
            self.point = Glyph.lookupFontMetric(
                font: metrics.font, category: category, code: code, key: "point", defaultValue: -1
            )
        } else {
            self.point = -1
        }
    }
}

/// Thread-safe glyph cache keyed by font stack + glyph code.
final class GlyphCache {
    private var cache: [String: [String: GlyphCacheEntry]] = [:]
    private let lock = NSLock()

    func lookup(code: String, category: String?) -> GlyphCacheEntry {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = Glyph.CURRENT_CACHE_KEY
        if cache[cacheKey] == nil {
            cache[cacheKey] = [:]
        }
        let key = category != nil ? "\(code)%\(category!)" : code
        if let entry = cache[cacheKey]![key] {
            return entry
        }
        let entry = GlyphCacheEntry(fontStack: Glyph.MUSIC_FONT_STACK, code: code, category: category)
        cache[cacheKey]![key] = entry
        return entry
    }
}

// MARK: - Glyph Class

/// Renders SMuFL music notation glyphs from outline data.
public final class Glyph: VexElement {

    // MARK: - Static Members

    override public class var CATEGORY: String { "Glyph" }

    nonisolated(unsafe) static var glyphCache = GlyphCache()

    /// The current cache key, computed from the font stack names.
    nonisolated(unsafe) public static var CURRENT_CACHE_KEY: String = ""

    /// The music font stack used for glyph lookup. Set via setMusicFont().
    nonisolated(unsafe) public static var MUSIC_FONT_STACK: [VexFont] = []

    /// Configure the music font stack. Call this before rendering any glyphs.
    public static func setMusicFont(_ fonts: [VexFont]) {
        MUSIC_FONT_STACK = fonts
        CURRENT_CACHE_KEY = fonts.map { $0.name }.joined(separator: ",")
    }

    // MARK: - Static Font Metric Lookup

    /// Look up a font metric, first trying `glyphs.{category}.{code}.{key}`,
    /// falling back to `glyphs.{category}.{key}`.
    public static func lookupFontMetric(
        font: VexFont, category: String, code: String, key: String, defaultValue: Double
    ) -> Double {
        if let value = font.lookupMetric("glyphs.\(category).\(code).\(key)") as? Double {
            return value
        }
        if let value = font.lookupMetric("glyphs.\(category).\(key)") as? Double {
            return value
        }
        return defaultValue
    }

    /// Look up a glyph in the font stack, returning the first font that contains it.
    public static func lookupGlyph(fontStack: [VexFont], code: String) throws -> (font: VexFont, glyph: FontGlyph) {
        for font in fontStack {
            if let glyphs = try? font.getGlyphs(), let glyph = glyphs[code] {
                return (font, glyph)
            }
        }
        throw VexError("BadGlyph", "Glyph \(code) does not exist in font.")
    }

    /// Load metrics for a glyph code, parsing its outline if needed.
    public static func loadMetrics(fontStack: [VexFont], code: String, category: String?) -> GlyphMetrics {
        let (font, glyph) = try! lookupGlyph(fontStack: fontStack, code: code)

        guard let outlineStr = glyph.outline else {
            fatalError("[VexError] BadGlyph: Glyph \(code) has no outline defined.")
        }

        var xShift: Double = 0
        var yShift: Double = 0
        var scale: Double = 1

        if let category {
            xShift = lookupFontMetric(font: font, category: category, code: code, key: "shiftX", defaultValue: 0)
            yShift = lookupFontMetric(font: font, category: category, code: code, key: "shiftY", defaultValue: 0)
            scale = lookupFontMetric(font: font, category: category, code: code, key: "scale", defaultValue: 1)
        }

        // Parse and cache the outline
        var parsedOutline: [Double]
        if let cached = glyph.cachedOutline {
            parsedOutline = cached
        } else {
            parsedOutline = GlyphOutline.parse(outlineStr)
        }

        return GlyphMetrics(
            width: glyph.xMax - glyph.xMin,
            height: glyph.ha,
            xMin: glyph.xMin,
            xMax: glyph.xMax,
            xShift: xShift,
            yShift: yShift,
            scale: scale,
            ha: glyph.ha,
            outline: parsedOutline,
            font: font
        )
    }

    // MARK: - Static Rendering

    /// Render a glyph from the default font stack.
    @discardableResult
    public static func renderGlyph(
        ctx: RenderContext,
        xPos: Double,
        yPos: Double,
        point: Double,
        code: String,
        category: String? = nil,
        scale customScale: Double = 1
    ) -> GlyphMetrics {
        let data = glyphCache.lookup(code: code, category: category)
        let metrics = data.metrics
        var pt = point
        if data.point != -1 {
            pt = data.point
        }

        let resolution = (try? metrics.font.getResolution()) ?? 1000
        let scale = ((pt * 72.0) / (resolution * 100.0)) * metrics.scale * customScale

        renderOutline(
            ctx: ctx,
            outline: metrics.outline,
            scale: scale,
            xPos: xPos + metrics.xShift * customScale,
            yPos: yPos + metrics.yShift * customScale
        )
        return metrics
    }

    /// Render a glyph outline (the core drawing loop).
    public static func renderOutline(
        ctx: RenderContext,
        outline: [Double],
        scale: Double,
        xPos: Double,
        yPos: Double
    ) {
        var go = GlyphOutline(outline: outline, originX: xPos, originY: yPos, scale: scale)

        ctx.beginPath()
        while !go.done {
            let cmd = go.next()
            switch OutlineCode(rawValue: cmd) {
            case .move:
                ctx.moveTo(go.nextX(), go.nextY())
            case .line:
                ctx.lineTo(go.nextX(), go.nextY())
            case .quadratic:
                let x = go.nextX(), y = go.nextY()
                ctx.quadraticCurveTo(go.nextX(), go.nextY(), x, y)
            case .bezier:
                let x = go.nextX(), y = go.nextY()
                ctx.bezierCurveTo(go.nextX(), go.nextY(), go.nextX(), go.nextY(), x, y)
            case .none:
                break
            }
        }
        ctx.fill()
    }

    /// Compute the bounding box of a glyph outline.
    public static func getOutlineBoundingBox(
        outline: [Double], scale: Double, xPos: Double, yPos: Double
    ) -> BoundingBox {
        var go = GlyphOutline(outline: outline, originX: xPos, originY: yPos, scale: scale)
        var comp = BoundingBoxComputation()

        var penX = xPos, penY = yPos
        while !go.done {
            let cmd = go.next()
            switch OutlineCode(rawValue: cmd) {
            case .move:
                penX = go.nextX()
                penY = go.nextY()
            case .line:
                comp.addPoint(penX, penY)
                penX = go.nextX()
                penY = go.nextY()
                comp.addPoint(penX, penY)
            case .quadratic:
                let x = go.nextX(), y = go.nextY()
                comp.addQuadraticCurve(penX, penY, go.nextX(), go.nextY(), x, y)
                penX = x; penY = y
            case .bezier:
                let x = go.nextX(), y = go.nextY()
                comp.addBezierCurve(penX, penY, go.nextX(), go.nextY(), go.nextX(), go.nextY(), x, y)
                penX = x; penY = y
            case .none:
                break
            }
        }

        return BoundingBox(x: comp.getX1(), y: comp.getY1(), w: comp.width(), h: comp.height())
    }

    /// Get the rendered width of a glyph at a given point size.
    public static func getWidth(code: String, point: Double, category: String? = nil) -> Double {
        let data = glyphCache.lookup(code: code, category: category)
        var pt = point
        if data.point != -1 {
            pt = data.point
        }
        let resolution = (try? data.metrics.font.getResolution()) ?? 1000
        let scale = (pt * 72) / (resolution * 100)
        return data.bbox.w * scale
    }

    // MARK: - Instance Members

    public var bbox: BoundingBox = BoundingBox(x: 0, y: 0, w: 0, h: 0)
    public var code: String
    public var glyphMetrics: GlyphMetrics!
    public var topGlyphs: [Glyph] = []
    public var botGlyphs: [Glyph] = []

    public var options: GlyphOptions = GlyphOptions()
    public var originShift: (x: Double, y: Double) = (0, 0)
    public var xShift: Double = 0
    public var yShift: Double = 0
    public var glyphScale: Double = 1
    public var point: Double

    // MARK: - Init

    public init(code: String, point: Double, options: GlyphOptions? = nil) {
        self.code = code
        self.point = point
        super.init()

        if let options {
            self.options = options
            reset()
        } else {
            reset()
        }
    }

    // MARK: - Methods

    override public func draw() throws {
        // Default: no-op. Use render() or renderToStave() instead.
    }

    public func getCode() -> String { code }

    @discardableResult
    public func setPoint(_ point: Double) -> Glyph {
        self.point = point
        return self
    }

    public func getXShift() -> Double { xShift }

    @discardableResult
    public func setXShift(_ x: Double) -> Glyph {
        self.xShift = x
        return self
    }

    public func getYShift() -> Double { yShift }

    @discardableResult
    public func setYShift(_ y: Double) -> Glyph {
        self.yShift = y
        return self
    }

    /// Reset metrics from the cache.
    public func reset() {
        let data = Glyph.glyphCache.lookup(code: code, category: options.category)
        self.glyphMetrics = data.metrics
        if data.point != -1 {
            self.point = data.point
        }

        let resolution = (try? glyphMetrics.font.getResolution()) ?? 1000
        self.glyphScale = (point * 72) / (resolution * 100)
        self.bbox = BoundingBox(
            x: data.bbox.x * glyphScale,
            y: data.bbox.y * glyphScale,
            w: data.bbox.w * glyphScale,
            h: data.bbox.h * glyphScale
        )
    }

    public func getMetrics() -> GlyphMetrics {
        let m = glyphMetrics!
        let s = glyphScale * m.scale
        return GlyphMetrics(
            width: bbox.w,
            height: bbox.h,
            xMin: m.xMin * s,
            xMax: m.xMax * s,
            xShift: m.xShift,
            yShift: m.yShift,
            scale: s,
            ha: m.ha,
            outline: m.outline,
            font: m.font
        )
    }

    public func setOriginX(_ x: Double) {
        let originX = abs(bbox.x / bbox.w)
        let shift = (x - originX) * bbox.w
        originShift.x = -shift
    }

    public func setOriginY(_ y: Double) {
        let originY = abs(bbox.y / bbox.h)
        let shift = (y - originY) * bbox.h
        originShift.y = -shift
    }

    public func setOrigin(_ x: Double, _ y: Double) {
        setOriginX(x)
        setOriginY(y)
    }

    /// Render the glyph at (x, y) using the given context.
    public func render(ctx: RenderContext, x: Double, y: Double) {
        let m = glyphMetrics!
        let scale = glyphScale * m.scale

        setRendered()
        applyStyle(context: ctx)
        let xPos = x + originShift.x + m.xShift
        let yPos = y + originShift.y + m.yShift
        Glyph.renderOutline(ctx: ctx, outline: m.outline, scale: scale, xPos: xPos, yPos: yPos)
        restoreStyle(context: ctx)
    }
}
