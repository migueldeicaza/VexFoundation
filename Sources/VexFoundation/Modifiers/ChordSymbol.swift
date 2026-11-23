// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Aaron (@AaronDavidNewman)
//
// Port of `src/chordsymbol.ts` (VexFlow 5.7.0).
//
// This implements chord symbols above/below a chord.
// Chord symbols are modifiers that can be attached to notes.
// They can contain multiple 'blocks' which represent text or
// glyphs with various positioning options.

import Foundation

// MARK: - Enums

public enum ChordSymbolHorizontalJustify: Int, Sendable {
    case left = 1
    case center = 2
    case right = 3
    case centerStem = 4
}

public enum ChordSymbolVerticalJustify: Int, Sendable {
    case top = 1
    case bottom = 2
}

/// Upstream `SymbolModifiers`.
public enum SymbolModifier: Int, Sendable {
    case none = 1
    /// Subscript.
    case sub = 2
    /// Superscript.
    case sup = 3
}

/// Upstream name of `SymbolModifier`.
public typealias SymbolModifiers = SymbolModifier

/// VexFlow 4 block type. VexFlow 5 blocks are all text (glyphs are SMuFL text).
@available(*, deprecated, message: "VexFlow 5 chord symbol blocks are text. Use addText/addGlyph/addLine.")
public enum SymbolType: Int, Sendable {
    case glyph = 1
    case text = 2
    case line = 3
}

// MARK: - ChordSymbolBlock

/// One block of a chord symbol: text (glyphs are SMuFL text) with a symbol modifier.
public final class ChordSymbolBlock: VexElement {
    public var symbolModifier: SymbolModifier
    public var vAlign: Bool

    public init(_ text: String, symbolModifier: SymbolModifier, xShift: Double, yShift: Double, vAlign: Bool) {
        self.symbolModifier = symbolModifier
        self.vAlign = vAlign
        super.init(category: nil)
        self.text = text
        self.xShift = xShift
        self.yShift = yShift
    }

    public func isSuperscript() -> Bool {
        symbolModifier == .sup
    }

    public func isSubscript() -> Bool {
        symbolModifier == .sub
    }
}

// MARK: - ChordSymbol

/// Chord-symbol kerning mode (VexFlow 5.2.0). `.none` keeps the legacy block layout.
public enum ChordSymbolKerning: String, Sendable {
    case auto
    case none
}

/// ChordSymbol is a modifier that creates a chord symbol above/below a chord.
/// As a modifier, it is attached to an existing note.
public final class ChordSymbol: Modifier {

    override public class var category: String { "ChordSymbol" }

    // Chord symbols can be positioned and justified relative to the note.
    public static let horizontalJustifyString: [String: ChordSymbolHorizontalJustify] = [
        "left": .left,
        "right": .right,
        "center": .center,
        "centerStem": .centerStem,
    ]

    public static let verticalJustifyString: [String: ChordSymbolVerticalJustify] = [
        "top": .top,
        "above": .top,
        "below": .bottom,
        "bottom": .bottom,
    ]

    public static var superSubRatio: Double {
        Metrics.getDouble("ChordSymbol.superSubRatio")
    }

    public static var spacingBetweenBlocks: Double {
        Metrics.getDouble("ChordSymbol.spacing")
    }

    public static var superscriptOffset: Double {
        Metrics.getDouble("ChordSymbol.superscriptOffset")
    }

    public static var subscriptOffset: Double {
        Metrics.getDouble("ChordSymbol.subscriptOffset")
    }

