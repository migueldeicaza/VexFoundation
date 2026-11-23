// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Mohit Cheppudira
// @author Greg Ristow (modifications)
//
// Port of `src/accidental.ts` (VexFlow 5.8.0) and `src/automaticaccidentals.ts` (VexFlow 5.8.0).

import Foundation

public enum AccidentalError: Error, LocalizedError, Equatable, Sendable {
    case missingTableMapping(String)

    public var errorDescription: String? {
        switch self {
        case .missingTableMapping(let type):
            return "Missing accidental table mapping for type: \(type)"
        }
    }
}

// MARK: - Accidental Layout Metrics

/// Metrics for accidental layout on a single stave line.
struct AccidentalLineMetrics {
    var column: Int = 0
    var line: Double
    /// A flat line needs more clearance above than below. This is
    /// set to true if the accidental is either a flat or double flat.
    var flatLine: Bool
    /// Double sharps need less clearance above and below than other
    /// accidentals.
    var dblSharpLine: Bool
    var numAcc: Int
    var width: Double
}

// MARK: - Accidental Type

/// Typed accidental kinds supported by the core notation tables.
public enum AccidentalType: String, CaseIterable, Sendable, Codable {
    case sharp = "#"
    case doubleSharp = "##"
    case flat = "b"
    case doubleFlat = "bb"
    case natural = "n"
    case parenLeft = "{"
    case parenRight = "}"
    case threeQuarterFlat = "db"
    case quarterFlat = "d"
    case threeQuarterSharp = "++"
    case quarterSharp = "+"
    case kucukMucennebSharp = "+-"
    case bakiyeFlat = "bs"
    case buyukMucennebFlat = "bss"
    case sori = "o"
    case koron = "k"
    case microtonalOne = "bbs"
    case buyukMucennebSharp = "++-"
    case microtonalThree = "ashs"
    case microtonalFour = "afhf"

    /// Parse from a string token.
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.init(rawValue: normalized)
    }
}

/// Errors for string accidental parsing.
public enum AccidentalParseError: Error, LocalizedError, Sendable {
    case invalidType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidType(let value):
            return "Unknown accidental type: '\(value)'."
        }
    }
}

/// Errors for automatic accidental application.
public enum AccidentalApplyError: Error, LocalizedError, Equatable, Sendable {
    case invalidKeySignature(String)
    case malformedKey(String)
    case invalidAccidental(String)
    case missingScaleRoot(String)

    public var errorDescription: String? {
        switch self {
        case .invalidKeySignature(let key):
            return "Invalid key signature for automatic accidentals: '\(key)'."
        case .malformedKey(let key):
            return "Malformed note key while applying accidentals: '\(key)'."
        case .invalidAccidental(let accidental):
            return "Invalid accidental while applying accidentals: '\(accidental)'."
        case .missingScaleRoot(let root):
            return "Missing scale root '\(root)' while applying accidentals."
        }
    }
}

// MARK: - Accidental Enclosure

/// The pair of glyphs around a cautionary or editorial accidental. (VexFlow 5.8.0)
public enum AccidentalEnclosure: String, Sendable {
    /// Round parentheses (cautionary accidental).
    case parentheses
    /// Square brackets (editorial accidental).
    case brackets
}

// MARK: - Accidental

/// An `Accidental` inherits from `Modifier`, and is formatted within a
/// `ModifierContext`. Accidentals are modifiers that can be attached to
/// notes. Support is included for both western and microtonal accidentals.
public final class Accidental: Modifier {

    override public class var category: String { "Accidental" }

    // MARK: - Properties

    public let accidentalType: AccidentalType
    /// Accidental code provided to the constructor (a key of the
    /// `Tables.accidentalCodes` table, or a SMuFL code point).
    public let type: String
    public private(set) var cautionary: Bool = false

    /// Identify explicit cautionary signs without inspecting protected engraving state. (VexFlow 5.2.0)
    public func isCautionary() -> Bool { cautionary }
    /// The printed sign at this same head, recomputed whenever the modifier group is formatted. (VexFlow 5.8.0)
    private weak var sharedWith: Accidental?
    /// Select the pair of glyphs around a cautionary or editorial accidental. (VexFlow 5.8.0)
    public private(set) var enclosure: AccidentalEnclosure = .parentheses
    /// An ordinary sign supplied by key-aware spelling, so engraving can share it at unisons.
    /// Explicit and cautionary signs retain independent placement. This flag replaces the
    /// upstream `automaticAccidentals` WeakSet (`src/automaticaccidentals.ts`). (VexFlow 5.8.0)
    var isAutomatic = false
    public private(set) var initError: AccidentalError?

