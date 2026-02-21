// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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
            return "Tied notes must have same number of indices (\(firstCount) vs \(lastCount))."
        case .noYValues:
            return "No Y-values to render tie."
        case .badIndices:
            return "Bad indices for tie rendering."
        }
    }
}

// MARK: - Tie Notes

/// Specifies the notes and indices for a tie connection.
public struct TieNotes {
    public var firstNote: Note?
    public var lastNote: Note?
    public var firstIndices: [Int]
    public var lastIndices: [Int]

    public init(
        firstNote: Note? = nil,
        lastNote: Note? = nil,
        firstIndices: [Int] = [0],
        lastIndices: [Int] = [0]
    ) {
        self.firstNote = firstNote
        self.lastNote = lastNote
        self.firstIndices = firstIndices
        self.lastIndices = lastIndices
    }
}

// MARK: - Tie Render Options

public struct TieRenderOptions {
    public var cp1: Double = 8
    public var cp2: Double = 12
    public var textShiftX: Double = 0
    public var firstXShift: Double = 0
    public var lastXShift: Double = 0
    public var yShift: Double = 7
    public var tieSpacing: Double = 0
}

// MARK: - StaveTie

/// Implements ties between contiguous notes including regular ties,
/// hammer ons, pull offs, and slides.
open class StaveTie: VexElement {

    override open class var category: String { "StaveTie" }

    // MARK: - Properties

    public var renderOptions = TieRenderOptions()
    public var notes: TieNotes
    public var text: String?
    public var direction: TieDirection?
    public private(set) var initError: StaveTieError?

    private static func normalizedTieNotes(_ notes: TieNotes) -> (notes: TieNotes, error: StaveTieError?) {
        guard notes.firstNote != nil || notes.lastNote != nil else {
            return (TieNotes(firstIndices: [0], lastIndices: [0]), .requiresStartOrEndNote)
        }

        var normalized = notes
        if normalized.firstIndices.isEmpty { normalized.firstIndices = [0] }
        if normalized.lastIndices.isEmpty { normalized.lastIndices = [0] }
        guard normalized.firstIndices.count != normalized.lastIndices.count else {
            return (normalized, nil)
        }

        let error = StaveTieError.mismatchedIndices(
            firstCount: normalized.firstIndices.count,
            lastCount: normalized.lastIndices.count
        )
        let count = min(normalized.firstIndices.count, normalized.lastIndices.count)
        if count > 0 {
            normalized.firstIndices = Array(normalized.firstIndices.prefix(count))
            normalized.lastIndices = Array(normalized.lastIndices.prefix(count))
        } else {
            normalized.firstIndices = [0]
            normalized.lastIndices = [0]
        }
        return (normalized, error)
    }

    // MARK: - Init

    public init(notes: TieNotes, text: String? = nil) {
        self.notes = TieNotes()
        self.text = text
        super.init()
        let normalized = Self.normalizedTieNotes(notes)
        self.notes = normalized.notes
        self.initError = normalized.error
    }

    public convenience init(validating notes: TieNotes, text: String? = nil) throws {
        self.init(notes: notes, text: text)
        if let initError {
            throw initError
        }
    }

    // MARK: - Direction

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
        if n.firstIndices.isEmpty { n.firstIndices = [0] }
        if n.lastIndices.isEmpty { n.lastIndices = [0] }

        guard n.firstIndices.count == n.lastIndices.count else {
            throw StaveTieError.mismatchedIndices(
                firstCount: n.firstIndices.count,
                lastCount: n.lastIndices.count
            )
        }

