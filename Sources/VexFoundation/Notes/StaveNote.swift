// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/stavenote.ts` (VexFlow 5.0.0).
// This file implements notes for standard notation. A note has one or more
// `NoteHead`s, an optional stem, and an optional flag.

import Foundation

// MARK: - StaveNote Struct

/// Input structure for creating a StaveNote (extends NoteStruct).
public struct StaveNoteStruct {
    public var keys: NonEmptyArray<StaffKeySpec>
    public var duration: NoteDurationSpec
    public var line: Double?
    public var dots: Int?
    public var type: NoteType?
    public var alignCenter: Bool?
    public var durationOverride: Fraction?
    public var stemDirection: StemDirection?
    public var autoStem: Bool?
    public var strokePx: Double?
    public var octaveShift: Int?
    public var clef: ClefName?

    public init(
        keys: NonEmptyArray<StaffKeySpec>,
        duration: NoteDurationSpec = .quarter,
        line: Double? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        strokePx: Double? = nil,
        octaveShift: Int? = nil,
        clef: ClefName? = nil
    ) {
        self.keys = keys
        self.duration = duration
        self.line = line
        self.dots = dots
        self.type = type
        self.alignCenter = alignCenter
        self.durationOverride = durationOverride
        self.stemDirection = stemDirection
        self.autoStem = autoStem
        self.strokePx = strokePx
        self.octaveShift = octaveShift
        self.clef = clef
    }

    /// String-based parser for compatibility with external text inputs.
    public init(
        parsingKeys keys: [String] = [],
        duration: String,
        line: Double? = nil,
        dots: Int? = nil,
        type: String? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        strokePx: Double? = nil,
        octaveShift: Int? = nil,
        clef: ClefName? = nil
    ) throws {
        let parsedDuration = try NoteDurationSpec(parsing: duration)
        let parsedKeys = try StaffKeySpec.parseManyNonEmpty(keys)
        let parsedType: NoteType?
        if let type {
            guard let explicitType = NoteType(parsing: type) else {
                throw NoteDurationParseError.invalidType(type)
            }
            parsedType = explicitType
        } else {
            parsedType = nil
        }

        self.init(
            keys: parsedKeys,
            duration: parsedDuration,
            line: line,
            dots: dots,
            type: parsedType,
            alignCenter: alignCenter,
            durationOverride: durationOverride,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: strokePx,
            octaveShift: octaveShift,
            clef: clef
        )
    }

    /// Failable parser convenience.
    public init?(
        parsingDuration duration: String,
        keys: [String],
        line: Double? = nil,
        dots: Int? = nil,
        type: String? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        strokePx: Double? = nil,
        octaveShift: Int? = nil,
        clef: ClefName? = nil
    ) {
        guard let parsed = try? StaveNoteStruct(
            parsingKeys: keys,
            duration: duration,
            line: line,
            dots: dots,
            type: type,
            alignCenter: alignCenter,
            durationOverride: durationOverride,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: strokePx,
            octaveShift: octaveShift,
            clef: clef
        ) else { return nil }
        self = parsed
    }

    /// Failable string parser convenience matching the throwing parser shape.
    public init?(
        parsingKeysOrNil keys: [String],
        duration: String,
        line: Double? = nil,
        dots: Int? = nil,
        type: String? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        strokePx: Double? = nil,
        octaveShift: Int? = nil,
        clef: ClefName? = nil
    ) {
        guard let parsed = try? StaveNoteStruct(
            parsingKeys: keys,
            duration: duration,
            line: line,
            dots: dots,
            type: type,
            alignCenter: alignCenter,
            durationOverride: durationOverride,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: strokePx,
            octaveShift: octaveShift,
            clef: clef
        ) else { return nil }
        self = parsed
    }

    /// String-key parser for typed duration inputs.
    public init(
        parsingKeys keys: [String],
        duration: NoteDurationSpec = .quarter,
        line: Double? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        strokePx: Double? = nil,
        octaveShift: Int? = nil,
        clef: ClefName? = nil
    ) throws {
        self.init(
            keys: try StaffKeySpec.parseManyNonEmpty(keys),
            duration: duration,
            line: line,
            dots: dots,
            type: type,
            alignCenter: alignCenter,
            durationOverride: durationOverride,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: strokePx,
            octaveShift: octaveShift,
            clef: clef
        )
    }

    /// Failable string-key parser for typed duration inputs.
    public init?(
        parsingKeysOrNil keys: [String],
        duration: NoteDurationSpec = .quarter,
        line: Double? = nil,
        dots: Int? = nil,
        type: NoteType? = nil,
        alignCenter: Bool? = nil,
        durationOverride: Fraction? = nil,
        stemDirection: StemDirection? = nil,
        autoStem: Bool? = nil,
        strokePx: Double? = nil,
        octaveShift: Int? = nil,
        clef: ClefName? = nil
    ) {
        guard let parsed = try? StaveNoteStruct(
            parsingKeys: keys,
            duration: duration,
            line: line,
            dots: dots,
            type: type,
            alignCenter: alignCenter,
            durationOverride: durationOverride,
            stemDirection: stemDirection,
            autoStem: autoStem,
            strokePx: strokePx,
            octaveShift: octaveShift,
            clef: clef
        ) else { return nil }
        self = parsed
    }

        /// Convert to NoteStruct for superclass init.
    func toNoteStruct() -> NoteStruct {
        NoteStruct(
            keys: keys.array.map(\.rawValue), duration: duration, line: line, dots: dots,
            type: type, alignCenter: alignCenter, durationOverride: durationOverride
        )
    }
}

// MARK: - NoteHead Bounds

/// Bounds of the noteheads. Used by the stem, the ledger lines and the bounding box.
public struct StaveNoteHeadBounds {
    public var yTop: Double
    public var yBottom: Double
    public var displacedX: Double?
    public var nonDisplacedX: Double?
    public var highestLine: Double
    public var lowestLine: Double
    public var highestDisplacedLine: Double?
    public var lowestDisplacedLine: Double?
    public var highestNonDisplacedLine: Double
    public var lowestNonDisplacedLine: Double
}

/// Settings used by `StaveNote.format()` (upstream `StaveNoteFormatSettings`).
public struct StaveNoteFormatSettings {
    public var line: Double
    public var maxLine: Double
    public var minLine: Double
    public var isrest: Bool
    public var stemDirection: StemDirection
    public var stemMax: Double
    public var stemMin: Double
    public var voiceShift: Double
    public var isDisplaced: Bool
    public var note: StaveNote
}