    /// True if `type` is a key of the accidental table or a single SMuFL code point.
    private static func isKnownType(_ type: String) -> Bool {
        if Tables.hasAccidentalCode(type) { return true }
        // A SMuFL code point (for example `Glyphs.accSagittal5CommaDown`).
        let scalars = type.unicodeScalars
        if scalars.count == 1, let scalar = scalars.first, (0xE000...0xF8FF).contains(scalar.value) {
            return true
        }
        return false
    }

    private init(type: String, accidentalType: AccidentalType) {
        self.type = type
        self.accidentalType = accidentalType
        super.init()
        position = .left
        // Cautionary accidentals have parentheses around them
        cautionary = false
        reset()
    }

    // MARK: - Init

    /// Create accidental.
    public init(_ accidentalType: AccidentalType) {
        self.type = accidentalType.rawValue
        self.accidentalType = accidentalType
        if !Self.isKnownType(accidentalType.rawValue) {
            self.initError = .missingTableMapping(accidentalType.rawValue)
        }
        super.init()
        position = .left
        // Cautionary accidentals have parentheses around them
        cautionary = false
        reset()
    }

    public convenience init(validating accidentalType: AccidentalType) throws {
        self.init(accidentalType)
        if let initError {
            throw initError
        }
    }

    /// String convenience initializer that throws on invalid accidental type.
    ///
    /// Accepts a key of the accidental table (`#`, `##`, `b`, `n`, ...), a SMuFL
    /// code point (for example `Glyphs.accSagittal5CommaDown`) or a SMuFL glyph
    /// name (for example `"accSagittal5CommaDown"`).
    public convenience init(parsing type: String) throws {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = AccidentalType(parsing: trimmed) {
            self.init(parsed)
            return
        }
        if Self.isKnownType(trimmed) {
            self.init(type: trimmed, accidentalType: .natural)
            return
        }
        if let code = Glyphs.code(named: trimmed) {
            self.init(type: code, accidentalType: .natural)
            return
        }
        throw AccidentalParseError.invalidType(type)
    }

    /// String convenience initializer that returns nil on invalid accidental type.
    public convenience init?(parsingOrNil type: String) {
        do {
            try self.init(parsing: type)
        } catch {
            return nil
        }
    }

    // MARK: - Reset

    override public func reset() {
        text = ""

        if !cautionary {
            text += Tables.accidentalCodes(type)
            setFontSize(Metrics.getDouble("Accidental.fontSize"))
        } else {
            text += enclosure == .brackets ? Glyphs.accidentalBracketLeft : Glyphs.accidentalParensLeft
            text += Tables.accidentalCodes(type)
            text += enclosure == .brackets ? Glyphs.accidentalBracketRight : Glyphs.accidentalParensRight
            setFontSize(Metrics.getDouble("Accidental.cautionary.fontSize"))
        }
        // Accidentals attached to grace notes are rendered smaller.
        if note is GraceNote {
            setFontSize(Metrics.getDouble("Accidental.grace.fontSize"))
        }
    }

    // MARK: - Set Note

    /// Attach this accidental to `note`, which must be a `StaveNote`.
    @discardableResult
    override public func setNote(_ note: Note) -> Self {
        self.note = note
        reset()
        return self
    }

    // MARK: - Cautionary

    /// Enclose the sign in round parentheses or square editorial brackets without changing its pitch spelling.
    @discardableResult
    public func setAsCautionary(_ enclosure: AccidentalEnclosure = .parentheses) -> Self {
        self.enclosure = enclosure
        cautionary = true
        reset()
        return self
    }

    // MARK: - Shared Unison Signs (VexFlow 5.8.0)

