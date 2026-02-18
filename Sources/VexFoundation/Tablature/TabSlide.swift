// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - TabSlide

/// Implements slide notation between contiguous tab notes.
/// Renders straight diagonal lines instead of curved ties.
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

    public init(notes: TieNotes, direction: TieDirection? = nil) {
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
        direction: TieDirection,
        firstXPx: Double,
        lastXPx: Double,
        firstYs: [Double],
        lastYs: [Double]
    ) throws {
        guard !firstYs.isEmpty && !lastYs.isEmpty else {
            fatalError("[VexError] BadArguments: No Y-values to render")
        }

        let ctx = try checkContext()

        let firstIndices = notes.firstIndices
        for i in 0..<firstIndices.count {
            let slideY = firstYs[firstIndices[i]] + renderOptions.yShift

            guard !slideY.isNaN else {
                fatalError("[VexError] BadArguments: Bad indices for slide rendering.")
            }

            ctx.beginPath()
            ctx.moveTo(firstXPx, slideY + 3 * direction.signDouble)
            ctx.lineTo(lastXPx, slideY - 3 * direction.signDouble)
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
        FontLoader.loadDefaultFonts()

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

        let slideUp = TabSlide(notes: TieNotes(firstNote: notes[0], lastNote: notes[1], firstIndices: [0], lastIndices: [0]), direction: TabSlide.SLIDE_UP)
        _ = slideUp.setContext(ctx)

        let slideDown = TabSlide(notes: TieNotes(firstNote: notes[2], lastNote: notes[3], firstIndices: [0], lastIndices: [0]), direction: TabSlide.SLIDE_DOWN)
        _ = slideDown.setContext(ctx)

        try? f.draw()
        try? slideUp.draw()
        try? slideDown.draw()
    }
    .padding()
}
#endif
