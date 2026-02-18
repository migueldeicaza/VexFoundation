// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TabSlide

/// Implements slide notation between contiguous tab notes.
/// Renders straight diagonal lines instead of curved ties.
public final class TabSlide: TabTie {

    override public class var CATEGORY: String { "TabSlide" }

    // MARK: - Constants

    public static let SLIDE_UP: Int = 1
    public static let SLIDE_DOWN: Int = -1

    // MARK: - Factory Methods

    public static func createSlideUp(notes: TieNotes) -> TabSlide {
        TabSlide(notes: notes, direction: SLIDE_UP)
    }

    public static func createSlideDown(notes: TieNotes) -> TabSlide {
        TabSlide(notes: notes, direction: SLIDE_DOWN)
    }

    // MARK: - Init

    public init(notes: TieNotes, direction: Int? = nil) {
        var dir = direction

        // Determine slide direction automatically if not provided
        if dir == nil {
            if let firstNote = notes.firstNote as? TabNote,
               let lastNote = notes.lastNote as? TabNote {
                let firstFret = Int(firstNote.getPositions()[0].fret)
                let lastFret = Int(lastNote.getPositions()[0].fret)

                if let f = firstFret, let l = lastFret {
                    dir = f > l ? TabSlide.SLIDE_DOWN : TabSlide.SLIDE_UP
                } else {
                    dir = TabSlide.SLIDE_UP
                }
            } else {
                dir = TabSlide.SLIDE_UP
            }
        }

        super.init(notes: notes, text: "sl.")

        self.direction = dir
        renderOptions.cp1 = 11
        renderOptions.cp2 = 14
        renderOptions.yShift = 0.5
    }

    // MARK: - Render Tie

    override public func renderTie(
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

        guard direction == TabSlide.SLIDE_UP || direction == TabSlide.SLIDE_DOWN else {
            fatalError("[VexError] BadSlide: Invalid slide direction")
        }

        let firstIndices = notes.firstIndices
        for i in 0..<firstIndices.count {
            let slideY = firstYs[firstIndices[i]] + renderOptions.yShift

            guard !slideY.isNaN else {
                fatalError("[VexError] BadArguments: Bad indices for slide rendering.")
            }

            ctx.beginPath()
            ctx.moveTo(firstXPx, slideY + 3 * Double(direction))
            ctx.lineTo(lastXPx, slideY - 3 * Double(direction))
            ctx.closePath()
            ctx.stroke()
        }

        setRendered()
    }
}
