// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Mike Corrigan
//
// Port of `src/tremolo.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - Tremolo

/// Tremolo implements tremolo notation.
public final class Tremolo: Modifier {

    override public class var category: String { "Tremolo" }

    // MARK: - Properties

    /// Number of bars.
    public let num: Int

    // MARK: - Init

    /// - Parameter num: number of bars.
    public init(_ num: Int) {
        self.num = num
        super.init()
        position = .center
        text = Glyphs.tremolo1
    }

    // MARK: - Draw

    /// Draw the tremolo on the rendering context.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        let stemDirection = note.getStemDirection()
        let scale = note.getFontScale()
        let ySpacing = Metrics.getDouble("Tremolo.spacing") * stemDirection.signDouble * scale

        let x = note.getAbsoluteX()
            + (stemDirection == Stem.UP ? note.getGlyphWidth() - Stem.WIDTH / 2 : Stem.WIDTH / 2)
        var y = note.getStemExtents().topY + (num <= 3 ? ySpacing : 0)

        setFontSize(Metrics.getDouble("Tremolo.fontSize") * scale)

        for _ in 0..<num {
            renderText(ctx, xPos: x, yPos: y)
            y += ySpacing
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Tremolo", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(Tremolo(2), index: 0)
        _ = notes[2].addModifier(Tremolo(3), index: 0)

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
