// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum TimeSignatureSpecError: Error, LocalizedError, Equatable, Sendable {
    case invalidMeterValues(numerator: Int, denominator: Int)
    case failedToConstructDigits(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMeterValues(let numerator, let denominator):
            return "Meter values must be positive. Got \(numerator)/\(denominator)."
        case .failedToConstructDigits(let raw):
            return "Failed to construct meter digits from \(raw)."
        }
    }
}

/// Symbolic time signatures supported by notation fonts.
public enum TimeSignatureSymbol: String, CaseIterable, Sendable, Codable {
    case common = "C"
    case cutCommon = "C|"

    /// Parse a time signature symbol from user input (case-insensitive).
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.init(rawValue: normalized)
    }
}

/// Validated digits / token sequence for displayed numeric time signatures.
public struct TimeSignatureDigits: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    private static let allowedCharacters = CharacterSet(charactersIn: "0123456789+-() ")

    public init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard normalized.unicodeScalars.allSatisfy({ Self.allowedCharacters.contains($0) }) else { return nil }
        self.rawValue = normalized
    }

    public init?(parsing raw: String) {
        self.init(rawValue: raw)
    }
}

/// Numeric meter used for rhythmic calculations.
public struct TimeSignatureMeter: Equatable, Sendable, Codable {
    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        self.numerator = max(1, numerator)
        self.denominator = max(1, denominator)
    }

    public init(validating numerator: Int, denominator: Int) throws {
        guard numerator > 0, denominator > 0 else {
            throw TimeSignatureSpecError.invalidMeterValues(
                numerator: numerator,
                denominator: denominator
            )
        }
        self.numerator = numerator
        self.denominator = denominator
    }

    public init?(validatingOrNil numerator: Int, denominator: Int) {
        guard let meter = try? TimeSignatureMeter(validating: numerator, denominator: denominator) else {
            return nil
        }
        self = meter
    }

    public var rawValue: String { "\(numerator)/\(denominator)" }
}

/// Strongly typed representation of a notated time signature.
public enum TimeSignatureSpec: Hashable, Sendable, Codable {
    case symbol(TimeSignatureSymbol)
    case numeric(top: TimeSignatureDigits, bottom: TimeSignatureDigits)
    /// Top-only numeric representation used by special renderers (e.g. multi-measure rest numbers).
    case topOnly(TimeSignatureDigits)

    public static let commonTime: TimeSignatureSpec = .symbol(.common)
    public static let cutTime: TimeSignatureSpec = .symbol(.cutCommon)
    public static let `default`: TimeSignatureSpec = (try? .meter(validating: 4, 4)) ?? .symbol(.common)

    /// Construct a standard numeric meter using typed validation.
    public static func meter(validating numerator: Int, _ denominator: Int) throws -> TimeSignatureSpec {
        let meter = try TimeSignatureMeter(validating: numerator, denominator: denominator)
        guard
            let top = TimeSignatureDigits(rawValue: String(meter.numerator)),
            let bottom = TimeSignatureDigits(rawValue: String(meter.denominator))
        else {
            throw TimeSignatureSpecError.failedToConstructDigits(meter.rawValue)
        }
        return .numeric(top: top, bottom: bottom)
    }

    /// Construct a standard numeric meter using typed validation.
    public static func meterOrNil(validating numerator: Int, _ denominator: Int) -> TimeSignatureSpec? {
        try? meter(validating: numerator, denominator)
    }

    /// Construct a standard numeric meter.
    public static func meter(_ numerator: Int, _ denominator: Int) -> TimeSignatureSpec {
        meterOrNil(validating: numerator, denominator) ?? .default
    }

    public var isNumeric: Bool {
        switch self {
        case .symbol:
            return false
        case .numeric, .topOnly:
            return true
        }
    }

    /// Canonical textual representation.
    public var rawValue: String {
        switch self {
        case .symbol(let symbol):
            return symbol.rawValue
        case .numeric(let top, let bottom):
            return "\(top.rawValue)/\(bottom.rawValue)"
        case .topOnly(let top):
            return "/\(top.rawValue)"
        }
    }

    /// Convert to a rhythmic meter if this spec is metrically interpretable.
    public var meter: TimeSignatureMeter? {
        switch self {
        case .symbol(.common):
            return TimeSignatureMeter(validatingOrNil: 4, denominator: 4)
        case .symbol(.cutCommon):
            return TimeSignatureMeter(validatingOrNil: 2, denominator: 2)
        case .numeric(let top, let bottom):
            guard
                let numerator = Self.parseIntegerComponent(top),
                let denominator = Self.parseIntegerComponent(bottom),
                numerator > 0,
                denominator > 0
            else {
                return nil
            }
            return TimeSignatureMeter(validatingOrNil: numerator, denominator: denominator)
        case .topOnly:
            return nil
        }
    }

    /// Parse from a string. If `validate` is false, accepts top-only forms like `/4`.
    public init?(parsing raw: String, validate: Bool = true) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        if let symbol = TimeSignatureSymbol(parsing: normalized) {
            self = .symbol(symbol)
            return
        }

        // Support standalone alternation / interchange symbols used in
        // time-signature compositions (e.g. "6/8 + 3/4", "3/4 - 2/4").
        if normalized == "+" || normalized == "-" {
            guard let token = TimeSignatureDigits(parsing: normalized) else { return nil }
            self = .topOnly(token)
            return
        }

        let parts = normalized.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let topRaw = String(parts[0])
        let bottomRaw = String(parts[1])

        if validate {
            guard
                let top = TimeSignatureDigits(parsing: topRaw),
                let bottom = TimeSignatureDigits(parsing: bottomRaw)
            else {
                return nil
            }
            self = .numeric(top: top, bottom: bottom)
            return
        }

        if
            let top = TimeSignatureDigits(parsing: topRaw),
            let bottom = TimeSignatureDigits(parsing: bottomRaw)
        {
            self = .numeric(top: top, bottom: bottom)
            return
        }

        if
            topRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let bottom = TimeSignatureDigits(parsing: bottomRaw)
        {
            self = .topOnly(bottom)
            return
        }

        if
            bottomRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let top = TimeSignatureDigits(parsing: topRaw)
        {
            self = .topOnly(top)
            return
        }

        return nil
    }

    private static func parseIntegerComponent(_ component: TimeSignatureDigits) -> Int? {
        let trimmed = component.rawValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) else { return nil }
        return Int(trimmed)
    }
}
