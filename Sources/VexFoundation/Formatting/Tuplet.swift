// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tuplet.ts` (VexFlow 5.1.0).
//
// Create a new tuplet from the specified notes. The notes must
// be part of the same voice. If they are of different rhythmic
// values, then `options.numNotes` must be set.
//
// - numNotes: fit this many notes into...
// - notesOccupied: ...the space of this many notes.
//   Together, these two properties make up the tuplet ratio in the form of
//   numNotes : notesOccupied. numNotes defaults to the number of notes passed
//   in. notesOccupied defaults to 2.
// - location: `.top` (default) is above the notes, `.bottom` below them.
// - bracketed: draw a bracket. Default: true if any note is not beamed.
// - ratioed: show the ratio (n:m). Default: true if |notesOccupied - numNotes| > 1.

import Foundation

public enum TupletError: Error, LocalizedError, Equatable, Sendable {
    case noNotesProvided

    public var errorDescription: String? {
        switch self {
        case .noNotesProvided:
            return "No notes provided for tuplet."
        }
    }
}

// MARK: - Tuplet Location

public enum TupletLocation: Int, Sendable {
    case bottom = -1
    case top = 1
}

// MARK: - Tuplet Options

public struct TupletOptions {
    public var numNotes: Int?
    public var notesOccupied: Int?
    public var bracketed: Bool?
    public var ratioed: Bool?
    public var location: TupletLocation?
    public var yOffset: Double?
    public var textYOffset: Double?
    /// Suffix shown after the ratio, e.g. a note glyph (`Glyphs.metNote8thUp`). (VexFlow 5.1.0)
    public var suffix: String?

    public init(
        numNotes: Int? = nil,
        notesOccupied: Int? = nil,
        bracketed: Bool? = nil,
        ratioed: Bool? = nil,
        location: TupletLocation? = nil,
        yOffset: Double? = nil,
        textYOffset: Double? = nil,
        suffix: String? = nil
    ) {
        self.numNotes = numNotes
        self.notesOccupied = notesOccupied
        self.bracketed = bracketed
        self.ratioed = ratioed
        self.location = location
        self.yOffset = yOffset
        self.textYOffset = textYOffset
        self.suffix = suffix
    }
}

// MARK: - Tuplet

/// Draws a tuplet bracket and number over or under a group of notes.
public final class Tuplet: VexElement {

    override public class var category: String { "Tuplet" }

    public static let LOCATION_TOP: TupletLocation = .top
    public static let LOCATION_BOTTOM: TupletLocation = .bottom
    public static let NESTING_OFFSET: Double = 15

    // MARK: - Properties

    public let notes: [Note]
    public var numNotes: Int
    public var notesOccupied: Int
    public var bracketed: Bool
    public var ratioed: Bool
    public var location: TupletLocation
    public var yOffset: Double
    public var textYOffset: Double
    public let textElement: VexElement
    /// Suffix shown after the ratio (empty for none). (VexFlow 5.1.0)
    public var suffix: String
    public let suffixElement: VexElement

    /// VexFlowPatch: option to not render tuplet numbers
    public var renderTupletNumber: Bool = true

    /// The resolved options (upstream `Required<TupletOptions>`).
    public var options: TupletOptions {
        TupletOptions(
            numNotes: numNotes,
            notesOccupied: notesOccupied,
            bracketed: bracketed,
            ratioed: ratioed,
            location: location,
            yOffset: yOffset,
            textYOffset: textYOffset,
            suffix: suffix
        )
    }

    // MARK: - Init

    public init(notes: [Note], options: TupletOptions = TupletOptions()) throws {
        guard !notes.isEmpty else {
            throw TupletError.noNotesProvided
        }

        self.notes = notes
        let numNotes = options.numNotes ?? notes.count
        let notesOccupied = (options.notesOccupied ?? 0) != 0 ? (options.notesOccupied ?? 2) : 2
        self.numNotes = numNotes
        self.notesOccupied = notesOccupied
        self.bracketed = options.bracketed ?? notes.contains { !$0.hasBeam() }
        self.ratioed = options.ratioed ?? (abs(notesOccupied - numNotes) > 1)
        let location = options.location ?? .top
        self.location = location
        if let y = options.yOffset, y != 0 {
            self.yOffset = y
        } else {
            self.yOffset = Metrics.getDouble("Tuplet.yOffset")
        }
        if let t = options.textYOffset, t != 0 {
            self.textYOffset = t
        } else {
            self.textYOffset = Metrics.getDouble("Tuplet.textYOffset")
        }
        self.suffix = options.suffix ?? ""
        self.textElement = VexElement(category: "Tuplet")
        self.suffixElement = VexElement(category: "Tuplet.suffix")

        super.init()

        setTupletLocation(location)

        Formatter.AlignRestsToNotes(notes, alignAllNotes: true, alignTuplets: true)
        resolveGlyphs()
        attach()
    }

    // MARK: - Attach / Detach

