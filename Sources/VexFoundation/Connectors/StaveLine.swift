// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/staveline.ts` (VexFlow 5.0.0).
//
// This file implements `StaveLine` which are simply lines that connect
// two notes. This object is highly configurable, see the `renderOptions`.
// A simple line is often used for notating glissando articulations, but you
// can format a `StaveLine` with arrows or colors for more pedagogical
// purposes, such as diagrams.

import Foundation

public enum StaveLineError: Error, LocalizedError, Equatable, Sendable {
    case mismatchedIndices(firstCount: Int, lastCount: Int)

    public var errorDescription: String? {
        switch self {
        case .mismatchedIndices(let firstCount, let lastCount):
            return "Connected notes must have same number of indexes (\(firstCount) vs \(lastCount))."
        }
    }
}

// MARK: - StaveLine Notes

public struct StaveLineNotes {
    public var firstNote: StaveNote
    public var firstIndexes: [Int]
    public var lastNote: StaveNote
    public var lastIndexes: [Int]

    public init(
        firstNote: StaveNote,
        firstIndexes: [Int] = [0],
        lastNote: StaveNote,
        lastIndexes: [Int] = [0]
    ) {
        self.firstNote = firstNote
        self.firstIndexes = firstIndexes
        self.lastNote = lastNote
        self.lastIndexes = lastIndexes
    }

    @available(*, deprecated, renamed: "init(firstNote:firstIndexes:lastNote:lastIndexes:)")
    public init(
        firstNote: StaveNote,
        firstIndices: [Int],
        lastNote: StaveNote,
        lastIndices: [Int]
    ) {
        self.init(firstNote: firstNote, firstIndexes: firstIndices, lastNote: lastNote, lastIndexes: lastIndices)
    }

    @available(*, deprecated, renamed: "firstIndexes")
    public var firstIndices: [Int] {
        get { firstIndexes }
        set { firstIndexes = newValue }
    }

    @available(*, deprecated, renamed: "lastIndexes")
    public var lastIndices: [Int] {
        get { lastIndexes }
        set { lastIndexes = newValue }
    }
}

// MARK: - StaveLine Text Position

public enum StaveLineTextVerticalPosition: Int, Sendable {
    case top = 1
    case bottom = 2
}

// MARK: - StaveLine Render Options

public struct StaveLineRenderOptions {
    /// Space to add to the left or the right
    public var paddingLeft: Double = 4
    public var paddingRight: Double = 3
    /// The width of the line in pixels
    public var lineWidth: Double = 1
    /// An array of line/space lengths.
    public var lineDash: [Double]?
    /// Can draw rounded line end, instead of a square.
    public var roundedEnd: Bool = true
    /// The color of the line and arrowheads
    public var color: String?
    /// Flags to draw arrows on each end of the line
    public var drawStartArrow: Bool = false
    public var drawEndArrow: Bool = false
    /// The length of the arrowhead sides
    public var arrowheadLength: Double = 10
    /// The angle of the arrowhead
    public var arrowheadAngle: Double = Double.pi / 8
    /// The position of the text
    public var textPositionVertical: StaveLineTextVerticalPosition = .top
    public var textJustification: TextJustification = .center

    public init() {}
}

// Attribution: Arrow rendering implementations based off of
// Patrick Horgan's article, "Drawing lines and arcs with
// arrow heads on  HTML5 Canvas"
//
// Draw an arrow head that connects between 3 coordinates.
private func drawArrowHead(
    _ ctx: RenderContext,
    _ x0: Double, _ y0: Double,
    _ x1: Double, _ y1: Double,
    _ x2: Double, _ y2: Double
) {
    // all cases do this.
    ctx.beginPath()
    ctx.moveTo(x0, y0)
    ctx.lineTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.lineTo(x0, y0)
    ctx.closePath()

    ctx.fill()
}

// MARK: - StaveLine

/// Draws lines connecting two notes (glissando, pedagogical diagrams, etc.).
public final class StaveLine: VexElement {

    override public class var category: String { "StaveLine" }

    public typealias TextVerticalPosition = StaveLineTextVerticalPosition

    // MARK: - Properties

    public var renderOptions = StaveLineRenderOptions()

    public private(set) var notes: StaveLineNotes
    public private(set) var firstNote: StaveNote
    public private(set) var firstIndexes: [Int]
    public private(set) var lastNote: StaveNote
    public private(set) var lastIndexes: [Int]

    /// Swift-native: set when the index counts do not match (upstream throws).
    public private(set) var initError: StaveLineError?

    @available(*, deprecated, renamed: "renderOptions")
    public var lineRenderOptions: StaveLineRenderOptions {
        get { renderOptions }
        set { renderOptions = newValue }
    }

    @available(*, deprecated, renamed: "firstIndexes")
    public var firstIndices: [Int] { firstIndexes }

