// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Taehoon Moon 2014. MIT License.

import Foundation

// MARK: - TimeSigNote

/// A note that renders a time signature within a voice.
/// Has no duration and consumes no ticks.
public final class TimeSigNote: Note {

    override public class var CATEGORY: String { "TimeSigNote" }

    // MARK: - Properties

    public let timeSig: TimeSignature

    // MARK: - Init

    public init(timeSpec: String, customPadding: Double = 15) {
        self.timeSig = TimeSignature(timeSpec: timeSpec, customPadding: customPadding)

        super.init(NoteStruct(duration: "b"))

        let glyph = timeSig.getGlyph()
        setTickableWidth(glyph.getMetrics().width)
        ignoreTicks = true
    }

    // MARK: - Overrides

    override public func addToModifierContext(_ mc: ModifierContext) -> Self {
        // TimeSigNotes don't participate in modifier context
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

        let tsGlyph = timeSig.getGlyph()
        if tsGlyph.getContext() == nil {
            _ = tsGlyph.setContext(ctx)
        }

        _ = tsGlyph.setStave(stave)
        _ = tsGlyph.setYShift(stave.getYForLine(2) - stave.getYForGlyphs())
        tsGlyph.renderToStave(x: getAbsoluteX())
    }
}
