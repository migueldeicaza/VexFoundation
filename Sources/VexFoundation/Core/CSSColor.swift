// VexFoundation - CSS color string parser for VexFlow port.

import SwiftUI

/// Parse CSS color strings (used throughout VexFlow) into SwiftUI Color values.
public enum CSSColor {

    /// Parse a CSS color string into a SwiftUI Color.
    /// Supports: "#RGB", "#RRGGBB", "#RRGGBBAA", "rgb(r,g,b)", "rgba(r,g,b,a)", and named colors.
    public static func parse(_ css: String) -> Color {
        let trimmed = css.trimmingCharacters(in: .whitespaces).lowercased()

        if trimmed.hasPrefix("#") {
            return parseHex(trimmed)
        } else if trimmed.hasPrefix("rgba(") {
            return parseRGBA(trimmed)
        } else if trimmed.hasPrefix("rgb(") {
            return parseRGB(trimmed)
        } else {
            return namedColor(trimmed) ?? .black
        }
    }

    // MARK: - Hex

    private static func parseHex(_ hex: String) -> Color {
        let h = String(hex.dropFirst()) // remove "#"
        var r: Double = 0, g: Double = 0, b: Double = 0, a: Double = 1

        switch h.count {
        case 3: // #RGB
            r = hexVal(h, start: 0, length: 1) / 15
            g = hexVal(h, start: 1, length: 1) / 15
            b = hexVal(h, start: 2, length: 1) / 15
        case 4: // #RGBA
            r = hexVal(h, start: 0, length: 1) / 15
            g = hexVal(h, start: 1, length: 1) / 15
            b = hexVal(h, start: 2, length: 1) / 15
            a = hexVal(h, start: 3, length: 1) / 15
        case 6: // #RRGGBB
            r = hexVal(h, start: 0, length: 2) / 255
            g = hexVal(h, start: 2, length: 2) / 255
            b = hexVal(h, start: 4, length: 2) / 255
        case 8: // #RRGGBBAA
            r = hexVal(h, start: 0, length: 2) / 255
            g = hexVal(h, start: 2, length: 2) / 255
            b = hexVal(h, start: 4, length: 2) / 255
            a = hexVal(h, start: 6, length: 2) / 255
        default:
            return .black
        }

        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    private static func hexVal(_ str: String, start: Int, length: Int) -> Double {
        let s = str.index(str.startIndex, offsetBy: start)
        let e = str.index(s, offsetBy: length)
        guard let val = UInt64(str[s..<e], radix: 16) else { return 0 }
        return Double(val)
    }

    // MARK: - RGB / RGBA

    private static func parseRGB(_ str: String) -> Color {
        let nums = extractNumbers(str)
        guard nums.count >= 3 else { return .black }
        return Color(
            .sRGB,
            red: nums[0] / 255,
            green: nums[1] / 255,
            blue: nums[2] / 255,
            opacity: 1
        )
    }

    private static func parseRGBA(_ str: String) -> Color {
        let nums = extractNumbers(str)
        guard nums.count >= 4 else { return parseRGB(str) }
        return Color(
            .sRGB,
            red: nums[0] / 255,
            green: nums[1] / 255,
            blue: nums[2] / 255,
            opacity: nums[3]  // alpha is 0..1 in CSS rgba()
        )
    }

    private static func extractNumbers(_ str: String) -> [Double] {
        let inner = str.replacingOccurrences(of: "[^\\d.,]", with: "", options: .regularExpression)
        return inner.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - Named Colors

    private static func namedColor(_ name: String) -> Color? {
        switch name {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "gray", "grey": return .gray
        case "brown": return .brown
        case "cyan": return .cyan
        case "pink": return .pink
        case "transparent": return .clear
        case "none": return .clear
        default: return nil
        }
    }
}