    /// At one onset, compare the actual heads after StaveNote.format has separated colliding voices.
    private static func shareUnisonSigns(_ signs: [Accidental]) -> [Accidental] {
        if !signs.contains(where: { $0.isAutomatic }) { return signs }
        func automatic(_ mark: Accidental) -> Bool { mark.isAutomatic && !mark.isCautionary() }
        for mark in signs { mark.sharedWith = nil }
        if signs.count < 2 { return signs }

        // Prefer an explicit matching sign, even if its voice was supplied last.
        var visible = signs.filter { !automatic($0) }
        for mark in signs {
            if !automatic(mark) { continue }
            mark.sharedWith = visible.first { mark.sharesHeadWith($0) }
            if mark.sharedWith == nil { visible.append(mark) }
        }
        return signs.filter { $0.sharedWith == nil }
    }

    /// A displaced chord head or a separate unison column needs its own sign.
    private func sharesHeadWith(_ other: Accidental) -> Bool {
        if other.type != type { return false }
        guard let a = note as? StaveNote, let b = other.note as? StaveNote, a !== b else { return false }
        guard let stave = a.getStave(), stave === b.getStave(),
              a.renderOptions.draw, b.renderOptions.draw,
              a.isCenterAligned() == b.isCenterAligned(),
              a.getCenterXShift() == b.getCenterXShift()
        else { return false }
        let i = checkIndex()
        let j = other.checkIndex()
        guard i < a.keys.count, j < b.keys.count, i < a.noteHeads.count, j < b.noteHeads.count else { return false }
        if a.keys[i].lowercased() != b.keys[j].lowercased() { return false }
        let h = a.noteHeads[i]
        let k = b.noteHeads[j]
        return h.getLine() == k.getLine()
            && h.getText() == k.getText()
            && h.getFont() == k.getFont()
            && h.getYShift() == k.getYShift()
            && a.getXShift() + h.getDisplacementX() + h.getXShift()
                == b.getXShift() + k.getDisplacementX() + k.getXShift()
    }

    // MARK: - Static Format