    /// Glyph data.
    public static let glyphs: [String: String] = [
        "diminished": Glyphs.csymDiminished,
        "dim": Glyphs.csymDiminished,
        "halfDiminished": Glyphs.csymHalfDiminished,
        "+": Glyphs.csymAugmented,
        "augmented": Glyphs.csymAugmented,
        "majorSeventh": Glyphs.csymMajorSeventh,
        "minor": Glyphs.csymMinor,
        "-": Glyphs.csymMinor,
        "(": "(", // Glyphs.csymParensLeftTall
        "leftParen": "(", // Glyphs.csymParensLeftTall
        ")": ")", // Glyphs.csymParensRightTall
        "rightParen": ")", // Glyphs.csymParensRightTall
        "leftBracket": Glyphs.csymBracketLeftTall,
        "rightBracket": Glyphs.csymBracketRightTall,
        "leftParenTall": "(", // Glyphs.csymParensLeftVeryTall
        "rightParenTall": ")", // Glyphs.csymParensRightVeryTall
        "/": Glyphs.csymDiagonalArrangementSlash,
        "over": Glyphs.csymDiagonalArrangementSlash,
        "#": Glyphs.csymAccidentalSharp,
        "b": Glyphs.csymAccidentalFlat,
    ]

    public static var minPadding: Double {
        Metrics.getDouble("NoteHead.minPadding")
    }

    // MARK: - Static Format

    /// Estimate the width of the whole chord symbol, based on the sum of the widths of the individual blocks.
    /// Estimate how many lines above/below the staff we need.
    @discardableResult
    public static func format(
        _ symbols: [ChordSymbol],
        state: inout ModifierContextState
    ) -> Bool {
        if symbols.isEmpty { return false }

        var width: Double = 0
        var leftWidth: Double = 0
        var rightWidth: Double = 0
        var maxLeftGlyphWidth: Double = 0
        var maxRightGlyphWidth: Double = 0

        for symbol in symbols {
            let note = symbol.checkAttachedNote()
            var lineSpaces: Double = 1

            if let kernedWidth = symbol.formatKerning() {
                width = kernedWidth
                if symbol.symbolBlocks.contains(where: { $0.isSuperscript() || $0.isSubscript() }) { lineSpaces = 2 }
            } else {
                for j in 0..<symbol.symbolBlocks.count {
                    let block = symbol.symbolBlocks[j]
                    let sup = block.isSuperscript()
                    let sub = block.isSubscript()
                    block.setXShift(width)

                    // If there are super/subscripts, they extend beyond the line so
                    // assume they take up 2 lines
                    if sup || sub {
                        lineSpaces = 2
                    }

                    // If a subscript immediately follows a superscript block, try to
                    // overlay them.
                    if sub && j > 0 {
                        let prev = symbol.symbolBlocks[j - 1]
                        if prev.isSuperscript() {
                            // slide the symbol over so it lines up with superscript
                            block.setXShift(width - prev.getWidth() - ChordSymbol.minPadding)
                            block.vAlign = true
                            width += -prev.getWidth()
                                - ChordSymbol.minPadding
                                + (prev.getWidth() > block.getWidth() ? prev.getWidth() - block.getWidth() : 0)
                        }
                    }
                    width += block.getWidth() + ChordSymbol.minPadding
                }
            }

            if symbol.getVertical() == .top {
                _ = symbol.setTextLine(state.topTextLine)
                state.topTextLine += lineSpaces
            } else {
                _ = symbol.setTextLine(state.textLine + 1)
                state.textLine += lineSpaces + 1
            }
            if symbol.getReportWidth() {
                if note is StemmableNote {
                    let glyphWidth = note.getGlyphWidth()
                    if symbol.getHorizontal() == .right {
                        maxLeftGlyphWidth = max(glyphWidth, maxLeftGlyphWidth)
                        leftWidth = max(leftWidth, width) + ChordSymbol.minPadding
                    } else if symbol.getHorizontal() == .left {
                        maxRightGlyphWidth = max(glyphWidth, maxRightGlyphWidth)
                        rightWidth = max(rightWidth, width)
                    } else {
                        leftWidth = max(leftWidth, width / 2) + ChordSymbol.minPadding
                        rightWidth = max(rightWidth, width / 2)
                        maxLeftGlyphWidth = max(glyphWidth / 2, maxLeftGlyphWidth)
                        maxRightGlyphWidth = max(glyphWidth / 2, maxRightGlyphWidth)
                    }
                }
            }
            // Opt-in runs need their width for alignment even when they reserve no stave space.
            if symbol.getReportWidth() || symbol.kernedRuns != nil { symbol.width = width }
            width = 0 // reset symbol width
        }
        let rightOverlap = min(
            max(rightWidth - maxRightGlyphWidth, 0),
            max(rightWidth - state.rightShift, 0)
        )
        let leftOverlap = min(
            max(leftWidth - maxLeftGlyphWidth, 0),
            max(leftWidth - state.leftShift, 0)
        )

        state.leftShift += leftOverlap
        state.rightShift += rightOverlap
        return true
    }

