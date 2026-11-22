// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/vibrato.ts` (VexFlow 5.0.0).
// The vibrato is drawn as a repeated SMuFL glyph (text), not as a path.

import Foundation

// MARK: - Vibrato Render Options

public struct VibratoRenderOptions {
    /// SMuFL code point of the repeated glyph (default U+EAB0 `wiggleTrill`).
    public var code: Int = 0xEAB0
    /// Vibrato width in pixels.
    public var width: Double = 20

    public init(code: Int = 0xEAB0, width: Double = 20) {
        self.code = code
        self.width = width
    }
}

// MARK: - Vibrato

/// `Vibrato` implements diverse vibratos.
public final class Vibrato: Modifier {

    override public class var category: String { "Vibrato" }

    // MARK: - Properties

    public var renderOptions = VibratoRenderOptions()

    // MARK: - Static Format

    /// Arrange vibratos inside a `ModifierContext`.
    @discardableResult
    public static func format(
        _ vibratos: [Vibrato],
        state: inout ModifierContextState,
        context: ModifierContext
    ) -> Bool {
        if vibratos.isEmpty { return false }

        // Vibratos are always on top.
        var textLine = state.topTextLine
        var width: Double = 0
        var shift = state.rightShift - 7

        // If there's a bend, drop the text line
        let bends = context.getMembers(Bend.category).compactMap { $0 as? Bend }
        if !bends.isEmpty {
            let bendHeight = bends.map { $0.getTextHeight() }.reduce(-Double.infinity) { $0 > $1 ? $0 : $1 }
                / Tables.STAVE_LINE_DISTANCE
            textLine = textLine - (bendHeight + 1)
        } else {
            state.topTextLine += 1
        }

        // Format Vibratos
        for vibrato in vibratos {
            vibrato.setXShift(shift)
            vibrato.setTextLine(textLine)
            width += vibrato.getWidth()
            shift += width
        }

        state.rightShift += width
        return true
    }

    // MARK: - Init

    public override init() {
        super.init()
        position = .right
        renderOptions = VibratoRenderOptions(code: 0xEAB0, width: 20)
        setVibratoWidth(renderOptions.width)
    }

    // MARK: - Setters

    private static func glyph(_ code: Int) -> String {
        guard let scalar = Unicode.Scalar(UInt32(truncatingIfNeeded: code)) else { return "" }
        return String(Character(scalar))
    }

    /// Set vibrato width in pixels.
    /// Upstream throws when the glyph width is 0; here the text then keeps one glyph.
    @discardableResult
    public func setVibratoWidth(_ width: Double) -> Self {
        (try? setVibratoWidthThrowing(width)) ?? self
    }

    /// Set vibrato width in pixels. Throws when the glyph width is 0 (upstream behavior).
    @discardableResult
    public func setVibratoWidthThrowing(_ width: Double) throws -> Self {
        renderOptions.width = width
        text = Self.glyph(renderOptions.code)
        let myWidth = getWidth()
        if myWidth == 0 || myWidth.isNaN {
            throw VexError("RuntimeError", "Cannot set vibrato width if width is 0")
        }

        let items = Int((renderOptions.width / myWidth).rounded(.toNearestOrAwayFromZero))
        if items > 1 {
            for _ in 1..<items {
                text += Self.glyph(renderOptions.code)
            }
        }

        return self
    }

    /// Set vibrato code.
    @discardableResult
    public func setVibratoCode(_ code: Int) -> Self {
        renderOptions.code = code
        return setVibratoWidth(renderOptions.width)
    }

    // MARK: - Draw

    /// Draw the vibrato on the rendering context.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        let start = note.getModifierStartXY(position: .right, index: checkIndex())

        let vx = start.x
        let vy = note.getYForTopText(textLine) + 5

        renderText(ctx, xPos: vx, yPos: vy)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Vibrato", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

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