public enum StaveNoteError: Error, LocalizedError, Equatable, Sendable {
    case missingGlyph(duration: String, type: String)
    case invalidKeyProperties(String)
    case noKeyProps
    case invalidKeyIndex(Int)
    case unformattedNoteForModifierStart
    case invalidModifierIndex(Int)
    case noYValues
    case unformattedNoteForBoundingBox

    public var errorDescription: String? {
        switch self {
        case .missingGlyph(let duration, let type):
            return "No glyph found for duration '\(duration)' and type '\(type)'."
        case .invalidKeyProperties(let key):
            return "Invalid key for note properties: \(key)"
        case .noKeyProps:
            return "Can't get bottom note line, because note is not initialized properly."
        case .invalidKeyIndex(let index):
            return "Key index out of range: \(index)"
        case .unformattedNoteForModifierStart:
            return "Can't call GetModifierStartXY on an unformatted note"
        case .invalidModifierIndex(let index):
            return "Modifier index out of range: \(index)"
        case .noYValues:
            return "No Y-Values calculated for this note."
        case .unformattedNoteForBoundingBox:
            return "Can't call getBoundingBox on an unformatted note."
        }
    }
}

// Helper methods for rest positioning in ModifierContext.
private func shiftRestVertical(_ rest: inout StaveNoteFormatSettings, _ dir: Double) {
    let delta = dir

    rest.line += delta
    rest.maxLine += delta
    rest.minLine += delta
    rest.note.setKeyLine(0, line: rest.note.getKeyLine(0) + delta)
}

// Called from format(): center a rest between two notes.
private func centerRest(
    _ rest: inout StaveNoteFormatSettings,
    _ noteU: StaveNoteFormatSettings,
    _ noteL: StaveNoteFormatSettings
) {
    let delta = rest.line - midLine(noteU.minLine, noteL.maxLine)
    rest.note.setKeyLine(0, line: rest.note.getKeyLine(0) - delta)
    rest.line -= delta
    rest.maxLine -= delta
    rest.minLine -= delta
}

/// Upstream compares the styles with `JSON.stringify`.
private func isStyleEqual(_ lhs: ElementStyle?, _ rhs: ElementStyle?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case let (lhs?, rhs?):
        return lhs.shadowColor == rhs.shadowColor
            && lhs.shadowBlur == rhs.shadowBlur
            && lhs.fillStyle == rhs.fillStyle
            && lhs.strokeStyle == rhs.strokeStyle
            && lhs.lineWidth == rhs.lineWidth
            && lhs.lineDash == rhs.lineDash
    default:
        return false
    }
}

/// `{ ...base, ...override }` for element styles.
private func mergeStyles(_ base: ElementStyle?, _ override: ElementStyle?) -> ElementStyle {
    var result = base ?? ElementStyle()
    guard let override else { return result }
    if let v = override.shadowColor { result.shadowColor = v }
    if let v = override.shadowBlur { result.shadowBlur = v }
    if let v = override.fillStyle { result.fillStyle = v }
    if let v = override.strokeStyle { result.strokeStyle = v }
    if let v = override.lineWidth { result.lineWidth = v }
    if let v = override.lineDash { result.lineDash = v }
    return result
}

// MARK: - StaveNote

/// Notes for standard notation. A `StaveNote` has one or more `NoteHead`s,
/// an optional stem and an optional flag.
///
/// Here a "note" is the full `StaveNote`, and a "key" is one pitch (notehead)
/// of the note.
open class StaveNote: StemmableNote {

    override open class var category: String { "StaveNote" }

    public static let LEDGER_LINE_OFFSET: Double = 3

    public static var minNoteheadPadding: Double {
        Metrics.getDouble("NoteHead.minPadding")
    }

    // MARK: - Static Format

