// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Options for tempo markings.
public struct StaveTempoOptions {
    public var bpm: Int?
    public var duration: String?
    public var dots: Int?
    public var name: String?

    public init(bpm: Int? = nil, duration: String? = nil, dots: Int? = nil, name: String? = nil) {
        self.bpm = bpm
        self.duration = duration
        self.dots = dots
        self.name = name
    }
}

/// Renders tempo markings (e.g. "Allegro ♩= 120") on a stave.
public final class StaveTempo: StaveModifier {

    override public class var CATEGORY: String { "StaveTempo" }

    override public class var TEXT_FONT: FontInfo {
        FontInfo(
            family: VexFont.SERIF,
            size: 14,
            weight: VexFontWeight.bold.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    public var tempo: StaveTempoOptions
    public var tempoShiftX: Double = 10
    public var tempoShiftY: Double
    public var glyphFontScale: Double = 30

    // MARK: - Init

    public init(tempo: StaveTempoOptions, x: Double, shiftY: Double) {
        self.tempo = tempo
        self.tempoShiftY = shiftY
        super.init()
        self.position = .above
        self.modifierX = x
        resetFont()
    }

    @discardableResult
    public func setTempo(_ tempo: StaveTempoOptions) -> Self {
        self.tempo = tempo
        return self
    }

    @discardableResult
    public func setShiftX(_ x: Double) -> Self {
        tempoShiftX = x
        return self
    }

    @discardableResult
    public func setShiftY(_ y: Double) -> Self {
        tempoShiftY = y
        return self
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()

        let scale = glyphFontScale / Tables.NOTATION_FONT_SCALE
        var x = modifierX + tempoShiftX + xShift
        let y = stave.getYForTopText(1) + tempoShiftY

        ctx.save()
        ctx.setFont(fontInfo)

        // Draw tempo name
        if let name = tempo.name {
            ctx.fillText(name, x, y)
            x += ctx.measureText(name).width
        }

        // Draw note + BPM
        if let duration = tempo.duration, let bpm = tempo.bpm {
            if tempo.name != nil {
                ctx.fillText(" (", x, y)
                x += ctx.measureText(" (").width
            }

            // Draw note glyph
            if let glyphProps = Tables.getGlyphProps(duration: duration) {
                x += 3 * scale

                // Render note head
                if !glyphProps.codeHead.isEmpty {
                    Glyph.renderGlyph(ctx: ctx, xPos: x, yPos: y, point: glyphFontScale,
                                      code: glyphProps.codeHead)
                }

                x += Glyph.getWidth(code: glyphProps.codeHead.isEmpty ? "noteheadBlack" : glyphProps.codeHead,
                                     point: glyphFontScale) * scale

                // Draw stem
                if glyphProps.stem {
                    let stemHeight = 30 + (glyphProps.beamCount > 0 ? 3 * Double(glyphProps.beamCount - 1) : 0)
                    let scaledHeight = stemHeight * scale
                    ctx.fillRect(x - scale, y - scaledHeight, scale, scaledHeight)

                    // Draw flag
                    if glyphProps.flag, let flagCode = glyphProps.codeFlagUpstem, !flagCode.isEmpty {
                        Glyph.renderGlyph(ctx: ctx, xPos: x, yPos: y - scaledHeight,
                                          point: glyphFontScale, code: flagCode)
                        x += 12 * scale
                    }
                }

                // Draw dots
                for _ in 0..<(tempo.dots ?? 0) {
                    x += 6 * scale
                    ctx.beginPath()
                    ctx.arc(x, y + 2 * scale, 2 * scale, 0, .pi * 2, false)
                    ctx.fill()
                }

                x += 10 * scale
            }

            ctx.fillText("= \(bpm)", x, y)
            if tempo.name != nil {
                x += ctx.measureText("= \(bpm)").width
                ctx.fillText(")", x, y)
            }
        }

        ctx.restore()
    }
}
