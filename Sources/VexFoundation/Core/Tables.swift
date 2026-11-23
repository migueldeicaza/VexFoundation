// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tables.ts` (VexFlow 5.0.0).
//
// Swift notes:
// - `GlyphProps` and `KeyProps` live in `Notes/Note.swift` (as upstream `note.ts`).
// - `ArticulationStruct` is declared here (upstream `articulation.ts`), because
//   the `articulations` table needs it. `Tables.ArticulationStruct` is an alias.
// - Glyph codes are SMuFL code point strings (`Glyphs.*`), not glyph names.

import Foundation

// MARK: - Key Signature Entry

/// Defines a key signature by accidental type and count.
public struct KeySignatureSpec: Sendable {
    public var accidental: String?
    public var num: Int

    public init(accidental: String? = nil, num: Int) {
        self.accidental = accidental
        self.num = num
    }

    @available(*, deprecated, renamed: "accidental")
    public var acc: String? { accidental }
}

// MARK: - Articulation Struct

/// Defines an articulation glyph with optional above/below variants (upstream `articulation.ts`).
public struct ArticulationStruct: Sendable {
    public var code: String?
    public var aboveCode: String?
    public var belowCode: String?
    public var betweenLines: Bool

    public init(code: String? = nil, aboveCode: String? = nil, belowCode: String? = nil, betweenLines: Bool) {
        self.code = code
        self.aboveCode = aboveCode
        self.belowCode = belowCode
        self.betweenLines = betweenLines
    }
}

/// Clef properties (upstream `{ lineShift: number }`).
public struct ClefProperties: Sendable, Equatable {
    public var lineShift: Int

    public init(lineShift: Int) {
        self.lineShift = lineShift
    }
}

public enum TablesError: Error, LocalizedError, Equatable, Sendable {
    case missingDurationTickMapping(String)
    case invalidClef(String)
    case invalidDuration(String)
    case integerToNoteOutOfRange(Int)

    public var errorDescription: String? {
        switch self {
        case .missingDurationTickMapping(let duration):
            return "Missing tick mapping for duration \(duration)."
        case .invalidClef(let clef):
            return "Invalid clef: \(clef)"
        case .invalidDuration(let duration):
            return "The provided duration is not valid: \(duration)"
        case .integerToNoteOutOfRange(let integer):
            return "integerToNote() requires an integer in the range [0, 11]: \(integer)"
        }
    }
}

/// Central constants and lookup tables for VexFlow music notation.
public enum Tables {

    public typealias ArticulationStruct = VexFoundation.ArticulationStruct

    // MARK: - Constants

    /// Whether same-line unisons should share head placement when possible.
    public static var UNISON: Bool {
        get { VexRuntime.getCurrentContext().getUnisonEnabled() }
        set { VexRuntime.getCurrentContext().setUnisonEnabled(newValue) }
    }
    /// Softmax factor for formatter.
    public static let SOFTMAX_FACTOR: Double = 10
    /// Stem width in pixels.
    public static let STEM_WIDTH: Double = 1.5
    /// Default stem height in pixels.
    public static let STEM_HEIGHT: Double = 35
    /// Stave line thickness in pixels.
    public static var STAVE_LINE_THICKNESS: Double {
        get { VexRuntime.getCurrentContext().getStaveLineThickness() }
        set { VexRuntime.getCurrentContext().setStaveLineThickness(newValue) }
    }
    /// Decimal places for rounding during rendering.
    public static let RENDER_PRECISION_PLACES: Int = 3
    /// Ticks per whole note.
    public static let RESOLUTION: Int = 16384

    /// Default font scale for standard notation.
    public static let NOTATION_FONT_SCALE: Double = 39
    /// Default font scale for tablature.
    public static let TABLATURE_FONT_SCALE: Double = 39

    /// Width of slash noteheads.
    public static let SLASH_NOTEHEAD_WIDTH: Double = 15
    /// Distance between stave lines.
    public static let STAVE_LINE_DISTANCE: Double = 10

    /// HACK:
    /// Since text origins are positioned at the baseline, we must
    /// compensate for the ascender of the text. Of course, 1 staff space is
    /// a very poor approximation.
    ///
    /// This will be deprecated in the future. This is a temporary solution until
    /// we have more robust text metrics.
    public static let TEXT_HEIGHT_OFFSET_HACK: Double = 1

    /// Default time signature.
    public static let TIME4_4: (numBeats: Int, beatValue: Int, resolution: Int) = (4, 4, RESOLUTION)

    // MARK: - Duration Tables

    /// Map duration numbers to 'ticks', the unit of duration used throughout VexFlow.
    /// For example, a quarter note is 4, so it maps to RESOLUTION / 4 = 4096 ticks.
    public static let durations: [String: Int] = [
        "1/2": RESOLUTION * 2,
        "1": RESOLUTION / 1,
        "2": RESOLUTION / 2,
        "4": RESOLUTION / 4,
        "8": RESOLUTION / 8,
        "16": RESOLUTION / 16,
        "32": RESOLUTION / 32,
        "64": RESOLUTION / 64,
        "128": RESOLUTION / 128,
        "256": RESOLUTION / 256,
    ]