    /// Arrange accidentals inside a ModifierContext.
    @discardableResult
    public static func format(_ accidentals: [Accidental], state: inout ModifierContextState) -> Bool {
        // If there are no accidentals, no need to format their positions.
        if accidentals.isEmpty { return false }

        let accidentals = shareUnisonSigns(accidentals)

        let noteheadAccidentalPadding = Metrics.getDouble("Accidental.noteheadAccidentalPadding")
        let leftShift = state.leftShift + noteheadAccidentalPadding
        let accidentalSpacing = Metrics.getDouble("Accidental.accidentalSpacing")
        // padding to the left of all accidentals
        let additionalPadding = Metrics.getDouble("Accidental.leftPadding")

        struct AccidentalLinePositionsAndXSpaceNeeds {
            var y: Double?
            var line: Double
            /// The amount by which the accidental requests that notes be shifted to the right
            /// to accommodate its presence.
            var extraXSpaceNeeded: Double
            var accidental: Accidental
            var spacingBetweenStaveLines: Double?
        }

        var accidentalLinePositionsAndSpaceNeeds: [AccidentalLinePositionsAndXSpaceNeeds] = []
        var prevNote: Note?
        var extraXSpaceNeededForLeftDisplacedNotehead: Double = 0

        // First determine the accidentals' Y positions from the note.keys
        for accidental in accidentals {
            let note = accidental.getNote()
            let stave = note.getStave()
            let index = accidental.checkIndex()
            let props = note.getKeyProps()[index]

            if note !== prevNote {
                // Iterate through all notes to get the displaced pixels
                for _ in 0..<note.keys.count {
                    // If the current extra left-space needed isn't as big as this note's,
                    // then we need to use this note's.
                    extraXSpaceNeededForLeftDisplacedNotehead = max(
                        note.getLeftDisplacedHeadPx() - note.getXShift(),
                        extraXSpaceNeededForLeftDisplacedNotehead
                    )
                }
                prevNote = note
            }
            if let stave {
                let lineSpace = stave.getSpacingBetweenLines()
                let y = stave.getYForLine(props.line)
                let accLine = (y / lineSpace * 2).rounded() / 2
                accidentalLinePositionsAndSpaceNeeds.append(AccidentalLinePositionsAndXSpaceNeeds(
                    y: y,
                    line: accLine,
                    extraXSpaceNeeded: extraXSpaceNeededForLeftDisplacedNotehead,
                    accidental: accidental,
                    spacingBetweenStaveLines: lineSpace
                ))
            } else {
                accidentalLinePositionsAndSpaceNeeds.append(AccidentalLinePositionsAndXSpaceNeeds(
                    line: props.line,
                    extraXSpaceNeeded: extraXSpaceNeededForLeftDisplacedNotehead,
                    accidental: accidental
                ))
            }
        }

        // Sort accidentals by line number (stable, like Array.prototype.sort).
        accidentalLinePositionsAndSpaceNeeds = accidentalLinePositionsAndSpaceNeeds
            .enumerated()
            .sorted { $0.element.line != $1.element.line ? $0.element.line > $1.element.line : $0.offset < $1.offset }
            .map(\.element)

        var staveLineAccidentalLayoutMetrics: [AccidentalLineMetrics] = []

        // amount by which all accidentals must be shifted right or left for
        // stem flipping, notehead shifting concerns.
        var maxExtraXSpaceNeeded: Double = 0

        // Create an array of unique line numbers (staveLineAccidentalLayoutMetrics)
        // from accidentalLinePositionsAndSpaceNeeds
        for accidentalLinePositionAndSpaceNeeds in accidentalLinePositionsAndSpaceNeeds {
            let accidentalType = accidentalLinePositionAndSpaceNeeds.accidental.type

            // if this is the first line, or a new line, add a staveLineAccidentalLayoutMetric
            if staveLineAccidentalLayoutMetrics.last?.line != accidentalLinePositionAndSpaceNeeds.line {
                staveLineAccidentalLayoutMetrics.append(AccidentalLineMetrics(
                    column: 0,
                    line: accidentalLinePositionAndSpaceNeeds.line,
                    flatLine: true,
                    dblSharpLine: true,
                    numAcc: 0,
                    width: 0
                ))
            }
            let current = staveLineAccidentalLayoutMetrics.count - 1

            // if this accidental is not a flat, the accidental needs 3.0 lines lower
            // clearance instead of 2.5 lines for b or bb.
            if accidentalType != "b" && accidentalType != "bb" {
                staveLineAccidentalLayoutMetrics[current].flatLine = false
            }

            // if this accidental is not a double sharp, the accidental needs 3.0 lines above
            if accidentalType != "##" {
                staveLineAccidentalLayoutMetrics[current].dblSharpLine = false
            }

            // Track how many accidentals are on this line:
            staveLineAccidentalLayoutMetrics[current].numAcc += 1

            // Track the total xOffset needed for this line which will be needed
            // for formatting lines w/ multiple accidentals:

            // width = accidental width + universal spacing between accidentals
            staveLineAccidentalLayoutMetrics[current].width +=
                accidentalLinePositionAndSpaceNeeds.accidental.getWidth() + accidentalSpacing

            // if this extraXSpaceNeeded is the largest so far, use it as the starting point for
            // all accidental columns.
            maxExtraXSpaceNeeded = max(accidentalLinePositionAndSpaceNeeds.extraXSpaceNeeded, maxExtraXSpaceNeeded)
        }

        // ### Place Accidentals in Columns
        //
        // Default to a classic triangular layout (middle accidental farthest left),
        // but follow exceptions as outlined in G. Read's _Music Notation_ and
        // Elaine Gould's _Behind Bars_.
        //
        // Additionally, this implements different vertical collision rules for
        // flats (only need 2.5 lines clearance below) and double sharps (only
        // need 2.5 lines of clearance above or below).
        //
        // Classic layouts and exception patterns are found in the 'tables.js'
        // in 'Tables.accidentalColumnsTable'
        //
        // Beyond 6 vertical accidentals, default to the parallel ascending lines approach,
        // using as few columns as possible for the vertical structure.

        var totalColumns = 0

        // establish the boundaries for a group of notes with clashing accidentals:
        var i = 0
        while i < staveLineAccidentalLayoutMetrics.count {
            var noFurtherConflicts = false
            let groupStart = i
            var groupEnd = i

            while groupEnd + 1 < staveLineAccidentalLayoutMetrics.count && !noFurtherConflicts {
                // if this note conflicts with the next:
                if checkCollision(
                    staveLineAccidentalLayoutMetrics[groupEnd],
                    staveLineAccidentalLayoutMetrics[groupEnd + 1]
                ) {
                    // include the next note in the group:
                    groupEnd += 1
                } else {
                    noFurtherConflicts = true
                }
            }

            // Gets a line from the `lineList`, relative to the current group
            func getGroupLine(_ index: Int) -> AccidentalLineMetrics {
                staveLineAccidentalLayoutMetrics[groupStart + index]
            }
            func lineDifference(_ indexA: Int, _ indexB: Int) -> Double {
                getGroupLine(indexA).line - getGroupLine(indexB).line
            }
            func notColliding(_ indexPairs: [Int]...) -> Bool {
                indexPairs.allSatisfy { pair in
                    !checkCollision(getGroupLine(pair[0]), getGroupLine(pair[1]))
                }
            }

            // Set columns for the lines in this group:
            let groupLength = groupEnd - groupStart + 1

            // Set the accidental column for each line of the group
            var endCase = checkCollision(
                staveLineAccidentalLayoutMetrics[groupStart],
                staveLineAccidentalLayoutMetrics[groupEnd]
            ) ? "a" : "b"

            switch groupLength {
            case 3:
                if endCase == "a" && lineDifference(1, 2) == 0.5 && lineDifference(0, 1) != 0.5 {
                    endCase = "secondOnBottom"
                }
            case 4:
                if notColliding([0, 2], [1, 3]) {
                    endCase = "spacedOutTetrachord"
                }
            case 5:
                if endCase == "b" && notColliding([1, 3]) {
                    endCase = "spacedOutPentachord"
                    if notColliding([0, 2], [2, 4]) {
                        endCase = "verySpacedOutPentachord"
                    }
                }
            case 6:
                if notColliding([0, 3], [1, 4], [2, 5]) {
                    endCase = "spacedOutHexachord"
                }
                if notColliding([0, 2], [2, 4], [1, 3], [3, 5]) {
                    endCase = "verySpacedOutHexachord"
                }
            default:
                break
            }

            // If the group contains seven members or more, use ascending parallel lines
            // of accidentals, using as few columns as possible while avoiding collisions.
            if groupLength >= 7 {
                // First, determine how many columns to use:
                var patternLength = 2
                var collisionDetected = true
                while collisionDetected {
                    collisionDetected = false
                    var line = 0
                    while line + patternLength < staveLineAccidentalLayoutMetrics.count {
                        if checkCollision(
                            staveLineAccidentalLayoutMetrics[line],
                            staveLineAccidentalLayoutMetrics[line + patternLength]
                        ) {
                            collisionDetected = true
                            patternLength += 1
                            break
                        }
                        line += 1
                    }
                }
                // Then, assign a column to each line of accidentals
                for groupMember in i...groupEnd {
                    let column = ((groupMember - i) % patternLength) + 1
                    staveLineAccidentalLayoutMetrics[groupMember].column = column
                    totalColumns = totalColumns > column ? totalColumns : column
                }
            } else {
                // If the group contains fewer than seven members, use the layouts from
                // the Tables.accidentalColumnsTable (See: tables.ts).
                let layout = Tables.accidentalColumnsTable[groupLength]?[endCase] ?? []
                for groupMember in i...groupEnd where groupMember - i < layout.count {
                    let column = layout[groupMember - i]
                    staveLineAccidentalLayoutMetrics[groupMember].column = column
                    totalColumns = totalColumns > column ? totalColumns : column
                }
            }

            // Increment i to the last note that was set, so that if a lower set of notes
            // does not conflict at all with this group, it can have its own classic shape.
            i = groupEnd + 1
        }

        // ### Convert Columns to xOffsets
        //
        // This keeps columns aligned, even if they have different accidentals within them
        // which sometimes results in a larger xOffset than is an accidental might need
        // to preserve the symmetry of the accidental shape.

        // track each column's max width, which will be used as initial shift of later columns:
        var columnWidths = [Double](repeating: 0, count: totalColumns + 1)
        var columnXOffsets = [Double](repeating: 0, count: totalColumns + 1)

        columnWidths[0] = leftShift + maxExtraXSpaceNeeded
        columnXOffsets[0] = leftShift

        // Fill columnWidths with the widest needed x-space;
        // this is what keeps the columns parallel.
        for line in staveLineAccidentalLayoutMetrics where line.width > columnWidths[line.column] {
            columnWidths[line.column] = line.width
        }

        for col in stride(from: 1, to: columnWidths.count, by: 1) {
            // this column's offset = this column's width + previous column's offset
            columnXOffsets[col] = columnWidths[col] + columnXOffsets[col - 1]
        }

        let totalShift = columnXOffsets[columnXOffsets.count - 1]
        // Set the xShift for each accidental according to column offsets:
        var accCount = 0
        for line in staveLineAccidentalLayoutMetrics {
            var lineWidth: Double = 0
            let lastAccOnLine = accCount + line.numAcc
            // handle all accidentals on a given line:
            while accCount < lastAccOnLine {
                let xShift = columnXOffsets[max(line.column - 1, 0)] + lineWidth + maxExtraXSpaceNeeded
                _ = accidentalLinePositionsAndSpaceNeeds[accCount].accidental.setXShift(xShift)
                // keep track of the width of accidentals we've added so far, so that when
                // we loop, we add space for them.
                lineWidth += accidentalLinePositionsAndSpaceNeeds[accCount].accidental.getWidth() + accidentalSpacing
                accCount += 1
            }
        }
        // update the overall layout with the full width of the accidental shapes:
        state.leftShift = totalShift + additionalPadding
        return true
    }