    // MARK: - Properties

    public var symbolBlocks: [ChordSymbolBlock] = []
    public var horizontal: ChordSymbolHorizontalJustify = .left
    public var vertical: ChordSymbolVerticalJustify = .top
    public var reportWidth: Bool = true

    // MARK: - Kerning (VexFlow 5.2.0)

    /// Default rendering stays compatible; only a matching opt-in profile uses shaped runs.
    public private(set) var kerning: ChordSymbolKerning = .none
    public private(set) var kerningProfile: ChordSymbolKerningProfile?
    /// The positioned runs of the last format pass, or `nil` for the legacy block layout.
    public private(set) var kernedRuns: [ChordSymbolRun]?
    private var kerningMeasurement: VexElement?
    private var kerningOrigin: (x: Double, y: Double) = (0, 0)

    /// Select optical kerning. Format the score again after changing layout settings.
    @discardableResult
    public func setKerning(_ mode: ChordSymbolKerning) -> Self {
        kerning = mode
        kernedRuns = nil
        return self
    }

    public func getKerning() -> ChordSymbolKerning { kerning }

    /// Replace the font-specific table for this chord only. Pass `nil` to restore the built-in profiles.
    @discardableResult
    public func setKerningProfile(_ profile: ChordSymbolKerningProfile?) throws -> Self {
        if let profile {
            let invalid = profile.textFont.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || profile.musicFont.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || profile.pairs.contains { pair in
                    pair.left.unicodeScalars.count != 1 || pair.right.unicodeScalars.count != 1
                        || !pair.adjustmentEm.isFinite
                }
            if invalid { throw VexError("BadArgument", "Invalid chord kerning profile.") }
        }
        kerningProfile = profile
        kernedRuns = nil
        return self
    }

    /// Re-measure on every format pass; the shared text cache handles reuse.
    func formatKerning() -> Double? {
        kernedRuns = nil
        if kerning == .none { return nil }
        guard let profile = chordKerningProfile(fontInfo, custom: kerningProfile) else { return nil }
        let measurement = kerningMeasurement ?? VexElement()
        kerningMeasurement = measurement
        let layout = layoutChordRuns(
            symbolBlocks.map { block in
                ChordSymbolText(
                    text: block.getText(),
                    position: block.isSuperscript() ? .superscript : block.isSubscript() ? .subscript : .baseline
                )
            },
            font: fontInfo,
            profile: profile,
            options: ChordSymbolRunOptions(
                spacing: ChordSymbol.spacingBetweenBlocks,
                ratio: ChordSymbol.superSubRatio,
                superscript: ChordSymbol.superscriptOffset,
                subscript: ChordSymbol.subscriptOffset
            ),
            measure: { text, font in
                measurement.setText(text)
                measurement.setFont(font)
                return measurement.measureText()
            }
        )
        kernedRuns = layout.runs
        return layout.width
    }

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - Offsets

    /// The offset is specified in `em`. Scale this value by the font size in pixels.
    public var superscriptOffset: Double {
        ChordSymbol.superscriptOffset * VexFont.convertSizeToPixelValue(fontInfo.size)
    }

    public var subscriptOffset: Double {
        ChordSymbol.subscriptOffset * VexFont.convertSizeToPixelValue(fontInfo.size)
    }