    /// Duration aliases: shorthand names for durations.
    public static let durationAliases: [String: String] = [
        "w": "1",
        "h": "2",
        "q": "4",
        // This is the default duration used to render bars (BarNote). Bars no longer
        // consume ticks, so this should be a no-op.
        "b": "256",
    ]

    /// Glyph properties per duration (upstream `Partial<GlyphProps>`: `codeHead` is empty).
    ///
    /// 1/2, 1, 2, 4, 8, 16, 32, 64, 128 as upstream 5.0.0.
    /// 4.x fix kept: a `256` entry (upstream 5.0.0 falls back to `4`).
    public static let durationCodes: [String: GlyphProps] = [
        "1/2": GlyphProps(stem: false),
        "1": GlyphProps(stem: false),
        "2": GlyphProps(stem: true),
        "4": GlyphProps(stem: true),
        "8": GlyphProps(stemBeamExtension: 0, stem: true, codeFlagUp: Glyphs.flag8thUp, beamCount: 1),
        "16": GlyphProps(stemBeamExtension: 0, stem: true, codeFlagUp: Glyphs.flag16thUp, beamCount: 2),
        "32": GlyphProps(stemBeamExtension: 7.5, stem: true, codeFlagUp: Glyphs.flag32ndUp, beamCount: 3),
        "64": GlyphProps(stemBeamExtension: 15, stem: true, codeFlagUp: Glyphs.flag64thUp, beamCount: 4),
        "128": GlyphProps(stemBeamExtension: 22.5, stem: true, codeFlagUp: Glyphs.flag128thUp, beamCount: 5),
        // 4.x-branch fix (a0c4d47a): 256th notes.
        "256": GlyphProps(stemBeamExtension: 25, stem: true, codeFlagUp: Glyphs.flag256thUp, beamCount: 6),
    ]

    // MARK: - Key Signatures

    /// Key signature definitions: key name → accidental type + count.
    public static let keySignatures: [String: KeySignatureSpec] = [
        "C": KeySignatureSpec(num: 0),
        "Am": KeySignatureSpec(num: 0),
        "F": KeySignatureSpec(accidental: "b", num: 1),
        "Dm": KeySignatureSpec(accidental: "b", num: 1),
        "Bb": KeySignatureSpec(accidental: "b", num: 2),
        "Gm": KeySignatureSpec(accidental: "b", num: 2),
        "Eb": KeySignatureSpec(accidental: "b", num: 3),
        "Cm": KeySignatureSpec(accidental: "b", num: 3),
        "Ab": KeySignatureSpec(accidental: "b", num: 4),
        "Fm": KeySignatureSpec(accidental: "b", num: 4),
        "Db": KeySignatureSpec(accidental: "b", num: 5),
        "Bbm": KeySignatureSpec(accidental: "b", num: 5),
        "Gb": KeySignatureSpec(accidental: "b", num: 6),
        "Ebm": KeySignatureSpec(accidental: "b", num: 6),
        "Cb": KeySignatureSpec(accidental: "b", num: 7),
        "Abm": KeySignatureSpec(accidental: "b", num: 7),
        "G": KeySignatureSpec(accidental: "#", num: 1),
        "Em": KeySignatureSpec(accidental: "#", num: 1),
        "D": KeySignatureSpec(accidental: "#", num: 2),
        "Bm": KeySignatureSpec(accidental: "#", num: 2),
        "A": KeySignatureSpec(accidental: "#", num: 3),
        "F#m": KeySignatureSpec(accidental: "#", num: 3),
        "E": KeySignatureSpec(accidental: "#", num: 4),
        "C#m": KeySignatureSpec(accidental: "#", num: 4),
        "B": KeySignatureSpec(accidental: "#", num: 5),
        "G#m": KeySignatureSpec(accidental: "#", num: 5),
        "F#": KeySignatureSpec(accidental: "#", num: 6),
        "D#m": KeySignatureSpec(accidental: "#", num: 6),
        "C#": KeySignatureSpec(accidental: "#", num: 7),
        "A#m": KeySignatureSpec(accidental: "#", num: 7),
    ]

    /// Staff line positions for flats (in order of key signature).
    public static let flatPositions: [Double] = [2, 0.5, 2.5, 1, 3, 1.5, 3.5]
    /// Staff line positions for sharps (in order of key signature).
    public static let sharpPositions: [Double] = [0, 1.5, -0.5, 1, 2.5, 0.5, 2]

    /// Build accidental list for a key signature spec.
    public static func keySignature(_ spec: String) throws -> [(type: String, line: Double)] {
        guard let keySpec = keySignatures[spec] else {
            throw VexError("BadKeySignature", "Bad key signature spec: '\(spec)'")
        }
        guard let accidental = keySpec.accidental else {
            return []
        }
        let notes = accidental == "b" ? flatPositions : sharpPositions
        var accList: [(type: String, line: Double)] = []
        for i in 0..<keySpec.num {
            accList.append((type: accidental, line: notes[i]))
        }
        return accList
    }

