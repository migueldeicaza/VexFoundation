// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Taehoon Moon 2014. MIT License.

import Foundation

// MARK: - TimeSigNote

/// A note that renders a time signature within a voice.
/// Has no duration and consumes no ticks.
public final class TimeSigNote: Note {

    override public class var category: String { "TimeSigNote" }

    // MARK: - Properties

    public let timeSig: TimeSignature

    // MARK: - Init

    public init(timeSpec: TimeSignatureSpec, customPadding: Double = 15) {
        self.timeSig = TimeSignature(timeSpec: timeSpec, customPadding: customPadding)

        super.init(NoteStruct(duration: .twoFiftySixth))

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

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TimeSigNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(score.notes("C5/q, D5, E5, F5"))]
        )).addClef(.treble).addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
