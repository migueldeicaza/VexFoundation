// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tabnote.ts` (VexFlow 5.6.0).
//
// Notes for tablature notation. A tab note has one or more fret positions
// and can be drawn with or without a stem.

import Foundation

// MARK: - Tab Note Position

/// A string/fret position on a tab stave.
public struct TabNotePosition {
    /// String number (1-based, e.g., on a 6-string guitar, str ranges from 1 to 6).
    public var str: Int
    /// Fret number or "X" for muted string.
    public var fret: String

    public init(str: Int, fret: String) {
        self.str = str
        self.fret = fret
    }

    public init(str: Int, fret: Int) {
        self.str = str
        self.fret = String(fret)
    }
}

// MARK: - Tab Note Struct

/// Input structure for creating a TabNote.
public struct TabNoteStruct {
    public var positions: [TabNotePosition]
    public var duration: NoteValue
    public var dots: Int?
    public var type: NoteType?
    public var stemDirection: StemDirection?
    /// Source identities of instruments and playing instructions. (VexFlow 5.4.0)
    public var notation: [NotationIdentity] = []

    public init(
        positions: [TabNotePosition],
        duration: NoteValue = .quarter,
        dots: Int? = nil,
        type: NoteType? = nil,
        stemDirection: StemDirection? = nil
    ) {
        self.positions = positions
        self.duration = duration
        self.dots = dots
        self.type = type
        self.stemDirection = stemDirection
    }

    /// String-based parser for compatibility with external text inputs.
    public init(
        positions: [TabNotePosition],
        duration: String,
        dots: Int? = nil,
        type: String? = nil,
        stemDirection: StemDirection? = nil
    ) throws {
        let parsedDuration = try NoteDurationSpec(parsing: duration)
        let parsedType: NoteType?
        if let type {
            guard let explicitType = NoteType(parsing: type) else {
                throw NoteDurationParseError.invalidType(type)
            }
            parsedType = explicitType
        } else if parsedDuration.type == .note {
            parsedType = nil
        } else {
            parsedType = parsedDuration.type
        }

        self.init(
            positions: positions,
            duration: parsedDuration.value,
            dots: dots ?? parsedDuration.dots,
            type: parsedType,
            stemDirection: stemDirection
        )
    }

    /// Failable parser convenience.
    public init?(
        parsingDuration duration: String,
        positions: [TabNotePosition],
        dots: Int? = nil,
        type: String? = nil,
        stemDirection: StemDirection? = nil
    ) {
        guard let parsed = try? TabNoteStruct(
            positions: positions,
            duration: duration,
            dots: dots,
            type: type,
            stemDirection: stemDirection
        ) else { return nil }
        self = parsed
    }
}

// MARK: - Helper Functions

/// Get the unused strings, grouped together if consecutive.
private func getUnusedStringGroups(numLines: Int, stringsUsed: [Int]) -> [[Int]] {
    var stemThrough: [[Int]] = []
    var group: [Int] = []
    if numLines >= 1 {
        for string in 1...numLines {
            let isUsed = stringsUsed.contains(string)
            if !isUsed {
                group.append(string)
            } else {
                stemThrough.append(group)
                group = []
            }
        }
    }
    if !group.isEmpty { stemThrough.append(group) }
    return stemThrough
}

