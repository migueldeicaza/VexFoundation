// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Joshua Koo / @zz85
// @author @incompleteopus
//
// Port of `src/fraction.ts` (VexFlow 5.1.0).
//
// Swift note: numerator and denominator are `Int` (upstream uses JS numbers).

import Foundation

/// Fraction represents a rational number used for tick-based timing in music notation.
public final class Fraction: @unchecked Sendable {
    public static var category: String { "Fraction" }

    public var numerator: Int
    public var denominator: Int

    // MARK: - Static Helpers

    /// Greatest common divisor using the Euclidean algorithm.
    public static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 {
            let t = b
            b = a % b
            a = t
        }
        return a
    }

    /// Lowest common multiple.
    public static func lcm(_ a: Int, _ b: Int) -> Int {
        guard b != 0 else { return 0 }
        return (a * b) / gcd(a, b)
    }

    /// Lowest common multiple for more than two numbers.
    public static func lcmm(_ args: [Int]) -> Int {
        if args.isEmpty { return 0 }
        if args.count == 1 { return args[0] }
        if args.count == 2 { return lcm(args[0], args[1]) }
        // LCM the first number with the rest of the numbers.
        return lcm(args[0], lcmm(Array(args.dropFirst())))
    }

    /// Upstream name of `gcd(_:_:)`.
    public static func GCD(_ a: Int, _ b: Int) -> Int { gcd(a, b) }
    /// Upstream name of `lcm(_:_:)`.
    public static func LCM(_ a: Int, _ b: Int) -> Int { lcm(a, b) }
    /// Upstream name of `lcmm(_:)`.
    public static func LCMM(_ args: [Int]) -> Int { lcmm(args) }

    // MARK: - Init

    public init(_ numerator: Int = 1, _ denominator: Int = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }

    // MARK: - Mutating Operations

    @discardableResult
    public func set(_ numerator: Int = 1, _ denominator: Int = 1) -> Fraction {
        self.numerator = numerator
        self.denominator = denominator
        return self
    }

    /// Set the numerator and denominator. Throws for a zero denominator (VexFlow 5.1.0
    /// rejects invalid fractions; `Int` values are always finite).
    @discardableResult
    public func setThrowing(_ numerator: Int = 1, _ denominator: Int = 1) throws -> Fraction {
        guard denominator != 0 else {
            throw VexError("BadArgument", "Invalid fraction: \(numerator)/\(denominator)")
        }
        return set(numerator, denominator)
    }

    /// Return the floating-point value.
    public func value() -> Double {
        Double(numerator) / Double(denominator)
    }

    /// Simplify numerator and denominator using GCD.
    @discardableResult
    public func simplify() -> Fraction {
        let g = Fraction.gcd(numerator, denominator)
        guard g != 0 else { return self }
        var u = numerator / g
        var d = denominator / g
        if d < 0 {
            d = -d
            u = -u
        }
        return set(u, d)
    }

    /// Add value of another fraction.
    @discardableResult
    public func add(_ other: Fraction) -> Fraction {
        let l = Fraction.lcm(denominator, other.denominator)
        guard l != 0 else { return self }
        let a = l / denominator
        let b = l / other.denominator
        let u = numerator * a + other.numerator * b
        return set(u, l)
    }

    @discardableResult
    public func add(_ n: Int, _ d: Int = 1) -> Fraction {
        add(Fraction(n, d))
    }

    /// Subtract value of another fraction.
    @discardableResult
    public func subtract(_ other: Fraction) -> Fraction {
        let l = Fraction.lcm(denominator, other.denominator)
        guard l != 0 else { return self }
        let a = l / denominator
        let b = l / other.denominator
        let u = numerator * a - other.numerator * b
        return set(u, l)
    }

    @discardableResult
    public func subtract(_ n: Int, _ d: Int = 1) -> Fraction {
        subtract(Fraction(n, d))
    }

    /// Multiply by value of another fraction.
    @discardableResult
    public func multiply(_ other: Fraction) -> Fraction {
        set(numerator * other.numerator, denominator * other.denominator)
    }

    @discardableResult
    public func multiply(_ n: Int, _ d: Int = 1) -> Fraction {
        multiply(Fraction(n, d))
    }

    /// Divide by value of another fraction.
    @discardableResult
    public func divide(_ other: Fraction) -> Fraction {
        set(numerator * other.denominator, denominator * other.numerator)
    }

    @discardableResult
    public func divide(_ n: Int, _ d: Int = 1) -> Fraction {
        divide(Fraction(n, d))
    }

    /// Copy value of another fraction.
    @discardableResult
    public func copy(_ other: Fraction) -> Fraction {
        set(other.numerator, other.denominator)
    }

    @discardableResult
    public func copy(_ n: Int) -> Fraction {
        set(n)
    }

    /// Calculate absolute value.
    @discardableResult
    public func makeAbs() -> Fraction {
        numerator = abs(numerator)
        denominator = abs(denominator)
        return self
    }

    // MARK: - Queries

    /// Return a new copy with current values.
    public func clone() -> Fraction {
        Fraction(numerator, denominator)
    }

    /// Return the integer component (e.g. 5/2 => 2). Rounds down, as upstream `Math.floor`.
    public func quotient() -> Int {
        Int((Double(numerator) / Double(denominator)).rounded(.down))
    }

    /// Return the remainder component (e.g., 5/2 => 1).
    public func remainder() -> Int {
        numerator % denominator
    }

    /// Parse a fraction string (e.g., "5/2").
    @discardableResult
    public func parse(_ str: String) -> Fraction {
        let parts = str.split(separator: "/")
        let n = Int(parts[0]) ?? 1
        let d = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
        return set(n, d)
    }
}

