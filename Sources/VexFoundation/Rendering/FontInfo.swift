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

/// Describes a text font (not a music glyph font).
public struct FontInfo: Sendable {
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
        size: String = "\(VexFont.SIZE)pt",
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
        self.size = "\(size)pt"
        self.weight = weight
        self.style = style
    }
}

/// Data for an individual music font glyph.
public struct FontGlyph: Sendable {
    public var xMin: Double
    public var xMax: Double
    public var yMin: Double?
    public var yMax: Double?
    /// Horizontal advance width.
    public var ha: Double
    public var leftSideBearing: Double?
    public var advanceWidth: Double?
    /// Glyph outline string (SMuFL format). Parsed on demand.
    public var outline: String?
    /// Cached parsed outline as numeric commands.
    public var cachedOutline: [Double]?

    public init(
        xMin: Double, xMax: Double,
        yMin: Double? = nil, yMax: Double? = nil,
        ha: Double,
        leftSideBearing: Double? = nil,
        advanceWidth: Double? = nil,
        outline: String? = nil
    ) {
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
        self.ha = ha
        self.leftSideBearing = leftSideBearing
        self.advanceWidth = advanceWidth
        self.outline = outline
    }
}

/// Complete font dataset with all glyphs.
public struct FontData: Sendable {
    public var glyphs: [String: FontGlyph]
    public var fontFamily: String?
    public var resolution: Double
    public var generatedOn: String?

    public init(
        glyphs: [String: FontGlyph],
        fontFamily: String? = nil,
        resolution: Double,
        generatedOn: String? = nil
    ) {
        self.glyphs = glyphs
        self.fontFamily = fontFamily
        self.resolution = resolution
        self.generatedOn = generatedOn
    }
}

/// Font metrics for positioning and layout, specified per music font.
public typealias FontMetrics = [String: Any]
