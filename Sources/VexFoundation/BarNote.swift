// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - BarNote

/// A note that renders a bar line within a voice.
/// Has no duration and consumes no ticks.
public final class BarNote: Note {

    override public class var CATEGORY: String { "BarNote" }

    // MARK: - Properties

    public var barlineType: BarlineType
    public var barline: Barline

    private static let widths: [BarlineType: Double] = [
        .single: 8,
        .double: 12,
        .end: 15,
        .repeatBegin: 14,
        .repeatEnd: 14,
        .repeatBoth: 18,
        .none: 0,
    ]

    // MARK: - Init

    public init(type: BarlineType = .single) {
        self.barlineType = type
        self.barline = Barline(type)

        super.init(NoteStruct(duration: "b"))

        ignoreTicks = true
        setTickableWidth(BarNote.widths[type] ?? 0)
    }

    // MARK: - Type

    public func getType() -> BarlineType { barlineType }

    @discardableResult
    public func setType(_ type: BarlineType) -> Self {
        barlineType = type
        barline = Barline(type)
        setTickableWidth(BarNote.widths[type] ?? 0)
        return self
    }

    // MARK: - Overrides

    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // BarNotes don't participate in modifier context
        return self
    }

    override public func preFormat() {
        preFormatted = true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        applyStyle(context: ctx)

        _ = barline.setBarlineType(barlineType)
        barline.modifierX = getAbsoluteX()
        try barline.drawStave(stave: checkStave())

        restoreStyle(context: ctx)
        setRendered()
    }
}