    public static func getKeySignatures() -> [String: KeySignatureSpec] {
        keySignatures
    }

    /// Check if a key signature spec is valid.
    public static func hasKeySignature(_ spec: String) -> Bool {
        keySignatures[spec] != nil
    }

    // MARK: - Clefs

    /// Clef vertical line shifts.
    /// Swift: `.tab` is accepted with shift 0 (upstream `clefs` has no `tab`).
    public static let clefLineShifts: [ClefName: Int] = [
        .treble: 0,
        .bass: 6,
        .tenor: 4,
        .alto: 3,
        .soprano: 1,
        .percussion: 0,
        .mezzoSoprano: 2,
        .baritoneC: 5,
        .baritoneF: 5,
        .subbass: 7,
        .french: -1,
        .tab: 0,
    ]

    public static func clefPropertiesThrowing(_ clef: ClefName) throws -> ClefProperties {
        guard let shift = clefLineShifts[clef] else {
            throw TablesError.invalidClef(clef.rawValue)
        }
        return ClefProperties(lineShift: shift)
    }

    /// Clef properties for a clef name string. Throws for an invalid clef (as upstream).
    public static func clefProperties(_ clef: String) throws -> ClefProperties {
        guard let name = ClefName(rawValue: clef) else {
            throw TablesError.invalidClef(clef)
        }
        return try clefPropertiesThrowing(name)
    }

    public static func clefProperties(_ clef: ClefName) -> ClefProperties {
        (try? clefPropertiesThrowing(clef)) ?? ClefProperties(lineShift: 0)
    }

    // MARK: - Note Info

    /// Properties for a note name (used by keyProperties).
    private struct NoteInfo {
        var index: Int
        var intVal: Int?
    }

    private static let notesInfo: [String: NoteInfo] = [
        "C": NoteInfo(index: 0, intVal: 0),
        "CN": NoteInfo(index: 0, intVal: 0),
        "C#": NoteInfo(index: 0, intVal: 1),
        "C##": NoteInfo(index: 0, intVal: 2),
        "CB": NoteInfo(index: 0, intVal: 11),
        "CBB": NoteInfo(index: 0, intVal: 10),
        "D": NoteInfo(index: 1, intVal: 2),
        "DN": NoteInfo(index: 1, intVal: 2),
        "D#": NoteInfo(index: 1, intVal: 3),
        "D##": NoteInfo(index: 1, intVal: 4),
        "DB": NoteInfo(index: 1, intVal: 1),
        "DBB": NoteInfo(index: 1, intVal: 0),
        "E": NoteInfo(index: 2, intVal: 4),
        "EN": NoteInfo(index: 2, intVal: 4),
        "E#": NoteInfo(index: 2, intVal: 5),
        "E##": NoteInfo(index: 2, intVal: 6),
        "EB": NoteInfo(index: 2, intVal: 3),
        "EBB": NoteInfo(index: 2, intVal: 2),
        "F": NoteInfo(index: 3, intVal: 5),
        "FN": NoteInfo(index: 3, intVal: 5),
        "F#": NoteInfo(index: 3, intVal: 6),
        "F##": NoteInfo(index: 3, intVal: 7),
        "FB": NoteInfo(index: 3, intVal: 4),
        "FBB": NoteInfo(index: 3, intVal: 3),
        "G": NoteInfo(index: 4, intVal: 7),
        "GN": NoteInfo(index: 4, intVal: 7),
        "G#": NoteInfo(index: 4, intVal: 8),
        "G##": NoteInfo(index: 4, intVal: 9),
        "GB": NoteInfo(index: 4, intVal: 6),
        "GBB": NoteInfo(index: 4, intVal: 5),
        "A": NoteInfo(index: 5, intVal: 9),
        "AN": NoteInfo(index: 5, intVal: 9),
        "A#": NoteInfo(index: 5, intVal: 10),
        "A##": NoteInfo(index: 5, intVal: 11),
        "AB": NoteInfo(index: 5, intVal: 8),
        "ABB": NoteInfo(index: 5, intVal: 7),
        "B": NoteInfo(index: 6, intVal: 11),
        "BN": NoteInfo(index: 6, intVal: 11),
        "B#": NoteInfo(index: 6, intVal: 12),
        "B##": NoteInfo(index: 6, intVal: 13),
        "BB": NoteInfo(index: 6, intVal: 10),
        "BBB": NoteInfo(index: 6, intVal: 9),
        "R": NoteInfo(index: 6), // Rest
        "X": NoteInfo(index: 6),
    ]

