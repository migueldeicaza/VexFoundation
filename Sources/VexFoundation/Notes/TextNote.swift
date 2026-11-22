// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/textnote.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - Text Justification

public enum TextJustification: Int, Sendable {
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
    /// Upstream `subscript` (a Swift keyword).
    public var subscriptText: String?
    public var font: FontInfo?

    public init(
        keys: [StaffKeySpec] = [StaffKeySpec(letter: .b, octave: 4)],
        duration: NoteDurationSpec = .quarter,
        text: String? = nil,
        glyph: String? = nil,
        ignoreTicks: Bool? = nil,
        smooth: Bool? = nil,
        line: Double? = nil,
        superscript: String? = nil,
        subscriptText: String? = nil,
        font: FontInfo? = nil
    ) {
        self.font = font
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

// MARK: - Text Note

/// `TextNote` is a notation element that is positioned in time. Generally
/// meant for objects that sit above/below the staff and inline with each other.
/// A `TextNote` must be assigned to a `Stave` with `setStave` before rendering.
/// Examples are dynamics, lyrics, chord changes, and so on.
public final class TextNote: Note {

    override public class var category: String { "TextNote" }

    public typealias Justification = TextJustification

    /// Glyph data.
    public static let GLYPHS: [String: String] = [
        "segno": Glyphs.segno,
        "tr": Glyphs.ornamentTrill,
        "mordent": Glyphs.ornamentMordent,
        "mordentUpper": Glyphs.ornamentShortTrill,
        "mordentLower": Glyphs.ornamentMordent,
        "f": Glyphs.dynamicForte,
        "p": Glyphs.dynamicPiano,
        "m": Glyphs.dynamicMezzo,
        "s": Glyphs.dynamicSforzando,
        "z": Glyphs.dynamicZ,
        "coda": Glyphs.coda,
        "pedalOpen": Glyphs.keyboardPedalPed,
        "pedalClose": Glyphs.keyboardPedalUp,
        "caesuraStraight": Glyphs.caesura,
        "caesuraCurved": Glyphs.caesuraCurved,
        "breath": Glyphs.breathMarkComma,
        "tick": Glyphs.breathMarkTick,
        "turn": Glyphs.ornamentTurn,
        "turnInverted": Glyphs.ornamentTurnSlash,
    ]

    // MARK: - Properties

    public var superscript: VexElement?
    public var `subscript`: VexElement?
    public var smooth: Bool
    public var justification: TextJustification
    public var line: Double

    // MARK: - Init

    public init(_ noteStruct: TextNoteStruct) {
        self.line = noteStruct.line ?? 0
        self.smooth = noteStruct.smooth ?? false
        self.justification = .left

        super.init(NoteStruct(
            keys: noteStruct.keys.map(\.rawValue),
            duration: noteStruct.duration,
            line: noteStruct.line
        ))

        text = noteStruct.text ?? ""
        if let glyph = noteStruct.glyph {
            text += TextNote.GLYPHS[glyph] ?? glyph
        }
        if let font = noteStruct.font {
            setFont(font)
        } else if noteStruct.glyph == nil {
            setFont(Metrics.getFontInfo("TextNote.text.fontSize"))
        }

        // Scale the font size by 1/1.3.
        let smallerFontSize = VexFont.convertSizeToPointValue(fontInfo.size) * 0.769231
        if let sup = noteStruct.superscript, !sup.isEmpty {
            let element = VexElement(category: "TexNote.subSuper")
            element.setText(sup)
            element.setFontSize(smallerFontSize)
            superscript = element
        }
        if let sub = noteStruct.subscriptText, !sub.isEmpty {
            let element = VexElement(category: "TexNote.subSuper")
            element.setText(sub)
            element.setFontSize(smallerFontSize)
            `subscript` = element
        }

        ignoreTicks = noteStruct.ignoreTicks ?? false
    }

    // MARK: - Justification

    /// Set the horizontal justification of the TextNote.
    @discardableResult
    public func setJustification(_ just: TextJustification) -> Self {
        justification = just
        return self
    }

    /// Set the stave line of the note.
    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    /// The stave line of the TextNote.
    public func getLine() -> Double { line }

    // MARK: - PreFormat

    /// Pre-render formatting.
    override public func preFormat() {
        if preFormatted { return }
        let tickContext = checkTickContext("Can't preformat without a TickContext.")

        if justification == .center {
            leftDisplacedHeadPx = width / 2
        } else if justification == .right {
            leftDisplacedHeadPx = width
        }

        // We reposition to the center of the note head
        rightDisplacedHeadPx = tickContext.getMetrics().glyphPx / 2
        preFormatted = true
    }

    // MARK: - Draw

    /// Render the TextNote. It must have a stave (`setStave`).
    override public func draw() throws {
        let ctx = try checkContext()
        let stave = checkStave()
        let tickContext = checkTickContext("Can't draw without a TickContext.")

        setRendered()

        // Reposition to center of note head
        var x = getAbsoluteX() + tickContext.getMetrics().glyphPx / 2

        // Align based on tick-context width.
        let width = getWidth()

        if justification == .center {
            x -= width / 2
        } else if justification == .right {
            x -= width
        }

        let y = stave.getYForLine(line + -3)
        renderText(ctx, xPos: x, yPos: y)

        let height = getHeight()

        if let superscript {
            superscript.renderText(ctx, xPos: x + self.width + 2, yPos: y - height / 2.2)
        }

        if let sub = `subscript` {
            sub.renderText(ctx, xPos: x + self.width + 2, yPos: y + height / 2.2 - 1)
        }
    }
}