    /// Format notes inside a ModifierContext.
    @discardableResult
    public static func format(_ notes: [StaveNote], state: inout ModifierContextState) -> Bool {
        if notes.count < 2 { return false }

        var notesList: [StaveNoteFormatSettings] = []

        for note in notes {
            // Formatting uses sortedKeyProps to calculate line and minL.
            let props = note.sortedKeyProps
            let line = props[0].keyProps.line
            var minL = props[props.count - 1].keyProps.line
            let stemDirection = note.getStemDirection()
            let stemMax = note.getStemLength() / 10
            let stemMin = note.getStemMinimumLength() / 10

            let maxL: Double
            if note.isRest() {
                let metrics = note.noteHeads.first?.getTextMetrics() ?? TextMetrics()
                maxL = line + (metrics.actualBoundingBoxAscent / Tables.STAVE_LINE_DISTANCE).rounded(.up)
                minL = line - (metrics.actualBoundingBoxDescent / Tables.STAVE_LINE_DISTANCE).rounded(.up)
            } else {
                maxL = stemDirection == .up
                    ? props[props.count - 1].keyProps.line + stemMax
                    : props[props.count - 1].keyProps.line

                minL = stemDirection == .up ? props[0].keyProps.line : props[0].keyProps.line - stemMax
            }

            notesList.append(StaveNoteFormatSettings(
                line: props[0].keyProps.line, // note/rest base line
                maxLine: maxL, // note/rest upper bounds line
                minLine: minL, // note/rest lower bounds line
                isrest: note.isRest(),
                stemDirection: stemDirection,
                stemMax: stemMax, // Maximum (default) note stem length
                stemMin: stemMin, // minimum note stem length
                voiceShift: note.getVoiceShiftWidth(),
                isDisplaced: note.isDisplaced(), // note manually displaced
                note: note
            ))
        }

        var voices = 0
        var noteU: StaveNoteFormatSettings
        var noteM: StaveNoteFormatSettings?
        var noteL: StaveNoteFormatSettings
        var draw = [false, false, false]

        for i in 0..<min(notesList.count, 3) {
            // If .draw is true or undefined, set draw[i] = true.
            draw[i] = notesList[i].note.renderOptions.draw != false
        }

        if draw[0] && draw[1] && draw[2] {
            // Three visible notes
            voices = 3
            noteU = notesList[0]
            noteM = notesList[1]
            noteL = notesList[2]
        } else if draw[0] && draw[1] {
            // Two visible notes, 0 & 1
            voices = 2
            noteU = notesList[0]
            noteL = notesList[1]
        } else if draw[0] && draw[2] {
            // Two visible notes, 0 & 2
            voices = 2
            noteU = notesList[0]
            noteL = notesList[2]
        } else if draw[1] && draw[2] {
            // Two visible notes, 1 & 2
            voices = 2
            noteU = notesList[1]
            noteL = notesList[2]
        } else {
            // No shift required for less than 2 visible notes
            return true
        }

        // For two voice backward compatibility, ensure upper voice is stems up.
        // For three voices, the voices must be in order (upper, middle, lower).
        if voices == 2 && noteU.stemDirection == .down && noteL.stemDirection == .up {
            noteU = notesList[1]
            noteL = notesList[0]
        }

        let voiceXShift = max(noteU.voiceShift, noteL.voiceShift)
        var xShift: Double = 0

        // Test for two voice note intersection
        if voices == 2 {
            let lineSpacing: Double =
                noteU.note.hasStem() && noteL.note.hasStem() && noteU.stemDirection == noteL.stemDirection ? 0.0 : 0.5
            if noteL.isrest && noteU.isrest && noteU.note.duration == noteL.note.duration {
                noteL.note.renderOptions.draw = false
            } else if noteU.minLine <= noteL.maxLine + lineSpacing {
                if noteU.isrest {
                    // shift rest up
                    shiftRestVertical(&noteU, 1)
                } else if noteL.isrest {
                    // shift rest down
                    shiftRestVertical(&noteL, -1)
                } else {
                    // Instead of shifting notes, remove the appropriate flag.
                    // If we are sharing a line, switch one notes stem direction.
                    // If we are sharing a line and in the same voice, only then offset one note.
                    let lineDiff = abs(noteU.line - noteL.line)
                    if noteU.note.hasStem() && noteL.note.hasStem() {
                        let noteUHead = noteU.note.sortedKeyProps[0].keyProps.code
                        let noteLHead = noteL.note.sortedKeyProps[noteL.note.sortedKeyProps.count - 1].keyProps.code
                        if
                            // If unison is not configured, shift
                            !Tables.UNISON
                            // If we have different noteheads, shift
                            || noteUHead != noteLHead
                            // If we have different dot values, shift
                            || dotCountAtIndexZero(noteU.note) != dotCountAtIndexZero(noteL.note)
                            // If the notes are quite close but not on the same line, shift
                            || (lineDiff < 1 && lineDiff > 0)
                            // If styles are different, shift
                            || !isStyleEqual(noteU.note.getStyle(), noteL.note.getStyle())
                        {
                            xShift = voiceXShift + 2
                            if noteU.stemDirection == noteL.stemDirection {
                                // upper voice is middle voice, so shift it right
                                noteU.note.setXShift(xShift)
                            } else {
                                // shift lower voice right
                                noteL.note.setXShift(xShift)
                            }
                        } else if noteU.note.voice !== noteL.note.voice {
                            // If we are not in the same voice
                            if noteU.stemDirection == noteL.stemDirection {
                                if noteU.line != noteL.line {
                                    xShift = voiceXShift + 2
                                    noteU.note.setXShift(xShift)
                                } else {
                                    // same line, swap stem direction for one note
                                    if noteL.stemDirection == .up {
                                        noteL.stemDirection = .down
                                        noteL.note.setStemDirection(.down)
                                    }
                                }
                            }
                        } // Very close whole notes
                    } else if lineDiff < 1 {
                        xShift = voiceXShift + 2
                        // Upstream compares the duration strings.
                        if noteU.note.duration < noteL.note.duration {
                            // upper voice is shorter, so shift it right
                            noteU.note.setXShift(xShift)
                        } else {
                            // shift lower voice right
                            noteL.note.setXShift(xShift)
                        }
                    } else if noteU.note.hasStem() {
                        noteU.stemDirection = noteU.note.getStemDirection() == .up ? .down : .up
                        noteU.note.setStemDirection(noteU.stemDirection)
                    } else if noteL.note.hasStem() {
                        noteL.stemDirection = noteL.note.getStemDirection() == .up ? .down : .up
                        noteL.note.setStemDirection(noteL.stemDirection)
                    }
                }
            }

            // format complete
            state.rightShift += xShift
            return true
        }

        // Upstream throws 'InvalidState' here. noteM is always set for three voices.
        guard var noteM else { return true }

        // For three voices, test if rests can be repositioned
        //
        // Special case 1 :: middle voice rest between two notes
        //
        if noteM.isrest && !noteU.isrest && !noteL.isrest {
            if noteU.minLine <= noteM.maxLine || noteM.minLine <= noteL.maxLine {
                let restHeight = noteM.maxLine - noteM.minLine
                let space = noteU.minLine - noteL.maxLine
                if restHeight < space {
                    // center middle voice rest between the upper and lower voices
                    centerRest(&noteM, noteU, noteL)
                } else {
                    xShift = voiceXShift + 2 // shift middle rest right
                    noteM.note.setXShift(xShift)
                    if noteL.note.hasBeam() == false {
                        noteL.stemDirection = .down
                        noteL.note.setStemDirection(.down)
                    }
                    if noteU.minLine <= noteL.maxLine && noteU.note.hasBeam() == false {
                        noteU.stemDirection = .up
                        noteU.note.setStemDirection(.up)
                    }
                }
                // format complete
                state.rightShift += xShift
                return true
            }
        }

        // Special case 2 :: all voices are rests
        if noteU.isrest && noteM.isrest && noteL.isrest {
            // Hide upper voice rest
            noteU.note.renderOptions.draw = false
            // Hide lower voice rest
            noteL.note.renderOptions.draw = false
            // format complete
            state.rightShift += xShift
            return true
        }

        // Test if any other rests can be repositioned
        if noteM.isrest && noteU.isrest && noteM.minLine <= noteL.maxLine {
            // Hide middle voice rest
            noteM.note.renderOptions.draw = false
        }
        if noteM.isrest && noteL.isrest && noteU.minLine <= noteM.maxLine {
            // Hide middle voice rest
            noteM.note.renderOptions.draw = false
        }
        if noteU.isrest && noteU.minLine <= noteM.maxLine {
            // shift upper voice rest up
            shiftRestVertical(&noteU, 1)
        }
        if noteL.isrest && noteM.minLine <= noteL.maxLine {
            // shift lower voice rest down
            shiftRestVertical(&noteL, -1)
        }
        // If middle voice intersects upper or lower voice
        if noteU.minLine <= noteM.maxLine + 0.5 || noteM.minLine <= noteL.maxLine {
            // shift middle note right
            xShift = voiceXShift + 2
            noteM.note.setXShift(xShift)
            if noteL.note.hasBeam() == false {
                noteL.stemDirection = .down
                noteL.note.setStemDirection(.down)
            }
            if noteU.minLine <= noteL.maxLine && noteU.note.hasBeam() == false {
                noteU.stemDirection = .up
                noteU.note.setStemDirection(.up)
            }
        }

        state.rightShift += xShift
        return true
    }

