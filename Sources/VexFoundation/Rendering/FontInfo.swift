// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Font weight constants, inspired by CSS font-weight.
public enum VexFontWeight: String, Sendable {
    case normal = "normal"
    case bold = "bold"
}

/// Font style constants, inspired by CSS font-style.
public enum VexFontStyle: String, Sendable {
    case normal = "normal"
    case italic = "italic"
}

/// Describes a font: CSS family list, size, weight and style.
/// In VexFlow 5 the same type describes music fonts and text fonts.
public struct FontInfo: Sendable, Equatable, Hashable {
    /// CSS font-family, e.g., "Arial", "Times New Roman".
    public var family: String
    /// Font size as a string with units (e.g., "10pt", "12px") or as a point value.
    public var size: String
    /// Font weight (e.g., "bold", "normal", "900").
    public var weight: String
    /// Font style (e.g., "italic", "normal").
    public var style: String

    public init(
        family: String = VexFont.SANS_SERIF,
        size: String = "10pt",
        weight: String = VexFontWeight.normal.rawValue,
        style: String = VexFontStyle.normal.rawValue
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.style = style
    }

    public init(
        family: String = VexFont.SANS_SERIF,
        size: Double,
        weight: String = VexFontWeight.normal.rawValue,
        style: String = VexFontStyle.normal.rawValue
    ) {
        self.family = family
        self.size = "\(formatJSNumber(size))pt"
        self.weight = weight
        self.style = style
    }
}
