// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

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

    override open class var CATEGORY: String { "StaveTie" }

    // MARK: - Properties

    public var renderOptions = TieRenderOptions()
    public var notes: TieNotes
    public var text: String?
    public var direction: Int?

    // MARK: - Init

    public init(notes: TieNotes, text: String? = nil) {
        self.notes = TieNotes()
        self.text = text
        super.init()
        setNotes(notes)
    }

    // MARK: - Direction

    @discardableResult
    public func setDirection(_ direction: Int) -> Self {
        self.direction = direction
        return self
    }

    // MARK: - Notes

    @discardableResult
    public func setNotes(_ notes: TieNotes) -> Self {
        guard notes.firstNote != nil || notes.lastNote != nil else {
            fatalError("[VexError] BadArguments: Tie needs to have either firstNote or lastNote set.")
        }

        var n = notes
        if n.firstIndices.isEmpty { n.firstIndices = [0] }
        if n.lastIndices.isEmpty { n.lastIndices = [0] }

        guard n.firstIndices.count == n.lastIndices.count else {
            fatalError("[VexError] BadArguments: Tied notes must have same number of indices.")
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
        direction: Int,
        firstXPx: Double,
        lastXPx: Double,
        firstYs: [Double],
        lastYs: [Double]
    ) throws {
        guard !firstYs.isEmpty && !lastYs.isEmpty else {
            fatalError("[VexError] BadArguments: No Y-values to render")
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
        let yShift = renderOptions.yShift * Double(direction)

        let firstIndices = notes.firstIndices
        let lastIndices = notes.lastIndices

        applyStyle(context: ctx, style: getStyle())
        _ = ctx.openGroup("stavetie", getAttribute("id") ?? "")

        for i in 0..<firstIndices.count {
            let cpX = (lastXPx + lastXShift + firstXPx + firstXShift) / 2
            let firstYPx = firstYs[firstIndices[i]] + yShift
            let lastYPx = lastYs[lastIndices[i]] + yShift

            guard !firstYPx.isNaN && !lastYPx.isNaN else {
                fatalError("[VexError] BadArguments: Bad indices for tie rendering.")
            }

            let topCpY = (firstYPx + lastYPx) / 2 + cp1 * Double(direction)
            let bottomCpY = (firstYPx + lastYPx) / 2 + cp2 * Double(direction)

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

        let firstNote = notes.firstNote
        let lastNote = notes.lastNote

        var firstXPx: Double = 0
        var lastXPx: Double = 0
        var firstYs: [Double] = [0]
        var lastYs: [Double] = [0]
        var stemDirection: Int = 0

        if let firstNote {
            firstXPx = firstNote.getTieRightX() + renderOptions.tieSpacing
            stemDirection = firstNote.getStemDirection()
            firstYs = firstNote.getYs()
        } else if let lastNote {
            let stave = lastNote.checkStave()
            firstXPx = stave.getTieStartX()
            firstYs = lastNote.getYs()
            notes.firstIndices = notes.lastIndices
        }

        if let lastNote {
            lastXPx = lastNote.getTieLeftX() + renderOptions.tieSpacing
            stemDirection = lastNote.getStemDirection()
            lastYs = lastNote.getYs()
        } else if let firstNote {
            let stave = firstNote.checkStave()
            lastXPx = stave.getTieEndX()
            lastYs = firstNote.getYs()
            notes.lastIndices = notes.firstIndices
        }

        if let dir = direction {
            stemDirection = dir
        }

        try renderTie(
            direction: stemDirection,
            firstXPx: firstXPx,
            lastXPx: lastXPx,
            firstYs: firstYs,
            lastYs: lastYs
        )

        try renderText(firstXPx: firstXPx, lastXPx: lastXPx)
    }
}