    private static func dotCountAtIndexZero(_ note: StaveNote) -> Int {
        note.getModifiers().filter { $0.getCategory() == Dot.category && $0.getIndex() == 0 }.count
    }

    // MARK: - Static PostFormat

    @discardableResult
    public static func postFormat(_ notes: [Note]) -> Bool {
        for note in notes { _ = note.postFormat() }
        return true
    }

    // MARK: - Properties

    public var minLine: Double = 0
    public var maxLine: Double = 0

    public let clef: ClefName
    public let octaveShift: Int

    public var displaced: Bool = false
    public var dotShiftY: Double = 0
    public var useDefaultHeadX: Bool = false
    public var ledgerLineStyle = ElementStyle()

    /// The noteheads, in key order.
    public private(set) var noteHeads: [NoteHead] = []

    /// Sorted variant of keyProps (lowest line first), used internally.
    public private(set) var sortedKeyProps: [(keyProps: KeyProps, index: Int)] = []

    public private(set) var staveInitError: StaveNoteError?

    /// VexFlowPatch: optional padding to the right (e.g. for large lyrics), default 0.
    public var paddingRight: Double = 0

    private func setInitErrorIfNeeded(_ error: StaveNoteError) {
        if staveInitError == nil {
            staveInitError = error
        }
    }

    // MARK: - Init

    public init(_ noteStruct: StaveNoteStruct) {
        self.clef = noteStruct.clef ?? .treble
        self.octaveShift = noteStruct.octaveShift ?? 0

        super.init(noteStruct.toNoteStruct())

        ledgerLineStyle = ElementStyle()

        // Pull note rendering properties.
        glyphProps = Note.getGlyphProps(duration, noteType)

        // if true, displace note to right
        displaced = false
        dotShiftY = 0
        // for displaced ledger lines
        useDefaultHeadX = false

        // Drawing
        noteHeads = []
        modifiers = []

        // number of stroke px to the left and right of head
        renderOptions.strokePx = noteStruct.strokePx ?? StaveNote.LEDGER_LINE_OFFSET

        calculateKeyProps()
        buildStem()

        // Set the stem direction
        if noteStruct.autoStem == true {
            autoStem()
        } else {
            setStemDirection(noteStruct.stemDirection ?? .up)
        }
        reset()
        buildFlag()
    }

    public convenience init(validating noteStruct: StaveNoteStruct) throws {
        self.init(noteStruct)
        if let error = staveInitError {
            throw error
        }
    }

    // MARK: - Reset

    @discardableResult
    override open func reset() -> Self {
        super.reset()

        // Save prior noteHead styles & reapply them after making new noteheads.
        let noteHeadStyles = noteHeads.map { $0.getStyle() }
        // VexFlowPatch: keep notehead types (e.g. slash noteheads) across the rebuild.
        let noteHeadTypes = noteHeads.map { $0.noteType }
        let noteHeadTexts = noteHeads.map { $0.text }
        buildNoteHeads()
        for (index, noteHead) in noteHeads.enumerated() {
            if index < noteHeadStyles.count, let noteHeadStyle = noteHeadStyles[index] {
                noteHead.setStyle(noteHeadStyle)
            }
            // VexFlowPatch: restore a notehead type (and its glyph) that differs from the note type.
            if index < noteHeadTypes.count, noteHeadTypes[index] != noteType {
                noteHead.noteType = noteHeadTypes[index]
                noteHead.text = noteHeadTexts[index]
            }
        }

        if let stave {
            setStave(stave)
        }
        calcNoteDisplacements()
        return self
    }

    // MARK: - Beam

    @discardableResult
    override public func setBeam(_ beam: Beam) -> Self {
        self.beam = beam
        calcNoteDisplacements()
        // Update stem extension if a beam is assigned.
        stem?.setExtension(getStemExtension())
        return self
    }

    // MARK: - Build Stem

    /// Build a `Stem` for the note.
    @discardableResult
    override open func buildStem() -> Self {
        setStem(Stem(options: StemOptions(hide: isRest())))
        return self
    }

    // MARK: - Build NoteHeads

    /// Build a `NoteHead` for each key in the note.
    @discardableResult
    public func buildNoteHeads() -> [NoteHead] {
        let stemDirection = getStemDirection()
        let count = sortedKeyProps.count
        var heads = [NoteHead?](repeating: nil, count: count)

        var lastLine: Double?
        var displaced = false

        // Draw notes from bottom to top.
        // For down-stem notes, draw from top to bottom.
        let start: Int
        let end: Int
        let step: Int
        if stemDirection == Stem.UP {
            start = 0
            end = count
            step = 1
        } else {
            start = count - 1
            end = -1
            step = -1
        }

        var i = start
        while i != end {
            // Building noteheads relies on sortedKeyProps to calculate the displacements.
            let noteProps = sortedKeyProps[i].keyProps
            let line = noteProps.line

            // Keep track of the last line with a notehead, so that consecutive
            // heads are correctly displaced.
            if let last = lastLine {
                let lineDiff = abs(last - line)
                if lineDiff == 0 || lineDiff == 0.5 {
                    displaced = !displaced
                } else {
                    displaced = false
                    useDefaultHeadX = true
                }
            }
            lastLine = line

            let notehead = NoteHead(noteHeadStruct: NoteHeadStruct(
                duration: noteValue,
                line: noteProps.line,
                // VexFlowPatch: TI notehead x offsets (gated in Tables) and
                // notehead y-shift that does not depend on stem length.
                stemDownXOffset: noteProps.stemDownXOffset,
                stemUpXOffset: noteProps.stemUpXOffset,
                stemUpYShift: noteProps.stemUpYShift,
                stemDownYShift: noteProps.stemDownYShift,
                customGlyphCode: noteProps.code,
                stemDirection: stemDirection,
                displaced: displaced,
                noteType: noteTypeValue
            ))

            notehead.fontInfo = fontInfo

            addChild(notehead)
            let index = sortedKeyProps[i].index
            if index < heads.count {
                heads[index] = notehead
            }

            i += step
        }
        noteHeads = heads.compactMap { $0 }
        return noteHeads
    }