    // MARK: - Collision Detection

    /// Helper function to determine whether two lines of accidentals collide vertically.
    static func checkCollision(_ line1: AccidentalLineMetrics, _ line2: AccidentalLineMetrics) -> Bool {
        var clearance = line2.line - line1.line
        var clearanceRequired: Double = 3
        // But less clearance is required for certain accidentals: b, bb and ##.
        if clearance > 0 {
            // then line 2 is on top
            clearanceRequired = (line2.flatLine || line2.dblSharpLine) ? 2.5 : 3.0
            if line1.dblSharpLine { clearance -= 0.5 }
        } else {
            // line 1 is on top
            clearanceRequired = (line1.flatLine || line1.dblSharpLine) ? 2.5 : 3.0
            if line2.dblSharpLine { clearance -= 0.5 }
        }
        return abs(clearance) < clearanceRequired
    }

    // MARK: - Automatic Accidentals

    /// Automatically apply accidentals across one or more voices using a pre-validated key manager.
    ///
    /// The accidental state is shared across all provided voices at matching tick positions.
    public static func applyAccidentals(_ voices: [Voice], keyManager: KeyManager) throws {
        let music = keyManager.music
        var scaleMapByRoot: [String: String] = [:]
        for (root, note) in keyManager.scaleMap {
            // Match VexFlow createScaleMap behavior: naturals are explicit.
            scaleMapByRoot[root] = note.count == 1 ? "\(note)n" : note
        }
        try applyAccidentals(voices, scaleMapByRoot: scaleMapByRoot, music: music)
    }

