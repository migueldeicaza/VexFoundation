// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Tuplet Location

public enum TupletError: Error, LocalizedError, Equatable, Sendable {
    case noNotesProvided

    public var errorDescription: String? {
        switch self {
        case .noNotesProvided:
            return "No notes provided for tuplet."
        }
    }
}

public enum TupletLocation: Int {
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

    public init(
        numNotes: Int? = nil,
        notesOccupied: Int? = nil,
        bracketed: Bool? = nil,
        ratioed: Bool? = nil,
        location: TupletLocation? = nil,
        yOffset: Double? = nil
    ) {
        self.numNotes = numNotes
        self.notesOccupied = notesOccupied
        self.bracketed = bracketed
        self.ratioed = ratioed
        self.location = location
        self.yOffset = yOffset
    }
}

// MARK: - Tuplet Metrics

public struct TupletMetrics {
    public var noteHeadOffset: Double
    public var stemOffset: Double
    public var bottomLine: Double
    public var topModifierOffset: Double

    public init(
        noteHeadOffset: Double = 20,
        stemOffset: Double = 10,
        bottomLine: Double = 4,
        topModifierOffset: Double = 15
    ) {
        self.noteHeadOffset = noteHeadOffset
        self.stemOffset = stemOffset
        self.bottomLine = bottomLine
        self.topModifierOffset = topModifierOffset
    }
}

// MARK: - Tuplet

/// Draws a tuplet bracket and number over or under a group of notes.
public final class Tuplet: VexElement {

    override public class var category: String { "Tuplet" }

    public static let NESTING_OFFSET: Double = 15

    public static var metrics: TupletMetrics {
        if let font = Glyph.MUSIC_FONT_STACK.first,
           let m = font.lookupMetric("tuplet") as? [String: Any] {
            return TupletMetrics(
                noteHeadOffset: m["noteHeadOffset"] as? Double ?? 20,
                stemOffset: m["stemOffset"] as? Double ?? 10,
                bottomLine: m["bottomLine"] as? Double ?? 4,
                topModifierOffset: m["topModifierOffset"] as? Double ?? 15
            )
        }
        return TupletMetrics()
    }

    // MARK: - Properties

    public let notes: [Note]
    public let options: TupletOptions
    public var numNotes: Int
    public var notesOccupied: Int
    public var bracketed: Bool
    public var ratioed: Bool
    public var location: TupletLocation

    public var yPos: Double = 16
    public var xPos: Double = 100
    public var tupletWidth: Double = 200

    private var point: Double
    private var numeratorGlyphs: [Glyph] = []
    private var denomGlyphs: [Glyph] = []

    // MARK: - Init