    // MARK: - Auto Stem

    /// Set the stem direction from the keys in the note.
    public func autoStem() {
        setStemDirection(calculateOptimalStemDirection())
    }

    public func calculateOptimalStemDirection() -> StemDirection {
        // Figure out the optimal stem direction from the notes.
        // minLine & maxLine rely on sortedKeyProps.
        guard !sortedKeyProps.isEmpty else { return .up }
        minLine = sortedKeyProps[0].keyProps.line
        maxLine = sortedKeyProps[sortedKeyProps.count - 1].keyProps.line

        let MIDDLE_LINE: Double = 3
        let decider = (minLine + maxLine) / 2
        return decider < MIDDLE_LINE ? .up : .down
    }

    // MARK: - Calculate Key Props

    /// Calculate and store the properties of each key in the note.
    public func calculateKeyProps() {
        do {
            try calculateKeyPropsThrowing()
        } catch {
            if let error = error as? StaveNoteError {
                setInitErrorIfNeeded(error)
            }
            let fallback = fallbackKeyProps()
            keyProps = [fallback]
            sortedKeyProps = [(keyProps: fallback, index: 0)]
        }
    }

    public func calculateKeyPropsThrowing() throws {
        keyProps = []
        sortedKeyProps = []

        var lastLine: Double?
        for i in 0..<keys.count {
            let key = keys[i]

            var props: KeyProps
            do {
                props = try Tables.keyProperties(
                    key,
                    clef: clef,
                    type: noteType,
                    octaveShift: octaveShift,
                    duration: duration
                )
            } catch {
                throw StaveNoteError.invalidKeyProperties(key)
            }

            // Override line placement for default rests
            if props.key == "R" {
                if duration == "1" || duration == "w" {
                    props.line = 4
                } else {
                    props.line = 3
                }
            }

            // Calculate displacement of this note
            let line = props.line
            if let prevLine = lastLine {
                // < 1 means == 0.5 (second) or 0.0 (unison)
                if abs(prevLine - line) < 1 {
                    displaced = true
                    props.displaced = true

                    // Mark the previous note as displaced too, for modifier placement.
                    if keyProps.count > 0 {
                        keyProps[i - 1].displaced = true
                    }
                }
            }

            lastLine = line
            keyProps.append(props)
        }

        guard !keyProps.isEmpty else {
            throw StaveNoteError.noKeyProps
        }

        // Sort the notes from lowest line to highest line in sortedKeyProps.
        for (index, kp) in keyProps.enumerated() {
            sortedKeyProps.append((keyProps: kp, index: index))
        }
        sortedKeyProps.sort { $0.keyProps.line < $1.keyProps.line }
    }

    private func fallbackKeyProps() -> KeyProps {
        if let props = try? Tables.keyProperties(
            "b/4", clef: clef, type: noteType, octaveShift: octaveShift, duration: duration
        ) {
            return props
        }
        return KeyProps(key: "B", octave: 4, line: 3, intValue: 59, code: Glyphs.noteheadBlack, displaced: false)
    }

    // MARK: - Bounding Box

    /// The `BoundingBox` of the entire note.
    override public func getBoundingBox() -> BoundingBox? {
        var boundingBox = BoundingBox(x: getAbsoluteX(), y: ys.first ?? 0, w: 0, h: 0)
        for notehead in noteHeads {
            if let bb = notehead.getBoundingBox() {
                _ = boundingBox.mergeWith(bb)
            }
        }
        let bounds = getNoteHeadBounds()

        if !isRest() && hasStem(), let stem {
            let noteStemHeight = stem.getHeight()
            let stemY = getStemDirection() == Stem.DOWN
                ? bounds.yTop - noteStemHeight - flag.getTextMetrics().actualBoundingBoxDescent
                : bounds.yBottom - noteStemHeight + flag.getTextMetrics().actualBoundingBoxAscent
            _ = boundingBox.mergeWith(BoundingBox(x: getAbsoluteX(), y: stemY, w: 0, h: 0))
        }
        if hasFlag(), let bbFlag = flag.getBoundingBox() {
            _ = boundingBox.mergeWith(bbFlag)
        }
        for modifier in modifiers {
            if let bb = modifier.getBoundingBox() {
                _ = boundingBox.mergeWith(bb)
            }
        }
        return boundingBox
    }

    // MARK: - Line Numbers

    /// The line number of the bottom note in the chord.
    /// If `isTopNote` is `true`, the line number of the top note.
    override public func getLineNumber(isTopNote: Bool = false) -> Double {
        (try? getLineNumberThrowing(isTopNote: isTopNote)) ?? 0
    }

    public func getLineNumberThrowing(isTopNote: Bool = false) throws -> Double {
        guard !keyProps.isEmpty else {
            throw StaveNoteError.noKeyProps
        }

        var resultLine = keyProps[0].line

        // No precondition assumed for sortedness of keyProps array
        for kp in keyProps {
            let thisLine = kp.line
            if isTopNote {
                if thisLine > resultLine { resultLine = thisLine }
            } else {
                if thisLine < resultLine { resultLine = thisLine }
            }
        }

        return resultLine
    }

    // MARK: - Rest / Chord / Stem / Flag

    /// True if this note is a rest. Rests have no pitch, but take up space in the score.
    override public func isRest() -> Bool {
        let val = glyphProps.codeHead
        return val >= "\u{E4E0}" && val <= "\u{E4FF}"
    }

    /// True if the note is a chord.
    public func isChord() -> Bool {
        !isRest() && keys.count > 1
    }

    /// True if the note has a stem.
    override public func hasStem() -> Bool {
        glyphProps.stem
    }

    override public func hasFlag() -> Bool {
        super.hasFlag() && !isRest()
    }

    override public func getStemX() -> Double {
        if noteType == "r" {
            return getCenterGlyphX()
        }
        // Adjust the origin of the stem: left-aligned with the notehead if
        // stemmed down, right-aligned if stemmed up.
        let adjust = stemDirection.map { Stem.WIDTH / (2 * -$0.signDouble) } ?? 0
        return super.getStemX() + adjust
    }

    // MARK: - Y for Text