/// Get groups of points that outline the partial stem lines between fret positions.
///
/// - Parameters:
///   - stemY: The `y` coordinate of the stem.
///   - unusedStrings: Groups of unused strings.
///   - stave: The reference stave.
///   - stemDirection: The stem direction.
private func getPartialStemLines(
    stemY: Double, unusedStrings: [[Int]], stave: Stave, stemDirection: StemDirection
) -> [[Double]] {
    let upStem = stemDirection != .up
    let downStem = stemDirection != .down

    let lineSpacing = stave.getSpacingBetweenLines()
    let totalLines = stave.getNumLines()

    var stemLines: [[Double]] = []

    for var strings in unusedStrings {
        let containsLastString = strings.contains(totalLines)
        let containsFirstString = strings.contains(1)

        if (upStem && containsFirstString) || (downStem && containsLastString) {
            continue
        }

        // A group with one string gets a duplicate value, because two strings
        // are necessary to get the upper and lower y values.
        if strings.count == 1 {
            strings.append(strings[0])
        }

        var lineYs: [Double] = []
        for (index, string) in strings.enumerated() {
            let isTopBound = string == 1
            let isBottomBound = string == totalLines

            // getYForLine uses a 0-based index. String numbers are 1-based.
            var y = stave.getYForLine(Double(string - 1))

            // Add padding on each side of the line, unless it is the first or last string.
            if index == 0 && !isTopBound {
                y -= lineSpacing / 2 - 1
            } else if index == strings.count - 1 && !isBottomBound {
                y += lineSpacing / 2 - 1
            }

            lineYs.append(y)

            // Connect the group to the main stem above or below the stave
            // if it is the top or bottom string.
            if stemDirection == .up && isTopBound {
                lineYs.append(stemY - 2)
            } else if stemDirection == .down && isBottomBound {
                lineYs.append(stemY + 2)
            }
        }

        stemLines.append(lineYs.sorted())
    }

    return stemLines
}

public enum TabNoteError: Error, LocalizedError, Equatable, Sendable {
    case emptyPositions
    case missingGlyph(duration: String, type: String)
    case unformattedNoteForModifierStart
    case invalidModifierIndex(Int)
    case noYValues
    /// Upstream throws `BadArguments` for an invalid timed bend or a bent string outside the chord.
    case invalidNotation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidNotation(let message):
            return message
        case .emptyPositions:
            return "TabNote requires at least one position."
        case .missingGlyph(let duration, let type):
            return "No glyph found for duration '\(duration)' and type '\(type)'."
        case .unformattedNoteForModifierStart:
            return "Can't call GetModifierStartXY on an unformatted note."
        case .invalidModifierIndex(let index):
            return "Modifier index out of range: \(index)"
        case .noYValues:
            return "No Y-Values calculated for this note."
        }
    }
}

// MARK: - TabNote

/// Notes for tablature notation. A tab note has one or more fret positions
/// and can be drawn with or without a stem.
open class TabNote: StemmableNote {

    override open class var category: String { "TabNote" }

    // MARK: - Properties

    /// Draw parentheses around the fret positions.
    public var ghost: Bool = false
    /// One text element for each fret position.
    public internal(set) var fretElement: [VexElement] = []
    public var positions: [TabNotePosition]
    public private(set) var tabInitError: TabNoteError?

    /// VexFlowPatch: configurable background color for tab notes. When set,
    /// the area behind each fret number is filled with this color instead of
    /// `clearRect` (some viewers render a transparent clear as black).
    public var backgroundColor: String?

    /// VexFlowPatch: use a classical X notehead glyph (`noteheadXBlack`)
    /// instead of `accidentalDoubleSharp` for muted strings ("X").
    public var useAlternativeXNoteheadGlyph: Bool = false {
        didSet { if oldValue != useAlternativeXNoteheadGlyph { updateWidth() } }
    }

    private func setInitErrorIfNeeded(_ error: TabNoteError) {
        if tabInitError == nil {
            tabInitError = error
        }
    }

    // MARK: - Init

    /// Create a `TabNote` from `noteStruct`. `drawStem` enables the stem.
    public init(_ noteStruct: TabNoteStruct, drawStem: Bool = false) {
        // The fret positions in the note.
        self.positions = noteStruct.positions

        var noteInput = NoteStruct(
            keys: [],
            duration: NoteDurationSpec(uncheckedValue: noteStruct.duration),
            dots: noteStruct.dots,
            type: noteStruct.type
        )
        noteInput.notation = noteStruct.notation

        super.init(noteInput)

        self.ghost = false // Draw parentheses around the notes.

        // Render options.
        renderOptions.drawStem = drawStem
        renderOptions.drawDots = drawStem
        renderOptions.drawStemThroughStave = false
        renderOptions.yShift = 0

        if noteStruct.positions.isEmpty {
            setInitErrorIfNeeded(.emptyPositions)
        }
        // Upstream sets `glyphProps = Note.getGlyphProps(duration, noteType)`
        // here. The Note initializer already does the same lookup.

        buildStem()

        if let dir = noteStruct.stemDirection {
            setStemDirection(dir)
        } else {
            setStemDirection(Stem.UP)
        }

        self.ghost = false
        updateWidth()
        if case .invalidNotation(let message)? = initError {
            setInitErrorIfNeeded(.invalidNotation(message))
        } else if !notation.isEmpty {
            do {
                try attachGuitarGestures(self)
            } catch {
                setInitErrorIfNeeded(.invalidNotation((error as? VexError)?.message ?? "\(error)"))
            }
        }
    }

