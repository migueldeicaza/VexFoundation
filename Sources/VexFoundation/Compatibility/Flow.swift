// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of the static API of `src/vexflow.ts` (VexFlow 5.4.0). Upstream 5
// merged `flow.ts` and `vex.ts` into the `VexFlow` class. In Swift, the
// classes are module types (use `VexFoundation.StaveNote` and so on), so this
// facade holds only the static functions and constants. (5.2.0 adds
// `VexFlow.EasyScoreError`; in Swift it is the module type `EasyScoreError`.
// 5.3.0 adds `VexFlow.EngravingProfile`, the module type `EngravingProfile`,
// and `VexFlow.measureEngraving`. 5.4.0 adds `VexFlow.PhraseLayout`,
// `FrettedInstrument`, `PercussionMap`, `FretDiagram`, `AlternatingTremolo`,
// `WrittenAccidentalState` and `NotationSpelling`, all module types.
// `ScoreNavigation` and `Publication` come with the second 5.4.0 pass.)
//
// Global state (fonts, metrics) lives in the active `VexRuntimeContext`.

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

/// Music fonts bundled with VexFoundation (see `FontRegistry.bundledFonts`).
public enum MusicFontName: String, CaseIterable, Sendable {
    case bravura = "Bravura"
    case gonville = "Gonville"
    case leland = "Leland"
    case petaluma = "Petaluma"

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
        default: return nil
        }
    }
}

/// Upstream name of the static facade (`VexFlow.setFonts(...)` and so on).
public typealias VexFlow = Flow

/// Static VexFlow API (port of the `VexFlow` class statics).
public enum Flow {

    // MARK: Build metadata

    /// Upstream `VexFlow.BUILD`.
    public static var BUILD: VexBuildInfo { VexVersion.build }

    /// Pre-draw geometry of formatted notation (VexFlow 5.3.0 `VexFlow.measureEngraving`).
    public static func measureEngraving(
        _ element: VexElement, options: GeometryOptions = GeometryOptions()
    ) throws -> EngravingGeometry {
        try VexFoundation.measureEngraving(element, options: options)
    }

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

    // MARK: Fonts

    /// Load the fonts that your app uses.
    ///
    /// Upstream loads web fonts from a CDN. VexFoundation bundles its fonts
    /// (see `FontRegistry.bundledFonts`), so this loads the bundled fonts and
    /// checks that each family in `fontNames` is available. With no names,
    /// only the bundled fonts are loaded. To add other fonts, use
    /// `FontRegistry.shared.register(family:data:weight:style:)`.
    public static func loadFonts(_ fontNames: String...) throws {
        try loadFonts(fontNames)
    }

    /// Array form of `loadFonts(_:)`.
    public static func loadFonts(_ fontNames: [String]) throws {
        let registry = FontRegistry.shared
        registry.loadBundledFontsIfNeeded()
        for fontName in fontNames where !registry.hasFamily(fontName) {
            throw FontRegistryError.resourceNotFound(fontName)
        }
    }

    /// Set the music and text fonts of the active runtime context.
    ///
    /// Example: `VexFlow.setFonts("Petaluma", "Petaluma Script")`.
    /// The default is `"Bravura", "Academico"`.
    public static func setFonts(_ fontNames: String...) {
        setFonts(fontNames)
    }

    /// Array form of `setFonts(_:)`.
    public static func setFonts(_ fontNames: [String]) {
        VexRuntime.getCurrentContext().setFonts(fontNames)
    }

    /// The font families of the active runtime context.
    public static func getFonts() -> [String] {
        VexRuntime.getCurrentContext().getFonts()
    }

    /// Choose text faces independently of the music fonts (VexFlow 5.1.0).
    /// Call it after `setFonts(_:)` to select a custom text face.
    public static func setTextFonts(_ fontNames: String...) {
        setTextFonts(fontNames)
    }

    /// Array form of `setTextFonts(_:)`.
    public static func setTextFonts(_ fontNames: [String]) {
        VexRuntime.getCurrentContext().setTextFonts(fontNames)
    }

    /// The text-first font stack used by new text elements.
    public static func getTextFonts() -> [String] {
        VexRuntime.getCurrentContext().getTextFonts()
    }