    /// Automatically apply accidentals across one or more voices using a string key signature.
    ///
    /// Example: `try Accidental.applyAccidentals([voice], keySignature: "F")`
    public static func applyAccidentals(_ voices: [Voice], keySignature: String = "C") throws {
        let normalized = keySignature.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedKey = normalized.isEmpty ? "C" : normalized
        let keyManager: KeyManager
        do {
            keyManager = try KeyManager(parsing: resolvedKey)
        } catch {
            throw AccidentalApplyError.invalidKeySignature(keySignature)
        }
        try applyAccidentals(voices, keyManager: keyManager)
    }

    /// Failable convenience wrapper for string key signatures.
    ///
    /// Returns `nil` when the key signature is invalid.
    @discardableResult
    public static func applyAccidentalsOrNil(_ voices: [Voice], keySignature: String = "C") -> [Voice]? {
        guard (try? applyAccidentals(voices, keySignature: keySignature)) != nil else {
            return nil
        }
        return voices
    }

    private static func applyAccidentals(
        _ voices: [Voice],
        scaleMapByRoot: [String: String],
        music: Music
    ) throws {
        var tickPositions: [Fraction] = []
        var tickNoteMap: [String: [Tickable]] = [:]

        func tickKey(_ position: Fraction) -> String {
            position.clone().simplify().description
        }

        // Group tickables by absolute tick position across all voices.
        for voice in voices {
            let tickPosition = Fraction(0, 1)
            for tickable in voice.getTickables() {
                if tickable.shouldIgnoreTicks() { continue }

                let positionKey = tickKey(tickPosition)
                if tickNoteMap[positionKey] == nil {
                    tickPositions.append(tickPosition.clone())
                    tickNoteMap[positionKey] = [tickable]
                } else {
                    tickNoteMap[positionKey]?.append(tickable)
                }

                tickPosition.add(tickable.getTicks())
            }
        }

        tickPositions.sort()

        // Mutable per-octave accidental state, e.g. "c4" -> "c#".
        var scaleMap: [String: String] = [:]

        func processTickable(_ tickable: Tickable, modifiedPitches: inout Set<String>) throws {
            guard let staveNote = tickable as? StaveNote,
                  !staveNote.isRest(),
                  !staveNote.shouldIgnoreTicks()
            else {
                return
            }

            for (keyIndex, keyString) in staveNote.keys.enumerated() {
                let parts = keyString.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                guard parts.count >= 2 else {
                    throw AccidentalApplyError.malformedKey(keyString)
                }

                let keyToken = parts[0]
                let octave = parts[1]
                let keyParts: NoteParts
                do {
                    keyParts = try music.noteParts(parsing: keyToken)
                } catch {
                    throw AccidentalApplyError.malformedKey(keyString)
                }

                let accidentalString = keyParts.accidental ?? "n"
                let pitch = keyParts.root + accidentalString

                let scaleStateKey = keyParts.root + octave
                if scaleMap[scaleStateKey] == nil {
                    guard let initialPitch = scaleMapByRoot[keyParts.root] else {
                        throw AccidentalApplyError.missingScaleRoot(keyParts.root)
                    }
                    scaleMap[scaleStateKey] = initialPitch
                }

                let sameAccidental = (scaleMap[scaleStateKey] == pitch)
                let pitchIdentity = "\(keyParts.root)\(accidentalString)/\(octave)"
                let previouslyModified = modifiedPitches.contains(pitchIdentity)

                // Remove duplicate pre-existing accidental of same type at this key index.
                staveNote.modifiers.removeAll { modifier in
                    guard let accidental = modifier as? Accidental else { return false }
                    return accidental.type == accidentalString && accidental.getIndex() == keyIndex
                }

                if !sameAccidental || previouslyModified {
                    scaleMap[scaleStateKey] = pitch

                    guard let accidentalType = AccidentalType(parsing: accidentalString) else {
                        throw AccidentalApplyError.invalidAccidental(accidentalString)
                    }
                    _ = staveNote.addModifier(Accidental(accidentalType), index: keyIndex)
                    modifiedPitches.insert(pitchIdentity)
                }
            }

            // Process grace notes attached to this note.
            for modifier in staveNote.getModifiers() {
                if let graceGroup = modifier as? GraceNoteGroup {
                    for graceNote in graceGroup.getGraceNotes() {
                        try processTickable(graceNote, modifiedPitches: &modifiedPitches)
                    }
                }
            }
        }

        for tickPosition in tickPositions {
            let positionKey = tickKey(tickPosition)
            guard let tickables = tickNoteMap[positionKey] else { continue }

            var modifiedPitches = Set<String>()
            for tickable in tickables {
                try processTickable(tickable, modifiedPitches: &modifiedPitches)
            }
        }
    }

