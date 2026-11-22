// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/stave.ts` (VexFlow 5.0.0).

import Foundation

public enum StaveError: Error, LocalizedError, Equatable, Sendable {
    case lineNumberOutOfRange(Int)
    case invalidLineConfigCount(expected: Int, actual: Int)
    case invalidRepetitionType(String)
    case invalidVoltaType(String)
    case invalidModifierPosition(String)
    case invalidTextJustification(String)
    case invalidTempoDuration(String)

    public var errorDescription: String? {
        switch self {
        case .lineNumberOutOfRange:
            return "The line number must be within the range of the number of lines in the Stave."
        case .invalidLineConfigCount:
            return "The length of the lines configuration array must match the number of lines in the Stave"
        case .invalidRepetitionType(let value):
            return "Invalid repetition type: '\(value)'."
        case .invalidVoltaType(let value):
            return "Invalid volta type: '\(value)'."
        case .invalidModifierPosition(let value):
            return "Invalid stave modifier position: '\(value)'."
        case .invalidTextJustification(let value):
            return "Invalid stave text justification: '\(value)'."
        case .invalidTempoDuration(let value):
            return "Invalid stave tempo duration: '\(value)'."
        }
    }
}

// MARK: - Stave Options

/// Configuration for individual stave lines.
public struct StaveLineConfig {
    public var visible: Bool

    public init(visible: Bool = true) {
        self.visible = visible
    }
}

/// Configuration options for a Stave.
public struct StaveOptions {
    public var bottomTextPosition: Int
    public var lineConfig: [StaveLineConfig]
    public var spaceBelowStaffLn: Int
    public var spaceAboveStaffLn: Int
    public var verticalBarWidth: Double
    public var leftBar: Bool
    public var rightBar: Bool
    public var spacingBetweenLinesPx: Double {
        didSet { spacingBetweenLinesPxWasSpecified = true }
    }
    public var topTextPosition: Int
    public var numLines: Int
    /// True when `spacingBetweenLinesPx` was given (commit 252b9a7). `TabStave` uses
    /// this to emulate the JavaScript `{ spacingBetweenLinesPx: 13, ...options }` merge.
    var spacingBetweenLinesPxWasSpecified: Bool

    public init(
        bottomTextPosition: Int = 4,
        lineConfig: [StaveLineConfig] = [],
        spaceBelowStaffLn: Int = 4,
        spaceAboveStaffLn: Int = 4,
        verticalBarWidth: Double = 10,
        leftBar: Bool = true,
        rightBar: Bool = true,
        spacingBetweenLinesPx: Double? = nil,
        topTextPosition: Int = 1,
        numLines: Int = 5
    ) {
        self.bottomTextPosition = bottomTextPosition
        self.lineConfig = lineConfig
        self.spaceBelowStaffLn = spaceBelowStaffLn
        self.spaceAboveStaffLn = spaceAboveStaffLn
        self.verticalBarWidth = verticalBarWidth
        self.leftBar = leftBar
        self.rightBar = rightBar
        self.spacingBetweenLinesPx = spacingBetweenLinesPx ?? Tables.STAVE_LINE_DISTANCE
        self.topTextPosition = topTextPosition
        self.numLines = numLines
        self.spacingBetweenLinesPxWasSpecified = spacingBetweenLinesPx != nil
    }
}

/// Typed options for `StaveText` placement helpers.
public struct StaveTextOptions: Sendable {
    public var shiftX: Double
    public var shiftY: Double
    public var justification: StaveTextJustification

    public init(shiftX: Double = 0, shiftY: Double = 0, justification: StaveTextJustification = .center) {
        self.shiftX = shiftX
        self.shiftY = shiftY
        self.justification = justification
    }
}

// MARK: - Sort Orders

// Used by Stave.format() to sort the modifiers at the beginning and end of a stave.
// The keys match the category of the Barline, Clef, KeySignature, TimeSignature classes.
private let SORT_ORDER_BEG_MODIFIERS: [String: Int] = [
    "Barline": 0,
    "Clef": 1,
    "KeySignature": 2,
    "TimeSignature": 3,
]

private let SORT_ORDER_END_MODIFIERS: [String: Int] = [
    "TimeSignature": 0,
    "KeySignature": 1,
    "Barline": 2,
    "Clef": 3,
]

