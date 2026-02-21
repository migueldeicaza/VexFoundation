// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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
    var flatLine: Bool
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

// MARK: - Accidental

/// Modifier that adds accidentals (sharps, flats, naturals, etc.) to notes.
/// Positioned to the left of the notehead.
public final class Accidental: Modifier {

    override public class var category: String { "Accidental" }

    // MARK: - Properties

    public let accidentalType: AccidentalType
    public let type: String
    public var accidentalData: AccidentalCode
    public var cautionary: Bool = false
    public var fontScale: Double = Tables.NOTATION_FONT_SCALE
    public var parenLeftPadding: Double = 2
    public var parenRightPadding: Double = 2
    public private(set) var initError: AccidentalError?

    private var glyph: Glyph!
    private var parenLeft: Glyph?
    private var parenRight: Glyph?

    private static func fallbackAccidentalData() -> AccidentalCode {
        Tables.accidentalCode(AccidentalType.natural.rawValue) ?? AccidentalCode(
            code: "accidentalNatural",
            parenRightPaddingAdjustment: 0
        )
    }

    private static func resolveAccidentalData(for type: String) -> AccidentalCode? {
        if let code = Tables.accidentalCode(type) {
            return code
        }
        if let code = Tables.accidentalCode(type.lowercased()) {
            return code
        }
        if (try? Glyph.lookupGlyph(fontStack: Glyph.MUSIC_FONT_STACK, code: type)) != nil {
            // Upstream includes many accidental names (e.g., Sagittal) whose glyph code
            // is the same as the accidental key.
            return AccidentalCode(code: type, parenRightPaddingAdjustment: -1)
        }
        return nil
    }

    private init(
        type: String,
        accidentalType: AccidentalType,
        accidentalData: AccidentalCode,
        initError: AccidentalError? = nil
    ) {
        self.type = type
        self.accidentalType = accidentalType
        self.accidentalData = accidentalData
        self.initError = initError
        super.init()
        position = .left
        reset()
    }

    // MARK: - Init

    public init(_ accidentalType: AccidentalType) {
        if let accData = Self.resolveAccidentalData(for: accidentalType.rawValue) {
            self.type = accidentalType.rawValue
            self.accidentalType = accidentalType
            self.accidentalData = accData
        } else {
            self.type = accidentalType.rawValue
            self.accidentalType = accidentalType
            self.accidentalData = Self.fallbackAccidentalData()
            self.initError = .missingTableMapping(accidentalType.rawValue)
        }
        super.init()
        position = .left
        reset()
    }

    public convenience init(validating accidentalType: AccidentalType) throws {
        self.init(accidentalType)
        if let initError {
            throw initError
        }
    }

