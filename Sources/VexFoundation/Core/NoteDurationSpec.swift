// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Canonical note values used for rhythmic duration.
public enum NoteValue: String, CaseIterable, Sendable, Codable {
    case doubleWhole = "1/2"
    case whole = "1"
    case half = "2"
    case quarter = "4"
    case eighth = "8"
    case sixteenth = "16"
    case thirtySecond = "32"
    case sixtyFourth = "64"
    case oneTwentyEighth = "128"
    case twoFiftySixth = "256"

    private static let aliases: [String: NoteValue] = [
        "w": .whole,
        "h": .half,
        "q": .quarter,
        "b": .twoFiftySixth,
    ]

    /// Parse from canonical numeric/fraction value or alias (`w`, `h`, `q`, `b`).
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let alias = Self.aliases[normalized] {
            self = alias
            return
        }
        self.init(rawValue: normalized)
    }
}

/// Semantic note kind used for glyph/type overrides.
public enum NoteType: String, CaseIterable, Sendable, Codable {
    case note = "n"
    case rest = "r"
    case harmonic = "h"
    case muted = "m"
    case slash = "s"
    case ghost = "g"
    case diamond = "d"
    case x = "x"
    case circled = "ci"
    case circleX = "cx"
    case slashed = "sf"
    case slashedBackward = "sb"
    case square = "sq"
    case triangleUp = "tu"
    case triangleDown = "td"

    /// Parse from a case-insensitive raw string (e.g. `"R"` -> `.rest`).
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.init(rawValue: normalized)
    }
}

/// Errors emitted when parsing string-based note duration specs.
public enum NoteDurationParseError: Error, LocalizedError, Sendable {
    case emptyInput
    case invalidFormat(String)
    case invalidValue(String)
    case invalidType(String)
    case negativeDots(Int)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Duration input cannot be empty."
        case .invalidFormat(let raw):
            return "Invalid duration format: '\(raw)'."
        case .invalidValue(let raw):
            return "Invalid duration value: '\(raw)'."
        case .invalidType(let raw):
            return "Invalid note type: '\(raw)'."
        case .negativeDots(let dots):
            return "Dots must be non-negative. Got \(dots)."
        }
    }
}

/// Parsed duration token with optional dots and note type suffix.
public struct NoteDurationSpec: Equatable, Hashable, Sendable, Codable {
    public let value: NoteValue
    public let dots: Int
    public let type: NoteType

    public static let doubleWhole = NoteDurationSpec(uncheckedValue: .doubleWhole)
    public static let whole = NoteDurationSpec(uncheckedValue: .whole)
    public static let half = NoteDurationSpec(uncheckedValue: .half)
    public static let quarter = NoteDurationSpec(uncheckedValue: .quarter)
    public static let eighth = NoteDurationSpec(uncheckedValue: .eighth)
    public static let sixteenth = NoteDurationSpec(uncheckedValue: .sixteenth)
    public static let thirtySecond = NoteDurationSpec(uncheckedValue: .thirtySecond)
    public static let sixtyFourth = NoteDurationSpec(uncheckedValue: .sixtyFourth)
    public static let oneTwentyEighth = NoteDurationSpec(uncheckedValue: .oneTwentyEighth)
    public static let twoFiftySixth = NoteDurationSpec(uncheckedValue: .twoFiftySixth)

    /// Construct from trusted typed inputs without throwing.
    /// Use throwing initializers/parsers at API boundaries.
    public init(uncheckedValue value: NoteValue, dots: Int = 0, type: NoteType = .note) {
        precondition(dots >= 0, "Dots must be non-negative.")
        self.value = value
        self.dots = dots
        self.type = type
    }

    public init(value: NoteValue, dots: Int = 0, type: NoteType = .note) throws {
        guard dots >= 0 else { throw NoteDurationParseError.negativeDots(dots) }
        self.value = value
        self.dots = dots
        self.type = type
    }

    /// Canonical textual representation used by VexFlow-style inputs.
    public var rawValue: String {
        let dotsString = String(repeating: "d", count: dots)
        let typeString = type == .note ? "" : type.rawValue
        return "\(value.rawValue)\(dotsString)\(typeString)"
    }

    /// Parse from a compact string, e.g. `"4"`, `"8d"`, `"4r"`, `"16ddh"`.
    public init(parsing raw: String) throws {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw NoteDurationParseError.emptyInput }

        let pattern = #"^([0-9]+(?:\/[0-9]+)?|[whqbWHQB])(d*)([a-zA-Z]*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: normalized,
                  range: NSRange(normalized.startIndex..., in: normalized)
              )
        else {
            throw NoteDurationParseError.invalidFormat(raw)
        }

        guard let valueRange = Range(match.range(at: 1), in: normalized),
              let dotsRange = Range(match.range(at: 2), in: normalized),
              let typeRange = Range(match.range(at: 3), in: normalized)
        else {
            throw NoteDurationParseError.invalidFormat(raw)
        }

        let valueToken = String(normalized[valueRange])
        let dotsToken = String(normalized[dotsRange])
        let typeToken = String(normalized[typeRange])

        guard let value = NoteValue(parsing: valueToken) else {
            throw NoteDurationParseError.invalidValue(valueToken)
        }

        let type: NoteType
        if typeToken.isEmpty {
            type = .note
        } else if let parsedType = NoteType(parsing: typeToken) {
            type = parsedType
        } else {
            throw NoteDurationParseError.invalidType(typeToken)
        }

        try self.init(value: value, dots: dotsToken.count, type: type)
    }
}
