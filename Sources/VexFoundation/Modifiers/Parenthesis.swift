// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Rodrigo Vilar
//
// Port of `src/parenthesis.ts` (VexFlow 5.2.0).

import Foundation

// MARK: - Parenthesis

/// Parenthesis implements parenthesis modifiers for notes.
public final class Parenthesis: Modifier {

    override public class var category: String { "Parenthesis" }

    // MARK: - Static Methods

    /// Add parentheses to the notes.
    public static func buildAndAttach(_ notes: [Note]) {
        for note in notes {
            for i in 0..<note.keys.count {
                _ = note.addModifier(Parenthesis(position: .left), index: i)
                _ = note.addModifier(Parenthesis(position: .right), index: i)
            }
        }
    }

    /// Arrange parentheses inside a ModifierContext.
    @discardableResult
    public static func format(
        _ parentheses: [Parenthesis],
        state: inout ModifierContextState
    ) -> Bool {
        if parentheses.isEmpty { return false }

        var xWidthL: Double = 0
        var xWidthR: Double = 0

        for parenthesis in parentheses {
            let note = parenthesis.getNote()
            let pos = parenthesis.getPosition()
            let index = parenthesis.checkIndex()

            var shift: Double = 0

            if pos == .right {
                shift = note.getRightParenthesisPx(index: index)
                xWidthR = xWidthR > shift + parenthesis.width ? xWidthR : shift + parenthesis.width
            }
            if pos == .left {
                shift = note.getLeftParenthesisPx(index: index) + parenthesis.width
                xWidthL = xWidthL > shift + parenthesis.width ? xWidthL : shift + parenthesis.width
            }
            _ = parenthesis.setXShift(shift)
        }
        state.leftShift += xWidthL
        state.rightShift += xWidthR

        return true
    }

    // MARK: - Init

    /// - Parameter position: `.left` (default) or `.right`.
    public init(position: ModifierPosition = .left) {
        super.init()

        self.position = position
        if position == .right {
            text = "\u{E0F6}" // noteheadParenthesisRight
        } else if position == .left {
            text = "\u{E0F5}" // noteheadParenthesisLeft
        }
    }

    // MARK: - Set Note

    /// Set the associated note.
    @discardableResult
    public override func setNote(_ note: Note) -> Self {
        self.note = note
        // Copy structured font data so attachment also works without a browser document.
        fontInfo = note.fontInfo
        return self
    }

    // MARK: - Draw

    /// Render the parenthesis.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        let start = note.getModifierStartXY(position: position, index: index ?? 0, forceFlagRight: true)
        renderText(ctx, xPos: start.x, yPos: start.y)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Parenthesis", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        Parenthesis.buildAndAttach([notes[1]])

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