    @available(*, deprecated, renamed: "superscriptOffset")
    public var superscriptOffsetValue: Double { superscriptOffset }

    @available(*, deprecated, renamed: "subscriptOffset")
    public var subscriptOffsetValue: Double { subscriptOffset }

    // MARK: - Report Width

    @discardableResult
    public func setReportWidth(_ value: Bool) -> Self {
        reportWidth = value
        return self
    }

    public func getReportWidth() -> Bool { reportWidth }

    // MARK: - Symbol Blocks

    /// ChordSymbol allows multiple blocks so we can mix glyphs and font text.
    /// Each block can have its own vertical orientation.
    public func getSymbolBlock(text: String? = nil, symbolModifier: SymbolModifier? = nil) -> ChordSymbolBlock {
        let symbolBlock = ChordSymbolBlock(
            text ?? "",
            symbolModifier: symbolModifier ?? .none,
            xShift: 0,
            yShift: 0,
            vAlign: false
        )

        if symbolBlock.isSubscript() {
            symbolBlock.setYShift(subscriptOffset)
        }
        if symbolBlock.isSuperscript() {
            symbolBlock.setYShift(superscriptOffset)
        }
        if symbolBlock.isSubscript() || symbolBlock.isSuperscript() {
            let font = fontInfo
            let smallerFontSize = VexFont.scaleSize(font.size, ChordSymbol.superSubRatio)
            symbolBlock.setFont(family: font.family, size: smallerFontSize, weight: font.weight, style: font.style)
        } else {
            symbolBlock.setFont(fontInfo)
        }

        return symbolBlock
    }

    /// Add a symbol to this chord, could be text, glyph or line.
    @discardableResult
    public func addSymbolBlock(text: String? = nil, symbolModifier: SymbolModifier? = nil) -> Self {
        symbolBlocks.append(getSymbolBlock(text: text, symbolModifier: symbolModifier))
        return self
    }

    /// VexFlow 4 form. `.glyph` looks up `glyphName` in `ChordSymbol.glyphs`;
    /// `.line` adds a line (the width is ignored).
    @available(*, deprecated, message: "Use addText/addGlyph/addLine.")
    @discardableResult
    public func addSymbolBlock(
        text: String = "",
        symbolType: SymbolType,
        symbolModifier: SymbolModifier = .none,
        glyphName: String? = nil,
        width: Double? = nil
    ) -> Self {
        switch symbolType {
        case .glyph:
            return addText(glyphName.flatMap { ChordSymbol.glyphs[$0] } ?? "", symbolModifier: symbolModifier)
        case .line:
            return addLine(symbolModifier: symbolModifier)
        case .text:
            return addText(text, symbolModifier: symbolModifier)
        }
    }

    // MARK: - Convenience Add Methods

    /// Add a text block.
    @discardableResult
    public func addText(_ text: String, symbolModifier: SymbolModifier? = nil) -> Self {
        addSymbolBlock(text: text, symbolModifier: symbolModifier)
    }

    /// Add a text block with superscript modifier.
    @discardableResult
    public func addTextSuperscript(_ text: String) -> Self {
        addSymbolBlock(text: text, symbolModifier: .sup)
    }

    /// Add a text block with subscript modifier.
    @discardableResult
    public func addTextSubscript(_ text: String) -> Self {
        addSymbolBlock(text: text, symbolModifier: .sub)
    }

    /// Add a glyph block with superscript modifier.
    @discardableResult
    public func addGlyphSuperscript(_ glyph: String) -> Self {
        addTextSuperscript(ChordSymbol.glyphs[glyph] ?? "")
    }

    /// Add a glyph block.
    @discardableResult
    public func addGlyph(_ glyph: String, symbolModifier: SymbolModifier? = nil) -> Self {
        addText(ChordSymbol.glyphs[glyph] ?? "", symbolModifier: symbolModifier)
    }

