// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/stavetie.ts` (VexFlow 5.0.0).
//
// This class implements varies types of ties between contiguous notes. The
// ties include: regular ties, hammer ons, pull offs, and slides.

import Foundation

public enum StaveTieError: Error, LocalizedError, Equatable, Sendable {
    case requiresStartOrEndNote
    case mismatchedIndices(firstCount: Int, lastCount: Int)
    case noYValues
    case badIndices

    public var errorDescription: String? {
        switch self {
        case .requiresStartOrEndNote:
            return "Tie needs to have either firstNote or lastNote set."
        case .mismatchedIndices(let firstCount, let lastCount):
            return "Tied notes must have same number of indexes (\(firstCount) vs \(lastCount))."
        case .noYValues:
            return "No Y-values to render"
        case .badIndices:
            return "Bad indexes for tie rendering."
        }
    }
}

// MARK: - Tie Notes

/// Specifies the notes and indexes for a tie connection.
public struct TieNotes {
    public var firstNote: Note?
    public var lastNote: Note?
    public var firstIndexes: [Int]
    public var lastIndexes: [Int]

    public init(
        firstNote: Note? = nil,
        lastNote: Note? = nil,
        firstIndexes: [Int] = [0],
        lastIndexes: [Int] = [0]
    ) {
        self.firstNote = firstNote
        self.lastNote = lastNote
        self.firstIndexes = firstIndexes
        self.lastIndexes = lastIndexes
    }

