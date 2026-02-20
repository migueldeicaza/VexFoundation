// VexFoundation - Lightweight compatibility facade for selected VexFlow `Vex` helpers.

import Dispatch
import Foundation

public enum Vex {
    /// Back-compat alias for older `Vex.Flow`-style call sites.
    public static var Flow: VexFoundation.Flow.Type { VexFoundation.Flow.self }

    /// Back-compat runtime error aliases.
    public typealias RuntimeError = VexError
    public typealias RERR = VexError

    /// Return a sorted array with duplicates removed according to the provided comparators.
    public static func sortAndUnique<T>(
        _ array: [T],
        sortedBy areInIncreasingOrder: (T, T) -> Bool,
        equalBy areEqual: (T, T) -> Bool
    ) -> [T] {
        guard array.count > 1 else { return array }

        let sorted = array.sorted(by: areInIncreasingOrder)
        var result: [T] = []
        result.reserveCapacity(sorted.count)

        for value in sorted {
            if let last = result.last, areEqual(value, last) {
                continue
            }
            result.append(value)
        }

        return result
    }

    public static func contains<T: Equatable>(_ array: [T], _ item: T) -> Bool {
        array.contains(item)
    }

    public static func stackTrace() -> String {
        Thread.callStackSymbols.joined(separator: "\n")
    }

    /// Run `operation` and return both result and elapsed milliseconds.
    @discardableResult
    public static func benchmark<T>(_ operation: () throws -> T) rethrows -> (result: T, elapsedMs: Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        let result = try operation()
        let end = DispatchTime.now().uptimeNanoseconds
        let elapsedMs = Double(end - start) / 1_000_000.0
        return (result: result, elapsedMs: elapsedMs)
    }
}
