// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Options for tempo markings.
public struct StaveTempoOptions {
    public var bpm: Int?
    public var duration: NoteValue?
    public var dots: Int?
    public var name: String?

    public init(bpm: Int? = nil, duration: NoteValue? = nil, dots: Int? = nil, name: String? = nil) {
        self.bpm = bpm
        self.duration = duration
        self.dots = dots
        self.name = name
    }

    public init(bpm: Int? = nil, duration: String?, dots: Int? = nil, name: String? = nil) throws {
        self.bpm = bpm
        if let duration {
            guard let parsed = NoteValue(parsing: duration) else {
                throw NoteDurationParseError.invalidValue(duration)
            }
            self.duration = parsed
        } else {
            self.duration = nil
        }
        self.dots = dots
        self.name = name
    }

    public init?(parsingDuration duration: String?, bpm: Int? = nil, dots: Int? = nil, name: String? = nil) {
        guard let parsed = try? StaveTempoOptions(bpm: bpm, duration: duration, dots: dots, name: name) else {
            return nil
        }
        self = parsed
    }
}

/// Renders tempo markings (e.g. "Allegro ♩= 120") on a stave.
public final class StaveTempo: StaveModifier {

    override public class var category: String { "StaveTempo" }

    override public class var textFont: FontInfo {
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
        let name = tempo.name
        let duration = tempo.duration
        let dots = tempo.dots ?? 0
        let bpm = tempo.bpm
        var x = modifierX + tempoShiftX + xShift
        let y = stave.getYForTopText(1) + tempoShiftY

        ctx.save()
        let textFormatter = TextFormatter.create(font: fontInfo, context: ctx)

        if let name {
            ctx.setFont(fontInfo)
            ctx.fillText(name, x, y)
            x += textFormatter.getWidthForTextInPx(name)
        }

        if let duration, let bpm {
            var noteTextFont = fontInfo
            noteTextFont.weight = VexFontWeight.normal.rawValue
            noteTextFont.style = VexFontStyle.normal.rawValue
            ctx.setFont(noteTextFont)
            let noteTextFormatter = TextFormatter.create(font: noteTextFont, context: ctx)

            if name != nil {
                x += noteTextFormatter.getWidthForTextInPx("|")
                ctx.fillText("(", x, y)
                x += noteTextFormatter.getWidthForTextInPx("(")
            }

            if let glyphProps = Tables.getGlyphProps(duration: duration) {
                x += 3 * scale

                Glyph.renderGlyph(
                    ctx: ctx,
                    xPos: x,
                    yPos: y,
                    point: glyphFontScale,
                    code: glyphProps.codeHead
                )
                x += Glyph.getWidth(code: glyphProps.codeHead, point: glyphFontScale)

                if glyphProps.stem {
                    let stemHeight = 30 + (glyphProps.beamCount > 0 ? 3 * Double(glyphProps.beamCount - 1) : 0)
                    let scaledHeight = stemHeight * scale
                    let yTop = y - scaledHeight
                    ctx.fillRect(x - scale, yTop, scale, scaledHeight)

                    if glyphProps.flag, let flagCode = glyphProps.codeFlagUpstem, !flagCode.isEmpty {
                        let flagMetrics = Glyph.renderGlyph(
                            ctx: ctx,
                            xPos: x,
                            yPos: yTop,
                            point: glyphFontScale,
                            code: flagCode,
                            category: "flag.staveTempo"
                        )
                        let resolution = (try? flagMetrics.font.getResolution()) ?? 1000
                        x += (flagMetrics.width * Tables.NOTATION_FONT_SCALE) / resolution
                    }
                }

                for _ in 0..<dots {
                    x += 6 * scale
                    ctx.beginPath()
                    ctx.arc(x, y + 2 * scale, 2 * scale, 0, .pi * 2, false)
                    ctx.fill()
                }
            }

            ctx.fillText(" = \(bpm)\(name != nil ? ")" : "")", x + 3 * scale, y)
        }

        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveTempo", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 150) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s = f.Stave(x: 10, y: 40, width: 490)
        _ = s.addClef(.treble).addTimeSignature(.meter(4, 4))
        _ = s.addModifier(StaveTempo(
            tempo: StaveTempoOptions(bpm: 120, duration: .quarter),
            x: 0, shiftY: -15
        ))

        try? f.draw()
    }
    .padding()
}
#endif