    public func attach() {
        for note in notes where !note.getTupletStack().contains(where: { $0 === self }) {
            note.addTuplet(self)
        }
    }

    public func detach() {
        for note in notes {
            _ = try? note.removeTuplet(self)
        }
    }

    // MARK: - Setters

    /// Set whether or not the bracket is drawn.
    @discardableResult
    public func setBracketed(_ bracketed: Bool) -> Self {
        self.bracketed = bracketed
        return self
    }

    /// Set whether or not the ratio is shown.
    @discardableResult
    public func setRatioed(_ ratioed: Bool) -> Self {
        self.ratioed = ratioed
        return self
    }

    /// Set the tuplet indicator to be displayed either on the top or bottom of the stave.
    @discardableResult
    public func setTupletLocation(_ location: TupletLocation) -> Self {
        self.location = location
        return self
    }

    // MARK: - Getters

    public func getNotes() -> [Note] { notes }

    public func getNoteCount() -> Int { numNotes }

    public func getNotesOccupied() -> Int { notesOccupied }

    @discardableResult
    public func setNotesOccupied(_ notes: Int) -> Self {
        detach()
        notesOccupied = notes
        resolveGlyphs()
        attach()
        return self
    }

    // MARK: - Resolve Glyphs

    private static func tupletDigit(_ d: Int) -> String {
        guard let scalar = Unicode.Scalar(UInt32(0xE880 + d)) else { return "" } // tuplet0
        return String(Character(scalar))
    }

    public func resolveGlyphs() {
        var numerator = ""
        var denominator = ""
        var n = numNotes
        while n >= 1 {
            numerator = Self.tupletDigit(n % 10) + numerator
            n = n / 10
        }
        if ratioed {
            n = notesOccupied
            while n >= 1 {
                denominator = Self.tupletDigit(n % 10) + denominator
                n = n / 10
            }
            denominator = Glyphs.tupletColon + denominator
        }
        textElement.setText(numerator + denominator)

        // Resolve the suffix glyph if needed.
        if !suffix.isEmpty {
            suffixElement.setText(suffix)
        }
    }

    // MARK: - Nested Tuplet Count

    /// Determine how many tuplets are nested within this tuplet
    /// on the same side (above/below), to calculate a y
    /// offset for this tuplet.
    public func getNestedTupletCount() -> Int {
        let location = self.location
        var maxOffset = 0
        for note in notes {
            // The tuplets on the same side (above/below) as this tuplet.
            let stack = note.getTupletStack().filter { $0.location == location }
            // Where this tuplet appears in that filtered stack.
            if let index = stack.firstIndex(where: { $0 === self }), index > maxOffset {
                maxOffset = index
            }
        }
        return maxOffset
    }

    // MARK: - Y Position

    /// Determine the y position of the tuplet.
    public func getYPosition() -> Double {
        // offset the tuplet for any nested tuplets between
        // it and the notes:
        let nestedTupletYOffset = Double(getNestedTupletCount()) * Tuplet.NESTING_OFFSET * Double(-location.rawValue)

        // offset the tuplet for any manual yOffset:
        let yOffset = self.yOffset

        // now iterate through the notes and find our highest
        // or lowest locations, to form a base yPosition
        let firstNote = notes[0]
        var yPosition: Double
        if location == .top {
            yPosition = firstNote.checkStave().getYForLine(0) - 1.5 * Tables.STAVE_LINE_DISTANCE

            // check modifiers above note to see if they will collide with tuplet beam
            for note in notes {
                var modLines: Double = 0
                if let mc = note.getModifierContext() {
                    modLines = max(modLines, mc.getState().topTextLine)
                }
                let modY = note.getYForTopText(modLines) - 2 * Tables.STAVE_LINE_DISTANCE
                if note.hasStem() || note.isRest() {
                    let topY = note.getStemDirection() == Stem.UP
                        ? note.getStemExtents().topY - Tables.STAVE_LINE_DISTANCE
                        : note.getStemExtents().baseY - 2 * Tables.STAVE_LINE_DISTANCE
                    yPosition = min(topY, yPosition)
                    if modLines > 0 {
                        yPosition = min(modY, yPosition)
                    }
                }
            }
        } else {
            var lineCheck: Double = 4 // tuplet default on line 4
            // check modifiers below note to see if they will collide with tuplet beam
            for nn in notes {
                if let mc = nn.getModifierContext() {
                    lineCheck = max(lineCheck, mc.getState().textLine + 1)
                }
            }
            yPosition = firstNote.checkStave().getYForLine(lineCheck) + 2 * Tables.STAVE_LINE_DISTANCE

            for note in notes {
                if note.hasStem() || note.isRest() {
                    let bottomY = note.getStemDirection() == Stem.UP
                        ? note.getStemExtents().baseY + 2 * Tables.STAVE_LINE_DISTANCE
                        : note.getStemExtents().topY + Tables.STAVE_LINE_DISTANCE
                    if bottomY > yPosition {
                        yPosition = bottomY
                    }
                }
            }
        }

        return yPosition + nestedTupletYOffset + yOffset
    }

