// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Text Justification

public enum TextJustification: Int {
    case left = 1
    case center = 2
    case right = 3
}

// MARK: - Text Note Struct

public struct TextNoteStruct {
    public var keys: [StaffKeySpec]
    public var duration: NoteDurationSpec
    public var text: String?
    public var glyph: String?
    public var ignoreTicks: Bool?
    public var smooth: Bool?
    public var line: Double?
    public var superscript: String?
    public var subscriptText: String?

    public init(
        keys: [StaffKeySpec] = [StaffKeySpec(letter: .b, octave: 4)],
        duration: NoteDurationSpec = .quarter,
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) {
        self.keys = keys
        self.duration = duration
        self.text = text
        self.glyph = glyph
        self.ignoreTicks = ignoreTicks
        self.smooth = smooth
        self.line = line
        self.superscript = superscript
        self.subscriptText = subscriptText
    }

    /// String-based parser for compatibility with external text inputs.
    public init(
        parsingKeys keys: [String] = ["b/4"],
        duration: String,
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) throws {
        let parsedDuration = try NoteDurationSpec(parsing: duration)
        let parsedKeys = try StaffKeySpec.parseMany(keys)
        self.init(
            keys: parsedKeys,
            duration: parsedDuration,
            text: text,
            glyph: glyph,
            ignoreTicks: ignoreTicks,
            smooth: smooth,
            line: line,
            superscript: superscript,
            subscriptText: subscriptText
        )
    }

    /// Failable parser convenience.
    public init?(
        parsingDuration duration: String,
        keys: [String] = ["b/4"],
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) {
        guard let parsed = try? TextNoteStruct(
            parsingKeys: keys,
            duration: duration,
            text: text,
            glyph: glyph,
            ignoreTicks: ignoreTicks,
            smooth: smooth,
            line: line,
            superscript: superscript,
            subscriptText: subscriptText
        ) else { return nil }
        self = parsed
    }

    /// Failable string parser convenience matching the throwing parser shape.
    public init?(
        parsingKeysOrNil keys: [String] = ["b/4"],
        duration: String,
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) {
        guard let parsed = try? TextNoteStruct(
            parsingKeys: keys,
            duration: duration,
            text: text,
            glyph: glyph,
            ignoreTicks: ignoreTicks,
            smooth: smooth,
            line: line,
            superscript: superscript,
            subscriptText: subscriptText
        ) else { return nil }
        self = parsed
    }

    /// String-key parser for typed duration inputs.
    public init(
        parsingKeys keys: [String],
        duration: NoteDurationSpec = .quarter,
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) throws {
        self.init(
            keys: try StaffKeySpec.parseMany(keys),
            duration: duration,
            text: text,
            glyph: glyph,
            ignoreTicks: ignoreTicks,
            smooth: smooth,
            line: line,
            superscript: superscript,
            subscriptText: subscriptText
        )
    }

    /// Failable string-key parser for typed duration inputs.
    public init?(
        parsingKeysOrNil keys: [String],
        duration: NoteDurationSpec = .quarter,
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil
    ) {
        guard let parsed = try? TextNoteStruct(
            parsingKeys: keys,
            duration: duration,
            text: text,
            glyph: glyph,
            ignoreTicks: ignoreTicks,
            smooth: smooth,
            line: line,
            superscript: superscript,
            subscriptText: subscriptText
        ) else { return nil }
        self = parsed
    }
}

// MARK: - Text Note Glyph Info

private struct TextNoteGlyphInfo {
    let code: String
    let point: Double
    let xShift: Double
    let yShift: Double
}

// MARK: - Text Note

/// A note that renders text or a glyph at a specific tick position.
/// Used for dynamics, lyrics, and other text-based elements.
public final class TextNote: Note {

    override public class var category: String { "TextNote" }

    // MARK: - Glyph Definitions

    private static let GLYPHS: [String: TextNoteGlyphInfo] = [
        "segno": TextNoteGlyphInfo(code: "segno", point: 40, xShift: 0, yShift: 0),
        "tr": TextNoteGlyphInfo(code: "ornamentTrill", point: 40, xShift: 0, yShift: 0),
        "mordent": TextNoteGlyphInfo(code: "ornamentMordent", point: 40, xShift: 0, yShift: 0),
        "mordent_upper": TextNoteGlyphInfo(code: "ornamentShortTrill", point: 40, xShift: 0, yShift: 0),
        "mordent_lower": TextNoteGlyphInfo(code: "ornamentMordent", point: 40, xShift: 0, yShift: 0),
        "f": TextNoteGlyphInfo(code: "dynamicForte", point: 40, xShift: 0, yShift: 0),
        "p": TextNoteGlyphInfo(code: "dynamicPiano", point: 40, xShift: 0, yShift: 0),
        "m": TextNoteGlyphInfo(code: "dynamicMezzo", point: 40, xShift: 0, yShift: 0),
        "s": TextNoteGlyphInfo(code: "dynamicSforzando", point: 40, xShift: 0, yShift: 0),
        "z": TextNoteGlyphInfo(code: "dynamicZ", point: 40, xShift: 0, yShift: 0),
        "coda": TextNoteGlyphInfo(code: "coda", point: 40, xShift: 0, yShift: 0),
        "pedal_open": TextNoteGlyphInfo(code: "keyboardPedalPed", point: 40, xShift: 0, yShift: 0),
        "pedal_close": TextNoteGlyphInfo(code: "keyboardPedalUp", point: 40, xShift: 0, yShift: 0),
        "caesura_straight": TextNoteGlyphInfo(code: "caesura", point: 40, xShift: 0, yShift: 0),
        "caesura_curved": TextNoteGlyphInfo(code: "caesuraCurved", point: 40, xShift: 0, yShift: 0),
        "breath": TextNoteGlyphInfo(code: "breathMarkComma", point: 40, xShift: 0, yShift: 0),
        "tick": TextNoteGlyphInfo(code: "breathMarkTick", point: 40, xShift: 0, yShift: 0),
        "turn": TextNoteGlyphInfo(code: "ornamentTurn", point: 40, xShift: 0, yShift: 0),
        "turn_inverted": TextNoteGlyphInfo(code: "ornamentTurnSlash", point: 40, xShift: 0, yShift: 0),
    ]

