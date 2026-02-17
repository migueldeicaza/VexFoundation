// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.
// Based on: https://github.com/canvg/canvg/blob/master/src/BoundingBox.ts (MIT License)

import Foundation

/// Computes metrics for a bounding box by continuously taking path commands.
public struct BoundingBoxComputation {
    private var x1: Double = .nan
    private var y1: Double = .nan
    private var x2: Double = .nan
    private var y2: Double = .nan

    public init() {}

    public func getX1() -> Double { x1 }
    public func getY1() -> Double { y1 }
    public func width() -> Double { x2 - x1 }
    public func height() -> Double { y2 - y1 }

    /// Add a point to the bounding box.
    public mutating func addPoint(_ x: Double, _ y: Double) {
        if x1.isNaN || x < x1 { x1 = x }
        if x2.isNaN || x > x2 { x2 = x }
        if y1.isNaN || y < y1 { y1 = y }
        if y2.isNaN || y > y2 { y2 = y }
    }

    public mutating func addX(_ x: Double) {
        addPoint(x, y1)
    }

    public mutating func addY(_ y: Double) {
        addPoint(x1, y)
    }

    /// Add a quadratic Bezier curve to the bounding box.
    public mutating func addQuadraticCurve(
        _ p0x: Double, _ p0y: Double,
        _ p1x: Double, _ p1y: Double,
        _ p2x: Double, _ p2y: Double
    ) {
        addPoint(p0x, p0y)
        addPoint(p2x, p2y)

        // Find extrema for X
        let p01x = p1x - p0x
        let p12x = p2x - p1x
        var denom = p01x - p12x
        if denom != 0 {
            let t = p01x / denom
            if t > 0 && t < 1 {
                let it = 1 - t
                addX(it * it * p0x + 2 * it * t * p1x + t * t * p2x)
            }
        }

        // Find extrema for Y
        let p01y = p1y - p0y
        let p12y = p2y - p1y
        denom = p01y - p12y
        if denom != 0 {
            let t = p01y / denom
            if t > 0 && t < 1 {
                let it = 1 - t
                addY(it * it * p0y + 2 * it * t * p1y + t * t * p2y)
            }
        }
    }

    /// Add a cubic Bezier curve to the bounding box.
    public mutating func addBezierCurve(
        _ p0x: Double, _ p0y: Double,
        _ p1x: Double, _ p1y: Double,
        _ p2x: Double, _ p2y: Double,
        _ p3x: Double, _ p3y: Double
    ) {
        let p0 = [p0x, p0y]
        let p1 = [p1x, p1y]
        let p2 = [p2x, p2y]
        let p3 = [p3x, p3y]

        addPoint(p0[0], p0[1])
        addPoint(p3[0], p3[1])

        let f = { (t: Double, i: Int) -> Double in
            let mt = 1 - t
            return mt * mt * mt * p0[i]
                + 3 * mt * mt * t * p1[i]
                + 3 * mt * t * t * p2[i]
                + t * t * t * p3[i]
        }

        for i in 0...1 {
            let b = 6 * p0[i] - 12 * p1[i] + 6 * p2[i]
            let a = -3 * p0[i] + 9 * p1[i] - 9 * p2[i] + 3 * p3[i]
            let c = 3 * p1[i] - 3 * p0[i]

            if a == 0 {
                if b == 0 { continue }
                let t = -c / b
                if t > 0 && t < 1 {
                    if i == 0 { addX(f(t, i)) }
                    if i == 1 { addY(f(t, i)) }
                }
                continue
            }

            let b2ac = b * b - 4 * c * a
            if b2ac < 0 { continue }
            let sqrtB2ac = sqrt(b2ac)

            let t1 = (-b + sqrtB2ac) / (2 * a)
            if t1 > 0 && t1 < 1 {
                if i == 0 { addX(f(t1, i)) }
                if i == 1 { addY(f(t1, i)) }
            }

            let t2 = (-b - sqrtB2ac) / (2 * a)
            if t2 > 0 && t2 < 1 {
                if i == 0 { addX(f(t2, i)) }
                if i == 1 { addY(f(t2, i)) }
            }
        }
    }
}
