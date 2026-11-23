// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/engravingprofile.ts` (VexFlow 5.3.0).
// Immutable, score-local settings for pitched glyphs and beam layout.
//
// Upstream takes the parsed SMuFL `metadata.json` of an installed font. The Swift
// port also bundles the needed subset (fontName, engravingDefaults,
// glyphsWithAnchors) for Bravura, Petaluma and Leland: see
// `EngravingProfile.bundledMetadata(for:)` and `Resources/smufl/NOTICE.txt`.

import CoreFoundation
import Foundation

/// Coordinates in a SMuFL font, in staff spaces, where positive y points up.
public struct EngravingAnchor: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Stem side of a SMuFL notehead anchor (`stemUpSE` or `stemDownNW`).
public enum EngravingStemSide: Sendable {
    case up
    case down
}

/// Errors for invalid explicit settings (upstream `RangeError`).
public enum EngravingProfileError: Error, LocalizedError, Equatable, Sendable {
    case missingMusicFont
    case invalidDistance
    case invalidMetadata

    public var errorDescription: String? {
        switch self {
        case .missingMusicFont: return "Expected a music font family."
        case .invalidDistance: return "Invalid engraving distance in staff spaces."
        case .invalidMetadata: return "Expected SMuFL metadata as a JSON object."
        }
    }
}

/// Holds a validated copy of the supported metadata. Never changes global Metrics or fonts.
/// All distances are in staff spaces.
public final class EngravingProfile: Sendable {
    public let musicFont: String
    public let beamThickness: Double
    public let clearance: Double
    private let anchors: [String: (up: EngravingAnchor?, down: EngravingAnchor?)]

    /// - Parameters:
    ///   - musicFont: the music font family, for example `"Bravura"`.
    ///   - metadata: the parsed SMuFL `metadata.json` (a `[String: Any]` from
    ///     `JSONSerialization`). It is ignored unless its `fontName` equals `musicFont`.
    ///   - beamThickness: explicit beam thickness. Default: `engravingDefaults.beamThickness`, else 0.5.
    ///   - clearance: explicit beam clearance. Default: 0.25.
    public init(musicFont: String, metadata: Any? = nil, beamThickness: Double? = nil, clearance: Double? = nil) throws {
        if musicFont.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw EngravingProfileError.missingMusicFont
        }
        self.musicFont = musicFont
        let supplied = Self.record(metadata)
        let metadata = (supplied["fontName"] as? String) == musicFont ? supplied : [:]
        let beamThickness = beamThickness
            ?? Self.distance(Self.record(metadata["engravingDefaults"])["beamThickness"], fallback: 0.5)
        let clearance = clearance ?? 0.25
        if !Self.distance(beamThickness, fallback: .nan).isFinite
            || !Self.distance(clearance, fallback: .nan, allowZero: true).isFinite {
            throw EngravingProfileError.invalidDistance
        }
        self.beamThickness = beamThickness
        self.clearance = clearance
        var anchors: [String: (up: EngravingAnchor?, down: EngravingAnchor?)] = [:]
        // Sorted for a deterministic result when two names share a code point.
        let glyphs = Self.record(metadata["glyphsWithAnchors"])
        for name in glyphs.keys.sorted() {
            guard let glyph = Glyphs.code(named: name) else { continue }
            let fields = Self.record(glyphs[name])
            anchors[glyph] = (up: Self.readAnchor(fields["stemUpSE"]), down: Self.readAnchor(fields["stemDownNW"]))
        }
        self.anchors = anchors
    }

    /// Parse `metadata.json` data, then create the profile.
    public convenience init(
        musicFont: String, metadataJSON: Data, beamThickness: Double? = nil, clearance: Double? = nil
    ) throws {
        guard let metadata = try JSONSerialization.jsonObject(with: metadataJSON) as? [String: Any] else {
            throw EngravingProfileError.invalidMetadata
        }
        try self.init(musicFont: musicFont, metadata: metadata, beamThickness: beamThickness, clearance: clearance)
    }

    /// A profile that uses the bundled SMuFL metadata of `musicFont` (Swift extension).
    /// Fonts without bundled metadata use the native glyph fallback, as upstream does without metadata.
    public static func bundled(
        musicFont: String, beamThickness: Double? = nil, clearance: Double? = nil
    ) throws -> EngravingProfile {
        try EngravingProfile(
            musicFont: musicFont,
            metadata: bundledMetadata(for: musicFont),
            beamThickness: beamThickness,
            clearance: clearance
        )
    }

    /// Families with bundled SMuFL metadata.
    public static let bundledMetadataFamilies = ["Bravura", "Petaluma", "Leland"]

    /// The bundled subset of the SMuFL `metadata.json` of `family`, or `nil`.
    public static func bundledMetadata(for family: String) -> [String: Any]? {
        guard let data = bundledMetadataData[family] else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static let bundledMetadataData: [String: Data] = {
        var result: [String: Data] = [:]
        for family in bundledMetadataFamilies {
            let resource = family.lowercased() + "-metadata"
            guard let url = Bundle.module.url(forResource: resource, withExtension: "json", subdirectory: "smufl")
                ?? Bundle.module.url(forResource: resource, withExtension: "json"),
                let data = try? Data(contentsOf: url) else { continue }
            result[family] = data
        }
        return result
    }()

    /// Missing or malformed anchors delegate to VF5's native glyph fallback.
    public func stemAnchor(_ glyph: String, direction: EngravingStemSide) -> EngravingAnchor? {
        guard let entry = anchors[glyph] else { return nil }
        return direction == .up ? entry.up : entry.down
    }

    // MARK: - Metadata helpers

    private static func record(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    /// A JSON number (not a boolean), as JavaScript `typeof value === 'number'`.
    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.doubleValue
        }
        return value as? Double
    }

    /// Ignore unusable optional font fields. Reject invalid explicit user settings.
    private static func distance(_ value: Any?, fallback: Double, allowZero: Bool = false) -> Double {
        guard let value = number(value), value.isFinite, allowZero ? value >= 0 : value > 0, value <= 16 else {
            return fallback
        }
        return value
    }

    private static func readAnchor(_ value: Any?) -> EngravingAnchor? {
        guard let array = value as? [Any], array.count == 2 else { return nil }
        let values = array.compactMap { number($0) }
        guard values.count == 2, values.allSatisfy({ $0.isFinite && abs($0) <= 16 }) else { return nil }
        return EngravingAnchor(x: values[0], y: values[1])
    }
}