    @available(*, deprecated, renamed: "lastIndexes")
    public var lastIndices: [Int] { lastIndexes }

    @available(*, deprecated, renamed: "text")
    public var lineText: String { text }

    private static func normalizeNotes(_ notes: StaveLineNotes) -> (notes: StaveLineNotes, error: StaveLineError?) {
        guard notes.firstIndexes.count != notes.lastIndexes.count else {
            return (notes, nil)
        }
        let error = StaveLineError.mismatchedIndices(
            firstCount: notes.firstIndexes.count,
            lastCount: notes.lastIndexes.count
        )
        var normalized = notes
        let count = min(notes.firstIndexes.count, notes.lastIndexes.count)
        if count > 0 {
            normalized.firstIndexes = Array(notes.firstIndexes.prefix(count))
            normalized.lastIndexes = Array(notes.lastIndexes.prefix(count))
        } else {
            normalized.firstIndexes = [0]
            normalized.lastIndexes = [0]
        }
        return (normalized, error)
    }

    // MARK: - Init

    /// Initialize the StaveLine with the given `notes`.
    /// When the index counts do not match, `initError` is set and the
    /// indexes are truncated to the shorter list. Use `init(validating:)`
    /// to throw instead (upstream behavior).
    public init(notes: StaveLineNotes) {
        let normalized = Self.normalizeNotes(notes)
        self.notes = normalized.notes
        self.firstNote = normalized.notes.firstNote
        self.firstIndexes = normalized.notes.firstIndexes
        self.lastNote = normalized.notes.lastNote
        self.lastIndexes = normalized.notes.lastIndexes
        self.initError = normalized.error
        super.init()

        self.text = ""
        self.renderOptions = StaveLineRenderOptions()
    }

    public convenience init(validating notes: StaveLineNotes) throws {
        self.init(notes: notes)
        if let initError {
            throw initError
        }
    }

    // MARK: - Setters

    /// The annotation for the `StaveLine`.
    @discardableResult
    override public func setText(_ text: String) -> Self {
        self.text = text
        return self
    }

    /// Set the notes for the `StaveLine`.
    @discardableResult
    public func setNotes(_ notes: StaveLineNotes) -> Self {
        _ = try? setNotesThrowing(notes)
        return self
    }

    @discardableResult
    public func setNotesThrowing(_ notes: StaveLineNotes) throws -> Self {
        guard notes.firstIndexes.count == notes.lastIndexes.count else {
            throw StaveLineError.mismatchedIndices(
                firstCount: notes.firstIndexes.count,
                lastCount: notes.lastIndexes.count
            )
        }
        self.notes = notes
        firstNote = notes.firstNote
        firstIndexes = notes.firstIndexes
        lastNote = notes.lastNote
        lastIndexes = notes.lastIndexes
        return self
    }

    // MARK: - Line Style

    /// Apply the style of the `StaveLine` to the context.
    public func applyLineStyle() throws {
        let ctx = try checkContext()
        let renderOptions = self.renderOptions

        if let lineDash = renderOptions.lineDash {
            ctx.setLineDash(lineDash)
        }

        if renderOptions.lineWidth != 0 && !renderOptions.lineWidth.isNaN {
            ctx.setLineWidth(renderOptions.lineWidth)
        }

        if renderOptions.roundedEnd {
            ctx.setLineCap(.round)
        } else {
            ctx.setLineCap(.square)
        }
    }

    // MARK: - Arrow Drawing

    /// Helper function to draw a line with arrow heads.
    func drawArrowLine(
        _ ctx: RenderContext,
        _ pt1: (x: Double, y: Double),
        _ pt2: (x: Double, y: Double)
    ) {
        let opts = renderOptions
        let bothArrows = opts.drawStartArrow && opts.drawEndArrow

        let x1 = pt1.x
        let y1 = pt1.y
        let x2 = pt2.x
        let y2 = pt2.y

        // For ends with arrow we actually want to stop before we get to the arrow
        // so that wide lines won't put a flat end on the arrow.
        let distance = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
        let ratio = (distance - opts.arrowheadLength / 3) / distance
        let endX: Double
        let endY: Double
        let startX: Double
        let startY: Double
        if opts.drawEndArrow || bothArrows {
            endX = jsRound(x1 + (x2 - x1) * ratio)
            endY = jsRound(y1 + (y2 - y1) * ratio)
        } else {
            endX = x2
            endY = y2
        }

        if opts.drawStartArrow || bothArrows {
            startX = x1 + (x2 - x1) * (1 - ratio)
            startY = y1 + (y2 - y1) * (1 - ratio)
        } else {
            startX = x1
            startY = y1
        }

        if let color = opts.color, !color.isEmpty {
            ctx.setStrokeStyle(color)
            ctx.setFillStyle(color)
        }

        // Draw the shaft of the arrow
        ctx.beginPath()
        ctx.moveTo(startX, startY)
        ctx.lineTo(endX, endY)
        ctx.stroke()
        ctx.closePath()

        // calculate the angle of the line
        let lineAngle = atan2(y2 - y1, x2 - x1)
        // h is the line length of a side of the arrow head
        let h = abs(opts.arrowheadLength / cos(opts.arrowheadAngle))

        if opts.drawEndArrow || bothArrows {
            let angle1 = lineAngle + Double.pi + opts.arrowheadAngle
            let topX = x2 + cos(angle1) * h
            let topY = y2 + sin(angle1) * h

            let angle2 = lineAngle + Double.pi - opts.arrowheadAngle
            let bottomX = x2 + cos(angle2) * h
            let bottomY = y2 + sin(angle2) * h

            drawArrowHead(ctx, topX, topY, x2, y2, bottomX, bottomY)
        }

        if opts.drawStartArrow || bothArrows {
            let angle1 = lineAngle + opts.arrowheadAngle
            let topX = x1 + cos(angle1) * h
            let topY = y1 + sin(angle1) * h

            let angle2 = lineAngle - opts.arrowheadAngle
            let bottomX = x1 + cos(angle2) * h
            let bottomY = y1 + sin(angle2) * h

            drawArrowHead(ctx, topX, topY, x1, y1, bottomX, bottomY)
        }
    }