// MARK: - Comparison (upstream names)

extension Fraction {
    /// Simplify both sides and check if they are equal.
    public func equals(_ compare: Fraction) -> Bool {
        let a = compare.clone().simplify()
        let b = clone().simplify()
        return a.numerator == b.numerator && a.denominator == b.denominator
    }

    public func equals(_ compare: Int) -> Bool { equals(Fraction(compare, 1)) }

    /// Greater than operator.
    public func greaterThan(_ compare: Fraction) -> Bool {
        clone().subtract(compare).numerator > 0
    }

    public func greaterThan(_ compare: Int) -> Bool { greaterThan(Fraction(compare, 1)) }

    /// Greater than or equals operator.
    public func greaterThanEquals(_ compare: Fraction) -> Bool {
        clone().subtract(compare).numerator >= 0
    }

    public func greaterThanEquals(_ compare: Int) -> Bool { greaterThanEquals(Fraction(compare, 1)) }

    /// Less than operator.
    public func lessThan(_ compare: Fraction) -> Bool { !greaterThanEquals(compare) }
    public func lessThan(_ compare: Int) -> Bool { !greaterThanEquals(compare) }

    /// Less than or equals operator.
    public func lessThanEquals(_ compare: Fraction) -> Bool { !greaterThan(compare) }
    public func lessThanEquals(_ compare: Int) -> Bool { !greaterThan(compare) }

    /// Return a raw string representation (e.g. "5/2").
    public func toString() -> String { "\(numerator)/\(denominator)" }
}

// MARK: - Comparable / Equatable

extension Fraction: Equatable {
    public static func == (lhs: Fraction, rhs: Fraction) -> Bool {
        let a = lhs.clone().simplify()
        let b = rhs.clone().simplify()
        return a.numerator == b.numerator && a.denominator == b.denominator
    }
}

extension Fraction: Comparable {
    public static func < (lhs: Fraction, rhs: Fraction) -> Bool {
        let diff = lhs.clone().subtract(rhs)
        return diff.numerator < 0
    }
}

// MARK: - CustomStringConvertible

extension Fraction: CustomStringConvertible {
    public var description: String {
        "\(numerator)/\(denominator)"
    }

    public func toSimplifiedString() -> String {
        clone().simplify().description
    }

    public func toMixedString() -> String {
        var s = ""
        let q = quotient()
        let f = clone()

        if q < 0 {
            f.makeAbs()
        }

        if q != 0 {
            s += "\(q)"
            if f.numerator != 0 {
                s += " \(f.toSimplifiedString())"
            }
        } else if f.numerator == 0 {
            s = "0"
        } else {
            s = f.toSimplifiedString()
        }

        return s
    }
}
