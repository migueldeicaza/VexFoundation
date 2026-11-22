// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/boundingbox.ts` (VexFlow 5.0.0).
//
// Swift note: `BoundingBox` is a value type. Upstream mutating methods
// (`setX`, `move`, `mergeWith`, ...) are `mutating` and also return the
// result, so `bb.mergeWith(other)` works as upstream on a `var`.

import Foundation

/// Rectangle bounds.
public protocol Bounds {
    var x: Double { get }
    var y: Double { get }
    var w: Double { get }
    var h: Double { get }
}

/// Bounding box for interactive notation elements.
public struct BoundingBox: Bounds, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    /// Create a new copy.
    public static func copy(_ that: BoundingBox) -> BoundingBox {
        BoundingBox(x: that.x, y: that.y, w: that.w, h: that.h)
    }

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    /// Positional initializer, as upstream `new BoundingBox(x, y, w, h)`.
    public init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.init(x: x, y: y, w: w, h: h)
    }

    /// Get x position.
    public func getX() -> Double { x }
    /// Get y position.
    public func getY() -> Double { y }
    /// Get width.
    public func getW() -> Double { w }
    /// Get height.
    public func getH() -> Double { h }

    /// Set x position.
    @discardableResult
    public mutating func setX(_ x: Double) -> BoundingBox {
        self.x = x
        return self
    }

    /// Set y position.
    @discardableResult
    public mutating func setY(_ y: Double) -> BoundingBox {
        self.y = y
        return self
    }

    /// Set width.
    @discardableResult
    public mutating func setW(_ w: Double) -> BoundingBox {
        self.w = w
        return self
    }

    /// Set height.
    @discardableResult
    public mutating func setH(_ h: Double) -> BoundingBox {
        self.h = h
        return self
    }

    /// Move to position.
    @discardableResult
    public mutating func move(_ x: Double, _ y: Double) -> BoundingBox {
        self.x += x
        self.y += y
        return self
    }

    /// Move by offset (labeled form).
    @discardableResult
    public mutating func move(x dx: Double, y dy: Double) -> BoundingBox {
        move(dx, dy)
    }

    /// Clone.
    public func clone() -> BoundingBox {
        BoundingBox.copy(self)
    }

    /// Merge my box with given box. Creates a bigger bounding box unless
    /// the given box is contained in this one.
    @discardableResult
    public mutating func mergeWith(_ boundingBox: BoundingBox) -> BoundingBox {
        let that = boundingBox
        let newX = x < that.x ? x : that.x
        let newY = y < that.y ? y : that.y
        let newW = Swift.max(x + w, that.x + that.w) - newX
        let newH = Swift.max(y + h, that.y + that.h) - newY
        x = newX
        y = newY
        w = newW
        h = newH
        return self
    }

    /// Return a merged copy without mutating self.
    public func merged(with other: BoundingBox) -> BoundingBox {
        var copy = self
        copy.mergeWith(other)
        return copy
    }
}
