// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Vibrato Render Options

public struct VibratoRenderOptions {
    public var harsh: Bool = false
    public var vibratoWidth: Double = 20
    public var waveHeight: Double = 6
    public var waveWidth: Double = 4
    public var waveGirth: Double = 2

    public init(
        harsh: Bool = false,
        vibratoWidth: Double = 20,
        waveHeight: Double = 6,
        waveWidth: Double = 4,
        waveGirth: Double = 2
    ) {
        self.harsh = harsh
        self.vibratoWidth = vibratoWidth
        self.waveHeight = waveHeight
        self.waveWidth = waveWidth
        self.waveGirth = waveGirth
    }
}

// MARK: - Vibrato

/// Modifier that renders vibrato notation on notes.
public final class Vibrato: Modifier {

    override public class var category: String { "Vibrato" }

    // MARK: - Properties

    public var vibratoRenderOptions = VibratoRenderOptions()

    // MARK: - Init

    public override init() {
        super.init()
        position = .right
        _ = setVibratoWidth(vibratoRenderOptions.vibratoWidth)
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ vibratos: [Vibrato],
        state: inout ModifierContextState,
        context: ModifierContext
    ) -> Bool {
        if vibratos.isEmpty { return false }

        let textLine = state.topTextLine
        var width: Double = 0
        var shift = state.rightShift - 7

        // If there's a bend, drop the text line
        // (Bend is not yet ported — check if available)
        state.topTextLine += 1

        for vibrato in vibratos {
            _ = vibrato.setXShift(shift)
            _ = vibrato.setTextLine(textLine)
            width += vibrato.getWidth()
            shift += width
        }

        state.rightShift += width
        return true
    }

    // MARK: - Setters

    @discardableResult
    public func setHarsh(_ harsh: Bool) -> Self {
        vibratoRenderOptions.harsh = harsh
        return self
    }

    @discardableResult
    public func setVibratoWidth(_ width: Double) -> Self {
        vibratoRenderOptions.vibratoWidth = width
        _ = setWidth(width)
        return self
    }

    // MARK: - Static Render

    /// Static rendering method used by both Vibrato and VibratoBracket.
    public static func renderVibrato(
        ctx: any RenderContext,
        x: Double,
        y: Double,
        opts: VibratoRenderOptions
    ) {
        let harsh = opts.harsh
        let vibratoWidth = opts.vibratoWidth
        let waveWidth = opts.waveWidth
        let waveGirth = opts.waveGirth
        let waveHeight = opts.waveHeight
        let numWaves = vibratoWidth / waveWidth

        ctx.beginPath()

        var cx = x
        if harsh {
            ctx.moveTo(cx, y + waveGirth + 1)
            for _ in 0..<Int(numWaves / 2) {
                ctx.lineTo(cx + waveWidth, y - waveHeight / 2)
                cx += waveWidth
                ctx.lineTo(cx + waveWidth, y + waveHeight / 2)
                cx += waveWidth
            }
            for _ in 0..<Int(numWaves / 2) {
                ctx.lineTo(cx - waveWidth, y - waveHeight / 2 + waveGirth + 1)
                cx -= waveWidth
                ctx.lineTo(cx - waveWidth, y + waveHeight / 2 + waveGirth + 1)
                cx -= waveWidth
            }
            ctx.fill()
        } else {
            ctx.moveTo(cx, y + waveGirth)
            for _ in 0..<Int(numWaves / 2) {
                ctx.quadraticCurveTo(
                    cx + waveWidth / 2, y - waveHeight / 2,
                    cx + waveWidth, y
                )
                cx += waveWidth
                ctx.quadraticCurveTo(
                    cx + waveWidth / 2, y + waveHeight / 2,
                    cx + waveWidth, y
                )
                cx += waveWidth
            }
            for _ in 0..<Int(numWaves / 2) {
                ctx.quadraticCurveTo(
                    cx - waveWidth / 2, y + waveHeight / 2 + waveGirth,
                    cx - waveWidth, y + waveGirth
                )
                cx -= waveWidth
                ctx.quadraticCurveTo(
                    cx - waveWidth / 2, y - waveHeight / 2 + waveGirth,
                    cx - waveWidth, y + waveGirth
                )
                cx -= waveWidth
            }
            ctx.fill()
        }
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        guard let staveNote = note as? StaveNote else { return }
        let start = staveNote.getModifierStartXY(position: .right, index: checkIndex())

        let vx = start.x + xShift
        let vy = note.getYForTopText(textLine) + 2

        Vibrato.renderVibrato(ctx: ctx, x: vx, y: vy, opts: vibratoRenderOptions)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Vibrato", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[1].addModifier(Vibrato())
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
