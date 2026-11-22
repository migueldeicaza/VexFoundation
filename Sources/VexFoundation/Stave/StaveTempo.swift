// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author: Radosaw Eichler 2012
//
// Port of `src/stavetempo.ts` (VexFlow 5.0.0).

import Foundation

/// Options for tempo markings.
public struct StaveTempoOptions {
    /// Free text i.e.: 'Adagio', 'Andate grazioso', ...
    public var name: String?
    /// Indicates whether or not to put the metronome mark in parentheses.
    public var parenthesis: Bool
    /// The graphical note type to use in a metronome mark.
    public var duration: NoteValue?
    /// The number of augmentation dots for a metronome mark note.
    public var dots: Int?
    /// The beats per minute associated with the metronome mark, i.e.: 120.
    public var bpm: Int?
    /// Text for the beats per minute, i.e.: "c. 108", "132-144". Used instead of `bpm` when set.
    public var bpmText: String?
    /// The graphical note type to use at the right of the equation in a metronome mark.
    public var duration2: NoteValue?
    /// The number of augmentation dots for the note at the right of the equation.
    public var dots2: Int?

    public init(
        bpm: Int? = nil,
        duration: NoteValue? = nil,
        dots: Int? = nil,
        name: String? = nil,
        parenthesis: Bool = false,
        bpmText: String? = nil,
        duration2: NoteValue? = nil,
        dots2: Int? = nil
    ) {
        self.bpm = bpm
        self.duration = duration
        self.dots = dots
        self.name = name
        self.parenthesis = parenthesis
        self.bpmText = bpmText
        self.duration2 = duration2
        self.dots2 = dots2
    }

    public init(bpm: Int? = nil, duration: String?, dots: Int? = nil, name: String? = nil) throws {
        let parsedDuration: NoteValue?
        if let duration {
            guard let parsed = NoteValue(parsing: duration) else {
                throw NoteDurationParseError.invalidValue(duration)
            }
            parsedDuration = parsed
        } else {
            parsedDuration = nil
        }
        self.init(bpm: bpm, duration: parsedDuration, dots: dots, name: name)
    }

    public init?(parsingDuration duration: String?, bpm: Int? = nil, dots: Int? = nil, name: String? = nil) {
        guard let parsed = try? StaveTempoOptions(bpm: bpm, duration: duration, dots: dots, name: name) else {
            return nil
        }
        self = parsed
    }

    /// The BPM text as upstream renders it (`'' + bpm`), or nil when the BPM is not set.
    var bpmString: String? {
        if let bpmText, !bpmText.isEmpty { return bpmText }
        if let bpm, bpm != 0 { return "\(bpm)" }
        return nil
    }
}

/// Renders tempo markings (e.g. "Allegro (♩ = 120)") on a stave.
public final class StaveTempo: StaveModifier {

    override public class var category: String { "StaveTempo" }

    // MARK: - Properties

    public var tempo: StaveTempoOptions

    /// Glyph codes of the metronome mark notes. The keys are duration strings.
    public let durationToCode: [String: String] = [
        "1/4": Glyphs.metNoteDoubleWholeSquare,
        "long": Glyphs.metNoteDoubleWholeSquare,
        "1/2": Glyphs.metNoteDoubleWhole,
        "breve": Glyphs.metNoteDoubleWhole,
        "1": Glyphs.metNoteWhole,
        "whole": Glyphs.metNoteWhole,
        "w": Glyphs.metNoteWhole,
        "2": Glyphs.metNoteHalfUp,
        "half": Glyphs.metNoteHalfUp,
        "h": Glyphs.metNoteHalfUp,
        "4": Glyphs.metNoteQuarterUp,
        "quarter": Glyphs.metNoteQuarterUp,
        "q": Glyphs.metNoteQuarterUp,
        "8": Glyphs.metNote8thUp,
        "eighth": Glyphs.metNote8thUp,
        "16": Glyphs.metNote16thUp,
        "16th": Glyphs.metNote16thUp,
        "32": Glyphs.metNote32ndUp,
        "32nd": Glyphs.metNote32ndUp,
        "64": Glyphs.metNote64thUp,
        "64th": Glyphs.metNote64thUp,
        "128": Glyphs.metNote128thUp,
        "128th": Glyphs.metNote128thUp,
        "256": Glyphs.metNote256thUp,
        "256th": Glyphs.metNote256thUp,
        "512": Glyphs.metNote512thUp,
        "512th": Glyphs.metNote512thUp,
        "1024": Glyphs.metNote1024thUp,
        "1024th": Glyphs.metNote1024thUp,
    ]

