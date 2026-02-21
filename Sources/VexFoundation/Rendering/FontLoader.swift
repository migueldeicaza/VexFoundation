// VexFoundation - Font loading for VexFlow glyph data.

import Foundation

public enum FontLoaderError: Error, LocalizedError, Equatable, Sendable {
    case missingFontResource(String)
    case failedToLoadFont(resource: String, reason: String)
    case missingMetricsResource(String)
    case invalidMetricsFormat(String)
    case failedToLoadMetrics(resource: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .missingFontResource(let resource):
            return "Missing font resource: \(resource).json"
        case .failedToLoadFont(let resource, let reason):
            return "Failed to load font \(resource): \(reason)"
        case .missingMetricsResource(let resource):
            return "Missing metrics resource: \(resource).json"
        case .invalidMetricsFormat(let resource):
            return "Invalid metrics format in \(resource).json"
        case .failedToLoadMetrics(let resource, let reason):
            return "Failed to load metrics \(resource): \(reason)"
        }
    }
}

/// JSON structure matching the glyph font files (bravura_glyphs.json, etc.)
private struct FontFileJSON: Decodable {
    let glyphs: [String: GlyphJSON]
    let fontFamily: String?
    let resolution: Double
    let generatedOn: String?
}

private struct GlyphJSON: Decodable {
    let x_min: Double
    let x_max: Double
    let y_min: Double?
    let y_max: Double?
    let ha: Double
    let leftSideBearing: Double?
    let advanceWidth: Double?
    let o: String?
}

/// Loads VexFlow font data from bundled JSON resources.
public enum FontLoader {

    /// Load a music font from a bundled JSON resource file.
    /// - Parameters:
    ///   - name: The display name (e.g., "Bravura")
    ///   - resourceName: The JSON filename without extension (e.g., "bravura_glyphs")
    ///   - metricsResourceName: Optional metrics JSON filename (e.g., "common_metrics")
    /// - Returns: A configured VexFont object
    @discardableResult
    public static func loadFontThrowing(
        name: String,
        resourceName: String,
        metricsResourceName: String? = nil
    ) throws -> VexFont {
        let data = try loadFontData(resourceName: resourceName)
        let metrics: FontMetrics?
        if let metricsResourceName {
            metrics = try loadMetrics(resourceName: metricsResourceName)
        } else {
            metrics = nil
        }
        return VexFont.load(name: name, data: data, metrics: metrics)
    }

    /// Load a music font from a bundled JSON resource file.
    /// - Parameters:
    ///   - name: The display name (e.g., "Bravura")
    ///   - resourceName: The JSON filename without extension (e.g., "bravura_glyphs")
    ///   - metricsResourceName: Optional metrics JSON filename (e.g., "common_metrics")
    /// - Returns: A configured VexFont object
    @discardableResult
    public static func loadFont(
        name: String,
        resourceName: String,
        metricsResourceName: String? = nil
    ) -> VexFont {
        (try? loadFontThrowing(
            name: name,
            resourceName: resourceName,
            metricsResourceName: metricsResourceName
        )) ?? VexFont.load(name: name)
    }

    /// Load Bravura font (the default music engraving font).
    @discardableResult
    public static func loadBravuraThrowing() throws -> VexFont {
        try loadFontThrowing(
            name: "Bravura",
            resourceName: "bravura_glyphs",
            metricsResourceName: "common_metrics"
        )
    }

    /// Load Bravura font (the default music engraving font).
    @discardableResult
    public static func loadBravura() -> VexFont {
        (try? loadBravuraThrowing()) ?? VexFont.load(name: "Bravura")
    }

    /// Load Gonville font.
    @discardableResult
    public static func loadGonvilleThrowing() throws -> VexFont {
        try loadFontThrowing(
            name: "Gonville",
            resourceName: "gonville_glyphs",
            metricsResourceName: "common_metrics"
        )
    }

    /// Load Gonville font.
    @discardableResult
    public static func loadGonville() -> VexFont {
        (try? loadGonvilleThrowing()) ?? VexFont.load(name: "Gonville")
    }

