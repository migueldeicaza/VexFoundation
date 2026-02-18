// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Bounding box for interactive notation elements.
public struct BoundingBox {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    /// Move by offset.
    public mutating func move(x dx: Double, y dy: Double) {
        x += dx
        y += dy
    }

    /// Merge with another bounding box, producing the union.
    public mutating func mergeWith(_ other: BoundingBox) {
        let newX = min(x, other.x)
        let newY = min(y, other.y)
        let newW = max(x + w, other.x + other.w) - newX
        let newH = max(y + h, other.y + other.h) - newY
        x = newX
        y = newY
        w = newW
        h = newH
    }

    /// Return a merged copy without mutating self.
    public func merged(with other: BoundingBox) -> BoundingBox {
        var copy = self
        copy.mergeWith(other)
        return copy
    }
}