        self.notes = n
        return self
    }

    public func getNotes() -> TieNotes { notes }

    public func isPartial() -> Bool {
        notes.firstNote == nil || notes.lastNote == nil
    }

    // MARK: - Render Tie

    open func renderTie(
        direction: TieDirection,
        firstXPx: Double,
        lastXPx: Double,
        firstYs: [Double],
        lastYs: [Double]
    ) throws {
        guard !firstYs.isEmpty && !lastYs.isEmpty else {
            throw StaveTieError.noYValues
        }

        let ctx = try checkContext()
        var cp1 = renderOptions.cp1
        var cp2 = renderOptions.cp2

        if abs(lastXPx - firstXPx) < 10 {
            cp1 = 2
            cp2 = 8
        }

        let firstXShift = renderOptions.firstXShift
        let lastXShift = renderOptions.lastXShift
        let yShift = renderOptions.yShift * direction.signDouble

        let firstIndices = notes.firstIndices
        let lastIndices = notes.lastIndices

        applyStyle(context: ctx, style: getStyle())
        _ = ctx.openGroup("stavetie", getAttribute("id") ?? "")

        for i in 0..<firstIndices.count {
            guard firstIndices[i] >= 0, firstIndices[i] < firstYs.count,
                  lastIndices[i] >= 0, lastIndices[i] < lastYs.count else {
                throw StaveTieError.badIndices
            }
            let cpX = (lastXPx + lastXShift + firstXPx + firstXShift) / 2
            let firstYPx = firstYs[firstIndices[i]] + yShift
            let lastYPx = lastYs[lastIndices[i]] + yShift

            guard !firstYPx.isNaN && !lastYPx.isNaN else {
                throw StaveTieError.badIndices
            }

            let topCpY = (firstYPx + lastYPx) / 2 + cp1 * direction.signDouble
            let bottomCpY = (firstYPx + lastYPx) / 2 + cp2 * direction.signDouble

            ctx.beginPath()
            ctx.moveTo(firstXPx + firstXShift, firstYPx)
            ctx.quadraticCurveTo(cpX, topCpY,
                                 lastXPx + lastXShift, lastYPx)
            ctx.quadraticCurveTo(cpX, bottomCpY,
                                 firstXPx + firstXShift, firstYPx)
            ctx.closePath()
            ctx.fill()
        }

        ctx.closeGroup()
        restoreStyle(context: ctx, style: getStyle())
    }

    // MARK: - Render Text

    public func renderText(firstXPx: Double, lastXPx: Double) throws {
        guard let text, !text.isEmpty else { return }
        let ctx = try checkContext()

        var centerX = (firstXPx + lastXPx) / 2
        centerX -= ctx.measureText(text).width / 2

        let stave = notes.firstNote?.checkStave() ?? notes.lastNote?.checkStave()
        if let stave {
            ctx.save()
            ctx.setFont(getFont())
            ctx.fillText(text, centerX + renderOptions.textShiftX,
                        stave.getYForTopText() - 1)
            ctx.restore()
        }
    }

    // MARK: - Draw

    override public func draw() throws {
        _ = try checkContext()
        setRendered()

        guard notes.firstNote != nil || notes.lastNote != nil else {
            throw StaveTieError.requiresStartOrEndNote
        }

        let firstNote = notes.firstNote
        let lastNote = notes.lastNote

        var firstXPx: Double = 0
        var lastXPx: Double = 0
        var firstYs: [Double] = [0]
        var lastYs: [Double] = [0]
        var tieDirection: TieDirection?

        if let firstNote {
            firstXPx = firstNote.getTieRightX() + renderOptions.tieSpacing
            tieDirection = TieDirection(stemDirection: firstNote.getStemDirection())
            firstYs = firstNote.getYs()
        } else if let lastNote {
            let stave = lastNote.checkStave()
            firstXPx = stave.getTieStartX()
            firstYs = lastNote.getYs()
            notes.firstIndices = notes.lastIndices
        }

        if let lastNote {
            lastXPx = lastNote.getTieLeftX() + renderOptions.tieSpacing
            tieDirection = TieDirection(stemDirection: lastNote.getStemDirection())
            lastYs = lastNote.getYs()
        } else if let firstNote {
            let stave = firstNote.checkStave()
            lastXPx = stave.getTieEndX()
            lastYs = firstNote.getYs()
            notes.lastIndices = notes.firstIndices
        }

        if let direction {
            tieDirection = direction
        }

        try renderTie(
            direction: tieDirection ?? .up,
            firstXPx: firstXPx,
            lastXPx: lastXPx,
            firstYs: firstYs,
            lastYs: lastYs
        )

        try renderText(firstXPx: firstXPx, lastXPx: lastXPx)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveTie", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
            firstIndices: [0], lastIndices: [0]
        ))
        _ = f.StaveTie(notes: TieNotes(
            firstNote: notes[2], lastNote: notes[3],
            firstIndices: [0], lastIndices: [0]
        ))

        try? f.draw()
    }
    .padding()
}
#endif