    public init(notes: [Note], options: TupletOptions = TupletOptions()) throws {
        guard !notes.isEmpty else {
            throw TupletError.noNotesProvided
        }

        self.notes = notes
        self.options = options
        self.numNotes = options.numNotes ?? notes.count
        self.notesOccupied = options.notesOccupied ?? 2

        if let b = options.bracketed {
            self.bracketed = b
        } else {
            self.bracketed = notes.contains { !$0.hasBeam() }
        }

        if let r = options.ratioed {
            self.ratioed = r
        } else {
            self.ratioed = abs(notesOccupied - numNotes) > 1
        }

        self.point = (Tables.NOTATION_FONT_SCALE * 3) / 5
        self.location = options.location ?? .top

        super.init()

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

    @discardableResult
    public func setBracketed(_ bracketed: Bool) -> Self {
        self.bracketed = bracketed
        return self
    }

    @discardableResult
    public func setRatioed(_ ratioed: Bool) -> Self {
        self.ratioed = ratioed
        return self
    }

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

    private func resolveGlyphs() {
        numeratorGlyphs = []
        var n = numNotes
        while n >= 1 {
            numeratorGlyphs.insert(
                Glyph(code: "timeSig\(n % 10)", point: point), at: 0
            )
            n = n / 10
        }

        denomGlyphs = []
        n = notesOccupied
        while n >= 1 {
            denomGlyphs.insert(
                Glyph(code: "timeSig\(n % 10)", point: point), at: 0
            )
            n = n / 10
        }
    }

    // MARK: - Nested Tuplet Count

    public func getNestedTupletCount() -> Int {
        let loc = location

        func countTuplets(_ note: Note, _ loc: TupletLocation) -> Int {
            note.getTupletStack().filter { $0.location == loc }.count
        }

        var maxCount = countTuplets(notes[0], loc)
        var minCount = maxCount

        for note in notes {
            let c = countTuplets(note, loc)
            maxCount = max(maxCount, c)
            minCount = min(minCount, c)
        }

        return maxCount - minCount
    }

    // MARK: - Y Position

    public func getYPosition() -> Double {
        let nestedOffset = Double(getNestedTupletCount()) * Tuplet.NESTING_OFFSET * Double(-location.rawValue)
        let yOffset = options.yOffset ?? 0

        let firstNote = notes[0]
        let m = Tuplet.metrics
        var yPos: Double

        if location == .top {
            yPos = firstNote.checkStave().getYForLine(0) - m.topModifierOffset

            for note in notes {
                var modLines: Double = 0
                if let mc = note.getModifierContext() {
                    modLines = max(modLines, mc.getState().topTextLine)
                }
                let modY = note.getYForTopText(modLines) - m.noteHeadOffset

                if note.hasStem() || note.isRest() {
                    let topY: Double
                    if note.getStemDirection() == Stem.UP {
                        topY = note.getStemExtents().topY - m.stemOffset
                    } else {
                        topY = note.getStemExtents().baseY - m.noteHeadOffset
                    }
                    yPos = min(topY, yPos)
                    if modLines > 0 {
                        yPos = min(modY, yPos)
                    }
                }
            }
        } else {
            var lineCheck = m.bottomLine

            for note in notes {
                if let mc = note.getModifierContext() {
                    lineCheck = max(lineCheck, mc.getState().textLine + 1)
                }
            }
            yPos = firstNote.checkStave().getYForLine(lineCheck) + m.noteHeadOffset

            for note in notes {
                if note.hasStem() || note.isRest() {
                    let bottomY: Double
                    if note.getStemDirection() == Stem.UP {
                        bottomY = note.getStemExtents().baseY + m.noteHeadOffset
                    } else {
                        bottomY = note.getStemExtents().topY + m.stemOffset
                    }
                    if bottomY > yPos {
                        yPos = bottomY
                    }
                }
            }
        }

        return yPos + nestedOffset + yOffset
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let firstNote = notes[0]
        let lastNote = notes[notes.count - 1]

        if !bracketed {
            if let stem = firstNote as? StemmableNote {
                xPos = stem.getStemX()
            }
            if let stem = lastNote as? StemmableNote {
                tupletWidth = stem.getStemX() - xPos
            }
        } else {
            xPos = firstNote.getTieLeftX() - 5
            tupletWidth = lastNote.getTieRightX() - xPos + 5
        }

        yPos = getYPosition()

        // Calculate total width of tuplet notation
        var notationWidth = numeratorGlyphs.reduce(0.0) { $0 + $1.getMetrics().width }
        if ratioed {
            notationWidth = denomGlyphs.reduce(notationWidth) { $0 + $1.getMetrics().width }
            notationWidth += point * 0.32
        }

        let notationCenterX = xPos + tupletWidth / 2
        let notationStartX = notationCenterX - notationWidth / 2

        // Draw bracket if the tuplet is not beamed
        if bracketed {
            let lineWidth = tupletWidth / 2 - notationWidth / 2 - 5

            if lineWidth > 0 {
                ctx.fillRect(xPos, yPos, lineWidth, 1)
                ctx.fillRect(xPos + tupletWidth / 2 + notationWidth / 2 + 5, yPos, lineWidth, 1)
                ctx.fillRect(
                    xPos,
                    yPos + (location == .bottom ? 1 : 0),
                    1,
                    Double(location.rawValue) * 10
                )
                ctx.fillRect(
                    xPos + tupletWidth,
                    yPos + (location == .bottom ? 1 : 0),
                    1,
                    Double(location.rawValue) * 10
                )
            }
        }

        // Draw numerator glyphs
        let shiftY = (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("digits.shiftY") as? Double) ?? 0

        var xOffset: Double = 0
        for glyph in numeratorGlyphs {
            glyph.render(ctx: ctx, x: notationStartX + xOffset,
                        y: yPos + point / 3 - 2 + shiftY)
            xOffset += glyph.getMetrics().width
        }

        // Display colon and denominator if ratio is shown
        if ratioed {
            let colonX = notationStartX + xOffset + point * 0.16
            let colonRadius = point * 0.06

            ctx.beginPath()
            ctx.arc(colonX, yPos - point * 0.08, colonRadius, 0, .pi * 2, false)
            ctx.closePath()
            ctx.fill()

            ctx.beginPath()
            ctx.arc(colonX, yPos + point * 0.12, colonRadius, 0, .pi * 2, false)
            ctx.closePath()
            ctx.fill()

            xOffset += point * 0.32
            for glyph in denomGlyphs {
                glyph.render(ctx: ctx, x: notationStartX + xOffset,
                            y: yPos + point / 3 - 2 + shiftY)
                xOffset += glyph.getMetrics().width
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Tuplet", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