    /// The list of valid note types. Used by note.ts during parseNoteStruct().
    public static let validTypes: [String: String] = [
        "n": "note", "r": "rest", "h": "harmonic", "m": "muted",
        "s": "slash", "g": "ghost", "d": "diamond", "x": "x",
        "ci": "circled", "cx": "circle x", "sf": "slashed",
        "sb": "slashed backward", "sq": "square",
        "tu": "triangle up", "td": "triangle down",
    ]

    // MARK: - Key Properties

    /// Get properties for a key/octave string (e.g., "c/4", "g/5/t3").
    public static func keyProperties(
        _ key: StaffKeySpec,
        clef: ClefName = .treble,
        type: String = "N",
        octaveShift: Int = 0,
        duration: NoteValue = .quarter
    ) throws -> KeyProps {
        try keyProperties(
            key.rawValue,
            clef: clef,
            type: type,
            octaveShift: octaveShift,
            duration: duration.rawValue
        )
    }

    /// Get properties for a key/octave string.
    ///
    /// - Parameters:
    ///   - keyOctaveGlyph: a string in the format "key/octave" (e.g., "c/5") or
    ///     "key/octave/custom-note-head-code" (e.g., "g/5/t3").
    ///   - clef: the clef.
    ///   - type: the note type (e.g. "n", "r"). Upstream default "N".
    ///   - octaveShift: clef ottavation (0 = default; 1 = 8va; -1 = 8vb, etc.).
    ///   - duration: the note duration (upstream `params.duration`, default "4").
    /// - Returns: properties for the specified note.
    public static func keyProperties(
        _ keyOctaveGlyph: String,
        clef: ClefName = .treble,
        type: String = "N",
        octaveShift: Int = 0,
        duration: String = "4"
    ) throws -> KeyProps {
        let duration = try sanitizeDurationThrowing(duration)

        let pieces = keyOctaveGlyph.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard pieces.count >= 2 else {
            throw VexError("BadArguments",
                "First argument must be note/octave or note/octave/glyph-code: \(keyOctaveGlyph)")
        }

        let key = pieces[0].uppercased()
        let type = type.uppercased()
        guard let value = notesInfo[key] else {
            throw VexError("BadArguments", "Invalid key name: \(key)")
        }
        let octaveToken = pieces[1].trimmingCharacters(in: .whitespaces)
        // Upstream `parseInt('')` is NaN: a key without an octave (for example the "x/"
        // shorthand) gets a NaN line. `NoteHead` then places it on line 0 (`line || 0`).
        let octaveMissing = octaveToken.isEmpty
        var octave = 0
        if !octaveMissing {
            guard let parsedOctave = Int(octaveToken) else {
                throw VexError("BadArguments", "Invalid octave: \(keyOctaveGlyph)")
            }
            octave = parsedOctave
        }

        // .octaveShift is the shift to compensate for clef 8va/8vb.
        octave -= octaveShift

        let baseIndex = octave * 7 - 4 * 7
        var line = octaveMissing ? Double.nan : Double(baseIndex + value.index) / 2
        line += Double(try clefPropertiesThrowing(clef).lineShift)

        // Integer value for note arithmetic.
        let intValue: Int? = octaveMissing ? nil : value.intVal.map { octave * 12 + $0 }

        // If the user specified a glyph, overwrite the glyph code.
        let glyphName: String
        if pieces.count > 2 && !pieces[2].isEmpty {
            glyphName = pieces[2].uppercased()
        } else if type != "N" {
            glyphName = type
        } else {
            glyphName = key
        }
        let code = codeNoteHead(glyphName, duration: duration)

        var props = KeyProps(
            key: key,
            octave: octave,
            line: line,
            intValue: intValue,
            code: code,
            displaced: false
        )

        // VexFlowPatch (gated): inverted triangle notehead needs custom shift properties.
        if glyphName == "TI", !VexRuntime.getCurrentContext().upstreamParityMode {
            props.stemUpYShift = 5
            props.stemDownYShift = 5
            props.stemUpXOffset = 6
            props.stemDownXOffset = 4
        }
        return props
    }

    /// Upstream-style overload that takes the clef as a string.
    public static func keyProperties(
        _ keyOctaveGlyph: String,
        clef: String,
        type: String = "N",
        octaveShift: Int = 0,
        duration: String = "4"
    ) throws -> KeyProps {
        guard let clefName = ClefName(rawValue: clef) else {
            throw TablesError.invalidClef(clef)
        }
        return try keyProperties(keyOctaveGlyph, clef: clefName, type: type, octaveShift: octaveShift, duration: duration)
    }

    // MARK: - Integer to Note

    /// Convert an integer (0-11) to a note name.
    public static func integerToNoteThrowing(_ integer: Int) throws -> String {
        let table: [Int: String] = [
            0: "C", 1: "C#", 2: "D", 3: "D#", 4: "E", 5: "F",
            6: "F#", 7: "G", 8: "G#", 9: "A", 10: "A#", 11: "B",
        ]
        guard integer >= 0 && integer <= 11, let noteValue = table[integer] else {
            throw TablesError.integerToNoteOutOfRange(integer)
        }
        return noteValue
    }

