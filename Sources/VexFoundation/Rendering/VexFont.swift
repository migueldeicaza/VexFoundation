// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/font.ts` (VexFlow 5). Named `VexFont` to avoid a collision
// with `SwiftUI.Font`. Font *files* are managed by `FontRegistry`.

import Foundation

/// CSS font helpers: size conversion, validation and CSS shorthand.
public enum VexFont {

    // MARK: - Constants

    /// Generic sans-serif family (kept for source compatibility).
    public static let SANS_SERIF = "Arial, sans-serif"
    /// Generic serif family (kept for source compatibility).
    public static let SERIF = "Times New Roman, serif"
    /// Default text size in pt (kept for source compatibility).
    public static let SIZE: Double = 10

    /// Scale factors to convert CSS units to pixels.
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

    // MARK: - Size conversion

    /// Parse the leading number of a CSS length, like JavaScript `parseFloat`.
    static func parseLeadingNumber(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        var end = trimmed.startIndex
        var seenDigit = false
        var seenDot = false
        var idx = trimmed.startIndex
        if idx < trimmed.endIndex, trimmed[idx] == "-" || trimmed[idx] == "+" {
            idx = trimmed.index(after: idx)
        }
        while idx < trimmed.endIndex {
            let c = trimmed[idx]
            if c.isASCII, c.isNumber {
                seenDigit = true
            } else if c == ".", !seenDot {
                seenDot = true
            } else {
                break
            }
            idx = trimmed.index(after: idx)
            end = idx
        }
        guard seenDigit else { return nil }
        return Double(trimmed[trimmed.startIndex..<end])
    }

    static func unit(of fontSize: String) -> String {
        fontSize.filter { !($0.isNumber || $0 == "." || $0.isWhitespace) }.lowercased()
    }

    /// Convert a CSS font size (e.g. "16px", "12pt") to pixels.
    public static func convertSizeToPixelValue(_ fontSize: String) -> Double {
        guard let value = parseLeadingNumber(fontSize) else { return 0 }
        return value * (scaleToPxFrom[unit(of: fontSize)] ?? 1)
    }

    /// Convert a size in points to pixels.
    public static func convertSizeToPixelValue(_ fontSize: Double) -> Double {
        fontSize * scaleToPxFrom["pt"]!
    }

    /// Convert a CSS font size to points.
    public static func convertSizeToPointValue(_ fontSize: String) -> Double {
        guard let value = parseLeadingNumber(fontSize) else { return 0 }
        return value * (scaleToPxFrom[unit(of: fontSize)] ?? 1) / scaleToPxFrom["pt"]!
    }

    public static func convertSizeToPointValue(_ fontSize: Double) -> Double {
        fontSize
    }

    // MARK: - Validation & CSS

    /// Normalize font parameters into a complete `FontInfo`.
    /// Missing values take the defaults from `Metrics` (`fontFamily`, `fontSize`).
    public static func validate(
        family: String? = nil,
        size: String? = nil,
        weight: String? = nil,
        style: String? = nil
    ) -> FontInfo {
        let family = family ?? (Metrics.get("fontFamily") as? String ?? "Bravura,Academico")
        let size = size ?? "\(formatJSNumber(Metrics.getDouble("fontSize", 30)))pt"
        let weight = (weight?.isEmpty ?? true) ? VexFontWeight.normal.rawValue : weight!
        let style = (style?.isEmpty ?? true) ? VexFontStyle.normal.rawValue : style!
        return FontInfo(family: family, size: size, weight: weight, style: style)
    }

    /// Validate with a size given in points.
    public static func validate(
        family: String? = nil,
        size: Double,
        weight: String? = nil,
        style: String? = nil
    ) -> FontInfo {
        validate(family: family, size: "\(formatJSNumber(size))pt", weight: weight, style: style)
    }

    public static func validate(fontInfo: FontInfo) -> FontInfo {
        validate(family: fontInfo.family, size: fontInfo.size, weight: fontInfo.weight, style: fontInfo.style)
    }