    /// String convenience initializer that throws on invalid accidental type.
    public convenience init(parsing type: String) throws {
        let trimmed = type.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = AccidentalType(parsing: trimmed) {
            self.init(parsed)
            return
        }
        guard let accidentalData = Self.resolveAccidentalData(for: trimmed) else {
            throw AccidentalParseError.invalidType(type)
        }
        self.init(
            type: trimmed,
            accidentalType: .natural,
            accidentalData: accidentalData
        )
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

    private func reset() {
        glyph = Glyph(code: accidentalData.code, point: fontScale)
        glyph.setOriginX(1.0)

        if cautionary {
            if let leftCode = Tables.accidentalCode("{"),
               let rightCode = Tables.accidentalCode("}") {
                parenLeft = Glyph(code: leftCode.code, point: fontScale)
                parenRight = Glyph(code: rightCode.code, point: fontScale)
                parenLeft?.setOriginX(1.0)
                parenRight?.setOriginX(1.0)
            }
        }
    }

    // MARK: - Width

    override public func getWidth() -> Double {
        if cautionary, let pl = parenLeft, let pr = parenRight {
            let parenWidth = pl.getMetrics().width + pr.getMetrics().width
                + parenLeftPadding + parenRightPadding
            return glyph.getMetrics().width + parenWidth
        }
        return glyph.getMetrics().width
    }

    // MARK: - Set Note

    @discardableResult
    override public func setNote(_ note: Note) -> Self {
        self.note = note
        // Grace notes get smaller accidentals, matching upstream behavior.
        if note is GraceNote {
            fontScale = 25
            reset()
        }
        return self
    }

    // MARK: - Cautionary

    @discardableResult
    public func setAsCautionary() -> Self {
        cautionary = true
        fontScale = 28
        reset()
        return self
    }

    // MARK: - Static Format

    /// Arrange accidentals inside a ModifierContext.
    /// Uses collision detection and column assignment to avoid overlap.
    @discardableResult
    public static func format(_ accidentals: [Accidental], state: inout ModifierContextState) -> Bool {
        if accidentals.isEmpty { return false }

        // Font metrics for spacing
        let musicFont = Glyph.MUSIC_FONT_STACK.first
        let noteheadAccidentalPadding = (musicFont?.lookupMetric("accidental.noteheadAccidentalPadding") as? Double) ?? 2
        let leftShift = state.leftShift + noteheadAccidentalPadding
        let accidentalSpacing = (musicFont?.lookupMetric("accidental.accidentalSpacing") as? Double) ?? 2
        let additionalPadding = (musicFont?.lookupMetric("accidental.leftPadding") as? Double) ?? 2

        // MARK: Phase 1 — Collect Y positions

        struct AccLineEntry {
            var line: Double
            var extraXSpaceNeeded: Double
            var acc: Accidental
        }

        var accEntries: [AccLineEntry] = []
        var prevNote: Note?
        var extraXSpace: Double = 0

        for acc in accidentals {
            let note = acc.getNote()
            let index = acc.checkIndex()
            let props = note.getKeyProps()[index]

            if note !== prevNote {
                extraXSpace = max(
                    note.getLeftDisplacedHeadPx() - note.getXShift(),
                    extraXSpace
                )
                prevNote = note
            }

            if let stave = note.getStave() {
                let lineSpace = stave.getSpacingBetweenLines()
                let y = stave.getYForLine(props.line)
                let accLine = (y / lineSpace * 2).rounded() / 2
                accEntries.append(AccLineEntry(line: accLine, extraXSpaceNeeded: extraXSpace, acc: acc))
            } else {
                accEntries.append(AccLineEntry(line: props.line, extraXSpaceNeeded: extraXSpace, acc: acc))
            }
        }

        // MARK: Phase 2 — Sort by line (descending)

        accEntries.sort { $0.line > $1.line }

        // MARK: Phase 3 — Build unique line metrics

        var lineMetrics: [AccidentalLineMetrics] = []
        var maxExtraXSpace: Double = 0

        for entry in accEntries {
            if let last = lineMetrics.last, last.line == entry.line {
                // Same line — update existing
                let idx = lineMetrics.count - 1
                if entry.acc.type != "b" && entry.acc.type != "bb" {
                    lineMetrics[idx].flatLine = false
                }
                if entry.acc.type != "##" {
                    lineMetrics[idx].dblSharpLine = false
                }
                lineMetrics[idx].numAcc += 1
                lineMetrics[idx].width += entry.acc.getWidth() + accidentalSpacing
            } else {
                // New line
                let isFlat = entry.acc.type == "b" || entry.acc.type == "bb"
                let isDblSharp = entry.acc.type == "##"
                lineMetrics.append(AccidentalLineMetrics(
                    line: entry.line,
                    flatLine: isFlat,
                    dblSharpLine: isDblSharp,
                    numAcc: 1,
                    width: entry.acc.getWidth() + accidentalSpacing
                ))
            }
            maxExtraXSpace = max(entry.extraXSpaceNeeded, maxExtraXSpace)
        }

        // MARK: Phase 4 — Column assignment

        var totalColumns = 0

        var i = 0
        while i < lineMetrics.count {
            let groupStart = i
            var groupEnd = i

            // Find collision group
            while groupEnd + 1 < lineMetrics.count &&
                  checkCollision(lineMetrics[groupEnd], lineMetrics[groupEnd + 1]) {
                groupEnd += 1
            }

            let groupLength = groupEnd - groupStart + 1

            // Helper functions
            func lineDiff(_ a: Int, _ b: Int) -> Double {
                lineMetrics[groupStart + a].line - lineMetrics[groupStart + b].line
            }

            func notColliding(_ pairs: [Int]...) -> Bool {
                pairs.allSatisfy { pair in
                    !checkCollision(lineMetrics[groupStart + pair[0]], lineMetrics[groupStart + pair[1]])
                }
            }

            // Determine layout case
            var endCase = checkCollision(lineMetrics[groupStart], lineMetrics[groupEnd]) ? "a" : "b"

            switch groupLength {
            case 3:
                if endCase == "a" && lineDiff(1, 2) == 0.5 && lineDiff(0, 1) != 0.5 {
                    endCase = "second_on_bottom"
                }
            case 4:
                if notColliding([0, 2], [1, 3]) {
                    endCase = "spaced_out_tetrachord"
                }
            case 5:
                if endCase == "b" && notColliding([1, 3]) {
                    endCase = "spaced_out_pentachord"
                    if notColliding([0, 2], [2, 4]) {
                        endCase = "very_spaced_out_pentachord"
                    }
                }
            case 6:
                if notColliding([0, 3], [1, 4], [2, 5]) {
                    endCase = "spaced_out_hexachord"
                }
                if notColliding([0, 2], [2, 4], [1, 3], [3, 5]) {
                    endCase = "very_spaced_out_hexachord"
                }
            default:
                break
            }

            if groupLength >= 7 {
                // Parallel ascending lines for 7+ accidentals
                var patternLength = 2
                var collisionDetected = true
                while collisionDetected {
                    collisionDetected = false
                    for line in 0..<(lineMetrics.count - patternLength) {
                        if checkCollision(lineMetrics[line], lineMetrics[line + patternLength]) {
                            collisionDetected = true
                            patternLength += 1
                            break
                        }
                    }
                }
                for member in i...groupEnd {
                    let column = ((member - i) % patternLength) + 1
                    lineMetrics[member].column = column
                    totalColumns = max(totalColumns, column)
                }
            } else {
                // Use table layouts for 1-6 accidentals
                if let layout = Tables.accidentalColumnsTable[groupLength]?[endCase] {
                    for member in i...groupEnd {
                        let column = layout[member - i]
                        lineMetrics[member].column = column
                        totalColumns = max(totalColumns, column)
                    }
                }
            }

            i = groupEnd + 1
        }

        // MARK: Phase 5 — Convert columns to X offsets

        var columnWidths = [Double](repeating: 0, count: totalColumns + 1)
        var columnXOffsets = [Double](repeating: 0, count: totalColumns + 1)

        columnWidths[0] = leftShift + maxExtraXSpace
        columnXOffsets[0] = leftShift

        // Fill with widest width per column
        for metric in lineMetrics {
            if metric.width > columnWidths[metric.column] {
                columnWidths[metric.column] = metric.width
            }
        }

        for col in 1..<columnWidths.count {
            columnXOffsets[col] = columnWidths[col] + columnXOffsets[col - 1]
        }

        let totalShift = columnXOffsets.last ?? 0

        // MARK: Phase 6 — Apply X shifts

        var accCount = 0
        for metric in lineMetrics {
            var lineWidth: Double = 0
            let lastAccOnLine = accCount + metric.numAcc
            while accCount < lastAccOnLine {
                let xShift = columnXOffsets[metric.column - 1] + lineWidth + maxExtraXSpace
                _ = accEntries[accCount].acc.setXShift(xShift)
                lineWidth += accEntries[accCount].acc.getWidth() + accidentalSpacing
                accCount += 1
            }
        }

        state.leftShift = totalShift + additionalPadding
        return true
    }

    // MARK: - Collision Detection

    /// Check if two accidental lines collide vertically.
    static func checkCollision(_ line1: AccidentalLineMetrics, _ line2: AccidentalLineMetrics) -> Bool {
        var clearance = line2.line - line1.line
        let clearanceRequired: Double
        if clearance > 0 {
            // line2 is on top
            clearanceRequired = (line2.flatLine || line2.dblSharpLine) ? 2.5 : 3.0
            if line1.dblSharpLine { clearance -= 0.5 }
        } else {
            // line1 is on top
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
                staveNote.noteModifiers.removeAll { modifier in
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

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        guard let staveNote = note as? StaveNote else { return }
        let start = staveNote.getModifierStartXY(position: position, index: checkIndex())
        var accX = start.x + xShift
        let accY = start.y + yShift

        if !cautionary {
            glyph.render(ctx: ctx, x: accX, y: accY)
        } else {
            guard let parenLeft, let parenRight else { return }

            // Render right-to-left: parenRight, glyph, parenLeft
            parenRight.render(ctx: ctx, x: accX, y: accY)
            accX -= parenRight.getMetrics().width
            accX -= parenRightPadding
            accX -= accidentalData.parenRightPaddingAdjustment
            glyph.render(ctx: ctx, x: accX, y: accY)
            accX -= glyph.getMetrics().width
            accX -= parenLeftPadding
            parenLeft.render(ctx: ctx, x: accX, y: accY)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Accidental", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