    /// Add a glyph for each character in 'text'. If the glyph is not available, use text from the font.
    /// e.g. `addGlyphOrText("(+5#11)")` will use text for the '5' and '11', and glyphs for everything else.
    @discardableResult
    public func addGlyphOrText(_ text: String, symbolModifier: SymbolModifier? = nil) -> Self {
        var str = ""
        for char in text {
            let s = String(char)
            if let glyph = ChordSymbol.glyphs[s] {
                str += glyph
            } else {
                // Collect consecutive characters with no glyphs.
                str += s
            }
        }
        if !str.isEmpty {
            addText(str, symbolModifier: symbolModifier)
        }
        return self
    }

    /// Add a line of the given width, used as a continuation of the previous symbol in analysis, or lyrics, etc.
    @discardableResult
    public func addLine(symbolModifier: SymbolModifier? = nil) -> Self {
        // Two csymMinor glyphs next to each other.
        addText("\u{E874}\u{E874}" /* {csymMinor}{csymMinor} */, symbolModifier: symbolModifier)
    }

    @available(*, deprecated, message: "VexFlow 5 lines have a fixed width. Use addLine().")
    @discardableResult
    public func addLine(_ width: Double) -> Self {
        addLine()
    }

    // MARK: - Justification

    /// Set vertical position of text (above or below stave).
    @discardableResult
    public func setVertical(_ vj: ChordSymbolVerticalJustify) -> Self {
        vertical = vj
        return self
    }

    /// Set vertical position from a string (`top`, `above`, `below`, `bottom`).
    /// Unknown strings leave the position unchanged.
    @discardableResult
    public func setVertical(_ vj: String) -> Self {
        if let value = ChordSymbol.verticalJustifyString[vj] {
            vertical = value
        }
        return self
    }

    public func getVertical() -> ChordSymbolVerticalJustify { vertical }

    /// Set horizontal justification.
    @discardableResult
    public func setHorizontal(_ hj: ChordSymbolHorizontalJustify) -> Self {
        horizontal = hj
        return self
    }

    /// Set horizontal justification from a string (`left`, `right`, `center`, `centerStem`).
    /// Unknown strings leave the justification unchanged.
    @discardableResult
    public func setHorizontal(_ hj: String) -> Self {
        if let value = ChordSymbol.horizontalJustifyString[hj] {
            horizontal = value
        }
        return self
    }

    public func getHorizontal() -> ChordSymbolHorizontalJustify { horizontal }

    // MARK: - Horizontal ink (VexFlow 5.7.0)

    /// Use the same note anchor for drawing and for spacing chords before a draw.
    private func originX(_ note: Note) -> Double {
        let start = note.getModifierStartXY(position: .above, index: index ?? 0)
        switch horizontal {
        case .left:
            return start.x
        case .right:
            return kernedRuns != nil ? start.x - getWidth() : start.x + getWidth()
        case .center:
            return start.x - getWidth() / 2
        case .centerStem:
            return ((note as? StemmableNote)?.getStemX() ?? start.x) - getWidth() / 2
        }
    }

    /// Horizontal ink of the formatted symbol at its current attachment, including italic overhangs.
    public func getHorizontalInk() throws -> (left: Double, right: Double) {
        let x = originX(try checkAttachedNoteThrowing())
        let parts: [(offset: Double, metrics: TextMetrics)] = kernedRuns.map { runs in
            runs.map { (offset: $0.x, metrics: $0.metrics) }
        } ?? symbolBlocks.map { (offset: $0.getXShift(), metrics: $0.textMetrics) }
        var left = Double.infinity
        var right = -Double.infinity
        for part in parts {
            let m = part.metrics
            if m.actualBoundingBoxLeft + m.actualBoundingBoxRight <= 0 { continue }
            left = min(left, x + part.offset - m.actualBoundingBoxLeft)
            right = max(right, x + part.offset + m.actualBoundingBoxRight)
        }
        return right > left ? (left, right) : (x, x)
    }

