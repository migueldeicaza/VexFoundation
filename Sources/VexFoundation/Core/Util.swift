// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/util.ts` (VexFlow 5.0.0).
// `RuntimeError` is `VexError`. `prefix` is `vexPrefix`, `log` is `vexLog`
// and `warn` is `vexWarn` (to avoid clashes with Swift/Foundation names).
// `globalObject()` has no Swift equivalent.

import Foundation

/// RuntimeError thrown by VexFlow classes in case of error.
public struct VexError: Error, CustomStringConvertible {
    public let code: String
    public let message: String

    public init(_ code: String, _ message: String = "") {
        self.code = code
        self.message = message
    }

    public var description: String {
        "[VexError] \(code): \(message)"
    }
}

/// Check that a value is non-nil. If nil, throw a VexError.
public func defined<T>(_ x: T?, _ code: String = "undefined", _ message: String = "") throws -> T {
    guard let x else {
        throw VexError(code, message)
    }
    return x
}

/// Round number to nearest fractional value (.5, .25, etc.)
func roundN(_ x: Double, _ n: Double) -> Double {
    return x.truncatingRemainder(dividingBy: n) >= n / 2
        ? Double(Int(x / n)) * n + n
        : Double(Int(x / n)) * n
}

/// Locate the mid point between stave lines. Returns a fractional line if a space.
public func midLine(_ a: Double, _ b: Double) -> Double {
    var midLine = b + (a - b) / 2
    if midLine.truncatingRemainder(dividingBy: 2) > 0 {
        midLine = roundN(midLine * 10, 5) / 10
    }
    return midLine
}

/// Provide a unique prefix to element names.
public func vexPrefix(_ text: String) -> String {
    "vf-\(text)"
}

/// Return `s` with the first letter capitalized.
public func upperFirst(_ s: String = "") -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

/// Default log function: print the block name and the arguments.
public func vexLog(_ block: String, _ args: Any...) {
    let line = args.map { "\($0)" }.joined(separator: " ")
    print(block + ": " + line)
}

/// Print a warning.
public func vexWarn(_ args: Any...) {
    let line = args.map { "\($0)" }.joined(separator: " ")
    print("Warning: ", line)
}

/// Convert an arbitrary angle in radians to the equivalent one in the range [0, 2*pi).
public func normalizeAngle(_ a: Double) -> Double {
    var a = a.truncatingRemainder(dividingBy: 2 * .pi)
    if a < 0 {
        a += 2 * .pi
    }
    return a
}

/// Return the sum of an array of numbers.
public func sumArray(_ arr: [Double]) -> Double {
    arr.reduce(0, +)
}
