// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Diatonic staff note letters.
public enum NoteLetter: String, CaseIterable, Sendable, Codable {
    case c = "c"
    case d = "d"
    case e = "e"
    case f = "f"
    case g = "g"
    case a = "a"
    case b = "b"

    public init?(parsing raw: String) {
        self.init(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// Accidentals supported by key token parsing.
public enum StaffAccidental: String, CaseIterable, Sendable, Codable {
    case natural = "n"
    case sharp = "#"
    case doubleSharp = "##"
    case flat = "b"
    case doubleFlat = "bb"

    public init?(parsing raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "N": self = .natural
        case "#": self = .sharp
        case "##": self = .doubleSharp
        case "B": self = .flat
        case "BB": self = .doubleFlat
        default: return nil
        }
    }

    var keyToken: String {
        switch self {
        case .natural: return "n"
        case .sharp: return "#"
        case .doubleSharp: return "##"
        case .flat: return "b"
        case .doubleFlat: return "bb"
        }
    }
}

/// Typed note root for staff keys.
public struct StaffNoteRoot: Hashable, Sendable, Codable {
    public let letter: NoteLetter
    public let accidental: StaffAccidental?

    public init(letter: NoteLetter, accidental: StaffAccidental? = nil) {
        self.letter = letter
        self.accidental = accidental
    }

    var keyToken: String {
        letter.rawValue + (accidental?.keyToken ?? "")
    }
}

/// Typed non-note root for staff keys.
public enum StaffNonNoteRoot: String, Hashable, Sendable, Codable {
    case rest = "r"
    case x = "x"
}

/// Root token for staff note keys.
public enum StaffKeyRoot: Hashable, Sendable, Codable {
    case note(StaffNoteRoot)
    case nonNote(StaffNonNoteRoot)

    var keyToken: String {
        switch self {
        case .note(let noteRoot):
            return noteRoot.keyToken
        case .nonNote(let nonNoteRoot):
            return nonNoteRoot.rawValue
        }
    }
}

/// Errors for string key parsing.
public enum StaffKeyParseError: Error, LocalizedError, Sendable {
    case emptyInput
    case invalidFormat(String)
    case invalidRoot(String)
    case invalidOctave(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Key spec input cannot be empty."
        case .invalidFormat(let raw):
            return "Invalid key format: '\(raw)'. Expected '<root>/<octave>' or '<root>/<octave>/<custom-glyph>'."
        case .invalidRoot(let raw):
            return "Invalid key root token: '\(raw)'."
        case .invalidOctave(let raw):
            return "Invalid key octave: '\(raw)'."
        }
    }
}

/// Strongly typed staff key token (e.g. `c#/4`, `g/5/x2`).
public struct StaffKeySpec: Hashable, Sendable, Codable {
    public let root: StaffKeyRoot
    public let octave: Int
    public let customGlyphType: String?

    public init(root: StaffKeyRoot, octave: Int, customGlyphType: String? = nil) {
        self.root = root
        self.octave = octave
        self.customGlyphType = customGlyphType?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(letter: NoteLetter, accidental: StaffAccidental? = nil, octave: Int, customGlyphType: String? = nil) {
        self.init(root: .note(StaffNoteRoot(letter: letter, accidental: accidental)), octave: octave, customGlyphType: customGlyphType)
    }

    public var rawValue: String {
        var result = "\(root.keyToken)/\(octave)"
        if let custom = customGlyphType, !custom.isEmpty {
            result += "/\(custom)"
        }
        return result
    }

    public init(parsing raw: String) throws {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw StaffKeyParseError.emptyInput }

        let pieces = normalized.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard pieces.count == 2 || pieces.count == 3 else {
            throw StaffKeyParseError.invalidFormat(raw)
        }

        let rootTokenRaw = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let octaveTokenRaw = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let customGlyphTokenRaw = pieces.count == 3
            ? pieces[2].trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        let root = try Self.parseRoot(rootTokenRaw)
        guard let octave = Int(octaveTokenRaw) else {
            throw StaffKeyParseError.invalidOctave(octaveTokenRaw)
        }

        let customGlyphType: String?
        if let customGlyphTokenRaw, !customGlyphTokenRaw.isEmpty {
            customGlyphType = customGlyphTokenRaw
        } else {
            customGlyphType = nil
        }

        self.init(root: root, octave: octave, customGlyphType: customGlyphType)
    }

    public init?(parsingOrNil raw: String) {
        guard let parsed = try? StaffKeySpec(parsing: raw) else { return nil }
        self = parsed
    }

    public static func parseMany(_ rawKeys: [String]) throws -> [StaffKeySpec] {
        try rawKeys.map { try StaffKeySpec(parsing: $0) }
    }

    public static func parseManyNonEmpty(_ rawKeys: [String]) throws -> NonEmptyArray<StaffKeySpec> {
        let parsed = try parseMany(rawKeys)
        guard let nonEmpty = NonEmptyArray(validating: parsed) else {
            throw StaffKeyParseError.emptyInput
        }
        return nonEmpty
    }

    public static func parseManyOrNil(_ rawKeys: [String]) -> [StaffKeySpec]? {
        try? parseMany(rawKeys)
    }

    public static func parseManyNonEmptyOrNil(_ rawKeys: [String]) -> NonEmptyArray<StaffKeySpec>? {
        try? parseManyNonEmpty(rawKeys)
    }

    private static func parseRoot(_ token: String) throws -> StaffKeyRoot {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw StaffKeyParseError.invalidRoot(token)
        }

        let upper = normalized.uppercased()
        if upper == "R" { return .nonNote(.rest) }
        if upper == "X" { return .nonNote(.x) }

        guard let first = upper.first, let letter = NoteLetter(parsing: String(first)) else {
            throw StaffKeyParseError.invalidRoot(token)
        }

        let accidentalToken = String(upper.dropFirst())
        let accidental: StaffAccidental?
        if accidentalToken.isEmpty {
            accidental = nil
        } else if let parsedAccidental = StaffAccidental(parsing: accidentalToken) {
            accidental = parsedAccidental
        } else {
            throw StaffKeyParseError.invalidRoot(token)
        }

        return .note(StaffNoteRoot(letter: letter, accidental: accidental))
    }
}