    // MARK: - Draw

    override public func draw() throws {
        let location = self.location
        let bracketed = self.bracketed
        let textYOffset = self.textYOffset

        let bracketPadding = Metrics.getDouble("Tuplet.bracket.padding")
        let bracketThickness = Metrics.getDouble("Tuplet.bracket.lineWidth")
        let bracketLegLength = Metrics.getDouble("Tuplet.bracket.legLength")
        let extraSpacing = Metrics.getDouble("Tuplet.suffix.extraSpacing")
        let suffixOffsetY = Metrics.getDouble("Tuplet.suffix.suffixOffsetY")

        let ctx = try checkContext()
        var xPos: Double = 0
        var yPos: Double = 0

        // Local change (1af03ba): apply the element style in draw().
        ctx.save()
        defer { ctx.restore() }
        applyStyle(context: ctx)

        // determine x value of left bound of tuplet
        let firstNote = notes[0]
        let lastNote = notes[notes.count - 1]
        var bodyWidth: Double = 0
        if !bracketed {
            xPos = (firstNote as? StemmableNote)?.getStemX() ?? firstNote.getTieLeftX()
            bodyWidth = ((lastNote as? StemmableNote)?.getStemX() ?? lastNote.getTieRightX()) - xPos
            setWidth(bodyWidth)
        } else {
            xPos = firstNote.getTieLeftX() - bracketPadding
            bodyWidth = lastNote.getTieRightX() - xPos + bracketPadding
            // value added to fully include right bracket leg in bounding box
            setWidth(bodyWidth + bracketThickness)
        }

        setX(xPos)

        // determine y value for tuplet
        yPos = getYPosition()

        // set y and height for bounding box calculations
        setY(location == .top ? yPos : yPos - bracketLegLength + bracketThickness)
        height = bracketLegLength

        // calculate width taken by all text elements
        let ratioWidth = textElement.getWidth()
        var totalTextWidth = ratioWidth
        var noteWidth: Double = 0
        if !suffix.isEmpty {
            noteWidth = suffixElement.getWidth()
            totalTextWidth = ratioWidth + extraSpacing + noteWidth
        }

        // find center of notation for text placement
        let notationCenterX = xPos + bodyWidth / 2
        let notationStartX = notationCenterX - totalTextWidth / 2

        // Common vertical coordinate for text rendering (the text element height is the reference).
        let commonTextY = yPos + textElement.getHeight() / 2 + (location == .top ? -1 : 1) * textYOffset

        // start grouping
        _ = ctx.openGroup(groupClass("tuplet"), getAttribute("id"))

        // draw bracket if the tuplet is not beamed
        if bracketed {
            let lineWidth = bodyWidth / 2 - totalTextWidth / 2 - bracketPadding
            let isTupletBottom = location == .bottom

            if lineWidth > 0 {
                let loc = Double(location.rawValue)
                ctx.fillRect(xPos, yPos, lineWidth, bracketThickness)
                ctx.fillRect(
                    xPos + bodyWidth / 2 + totalTextWidth / 2 + bracketPadding, yPos, lineWidth, bracketThickness
                )
                ctx.fillRect(xPos, yPos + (isTupletBottom ? 1 : 0), bracketThickness, loc * bracketLegLength)
                ctx.fillRect(
                    xPos + bodyWidth, yPos + (isTupletBottom ? 1 : 0), bracketThickness, loc * bracketLegLength
                )
            }
        }

        // draw ratio text (x:y)
        var currentX = notationStartX
        textElement.setX(currentX)
        textElement.setY(commonTextY)
        // VexFlowPatch: conditionally render tuplet numbers
        if renderTupletNumber {
            textElement.renderText(ctx, xPos: 0, yPos: 0)
        }
        currentX += ratioWidth + extraSpacing

        // draw the suffix glyph if wanted
        if !suffix.isEmpty {
            suffixElement.setX(currentX)
            suffixElement.setY(commonTextY + suffixOffsetY)
            if renderTupletNumber {
                suffixElement.renderText(ctx, xPos: 0, yPos: 0)
            }
            currentX += noteWidth
        }

        drawPointerRect()
        ctx.closeGroup()
        setRendered()
    }

    /// Bounding box of the ratio text, the suffix and (when bracketed) the bracket.
    /// Call it after `draw()`, which sets the positions. (VexFlow 5.1.0)
    override public func getBoundingBox() -> BoundingBox? {
        guard let ratioBounding = textElement.getBoundingBox() else { return nil }
        var mergedText = ratioBounding
        if !suffix.isEmpty, let suffixBounding = suffixElement.getBoundingBox() {
            mergedText.mergeWith(suffixBounding)
        }
        if !bracketed {
            return mergedText
        }
        var bracketBounding = BoundingBox(x: x, y: y, w: width, h: height)
        bracketBounding.mergeWith(mergedText)
        return bracketBounding
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Tuplet", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/8, D5, E5, F5/q, G5")
        _ = score.tuplet(Array(notes[0..<3]))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