// MARK: - Stave

/// Main stave class. Manages modifiers, calculates layout, and renders staff lines.
///
/// `x`, `y`, `width` and `height` are stored in `VexElement`.
open class Stave: VexElement {

    override open class var category: String { "Stave" }

    /// This is the sum of the padding that normally goes on left + right of a stave during
    /// drawing. Used to size staves correctly with content width.
    public static var defaultPadding: Double {
        Metrics.getDouble("Stave.padding") + Metrics.getDouble("Stave.endPaddingMax")
    }

    /// Right padding, used by system if startX is already determined.
    public static var rightPadding: Double {
        Metrics.getDouble("Stave.endPaddingMax")
    }

    // MARK: - Properties

    public var options: StaveOptions
    public var startX: Double
    public var endX: Double
    public var clefName: ClefName = .treble
    public var endClefName: ClefName?
    public var formatted: Bool = false
    public var measure: Int = 0
    public var modifiers: [StaveModifier] = []
    public var defaultLedgerLineStyle: ElementStyle

    // MARK: - Init

    public init(x: Double, y: Double, width: Double, options: StaveOptions? = nil) {
        self.startX = x + 5
        self.endX = x + width
        self.options = options ?? StaveOptions()
        self.defaultLedgerLineStyle = ElementStyle(strokeStyle: "#444", lineWidth: 2)
        super.init(category: nil)

        self.x = x
        self.y = y
        self.width = width
        self.formatted = false
        self.modifiers = [] // stave modifiers (clef, key, time, barlines, coda, segno, etc.)
        self.measure = 0
        self.clefName = .treble
        self.endClefName = nil

        resetLines()

        // beg bar
        addModifier(Barline(self.options.leftBar ? .single : .none))
        // end bar
        addEndModifier(Barline(self.options.rightBar ? .single : .none))
    }

    // MARK: - Ledger Lines

    /// Set default style for ledger lines.
    public func setDefaultLedgerLineStyle(_ style: ElementStyle) {
        defaultLedgerLineStyle = style
    }

    /// Get default style for ledger lines.
    public func getDefaultLedgerLineStyle() -> ElementStyle {
        var s = getStyle() ?? ElementStyle()
        let d = defaultLedgerLineStyle
        if let v = d.shadowColor { s.shadowColor = v }
        if let v = d.shadowBlur { s.shadowBlur = v }
        if let v = d.fillStyle { s.fillStyle = v }
        if let v = d.strokeStyle { s.strokeStyle = v }
        if let v = d.lineWidth { s.lineWidth = v }
        if let v = d.lineDash { s.lineDash = v }
        return s
    }

    // MARK: - Lines

    /// Convert staff line units to pixels.
    public func space(_ spacing: Double) -> Double {
        options.spacingBetweenLinesPx * spacing
    }

    public func resetLines() {
        options.lineConfig = []
        for _ in 0..<max(0, options.numLines) {
            options.lineConfig.append(StaveLineConfig(visible: true))
        }
        height = Double(options.numLines + options.spaceAboveStaffLn) * options.spacingBetweenLinesPx
        options.bottomTextPosition = options.numLines
    }

    // MARK: - Note Positions

    @discardableResult
    public func setNoteStartX(_ x: Double) -> Self {
        if !formatted { format() }

        startX = x
        return self
    }

    public func getNoteStartX() -> Double {
        if !formatted { format() }

        return startX
    }

    public func getNoteEndX() -> Double {
        if !formatted { format() }

        return endX
    }

    public func getTieStartX() -> Double { startX }

    public func getTieEndX() -> Double { endX }

    public func getNumLines() -> Int { options.numLines }

    @discardableResult
    public func setNumLines(_ n: Int) -> Self {
        options.numLines = n
        resetLines()
        return self
    }

    public func getTopLineTopY() -> Double {
        getYForLine(0)
    }

    public func getBottomLineBottomY() -> Double {
        getYForLine(Double(getNumLines() - 1)) + (getStyle()?.lineWidth ?? 1)
    }

    // MARK: - Position & Dimensions

    @discardableResult
    override open func setX(_ x: Double) -> Self {
        let shift = x - self.x
        formatted = false
        self.x = x
        startX += shift
        endX += shift
        for mod in modifiers {
            mod.setX(mod.getX() + shift)
        }
        return self
    }