    /// Convert an integer (0-11) to a note name.
    public static func integerToNote(_ integer: Int) -> String {
        (try? integerToNoteThrowing(integer)) ?? "C"
    }

    /// Used by annotation.ts and bend.ts. Clearly this implementation only works for the default font size.
    /// TODO: The actual width depends on the font family, size, weight, style.
    public static func textWidth(_ text: String) -> Double {
        7 * Double(text.count)
    }

    // MARK: - Articulations

    private static let articulations: [String: ArticulationStruct] = [
        "a.": ArticulationStruct(code: Glyphs.augmentationDot, betweenLines: true), // Staccato
        "av": ArticulationStruct(
            aboveCode: Glyphs.articStaccatissimoAbove,
            belowCode: Glyphs.articStaccatissimoBelow,
            betweenLines: true
        ), // Staccatissimo
        "a>": ArticulationStruct(
            aboveCode: Glyphs.articAccentAbove,
            belowCode: Glyphs.articAccentBelow,
            betweenLines: true
        ), // Accent
        "a-": ArticulationStruct(
            aboveCode: Glyphs.articTenutoAbove,
            belowCode: Glyphs.articTenutoBelow,
            betweenLines: true
        ), // Tenuto
        "a^": ArticulationStruct(
            aboveCode: Glyphs.articMarcatoAbove,
            belowCode: Glyphs.articMarcatoBelow,
            betweenLines: false
        ), // Marcato
        "a+": ArticulationStruct(code: Glyphs.pluckedLeftHandPizzicato, betweenLines: false), // Left hand pizzicato
        "ao": ArticulationStruct(
            aboveCode: Glyphs.pluckedSnapPizzicatoAbove,
            belowCode: Glyphs.pluckedSnapPizzicatoBelow,
            betweenLines: false
        ), // Snap pizzicato
        "ah": ArticulationStruct(code: Glyphs.stringsHarmonic, betweenLines: false), // Natural harmonic or open note
        "a@": ArticulationStruct(aboveCode: Glyphs.fermataAbove, belowCode: Glyphs.fermataBelow, betweenLines: false), // Fermata
        "a@a": ArticulationStruct(code: Glyphs.fermataAbove, betweenLines: false), // Fermata above staff
        "a@u": ArticulationStruct(code: Glyphs.fermataBelow, betweenLines: false), // Fermata below staff
        "a@s": ArticulationStruct(
            aboveCode: Glyphs.fermataShortAbove,
            belowCode: Glyphs.fermataShortBelow,
            betweenLines: false
        ), // Fermata short
        "a@as": ArticulationStruct(code: Glyphs.fermataShortAbove, betweenLines: false), // Fermata short above staff
        "a@us": ArticulationStruct(code: Glyphs.fermataShortBelow, betweenLines: false), // Fermata short below staff
        "a@l": ArticulationStruct(
            aboveCode: Glyphs.fermataLongAbove,
            belowCode: Glyphs.fermataLongBelow,
            betweenLines: false
        ), // Fermata long
        "a@al": ArticulationStruct(code: Glyphs.fermataLongAbove, betweenLines: false), // Fermata long above staff
        "a@ul": ArticulationStruct(code: Glyphs.fermataLongBelow, betweenLines: false), // Fermata long below staff
        "a@vl": ArticulationStruct(
            aboveCode: Glyphs.fermataVeryLongAbove,
            belowCode: Glyphs.fermataVeryLongBelow,
            betweenLines: false
        ), // Fermata very long
        "a@avl": ArticulationStruct(code: Glyphs.fermataVeryLongAbove, betweenLines: false), // Fermata very long above staff
        "a@uvl": ArticulationStruct(code: Glyphs.fermataVeryLongBelow, betweenLines: false), // Fermata very long below staff
        "a|": ArticulationStruct(code: Glyphs.stringsUpBow, betweenLines: false), // Bow up - up stroke
        "am": ArticulationStruct(code: Glyphs.stringsDownBow, betweenLines: false), // Bow down - down stroke
        "a,": ArticulationStruct(code: Glyphs.pictChokeCymbal, betweenLines: false), // Choked
    ]

    /// Look up an articulation. Returns nil for an unknown type (upstream `undefined`).
    public static func articulationCodes(_ artic: String) -> ArticulationStruct? {
        articulations[artic]
    }

    @available(*, deprecated, renamed: "articulationCodes(_:)")
    public static func articulationCode(_ type: String) -> ArticulationStruct? {
        articulationCodes(type)
    }

    // MARK: - Accidentals

