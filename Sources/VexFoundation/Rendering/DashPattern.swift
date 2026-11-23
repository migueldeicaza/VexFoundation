// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/dashpattern.ts` (VexFlow 5.8.0).
// Validate manual dash patterns and plan bounded paths for every rendering backend.

import Foundation

/// Limit the number of path commands for one line, including zero-length gaps.
let MAX_DASH_SEGMENTS = 16_384

/// A zero-length dash or gap is valid if the repeating pattern advances overall.
/// Throws `VexError("BadDashPattern")`.
public func validateDashPattern(_ pattern: [Double]) throws {
    var advances = false
    for length in pattern {
        if !length.isFinite || length < 0 {
            throw VexError("BadDashPattern", "Dash lengths must be finite and nonnegative.")
        }
        if length > 0 { advances = true }
    }
    if !advances { throw VexError("BadDashPattern", "A dash pattern must contain a positive length.") }
}

/// Plan distances before modifying the context so an over-budget line leaves no partial path.
/// Throws `VexError("BadDashPattern")`.
public func dashStops(_ lineLength: Double, _ pattern: [Double]) throws -> [Double] {
    try validateDashPattern(pattern)
    var stops: [Double] = []
    var distance: Double = 0
    while distance < lineLength {
        if stops.count == MAX_DASH_SEGMENTS {
            throw VexError("BadDashPattern", "A dashed line may use at most \(MAX_DASH_SEGMENTS) segments.")
        }
        distance = min(lineLength, distance + pattern[stops.count % pattern.count])
        stops.append(distance)
    }
    return stops
}
