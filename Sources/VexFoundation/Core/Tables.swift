// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Key Signature Entry

/// Defines a key signature by accidental type and count.
public struct KeySignatureSpec: Sendable {
    public var acc: String?
    public var num: Int
}

// MARK: - Accidental Code Entry

/// Maps an accidental type string to its SMuFL glyph code.
public struct AccidentalCode: Sendable {
    public var code: String
    public var parenRightPaddingAdjustment: Double
}

// MARK: - Glyph Properties

/// Properties for a note glyph at a given duration.
public struct GlyphProps: Sendable {
    public var codeHead: String
    public var stem: Bool
    public var flag: Bool
    public var rest: Bool
    public var position: String?
    public var dotShiftY: Double
    public var lineAbove: Double
    public var lineBelow: Double
    public var beamCount: Int
    public var codeFlagUpstem: String?
    public var codeFlagDownstem: String?
    public var stemUpExtension: Double
    public var stemDownExtension: Double
    public var stemBeamExtension: Double
    public var tabnoteStemUpExtension: Double
    public var tabnoteStemDownExtension: Double
}

/// Properties for a tab fret glyph (text or glyph code with dimensions).
public struct TabGlyphProps {
    public var text: String
    public var code: String?
    public var width: Double
    public var shiftY: Double
    public var scale: Double

    public func getWidth() -> Double { width * scale }
}

// MARK: - Key Properties

/// Properties for a note key (pitch/octave) on a staff.
public struct KeyProps {
    public var key: String
    public var octave: Int
    public var line: Double
    public var intValue: Int?
    public var accidental: String?
    public var code: String?
    public var stroke: Int
    public var shiftRight: Double
    public var displaced: Bool
    public var stemDownXOffset: Double = 0
    public var stemUpXOffset: Double = 0
}

public enum TablesError: Error, LocalizedError, Equatable, Sendable {
    case missingDurationTickMapping(String)
    case invalidClef(ClefName)
    case invalidDuration(String)
    case integerToNoteOutOfRange(Int)

    public var errorDescription: String? {
        switch self {
        case .missingDurationTickMapping(let duration):
            return "Missing tick mapping for duration \(duration)."
        case .invalidClef(let clef):
            return "Invalid clef: \(clef.rawValue)."
        case .invalidDuration(let duration):
            return "The provided duration is not valid: \(duration)."
        case .integerToNoteOutOfRange(let integer):
            return "integerToNote requires integer [0, 11]: \(integer)."
        }
    }
}

/// Central constants and lookup tables for VexFlow music notation.
public enum Tables {

    // MARK: - Rendering Constants

    /// Stem width in pixels.
    public static let STEM_WIDTH: Double = 1.5
    /// Default stem height in pixels.
    public static let STEM_HEIGHT: Double = 35
    /// Stave line thickness in pixels.
    public static let STAVE_LINE_THICKNESS: Double = 1
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
    /// Hack value for text height offset.
    public static let TEXT_HEIGHT_OFFSET_HACK: Double = 1
    /// Whether same-line unisons should share head placement when possible.
    public static var UNISON: Bool {
        get { VexRuntime.getCurrentContext().getUnisonEnabled() }
        set { VexRuntime.getCurrentContext().setUnisonEnabled(newValue) }
    }
    /// Softmax factor for formatter.
    public static let SOFTMAX_FACTOR: Double = 10

    // MARK: - Duration Tables

