// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tabslide.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - TabSlide

/// Slides between contiguous tab notes. A slide is a straight diagonal line
/// instead of a curved tie, with the text "sl.".
public final class TabSlide: TabTie {

    override public class var category: String { "TabSlide" }

    // MARK: - Constants

    public static let SLIDE_UP: TieDirection = .up
    public static let SLIDE_DOWN: TieDirection = .down

    // MARK: - Factory Methods

    public static func createSlideUp(notes: TieNotes) -> TabSlide {
        TabSlide(notes: notes, direction: SLIDE_UP)
    }

    public static func createSlideDown(notes: TieNotes) -> TabSlide {
        TabSlide(notes: notes, direction: SLIDE_DOWN)
    }

    // MARK: - Init

    /// - Parameters:
    ///   - notes: `firstNote` and `lastNote` are the start and end notes of the
    ///     slide. `firstIndexes` gives the string and fret positions of the
    ///     `TabNote` that the slide uses (zero indexed). `lastIndexes` is not
    ///     used: it is assumed to be the same as `firstIndexes`.
    ///   - direction: `TabSlide.SLIDE_UP` or `TabSlide.SLIDE_DOWN`.
    public init(notes: TieNotes, direction: TieDirection? = nil) {
        var dir = direction

        // Determine the direction automatically if it is not provided.
        if dir == nil {
            if let firstNote = notes.firstNote as? TabNote,
               let lastNote = notes.lastNote as? TabNote {
                let firstFret = Int(firstNote.getPositions()[0].fret)
                let lastFret = Int(lastNote.getPositions()[0].fret)

                // If either fret is 'X', the integer parse fails.
                // Choose TabSlide.SLIDE_UP by default.
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

    /// Draw the slide lines. `firstX` and `lastX` are in pixels.
    override public func renderTie(
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
        let firstX = firstX // pixel units
        let firstYs = firstYs
        let lastX = lastX // pixel units

        let direction = direction.signDouble

        let firstIndexes = notes.firstIndexes
        for i in 0..<firstIndexes.count {
            guard firstIndexes[i] >= 0, firstIndexes[i] < firstYs.count else {
                throw StaveTieError.badIndices
            }
            let slideY = firstYs[firstIndexes[i]] + renderOptions.yShift

            if slideY.isNaN {
                throw StaveTieError.badIndices
            }

            ctx.beginPath()
            ctx.moveTo(firstX, slideY + 3 * direction)
            ctx.lineTo(lastX, slideY - 3 * direction)
            ctx.closePath()
            ctx.stroke()
        }

        setRendered()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TabSlide", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)

        let ts = f.TabStave(x: 10, y: 10, width: 490)
        _ = ts.addTabGlyph()

        let notes: [TabNote] = [
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 9)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 3, fret: 7)], duration: .quarter)),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 3, fret: 3)], duration: .quarter)),
        ]

        let voice = f.Voice(timeSignature: .meter(4, 4))
        _ = voice.addTickables(notes)

        let formatter = f.Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 400)

        let slideUp = TabSlide(notes: TieNotes(firstNote: notes[0], lastNote: notes[1], firstIndexes: [0], lastIndexes: [0]), direction: TabSlide.SLIDE_UP)
        _ = slideUp.setContext(ctx)

        let slideDown = TabSlide(notes: TieNotes(firstNote: notes[2], lastNote: notes[3], firstIndexes: [0], lastIndexes: [0]), direction: TabSlide.SLIDE_DOWN)
        _ = slideDown.setContext(ctx)

        try? f.draw()
        try? slideUp.draw()
        try? slideDown.draw()
    }
    .padding()
}
#endif
