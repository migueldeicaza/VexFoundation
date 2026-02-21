// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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
    public var stemDownXOffset: Double?
    public var stemUpXOffset: Double?
    public var strokePx: Double?
    public var glyphFontScale: Double?
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
        stemDownXOffset: Double? = nil,
        stemUpXOffset: Double? = nil,
        strokePx: Double? = nil,
        glyphFontScale: Double? = nil,
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
        self.stemDownXOffset = stemDownXOffset
        self.stemUpXOffset = stemUpXOffset
        self.strokePx = strokePx
        self.glyphFontScale = glyphFontScale
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
        stemDownXOffset: Double? = nil,
        stemUpXOffset: Double? = nil,
        strokePx: Double? = nil,
        glyphFontScale: Double? = nil,
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
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            strokePx: strokePx,
            glyphFontScale: glyphFontScale,
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
        stemDownXOffset: Double? = nil,
        stemUpXOffset: Double? = nil,
        strokePx: Double? = nil,
        glyphFontScale: Double? = nil,
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
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            strokePx: strokePx,
            glyphFontScale: glyphFontScale,
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
        stemDownXOffset: Double? = nil,
        stemUpXOffset: Double? = nil,
        strokePx: Double? = nil,
        glyphFontScale: Double? = nil,
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
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            strokePx: strokePx,
            glyphFontScale: glyphFontScale,
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
        stemDownXOffset: Double? = nil,
        stemUpXOffset: Double? = nil,
        strokePx: Double? = nil,
        glyphFontScale: Double? = nil,
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
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            strokePx: strokePx,
            glyphFontScale: glyphFontScale,
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
        stemDownXOffset: Double? = nil,
        stemUpXOffset: Double? = nil,
        strokePx: Double? = nil,
        glyphFontScale: Double? = nil,
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
            stemDownXOffset: stemDownXOffset,
            stemUpXOffset: stemUpXOffset,
            strokePx: strokePx,
            glyphFontScale: glyphFontScale,
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

/// Bounds info for noteheads, used by stem, ledger lines, and bounding box.
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
            return "Can't get line number without key properties."
        case .invalidKeyIndex(let index):
            return "Key index out of range: \(index)"
        case .unformattedNoteForModifierStart:
            return "Can't call getModifierStartXY on an unformatted note."
        case .invalidModifierIndex(let index):
            return "Modifier index out of range: \(index)"
        case .noYValues:
            return "No Y-values calculated for this note."
        case .unformattedNoteForBoundingBox:
            return "Can't call getBoundingBox on an unformatted note."
        }
    }
}

// MARK: - StaveNote

/// The main class for rendering standard notes on a stave.
/// Manages noteheads, stems, flags, ledger lines, and modifiers.
public class StaveNote: StemmableNote {

    override public class var category: String { "StaveNote" }

    public static let LEDGER_LINE_OFFSET: Double = 3

    public static var minNoteheadPadding: Double {
        let musicFont = Glyph.MUSIC_FONT_STACK.first
        return (musicFont?.lookupMetric("noteHead.minPadding") as? Double) ?? 2
    }

    // MARK: - Properties

    public var minLine: Double = 0
    public var maxLine: Double = 0
    public let clef: ClefName
    public let octaveShift: Int
    public var displaced: Bool = false
    public var dotShiftY: Double = 0
    public var useDefaultHeadX: Bool = false
    public var ledgerLineStyle: ElementStyle?
    public var noteHeads: [NoteHead] = []
    public var sortedKeyProps: [(keyProps: KeyProps, index: Int)] = []
    public private(set) var staveInitError: StaveNoteError?

    private static func fallbackGlyphProps() -> GlyphProps {
        Tables.getGlyphProps(duration: .quarter, type: .note) ?? GlyphProps(
            codeHead: "noteheadBlack",
            stem: true,
            flag: false,
            rest: false,
            position: "B/4",
            dotShiftY: 0,
            lineAbove: 0,
            lineBelow: 0,
            beamCount: 0,
            codeFlagUpstem: nil,
            codeFlagDownstem: nil,
            stemUpExtension: 0,
            stemDownExtension: 0,
            stemBeamExtension: 0,
            tabnoteStemUpExtension: 0,
            tabnoteStemDownExtension: 0
        )
    }

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

        // Refresh glyph props with resolved duration/type
        if let resolvedGlyphProps = Tables.getGlyphProps(duration: noteDuration, type: noteType) {
            glyphProps = resolvedGlyphProps
        } else {
            glyphProps = Self.fallbackGlyphProps()
            setInitErrorIfNeeded(.missingGlyph(duration: noteDuration, type: noteType))
        }

