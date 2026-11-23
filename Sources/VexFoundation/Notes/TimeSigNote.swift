// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/timesignote.ts` (VexFlow 5.1.0).

import Foundation

// MARK: - TimeSigNote

/// A note that renders a time signature within a voice.
/// It has no duration and consumes no ticks.
public final class TimeSigNote: Note {

    override public class var category: String { "TimeSigNote" }

    // MARK: - Properties

    public private(set) var timeSig: TimeSignature!

    // MARK: - Init

    public init(timeSpec: TimeSignatureSpec, customPadding: Double = 15) {
        super.init(NoteStruct(duration: .twoFiftySixth))

        timeSig = TimeSignature(timeSpec: timeSpec, customPadding: customPadding)

        setWidth(timeSig.getWidth())

        // Note properties
        ignoreTicks = true
    }

    // MARK: - Overrides

    /// Overridden to ignore.
    @discardableResult
    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // DO NOTHING.
        return self
    }

    override public func preFormat() {
        preFormatted = true
    }

    // MARK: - Draw

    override public func draw() throws {
        let stave = checkStave()
        let ctx = try checkContext()
        setRendered()

        _ = ctx.openGroup(groupClass("timesignote"), getAttribute("id"))
        timeSig.drawAt(ctx, stave, getAbsoluteX())
        drawPointerRect()
        ctx.closeGroup()
    }
}