    // MARK: - Draw

    /// Render accidental onto canvas.
    /// Place the glyph using the same coordinates for measurement and drawing. (VexFlow 5.3.0)
    private func positionGlyph() throws {
        let note = try checkAttachedNoteThrowing()

        // Figure out the start `x` and `y` coordinates for note and index.
        let start = note.getModifierStartXY(position: position, index: index ?? 0)
        x = start.x - width
        y = start.y
    }

    /// Visible glyph after formatting, including cautionary or authored shifts. (VexFlow 5.3.0)
    public func getInkBounds() throws -> BoundingBox {
        if let sharedWith { return try sharedWith.getInkBounds() }
        try positionGlyph()
        return getTextInk(x, y)
    }

    /// Both voices report the published bounds of their shared sign. (VexFlow 5.8.0)
    override public func getBoundingBox() -> BoundingBox? {
        if let sharedWith { return sharedWith.getBoundingBox() }
        return super.getBoundingBox()
    }

    /// The representative accidental draws the glyph for every voice sharing this head. (VexFlow 5.8.0)
    override public func draw() throws {
        if sharedWith == nil {
            let ctx = try checkContext()
            try positionGlyph()
            renderText(ctx, xPos: 0, yPos: 0)
        }
        setRendered()
    }

    /// True when another accidental at the same printed unison head draws the sign. (VexFlow 5.8.0)
    public var isShared: Bool { sharedWith != nil }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Accidental", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C#5/q, Db5, En5, F#5")
        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
