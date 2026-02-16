// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Text measurement result, matching the semantics of SVG getBBox().
/// - `x`: typically 0
/// - `y`: negative (distance from baseline to top of ascender)
/// - `width`: actual text width in points
/// - `height`: total height (ascent + descent)
public struct TextMeasure: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}