    public convenience init(validating noteStruct: TabNoteStruct, drawStem: Bool = false) throws {
        self.init(noteStruct, drawStem: drawStem)
        if let error = tabInitError {
            throw error
        }
    }

    // MARK: - String Accessors

    /// The number of the greatest string (the lowest string on the display).
    public func greatestString() -> Int {
        positions.map { $0.str }.max() ?? 0
    }

    /// The number of the least string (the highest string on the display).
    public func leastString() -> Int {
        positions.map { $0.str }.min() ?? 0
    }

    // MARK: - Reset

    @discardableResult
    override open func reset() -> Self {
        super.reset()
        if let stave = getStave() { setStave(stave) }
        return self
    }

    // MARK: - Ghost

    /// Set as ghost `TabNote`: draw parentheses around the fret positions.
    /// Often used for frets that are bent to.
    @discardableResult
    public func setGhost(_ ghost: Bool) -> Self {
        self.ghost = ghost
        updateWidth()
        return self
    }

    // MARK: - Stem

    override public func hasStem() -> Bool {
        renderOptions.drawStem
    }

    /// The default stem extension of the note.
    override public func getStemExtension() -> Double {
        if let override = stemExtensionOverride {
            return override
        }
        return flag.getHeight() > Stem.HEIGHT ? flag.getHeight() - Stem.HEIGHT : 0
    }

    // MARK: - Fret Elements

    /// Make the element for a fret: `X` gives a glyph, other values give text.
    ///
    /// VexFlowPatch: `useAlternativeXGlyph` selects `noteheadXBlack` for `X`.
    public static func tabToElement(_ fret: String, useAlternativeXGlyph: Bool = false) -> VexElement {
        let el: VexElement

        if fret.uppercased() == "X" {
            el = VexElement(category: "TabNote")
            el.setText(useAlternativeXGlyph ? Glyphs.noteheadXBlack : Glyphs.accidentalDoubleSharp)
        } else {
            el = VexElement(category: "TabNote.text")
            el.setText(fret)
            el.setYShift(el.getHeight() / 2)
        }

        return el
    }

    // MARK: - Width

    /// Explicit fret size; otherwise use text metrics and this note's grace scale. (VexFlow 5.1.0)
    public private(set) var fretFontSize: String?

    /// Resize fret text as well as the parent. Set sizes before formatting the voice. (VexFlow 5.1.0)
    @discardableResult
    override open func setFontSize(_ size: String) -> Self {
        super.setFontSize(size)
        fretFontSize = size
        updateWidth()
        preFormatted = false
        return self
    }

    /// Calculate and store the width of the note, retaining explicit sizes across ghost changes.
    public func updateWidth() {
        fretElement = []
        width = 0
        for i in 0..<positions.count {
            var fret = positions[i].fret
            if ghost { fret = "(" + fret + ")" }
            let el = TabNote.tabToElement(fret, useAlternativeXGlyph: useAlternativeXNoteheadGlyph)
            let defaultSize = VexFont.convertSizeToPointValue(Metrics.getFontInfo("TabNote.text").size)
            let size = fretFontSize.map { VexFont.convertSizeToPointValue($0) } ?? defaultSize * getFontScale()
            el.setFontSize(VexFont.convertSizeToPointValue(el.fontInfo.size) * size / defaultSize)
            let metrics = el.getTextMetrics()
            el.setYShift((metrics.actualBoundingBoxAscent - metrics.actualBoundingBoxDescent) / 2)
            fretElement.append(el)
            width = max(el.getWidth(), width)
        }
        // VexFlow 5.6.0: the tick lies at the middle of a fret. Reserve its two halves on the corresponding sides.
        setLeftDisplacedHeadPx(width / 2)
        setRightDisplacedHeadPx(width / 2)
    }