    @discardableResult
    override open func setWidth(_ width: Double) -> Self {
        formatted = false
        self.width = width
        endX = x + width

        // reset the x position of the end barline (TODO(0xfe): This makes no sense)
        // this.modifiers[1].setX(this.endX);
        return self
    }

    /// Set the measure number of this Stave.
    @discardableResult
    public func setMeasure(_ measure: Int) -> Self {
        self.measure = measure
        return self
    }

    /// Return the measure number of this Stave.
    public func getMeasure() -> Int { measure }

    /// Gets the pixels to shift from the beginning of the stave
    /// following the modifier at the provided index.
    public func getModifierXShift(_ index: Int = 0) -> Double {
        if !formatted { format() }

        if getModifiers(position: .begin).count == 1 {
            return 0
        }

        // for right position modifiers zero shift seems correct, see 'Volta + Modifier Measure Test'
        // Upstream reads `this.modifiers[index]` without a range check.
        if index >= 0 && index < modifiers.count && modifiers[index].getPosition() == .right {
            return 0
        }

        var startX = self.startX - x
        if let begBarline = modifiers.first as? Barline,
           begBarline.getType() == .repeatBegin && startX > begBarline.getWidth() {
            startX -= begBarline.getWidth()
        }

        return startX
    }

    // MARK: - Coda & Segno

    /// Add a repetition marker (Coda & Segno Symbol functions).
    @discardableResult
    public func setRepetitionType(_ type: RepetitionType, yShift: Double = 0) -> Self {
        modifiers.append(StaveRepetition(type: type, x: x, yShift: yShift))
        return self
    }

    /// String convenience variant that throws on invalid repetition labels.
    @discardableResult
    public func setRepetitionType(parsing type: String, yShift: Double = 0) throws -> Self {
        guard let parsed = RepetitionType(parsing: type) else {
            throw StaveError.invalidRepetitionType(type)
        }
        return setRepetitionType(parsed, yShift: yShift)
    }

    /// String convenience variant that returns nil on invalid repetition labels.
    @discardableResult
    public func setRepetitionType(parsingOrNil type: String, yShift: Double = 0) -> Self? {
        guard let parsed = RepetitionType(parsing: type) else { return nil }
        return setRepetitionType(parsed, yShift: yShift)
    }

    // MARK: - Volta

    /// Add a volta bracket.
    @discardableResult
    public func setVoltaType(_ type: VoltaType, number label: String, yShift y: Double) -> Self {
        modifiers.append(Volta(type: type, number: label, x: x, yShift: y))
        return self
    }

    /// String convenience variant that throws on invalid volta labels.
    @discardableResult
    public func setVoltaType(parsing type: String, number: String, yShift: Double) throws -> Self {
        guard let parsed = VoltaType(parsing: type) else {
            throw StaveError.invalidVoltaType(type)
        }
        return setVoltaType(parsed, number: number, yShift: yShift)
    }

    /// String convenience variant that returns nil on invalid volta labels.
    @discardableResult
    public func setVoltaType(parsingOrNil type: String, number: String, yShift: Double) -> Self? {
        guard let parsed = VoltaType(parsing: type) else { return nil }
        return setVoltaType(parsed, number: number, yShift: yShift)
    }

    // MARK: - Section

    /// Add a section label.
    @discardableResult
    public func setSection(_ section: String, y: Double, xOffset: Double = 0, fontSize: Double? = nil,
                           drawRect: Bool = true) -> Self {
        let staveSection = StaveSection(section: section).setYShift(y).setXShift(xOffset).setDrawRect(drawRect)
        if let fontSize, fontSize != 0 {
            staveSection.setFontSize(fontSize)
        }
        addModifier(staveSection)
        return self
    }

    // MARK: - Tempo

    /// Add a tempo marking.
    @discardableResult
    public func setTempo(_ tempo: StaveTempoOptions, y: Double) -> Self {
        modifiers.append(StaveTempo(tempo: tempo, x: x, shiftY: y))
        return self
    }

    /// String convenience variant that throws on invalid duration tokens.
    @discardableResult
    public func setTempo(parsingDuration duration: String?, bpm: Int? = nil, dots: Int? = nil,
                         name: String? = nil, y: Double) throws -> Self {
        let options: StaveTempoOptions
        do {
            options = try StaveTempoOptions(bpm: bpm, duration: duration, dots: dots, name: name)
        } catch {
            throw StaveError.invalidTempoDuration(duration ?? "")
        }
        return setTempo(options, y: y)
    }