    private static let accidentals: [String: String] = [
        "#": Glyphs.accidentalSharp,
        "##": Glyphs.accidentalDoubleSharp,
        "b": Glyphs.accidentalFlat,
        "bb": Glyphs.accidentalDoubleFlat,
        "n": Glyphs.accidentalNatural,
        "{": Glyphs.accidentalParensLeft,
        "}": Glyphs.accidentalParensRight,
        "db": Glyphs.accidentalThreeQuarterTonesFlatZimmermann,
        "d": Glyphs.accidentalQuarterToneFlatStein,
        "++": Glyphs.accidentalThreeQuarterTonesSharpStein,
        "+": Glyphs.accidentalQuarterToneSharpStein,
        "+-": Glyphs.accidentalKucukMucennebSharp,
        "bs": Glyphs.accidentalBakiyeFlat,
        "bss": Glyphs.accidentalBuyukMucennebFlat,
        "o": Glyphs.accidentalSori,
        "k": Glyphs.accidentalKoron,
        "bbs": Glyphs.accidentalBuyukMucennebSharp,
        "++-": Glyphs.accidentalBuyukMucennebSharp,
        "ashs": Glyphs.accidentalBuyukMucennebSharp,
        "afhf": Glyphs.accidentalBuyukMucennebSharp,
    ]

    /// Return the glyph code of an accidental type, or `accidental` itself when unknown.
    public static func accidentalCodes(_ accidental: String) -> String {
        accidentals[accidental] ?? accidental
    }

    /// True if `accidental` is a known accidental type (Swift helper).
    public static func hasAccidentalCode(_ accidental: String) -> Bool {
        accidentals[accidental] != nil
    }

    /// Helps determine the layout of accidentals.
    public static let accidentalColumnsTable: [Int: [String: [Int]]] = [
        1: ["a": [1], "b": [1]],
        2: ["a": [1, 2]],
        3: [
            "a": [1, 3, 2],
            "b": [1, 2, 1],
            "secondOnBottom": [1, 2, 3],
        ],
        4: [
            "a": [1, 3, 4, 2],
            "b": [1, 2, 3, 1],
            "spacedOutTetrachord": [1, 2, 1, 2],
        ],
        5: [
            "a": [1, 3, 5, 4, 2],
            "b": [1, 2, 4, 3, 1],
            "spacedOutPentachord": [1, 2, 3, 2, 1],
            "verySpacedOutPentachord": [1, 2, 1, 2, 1],
        ],
        6: [
            "a": [1, 3, 5, 6, 4, 2],
            "b": [1, 2, 4, 5, 3, 1],
            "spacedOutHexachord": [1, 3, 2, 1, 3, 2],
            "verySpacedOutHexachord": [1, 2, 1, 2, 1, 2],
        ],
    ]

    // MARK: - Ornaments

    private static let ornaments: [String: String] = [
        "mordent": Glyphs.ornamentShortTrill,
        "mordentInverted": Glyphs.ornamentMordent,
        "turn": Glyphs.ornamentTurn,
        "turnInverted": Glyphs.ornamentTurnSlash,
        "tr": Glyphs.ornamentTrill,
        "upprall": Glyphs.ornamentPrecompSlideTrillDAnglebert,
        "downprall": Glyphs.ornamentPrecompDoubleCadenceUpperPrefix,
        "prallup": Glyphs.ornamentPrecompTrillSuffixDandrieu,
        "pralldown": Glyphs.ornamentPrecompTrillLowerSuffix,
        "upmordent": Glyphs.ornamentPrecompSlideTrillBach,
        "downmordent": Glyphs.ornamentPrecompDoubleCadenceUpperPrefixTurn,
        "lineprall": Glyphs.ornamentPrecompAppoggTrill,
        "prallprall": Glyphs.ornamentTremblement,
        "scoop": Glyphs.brassScoop,
        "doit": Glyphs.brassDoitMedium,
        "fall": Glyphs.brassFallLipShort,
        "doitLong": Glyphs.brassLiftMedium,
        "fallLong": Glyphs.brassFallRoughMedium,
        "bend": Glyphs.brassBend,
        "plungerClosed": Glyphs.brassMuteClosed,
        "plungerOpen": Glyphs.brassMuteOpen,
        "flip": Glyphs.brassFlip,
        "jazzTurn": Glyphs.brassJazzTurn,
        "smear": Glyphs.brassSmear,
    ]

    /// Return the glyph code of an ornament type, or `ornament` itself when unknown.
    public static func ornamentCodes(_ ornament: String) -> String {
        ornaments[ornament] ?? ornament
    }

    /// True if `ornament` is a known ornament type (Swift helper).
    public static func hasOrnamentCode(_ ornament: String) -> Bool {
        ornaments[ornament] != nil
    }

    // MARK: - Unicode

    /// Non-SMuFL Unicode characters.
    public static let unicode: [String: String] = [
        // ♯ accidental sharp
        "sharp": "\u{266f}",
        // ♭ accidental flat
        "flat": "\u{266d}",
        // ♮ accidental natural
        "natural": "\u{266e}",
        // △ major seventh
        "triangle": "\u{25b3}",
        // ø half-diminished
        "o-with-slash": "\u{00f8}",
        // ° diminished
        "degrees": "\u{00b0}",
        // ○ diminished
        "circle": "\u{25cb}",
    ]

