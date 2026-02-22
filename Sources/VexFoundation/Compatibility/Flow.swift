// VexFoundation - Lightweight compatibility facade for selected VexFlow `Flow` utilities.

import Foundation

public enum MusicFontParseError: Error, LocalizedError, Sendable {
    case emptyFontList
    case invalidFontName(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFontList:
            return "Font list cannot be empty."
        case .invalidFontName(let raw):
            return "Unknown music font name: '\(raw)'."
        }
    }
}

/// Supported built-in music font names for typed font selection.
public enum MusicFontName: String, CaseIterable, Sendable {
    case bravura = "Bravura"
    case gonville = "Gonville"
    case leland = "Leland"
    case petaluma = "Petaluma"
    case custom = "Custom"

    /// Parse a font name from a case-insensitive string.
    public init?(parsing raw: String) {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "bravura": self = .bravura
        case "gonville": self = .gonville
        case "leland": self = .leland
        case "petaluma": self = .petaluma
        case "custom", "vexflowcustom": self = .custom
        default: return nil
        }
    }

    fileprivate func load() -> VexFont {
        switch self {
        case .bravura:
            return FontLoader.loadBravura()
        case .gonville:
            return FontLoader.loadGonville()
        case .leland:
            return FontLoader.loadLeland()
        case .petaluma:
            return FontLoader.loadPetaluma()
        case .custom:
            return FontLoader.loadCustom()
        }
    }
}

/// Lightweight compatibility facade that intentionally wraps strongly-typed core APIs.
public enum Flow {

    // MARK: Build metadata

    public static var BUILD: VexBuildInfo { VexVersion.build }

    // MARK: Constants

    public static var RESOLUTION: Int { Tables.RESOLUTION }

    public static var STAVE_LINE_THICKNESS: Double {
        get { Tables.STAVE_LINE_THICKNESS }
        set { Tables.STAVE_LINE_THICKNESS = newValue }
    }

    public static var RENDER_PRECISION_PLACES: Int { Tables.RENDER_PRECISION_PLACES }

    // MARK: Runtime Context

    /// Create a new isolated runtime context.
    public static func makeRuntimeContext() -> VexRuntimeContext {
        VexRuntimeContext()
    }

    /// Get the currently active runtime context.
    public static func getRuntimeContext() -> VexRuntimeContext {
        VexRuntime.getCurrentContext()
    }

    /// Replace the active runtime context.
    public static func setRuntimeContext(_ context: VexRuntimeContext) {
        VexRuntime.setCurrentContext(context)
    }

    /// Run a closure with a temporary runtime context, then restore the previous one.
    @discardableResult
    public static func withRuntimeContext<T>(_ context: VexRuntimeContext, _ body: () throws -> T) rethrows -> T {
        try VexRuntime.withContext(context, body)
    }

    // MARK: Duration utilities

    /// Convert a typed duration into total ticks, including dotted augmentation.
    public static func durationToTicks(_ duration: NoteDurationSpec) -> Int {
        var ticks = Tables.durationToTicks(duration.value)
        var currentTicks = ticks

        for _ in 0..<duration.dots {
            if currentTicks <= 1 { break }
            currentTicks /= 2
            ticks += currentTicks
        }

        return ticks
    }

    /// String convenience parser for duration-to-ticks conversion.
    public static func durationToTicks(_ duration: String) throws -> Int {
        let parsed = try NoteDurationSpec(parsing: duration)
        return durationToTicks(parsed)
    }

    /// Failable string convenience parser for duration-to-ticks conversion.
    public static func durationToTicksOrNil(_ duration: String) -> Int? {
        try? durationToTicks(duration)
    }

    // MARK: Key signature utilities

    public static func hasKeySignature(_ spec: String) -> Bool {
        Tables.hasKeySignature(spec)
    }

    public static func keySignature(_ spec: String) throws -> [(type: String, line: Double)] {
        try Tables.keySignature(spec)
    }

    // MARK: Music font stack

    /// Typed-first API that guarantees a non-empty font list.
    @discardableResult
    public static func setMusicFont(_ fontNames: NonEmptyArray<MusicFontName>) -> [VexFont] {
        let fonts = fontNames.array.map { $0.load() }
        Glyph.setMusicFont(fonts)
        return fonts
    }

    /// Convenience typed overload for variadic call sites.
    @discardableResult
    public static func setMusicFont(_ first: MusicFontName, _ rest: MusicFontName...) -> [VexFont] {
        guard let nonEmpty = NonEmptyArray(validating: [first] + rest) else {
            return []
        }
        return setMusicFont(nonEmpty)
    }

    /// String convenience API that throws for invalid input.
    @discardableResult
    public static func setMusicFont(parsing fontNames: [String]) throws -> [VexFont] {
        guard !fontNames.isEmpty else {
            throw MusicFontParseError.emptyFontList
        }

        let parsed = try fontNames.map { name in
            guard let parsed = MusicFontName(parsing: name) else {
                throw MusicFontParseError.invalidFontName(name)
            }
            return parsed
        }

        guard let nonEmpty = NonEmptyArray(validating: parsed) else {
            throw MusicFontParseError.emptyFontList
        }

        return setMusicFont(nonEmpty)
    }

    /// String convenience API that returns nil for invalid input.
    @discardableResult
    public static func setMusicFont(parsingOrNil fontNames: [String]) -> [VexFont]? {
        try? setMusicFont(parsing: fontNames)
    }

    public static func getMusicFont() -> [String] {
        Glyph.MUSIC_FONT_STACK.map(\.name)
    }

    public static func getMusicFontStack() -> [VexFont] {
        Glyph.MUSIC_FONT_STACK
    }
}