    // MARK: - Properties

    public var text: String
    public var noteGlyph: Glyph?
    public var superscriptText: String?
    public var subscriptText: String?
    public var smooth: Bool
    public var justification: TextJustification = .left
    public var line: Double

    // MARK: - Init

    public init(_ noteStruct: TextNoteStruct) {
        self.text = noteStruct.text ?? ""
        self.superscriptText = noteStruct.superscript
        self.subscriptText = noteStruct.subscriptText
        self.smooth = noteStruct.smooth ?? false
        self.line = noteStruct.line ?? 0

        let ns = NoteStruct(
            keys: noteStruct.keys.map(\.rawValue),
            duration: noteStruct.duration
        )
        super.init(ns)

        if let ig = noteStruct.ignoreTicks {
            ignoreTicks = ig
        }

        // If a glyph is specified, create it
        if let glyphName = noteStruct.glyph,
           let glyphInfo = TextNote.GLYPHS[glyphName] {
            noteGlyph = Glyph(code: glyphInfo.code, point: glyphInfo.point)
        }
    }

    // MARK: - Justification

    @discardableResult
    public func setJustification(_ just: TextJustification) -> Self {
        justification = just
        return self
    }

    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    public func getLine() -> Double { line }

    public func getText() -> String { text }

    // MARK: - PreFormat

    override public func preFormat() {
        if preFormatted { return }

        if smooth {
            tickableWidth = 0
        } else if let glyph = noteGlyph {
            tickableWidth = glyph.getMetrics().width
        } else {
            let formatter = TextFormatter.create(
                font: fontInfo,
                context: getContext() ?? noteStave?.getContext()
            )
            tickableWidth = formatter.getWidthForTextInPx(text)
        }

        // Adjust displaced head offsets based on justification
        if justification == .center {
            leftDisplacedHeadPx = tickableWidth / 2
        } else if justification == .right {
            leftDisplacedHeadPx = tickableWidth
        }

        preFormatted = true
    }

    // MARK: - Draw

    override public func draw() throws {
        let stave = checkStave()
        let ctx = try checkContext()
        setRendered()

        // Calculate x position
        var x = getAbsoluteX()
        if justification == .center {
            x -= tickableWidth / 2
        } else if justification == .right {
            x -= tickableWidth
        }

        let y = stave.getYForLine(line + 0.5)  // Center on line

        if let glyph = noteGlyph {
            glyph.render(ctx: ctx, x: x, y: y)
        } else {
            applyStyle(context: ctx, style: getStyle())
            ctx.setFont(fontInfo)
            let formatter = TextFormatter.create(font: fontInfo, context: ctx)
            let textMeasure = formatter.measure(text)
            ctx.fillText(text, x, y)

            // Render superscript
            if let sup = superscriptText, !sup.isEmpty {
                ctx.fillText(sup, x + textMeasure.width + 2, y - textMeasure.height / 2.2)
            }

            // Render subscript
            if let sub = subscriptText, !sub.isEmpty {
                ctx.fillText(sub, x + textMeasure.width + 2, y + textMeasure.height / 2.2 - 1)
            }

            restoreStyle(context: ctx, style: getStyle())
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TextNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let stave = f.Stave(x: 10, y: 10, width: 500)
        _ = stave.addClef(.treble)

        let notes = score.notes("C5/q, D5, E5, F5")
        let voice = score.voice(notes)

        let textNotes: [Note] = [
            f.TextNote(TextNoteStruct(keys: [StaffKeySpec(letter: .c, octave: 5)], duration: .quarter, text: "do")),
            f.TextNote(TextNoteStruct(keys: [StaffKeySpec(letter: .d, octave: 5)], duration: .quarter, text: "re")),
            f.TextNote(TextNoteStruct(keys: [StaffKeySpec(letter: .e, octave: 5)], duration: .quarter, text: "mi")),
            f.TextNote(TextNoteStruct(keys: [StaffKeySpec(letter: .f, octave: 5)], duration: .quarter, text: "fa")),
        ]
        let textVoice = f.Voice(timeSignature: .meter(4, 4))
        _ = textVoice.addTickables(textNotes)
        for tn in textNotes { _ = (tn as! TextNote).setStave(stave) }

        let formatter = f.Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.joinVoices([textVoice])
        _ = formatter.format([voice, textVoice], justifyWidth: 400)

        try? f.draw()
    }
    .padding()
}
#endif