    /// String convenience variant that returns nil on invalid duration tokens.
    @discardableResult
    public func setTempo(parsingDurationOrNil duration: String?, bpm: Int? = nil, dots: Int? = nil,
                         name: String? = nil, y: Double) -> Self? {
        guard let options = StaveTempoOptions(parsingDuration: duration, bpm: bpm, dots: dots, name: name) else {
            return nil
        }
        return setTempo(options, y: y)
    }

    // MARK: - Text

    /// Add stave text using typed position and options.
    @discardableResult
    public func setStaveText(_ text: String, position: StaveModifierPosition,
                             options: StaveTextOptions = StaveTextOptions()) -> Self {
        modifiers.append(StaveText(
            text: text,
            position: position,
            shiftX: options.shiftX,
            shiftY: options.shiftY,
            justification: options.justification
        ))
        return self
    }

    /// String convenience variant that throws on invalid position / justification labels.
    @discardableResult
    public func setStaveText(_ text: String, parsingPosition position: String, shiftX: Double = 0, shiftY: Double = 0,
                             parsingJustification justification: String = "center") throws -> Self {
        guard let parsedPosition = StaveModifierPosition(parsing: position) else {
            throw StaveError.invalidModifierPosition(position)
        }
        guard let parsedJustification = StaveTextJustification(parsing: justification) else {
            throw StaveError.invalidTextJustification(justification)
        }
        return setStaveText(text, position: parsedPosition, options: StaveTextOptions(
            shiftX: shiftX,
            shiftY: shiftY,
            justification: parsedJustification
        ))
    }

    /// String convenience variant that returns nil on invalid position / justification labels.
    @discardableResult
    public func setStaveText(_ text: String, parsingPositionOrNil position: String, shiftX: Double = 0,
                             shiftY: Double = 0, parsingJustificationOrNil justification: String = "center") -> Self? {
        guard let parsedPosition = StaveModifierPosition(parsing: position) else { return nil }
        guard let parsedJustification = StaveTextJustification(parsing: justification) else { return nil }
        return setStaveText(text, position: parsedPosition, options: StaveTextOptions(
            shiftX: shiftX,
            shiftY: shiftY,
            justification: parsedJustification
        ))
    }

    @available(*, deprecated, renamed: "setStaveText(_:position:options:)")
    @discardableResult
    public func setText(_ text: String, position: StaveModifierPosition,
                        options: StaveTextOptions = StaveTextOptions()) -> Self {
        setStaveText(text, position: position, options: options)
    }

    // MARK: - Y Coordinates

    public func getSpacingBetweenLines() -> Double { options.spacingBetweenLinesPx }

    override open func getBoundingBox() -> BoundingBox? {
        BoundingBox(x: x, y: y, w: width, h: getBottomY() - y)
    }

    public func getBottomY() -> Double {
        let spacing = options.spacingBetweenLinesPx
        let scoreBottom = getYForLine(Double(options.numLines)) + Double(options.spaceBelowStaffLn) * spacing
        return scoreBottom
    }

    public func getBottomLineY() -> Double {
        getYForLine(Double(options.numLines))
    }

    /// Returns the y for the *center* of a staff line.
    public func getYForLine(_ line: Double) -> Double {
        let spacing = options.spacingBetweenLinesPx
        let headroom = Double(options.spaceAboveStaffLn)

        let y = self.y + line * spacing + headroom * spacing

        return y
    }

    /// The reverse of `getYForLine`.
    public func getLineForY(_ y: Double) -> Double {
        let spacing = options.spacingBetweenLinesPx
        let headroom = Double(options.spaceAboveStaffLn)
        return (y - self.y) / spacing - headroom
    }

    public func getYForTopText(_ line: Double = 0) -> Double {
        getYForLine(-line - Double(options.topTextPosition))
    }

    public func getYForBottomText(_ line: Double = 0) -> Double {
        getYForLine(Double(options.bottomTextPosition) + line)
    }

    public func getYForNote(_ line: Double) -> Double {
        let spacing = options.spacingBetweenLinesPx
        let headroom = Double(options.spaceAboveStaffLn)
        return y + headroom * spacing + 5 * spacing - line * spacing
    }