    @available(*, deprecated, renamed: "init(firstNote:lastNote:firstIndexes:lastIndexes:)")
    public init(
        firstNote: Note? = nil,
        lastNote: Note? = nil,
        firstIndices: [Int],
        lastIndices: [Int]
    ) {
        self.init(firstNote: firstNote, lastNote: lastNote, firstIndexes: firstIndices, lastIndexes: lastIndices)
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

// MARK: - Tie Render Options

public struct TieRenderOptions {
    /// Curve control point 1
    public var cp1: Double = 8
    /// Curve control point 2
    public var cp2: Double = 12
    /// Below this distance we use short control points
    public var shortTieCutoff: Double = 10
    public var cp1Short: Double = 2
    public var cp2Short: Double = 8
    public var textShiftX: Double = 0
    public var firstXShift: Double = 0
    public var lastXShift: Double = 0
    public var yShift: Double = 7
    public var tieSpacing: Double = 0

    public init() {}
}

// MARK: - StaveTie

/// Implements ties between contiguous notes including regular ties,
/// hammer ons, pull offs, and slides.
open class StaveTie: VexElement {

    override open class var category: String { "StaveTie" }

    // MARK: - Properties

    public var renderOptions = TieRenderOptions()
    public var notes: TieNotes
    /// The direction set with `setDirection`. `nil` means: use the note stem direction.
    public var direction: TieDirection?
    /// Swift-native: set when the notes are not valid (upstream throws).
    public private(set) var initError: StaveTieError?

    private static func normalizedTieNotes(_ notes: TieNotes) -> (notes: TieNotes, error: StaveTieError?) {
        guard notes.firstNote != nil || notes.lastNote != nil else {
            return (TieNotes(firstIndexes: [0], lastIndexes: [0]), .requiresStartOrEndNote)
        }

        var normalized = notes
        if normalized.firstIndexes.isEmpty { normalized.firstIndexes = [0] }
        if normalized.lastIndexes.isEmpty { normalized.lastIndexes = [0] }
        guard normalized.firstIndexes.count != normalized.lastIndexes.count else {
            return (normalized, nil)
        }

        let error = StaveTieError.mismatchedIndices(
            firstCount: normalized.firstIndexes.count,
            lastCount: normalized.lastIndexes.count
        )
        let count = min(normalized.firstIndexes.count, normalized.lastIndexes.count)
        if count > 0 {
            normalized.firstIndexes = Array(normalized.firstIndexes.prefix(count))
            normalized.lastIndexes = Array(normalized.lastIndexes.prefix(count))
        } else {
            normalized.firstIndexes = [0]
            normalized.lastIndexes = [0]
        }
        return (normalized, error)
    }

    // MARK: - Init

    /// - Parameters:
    ///   - notes: `firstNote`, `lastNote`, `firstIndexes`, `lastIndexes`.
    ///   - text: tie text.
    /// Invalid notes set `initError`; use `init(validating:text:)` to throw.
    public init(notes: TieNotes, text: String? = nil) {
        self.notes = TieNotes()
        super.init()
        let normalized = Self.normalizedTieNotes(notes)
        self.notes = normalized.notes
        self.initError = normalized.error
        self.text = text ?? ""
        self.renderOptions = TieRenderOptions()
    }

    public convenience init(validating notes: TieNotes, text: String? = nil) throws {
        self.init(notes: notes, text: text)
        if let initError {
            throw initError
        }
    }

    // MARK: - Direction

    /// Returns either the direction explicitly set with setDirection, or
    /// a logical direction based on lastNote or firstNote.
    public func getDirection() -> TieDirection {
        if let direction {
            return direction
        } else if let lastNote = notes.lastNote {
            return TieDirection(stemDirection: lastNote.getStemDirection())
        } else if let firstNote = notes.firstNote {
            return TieDirection(stemDirection: firstNote.getStemDirection())
        } else {
            // Upstream returns 0; setNotes() makes this unreachable.
            return .up
        }
    }

    @discardableResult
    public func setDirection(_ direction: TieDirection) -> Self {
        self.direction = direction
        return self
    }

    @discardableResult
    public func setDirection(_ direction: StemDirection) -> Self {
        setDirection(TieDirection(stemDirection: direction))
    }

    // MARK: - Notes

    /// Set the notes to attach this tie to.
    @discardableResult
    public func setNotes(_ notes: TieNotes) -> Self {
        _ = try? setNotesThrowing(notes)
        return self
    }

    @discardableResult
    public func setNotesThrowing(_ notes: TieNotes) throws -> Self {
        guard notes.firstNote != nil || notes.lastNote != nil else {
            throw StaveTieError.requiresStartOrEndNote
        }

        var n = notes
        if n.firstIndexes.isEmpty { n.firstIndexes = [0] }
        if n.lastIndexes.isEmpty { n.lastIndexes = [0] }

        guard n.firstIndexes.count == n.lastIndexes.count else {
            throw StaveTieError.mismatchedIndices(
                firstCount: n.firstIndexes.count,
                lastCount: n.lastIndexes.count
            )
        }

        self.notes = n
        return self
    }

    /// Returns true if this is a partial bar.
    public func isPartial() -> Bool {
        notes.firstNote == nil || notes.lastNote == nil
    }

    // MARK: - Render Tie

    /// `firstX` and `lastX` are specified in pixels.
    open func renderTie(
        direction: TieDirection,
        firstX: Double,
        lastX: Double,
        firstYs: [Double],
        lastYs: [Double]
    ) throws {
        if firstYs.isEmpty || lastYs.isEmpty {
            throw StaveTieError.noYValues
        }

        let ctx = try checkContext()
        var cp1 = renderOptions.cp1
        var cp2 = renderOptions.cp2

        if abs(lastX - firstX) < renderOptions.shortTieCutoff {
            // do not get super exaggerated curves for very short ties
            cp1 = renderOptions.cp1Short
            cp2 = renderOptions.cp2Short
        }

        let dir = direction.signDouble
        let firstXShift = renderOptions.firstXShift
        let lastXShift = renderOptions.lastXShift
        let yShift = renderOptions.yShift * dir

        let firstIndexes = notes.firstIndexes
        let lastIndexes = notes.lastIndexes
        _ = ctx.openGroup("stavetie", getAttribute("id"))
        for i in 0..<firstIndexes.count {
            let cpX = (lastX + lastXShift + (firstX + firstXShift)) / 2
            guard i < lastIndexes.count,
                  firstIndexes[i] >= 0, firstIndexes[i] < firstYs.count,
                  lastIndexes[i] >= 0, lastIndexes[i] < lastYs.count else {
                ctx.closeGroup()
                throw StaveTieError.badIndices
            }
            // firstY and lastY are specified in pixels.
            let firstY = firstYs[firstIndexes[i]] + yShift
            let lastY = lastYs[lastIndexes[i]] + yShift

            if firstY.isNaN || lastY.isNaN {
                ctx.closeGroup()
                throw StaveTieError.badIndices
            }

            let topControlPointY = (firstY + lastY) / 2 + cp1 * dir
            let bottomControlPointY = (firstY + lastY) / 2 + cp2 * dir

            ctx.beginPath()
            ctx.moveTo(firstX + firstXShift, firstY)
            ctx.quadraticCurveTo(cpX, topControlPointY, lastX + lastXShift, lastY)
            ctx.quadraticCurveTo(cpX, bottomControlPointY, firstX + firstXShift, firstY)
            ctx.closePath()
            ctx.fill()
        }
        ctx.closeGroup()
    }

    // MARK: - Render Text

    /// `firstX` and `lastX` are specified in pixels.
    public func renderTieText(firstX: Double, lastX: Double) throws {
        let ctx = try checkContext()
        var centerX = (firstX + lastX) / 2
        centerX -= ctx.measureText(text).width / 2
        let stave = notes.firstNote?.checkStave() ?? notes.lastNote?.checkStave()
        if let stave {
            ctx.setFont(fontInfo)
            ctx.fillText(text, centerX + renderOptions.textShiftX, stave.getYForTopText() - 1)
        }
    }

    @available(*, deprecated, renamed: "renderTieText(firstX:lastX:)")
    public func renderText(firstXPx: Double, lastXPx: Double) throws {
        try renderTieText(firstX: firstXPx, lastX: lastXPx)
    }

    // MARK: - Positions

    /// Returns the TieNotes structure of the first and last note this tie connects.
    public func getNotes() -> TieNotes { notes }

    /// Returns the X position in pixels that the tie will be drawn starting from;
    /// ideally from the firstNote, alternatively from the lastNote, or 0 if all else fails.
    public func getFirstX() -> Double {
        if let firstNote = notes.firstNote {
            return firstNote.getTieRightX() + renderOptions.tieSpacing
        } else if let lastNote = notes.lastNote {
            return lastNote.checkStave().getTieStartX()
        } else {
            return 0
        }
    }

    /// Returns the X position in pixels that the tie will be drawn ending at;
    /// ideally from the lastNote, alternatively from the firstNote, or 0 if all else fails.
    public func getLastX() -> Double {
        if let lastNote = notes.lastNote {
            return lastNote.getTieLeftX() + renderOptions.tieSpacing
        } else if let firstNote = notes.firstNote {
            return firstNote.checkStave().getTieEndX()
        } else {
            return 0
        }
    }

    /// Get the Y positions of the places where a tie needs to be drawn starting from.
    public func getFirstYs() -> [Double] {
        if let firstNote = notes.firstNote {
            return firstNote.getYs()
        } else if let lastNote = notes.lastNote {
            return lastNote.getYs()
        } else {
            return [0]
        }
    }

    /// Get the Y positions of the places where a tie needs to be drawn ending at.
    public func getLastYs() -> [Double] {
        if let lastNote = notes.lastNote {
            return lastNote.getYs()
        } else if let firstNote = notes.firstNote {
            return firstNote.getYs()
        } else {
            return [0]
        }
    }

    /// If a tie has firstNote and not lastNote, or vice-versa, then their
    /// firstIndexes and lastIndexes need to be equal to each other.
    ///
    /// Does nothing if both notes.firstNote and notes.lastNote are defined (or
    /// if neither are).
    public func synchronizeIndexes() {
        if notes.firstNote != nil && notes.lastNote != nil {
            return
        } else if notes.firstNote == nil && notes.lastNote == nil {
            return
        } else if notes.firstNote != nil {
            notes.lastIndexes = notes.firstIndexes
        } else {
            // notes.lastNote defined, but not firstNote
            notes.firstIndexes = notes.lastIndexes
        }
    }

    // MARK: - Draw

    override open func draw() throws {
        _ = try checkContext()
        setRendered()
        synchronizeIndexes()
        let firstX = getFirstX()
        let lastX = getLastX()
        try renderTie(
            direction: getDirection(), // note: not self.direction
            firstX: firstX,
            lastX: lastX,
            firstYs: getFirstYs(),
            lastYs: getLastYs()
        )

        try renderTieText(firstX: firstX, lastX: lastX)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveTie", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/q, C5, E5, E5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble).addTimeSignature(.meter(4, 4))

        system.format()

        _ = f.StaveTie(notes: TieNotes(
            firstNote: notes[0], lastNote: notes[1],
            firstIndexes: [0], lastIndexes: [0]
        ))
        _ = f.StaveTie(notes: TieNotes(
            firstNote: notes[2], lastNote: notes[3],
            firstIndexes: [0], lastIndexes: [0]
        ))

        try? f.draw()
    }
    .padding()
}
#endif
