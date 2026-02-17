// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Central constants and lookup tables for VexFlow music notation.
public enum Tables {

    // MARK: - Rendering Constants

    /// Stem width in pixels.
    public static let STEM_WIDTH: Double = 1.5
    /// Default stem height in pixels.
    public static let STEM_HEIGHT: Double = 35
    /// Stave line thickness in pixels.
    public static let STAVE_LINE_THICKNESS: Double = 1
    /// Decimal places for rounding during rendering.
    public static let RENDER_PRECISION_PLACES: Int = 3
    /// Ticks per whole note.
    public static let RESOLUTION: Int = 16384
    /// Default font scale for standard notation.
    public static let NOTATION_FONT_SCALE: Double = 39
    /// Default font scale for tablature.
    public static let TABLATURE_FONT_SCALE: Double = 39
    /// Width of slash noteheads.
    public static let SLASH_NOTEHEAD_WIDTH: Double = 15
    /// Distance between stave lines.
    public static let STAVE_LINE_DISTANCE: Double = 10

    // MARK: - Duration Tables

    /// Maps duration strings to tick counts.
    public static let durations: [String: Int] = [
        "1/2": RESOLUTION * 2,
        "1": RESOLUTION / 1,
        "2": RESOLUTION / 2,
        "4": RESOLUTION / 4,
        "8": RESOLUTION / 8,
        "16": RESOLUTION / 16,
        "32": RESOLUTION / 32,
        "64": RESOLUTION / 64,
        "128": RESOLUTION / 128,
        "256": RESOLUTION / 256,
    ]

    /// Duration aliases: shorthand names for durations.
    public static let durationAliases: [String: String] = [
        "w": "1",
        "h": "2",
        "q": "4",
        "b": "256",
    ]

    /// Convert a duration string to ticks.
    public static func durationToTicks(_ duration: String) -> Int? {
        let resolved = durationAliases[duration] ?? duration
        return durations[resolved]
    }
}