    /// Parse CSS font shorthand, e.g. `"italic bold 16pt Arial"`.
    ///
    /// Supports the subset that VexFlow uses: optional style, variant and
    /// weight keywords, a size with an optional `/line-height`, then the family.
    public static func fromCSSString(_ css: String) -> FontInfo {
        var style = VexFontStyle.normal.rawValue
        var weight = VexFontWeight.normal.rawValue
        var size = "\(formatJSNumber(Metrics.getDouble("fontSize", 30)))pt"
        var family = Metrics.get("fontFamily") as? String ?? "Bravura,Academico"

        var tokens = css.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        while let token = tokens.first {
            let lower = token.lowercased()
            if lower == "italic" || lower == "oblique" {
                style = lower
            } else if lower == "bold" || lower == "bolder" || lower == "lighter" || (Int(lower).map { $0 % 100 == 0 } ?? false) {
                weight = lower
            } else if lower == "normal" || lower == "small-caps" {
                // ignore
            } else if parseLeadingNumber(lower) != nil {
                size = String(token.split(separator: "/").first ?? Substring(token))
                tokens.removeFirst()
                break
            } else {
                break
            }
            tokens.removeFirst()
        }
        if !tokens.isEmpty {
            family = tokens.joined(separator: " ")
        }
        return FontInfo(family: family, size: size, weight: weight, style: style)
    }

    /// Generate a CSS font shorthand string: `"italic bold 16pt Arial"`.
    public static func toCSSString(_ fontInfo: FontInfo?) -> String {
        guard let fontInfo else { return "" }

        let st = fontInfo.style
        let style = (st == VexFontStyle.normal.rawValue || st.isEmpty) ? "" : st.trimmingCharacters(in: .whitespaces) + " "

        let wt = fontInfo.weight
        let weight = (wt == VexFontWeight.normal.rawValue || wt.isEmpty) ? "" : wt.trimmingCharacters(in: .whitespaces) + " "

        let size = fontInfo.size.isEmpty
            ? "\(formatJSNumber(Metrics.getDouble("fontSize", 30)))pt "
            : fontInfo.size.trimmingCharacters(in: .whitespaces) + " "

        return "\(style)\(weight)\(size)\(fontInfo.family)"
    }

    /// Scale a CSS font size by a factor. E.g. "16pt" * 2 = "32pt".
    public static func scaleSize(_ fontSize: String, _ scaleFactor: Double) -> String {
        guard let value = parseLeadingNumber(fontSize) else { return fontSize }
        let unit = fontSize.filter { !($0.isNumber || $0 == "." || $0.isWhitespace) }
        return "\(formatJSNumber(value * scaleFactor))\(unit)"
    }

    public static func scaleSize(_ fontSize: Double, _ scaleFactor: Double) -> Double {
        fontSize * scaleFactor
    }

    /// True if the weight means bold (`bold` or a numeric weight >= 600).
    public static func isBold(_ weight: String?) -> Bool {
        guard let weight, !weight.isEmpty else { return false }
        if let numeric = parseLeadingNumber(weight) {
            return numeric >= 600
        }
        return weight.lowercased() == "bold"
    }

    /// True if the style means italic.
    public static func isItalic(_ style: String?) -> Bool {
        guard let style, !style.isEmpty else { return false }
        return style.lowercased() == VexFontStyle.italic.rawValue
    }
}

/// Format a number the way JavaScript's `Number.prototype.toString()` does
/// for the values VexFlow uses (no trailing `.0`, shortest round-trip digits).
public func formatJSNumber(_ value: Double) -> String {
    if value.isNaN { return "NaN" }
    if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
    if value == value.rounded(), abs(value) < 1e21 {
        return String(Int64(value))
    }
    var s = "\(value)"
    // Swift prints e.g. "1e-07"; JavaScript prints "1e-7".
    if let eIdx = s.firstIndex(of: "e") {
        let mantissa = s[s.startIndex..<eIdx]
        var exp = String(s[s.index(after: eIdx)...])
        let sign = exp.hasPrefix("-") ? "-" : "+"
        exp = exp.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        while exp.hasPrefix("0"), exp.count > 1 { exp.removeFirst() }
        s = "\(mantissa)e\(sign)\(exp)"
    }
    return s
}