    // MARK: Music font (deprecated typed API)

    /// Typed API that guarantees a non-empty font list. Same as `setFonts(_:)`.
    @available(*, deprecated, message: "Use setFonts(_:).")
    @discardableResult
    public static func setMusicFont(_ fontNames: NonEmptyArray<MusicFontName>) -> [String] {
        let names = fontNames.array.map(\.rawValue)
        setFonts(names)
        return names
    }

    /// Convenience typed overload for variadic call sites.
    @available(*, deprecated, message: "Use setFonts(_:).")
    @discardableResult
    public static func setMusicFont(_ first: MusicFontName, _ rest: MusicFontName...) -> [String] {
        let names = ([first] + rest).map(\.rawValue)
        setFonts(names)
        return names
    }

    /// String convenience API that throws for invalid input.
    @available(*, deprecated, message: "Use setFonts(_:).")
    @discardableResult
    public static func setMusicFont(parsing fontNames: [String]) throws -> [String] {
        guard !fontNames.isEmpty else {
            throw MusicFontParseError.emptyFontList
        }

        let parsed = try fontNames.map { name in
            guard let parsed = MusicFontName(parsing: name) else {
                throw MusicFontParseError.invalidFontName(name)
            }
            return parsed.rawValue
        }

        setFonts(parsed)
        return parsed
    }

    /// String convenience API that returns nil for invalid input.
    @available(*, deprecated, message: "Use setFonts(_:).")
    @discardableResult
    public static func setMusicFont(parsingOrNil fontNames: [String]) -> [String]? {
        guard !fontNames.isEmpty else { return nil }
        var names: [String] = []
        for name in fontNames {
            guard let parsed = MusicFontName(parsing: name) else { return nil }
            names.append(parsed.rawValue)
        }
        setFonts(names)
        return names
    }

    @available(*, deprecated, renamed: "getFonts()")
    public static func getMusicFont() -> [String] {
        getFonts()
    }

    // MARK: Constants

    /// Upstream has setters for these constants. In Swift they are
    /// fixed `Tables` values, so only the getters are ported.
    public static var RENDER_PRECISION_PLACES: Int { Tables.RENDER_PRECISION_PLACES }

    public static var SOFTMAX_FACTOR: Double { Tables.SOFTMAX_FACTOR }

    /// Same-line unisons share the notehead position (active runtime context).
    public static var UNISON: Bool {
        get { Tables.UNISON }
        set { Tables.UNISON = newValue }
    }

    public static var NOTATION_FONT_SCALE: Double { Tables.NOTATION_FONT_SCALE }

    public static var TABLATURE_FONT_SCALE: Double { Tables.TABLATURE_FONT_SCALE }

    public static var RESOLUTION: Int { Tables.RESOLUTION }

    public static var SLASH_NOTEHEAD_WIDTH: Double { Tables.SLASH_NOTEHEAD_WIDTH }

    public static var STAVE_LINE_DISTANCE: Double { Tables.STAVE_LINE_DISTANCE }

    /// The stave line width: the `Stave.lineWidth` metric of the active
    /// runtime context. The setter also sets `TabStave.lineWidth`.
    public static var STAVE_LINE_THICKNESS: Double {
        get {
            let context = VexRuntime.getCurrentContext()
            return Metrics.number(context.metrics.get("Stave.lineWidth")) ?? context.getStaveLineThickness()
        }
        set {
            let context = VexRuntime.getCurrentContext()
            context.metrics.set("Stave.lineWidth", newValue)
            context.metrics.set("TabStave.lineWidth", newValue)
            context.metrics.clear("Stave")
            context.metrics.clear("TabStave")
            // Upstream leaves Tables.STAVE_LINE_THICKNESS unchanged here.
        }
    }

    public static var STEM_HEIGHT: Double { Tables.STEM_HEIGHT }

    public static var STEM_WIDTH: Double { Tables.STEM_WIDTH }

    // MARK: Table utilities

    public static func keySignature(_ spec: String) throws -> [(type: String, line: Double)] {
        try Tables.keySignature(spec)
    }

    public static func hasKeySignature(_ spec: String) -> Bool {
        Tables.hasKeySignature(spec)
    }

    /// Convert a typed duration into total ticks, with the dots.
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
}
