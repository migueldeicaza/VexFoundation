// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

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
    case buyukMucennebSharp = "++-"

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

// MARK: - Accidental

/// Modifier that adds accidentals (sharps, flats, naturals, etc.) to notes.
/// Positioned to the left of the notehead.
public final class Accidental: Modifier {

    override public class var category: String { "Accidental" }

    // MARK: - Properties

    public let accidentalType: AccidentalType
    public var type: String { accidentalType.rawValue }
    public var accidentalData: AccidentalCode
    public var cautionary: Bool = false
    public var fontScale: Double = Tables.NOTATION_FONT_SCALE
    public var parenLeftPadding: Double = 2
    public var parenRightPadding: Double = 2

    private var glyph: Glyph!
    private var parenLeft: Glyph?
    private var parenRight: Glyph?

    // MARK: - Init

    public init(_ accidentalType: AccidentalType) {
        guard let accData = Tables.accidentalCode(accidentalType.rawValue) else {
            fatalError("[VexError] BadRuntimeState: Missing accidental table mapping for type: \(accidentalType.rawValue)")
        }
        self.accidentalType = accidentalType
        self.accidentalData = accData
        super.init()
        position = .left
        reset()
    }

    /// String convenience initializer that throws on invalid accidental type.
    public convenience init(parsing type: String) throws {
        guard let parsed = AccidentalType(parsing: type) else {
            throw AccidentalParseError.invalidType(type)
        }
        self.init(parsed)
    }

    /// String convenience initializer that returns nil on invalid accidental type.
    public convenience init?(parsingOrNil type: String) {
        guard let parsed = AccidentalType(parsing: type) else { return nil }
        self.init(parsed)
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
        // Grace notes get smaller accidentals
        // if isGraceNote(note) { fontScale = 25; reset() }
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