    // MARK: - Durations

    /// Convert duration aliases to the number based duration.
    /// If the input isn't an alias, simply return the input.
    /// Example: 'q' -> '4', '8' -> '8'. Throws for an invalid duration.
    public static func sanitizeDurationThrowing(_ duration: String) throws -> String {
        var duration = duration
        if let durationNumber = durationAliases[duration] {
            duration = durationNumber
        }
        guard durations[duration] != nil else {
            throw TablesError.invalidDuration(duration)
        }
        return duration
    }

    /// Non-throwing `sanitizeDuration`: returns "4" for an invalid duration.
    public static func sanitizeDuration(_ duration: String) -> String {
        (try? sanitizeDurationThrowing(duration)) ?? NoteValue.quarter.rawValue
    }

    /// Sanitize duration for typed APIs.
    public static func sanitizeDuration(_ duration: NoteValue) -> String {
        duration.rawValue
    }

    /// Convert the `duration` to a fraction.
    public static func durationToFractionThrowing(_ duration: String) throws -> Fraction {
        Fraction().parse(try sanitizeDurationThrowing(duration))
    }

    /// Convert the `duration` to a fraction.
    public static func durationToFraction(_ duration: String) -> Fraction {
        Fraction().parse(sanitizeDuration(duration))
    }

    public static func durationToFraction(_ duration: NoteValue) -> Fraction {
        Fraction().parse(duration.rawValue)
    }

    /// Convert the `duration` to a number.
    public static func durationToNumberThrowing(_ duration: String) throws -> Double {
        try durationToFractionThrowing(duration).value()
    }

    /// Convert the `duration` to a number.
    public static func durationToNumber(_ duration: String) -> Double {
        durationToFraction(duration).value()
    }

    public static func durationToNumber(_ duration: NoteValue) -> Double {
        durationToFraction(duration).value()
    }

    /// Convert the `duration` to total ticks. Throws for an invalid duration.
    public static func durationToTicksThrowing(_ duration: String) throws -> Int {
        let duration = try sanitizeDurationThrowing(duration)
        guard let ticks = durations[duration] else {
            throw TablesError.missingDurationTickMapping(duration)
        }
        return ticks
    }

    /// Convert the `duration` to total ticks. Returns nil for an invalid duration.
    public static func durationToTicks(_ duration: String) -> Int? {
        try? durationToTicksThrowing(duration)
    }

    /// Convert a strongly typed duration to ticks.
    public static func durationToTicksThrowing(_ duration: NoteValue) throws -> Int {
        try durationToTicksThrowing(duration.rawValue)
    }

    /// Convert a strongly typed duration to ticks.
    public static func durationToTicks(_ duration: NoteValue) -> Int {
        durations[duration.rawValue] ?? (RESOLUTION / 4)
    }

    // MARK: - Note Heads

    /// Get the notehead glyph code for a custom type and duration.
    public static func codeNoteHead(_ type: String, duration: NoteValue) -> String {
        codeNoteHead(type, duration: duration.rawValue)
    }

