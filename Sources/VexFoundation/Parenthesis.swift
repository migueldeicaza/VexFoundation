// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Rodrigo Vilar. MIT License.

import Foundation

// MARK: - Parenthesis

/// Renders parenthesis modifiers around note heads.
public final class Parenthesis: Modifier {

    override public class var CATEGORY: String { "Parenthesis" }

    // MARK: - Properties

    public var point: Double

    // MARK: - Static Methods

    /// Add parentheses to all notes (left and right on every key).
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
                xWidthR = max(xWidthR, shift + parenthesis.getWidth())
            }
            if pos == .left {
                shift = note.getLeftParenthesisPx(index: index)
                xWidthL = max(xWidthL, shift + parenthesis.getWidth())
            }
            _ = parenthesis.setXShift(shift)
        }
        state.leftShift += xWidthL
        state.rightShift += xWidthR

        return true
    }

    // MARK: - Init

    public init(position: ModifierPosition) {
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        self.point = (musicFont.lookupMetric("parenthesis.default.point") as? Double)
            ?? Note.getPoint("default")

        super.init()

        self.position = position
        let width = (musicFont.lookupMetric("parenthesis.default.width") as? Double) ?? 7
        _ = setWidth(width)
    }

    // MARK: - Set Note

    @discardableResult
    public override func setNote(_ note: Note) -> Self {
        self.note = note
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        point = (musicFont.lookupMetric("parenthesis.default.point") as? Double)
            ?? Note.getPoint("default")
        let width: Double = (musicFont.lookupMetric("parenthesis.default.width") as? Double) ?? 7
        _ = setWidth(width)

        if note is GraceNote {
            point = (musicFont.lookupMetric("parenthesis.gracenote.point") as? Double)
                ?? Note.getPoint("gracenote")
            let graceWidth = (musicFont.lookupMetric("parenthesis.gracenote.width") as? Double) ?? 3
            _ = setWidth(graceWidth)
        }
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        guard let staveNote = note as? StaveNote else { return }
        let start = staveNote.getModifierStartXY(position: position, index: checkIndex(), forceFlagRight: true)
        let x = start.x + xShift
        let y = start.y + yShift

        if position == .right {
            Glyph.renderGlyph(ctx: ctx, xPos: x + 1, yPos: y, point: point,
                              code: "noteheadParenthesisRight",
                              category: "noteHead.standard.noteheadParenthesisRight")
        } else if position == .left {
            Glyph.renderGlyph(ctx: ctx, xPos: x - 2, yPos: y, point: point,
                              code: "noteheadParenthesisLeft",
                              category: "noteHead.standard.noteheadParenthesisLeft")
        }
    }
}