    // MARK: - Draw

    /// Render text and glyphs above/below the note.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        _ = ctx.openGroup(groupClass("chordsymbol"), getAttribute("id"))

        ctx.setFont(fontInfo)

        var y: Double

        // The position of the text varies based on whether or not the note
        // has a stem.
        let hasStem = note.hasStem()
        let stave = try note.checkStaveThrowing()

        if vertical == .bottom {
            // HACK: We need to compensate for the text's height since its origin is bottom-right.
            y = stave.getYForBottomText(textLine + Tables.TEXT_HEIGHT_OFFSET_HACK)
            if hasStem, let stemmable = note as? StemmableNote {
                let stemExt = try stemmable.checkStemThrowing().getExtents()
                let spacing = stave.getSpacingBetweenLines()
                let stemBase = note.getStemDirection() == Stem.UP ? stemExt.baseY : stemExt.topY
                y = max(y, stemBase + spacing * (textLine + 2))
            }
        } else {
            // (vertical == .top)
            let topY = note.getYs().min() ?? 0
            y = min(stave.getYForTopText(textLine), topY - 10)
            if hasStem, let stemmable = note as? StemmableNote {
                let stemExt = try stemmable.checkStemThrowing().getExtents()
                let spacing = stave.getSpacingBetweenLines()
                y = min(y, stemExt.topY - 5 - spacing * textLine)
            }
        }

        let x = originX(note)

        if let kernedRuns {
            kerningOrigin = (x, y)
            for run in kernedRuns {
                ctx.setFont(run.font)
                ctx.fillText(run.text, x + run.x, y + run.y)
            }
        } else {
            for symbol in symbolBlocks {
                symbol.setX(x)
                symbol.setY(y)
                symbol.renderText(ctx, xPos: 0, yPos: 0)
            }
        }
        drawPointerRect()
        ctx.closeGroup()
    }

    // MARK: - Bounding Box

    /// Return fresh ink bounds, including script offsets and overhangs. Empty symbols have empty bounds.
    override public func getBoundingBox() -> BoundingBox? {
        if let kernedRuns {
            let (x, y) = kerningOrigin
            var box: BoundingBox?
            for run in kernedRuns {
                let m = run.metrics
                let ink = BoundingBox(
                    x: x + run.x - m.actualBoundingBoxLeft,
                    y: y + run.y - m.actualBoundingBoxAscent,
                    w: m.actualBoundingBoxLeft + m.actualBoundingBoxRight,
                    h: m.actualBoundingBoxAscent + m.actualBoundingBoxDescent
                )
                if box != nil { box?.mergeWith(ink) } else { box = ink }
            }
            return box ?? BoundingBox(x: x, y: y, w: 0, h: 0)
        }
        guard var boundingBox = symbolBlocks.first?.getBoundingBox() else { return BoundingBox(x: 0, y: 0, w: 0, h: 0) }
        for block in symbolBlocks.dropFirst() {
            if let bb = block.getBoundingBox() {
                boundingBox.mergeWith(bb)
            }
        }
        return boundingBox
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("ChordSymbol", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 170))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")

        let cs1 = f.ChordSymbol(vJustify: .top, hJustify: .left)
        _ = cs1.addGlyphOrText("Cmaj7")
        _ = notes[0].addModifier(cs1, index: 0)

        let cs2 = f.ChordSymbol(vJustify: .top, hJustify: .left)
        _ = cs2.addGlyphOrText("Dm")
        _ = notes[1].addModifier(cs2, index: 0)

        let cs3 = f.ChordSymbol(vJustify: .top, hJustify: .left)
        _ = cs3.addGlyphOrText("G7")
        _ = notes[2].addModifier(cs3, index: 0)

        let cs4 = f.ChordSymbol(vJustify: .top, hJustify: .left)
        _ = cs4.addGlyphOrText("F")
        _ = notes[3].addModifier(cs4, index: 0)

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