    /// Load Leland font.
    @discardableResult
    public static func loadLelandThrowing() throws -> VexFont {
        try loadFontThrowing(
            name: "Leland",
            resourceName: "leland_glyphs",
            metricsResourceName: "common_metrics"
        )
    }

    /// Load Leland font.
    @discardableResult
    public static func loadLeland() -> VexFont {
        (try? loadLelandThrowing()) ?? VexFont.load(name: "Leland")
    }

    /// Load Petaluma font.
    @discardableResult
    public static func loadPetalumaThrowing() throws -> VexFont {
        try loadFontThrowing(
            name: "Petaluma",
            resourceName: "petaluma_glyphs",
            metricsResourceName: "common_metrics"
        )
    }

    /// Load Petaluma font.
    @discardableResult
    public static func loadPetaluma() -> VexFont {
        (try? loadPetalumaThrowing()) ?? VexFont.load(name: "Petaluma")
    }

    /// Load Custom (VexFlowCustom) font.
    @discardableResult
    public static func loadCustomThrowing() throws -> VexFont {
        try loadFontThrowing(
            name: "Custom",
            resourceName: "custom_glyphs",
            metricsResourceName: "common_metrics"
        )
    }

    /// Load Custom (VexFlowCustom) font.
    @discardableResult
    public static func loadCustom() -> VexFont {
        (try? loadCustomThrowing()) ?? VexFont.load(name: "Custom")
    }

    /// Load all fonts and set up the default music font stack (Bravura + Custom).
    public static func loadAllFontsThrowing() throws {
        let bravura = try loadBravuraThrowing()
        let custom = try loadCustomThrowing()
        _ = try loadGonvilleThrowing()
        _ = try loadLelandThrowing()
        _ = try loadPetalumaThrowing()

        // Default stack: Bravura as primary, Custom as fallback
        Glyph.setMusicFont([bravura, custom])
    }

    /// Load all fonts and set up the default music font stack (Bravura + Custom).
    public static func loadAllFonts() {
        if (try? loadAllFontsThrowing()) == nil {
            Glyph.setMusicFont([VexFont.load(name: "Bravura"), VexFont.load(name: "Custom")])
        }
    }

    /// Set up a minimal font configuration (Bravura + Custom).
    public static func loadDefaultFontsThrowing() throws {
        let bravura = try loadBravuraThrowing()
        let custom = try loadCustomThrowing()
        Glyph.setMusicFont([bravura, custom])
    }

    /// Set up a minimal font configuration (Bravura + Custom).
    public static func loadDefaultFonts() {
        if (try? loadDefaultFontsThrowing()) == nil {
            Glyph.setMusicFont([VexFont.load(name: "Bravura"), VexFont.load(name: "Custom")])
        }
    }

    // MARK: - Internal

    private static func loadFontData(resourceName: String) throws -> FontData {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw FontLoaderError.missingFontResource(resourceName)
        }

        do {
            let data = try Data(contentsOf: url)
            let fontFile = try JSONDecoder().decode(FontFileJSON.self, from: data)

            var glyphs: [String: FontGlyph] = [:]
            for (key, g) in fontFile.glyphs {
                glyphs[key] = FontGlyph(
                    xMin: g.x_min,
                    xMax: g.x_max,
                    yMin: g.y_min,
                    yMax: g.y_max,
                    ha: g.ha,
                    leftSideBearing: g.leftSideBearing,
                    advanceWidth: g.advanceWidth,
                    outline: g.o
                )
            }

            return FontData(
                glyphs: glyphs,
                fontFamily: fontFile.fontFamily,
                resolution: fontFile.resolution,
                generatedOn: fontFile.generatedOn
            )
        } catch {
            throw FontLoaderError.failedToLoadFont(
                resource: resourceName,
                reason: String(describing: error)
            )
        }
    }

    private static func loadMetrics(resourceName: String) throws -> FontMetrics {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw FontLoaderError.missingMetricsResource(resourceName)
        }

        do {
            let data = try Data(contentsOf: url)
            guard let metrics = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FontLoaderError.invalidMetricsFormat(resourceName)
            }
            return metrics
        } catch {
            throw FontLoaderError.failedToLoadMetrics(
                resource: resourceName,
                reason: String(describing: error)
            )
        }
    }
}