    open func getYForGlyphs() -> Double {
        getYForLine(3)
    }

    // MARK: - Modifier Management

    /// Add a stave modifier to the stave. The first two modifiers (barlines)
    /// are added automatically upon construction.
    @discardableResult
    public func addModifier(_ modifier: StaveModifier, position: StaveModifierPosition? = nil) -> Self {
        if let position {
            modifier.setPosition(position)
        }

        modifier.setStave(self)
        formatted = false
        modifiers.append(modifier)
        return self
    }

    @discardableResult
    public func addEndModifier(_ modifier: StaveModifier) -> Self {
        addModifier(modifier, position: .end)
        return self
    }

    // MARK: - Barline Functions

    @discardableResult
    public func setBegBarType(_ type: BarlineType) -> Self {
        // Only valid bar types at beginning of stave is none, single or begin repeat
        if type == .single || type == .repeatBegin || type == .none {
            if let barline = modifiers.first as? Barline {
                barline.setType(type)
            }
            formatted = false
        }
        return self
    }

    @discardableResult
    public func setEndBarType(_ type: BarlineType) -> Self {
        // Repeat end not valid at end of stave
        if type != .repeatBegin {
            if modifiers.count > 1, let barline = modifiers[1] as? Barline {
                barline.setType(type)
            }
            formatted = false
        }
        return self
    }

    // MARK: - Clef

    /// Treat the stave as if the clef is `clefSpec`, but don't display the clef.
    /// (4.x fix 7d9bb0d4: key signature on a non-treble stave without a clef glyph.)
    @discardableResult
    public func setClefLines(_ clefSpec: ClefName) -> Self {
        clefName = clefSpec
        return self
    }

    @discardableResult
    public func setClef(_ clefSpec: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil,
                        position: StaveModifierPosition = .begin) -> Self {
        if position == .end {
            endClefName = clefSpec
        } else {
            clefName = clefSpec
        }

        let clefs = getModifiers(position: position, category: Clef.category).compactMap { $0 as? Clef }
        if clefs.isEmpty {
            addClef(clefSpec, size: size, annotation: annotation, position: position)
        } else {
            clefs[0].setType(clefSpec, size: size, annotation: annotation)
        }

        return self
    }

    public func getClef() -> ClefName { clefName }

    @discardableResult
    public func setEndClef(_ clefSpec: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        setClef(clefSpec, size: size, annotation: annotation, position: .end)
        return self
    }

    public func getEndClef() -> ClefName? { endClefName }

    // MARK: - Key Signature

    @discardableResult
    public func setKeySignature(_ keySpec: String, cancelKeySpec: String? = nil,
                                position: StaveModifierPosition = .begin) -> Self {
        let keySignatures = getModifiers(position: position, category: KeySignature.category)
            .compactMap { $0 as? KeySignature }
        if keySignatures.isEmpty {
            addKeySignature(keySpec, cancelKeySpec: cancelKeySpec, position: position)
        } else {
            keySignatures[0].setKeySig(keySpec, cancelKeySpec: cancelKeySpec)
        }

        return self
    }

    @discardableResult
    public func setEndKeySignature(_ keySpec: String, cancelKeySpec: String? = nil) -> Self {
        setKeySignature(keySpec, cancelKeySpec: cancelKeySpec, position: .end)
        return self
    }

    // MARK: - Time Signature

