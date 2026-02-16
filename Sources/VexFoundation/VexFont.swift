// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Font management for VexFlow. Handles text font properties, size conversions,
/// and music font data loading. Named `VexFont` to avoid collision with SwiftUI.Font.
public final class VexFont: @unchecked Sendable {

    // MARK: - Static Constants

    /// Default sans-serif font family.
    public static let SANS_SERIF = "Arial, sans-serif"
    /// Default serif font family.
    public static let SERIF = "Times New Roman, serif"
    /// Default font size in pt.
    public static let SIZE: Double = 10

    /// Scale factors to convert various CSS units to pixels.
    /// 36pt == 48px == 3em == 300% == 0.5in
    public static let scaleToPxFrom: [String: Double] = [
        "pt": 4.0 / 3.0,
        "px": 1,
        "em": 16,
        "%": 4.0 / 25.0,
        "in": 96,
        "mm": 96.0 / 25.4,
        "cm": 96.0 / 2.54,
    ]

    // MARK: - Size Conversion

    /// Convert a font size (number in pt, or string like "16px") to pixels.
    public static func convertSizeToPixelValue(_ fontSize: String) -> Double {
        guard let value = Double(fontSize.filter { $0.isNumber || $0 == "." }) else { return 0 }
        let unit = fontSize.replacingOccurrences(
            of: "[\\d.\\s]", with: "", options: .regularExpression
        ).lowercased()
        let factor = scaleToPxFrom[unit] ?? 1
        return value * factor
    }

    public static func convertSizeToPixelValue(_ fontSize: Double) -> Double {
        fontSize * (scaleToPxFrom["pt"] ?? 1)
    }

    /// Convert a font size to points.
    public static func convertSizeToPointValue(_ fontSize: String) -> Double {
        guard let value = Double(fontSize.filter { $0.isNumber || $0 == "." }) else { return 0 }
        let unit = fontSize.replacingOccurrences(
            of: "[\\d.\\s]", with: "", options: .regularExpression
        ).lowercased()
        let pxFactor = scaleToPxFrom[unit] ?? 1
        let ptFactor = scaleToPxFrom["pt"] ?? 1
        return value * pxFactor / ptFactor
    }

    public static func convertSizeToPointValue(_ fontSize: Double) -> Double {
        fontSize
    }

    // MARK: - Validation & CSS

    /// Normalize font parameters into a complete FontInfo.
    public static func validate(
        family: String? = nil,
        size: String? = nil,
        weight: String? = nil,
        style: String? = nil
    ) -> FontInfo {
        FontInfo(
            family: family ?? SANS_SERIF,
            size: size ?? "\(SIZE)pt",
            weight: (weight?.isEmpty ?? true) ? VexFontWeight.normal.rawValue : weight!,
            style: (style?.isEmpty ?? true) ? VexFontStyle.normal.rawValue : style!
        )
    }

    public static func validate(
        family: String? = nil,
        size: Double,
        weight: String? = nil,
        style: String? = nil
    ) -> FontInfo {
        validate(family: family, size: "\(size)pt", weight: weight, style: style)
    }

    public static func validate(fontInfo: FontInfo) -> FontInfo {
        validate(family: fontInfo.family, size: fontInfo.size, weight: fontInfo.weight, style: fontInfo.style)
    }

    /// Generate a CSS font shorthand string: "italic bold 16pt Arial".
    public static func toCSSString(_ fontInfo: FontInfo?) -> String {
        guard let fontInfo else { return "" }

        let style: String
        if fontInfo.style == VexFontStyle.normal.rawValue || fontInfo.style.isEmpty {
            style = ""
        } else {
            style = fontInfo.style.trimmingCharacters(in: .whitespaces) + " "
        }

        let weight: String
        if fontInfo.weight == VexFontWeight.normal.rawValue || fontInfo.weight.isEmpty {
            weight = ""
        } else {
            weight = fontInfo.weight.trimmingCharacters(in: .whitespaces) + " "
        }

        let size: String
        if fontInfo.size.isEmpty {
            size = "\(SIZE)pt "
        } else {
            size = fontInfo.size.trimmingCharacters(in: .whitespaces) + " "
        }

        return "\(style)\(weight)\(size)\(fontInfo.family)"
    }

    /// Scale a font size by a factor. E.g., "16pt" * 2 = "32pt".
    public static func scaleSize(_ fontSize: String, _ scaleFactor: Double) -> String {
        guard let value = Double(fontSize.filter { $0.isNumber || $0 == "." }) else { return fontSize }
        let unit = fontSize.replacingOccurrences(of: "[\\d.\\s]", with: "", options: .regularExpression)
        return "\(value * scaleFactor)\(unit)"
    }

    public static func scaleSize(_ fontSize: Double, _ scaleFactor: Double) -> Double {
        fontSize * scaleFactor
    }

    /// Check if a font weight indicates bold.
    public static func isBold(_ weight: String?) -> Bool {
        guard let weight, !weight.isEmpty else { return false }
        if let numeric = Int(weight) {
            return numeric >= 600
        }
        return weight.lowercased() == "bold"
    }

    /// Check if a font style indicates italic.
    public static func isItalic(_ style: String?) -> Bool {
        guard let style, !style.isEmpty else { return false }
        return style.lowercased() == VexFontStyle.italic.rawValue
    }

    // MARK: - Font Registry

    nonisolated(unsafe) private static var fonts: [String: VexFont] = [:]

    /// Load or retrieve a font by name. Optionally set its data and metrics.
    public static func load(name: String, data: FontData? = nil, metrics: FontMetrics? = nil) -> VexFont {
        let font = fonts[name] ?? VexFont(name: name)
        fonts[name] = font
        if let data { font.data = data }
        if let metrics { font.metrics = metrics }
        return font
    }

    // MARK: - Instance Members

    public let name: String
    public var data: FontData?
    public var metrics: FontMetrics?

    private init(name: String) {
        self.name = name
    }

    public func getData() throws -> FontData {
        try defined(data, "FontError", "Missing font data for \(name)")
    }

    public func getMetrics() throws -> FontMetrics {
        try defined(metrics, "FontError", "Missing font metrics for \(name)")
    }

    public func getResolution() throws -> Double {
        try getData().resolution
    }

    public func getGlyphs() throws -> [String: FontGlyph] {
        try getData().glyphs
    }

    /// Look up a metric value using a dot-separated key path (e.g., "stave.endPaddingMax").
    public func lookupMetric(_ key: String, defaultValue: Any? = nil) -> Any? {
        guard let metrics else { return defaultValue }
        let parts = key.split(separator: ".")
        var current: Any = metrics
        for part in parts {
            if let dict = current as? [String: Any], let next = dict[String(part)] {
                current = next
            } else {
                return defaultValue
            }
        }
        return current
    }
}