        renderOptions.glyphFontScale = noteStruct.glyphFontScale ?? Tables.NOTATION_FONT_SCALE
        renderOptions.strokePx = noteStruct.strokePx ?? StaveNote.LEDGER_LINE_OFFSET

        noteModifiers = []

        calculateKeyProps()
        _ = buildStem()

        if noteStruct.autoStem == true {
            autoStem()
        } else {
            _ = setStemDirection(noteStruct.stemDirection ?? .up)
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
    public func reset() -> Self {
        let noteHeadStyles = noteHeads.map { $0.getStyle() }
        buildNoteHeads()
        for (index, noteHead) in noteHeads.enumerated() {
            if index < noteHeadStyles.count, let style = noteHeadStyles[index] {
                noteHead.setStyle(style)
            }
        }
        if let stave = noteStave {
            _ = setStave(stave)
        }
        calcNoteDisplacements()
        return self
    }

    // MARK: - Build Stem

    @discardableResult
    override public func buildStem() -> Self {
        _ = setStem(Stem(options: StemOptions(hide: isRest())))
        return self
    }

    // MARK: - Build NoteHeads

    @discardableResult
    public func buildNoteHeads() -> Self {
        noteHeads = []
        guard !sortedKeyProps.isEmpty else { return self }
        let dir = getStemDirection()
        let keyCount = keys.count

        var lastLine: Double?
        var isDisplaced = false

        let start: Int
        let end: Int
        let step: Int
        if dir == Stem.UP {
            start = 0; end = keyCount; step = 1
        } else {
            start = keyCount - 1; end = -1; step = -1
        }

        var i = start
        while i != end {
            let noteProps = sortedKeyProps[i].keyProps
            let line = noteProps.line

            if let lastLine {
                let lineDiff = abs(lastLine - line)
                if lineDiff == 0 || lineDiff == 0.5 {
                    isDisplaced = !isDisplaced
                } else {
                    isDisplaced = false
                    useDefaultHeadX = true
                }
            }
            lastLine = line

            let notehead = NoteHead(noteHeadStruct: NoteHeadStruct(
                duration: noteValue,
                line: noteProps.line,
                glyphFontScale: renderOptions.glyphFontScale,
                customGlyphCode: (noteProps.code?.isEmpty ?? true) ? nil : noteProps.code,
                xShift: noteProps.shiftRight,
                stemDirection: dir,
                displaced: isDisplaced,
                noteType: noteTypeValue,
                keys: keys,
                dots: nil
            ))

            addChildElement(notehead)
            // Store at the original (unsorted) index
            let originalIndex = sortedKeyProps[i].index
            if noteHeads.count <= originalIndex {
                noteHeads.append(contentsOf: Array(repeating: notehead, count: originalIndex - noteHeads.count + 1))
            }
            noteHeads[originalIndex] = notehead

            i += step
        }
        return self
    }

    // MARK: - Calculate Key Props

    public func calculateKeyProps() {
        do {
            try calculateKeyPropsThrowing()
        } catch let error as StaveNoteError {
            setInitErrorIfNeeded(error)
            let fallback = fallbackKeyProps()
            keyProps = [fallback]
            sortedKeyProps = [(keyProps: fallback, index: 0)]
        } catch {
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

            if glyphProps.rest {
                glyphProps.position = key
            }

            var props: KeyProps
            do {
                props = try Tables.keyProperties(
                    key,
                    clef: clef,
                    octaveShift: octaveShift,
                    duration: noteDuration
                )
            } catch {
                throw StaveNoteError.invalidKeyProperties(key)
            }

            // Override line placement for default rests
            if props.key == "R" {
                props.line = (noteDuration == "1" || noteDuration == "w") ? 4 : 3
            }

            // Detect displacement for seconds
            let line = props.line
            if let prevLine = lastLine {
                if abs(prevLine - line) == 0.5 {
                    displaced = true
                    props.displaced = true
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
        sortKeyProps()
    }

    private func fallbackKeyProps() -> KeyProps {
        if let props = try? Tables.keyProperties("b/4", clef: clef, octaveShift: octaveShift, duration: noteDuration) {
            return props
        }
        return KeyProps(
            key: "b/4",
            octave: 4,
            line: 3,
            intValue: 59,
            accidental: nil,
            code: nil,
            stroke: 0,
            shiftRight: 0,
            displaced: false
        )
    }

    private func sortKeyProps() {
        sortedKeyProps = []
        for (index, kp) in keyProps.enumerated() {
            sortedKeyProps.append((keyProps: kp, index: index))
        }
        sortedKeyProps.sort { $0.keyProps.line < $1.keyProps.line }
    }

    // MARK: - Auto Stem

    public func autoStem() {
        _ = setStemDirection(calculateOptimalStemDirection())
    }

    public func calculateOptimalStemDirection() -> StemDirection {
        guard !sortedKeyProps.isEmpty, !keyProps.isEmpty else {
            return .up
        }
        minLine = sortedKeyProps[0].keyProps.line
        maxLine = sortedKeyProps[keyProps.count - 1].keyProps.line

        let MIDDLE_LINE: Double = 3
        let decider = (minLine + maxLine) / 2
        return decider < MIDDLE_LINE ? .up : .down
    }

    // MARK: - Rest / Chord / Stem / Flag

    override public func isRest() -> Bool {
        glyphProps.rest
    }

    public func isChord() -> Bool {
        !isRest() && keys.count > 1
    }

    override public func hasStem() -> Bool {
        glyphProps.stem
    }

    override public func hasFlag() -> Bool {
        super.hasFlag() && !isRest()
    }

    // MARK: - Stem X

    override public func getStemX() -> Double {
        if noteType == "r" {
            return getCenterGlyphX()
        }
        let direction = getStemDirection()
        return super.getStemX() + Stem.WIDTH / (2 * -direction.signDouble)
    }

    // MARK: - Displaced

    public func isDisplaced() -> Bool { displaced }

    @discardableResult
    public func setNoteDisplaced(_ displaced: Bool) -> Self {
        self.displaced = displaced
        return self
    }

    // MARK: - Stave

    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        _ = super.setStave(stave)

        let ys = noteHeads.map { noteHead -> Double in
            _ = noteHead.setStave(stave)
            return noteHead.getHeadY()
        }
        _ = setYs(ys)

        if let stem {
            let bounds = getNoteHeadBounds()
            stem.setYBounds(bounds.yTop, bounds.yBottom)
        }

        return self
    }

    // MARK: - Line Numbers

    override public func getLineNumber(isTopNote: Bool = false) -> Double {
        (try? getLineNumberThrowing(isTopNote: isTopNote)) ?? 0
    }

    public func getLineNumberThrowing(isTopNote: Bool = false) throws -> Double {
        guard !keyProps.isEmpty else {
            throw StaveNoteError.noKeyProps
        }
        var resultLine = keyProps[0].line
        for kp in keyProps {
            if isTopNote {
                if kp.line > resultLine { resultLine = kp.line }
            } else {
                if kp.line < resultLine { resultLine = kp.line }
            }
        }
        return resultLine
    }

    override public func getLineForRest() -> Double {
        guard !keyProps.isEmpty else { return 0 }
        var restLine = keyProps[0].line
        if keyProps.count > 1 {
            let lastLine = keyProps[keyProps.count - 1].line
            let top = max(restLine, lastLine)
            let bot = min(restLine, lastLine)
            restLine = (top + bot) / 2
        }
        return restLine
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
        sortKeyProps()
        reset()
        return self
    }

    public func getKeyLineThrowing(_ index: Int) throws -> Double {
        guard index >= 0 && index < keyProps.count else {
            throw StaveNoteError.invalidKeyIndex(index)
        }
        return keyProps[index].line
    }

    // MARK: - Voice Shift Width

    public func getVoiceShiftWidth() -> Double {
        getGlyphWidth() * (displaced ? 2 : 1)
    }

    // MARK: - Note Displacements

    public func calcNoteDisplacements() {
        _ = setLeftDisplacedHeadPx(displaced && stemDirection == Stem.DOWN ? getGlyphWidth() : 0)
        _ = setRightDisplacedHeadPx(!hasFlag() && displaced && stemDirection == Stem.UP ? getGlyphWidth() : 0)
    }

    // MARK: - Modifier Start XY

    public func getModifierStartXY(position: ModifierPosition, index: Int, forceFlagRight: Bool = false) -> (x: Double, y: Double) {
        (try? getModifierStartXYThrowing(position: position, index: index, forceFlagRight: forceFlagRight)) ?? (
            x: getAbsoluteX(),
            y: ys.first ?? 0
        )
    }

    public func getModifierStartXYThrowing(
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
        guard index >= 0 && index < ys.count else {
            throw StaveNoteError.invalidModifierIndex(index)
        }

        var x: Double = 0
        switch position {
        case .left:
            x = -1 * 2
        case .right:
            x = getGlyphWidth() + xShift + 2
            if stemDirection == Stem.UP && hasFlag()
                && (forceFlagRight || isInnerNoteIndex(index)) {
                x += flag?.getMetrics().width ?? 0
            }
        case .above, .below:
            x = getGlyphWidth() / 2
        case .center:
            break
        }

        return (x: getAbsoluteX() + x, y: ys[index])
    }

    private func isInnerNoteIndex(_ index: Int) -> Bool {
        index == (getStemDirection() == Stem.UP ? keyProps.count - 1 : 0)
    }

    // MARK: - First Dot Px

    /// Returns the x offset for the first dot after the notehead.
    public func getFirstDotPx() -> Double {
        var dotX = getGlyphWidth() + xShift + 2
        if stemDirection == Stem.UP && hasFlag() {
            dotX += flag?.getMetrics().width ?? 0
        }
        return dotX
    }

    // MARK: - Ledger Line Style

    public func setLedgerLineStyle(_ style: ElementStyle) {
        ledgerLineStyle = style
    }

    public func getLedgerLineStyle() -> ElementStyle? {
        ledgerLineStyle
    }

    // MARK: - Stem Style

    @discardableResult
    public func setStemStyle(_ style: ElementStyle) -> Self {
        stem?.setStyle(style)
        return self
    }

    public func getStemStyle() -> ElementStyle? {
        stem?.getStyle()
    }

    // MARK: - Flag Style

    public func setFlagStyle(_ style: ElementStyle) {
        flag?.setStyle(style)
    }

    public func getFlagStyle() -> ElementStyle? {
        flag?.getStyle()
    }

    // MARK: - Key Style

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

    // MARK: - NoteHead Bounds

    public func getNoteHeadBounds() -> StaveNoteHeadBounds {
        if noteHeads.isEmpty {
            let line = getLineNumber()
            return StaveNoteHeadBounds(
                yTop: 0,
                yBottom: 0,
                displacedX: nil,
                nonDisplacedX: getAbsoluteX(),
                highestLine: line,
                lowestLine: line,
                highestDisplacedLine: nil,
                lowestDisplacedLine: nil,
                highestNonDisplacedLine: line,
                lowestNonDisplacedLine: line
            )
        }

        var yTop = Double.infinity
        var yBottom = -Double.infinity
        var displacedX: Double?
        var nonDisplacedX: Double?

        let numLines = Double(noteStave?.getNumLines() ?? 5)
        var highestLine = numLines
        var lowestLine: Double = 1
        var highestDisplacedLine: Double?
        var lowestDisplacedLine: Double?
        var highestNonDisplacedLine = highestLine
        var lowestNonDisplacedLine = lowestLine

        for notehead in noteHeads {
            let line = notehead.getLine()
            let y = notehead.getHeadY()

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
                highestDisplacedLine = max(line, highestDisplacedLine ?? line)
                lowestDisplacedLine = min(line, lowestDisplacedLine ?? line)
            } else {
                highestNonDisplacedLine = max(line, highestNonDisplacedLine)
                lowestNonDisplacedLine = min(line, lowestNonDisplacedLine)
            }
        }

        return StaveNoteHeadBounds(
            yTop: yTop, yBottom: yBottom,
            displacedX: displacedX, nonDisplacedX: nonDisplacedX,
            highestLine: highestLine, lowestLine: lowestLine,
            highestDisplacedLine: highestDisplacedLine,
            lowestDisplacedLine: lowestDisplacedLine,
            highestNonDisplacedLine: highestNonDisplacedLine,
            lowestNonDisplacedLine: lowestNonDisplacedLine
        )
    }

    // MARK: - NoteHead X

    public func getNoteHeadBeginX() -> Double {
        getAbsoluteX() + xShift
    }

    public func getNoteHeadEndX() -> Double {
        getNoteHeadBeginX() + getGlyphWidth()
    }

    // MARK: - Should Draw Flag

    public func shouldDrawFlag() -> Bool {
        stem != nil && glyphProps.flag && beam == nil
    }

    // MARK: - Stave Note Scale

    public func getStaveNoteScale() -> Double { 1.0 }

    // MARK: - Stem Extension Override

    override public func getStemExtension() -> Double {
        let superExt = super.getStemExtension()
        if !glyphProps.stem { return superExt }

        let dir = getStemDirection()
        if dir != calculateOptimalStemDirection() {
            return superExt
        }

        let MIDDLE_LINE: Double = 3
        let midLineDistance: Double
        if dir == Stem.UP {
            midLineDistance = MIDDLE_LINE - maxLine
        } else {
            midLineDistance = minLine - MIDDLE_LINE
        }

        let linesOverOctave = midLineDistance - 3.5
        if linesOverOctave <= 0 { return superExt }

        let spacing = noteStave?.getSpacingBetweenLines() ?? 10
        return superExt + linesOverOctave * spacing
    }

    // MARK: - Tie Positions

    override public func getTieRightX() -> Double {
        var tieStartX = getAbsoluteX()
        tieStartX += getGlyphWidth() + xShift + rightDisplacedHeadPx
        if let mc = modifierContext {
            tieStartX += mc.getRightShift()
        }
        return tieStartX
    }

    override public func getTieLeftX() -> Double {
        var tieEndX = getAbsoluteX()
        tieEndX += xShift - leftDisplacedHeadPx
        return tieEndX
    }

    // MARK: - PreFormat

    override public func preFormat() {
        if preFormatted { return }

        var noteHeadPadding: Double = 0
        if let mc = modifierContext {
            mc.preFormat()
            if mc.getWidth() == 0 {
                noteHeadPadding = StaveNote.minNoteheadPadding
            }
        }

        var width = getGlyphWidth() + leftDisplacedHeadPx + rightDisplacedHeadPx + noteHeadPadding

        if shouldDrawFlag() && stemDirection == Stem.UP {
            width += getGlyphWidth()
        }

        setTickableWidth(width)
        preFormatted = true
    }

    // MARK: - Bounding Box

    override public func getBoundingBox() -> BoundingBox? {
        try? getBoundingBoxThrowing()
    }

    public func getBoundingBoxThrowing() throws -> BoundingBox? {
        guard preFormatted else {
            throw StaveNoteError.unformattedNoteForBoundingBox
        }
        guard !ys.isEmpty else {
            throw StaveNoteError.noYValues
        }

        let metrics = try getMetricsThrowing()
        let x = getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let halfLineSpacing = (noteStave?.getSpacingBetweenLines() ?? 0) / 2
        let lineSpacing = halfLineSpacing * 2

        var minY: Double = 0
        var maxY: Double = 0

        if isRest() {
            let y = ys[0]
            let frac = Tables.durationToFraction(noteDuration)
            if frac == Fraction(1, 1) || frac == Fraction(2, 1) {
                minY = y - halfLineSpacing
                maxY = y + halfLineSpacing
            } else {
                minY = y - glyphProps.lineAbove * lineSpacing
                maxY = y + glyphProps.lineBelow * lineSpacing
            }
        } else if glyphProps.stem {
            var extents = try getStemExtentsThrowing()
            extents.baseY += halfLineSpacing * getStemDirection().signDouble
            minY = min(extents.topY, extents.baseY)
            maxY = max(extents.topY, extents.baseY)
        } else {
            for (i, yy) in ys.enumerated() {
                if i == 0 {
                    minY = yy
                    maxY = yy
                } else {
                    minY = min(yy, minY)
                    maxY = max(yy, maxY)
                }
            }
            minY -= halfLineSpacing
            maxY += halfLineSpacing
        }

        return BoundingBox(x: x, y: minY, w: metrics.width, h: maxY - minY)
    }

    // MARK: - Static Format (for ModifierContext)

    @discardableResult
    public static func format(_ notes: [StaveNote], state: inout ModifierContextState) -> Bool {
        if notes.count < 2 { return false }

        struct FormatSettings {
            var line: Double
            var maxLine: Double
            var minLine: Double
            var isRest: Bool
            var stemDirection: StemDirection
            var stemMax: Double
            var stemMin: Double
            var voiceShift: Double
            var isDisplaced: Bool
            var note: StaveNote
        }

        var notesList: [FormatSettings] = []

        for note in notes {
            let props = note.sortedKeyProps
            let line = props[0].keyProps.line
            var minL = props[props.count - 1].keyProps.line
            let dir = note.getStemDirection()
            let stemMax = note.getStemLength() / 10
            let stemMin = note.getStemMinimumLength() / 10

            let maxL: Double
            if note.isRest() {
                maxL = line + note.glyphProps.lineAbove
                minL = line - note.glyphProps.lineBelow
            } else {
                maxL = dir == .up
                    ? props[props.count - 1].keyProps.line + stemMax
                    : props[props.count - 1].keyProps.line
                minL = dir == .up
                    ? props[0].keyProps.line
                    : props[0].keyProps.line - stemMax
            }

            notesList.append(FormatSettings(
                line: props[0].keyProps.line,
                maxLine: maxL, minLine: minL,
                isRest: note.isRest(),
                stemDirection: dir,
                stemMax: stemMax, stemMin: stemMin,
                voiceShift: note.getVoiceShiftWidth(),
                isDisplaced: note.isDisplaced(),
                note: note
            ))
        }

        func shiftRestVertical(rest: inout FormatSettings, dir: Double) {
            rest.line += dir
            rest.maxLine += dir
            rest.minLine += dir
            rest.note.setKeyLine(0, line: rest.note.getKeyLine(0) + dir)
        }

        func centerRest(rest: inout FormatSettings, upper: FormatSettings, lower: FormatSettings) {
            let delta = rest.line - midLine(upper.minLine, lower.maxLine)
            rest.note.setKeyLine(0, line: rest.note.getKeyLine(0) - delta)
            rest.line -= delta
            rest.maxLine -= delta
            rest.minLine -= delta
        }

        func isStyleEqual(_ lhs: ElementStyle?, _ rhs: ElementStyle?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (lhs?, rhs?):
                return lhs.shadowColor == rhs.shadowColor
                    && lhs.shadowBlur == rhs.shadowBlur
                    && lhs.fillStyle == rhs.fillStyle
                    && lhs.strokeStyle == rhs.strokeStyle
                    && lhs.lineWidth == rhs.lineWidth
            default:
                return false
            }
        }

        func dotCountAtIndexZero(_ note: StaveNote) -> Int {
            note.getModifiers().reduce(0) { count, modifier in
                guard modifier is Dot, modifier.getIndex() == 0 else { return count }
                return count + 1
            }
        }

        // Determine visible notes at this tick context.
        var voices = 0
        var noteU: FormatSettings?
        var noteM: FormatSettings?
        var noteL: FormatSettings?
        let draw = notesList.map { $0.note.renderOptions.draw }

        if notesList.count >= 3 && draw[0] && draw[1] && draw[2] {
            voices = 3
            noteU = notesList[0]
            noteM = notesList[1]
            noteL = notesList[2]
        } else if draw.count >= 2 && draw[0] && draw[1] {
            voices = 2
            noteU = notesList[0]
            noteL = notesList[1]
        } else if notesList.count >= 3 && draw[0] && draw[2] {
            voices = 2
            noteU = notesList[0]
            noteL = notesList[2]
        } else if notesList.count >= 3 && draw[1] && draw[2] {
            voices = 2
            noteU = notesList[1]
            noteL = notesList[2]
        } else {
            return true
        }

        guard var u = noteU, var l = noteL else { return true }

        // For two voices, ensure upper voice has stems up.
        if voices == 2 && u.stemDirection == .down && l.stemDirection == .up {
            swap(&u, &l)
        }

        let voiceXShift = max(u.voiceShift, l.voiceShift)
        var xShift: Double = 0

        if voices == 2 {
            let lineSpacing: Double =
                u.note.hasStem() && l.note.hasStem() && u.stemDirection == l.stemDirection ? 0.0 : 0.5

            if l.isRest && u.isRest && u.note.noteDuration == l.note.noteDuration {
                l.note.renderOptions.draw = false
            } else if u.minLine <= l.maxLine + lineSpacing {
                if u.isRest {
                    shiftRestVertical(rest: &u, dir: 1)
                } else if l.isRest {
                    shiftRestVertical(rest: &l, dir: -1)
                } else {
                    let lineDiff = abs(u.line - l.line)
                    if u.note.hasStem() && l.note.hasStem() {
                        let uHeadCode = Tables.codeNoteHead(
                            (u.note.sortedKeyProps.first?.keyProps.code ?? "N").uppercased(),
                            duration: u.note.noteDuration
                        )
                        let lHeadCode = Tables.codeNoteHead(
                            (l.note.sortedKeyProps.last?.keyProps.code ?? "N").uppercased(),
                            duration: l.note.noteDuration
                        )

                        if !Tables.UNISON
                            || uHeadCode != lHeadCode
                            || dotCountAtIndexZero(u.note) != dotCountAtIndexZero(l.note)
                            || (lineDiff > 0 && lineDiff < 1)
                            || !isStyleEqual(u.note.getStyle(), l.note.getStyle())
                        {
                            xShift = voiceXShift + 2
                            if u.stemDirection == l.stemDirection {
                                u.note.setXShift(xShift)
                            } else {
                                l.note.setXShift(xShift)
                            }
                        } else {
                            let sameVoice: Bool = {
                                guard let uVoice = u.note.voice, let lVoice = l.note.voice else { return false }
                                return uVoice === lVoice
                            }()

                            if !sameVoice && u.stemDirection == l.stemDirection {
                                if u.line != l.line {
                                    xShift = voiceXShift + 2
                                    u.note.setXShift(xShift)
                                } else if l.stemDirection == .up {
                                    l.stemDirection = .down
                                    _ = l.note.setStemDirection(.down)
                                }
                            }
                        }
                    } else if lineDiff < 1 {
                        xShift = voiceXShift + 2
                        if u.note.getTicks().value() < l.note.getTicks().value() {
                            u.note.setXShift(xShift)
                        } else {
                            l.note.setXShift(xShift)
                        }
                    } else if u.note.hasStem() {
                        let flipped: StemDirection = u.note.getStemDirection() == .up ? .down : .up
                        u.stemDirection = flipped
                        _ = u.note.setStemDirection(flipped)
                    } else if l.note.hasStem() {
                        let flipped: StemDirection = l.note.getStemDirection() == .up ? .down : .up
                        l.stemDirection = flipped
                        _ = l.note.setStemDirection(flipped)
                    }
                }
            }

            state.rightShift += xShift
            return true
        }

        guard voices == 3, var m = noteM else {
            state.rightShift += xShift
            return true
        }

        // Special case: middle rest between two notes.
        if m.isRest && !u.isRest && !l.isRest {
            if u.minLine <= m.maxLine || m.minLine <= l.maxLine {
                let restHeight = m.maxLine - m.minLine
                let space = u.minLine - l.maxLine

                if restHeight < space {
                    centerRest(rest: &m, upper: u, lower: l)
                } else {
                    xShift = voiceXShift + 2
                    m.note.setXShift(xShift)

                    if !l.note.hasBeam() {
                        l.stemDirection = .down
                        _ = l.note.setStemDirection(.down)
                    }
                    if u.minLine <= l.maxLine && !u.note.hasBeam() {
                        u.stemDirection = .up
                        _ = u.note.setStemDirection(.up)
                    }
                }

                state.rightShift += xShift
                return true
            }
        }

        // Special case: all three voices are rests.
        if u.isRest && m.isRest && l.isRest {
            u.note.renderOptions.draw = false
            l.note.renderOptions.draw = false
            state.rightShift += xShift
            return true
        }

        if m.isRest && u.isRest && m.minLine <= l.maxLine {
            m.note.renderOptions.draw = false
        }
        if m.isRest && l.isRest && u.minLine <= m.maxLine {
            m.note.renderOptions.draw = false
        }
        if u.isRest && u.minLine <= m.maxLine {
            shiftRestVertical(rest: &u, dir: 1)
        }
        if l.isRest && m.minLine <= l.maxLine {
            shiftRestVertical(rest: &l, dir: -1)
        }

        if u.minLine <= m.maxLine + 0.5 || m.minLine <= l.maxLine {
            xShift = voiceXShift + 2
            m.note.setXShift(xShift)

            if !l.note.hasBeam() {
                l.stemDirection = .down
                _ = l.note.setStemDirection(.down)
            }
            if u.minLine <= l.maxLine && !u.note.hasBeam() {
                u.stemDirection = .up
                _ = u.note.setStemDirection(.up)
            }
        }

        state.rightShift += xShift
        return true
    }

    // MARK: - Static PostFormat

    @discardableResult
    public static func postFormat(_ notes: [Note]) -> Bool {
        for note in notes { _ = note.postFormat() }
        return true
    }

    // MARK: - Draw

    override public func draw() throws {
        guard renderOptions.draw else { return }
        guard !ys.isEmpty else {
            throw StaveNoteError.noYValues
        }

        let ctx = try checkContext()
        let xBegin = getNoteHeadBeginX()
        let shouldRenderStem = hasStem() && beam == nil

        // Position noteheads
        for notehead in noteHeads {
            notehead.setHeadX(xBegin)
        }

        // Position stem
        if let stem {
            let stemX = getStemX()
            stem.setNoteHeadXBounds(stemX, stemX)
        }

        applyStyle()
        _ = ctx.openGroup("stavenote", getAttribute("id"))

        try drawLedgerLines()
        if shouldRenderStem { try drawStemForNote() }
        try drawNoteHeads()
        try drawFlag()

        ctx.closeGroup()
        restoreStyle()
        setRendered()
    }

    // MARK: - Draw Ledger Lines

    public func drawLedgerLines() throws {
        let stave = checkStave()
        let ctx = try checkContext()
        let strokePx = renderOptions.strokePx
        let glyphWidth = getGlyphWidth()
        let width = glyphWidth + strokePx * 2
        let doubleWidth = 2 * (glyphWidth + strokePx) - Stem.WIDTH / 2

        if isRest() { return }

        let bounds = getNoteHeadBounds()
        if bounds.highestLine < 6 && bounds.lowestLine > 0 { return }

        let minX = min(bounds.displacedX ?? 0, bounds.nonDisplacedX ?? 0)

        func drawLine(y: Double, normal: Bool, displaced: Bool) {
            let x: Double
            if displaced && normal { x = minX - strokePx }
            else if normal { x = (bounds.nonDisplacedX ?? 0) - strokePx }
            else { x = (bounds.displacedX ?? 0) - strokePx }
            let ledgerWidth = normal && displaced ? doubleWidth : width

            ctx.beginPath()
            ctx.moveTo(x, y)
            ctx.lineTo(x + ledgerWidth, y)
            ctx.stroke()
        }

        // Ledger lines below the staff (lines 6, 7, 8, ...)
        var line = 6.0
        while line <= bounds.highestLine {
            let normal = bounds.nonDisplacedX != nil && line <= bounds.highestNonDisplacedLine
            let disp = bounds.highestDisplacedLine != nil && line <= (bounds.highestDisplacedLine ?? 0)
            drawLine(y: stave.getYForNote(line), normal: normal, displaced: disp)
            line += 1
        }

        // Ledger lines above the staff (lines 0, -1, -2, ...)
        line = 0
        while line >= bounds.lowestLine {
            let normal = bounds.nonDisplacedX != nil && line >= bounds.lowestNonDisplacedLine
            let disp = bounds.lowestDisplacedLine != nil && line >= (bounds.lowestDisplacedLine ?? 0)
            drawLine(y: stave.getYForNote(line), normal: normal, displaced: disp)
            line -= 1
        }
    }

    // MARK: - Draw NoteHeads

    public func drawNoteHeads() throws {
        let ctx = try checkContext()
        for notehead in noteHeads {
            notehead.applyStyle()
            _ = ctx.openGroup("notehead", notehead.getAttribute("id"))
            notehead.setContext(ctx)
            try notehead.draw()
            drawModifiers(notehead)
            ctx.closeGroup()
            notehead.restoreStyle()
        }
    }

    // MARK: - Draw Modifiers

    public func drawModifiers(_ noteheadParam: NoteHead) {
        for modifier in noteModifiers {
            guard let index = modifier.getIndex(),
                  index < noteHeads.count else { continue }
            let notehead = noteHeads[index]
            if notehead === noteheadParam {
                if let ctx = getContext() {
                    modifier.setContext(ctx)
                    try? modifier.drawWithStyle()
                }
            }
        }
    }

    // MARK: - Draw Stem (for note)

    public func drawStemForNote(_ stemOptions: StemOptions? = nil) throws {
        let ctx = try checkContext()

        if let opts = stemOptions {
            _ = setStem(Stem(options: opts))
        }

        if shouldDrawFlag(), let stem {
            stem.adjustHeightForFlag()
        }

        if let stem {
            stem.setContext(ctx)
            try stem.draw()
        }
    }

    // MARK: - Draw Flag

    public func drawFlag() throws {
        let context = try checkContext()

        if shouldDrawFlag() {
            guard let stem else { return }
            let bounds = getNoteHeadBounds()
            let noteStemHeight = stem.getHeight()
            let flagX = getStemX()
            let scale = getStaveNoteScale()

            let flagY: Double
            if getStemDirection() == Stem.DOWN {
                flagY = bounds.yTop - noteStemHeight + 2
                    - glyphProps.stemDownExtension * scale
                    - (flag?.getMetrics().yShift ?? 0) * (1 - scale)
            } else {
                flagY = bounds.yBottom - noteStemHeight - 2
                    + glyphProps.stemUpExtension * scale
                    - (flag?.getMetrics().yShift ?? 0) * (1 - scale)
            }

            flag?.render(ctx: context, x: flagX, y: flagY)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/w, D5/h, E5/q, F5/8, G5/16, A5/16"))]
        )).addClef(.treble).addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
