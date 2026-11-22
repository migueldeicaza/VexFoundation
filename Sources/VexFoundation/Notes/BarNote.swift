// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/barnote.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - BarNote

/// A `BarNote` renders a bar line (see `Barline`). Bar notes can be added to a
/// voice and rendered in the middle of a stave. A bar note has no duration,
/// so it consumes no ticks, and the formatter handles it as such.
public final class BarNote: Note {

    override public class var category: String { "BarNote" }

    // MARK: - Properties

    /// Widths of the bar line types (upstream `metrics.widths`).
    public var widths: [BarlineType: Double] = [:]
    /// The type of the bar note.
    public private(set) var type: BarlineType = .single
    /// 4.x-branch fix 198b8021: the bar note keeps one `Barline`.
    public var barline: Barline!

    // MARK: - Init

    public init(type: BarlineType = .single) {
        super.init(NoteStruct(duration: .twoFiftySixth))

        widths = [
            .single: 8,
            .double: 12,
            .end: 15,
            .repeatBegin: 14,
            .repeatEnd: 14,
            .repeatBoth: 18,
            .none: 0,
        ]

        // Tell the formatter that bar notes have no duration.
        ignoreTicks = true
        setType(type)
        barline = Barline(type)
    }

    /// Create a bar note from a type string (see `Barline.typeString`).
    public convenience init(typeString: String) {
        self.init(type: Barline.typeString[typeString] ?? .single)
    }

    // MARK: - Type

    /// The type of the bar note.
    public func getType() -> BarlineType { type }

    /// Set the type of the bar note.
    @discardableResult
    public func setType(_ type: BarlineType) -> Self {
        self.type = type

        // Set width to width of relevant `Barline`.
        setWidth(widths[type] ?? 0)
        return self
    }

    /// Set the type of the bar note from a type string (see `Barline.typeString`).
    @discardableResult
    public func setType(_ type: String) -> Self {
        setType(Barline.typeString[type] ?? .single)
    }

    // MARK: - Overrides

    /// Overridden to ignore.
    @discardableResult
    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // DO NOTHING.
        return self
    }

    /// Overridden to ignore.
    override public func preFormat() {
        preFormatted = true
    }

    // MARK: - Draw

    /// Render the note to the stave.
    override public func draw() throws {
        let ctx = try checkContext()
        // 4.x-branch fix 198b8021: draw the bar line inside a `barnote` group.
        _ = ctx.openGroup("barnote", getAttribute("id"))
        barline.setType(type)
        barline.setX(getAbsoluteX())
        barline.setStave(checkStave())
        barline.setContext(ctx)
        try barline.drawWithStyle()
        ctx.closeGroup()
        setRendered()
    }
}