    // MARK: - Stave

    /// Set the stave of the note.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        let ctx = stave.getContext()
        setContext(ctx)

        // getYForLine uses a 0-based index. position.str is 1-based.
        let ys = positions.map { stave.getYForLine(Double($0.str - 1)) }

        setYs(ys)

        if let stem {
            stem.setYBounds(getStemY(), getStemY())
        }

        return self
    }

    // MARK: - Positions

    /// The fret positions of the note.
    public func getPositions() -> [TabNotePosition] {
        positions
    }

    // MARK: - Modifier Start XY

    /// The default `x` and `y` coordinates of a modifier at `position`
    /// for the fret position at `index`.
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
            throw TabNoteError.unformattedNoteForModifierStart
        }
        guard !ys.isEmpty else {
            throw TabNoteError.noYValues
        }
        guard index >= 0 && index < ys.count else {
            throw TabNoteError.invalidModifierIndex(index)
        }

        // VexFlow 5.6.0: frets straddle the tick. Keep side modifiers outside the widest member of the chord.
        var x = getAbsoluteX()
        if position == .left {
            x = getTieLeftX()
        } else if position == .right {
            x = getTieRightX()
        }

        return (x: x, y: ys[index])
    }

    // MARK: - Rest Line

    /// The default line for a rest.
    override public func getLineForRest() -> Double {
        Double(positions.first?.str ?? 0)
    }

    // MARK: - Pre Format

    /// Pre-render formatting.
    override open func preFormat() {
        if preFormatted { return }
        modifierContext?.preFormat()
        // The width is already set in init.
        preFormatted = true
    }

    // MARK: - Stem Position

    /// The x position of the stem.
    override public func getStemX() -> Double {
        getCenterGlyphX()
    }

    /// The y position of the stem.
    public func getStemY() -> Double {
        (try? getStemYThrowing()) ?? 0
    }

    public func getStemYThrowing() throws -> Double {
        let stave = try checkStaveThrowing()
        let numLines = stave.getNumLines()

        // The decimal staff line values give good spacing between the
        // fret number and the stem.
        let stemUpLine = -0.5
        let stemDownLine = Double(numLines) - 0.5
        let stemStartLine = Stem.UP == stemDirection ? stemUpLine : stemDownLine

        return stave.getYForLine(stemStartLine)
    }

    /// The stem extents of the tab note.
    override public func getStemExtents() -> (topY: Double, baseY: Double) {
        checkStem().getExtents()
    }

    // MARK: - Draw Flag

    /// Draw the flag.
    public func drawFlag() throws {
        let drawStem = renderOptions.drawStem
        let context = try checkContext()

        let shouldDrawFlag = beam == nil && drawStem

        if glyphProps.codeFlagUp != nil && shouldDrawFlag {
            let flagX = getStemX()
            let flagY = getStemDirection() == Stem.DOWN
                // Down stems are below the notehead and have flags on the right.
                ? getStemY() - checkStem().getHeight() - getStemExtension()
                // Up stems are above the notehead and have flags on the right.
                : getStemY() - checkStem().getHeight() + getStemExtension()

            flag.setContext(context).setX(flagX).setY(flagY)
            try flag.drawWithStyle()
        }
    }

    // MARK: - Draw Modifiers

    /// Draw the modifiers.
    public func drawModifiers() throws {
        for modifier in getModifiers() {
            // Draw the dots only if enabled.
            if modifier is Dot && !renderOptions.drawDots {
                continue
            }
            modifier.setContext(getContext())
            try modifier.drawWithStyle()
        }
    }

    // MARK: - Draw Stem Through

    /// Draw the stem extension through the fret positions.
    public func drawStemThrough() throws {
        let stemX = getStemX()
        let stemY = getStemY()
        let ctx = try checkContext()

        let drawStem = renderOptions.drawStem
        let stemThrough = renderOptions.drawStemThroughStave
        if drawStem && stemThrough {
            let stave = try checkStaveThrowing()
            let numLines = stave.getNumLines()
            let stringsUsed = positions.map { $0.str }

            let unusedStrings = getUnusedStringGroups(numLines: numLines, stringsUsed: stringsUsed)
            let stemLines = getPartialStemLines(
                stemY: stemY, unusedStrings: unusedStrings,
                stave: stave, stemDirection: getStemDirection()
            )

            ctx.setLineWidth(Stem.WIDTH)
            for bounds in stemLines {
                if bounds.isEmpty { continue }

                ctx.beginPath()
                ctx.moveTo(stemX, bounds[0])
                ctx.lineTo(stemX, bounds[bounds.count - 1])
                ctx.stroke()
                ctx.closePath()
            }
        }
    }

    // MARK: - Fret Ink

    /// The visible fret text for each string, including ghost parentheses, font sizing and baseline shifts.
    /// (VexFlow 5.8.0)
    public func getFretInk() -> [BoundingBox] {
        let x = getAbsoluteX()
        return fretElement.enumerated().map { i, el in
            el.getTextInk(x - el.getWidth() / 2, (i < ys.count ? ys[i] : .nan) + renderOptions.yShift)
        }
    }

    // MARK: - Draw Positions

    /// Draw the fret positions.
    public func drawPositions() throws {
        let ctx = try checkContext()
        let x = getAbsoluteX()
        let ys = self.ys
        let count = min(positions.count, ys.count, fretElement.count)
        for i in 0..<count {
            let y = ys[i] + renderOptions.yShift
            let el = fretElement[i]

            // Center the fret text below the stem.
            let tabX = x - el.getWidth() / 2

            // FIXME: Magic numbers.
            if let bgColor = backgroundColor {
                // VexFlowPatch: fill with the background color instead of clearRect.
                ctx.save()
                ctx.setFillStyle(bgColor)
                ctx.setLineWidth(0)
                ctx.fillRect(tabX - 2, y - 3, el.getWidth() + 4, 6)
                ctx.restore()
            } else {
                ctx.clearRect(tabX - 2, y - 3, el.getWidth() + 4, 6)
            }

            el.renderText(ctx, xPos: tabX, yPos: y)
        }
    }

    // MARK: - Draw

    /// Draw the note.
    override public func draw() throws {
        let ctx = try checkContext()

        guard !ys.isEmpty else {
            throw TabNoteError.noYValues
        }

        setRendered()
        let renderStem = beam == nil && renderOptions.drawStem

        let group = ctx.openGroup(groupClass("tabnote"), getAttribute("id"))
        if !notation.isEmpty {
            (group as? SVGNode)?.setAttribute("aria-label", notation.map(\.label).joined(separator: ", "))
        }
        try drawPositions()
        try drawStemThrough()

        if let stem, renderStem {
            let stemX = getStemX()
            stem.setNoteHeadXBounds(stemX, stemX)
            stem.setContext(ctx)
            try stem.drawWithStyle()
        }

        try drawFlag()
        try drawModifiers()
        drawPointerRect()
        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TabNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)

        let ts = f.TabStave(x: 10, y: 10, width: 490)
        _ = ts.addTabGlyph()

        let notes: [Note] = [
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 3)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 3, fret: 7)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [
                TabNotePosition(str: 1, fret: 0),
                TabNotePosition(str: 2, fret: 1),
                TabNotePosition(str: 3, fret: 0),
            ], duration: .quarter)),
        ]

        let voice = f.Voice(timeSignature: .meter(4, 4))
        _ = voice.addTickables(notes)

        let formatter = f.Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 400)

        try? f.draw()
    }
    .padding()
}
#endif
