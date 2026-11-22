// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tuplet.ts` (VexFlow 5.0.0).
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

    public init(
        numNotes: Int? = nil,
        notesOccupied: Int? = nil,
        bracketed: Bool? = nil,
        ratioed: Bool? = nil,
        location: TupletLocation? = nil,
        yOffset: Double? = nil,
        textYOffset: Double? = nil
    ) {
        self.numNotes = numNotes
        self.notesOccupied = notesOccupied
        self.bracketed = bracketed
        self.ratioed = ratioed
        self.location = location
        self.yOffset = yOffset
        self.textYOffset = textYOffset
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
            textYOffset: textYOffset
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
        self.textElement = VexElement(category: "Tuplet")

        super.init()

        setTupletLocation(location)

        Formatter.AlignRestsToNotes(notes, alignAllNotes: true, alignTuplets: true)
        resolveGlyphs()
        attach()
    }

    // MARK: - Attach / Detach

    public func attach() {
        for note in notes {
            note.setTuplet(self)
        }
    }

    public func detach() {
        for note in notes {
            note.resetTuplet(self)
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
    }

    // MARK: - Nested Tuplet Count

    /// Determine how many tuplets are nested within this tuplet
    /// on the same side (above/below), to calculate a y
    /// offset for this tuplet.
    public func getNestedTupletCount() -> Int {
        let location = self.location
        let firstNote = notes[0]

        // Count the tuplets that are on the same side (above/below)
        // as this tuplet:
        func countTuplets(_ note: Note, _ location: TupletLocation) -> Int {
            note.getTupletStack().filter { $0.location == location }.count
        }

        var maxTupletCount = countTuplets(firstNote, location)
        var minTupletCount = countTuplets(firstNote, location)

        for note in notes {
            let tupletCount = countTuplets(note, location)
            maxTupletCount = tupletCount > maxTupletCount ? tupletCount : maxTupletCount
            minTupletCount = tupletCount < minTupletCount ? tupletCount : minTupletCount
        }

        return maxTupletCount - minTupletCount
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

        if !bracketed {
            xPos = (firstNote as? StemmableNote)?.getStemX() ?? firstNote.getTieLeftX()
            width = ((lastNote as? StemmableNote)?.getStemX() ?? lastNote.getTieRightX()) - xPos
        } else {
            xPos = firstNote.getTieLeftX() - 5
            width = lastNote.getTieRightX() - xPos + 5
        }

        // determine y value for tuplet
        yPos = getYPosition()

        let notationCenterX = xPos + width / 2
        let notationStartX = notationCenterX - textElement.getWidth() / 2

        // start grouping
        _ = ctx.openGroup("tuplet", getAttribute("id"))

        // draw bracket if the tuplet is not beamed
        if bracketed {
            let lineWidth = width / 2 - textElement.getWidth() / 2 - 5

            // only draw the bracket if it has positive length
            if lineWidth > 0 {
                let loc = Double(location.rawValue)
                ctx.fillRect(xPos, yPos, lineWidth, 1)
                ctx.fillRect(xPos + width / 2 + textElement.getWidth() / 2 + 5, yPos, lineWidth, 1)
                ctx.fillRect(xPos, yPos + (location == .bottom ? 1 : 0), 1, loc * 10)
                ctx.fillRect(xPos + width, yPos + (location == .bottom ? 1 : 0), 1, loc * 10)
            }
        }

        // VexFlowPatch: conditionally render tuplet numbers
        if renderTupletNumber {
            // draw text
            textElement.renderText(
                ctx,
                xPos: notationStartX,
                yPos: yPos + textElement.getHeight() / 2 + (location == .top ? -1 : 1) * textYOffset
            )
        }

        // Set up an interactive bounding box and finalize the tuplet rendering
        if let bb = getBoundingBox() {
            ctx.pointerRect(bb.x, bb.y, bb.w, bb.h)
        }
        ctx.closeGroup()
        setRendered()
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