    /// The `y` coordinate for text on the top of a note at a `textLine`.
    override public func getYForTopText(_ textLine: Double) -> Double {
        let extents = getStemExtents()
        return min(
            checkStave().getYForTopText(textLine),
            extents.topY - renderOptions.annotationSpacing * (textLine + 1)
        )
    }

    /// The `y` coordinate for text on the bottom of a note at a `textLine`.
    override public func getYForBottomText(_ textLine: Double) -> Double {
        let extents = getStemExtents()
        return max(
            checkStave().getYForTopText(textLine),
            extents.baseY + renderOptions.annotationSpacing * textLine
        )
    }

    // MARK: - Stave

    /// Set the stave. This applies `y` values to the noteheads.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)

        let ys = noteHeads.map { notehead -> Double in
            notehead.setStave(stave)
            return notehead.getY()
        }

        setYs(ys)

        if let stem {
            let bounds = getNoteHeadBounds()
            stem.setYBounds(bounds.yTop, bounds.yBottom)
        }

        return self
    }

    // MARK: - Displaced

    /// True if the note is shifted to the right.
    public func isDisplaced() -> Bool { displaced }

    /// Set if the note is shifted to the right.
    @discardableResult
    public func setNoteDisplaced(_ displaced: Bool) -> Self {
        self.displaced = displaced
        return self
    }

    // MARK: - Tie Positions

    /// The start `x` coordinate for a `StaveTie`.
    override public func getTieRightX() -> Double {
        var tieStartX = getAbsoluteX()
        tieStartX += getGlyphWidth() + xShift + rightDisplacedHeadPx
        if let mc = modifierContext {
            tieStartX += mc.getRightShift()
        }
        return tieStartX
    }

    /// The end `x` coordinate for a `StaveTie`.
    override public func getTieLeftX() -> Double {
        var tieEndX = getAbsoluteX()
        tieEndX += xShift - leftDisplacedHeadPx
        return tieEndX
    }

    /// The stave line for a rest.
    override public func getLineForRest() -> Double {
        guard !keyProps.isEmpty else { return 0 }
        var restLine = keyProps[0].line
        if keyProps.count > 1 {
            let lastLine = keyProps[keyProps.count - 1].line
            let top = max(restLine, lastLine)
            let bot = min(restLine, lastLine)
            restLine = midLine(top, bot)
        }

        return restLine
    }

    // MARK: - Modifier Start XY

    /// The default `x` and `y` coordinates for a `position` and key `index`.
    /// Does not throw; see `getModifierStartXYThrowing`.
    override public func getModifierStartXY(
        position: ModifierPosition,
        index: Int,
        forceFlagRight: Bool = false
    ) -> (x: Double, y: Double) {
        (try? getModifierStartXYThrowing(position: position, index: index, forceFlagRight: forceFlagRight)) ?? (
            x: getAbsoluteX(),
            y: ys.first ?? 0
        )
    }

    override public func getModifierStartXYThrowing(
        position: ModifierPosition,
        index: Int,
        forceFlagRight: Bool = false
    ) throws -> (x: Double, y: Double) {
        guard preFormatted else {
            throw StaveNoteError.unformattedNoteForModifierStart
        }
        guard !ys.isEmpty else {
            throw StaveNoteError.noYValues
        }
        guard index >= 0 && index < ys.count && index < noteHeads.count else {
            throw StaveNoteError.invalidModifierIndex(index)
        }

        var x: Double = 0
        switch position {
        case .left:
            // FIXME: Left modifier padding, move to font file
            x = -1 * 2
        case .right:
            // FIXME: Right modifier padding, move to font file
            x = getGlyphWidth() + xShift + 2

            if stemDirection == Stem.UP && hasFlag() && (forceFlagRight || isInnerNoteIndex(index)) {
                x += flag.getWidth()
            }
        case .below, .above:
            x = getGlyphWidth() / 2
        case .center:
            break
        }

        // Additional y shifts for rests
        var restShift: Double = 0
        switch noteHeads[index].getText() {
        case Glyphs.restDoubleWhole, Glyphs.restWhole:
            restShift += 0.5
        case Glyphs.restHalf, Glyphs.restQuarter, Glyphs.rest8th, Glyphs.rest16th:
            restShift -= 0.5
        case Glyphs.rest32nd, Glyphs.rest64th:
            restShift -= 1.5
        case Glyphs.rest128th:
            restShift -= 2.5
        default:
            break
        }

        return (
            x: getAbsoluteX() + x,
            y: ys[index] + restShift * checkStave().getSpacingBetweenLines()
        )
    }

    private func isInnerNoteIndex(_ index: Int) -> Bool {
        index == (getStemDirection() == Stem.UP ? keyProps.count - 1 : 0)
    }

    // MARK: - Styles

    /// Set the style of the full StaveNote, all keys and the stem included.
    @discardableResult
    override public func setStyle(_ style: ElementStyle?) -> Self {
        guard let style else { return super.setStyle(nil) }
        return setGroupStyle(style)
    }

    @discardableResult
    public func setStemStyle(_ style: ElementStyle) -> Self {
        getStem()?.setStyle(style)
        return self
    }

    public func getStemStyle() -> ElementStyle? {
        stem?.getStyle()
    }

    public func setLedgerLineStyle(_ style: ElementStyle) {
        ledgerLineStyle = style
    }

    public func getLedgerLineStyle() -> ElementStyle {
        ledgerLineStyle
    }

    public func setFlagStyle(_ style: ElementStyle) {
        flag.setStyle(style)
    }

    public func getFlagStyle() -> ElementStyle? {
        flag.getStyle()
    }

    /// The glyph width.
    override public func getGlyphWidth() -> Double {
        noteHeads.first?.getWidth() ?? 0
    }

    /// Set the style of the notehead at `index`.
    @discardableResult
    public func setKeyStyle(_ index: Int, style: ElementStyle) -> Self {
        _ = try? setKeyStyleThrowing(index, style: style)
        return self
    }

    @discardableResult
    public func setKeyStyleThrowing(_ index: Int, style: ElementStyle) throws -> Self {
        guard index >= 0 && index < noteHeads.count else {
            throw StaveNoteError.invalidKeyIndex(index)
        }
        noteHeads[index].setStyle(style)
        return self
    }

    // MARK: - Key Line

    @discardableResult
    public func setKeyLine(_ index: Int, line: Double) -> Self {
        _ = try? setKeyLineThrowing(index, line: line)
        return self
    }

    public func getKeyLine(_ index: Int) -> Double {
        (try? getKeyLineThrowing(index)) ?? 0
    }

    @discardableResult
    public func setKeyLineThrowing(_ index: Int, line: Double) throws -> Self {
        guard index >= 0 && index < keyProps.count else {
            throw StaveNoteError.invalidKeyIndex(index)
        }
        keyProps[index].line = line
        // Upstream sortedKeyProps holds references to the same objects (not re-sorted).
        for j in sortedKeyProps.indices where sortedKeyProps[j].index == index {
            sortedKeyProps[j].keyProps.line = line
        }
        reset()
        return self
    }

    public func getKeyLineThrowing(_ index: Int) throws -> Double {
        guard index >= 0 && index < keyProps.count else {
            throw StaveNoteError.invalidKeyIndex(index)
        }
        return keyProps[index].line
    }

    // MARK: - Displacements

    /// The width of the note if it is displaced. Used for `Voice` formatting.
    public func getVoiceShiftWidth() -> Double {
        // TODO: may need to accommodate for dot here.
        getGlyphWidth() * (displaced ? 2 : 1)
    }

    /// Calculate and set the extra pixels to the left or right if the note is displaced.
    public func calcNoteDisplacements() {
        setLeftDisplacedHeadPx(displaced && stemDirection == Stem.DOWN ? getGlyphWidth() : 0)

        // For upstems with flags, the extra space is unnecessary, since it's
        // taken up by the flag.
        setRightDisplacedHeadPx(!hasFlag() && displaced && stemDirection == Stem.UP ? getGlyphWidth() : 0)
    }

    // MARK: - PreFormat

    /// Pre-render formatting.
    override public func preFormat() {
        if preFormatted { return }

        var noteHeadPadding: Double = 0
        if let mc = modifierContext {
            mc.preFormat()
            // If there are no modifiers on this note, make sure there is
            // adequate padding between the notes.
            if mc.getWidth() == 0 {
                noteHeadPadding = StaveNote.minNoteheadPadding
            }
        }

        // VexFlowPatch: add optional paddingRight (e.g. for large lyrics), default 0.
        var width = getGlyphWidth() + leftDisplacedHeadPx + rightDisplacedHeadPx + noteHeadPadding + paddingRight

        // For upward flagged notes, the width of the flag needs to be added
        if shouldDrawFlag() && stemDirection == Stem.UP {
            width += getGlyphWidth()
            // TODO: Add flag width as a separate metric
        }

        setWidth(width)
        preFormatted = true
    }

    // MARK: - NoteHead Bounds

    /// The staff line and y value of the highest and lowest noteheads.
    public func getNoteHeadBounds() -> StaveNoteHeadBounds {
        // Top and bottom Y values for stem.
        var yTop = Double.infinity
        var yBottom = -Double.infinity
        var nonDisplacedX: Double?
        var displacedX: Double?

        var highestLine = Double(checkStave().getNumLines())
        var lowestLine: Double = 1
        var highestDisplacedLine: Double?
        var lowestDisplacedLine: Double?
        var highestNonDisplacedLine = highestLine
        var lowestNonDisplacedLine = lowestLine

        for notehead in noteHeads {
            let line = notehead.getLine()
            let y = notehead.getY()

            yTop = min(y, yTop)
            yBottom = max(y, yBottom)

            if displacedX == nil && notehead.isDisplaced() {
                displacedX = notehead.getAbsoluteX()
            }

            if nonDisplacedX == nil && !notehead.isDisplaced() {
                nonDisplacedX = notehead.getAbsoluteX()
            }

            highestLine = max(line, highestLine)
            lowestLine = min(line, lowestLine)

            if notehead.isDisplaced() {
                highestDisplacedLine = highestDisplacedLine.map { max(line, $0) } ?? line
                lowestDisplacedLine = lowestDisplacedLine.map { min(line, $0) } ?? line
            } else {
                highestNonDisplacedLine = max(line, highestNonDisplacedLine)
                lowestNonDisplacedLine = min(line, lowestNonDisplacedLine)
            }
        }

        return StaveNoteHeadBounds(
            yTop: yTop,
            yBottom: yBottom,
            displacedX: displacedX,
            nonDisplacedX: nonDisplacedX,
            highestLine: highestLine,
            lowestLine: lowestLine,
            highestDisplacedLine: highestDisplacedLine,
            lowestDisplacedLine: lowestDisplacedLine,
            highestNonDisplacedLine: highestNonDisplacedLine,
            lowestNonDisplacedLine: lowestNonDisplacedLine
        )
    }

    /// The start `x` coordinate of the noteheads.
    public func getNoteHeadBeginX() -> Double {
        getAbsoluteX() + xShift
    }

    /// The end `x` coordinate of the noteheads.
    public func getNoteHeadEndX() -> Double {
        let xBegin = getNoteHeadBeginX()
        return xBegin + getGlyphWidth()
    }

    // MARK: - Draw Ledger Lines

    /// Draw the ledger lines between the stave and the highest/lowest keys.
    public func drawLedgerLines() throws {
        let stave = checkStave()
        let strokePx = renderOptions.strokePx
        let ctx = try checkContext()
        let width = getGlyphWidth() + strokePx * 2
        let doubleWidth = 2 * (getGlyphWidth() + strokePx) - Stem.WIDTH / 2

        if isRest() { return }

        let bounds = getNoteHeadBounds()
        let highestLine = bounds.highestLine
        let lowestLine = bounds.lowestLine
        let highestDisplacedLine = bounds.highestDisplacedLine
        let highestNonDisplacedLine = bounds.highestNonDisplacedLine
        let lowestDisplacedLine = bounds.lowestDisplacedLine
        let lowestNonDisplacedLine = bounds.lowestNonDisplacedLine
        let displacedX = bounds.displacedX
        let nonDisplacedX = bounds.nonDisplacedX

        // Early out if there are no ledger lines to draw.
        if highestLine < 6 && lowestLine > 0 { return }

        let minX = min(displacedX ?? 0, nonDisplacedX ?? 0)

        func drawLedgerLine(_ y: Double, _ normal: Bool, _ displaced: Bool) {
            let x: Double
            if displaced && normal { x = minX - strokePx }
            else if normal { x = (nonDisplacedX ?? 0) - strokePx }
            else { x = (displacedX ?? 0) - strokePx }
            let ledgerWidth = normal && displaced ? doubleWidth : width

            ctx.beginPath()
            ctx.moveTo(x, y)
            ctx.lineTo(x + ledgerWidth, y)
            ctx.stroke()
        }

        let style = mergeStyles(stave.getDefaultLedgerLineStyle(), getLedgerLineStyle())
        ctx.save()
        applyStyle(context: ctx, style: style)
        // VexFlowPatch: wrap the ledger lines in an SVG group (gated for upstream parity).
        let groupLedgers = !VexRuntime.getCurrentContext().upstreamParityMode
        if groupLedgers {
            _ = ctx.openGroup("ledgers", (getAttribute("id") ?? "") + "ledgers")
        }

        // Draw ledger lines below the staff:
        var line: Double = 6
        while line <= highestLine {
            let normal = nonDisplacedX != nil && line <= highestNonDisplacedLine
            let displaced = highestDisplacedLine.map { line <= $0 } ?? false
            drawLedgerLine(stave.getYForNote(line), normal, displaced)
            line += 1
        }

        // Draw ledger lines above the staff:
        line = 0
        while line >= lowestLine {
            let normal = nonDisplacedX != nil && line >= lowestNonDisplacedLine
            let displaced = lowestDisplacedLine.map { line >= $0 } ?? false
            drawLedgerLine(stave.getYForNote(line), normal, displaced)
            line -= 1
        }

        // VexFlowPatch: close the ledger lines SVG group.
        if groupLedgers { ctx.closeGroup() }
        ctx.restore()
    }

    // MARK: - Draw Modifiers

    /// Draw all key modifiers of `noteheadParam`.
    public func drawModifiers(_ noteheadParam: NoteHead) throws {
        let ctx = try checkContext()
        for modifier in modifiers {
            let index = modifier.checkIndex()
            guard index >= 0 && index < noteHeads.count else { continue }
            let notehead = noteHeads[index]
            if notehead === noteheadParam {
                modifier.setContext(ctx)
                try modifier.drawWithStyle()
            }
        }
    }

    // MARK: - Flag

    public func shouldDrawFlag() -> Bool {
        let hasStem = stem != nil
        let hasFlag = glyphProps.codeFlagUp != nil
        let hasNoBeam = beam == nil
        return hasStem && hasFlag && hasNoBeam && !isRest()
    }

    /// Draw the flag of the note.
    public func drawFlag() throws {
        let ctx = try checkContext()

        if shouldDrawFlag() {
            let bounds = getNoteHeadBounds()

            let noteStemHeight = stem?.getHeight() ?? 0
            let flagX = getStemX() - Tables.STEM_WIDTH / 2
            let flagY = getStemDirection() == Stem.DOWN
                // Down stems are below the notehead and have flags on the right.
                ? bounds.yTop - noteStemHeight - flag.getTextMetrics().actualBoundingBoxDescent
                // Up stems are above the notehead and have flags on the right.
                : bounds.yBottom - noteStemHeight + flag.getTextMetrics().actualBoundingBoxAscent

            // Draw the Flag
            try flag.setContext(ctx).setX(flagX).setY(flagY).drawWithStyle()
        }
    }

    // MARK: - Draw NoteHeads

    /// Draw the noteheads.
    public func drawNoteHeads() throws {
        let ctx = try checkContext()
        for notehead in noteHeads {
            try notehead.setContext(ctx).drawWithStyle()
        }
    }

    // MARK: - Draw Stem

    /// Draw the stem.
    override public func drawStem(_ stemOptions: StemOptions? = nil) throws {
        let ctx = try checkContext()

        if let stemOptions {
            setStem(Stem(options: stemOptions))
        }

        // If we render a flag, shorten the stem so that the tip does not
        // poke through the flag.
        if shouldDrawFlag(), let stem {
            stem.adjustHeightForFlag()
        }

        if let stem {
            try stem.setContext(ctx).drawWithStyle()
        }
    }

    @available(*, deprecated, renamed: "drawStem(_:)")
    public func drawStemForNote(_ stemOptions: StemOptions? = nil) throws {
        try drawStem(stemOptions)
    }

    // MARK: - Stem Extension Override

    /// Adjust the stem extension for the distance from the middle line.
    override public func getStemExtension() -> Double {
        let superStemExtension = super.getStemExtension()
        if !glyphProps.stem {
            return superStemExtension
        }

        let stemDirection = getStemDirection()
        if stemDirection != calculateOptimalStemDirection() {
            return superStemExtension // no adjustment for manually set stem direction.
        }
        let midLineDistance: Double
        let MIDDLE_LINE: Double = 3
        if stemDirection == Stem.UP {
            // Use maxLine instead of minLine: for a treble clef chord (F2, E4)
            // with stem up, do not extend the stem because of F2; a normal
            // octave-length stem above E4 is fine.
            //
            // calculateOptimalStemDirection() sets maxLine and minLine.
            midLineDistance = MIDDLE_LINE - maxLine
        } else {
            midLineDistance = minLine - MIDDLE_LINE
        }

        // How many lines more than an octave is the relevant notehead?
        let linesOverOctaveFromMidLine = midLineDistance - 3.5
        if linesOverOctaveFromMidLine <= 0 {
            return superStemExtension
        }
        var spacingBetweenLines: Double = 10
        if let stave = getStave() {
            spacingBetweenLines = stave.getSpacingBetweenLines()
        }
        return superStemExtension + linesOverOctaveFromMidLine * spacingBetweenLines
    }

    // MARK: - Draw

    /// Draw all the parts of the `StaveNote`. This is the main drawing method.
    override public func draw() throws {
        if renderOptions.draw == false { return }

        guard !ys.isEmpty else {
            throw StaveNoteError.noYValues
        }

        let ctx = try checkContext()
        let xBegin = getNoteHeadBeginX()
        let shouldRenderStem = hasStem() && beam == nil

        // Format note head x positions
        for notehead in noteHeads {
            notehead.setX(xBegin)
        }

        if let stem {
            // Format stem x positions
            let stemX = getStemX()
            stem.setNoteHeadXBounds(stemX, stemX)
        }

        // Apply the overall style -- may be contradicted by local settings:
        _ = ctx.openGroup("stavenote", getAttribute("id"))
        try drawLedgerLines()
        if shouldRenderStem { try drawStem() }
        try drawNoteHeads()
        try drawFlag()
        if let bb = getBoundingBox() {
            ctx.pointerRect(bb.getX(), bb.getY(), bb.getW(), bb.getH())
        }
        ctx.closeGroup()
        setRendered()
    }
}