    // MARK: - Init

    public init(tempo: StaveTempoOptions, x: Double, shiftY: Double) {
        self.tempo = tempo
        super.init()

        position = .above
        self.x = x
        setXShift(10)
        setYShift(shiftY)
    }

    @discardableResult
    public func setTempo(_ tempo: StaveTempoOptions) -> Self {
        self.tempo = tempo
        return self
    }

    // MARK: - Deprecated 4.x API

    @available(*, deprecated, renamed: "setXShift(_:)")
    @discardableResult
    public func setShiftX(_ x: Double) -> Self { setXShift(x) }

    @available(*, deprecated, renamed: "setYShift(_:)")
    @discardableResult
    public func setShiftY(_ y: Double) -> Self { setYShift(y) }

    // MARK: - Draw

    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let shiftX = stave.getModifierXShift(getPosition().rawValue)
        let ctx = try stave.checkContext()
        setRendered()

        let name = tempo.name.flatMap { $0.isEmpty ? nil : $0 }
        let duration = tempo.duration
        let dots = tempo.dots ?? 0
        let bpm = tempo.bpmString
        let duration2 = tempo.duration2
        let dots2 = tempo.dots2 ?? 0
        let parenthesis = tempo.parenthesis
        var x = self.x + shiftX
        let y = stave.getYForTopText(1)
        let el = VexElement(category: "StaveTempo.glyph")
        let elText = VexElement(category: "StaveTempo")

        // VexFlowPatch: wrap entire tempo marking in an SVG group for DOM access
        _ = ctx.openGroup("stavetempo", nil)

        if let name {
            text = name
            fontInfo = Metrics.getFontInfo("StaveTempo.name")
            renderText(ctx, xPos: shiftX, yPos: y)
            x += getWidth() + 3
        }

        if (name != nil && duration != nil) || parenthesis {
            elText.setText("(")
            elText.renderText(ctx, xPos: x + xShift, yPos: y + yShift)
            x += elText.getWidth() + 3
        }

        if let duration {
            el.setText(durationToCode[duration.rawValue] ?? "")
            el.renderText(ctx, xPos: x + xShift, yPos: y + yShift)
            x += el.getWidth() + 3
            if dots > 0 {
                // Draw dot
                el.setText(Glyphs.metAugmentationDot)
                for _ in 0..<dots {
                    el.renderText(ctx, xPos: x + xShift, yPos: y + 2 + yShift)
                    x += el.getWidth() + 3
                }
            }
            // VexFlowPatch: wrap BPM text in its own SVG group
            _ = ctx.openGroup("bpm", nil)
            elText.setText("=")
            elText.renderText(ctx, xPos: x + xShift, yPos: y + yShift)
            x += elText.getWidth() + 3
            if let duration2 {
                el.setText(durationToCode[duration2.rawValue] ?? "")
                el.renderText(ctx, xPos: x + xShift, yPos: y + yShift)
                x += el.getWidth() + 3
                if dots2 > 0 {
                    // Draw dot
                    el.setText(Glyphs.metAugmentationDot)
                    for _ in 0..<dots2 {
                        el.renderText(ctx, xPos: x + xShift, yPos: y + 2 + yShift)
                        x += el.getWidth() + 3
                    }
                }
            } else if let bpm {
                elText.setText(bpm)
                elText.renderText(ctx, xPos: x + xShift, yPos: y + yShift)
                x += elText.getWidth() + 3
            }
            if name != nil || parenthesis {
                elText.setText(")")
                elText.renderText(ctx, xPos: x + xShift, yPos: y + yShift)
            }
            ctx.closeGroup()
        }

        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveTempo", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 150) { ctx in
        ctx.clear()

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