    /// Get the notehead glyph code for a custom type and duration.
    /// Returns `Glyphs.null` when there is no glyph (rest of an unknown duration).
    public static func codeNoteHead(_ type: String, duration: String) -> String {
        switch type {
        // Diamond
        case "D0": return Glyphs.noteheadDiamondWhole
        case "D1": return Glyphs.noteheadDiamondHalf
        case "D2": return Glyphs.noteheadDiamondBlack
        case "D3": return Glyphs.noteheadDiamondBlack

        // Triangle
        case "T0": return Glyphs.noteheadTriangleUpWhole
        case "T1": return Glyphs.noteheadTriangleUpHalf
        case "T2": return Glyphs.noteheadTriangleUpBlack
        case "T3": return Glyphs.noteheadTriangleUpBlack

        // Cross
        case "X0": return Glyphs.noteheadXWhole
        case "X1": return Glyphs.noteheadXHalf
        case "X2": return Glyphs.noteheadXBlack
        case "X3": return Glyphs.noteheadCircleX

        // Square
        case "S1": return Glyphs.noteheadSquareWhite
        case "S2": return Glyphs.noteheadSquareBlack

        // Rectangle
        case "R1": return Glyphs.noteheadSquareWhite // no smufl code
        case "R2": return Glyphs.noteheadSquareWhite // no smufl code

        case "DO": return Glyphs.noteheadTriangleUpBlack
        case "RE": return Glyphs.noteheadMoonBlack
        case "MI": return Glyphs.noteheadDiamondBlack
        case "FA": return Glyphs.noteheadTriangleLeftBlack
        case "FAUP": return Glyphs.noteheadTriangleRightBlack
        case "SO": return Glyphs.noteheadBlack
        case "LA": return Glyphs.noteheadSquareBlack
        case "TI": return Glyphs.noteheadTriangleRoundDownBlack

        case "DI", "H": // Diamond, Harmonics
            switch duration {
            case "1/2": return Glyphs.noteheadDiamondDoubleWhole
            case "1": return Glyphs.noteheadDiamondWhole
            case "2": return Glyphs.noteheadDiamondHalf
            default: return Glyphs.noteheadDiamondBlack
            }
        case "X", "M": // Muted
            switch duration {
            case "1/2": return Glyphs.noteheadXDoubleWhole
            case "1": return Glyphs.noteheadXWhole
            case "2": return Glyphs.noteheadXHalf
            default: return Glyphs.noteheadXBlack
            }
        case "CX":
            switch duration {
            case "1/2": return Glyphs.noteheadCircleXDoubleWhole
            case "1": return Glyphs.noteheadCircleXWhole
            case "2": return Glyphs.noteheadCircleXHalf
            default: return Glyphs.noteheadCircleX
            }
        case "CI":
            switch duration {
            case "1/2": return Glyphs.noteheadCircledDoubleWhole
            case "1": return Glyphs.noteheadCircledWhole
            case "2": return Glyphs.noteheadCircledHalf
            default: return Glyphs.noteheadCircledBlack
            }
        case "SQ":
            switch duration {
            case "1/2": return Glyphs.noteheadDoubleWholeSquare
            case "1": return Glyphs.noteheadSquareWhite
            case "2": return Glyphs.noteheadSquareWhite
            default: return Glyphs.noteheadSquareBlack
            }
        case "TU":
            switch duration {
            case "1/2": return Glyphs.noteheadTriangleUpDoubleWhole
            case "1": return Glyphs.noteheadTriangleUpWhole
            case "2": return Glyphs.noteheadTriangleUpHalf
            default: return Glyphs.noteheadTriangleUpBlack
            }
        case "TD":
            switch duration {
            case "1/2": return Glyphs.noteheadTriangleDownDoubleWhole
            case "1": return Glyphs.noteheadTriangleDownWhole
            case "2": return Glyphs.noteheadTriangleDownHalf
            default: return Glyphs.noteheadTriangleDownBlack
            }
        case "SF":
            switch duration {
            case "1/2": return Glyphs.noteheadSlashedDoubleWhole1
            case "1": return Glyphs.noteheadSlashedWhole1
            case "2": return Glyphs.noteheadSlashedHalf1
            default: return Glyphs.noteheadSlashedBlack1
            }
        case "SB":
            switch duration {
            case "1/2": return Glyphs.noteheadSlashedDoubleWhole2
            case "1": return Glyphs.noteheadSlashedWhole2
            case "2": return Glyphs.noteheadSlashedHalf2
            default: return Glyphs.noteheadSlashedBlack2
            }
        case "R":
            switch duration {
            case "1/2": return Glyphs.restDoubleWhole
            case "1": return Glyphs.restWhole
            case "2": return Glyphs.restHalf
            case "4": return Glyphs.restQuarter
            case "8": return Glyphs.rest8th
            case "16": return Glyphs.rest16th
            case "32": return Glyphs.rest32nd
            case "64": return Glyphs.rest64th
            case "128": return Glyphs.rest128th
            // 4.x-branch fix (a0c4d47a): 256th rest.
            case "256": return Glyphs.rest256th
            default: break
            }
        case "S":
            switch duration {
            case "1/2": return Glyphs.noteheadSlashWhiteDoubleWhole
            case "1": return Glyphs.noteheadSlashWhiteWhole
            case "2": return Glyphs.noteheadSlashWhiteHalf
            default: return Glyphs.noteheadSlashVerticalEnds
            }
        default:
            switch duration {
            case "1/2": return Glyphs.noteheadDoubleWhole
            case "1": return Glyphs.noteheadWhole
            case "2": return Glyphs.noteheadHalf
            default: return Glyphs.noteheadBlack
            }
        }
        return Glyphs.null
    }

    // MARK: - Tablature (VexFlowPatch)

    /// VexFlowPatch: the glyph for an `X` fret on a tab note.
    /// `useAlternativeXGlyph` selects a classical X notehead (`noteheadXBlack`)
    /// instead of upstream `accidentalDoubleSharp`. For `TabNote.tabToElement`.
    public static func tabXGlyphCode(useAlternativeXGlyph: Bool = false) -> String {
        useAlternativeXGlyph ? Glyphs.noteheadXBlack : Glyphs.accidentalDoubleSharp
    }

    // MARK: - Source compatibility

    /// Use `Note.getGlyphProps(_:_:)`.
    @available(*, deprecated, message: "Use Note.getGlyphProps(_:_:)")
    public static func getGlyphProps(duration: String, type: String = "n") -> GlyphProps? {
        Note.getGlyphProps(duration, type)
    }

    @available(*, deprecated, message: "Use Note.getGlyphProps(_:_:)")
    public static func getGlyphProps(duration: NoteValue, type: NoteType = .note) -> GlyphProps? {
        Note.getGlyphProps(duration.rawValue, type.rawValue)
    }
}
