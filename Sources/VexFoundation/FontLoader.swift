// VexFoundation - Font loading for VexFlow glyph data.

import Foundation

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
    public static func loadFont(
        name: String,
        resourceName: String,
        metricsResourceName: String? = nil
    ) -> VexFont {
        let data = loadFontData(resourceName: resourceName)
        var metrics: FontMetrics? = nil
        if let metricsResourceName {
            metrics = loadMetrics(resourceName: metricsResourceName)
        }
        return VexFont.load(name: name, data: data, metrics: metrics)
    }

    /// Load Bravura font (the default music engraving font).
    @discardableResult
    public static func loadBravura() -> VexFont {
        loadFont(name: "Bravura", resourceName: "bravura_glyphs", metricsResourceName: "common_metrics")
    }

    /// Load Gonville font.
    @discardableResult
    public static func loadGonville() -> VexFont {
        loadFont(name: "Gonville", resourceName: "gonville_glyphs", metricsResourceName: "common_metrics")
    }

    /// Load Leland font.
    @discardableResult
    public static func loadLeland() -> VexFont {
        loadFont(name: "Leland", resourceName: "leland_glyphs", metricsResourceName: "common_metrics")
    }

    /// Load Petaluma font.
    @discardableResult
    public static func loadPetaluma() -> VexFont {
        loadFont(name: "Petaluma", resourceName: "petaluma_glyphs", metricsResourceName: "common_metrics")
    }

    /// Load Custom (VexFlowCustom) font.
    @discardableResult
    public static func loadCustom() -> VexFont {
        loadFont(name: "Custom", resourceName: "custom_glyphs", metricsResourceName: "common_metrics")
    }

    /// Load all fonts and set up the default music font stack (Bravura + Custom).
    public static func loadAllFonts() {
        let bravura = loadBravura()
        let custom = loadCustom()
        _ = loadGonville()
        _ = loadLeland()
        _ = loadPetaluma()

        // Default stack: Bravura as primary, Custom as fallback
        Glyph.setMusicFont([bravura, custom])
    }

    /// Set up a minimal font configuration (Bravura only).
    public static func loadDefaultFonts() {
        let bravura = loadBravura()
        let custom = loadCustom()
        Glyph.setMusicFont([bravura, custom])
    }

    // MARK: - Internal

    private static func loadFontData(resourceName: String) -> FontData {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources") else {
            fatalError("[VexFoundation] Missing font resource: \(resourceName).json")
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
            fatalError("[VexFoundation] Failed to load font \(resourceName): \(error)")
        }
    }

    private static func loadMetrics(resourceName: String) -> FontMetrics {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: "Resources") else {
            fatalError("[VexFoundation] Missing metrics resource: \(resourceName).json")
        }

        do {
            let data = try Data(contentsOf: url)
            guard let metrics = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                fatalError("[VexFoundation] Invalid metrics format in \(resourceName).json")
            }
            return metrics
        } catch {
            fatalError("[VexFoundation] Failed to load metrics \(resourceName): \(error)")
        }
    }
}