    /// JavaScript `Math.round` (half rounds toward +infinity).
    private func jsRound(_ v: Double) -> Double {
        (v + 0.5).rounded(.down)
    }

    // MARK: - Draw

    /// Renders the `StaveLine` on the context.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let firstNote = self.firstNote
        let lastNote = self.lastNote
        let renderOptions = self.renderOptions

        try applyLineStyle()

        // Cycle through each set of indexes and draw lines
        var startPosition: (x: Double, y: Double) = (0, 0)
        var endPosition: (x: Double, y: Double) = (0, 0)
        for (i, firstIndex) in firstIndexes.enumerated() {
            let lastIndex = lastIndexes[i]

            // Get initial coordinates for the start/end of the line
            startPosition = firstNote.getModifierStartXY(position: .right, index: firstIndex)
            endPosition = lastNote.getModifierStartXY(position: .left, index: lastIndex)
            let upwardsSlope = startPosition.y > endPosition.y

            // Adjust `x` coordinates for modifiers
            startPosition.x += firstNote.getMetrics().modRightPx + renderOptions.paddingLeft
            endPosition.x -= lastNote.getMetrics().modLeftPx + renderOptions.paddingRight

            // Adjust first `x` coordinates for displacements
            let noteheadWidth = firstNote.getGlyphWidth()
            let firstKeyProps = firstNote.getKeyProps()
            let firstDisplaced = firstIndex < firstKeyProps.count && firstKeyProps[firstIndex].displaced
            if firstDisplaced && firstNote.getStemDirection() == Stem.UP {
                startPosition.x += noteheadWidth + renderOptions.paddingLeft
            }

            // Adjust last `x` coordinates for displacements
            let lastKeyProps = lastNote.getKeyProps()
            let lastDisplaced = lastIndex < lastKeyProps.count && lastKeyProps[lastIndex].displaced
            if lastDisplaced && lastNote.getStemDirection() == Stem.DOWN {
                endPosition.x -= noteheadWidth + renderOptions.paddingRight
            }

            // Adjust y position better if it's not coming from the center of the note
            startPosition.y += upwardsSlope ? -3 : 1
            endPosition.y += upwardsSlope ? 2 : 0

            drawArrowLine(ctx, startPosition, endPosition)
        }

        // Determine the x coordinate where to start the text
        let textWidth = width
        let justification = renderOptions.textJustification
        var x: Double = 0
        switch justification {
        case .left:
            x = startPosition.x
        case .center:
            let deltaX = endPosition.x - startPosition.x
            let centerX = deltaX / 2 + startPosition.x
            x = centerX - textWidth / 2
        case .right:
            x = endPosition.x - textWidth
        }

        // Determine the y value to start the text
        var y: Double = 0
        switch renderOptions.textPositionVertical {
        case .top:
            y = firstNote.checkStave().getYForTopText()
        case .bottom:
            y = firstNote.checkStave().getYForBottomText(Tables.TEXT_HEIGHT_OFFSET_HACK)
        }

        // Draw the text
        let color = renderOptions.color
        applyStyle(context: ctx, style: ElementStyle(fillStyle: color, strokeStyle: color))
        renderText(ctx, xPos: x, yPos: y)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveLine", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()

        if let first = notes[0] as? StaveNote, let last = notes[3] as? StaveNote {
            _ = f.StaveLine(notes: StaveLineNotes(
                firstNote: first,
                firstIndexes: [0],
                lastNote: last,
                lastIndexes: [0]
            ))
        }

        try? f.draw()
    }
    .padding()
}
#endif