    @discardableResult
    public func setTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil,
                                 position: StaveModifierPosition = .begin) -> Self {
        let timeSignatures = getModifiers(position: position, category: TimeSignature.category)
            .compactMap { $0 as? TimeSignature }
        if timeSignatures.isEmpty {
            addTimeSignature(timeSpec, customPadding: customPadding, position: position)
        } else {
            timeSignatures[0].setTimeSig(timeSpec)
        }

        return self
    }

    @discardableResult
    public func setEndTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil) -> Self {
        setTimeSignature(timeSpec, customPadding: customPadding, position: .end)
        return self
    }

    /// Add a key signature to the stave.
    ///
    /// Example: `stave.addKeySignature("Db")`
    @discardableResult
    public func addKeySignature(_ keySpec: String, cancelKeySpec: String? = nil,
                                position: StaveModifierPosition = .begin) -> Self {
        addModifier(KeySignature(keySpec: keySpec, cancelKeySpec: cancelKeySpec).setPosition(position),
                    position: position)
        return self
    }

    /// Add a clef to the stave.
    ///
    /// Example: `stave.addClef(.treble)`
    @discardableResult
    public func addClef(_ clef: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil,
                        position: StaveModifierPosition = .begin) -> Self {
        if position == .begin {
            clefName = clef
        } else if position == .end {
            endClefName = clef
        }

        addModifier(Clef(type: clef, size: size, annotation: annotation), position: position)
        return self
    }

    @discardableResult
    public func addEndClef(_ clef: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        addClef(clef, size: size, annotation: annotation, position: .end)
        return self
    }

    /// Add a time signature to the stave.
    ///
    /// Example: `stave.addTimeSignature(.meter(4, 4))`
    @discardableResult
    public func addTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil,
                                 position: StaveModifierPosition = .begin) -> Self {
        addModifier(TimeSignature(timeSpec: timeSpec, customPadding: customPadding ?? 15), position: position)
        return self
    }

    @discardableResult
    public func addEndTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil) -> Self {
        addTimeSignature(timeSpec, customPadding: customPadding, position: .end)
        return self
    }

    /// Deprecated upstream.
    @discardableResult
    public func addTrebleGlyph() -> Self {
        addClef(.treble)
        return self
    }

    /// Return the stave modifiers that match the provided position and category.
    public func getModifiers(position: StaveModifierPosition? = nil, category: String? = nil) -> [StaveModifier] {
        if position == nil && category == nil {
            return modifiers
        } else if position == nil {
            // A category was provided.
            return modifiers.filter { $0.getCategory() == category }
        } else if category == nil {
            // A position was provided.
            return modifiers.filter { $0.getPosition() == position }
        } else {
            // Both position and category were provided!
            return modifiers.filter { $0.getPosition() == position && $0.getCategory() == category }
        }
    }

    /// Use the modifier's `getCategory()` as a key for the `order` table.
    /// The retrieved value is used to sort modifiers from left to right (0 to 3).
    /// Same bubble sort as upstream: a category missing from `order` is never swapped.
    public func sortByCategory(_ items: inout [StaveModifier], order: [String: Int]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, through: 0, by: -1) {
            for j in 0..<i {
                if let a = order[items[j].getCategory()], let b = order[items[j + 1].getCategory()], a > b {
                    items.swapAt(j, j + 1)
                }
            }
        }
    }

    // MARK: - Format

    public func format() {
        let begBarline = modifiers[0] as? Barline
        let endBarline = modifiers[1]

        var begModifiers = getModifiers(position: .begin)
        var endModifiers = getModifiers(position: .end)

        sortByCategory(&begModifiers, order: SORT_ORDER_BEG_MODIFIERS)
        sortByCategory(&endModifiers, order: SORT_ORDER_END_MODIFIERS)

        if begModifiers.count > 1 && begBarline?.getType() == .repeatBegin {
            begModifiers.append(begModifiers.remove(at: 0))
            begModifiers.insert(Barline(.single), at: 0)
        }

        if let idx = endModifiers.firstIndex(where: { $0 === endBarline }), idx > 0 {
            endModifiers.insert(Barline(.none), at: 0)
        }

        var width: Double
        var padding: Double
        var offset = 0
        var x = self.x
        let parity = VexRuntime.getCurrentContext().upstreamParityMode
        for i in 0..<begModifiers.count {
            let modifier = begModifiers[i]
            padding = modifier.getPadding(i + offset)
            width = modifier.getWidth()
            // VexFlowPatch: prevent modifier width being NaN
            if width.isNaN {
                modifier.setWidth(10)
                width = 10
            }

            x += padding
            if parity {
                modifier.setX(x)
            } else {
                // VexFlowPatch: don't overwrite modifier.x when it was already shifted further
                // (e.g. to align time signatures via formatBegModifiers)
                if modifier.getX() > x {
                    x = modifier.getX()
                } else {
                    modifier.setX(x)
                }
            }
            x += width

            if padding + width == 0 { offset -= 1 }
        }

        if parity {
            startX = x
        } else if x > startX {
            // VexFlowPatch: don't overwrite startX if it's already bigger (alignment)
            startX = x
        }
        x = self.x + self.width

        var widths = (left: 0.0, right: 0.0, paddingRight: 0.0, paddingLeft: 0.0)

        var lastBarlineIdx = 0

        for i in 0..<endModifiers.count {
            let modifier = endModifiers[i]
            lastBarlineIdx = modifier is Barline ? i : lastBarlineIdx

            widths.right = 0
            widths.left = 0
            widths.paddingRight = 0
            widths.paddingLeft = 0
            let layoutMetrics = modifier.getLayoutMetrics()

            if let layoutMetrics {
                if i != 0 {
                    widths.right = layoutMetrics.xMax
                    widths.paddingRight = layoutMetrics.paddingRight
                }
                widths.left = -layoutMetrics.xMin
                widths.paddingLeft = layoutMetrics.paddingLeft

                if i == endModifiers.count - 1 {
                    widths.paddingLeft = 0
                }
            } else {
                widths.paddingRight = modifier.getPadding(i - lastBarlineIdx)
                if i != 0 {
                    widths.right = modifier.getWidth()
                }
                if i == 0 {
                    widths.left = modifier.getWidth()
                }
            }
            x -= widths.paddingRight
            x -= widths.right

            modifier.setX(x)

            x -= widths.left
            x -= widths.paddingLeft
        }

        endX = endModifiers.count == 1 ? self.x + self.width : x
        formatted = true
    }

    // MARK: - Draw

    /// All drawing functions below need the context to be set.
    override open func draw() throws {
        let ctx = try checkContext()
        setRendered()

        _ = ctx.openGroup("stave", getAttribute("id"))
        if !formatted { format() }

        let numLines = options.numLines
        let width = self.width
        let x = self.x
        var y: Double

        let lineWidth = getStyle()?.lineWidth ?? 1
        let lineWidthCorrection = lineWidth.truncatingRemainder(dividingBy: 2) == 0 ? 0 : 0.5

        // Render lines
        for line in 0..<numLines {
            y = getYForLine(Double(line))

            if options.lineConfig[line].visible {
                ctx.beginPath()
                ctx.moveTo(x, y + lineWidthCorrection)
                ctx.lineTo(x + width, y + lineWidthCorrection)
                ctx.stroke()
            }
        }

        ctx.closeGroup()

        // Draw the modifiers (bar lines, coda, segno, repeat brackets, etc.)
        for modifier in modifiers {
            modifier.setContext(ctx)
            modifier.setStave(self)
            try modifier.drawWithStyle()
        }

        // Render measure numbers
        if measure > 0 {
            ctx.setFont(fontInfo)
            let textWidth = ctx.measureText("\(measure)").width
            y = getYForTopText(0) + 3
            ctx.fillText("\(measure)", self.x - textWidth / 2, y)
        }
    }

    public func getVerticalBarWidth() -> Double { options.verticalBarWidth }

    // MARK: - Line Configuration

    /// Get the current configuration for the Stave.
    public func getConfigForLines() -> [StaveLineConfig] { options.lineConfig }

    /// Configure properties of the lines in the Stave. Invalid input is ignored;
    /// use `setConfigForLineThrowing` to get the upstream `StaveConfigError`.
    @discardableResult
    public func setConfigForLine(_ lineNumber: Int, config: StaveLineConfig) -> Self {
        _ = try? setConfigForLineThrowing(lineNumber, config: config)
        return self
    }

    /// Set the staff line configuration array for all of the lines at once.
    /// Invalid input is ignored; use `setConfigForLinesThrowing` to get the error.
    @discardableResult
    public func setConfigForLines(_ configs: [StaveLineConfig]) -> Self {
        _ = try? setConfigForLinesThrowing(configs)
        return self
    }

    @discardableResult
    public func setConfigForLineThrowing(_ lineNumber: Int, config: StaveLineConfig) throws -> Self {
        if lineNumber >= options.numLines || lineNumber < 0 {
            throw StaveError.lineNumberOutOfRange(lineNumber)
        }

        options.lineConfig[lineNumber] = config

        return self
    }

    @discardableResult
    public func setConfigForLinesThrowing(_ configs: [StaveLineConfig]) throws -> Self {
        if configs.count != options.numLines {
            throw StaveError.invalidLineConfigCount(expected: options.numLines, actual: configs.count)
        }

        options.lineConfig = configs

        return self
    }

    // MARK: - Format Beginning Modifiers Across Staves

    /// Align beginning modifiers across multiple staves.
    public static func formatBegModifiers(_ staves: [Stave]) {
        func adjustCategoryStartX(_ category: String) {
            var minStartX: Double = 0
            // Calculate min start X for the category
            for stave in staves {
                let modifiers = stave.getModifiers(position: .begin, category: category)
                // Consider only the first instance
                if let first = modifiers.first, first.getX() > minStartX {
                    minStartX = first.getX()
                }
            }
            var adjustX: Double = 0
            for stave in staves {
                adjustX = 0
                let modifiers = stave.getModifiers(position: .begin, category: category)
                // Calculate adjustement required for the stave
                for modifier in modifiers where minStartX - modifier.getX() > adjustX {
                    adjustX = minStartX - modifier.getX()
                }
                let allModifiers = stave.getModifiers(position: .begin)
                var bAdjust = false
                // Apply adjustment to all the modifiers in and beyond the category
                for modifier in allModifiers {
                    if modifier.getCategory() == category { bAdjust = true }
                    if bAdjust && adjustX > 0 { modifier.setX(modifier.getX() + adjustX) }
                }
                // Apply adjustment also to note start.
                stave.setNoteStartX(stave.getNoteStartX() + adjustX)
            }
        }

        // Make sure that staves are formatted
        for stave in staves where !stave.formatted {
            stave.format()
        }
        // Align Clefs
        adjustCategoryStartX(Clef.category)
        // Align key signatures
        adjustCategoryStartX(KeySignature.category)
        // Align time signatures
        adjustCategoryStartX(TimeSignature.category)

        var maxX: Double = 0
        // align note start
        for stave in staves where stave.getNoteStartX() > maxX {
            maxX = stave.getNoteStartX()
        }
        for stave in staves {
            stave.setNoteStartX(maxX)
        }

        maxX = 0
        // align REPEAT_BEGIN
        for stave in staves {
            let modifiers = stave.getModifiers(position: .begin, category: Barline.category)
            for modifier in modifiers {
                if let barline = modifier as? Barline, barline.getType() == .repeatBegin,
                   modifier.getX() > maxX {
                    maxX = modifier.getX()
                }
            }
        }
        for stave in staves {
            let modifiers = stave.getModifiers(position: .begin, category: Barline.category)
            for modifier in modifiers {
                if let barline = modifier as? Barline, barline.getType() == .repeatBegin {
                    modifier.setX(maxX)
                }
            }
        }
    }

    // MARK: - Deprecated 4.x API

    @available(*, deprecated, message: "Use x / getX().")
    public var staveX: Double {
        get { x }
        set { setX(newValue) }
    }

    @available(*, deprecated, message: "Use y / getY().")
    public var staveY: Double {
        get { y }
        set { y = newValue }
    }

    @available(*, deprecated, message: "Use width / getWidth().")
    public var staveWidth: Double {
        get { width }
        set { setWidth(newValue) }
    }

    @available(*, deprecated, message: "Use height / getHeight().")
    public var staveHeight: Double { height }

    @available(*, deprecated, renamed: "setX(_:)")
    @discardableResult
    public func setStaveX(_ x: Double) -> Self { setX(x) }

    @available(*, deprecated, renamed: "setY(_:)")
    @discardableResult
    public func setStaveY(_ y: Double) -> Self { setY(y) }

    @available(*, deprecated, renamed: "setWidth(_:)")
    @discardableResult
    public func setStaveWidth(_ width: Double) -> Self { setWidth(width) }

    @available(*, deprecated, message: "Use getBoundingBox().")
    public func getBBox() -> BoundingBox {
        BoundingBox(x: x, y: y, w: width, h: getBottomY() - y)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Stave", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()

        let factory = Factory(options: FactoryOptions(width: 480, height: 150))
        _ = factory.setContext(ctx)
        let score = factory.EasyScore()

        let system = factory.System(options: SystemOptions(
            factory: factory, x: 10, width: 480, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [
                score.voice(score.notes("C5/q, D5, E5, F5"))
            ]
        ))
            .addClef(.treble)
            .addKeySignature("G")
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? factory.draw()
    }
    .padding()
}
#endif