    /// Maps duration strings to tick counts.
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
        "b": "256",
    ]

    /// Convert a duration string to ticks.
    public static func durationToTicks(_ duration: String) -> Int? {
        guard let value = NoteValue(parsing: duration) else { return nil }
        return durationToTicks(value)
    }

    /// Convert a strongly typed duration to ticks.
    public static func durationToTicksThrowing(_ duration: NoteValue) throws -> Int {
        if let ticks = durations[duration.rawValue] {
            return ticks
        }
        if let ticks = computedTicks(for: duration.rawValue) {
            return ticks
        }
        throw TablesError.missingDurationTickMapping(duration.rawValue)
    }

    /// Convert a strongly typed duration to ticks.
    public static func durationToTicks(_ duration: NoteValue) -> Int {
        (try? durationToTicksThrowing(duration)) ?? (RESOLUTION / 4)
    }

    // MARK: - Key Signatures

    /// Key signature definitions: key name → accidental type + count.
    public static let keySignatures: [String: KeySignatureSpec] = [
        "C": KeySignatureSpec(num: 0),
        "Am": KeySignatureSpec(num: 0),
        "F": KeySignatureSpec(acc: "b", num: 1),
        "Dm": KeySignatureSpec(acc: "b", num: 1),
        "Bb": KeySignatureSpec(acc: "b", num: 2),
        "Gm": KeySignatureSpec(acc: "b", num: 2),
        "Eb": KeySignatureSpec(acc: "b", num: 3),
        "Cm": KeySignatureSpec(acc: "b", num: 3),
        "Ab": KeySignatureSpec(acc: "b", num: 4),
        "Fm": KeySignatureSpec(acc: "b", num: 4),
        "Db": KeySignatureSpec(acc: "b", num: 5),
        "Bbm": KeySignatureSpec(acc: "b", num: 5),
        "Gb": KeySignatureSpec(acc: "b", num: 6),
        "Ebm": KeySignatureSpec(acc: "b", num: 6),
        "Cb": KeySignatureSpec(acc: "b", num: 7),
        "Abm": KeySignatureSpec(acc: "b", num: 7),
        "G": KeySignatureSpec(acc: "#", num: 1),
        "Em": KeySignatureSpec(acc: "#", num: 1),
        "D": KeySignatureSpec(acc: "#", num: 2),
        "Bm": KeySignatureSpec(acc: "#", num: 2),
        "A": KeySignatureSpec(acc: "#", num: 3),
        "F#m": KeySignatureSpec(acc: "#", num: 3),
        "E": KeySignatureSpec(acc: "#", num: 4),
        "C#m": KeySignatureSpec(acc: "#", num: 4),
        "B": KeySignatureSpec(acc: "#", num: 5),
        "G#m": KeySignatureSpec(acc: "#", num: 5),
        "F#": KeySignatureSpec(acc: "#", num: 6),
        "D#m": KeySignatureSpec(acc: "#", num: 6),
        "C#": KeySignatureSpec(acc: "#", num: 7),
        "A#m": KeySignatureSpec(acc: "#", num: 7),
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
        guard let acc = keySpec.acc, keySpec.num > 0 else {
            return []
        }
        let positions = acc == "b" ? flatPositions : sharpPositions
        var result: [(type: String, line: Double)] = []
        for i in 0..<keySpec.num {
            result.append((type: acc, line: positions[i]))
        }
        return result
    }

    /// Check if a key signature spec is valid.
    public static func hasKeySignature(_ spec: String) -> Bool {
        keySignatures[spec] != nil
    }

    // MARK: - Accidental Codes

    /// Maps accidental type strings to their glyph codes.
    public static let accidentalCodes: [String: AccidentalCode] = [
        "#": AccidentalCode(code: "accidentalSharp", parenRightPaddingAdjustment: -1),
        "##": AccidentalCode(code: "accidentalDoubleSharp", parenRightPaddingAdjustment: -1),
        "b": AccidentalCode(code: "accidentalFlat", parenRightPaddingAdjustment: -2),
        "bb": AccidentalCode(code: "accidentalDoubleFlat", parenRightPaddingAdjustment: -2),
        "n": AccidentalCode(code: "accidentalNatural", parenRightPaddingAdjustment: -1),
        "{": AccidentalCode(code: "accidentalParensLeft", parenRightPaddingAdjustment: -1),
        "}": AccidentalCode(code: "accidentalParensRight", parenRightPaddingAdjustment: -1),
        "db": AccidentalCode(code: "accidentalThreeQuarterTonesFlatZimmermann", parenRightPaddingAdjustment: -1),
        "d": AccidentalCode(code: "accidentalQuarterToneFlatStein", parenRightPaddingAdjustment: 0),
        "++": AccidentalCode(code: "accidentalThreeQuarterTonesSharpStein", parenRightPaddingAdjustment: -1),
        "+": AccidentalCode(code: "accidentalQuarterToneSharpStein", parenRightPaddingAdjustment: -1),
        "+-": AccidentalCode(code: "accidentalKucukMucennebSharp", parenRightPaddingAdjustment: -1),
        "bs": AccidentalCode(code: "accidentalBakiyeFlat", parenRightPaddingAdjustment: -1),
        "bss": AccidentalCode(code: "accidentalBuyukMucennebFlat", parenRightPaddingAdjustment: -1),
        "o": AccidentalCode(code: "accidentalSori", parenRightPaddingAdjustment: -1),
        "k": AccidentalCode(code: "accidentalKoron", parenRightPaddingAdjustment: -1),
        "bbs": AccidentalCode(code: "vexAccidentalMicrotonal1", parenRightPaddingAdjustment: -1),
        "++-": AccidentalCode(code: "accidentalBuyukMucennebSharp", parenRightPaddingAdjustment: -1),
        "ashs": AccidentalCode(code: "vexAccidentalMicrotonal3", parenRightPaddingAdjustment: -1),
        "afhf": AccidentalCode(code: "vexAccidentalMicrotonal4", parenRightPaddingAdjustment: -1),
    ]

    /// Look up an accidental's glyph code.
    public static func accidentalCode(_ acc: String) -> AccidentalCode? {
        accidentalCodes[acc]
    }

    // MARK: - Accidental Columns Table

    /// Pre-computed column layouts for groups of 1-6 accidentals.
    /// Columns represent horizontal positions (1 = closest to note).
    public static let accidentalColumnsTable: [Int: [String: [Int]]] = [
        1: ["a": [1], "b": [1]],
        2: ["a": [1, 2]],
        3: [
            "a": [1, 3, 2],
            "b": [1, 2, 1],
            "second_on_bottom": [1, 2, 3],
        ],
        4: [
            "a": [1, 3, 4, 2],
            "b": [1, 2, 3, 1],
            "spaced_out_tetrachord": [1, 2, 1, 2],
        ],
        5: [
            "a": [1, 3, 5, 4, 2],
            "b": [1, 2, 4, 3, 1],
            "spaced_out_pentachord": [1, 2, 3, 2, 1],
            "very_spaced_out_pentachord": [1, 2, 1, 2, 1],
        ],
        6: [
            "a": [1, 3, 5, 6, 4, 2],
            "b": [1, 2, 4, 5, 3, 1],
            "spaced_out_hexachord": [1, 3, 2, 1, 3, 2],
            "very_spaced_out_hexachord": [1, 2, 1, 2, 1, 2],
        ],
    ]

    // MARK: - Articulation Codes

    /// Defines an articulation glyph with optional above/below variants.
    public struct ArticulationStruct: Sendable {
        public var code: String?
        public var aboveCode: String?
        public var belowCode: String?
        public var betweenLines: Bool
    }

    /// Maps articulation type strings to their glyph codes.
    public static let articulationCodes: [String: ArticulationStruct] = [
        "a.": ArticulationStruct(code: "augmentationDot", betweenLines: true),
        "av": ArticulationStruct(aboveCode: "articStaccatissimoAbove", belowCode: "articStaccatissimoBelow", betweenLines: true),
        "a>": ArticulationStruct(aboveCode: "articAccentAbove", belowCode: "articAccentBelow", betweenLines: true),
        "a-": ArticulationStruct(aboveCode: "articTenutoAbove", belowCode: "articTenutoBelow", betweenLines: true),
        "a^": ArticulationStruct(aboveCode: "articMarcatoAbove", belowCode: "articMarcatoBelow", betweenLines: false),
        "a+": ArticulationStruct(code: "pluckedLeftHandPizzicato", betweenLines: false),
        "ao": ArticulationStruct(aboveCode: "pluckedSnapPizzicatoAbove", belowCode: "pluckedSnapPizzicatoBelow", betweenLines: false),
        "ah": ArticulationStruct(code: "stringsHarmonic", betweenLines: false),
        "a@": ArticulationStruct(aboveCode: "fermataAbove", belowCode: "fermataBelow", betweenLines: false),
        "a@a": ArticulationStruct(code: "fermataAbove", betweenLines: false),
        "a@u": ArticulationStruct(code: "fermataBelow", betweenLines: false),
        "a@s": ArticulationStruct(aboveCode: "fermataShortAbove", belowCode: "fermataShortBelow", betweenLines: false),
        "a@as": ArticulationStruct(code: "fermataShortAbove", betweenLines: false),
        "a@us": ArticulationStruct(code: "fermataShortBelow", betweenLines: false),
        "a@l": ArticulationStruct(aboveCode: "fermataLongAbove", belowCode: "fermataLongBelow", betweenLines: false),
        "a@al": ArticulationStruct(code: "fermataLongAbove", betweenLines: false),
        "a@ul": ArticulationStruct(code: "fermataLongBelow", betweenLines: false),
        "a@vl": ArticulationStruct(aboveCode: "fermataVeryLongAbove", belowCode: "fermataVeryLongBelow", betweenLines: false),
        "a@avl": ArticulationStruct(code: "fermataVeryLongAbove", betweenLines: false),
        "a@uvl": ArticulationStruct(code: "fermataVeryLongBelow", betweenLines: false),
        "a|": ArticulationStruct(code: "stringsUpBow", betweenLines: false),
        "am": ArticulationStruct(code: "stringsDownBow", betweenLines: false),
        "a,": ArticulationStruct(code: "pictChokeCymbal", betweenLines: false),
    ]

    /// Look up an articulation's glyph data.
    public static func articulationCode(_ type: String) -> ArticulationStruct? {
        articulationCodes[type]
    }

    // MARK: - Ornament Codes

    public static let ornamentCodes: [String: String] = [
        "mordent": "ornamentShortTrill",
        "mordent_inverted": "ornamentMordent",
        "turn": "ornamentTurn",
        "turn_inverted": "ornamentTurnSlash",
        "tr": "ornamentTrill",
        "upprall": "ornamentPrecompSlideTrillDAnglebert",
        "downprall": "ornamentPrecompDoubleCadenceUpperPrefix",
        "prallup": "ornamentPrecompTrillSuffixDandrieu",
        "pralldown": "ornamentPrecompTrillLowerSuffix",
        "upmordent": "ornamentPrecompSlideTrillBach",
        "downmordent": "ornamentPrecompDoubleCadenceUpperPrefixTurn",
        "lineprall": "ornamentPrecompAppoggTrill",
        "prallprall": "ornamentTremblement",
        "scoop": "brassScoop",
        "doit": "brassDoitMedium",
        "fall": "brassFallLipShort",
        "doitLong": "brassLiftMedium",
        "fallLong": "brassFallRoughMedium",
        "bend": "brassBend",
        "plungerClosed": "brassMuteClosed",
        "plungerOpen": "brassMuteOpen",
        "flip": "brassFlip",
        "jazzTurn": "brassJazzTurn",
        "smear": "brassSmear",
    ]

    public static func ornamentCode(_ type: String) -> String? {
        ornamentCodes[type]
    }

    // MARK: - Clef Data

    /// Clef vertical line shifts for key signature positioning.
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

    // MARK: - Duration Codes (Glyph Properties)

    /// Get glyph properties for a given duration and type.
    public static func getGlyphProps(duration: NoteValue, type: NoteType = .note) -> GlyphProps? {
        getGlyphProps(duration: duration.rawValue, type: type.rawValue)
    }

    /// Get glyph properties for a given duration and type.
    public static func getGlyphProps(duration: String, type: String = "n") -> GlyphProps? {
        guard let noteValue = NoteValue(parsing: duration) else { return nil }
        let dur = noteValue.rawValue
        guard let common = durationCodes[dur] else { return nil }
        let typeProps = durationTypeOverrides[dur]?[type]
        let isSlash = type == NoteType.slash.rawValue

        // Resolve codeHead: try custom note head lookup first, then type override, then common
        var codeHead = typeProps?.codeHead ?? common.codeHead
        let noteHeadCode = codeNoteHead(type.uppercased(), duration: dur)
        if !noteHeadCode.isEmpty {
            codeHead = noteHeadCode
        }

        return GlyphProps(
            codeHead: codeHead,
            stem: typeProps?.stem ?? common.stem,
            flag: typeProps?.flag ?? common.flag,
            rest: typeProps?.rest ?? false,
            position: isSlash ? (typeProps?.position ?? "B/4") : (typeProps?.position ?? common.position),
            dotShiftY: typeProps?.dotShiftY ?? common.dotShiftY,
            lineAbove: typeProps?.lineAbove ?? common.lineAbove,
            lineBelow: typeProps?.lineBelow ?? common.lineBelow,
            beamCount: common.beamCount,
            codeFlagUpstem: common.codeFlagUpstem,
            codeFlagDownstem: common.codeFlagDownstem,
            stemUpExtension: common.stemUpExtension,
            stemDownExtension: common.stemDownExtension,
            stemBeamExtension: common.stemBeamExtension,
            tabnoteStemUpExtension: common.tabnoteStemUpExtension,
            tabnoteStemDownExtension: common.tabnoteStemDownExtension
        )
    }

    /// Common properties per duration.
    private static let durationCodes: [String: GlyphProps] = [
        "1/2": GlyphProps(codeHead: "", stem: false, flag: false, rest: false, dotShiftY: 0,
                          lineAbove: 0, lineBelow: 0, beamCount: 0, stemUpExtension: -STEM_HEIGHT,
                          stemDownExtension: -STEM_HEIGHT, stemBeamExtension: 0,
                          tabnoteStemUpExtension: -STEM_HEIGHT, tabnoteStemDownExtension: -STEM_HEIGHT),
        "1": GlyphProps(codeHead: "", stem: false, flag: false, rest: false, dotShiftY: 0,
                        lineAbove: 0, lineBelow: 0, beamCount: 0, stemUpExtension: -STEM_HEIGHT,
                        stemDownExtension: -STEM_HEIGHT, stemBeamExtension: 0,
                        tabnoteStemUpExtension: -STEM_HEIGHT, tabnoteStemDownExtension: -STEM_HEIGHT),
        "2": GlyphProps(codeHead: "", stem: true, flag: false, rest: false, dotShiftY: 0,
                        lineAbove: 0, lineBelow: 0, beamCount: 0, stemUpExtension: 0,
                        stemDownExtension: 0, stemBeamExtension: 0,
                        tabnoteStemUpExtension: 0, tabnoteStemDownExtension: 0),
        "4": GlyphProps(codeHead: "", stem: true, flag: false, rest: false, dotShiftY: 0,
                        lineAbove: 0, lineBelow: 0, beamCount: 0, stemUpExtension: 0,
                        stemDownExtension: 0, stemBeamExtension: 0,
                        tabnoteStemUpExtension: 0, tabnoteStemDownExtension: 0),
        "8": GlyphProps(codeHead: "", stem: true, flag: true, rest: false, dotShiftY: 0,
                        lineAbove: 0, lineBelow: 0, beamCount: 1,
                        codeFlagUpstem: "flag8thUp", codeFlagDownstem: "flag8thDown",
                        stemUpExtension: 0, stemDownExtension: 0, stemBeamExtension: 0,
                        tabnoteStemUpExtension: 0, tabnoteStemDownExtension: 0),
        "16": GlyphProps(codeHead: "", stem: true, flag: true, rest: false, dotShiftY: 0,
                         lineAbove: 0, lineBelow: 0, beamCount: 2,
                         codeFlagUpstem: "flag16thUp", codeFlagDownstem: "flag16thDown",
                         stemUpExtension: 0, stemDownExtension: 0, stemBeamExtension: 0,
                         tabnoteStemUpExtension: 0, tabnoteStemDownExtension: 0),
        "32": GlyphProps(codeHead: "", stem: true, flag: true, rest: false, dotShiftY: 0,
                         lineAbove: 0, lineBelow: 0, beamCount: 3,
                         codeFlagUpstem: "flag32ndUp", codeFlagDownstem: "flag32ndDown",
                         stemUpExtension: 9, stemDownExtension: 9, stemBeamExtension: 7.5,
                         tabnoteStemUpExtension: 9, tabnoteStemDownExtension: 9),
        "64": GlyphProps(codeHead: "", stem: true, flag: true, rest: false, dotShiftY: 0,
                         lineAbove: 0, lineBelow: 0, beamCount: 4,
                         codeFlagUpstem: "flag64thUp", codeFlagDownstem: "flag64thDown",
                         stemUpExtension: 13, stemDownExtension: 13, stemBeamExtension: 15,
                         tabnoteStemUpExtension: 13, tabnoteStemDownExtension: 13),
        "128": GlyphProps(codeHead: "", stem: true, flag: true, rest: false, dotShiftY: 0,
                          lineAbove: 0, lineBelow: 0, beamCount: 5,
                          codeFlagUpstem: "flag128thUp", codeFlagDownstem: "flag128thDown",
                          stemUpExtension: 22, stemDownExtension: 22, stemBeamExtension: 22.5,
                          tabnoteStemUpExtension: 22, tabnoteStemDownExtension: 22),
        "256": GlyphProps(codeHead: "", stem: true, flag: true, rest: false, dotShiftY: 0,
                          lineAbove: 0, lineBelow: 0, beamCount: 6,
                          codeFlagUpstem: "flag256thUp", codeFlagDownstem: "flag256thDown",
                          stemUpExtension: 24, stemDownExtension: 24, stemBeamExtension: 25,
                          tabnoteStemUpExtension: 24, tabnoteStemDownExtension: 24),
    ]

    // MARK: - Tab Glyph Properties

    /// Get glyph properties for a tab fret number/symbol.
    public static func tabToGlyphProps(_ fret: String, scale: Double = 1.0) -> TabGlyphProps {
        if fret.uppercased() == "X" {
            let metrics = Glyph(code: "accidentalDoubleSharp", point: TABLATURE_FONT_SCALE).getMetrics()
            return TabGlyphProps(text: fret, code: "accidentalDoubleSharp",
                                 width: metrics.width, shiftY: -metrics.height / 2, scale: scale)
        } else {
            let width = textWidth(fret)
            return TabGlyphProps(text: fret, code: nil, width: width, shiftY: 0, scale: scale)
        }
    }

    /// Approximate text width for a string (font-independent estimate).
    public static func textWidth(_ text: String) -> Double {
        7 * Double(text.count)
    }

    // MARK: - Note Info

    /// Properties for a note name (used by keyProperties).
    private struct NoteInfo {
        var index: Int
        var intVal: Int?
        var accidental: String?
        var rest: Bool
        var octave: Int?
        var code: String?
        var shiftRight: Double?
    }

    /// Note name → pitch index, integer value, and accidental.
    private static let notesInfo: [String: NoteInfo] = [
        "C": NoteInfo(index: 0, intVal: 0, rest: false),
        "CN": NoteInfo(index: 0, intVal: 0, accidental: "n", rest: false),
        "C#": NoteInfo(index: 0, intVal: 1, accidental: "#", rest: false),
        "C##": NoteInfo(index: 0, intVal: 2, accidental: "##", rest: false),
        "CB": NoteInfo(index: 0, intVal: 11, accidental: "b", rest: false),
        "CBB": NoteInfo(index: 0, intVal: 10, accidental: "bb", rest: false),
        "D": NoteInfo(index: 1, intVal: 2, rest: false),
        "DN": NoteInfo(index: 1, intVal: 2, accidental: "n", rest: false),
        "D#": NoteInfo(index: 1, intVal: 3, accidental: "#", rest: false),
        "D##": NoteInfo(index: 1, intVal: 4, accidental: "##", rest: false),
        "DB": NoteInfo(index: 1, intVal: 1, accidental: "b", rest: false),
        "DBB": NoteInfo(index: 1, intVal: 0, accidental: "bb", rest: false),
        "E": NoteInfo(index: 2, intVal: 4, rest: false),
        "EN": NoteInfo(index: 2, intVal: 4, accidental: "n", rest: false),
        "E#": NoteInfo(index: 2, intVal: 5, accidental: "#", rest: false),
        "E##": NoteInfo(index: 2, intVal: 6, accidental: "##", rest: false),
        "EB": NoteInfo(index: 2, intVal: 3, accidental: "b", rest: false),
        "EBB": NoteInfo(index: 2, intVal: 2, accidental: "bb", rest: false),
        "F": NoteInfo(index: 3, intVal: 5, rest: false),
        "FN": NoteInfo(index: 3, intVal: 5, accidental: "n", rest: false),
        "F#": NoteInfo(index: 3, intVal: 6, accidental: "#", rest: false),
        "F##": NoteInfo(index: 3, intVal: 7, accidental: "##", rest: false),
        "FB": NoteInfo(index: 3, intVal: 4, accidental: "b", rest: false),
        "FBB": NoteInfo(index: 3, intVal: 3, accidental: "bb", rest: false),
        "G": NoteInfo(index: 4, intVal: 7, rest: false),
        "GN": NoteInfo(index: 4, intVal: 7, accidental: "n", rest: false),
        "G#": NoteInfo(index: 4, intVal: 8, accidental: "#", rest: false),
        "G##": NoteInfo(index: 4, intVal: 9, accidental: "##", rest: false),
        "GB": NoteInfo(index: 4, intVal: 6, accidental: "b", rest: false),
        "GBB": NoteInfo(index: 4, intVal: 5, accidental: "bb", rest: false),
        "A": NoteInfo(index: 5, intVal: 9, rest: false),
        "AN": NoteInfo(index: 5, intVal: 9, accidental: "n", rest: false),
        "A#": NoteInfo(index: 5, intVal: 10, accidental: "#", rest: false),
        "A##": NoteInfo(index: 5, intVal: 11, accidental: "##", rest: false),
        "AB": NoteInfo(index: 5, intVal: 8, accidental: "b", rest: false),
        "ABB": NoteInfo(index: 5, intVal: 7, accidental: "bb", rest: false),
        "B": NoteInfo(index: 6, intVal: 11, rest: false),
        "BN": NoteInfo(index: 6, intVal: 11, accidental: "n", rest: false),
        "B#": NoteInfo(index: 6, intVal: 12, accidental: "#", rest: false),
        "B##": NoteInfo(index: 6, intVal: 13, accidental: "##", rest: false),
        "BB": NoteInfo(index: 6, intVal: 10, accidental: "b", rest: false),
        "BBB": NoteInfo(index: 6, intVal: 9, accidental: "bb", rest: false),
        "R": NoteInfo(index: 6, rest: true),
        "X": NoteInfo(index: 6, accidental: "", rest: false, octave: 4,
                      code: "noteheadXBlack", shiftRight: 5.5),
    ]

    /// Valid note types used during note struct parsing.
    public static let validTypes: [String: String] = [
        "n": "note", "r": "rest", "h": "harmonic", "m": "muted",
        "s": "slash", "g": "ghost", "d": "diamond", "x": "x",
        "ci": "circled", "cx": "circle x", "sf": "slashed",
        "sb": "slashed backward", "sq": "square",
        "tu": "triangle up", "td": "triangle down",
    ]

    /// Clef line shift for note line calculation.
    /// Get clef properties (line_shift).
    public static func clefPropertiesThrowing(_ clef: ClefName) throws -> Int {
        guard let shift = clefLineShifts[clef] else {
            throw TablesError.invalidClef(clef)
        }
        return shift
    }

    /// Clef line shift for note line calculation.
    /// Get clef properties (line_shift).
    public static func clefProperties(_ clef: ClefName) -> Int {
        (try? clefPropertiesThrowing(clef)) ?? 0
    }

    /// Sanitize duration: resolve aliases and validate.
    public static func sanitizeDurationThrowing(_ duration: String) throws -> String {
        guard let value = NoteValue(parsing: duration) else {
            throw TablesError.invalidDuration(duration)
        }
        return value.rawValue
    }

    /// Sanitize duration: resolve aliases and validate.
    public static func sanitizeDuration(_ duration: String) -> String {
        (try? sanitizeDurationThrowing(duration)) ?? NoteValue.quarter.rawValue
    }

    /// Sanitize duration for typed APIs.
    public static func sanitizeDuration(_ duration: NoteValue) -> String {
        duration.rawValue
    }

    /// Convert duration to a Fraction.
    public static func durationToFractionThrowing(_ duration: String) throws -> Fraction {
        Fraction().parse(try sanitizeDurationThrowing(duration))
    }

    /// Convert duration to a Fraction.
    public static func durationToFraction(_ duration: String) -> Fraction {
        Fraction().parse(sanitizeDuration(duration))
    }

    /// Convert duration to a Fraction.
    public static func durationToFraction(_ duration: NoteValue) -> Fraction {
        Fraction().parse(duration.rawValue)
    }

    /// Convert duration to a number.
    public static func durationToNumberThrowing(_ duration: String) throws -> Double {
        try durationToFractionThrowing(duration).value()
    }

    /// Convert duration to a number.
    public static func durationToNumber(_ duration: String) -> Double {
        durationToFraction(duration).value()
    }

    /// Convert duration to a number.
    public static func durationToNumber(_ duration: NoteValue) -> Double {
        durationToFraction(duration).value()
    }

    /// Get properties for a key/octave string (e.g., "c/4", "g/5/x2").
    public static func keyProperties(
        _ key: StaffKeySpec,
        clef: ClefName = .treble,
        octaveShift: Int = 0,
        duration: NoteValue = .quarter
    ) throws -> KeyProps {
        try keyProperties(
            key.rawValue,
            clef: clef,
            octaveShift: octaveShift,
            duration: duration.rawValue
        )
    }

    /// Get properties for a key/octave string (e.g., "c/4", "g/5/x2").
    public static func keyProperties(
        _ keyOctaveGlyph: String,
        clef: ClefName = .treble,
        octaveShift: Int = 0,
        duration: String = NoteValue.quarter.rawValue
    ) throws -> KeyProps {
        let pieces = keyOctaveGlyph.split(separator: "/").map(String.init)
        guard pieces.count >= 2 else {
            throw VexError("BadArguments",
                "First argument must be note/octave or note/octave/glyph-code: \(keyOctaveGlyph)")
        }

        let key = pieces[0].uppercased()
        guard let value = notesInfo[key] else {
            throw VexError("BadArguments", "Invalid key name: \(key)")
        }

        var octaveStr = pieces[1]
        if let noteOctave = value.octave {
            octaveStr = String(noteOctave)
        }
        var octave = Int(octaveStr) ?? 4
        octave -= octaveShift

        let baseIndex = octave * 7 - 4 * 7
        var line = Double(baseIndex + value.index) / 2.0
        line += Double(try clefPropertiesThrowing(clef))

        var stroke = 0
        if line <= 0 && Int(line * 2) % 2 == 0 { stroke = 1 }
        if line >= 6 && Int(line * 2) % 2 == 0 { stroke = -1 }

        let intValue: Int? = value.intVal != nil ? octave * 12 + value.intVal! : nil

        var code = value.code
        if pieces.count > 2 && !pieces[2].isEmpty {
            code = codeNoteHead(pieces[2].uppercased(), duration: duration)
        }

        return KeyProps(
            key: key, octave: octave, line: line,
            intValue: intValue, accidental: value.accidental,
            code: code, stroke: stroke,
            shiftRight: value.shiftRight ?? 0, displaced: false
        )
    }

    /// Convert an integer (0-11) to a note name.
    public static func integerToNoteThrowing(_ integer: Int) throws -> String {
        let table: [Int: String] = [
            0: "C", 1: "C#", 2: "D", 3: "D#", 4: "E", 5: "F",
            6: "F#", 7: "G", 8: "G#", 9: "A", 10: "A#", 11: "B",
        ]
        guard integer >= 0 && integer <= 11, let note = table[integer] else {
            throw TablesError.integerToNoteOutOfRange(integer)
        }
        return note
    }

    /// Convert an integer (0-11) to a note name.
    public static func integerToNote(_ integer: Int) -> String {
        (try? integerToNoteThrowing(integer)) ?? "C"
    }

    private static func computedTicks(for duration: String) -> Int? {
        let parts = duration.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 1, let denominator = Int(parts[0]), denominator > 0 {
            return RESOLUTION / denominator
        }
        guard
            parts.count == 2,
            let numerator = Int(parts[0]),
            let denominator = Int(parts[1]),
            numerator > 0,
            denominator > 0
        else {
            return nil
        }
        return (RESOLUTION * denominator) / numerator
    }

    /// Get the notehead glyph code for a custom type and duration.
    public static func codeNoteHead(_ type: String, duration: NoteValue) -> String {
        codeNoteHead(type, duration: duration.rawValue)
    }

    /// Get the notehead glyph code for a custom type and duration.
    public static func codeNoteHead(_ type: String, duration: String) -> String {
        switch type {
        case "D0": return "noteheadDiamondWhole"
        case "D1": return "noteheadDiamondHalf"
        case "D2", "D3": return "noteheadDiamondBlack"
        case "T0": return "noteheadTriangleUpWhole"
        case "T1": return "noteheadTriangleUpHalf"
        case "T2", "T3": return "noteheadTriangleUpBlack"
        case "X0": return "noteheadXWhole"
        case "X1": return "noteheadXHalf"
        case "X2": return "noteheadXBlack"
        case "X3": return "noteheadCircleX"
        case "S1": return "noteheadSquareWhite"
        case "S2": return "noteheadSquareBlack"
        case "R1": return "vexNoteHeadRectWhite"
        case "R2": return "vexNoteHeadRectBlack"
        case "DO": return "noteheadTriangleUpBlack"
        case "RE": return "noteheadMoonBlack"
        case "MI": return "noteheadDiamondBlack"
        case "FA": return "noteheadTriangleLeftBlack"
        case "FAUP": return "noteheadTriangleRightBlack"
        case "SO": return "noteheadBlack"
        case "LA": return "noteheadSquareBlack"
        case "TI": return "noteheadTriangleRoundDownBlack"
        case "D", "H":
            switch duration {
            case "1/2": return "noteheadDiamondDoubleWhole"
            case "1": return "noteheadDiamondWhole"
            case "2": return "noteheadDiamondHalf"
            default: return "noteheadDiamondBlack"
            }
        case "N", "G":
            switch duration {
            case "1/2": return "noteheadDoubleWhole"
            case "1": return "noteheadWhole"
            case "2": return "noteheadHalf"
            default: return "noteheadBlack"
            }
        case "M", "X":
            switch duration {
            case "1/2": return "noteheadXDoubleWhole"
            case "1": return "noteheadXWhole"
            case "2": return "noteheadXHalf"
            default: return "noteheadXBlack"
            }
        case "CX":
            switch duration {
            case "1/2": return "noteheadCircleXDoubleWhole"
            case "1": return "noteheadCircleXWhole"
            case "2": return "noteheadCircleXHalf"
            default: return "noteheadCircleX"
            }
        case "CI":
            switch duration {
            case "1/2": return "noteheadCircledDoubleWhole"
            case "1": return "noteheadCircledWhole"
            case "2": return "noteheadCircledHalf"
            default: return "noteheadCircledBlack"
            }
        case "SQ":
            switch duration {
            case "1/2": return "noteheadDoubleWholeSquare"
            case "1", "2": return "noteheadSquareWhite"
            default: return "noteheadSquareBlack"
            }
        case "TU":
            switch duration {
            case "1/2": return "noteheadTriangleUpDoubleWhole"
            case "1": return "noteheadTriangleUpWhole"
            case "2": return "noteheadTriangleUpHalf"
            default: return "noteheadTriangleUpBlack"
            }
        case "TD":
            switch duration {
            case "1/2": return "noteheadTriangleDownDoubleWhole"
            case "1": return "noteheadTriangleDownWhole"
            case "2": return "noteheadTriangleDownHalf"
            default: return "noteheadTriangleDownBlack"
            }
        case "SF":
            switch duration {
            case "1/2": return "noteheadSlashedDoubleWhole1"
            case "1": return "noteheadSlashedWhole1"
            case "2": return "noteheadSlashedHalf1"
            default: return "noteheadSlashedBlack1"
            }
        case "SB":
            switch duration {
            case "1/2": return "noteheadSlashedDoubleWhole2"
            case "1": return "noteheadSlashedWhole2"
            case "2": return "noteheadSlashedHalf2"
            default: return "noteheadSlashedBlack2"
            }
        default: return ""
        }
    }

    /// Per-type overrides (rest, slash, etc.).
    private struct TypeOverride: Sendable {
        var codeHead: String?
        var stem: Bool?
        var flag: Bool?
        var rest: Bool?
        var position: String?
        var dotShiftY: Double?
        var lineAbove: Double?
        var lineBelow: Double?
    }

    private static let durationTypeOverrides: [String: [String: TypeOverride]] = [
        "1/2": [
            "r": TypeOverride(codeHead: "restDoubleWhole", rest: true, position: "B/5", dotShiftY: 0),
        ],
        "1": [
            "r": TypeOverride(codeHead: "restWhole", rest: true, position: "D/5", dotShiftY: 0.5),
        ],
        "2": [
            "r": TypeOverride(codeHead: "restHalf", stem: false, rest: true, position: "B/4", dotShiftY: -0.5),
        ],
        "4": [
            "r": TypeOverride(codeHead: "restQuarter", stem: false, rest: true, position: "B/4",
                              dotShiftY: -0.5, lineAbove: 1.5, lineBelow: 1.5),
        ],
        "8": [
            "r": TypeOverride(codeHead: "rest8th", stem: false, flag: false, rest: true, position: "B/4",
                              dotShiftY: -0.5, lineAbove: 1.0, lineBelow: 1.0),
        ],
        "16": [
            "r": TypeOverride(codeHead: "rest16th", stem: false, flag: false, rest: true, position: "B/4",
                              dotShiftY: -0.5, lineAbove: 1.0, lineBelow: 2.0),
        ],
        "32": [
            "r": TypeOverride(codeHead: "rest32nd", stem: false, flag: false, rest: true, position: "B/4",
                              dotShiftY: -1.5, lineAbove: 2.0, lineBelow: 2.0),
        ],
        "64": [
            "r": TypeOverride(codeHead: "rest64th", stem: false, flag: false, rest: true, position: "B/4",
                              dotShiftY: -1.5, lineAbove: 2.0, lineBelow: 3.0),
        ],
        "128": [
            "r": TypeOverride(codeHead: "rest128th", stem: false, flag: false, rest: true, position: "B/4",
                              dotShiftY: -2.5, lineAbove: 3.0, lineBelow: 3.0),
        ],
        "256": [
            "r": TypeOverride(codeHead: "rest256th", stem: false, flag: false, rest: true, position: "B/4",
                              dotShiftY: -2.5, lineAbove: 3.0, lineBelow: 3.0),
        ],
    ]
}
