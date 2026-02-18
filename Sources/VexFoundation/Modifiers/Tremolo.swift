// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Mike Corrigan. MIT License.

import Foundation

// MARK: - Tremolo

/// Modifier that renders tremolo notation (repeated strokes) on note stems.
public final class Tremolo: Modifier {

    override public class var category: String { "Tremolo" }

    // MARK: - Properties

    public let num: Int
    public let code: String = "tremolo1"

    /// Extra spacing required for big strokes.
    public var ySpacingScale: Double = 1

    /// Font scaling for big strokes.
    public var extraStrokeScale: Double = 1

    // MARK: - Init

    public init(_ num: Int) {
        self.num = num
        super.init()
        position = .center
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        let stemDirection = note.getStemDirection()

        let category = "tremolo.default"

        guard let musicFont = Glyph.MUSIC_FONT_STACK.first else { return }
        var ySpacing = (musicFont.lookupMetric("\(category).spacing") as? Double ?? 12)
            * stemDirection.signDouble
        ySpacing *= ySpacingScale

        let height = Double(num) * ySpacing
        var y = note.getStemExtents().baseY - height

        if stemDirection == .down {
            y += (musicFont.lookupMetric("\(category).offsetYStemDown") as? Double ?? 0)
        } else {
            y += (musicFont.lookupMetric("\(category).offsetYStemUp") as? Double ?? 0)
        }

        let fontScale = (musicFont.lookupMetric("\(category).point") as? Double)
            ?? Note.getPoint()

        guard let staveNote = note as? StaveNote else { return }
        let start = staveNote.getModifierStartXY(position: position, index: checkIndex())
        var x = start.x

        let stemKey = stemDirection == Stem.UP ? "Up" : "Down"
        x += (musicFont.lookupMetric("\(category).offsetXStem\(stemKey)") as? Double ?? 0)

        for _ in 0..<num {
            Glyph.renderGlyph(
                ctx: ctx,
                xPos: x,
                yPos: y,
                point: fontScale,
                code: code,
                category: category,
                scale: extraStrokeScale
            )
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
        FontLoader.loadDefaultFonts()

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
