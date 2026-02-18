// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Aaron (@AaronDavidNewman). MIT License.

import Foundation

// MARK: - Chord Symbol Types

public struct ChordSymbolBlock {
    public var text: String
    public var symbolType: SymbolType
    public var symbolModifier: SymbolModifier
    public var xShift: Double
    public var yShift: Double
    public var vAlign: Bool
    public var width: Double
    public var glyph: Glyph?
}

public struct ChordSymbolGlyphMetrics {
    public var leftSideBearing: Double
    public var advanceWidth: Double
    public var yOffset: Double
}

public enum ChordSymbolHorizontalJustify: Int {
    case left = 1
    case center = 2
    case right = 3
    case centerStem = 4
}

public enum ChordSymbolVerticalJustify: Int {
    case top = 1
    case bottom = 2
}

public enum SymbolType: Int {
    case glyph = 1
    case text = 2
    case line = 3
}

public enum SymbolModifier: Int {
    case none = 1
    case sub = 2
    case sup = 3
}

// MARK: - ChordSymbol

/// Renders chord symbols (e.g. Cmaj7, Dm, G7) above or below notes.
/// Supports mixed text and glyph blocks with super/subscript positioning.
public final class ChordSymbol: Modifier {

    override public class var category: String { "ChordSymbol" }

    // MARK: - Static Glyph Data

    public static let glyphs: [String: String] = [
        "diminished": "csymDiminished",
        "dim": "csymDiminished",
        "halfDiminished": "csymHalfDiminished",
        "+": "csymAugmented",
        "augmented": "csymAugmented",
        "majorSeventh": "csymMajorSeventh",
        "minor": "csymMinor",
        "-": "csymMinor",
        "(": "csymParensLeftTall",
        "leftParen": "csymParensLeftTall",
        ")": "csymParensRightTall",
        "rightParen": "csymParensRightTall",
        "leftBracket": "csymBracketLeftTall",
        "rightBracket": "csymBracketRightTall",
        "leftParenTall": "csymParensLeftVeryTall",
        "rightParenTall": "csymParensRightVeryTall",
        "/": "csymDiagonalArrangementSlash",
        "over": "csymDiagonalArrangementSlash",
        "#": "accidentalSharp",
        "b": "accidentalFlat",
    ]

    // MARK: - Static Metrics

    nonisolated(unsafe) private static var cachedMetrics: [String: Any]?

    private static func getMetricsGlobal() -> [String: Any] {
        if let cached = cachedMetrics { return cached }
        guard let font = Glyph.MUSIC_FONT_STACK.first,
              let csGlobal = font.lookupMetric("chordSymbol.global") as? [String: Any] else {
            return [:]
        }
        cachedMetrics = csGlobal
        return csGlobal
    }

    public static var superSubRatio: Double {
        getMetricsGlobal()["superSubRatio"] as? Double ?? 0.66
    }

    public static var engravingFontResolution: Double {
        guard let font = Glyph.MUSIC_FONT_STACK.first else { return 1000 }
        return (try? font.getResolution()) ?? 1000
    }

    public static var spacingBetweenBlocks: Double {
        let spacing = getMetricsGlobal()["spacing"] as? Double ?? 100
        return spacing / engravingFontResolution
    }

    public static func getMetricForGlyph(_ glyphCode: String) -> ChordSymbolGlyphMetrics? {
        guard let font = Glyph.MUSIC_FONT_STACK.first,
              let glyphMetrics = font.lookupMetric("chordSymbol.glyphs.\(glyphCode)") as? [String: Any] else {
            return nil
        }
        return ChordSymbolGlyphMetrics(
            leftSideBearing: glyphMetrics["leftSideBearing"] as? Double ?? 0,
            advanceWidth: glyphMetrics["advanceWidth"] as? Double ?? 0,
            yOffset: glyphMetrics["yOffset"] as? Double ?? 0
        )
    }

    public static func getWidthForGlyph(_ glyph: Glyph) -> Double {
        guard let metric = getMetricForGlyph(glyph.code) else { return 0.65 }
        return metric.advanceWidth / engravingFontResolution
    }

    public static func getYShiftForGlyph(_ glyph: Glyph) -> Double {
        guard let metric = getMetricForGlyph(glyph.code) else { return 0 }
        return metric.yOffset / engravingFontResolution
    }

    public static func getXShiftForGlyph(_ glyph: Glyph) -> Double {
        guard let metric = getMetricForGlyph(glyph.code) else { return 0 }
        return -1 * metric.leftSideBearing / engravingFontResolution
    }

    public static var superscriptOffset: Double {
        let offset = getMetricsGlobal()["superscriptOffset"] as? Double ?? -400
        return offset / engravingFontResolution
    }

    public static var subscriptOffset: Double {
        let offset = getMetricsGlobal()["subscriptOffset"] as? Double ?? 300
        return offset / engravingFontResolution
    }

    public static var kerningOffset: Double {
        let offset = getMetricsGlobal()["kerningOffset"] as? Double ?? -250
        return offset / engravingFontResolution
    }

    public static var lowerKerningText: [String] {
        getMetricsGlobal()["lowerKerningText"] as? [String] ?? []
    }

    public static var upperKerningText: [String] {
        getMetricsGlobal()["upperKerningText"] as? [String] ?? []
    }

    public static var minPadding: Double {
        guard let font = Glyph.MUSIC_FONT_STACK.first else { return 2 }
        return font.lookupMetric("noteHead.minPadding") as? Double ?? 2
    }

    public static func isSuperscript(_ block: ChordSymbolBlock) -> Bool {
        block.symbolModifier == .sup
    }

    public static func isSubscript(_ block: ChordSymbolBlock) -> Bool {
        block.symbolModifier == .sub
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ symbols: [ChordSymbol],
        state: inout ModifierContextState
    ) -> Bool {
        if symbols.isEmpty { return false }

        var width: Double = 0
        var nonSuperWidth: Double = 0
        var leftWidth: Double = 0
        var rightWidth: Double = 0
        var maxLeftGlyphWidth: Double = 0
        var maxRightGlyphWidth: Double = 0

        for symbol in symbols {
            let fontSize = symbol.fontSizeInPixels
            let fontAdj = fontSize * 0.05
            let glyphAdj = fontAdj * 2
            let note = symbol.checkAttachedNote()
            var symbolWidth: Double = 0
            var lineSpaces: Double = 1
            var vAlign = false

            for j in 0..<symbol.symbolBlocks.count {
                var block = symbol.symbolBlocks[j]
                let sup = ChordSymbol.isSuperscript(block)
                let sub = ChordSymbol.isSubscript(block)
                let superSubScale = (sup || sub) ? ChordSymbol.superSubRatio : 1
                let adj = block.symbolType == .glyph
                    ? glyphAdj * superSubScale : fontAdj * superSubScale

                if sup || sub {
                    lineSpaces = 2
                }

                let superSubFontSize = fontSize * superSubScale
                if block.symbolType == .glyph, let glyph = block.glyph {
                    block.width = ChordSymbol.getWidthForGlyph(glyph) * superSubFontSize
                    block.yShift += ChordSymbol.getYShiftForGlyph(glyph) * superSubFontSize
                    block.xShift += ChordSymbol.getXShiftForGlyph(glyph) * superSubFontSize
                    glyph.glyphScale = glyph.glyphScale * adj
                } else if block.symbolType == .text {
                    block.width = block.width * superSubFontSize
                    block.yShift += symbol.getYOffsetForText(block.text) * adj
                }

                if block.symbolType == .glyph,
                   let glyph = block.glyph,
                   glyph.code == ChordSymbol.glyphs["over"] {
                    lineSpaces = 2
                }
                block.width += ChordSymbol.spacingBetweenBlocks * fontSize * superSubScale

                if sup && j > 0 {
                    let prev = symbol.symbolBlocks[j - 1]
                    if !ChordSymbol.isSuperscript(prev) {
                        nonSuperWidth = width
                    }
                }
                if sub && nonSuperWidth > 0 {
                    vAlign = true
                    block.xShift = block.xShift + (nonSuperWidth - width)
                    width = nonSuperWidth
                    nonSuperWidth = 0
                    symbol.setEnableKerning(false)
                }
                if !sup && !sub {
                    nonSuperWidth = 0
                }
                block.vAlign = vAlign
                symbol.symbolBlocks[j] = block
                width += block.width
                symbolWidth = width
            }

            symbol.updateKerningAdjustments()
            symbol.updateOverBarAdjustments()

            if symbol.vertical == .top {
                symbol.setTextLine(state.topTextLine)
                state.topTextLine += lineSpaces
            } else {
                symbol.setTextLine(state.textLine + 1)
                state.textLine += lineSpaces + 1
            }

            if symbol.reportWidth, let stemmable = note as? StemmableNote {
                let glyphWidth = stemmable.getGlyphWidth()
                if symbol.horizontal == .left {
                    maxLeftGlyphWidth = max(glyphWidth, maxLeftGlyphWidth)
                    leftWidth = max(leftWidth, symbolWidth) + ChordSymbol.minPadding
                } else if symbol.horizontal == .right {
                    maxRightGlyphWidth = max(glyphWidth, maxRightGlyphWidth)
                    rightWidth = max(rightWidth, symbolWidth)
                } else {
                    leftWidth = max(leftWidth, symbolWidth / 2) + ChordSymbol.minPadding
                    rightWidth = max(rightWidth, symbolWidth / 2)
                    maxLeftGlyphWidth = max(glyphWidth / 2, maxLeftGlyphWidth)
                    maxRightGlyphWidth = max(glyphWidth / 2, maxRightGlyphWidth)
                }
            }
            width = 0
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
    public var useKerning: Bool = true
    public var reportWidth: Bool = true

    // MARK: - Init

    public override init() {
        super.init()
    }

    // MARK: - Accessors

    public var superscriptOffsetValue: Double {
        ChordSymbol.superscriptOffset * fontSizeInPixels
    }

    public var subscriptOffsetValue: Double {
        ChordSymbol.subscriptOffset * fontSizeInPixels
    }

    @discardableResult
    public func setReportWidth(_ value: Bool) -> Self {
        reportWidth = value
        return self
    }

    public func getReportWidth() -> Bool { reportWidth }

    @discardableResult
    public func setEnableKerning(_ val: Bool) -> Self {
        useKerning = val
        return self
    }

    @discardableResult
    public func setVertical(_ vj: ChordSymbolVerticalJustify) -> Self {
        vertical = vj
        return self
    }

    public func getVertical() -> ChordSymbolVerticalJustify { vertical }

    @discardableResult
    public func setHorizontal(_ hj: ChordSymbolHorizontalJustify) -> Self {
        horizontal = hj
        return self
    }

    public func getHorizontal() -> ChordSymbolHorizontalJustify { horizontal }

    override public func getWidth() -> Double {
        var w: Double = 0
        for symbol in symbolBlocks {
            w += symbol.vAlign ? 0 : symbol.width
        }
        return w
    }

    // MARK: - Text Measurement

    public func getYOffsetForText(_ text: String) -> Double {
        // Simplified: approximate y offset based on text content
        // The TS version uses TextFormatter to get per-glyph y_max metrics
        0
    }

    /// Approximate width for text in em units (simplified from TextFormatter).
    private func getWidthForTextInEm(_ text: String) -> Double {
        // Approximate: each character ~0.6 em
        Double(text.count) * 0.6
    }

    // MARK: - Over Bar Adjustments

    public func updateOverBarAdjustments() {
        let barIndex = symbolBlocks.firstIndex {
            $0.symbolType == .glyph && $0.glyph?.code == "csymDiagonalArrangementSlash"
        }

        guard let barIndex else { return }
        let bar = symbolBlocks[barIndex]
        let xoff = bar.width / 4
        let yoff = 0.25 * fontSizeInPixels

        for i in 0..<barIndex {
            symbolBlocks[i].xShift += xoff
            symbolBlocks[i].yShift -= yoff
        }
        for i in (barIndex + 1)..<symbolBlocks.count {
            symbolBlocks[i].xShift -= xoff
            symbolBlocks[i].yShift += yoff
        }
    }

    // MARK: - Kerning

    public func updateKerningAdjustments() {
        var accum: Double = 0
        for j in 0..<symbolBlocks.count {
            accum += getKerningAdjustment(j)
            symbolBlocks[j].xShift += accum
        }
    }

    public func getKerningAdjustment(_ j: Int) -> Double {
        guard useKerning else { return 0 }

        let currSymbol = symbolBlocks[j]
        let prevSymbol = j > 0 ? symbolBlocks[j - 1] : nil
        var adjustment: Double = 0

        if currSymbol.symbolType == .glyph,
           let glyph = currSymbol.glyph,
           glyph.code == ChordSymbol.glyphs["over"] {
            let metrics = glyph.getMetrics()
            adjustment += metrics.xShift
        }

        if let prevSymbol,
           prevSymbol.symbolType == .glyph,
           let glyph = prevSymbol.glyph,
           glyph.code == ChordSymbol.glyphs["over"] {
            let metrics = glyph.getMetrics()
            adjustment += metrics.xShift
        }

        var preKernUpper = false
        var preKernLower = false
        if let prevSymbol, prevSymbol.symbolType == .text, !prevSymbol.text.isEmpty {
            let lastChar = String(prevSymbol.text.last!)
            preKernUpper = ChordSymbol.upperKerningText.contains(lastChar)
            preKernLower = ChordSymbol.lowerKerningText.contains(lastChar)
        }

        let kerningOffsetPixels = ChordSymbol.kerningOffset * fontSizeInPixels

        if preKernUpper && currSymbol.symbolModifier == .sup {
            adjustment += kerningOffsetPixels
        }

        if preKernLower && currSymbol.symbolType == .text && !currSymbol.text.isEmpty {
            let firstChar = currSymbol.text.first!
            if firstChar >= "a" && firstChar <= "z" {
                adjustment += kerningOffsetPixels / 2
            }
            if let prevSymbol, !prevSymbol.text.isEmpty {
                let lastChar = String(prevSymbol.text.last!)
                if ChordSymbol.upperKerningText.contains(lastChar) {
                    adjustment += kerningOffsetPixels / 2
                }
            }
        }

        return adjustment
    }

    // MARK: - Symbol Block Creation

    public func getSymbolBlock(
        text: String = "",
        symbolType: SymbolType = .text,
        symbolModifier: SymbolModifier = .none,
        glyphName: String? = nil,
        width: Double? = nil
    ) -> ChordSymbolBlock {
        var block = ChordSymbolBlock(
            text: text,
            symbolType: symbolType,
            symbolModifier: symbolModifier,
            xShift: 0,
            yShift: 0,
            vAlign: false,
            width: 0
        )

        if symbolType == .glyph, let glyphName,
           let glyphCode = ChordSymbol.glyphs[glyphName] {
            block.glyph = Glyph(code: glyphCode, point: 20,
                                options: GlyphOptions(category: "chordSymbol"))
        } else if symbolType == .text {
            block.width = getWidthForTextInEm(text)
        } else if symbolType == .line, let width {
            block.width = width
        }

        return block
    }

    // MARK: - Convenience Add Methods

    @discardableResult
    public func addSymbolBlock(
        text: String = "",
        symbolType: SymbolType = .text,
        symbolModifier: SymbolModifier = .none,
        glyphName: String? = nil,
        width: Double? = nil
    ) -> Self {
        symbolBlocks.append(getSymbolBlock(
            text: text, symbolType: symbolType,
            symbolModifier: symbolModifier,
            glyphName: glyphName, width: width
        ))
        return self
    }

    @discardableResult
    public func addText(_ text: String, symbolModifier: SymbolModifier = .none) -> Self {
        addSymbolBlock(text: text, symbolType: .text, symbolModifier: symbolModifier)
    }

    @discardableResult
    public func addTextSuperscript(_ text: String) -> Self {
        addSymbolBlock(text: text, symbolType: .text, symbolModifier: .sup)
    }

    @discardableResult
    public func addTextSubscript(_ text: String) -> Self {
        addSymbolBlock(text: text, symbolType: .text, symbolModifier: .sub)
    }

    @discardableResult
    public func addGlyphSuperscript(_ glyph: String) -> Self {
        addSymbolBlock(symbolType: .glyph, symbolModifier: .sup, glyphName: glyph)
    }

    @discardableResult
    public func addGlyph(_ glyph: String) -> Self {
        addSymbolBlock(symbolType: .glyph, glyphName: glyph)
    }

    @discardableResult
    public func addGlyphOrText(_ text: String) -> Self {
        var str = ""
        for char in text {
            let s = String(char)
            if ChordSymbol.glyphs[s] != nil {
                if !str.isEmpty {
                    _ = addText(str)
                    str = ""
                }
                _ = addGlyph(s)
            } else {
                str += s
            }
        }
        if !str.isEmpty {
            _ = addText(str)
        }
        return self
    }

    @discardableResult
    public func addLine(_ width: Double) -> Self {
        addSymbolBlock(symbolType: .line, width: width)
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        guard let stemmable = note as? StemmableNote else { return }
        setRendered()

        ctx.save()
        applyStyle()
        _ = ctx.openGroup("chordsymbol", getAttribute("id") ?? "")

        let start = note.getModifierStartXY(position: .above, index: index ?? 0)
        if let font = textFont { ctx.setFont(font) }

        var y: Double
        let hasStem = stemmable.hasStem()
        let stave = note.checkStave()

        if vertical == .bottom {
            y = stave.getYForBottomText(textLine + Tables.TEXT_HEIGHT_OFFSET_HACK)
            if hasStem {
                let stemExt = stemmable.checkStem().getExtents()
                let spacing = stave.getSpacingBetweenLines()
                let stemBase = stemmable.getStemDirection() == .up ? stemExt.baseY : stemExt.topY
                y = max(y, stemBase + spacing * (textLine + 2))
            }
        } else {
            let topY = note.getYs().min() ?? start.y
            y = min(stave.getYForTopText(textLine), topY - 10)
            if hasStem {
                let stemExt = stemmable.checkStem().getExtents()
                let spacing = stave.getSpacingBetweenLines()
                y = min(y, stemExt.topY - 5 - spacing * textLine)
            }
        }

        var x = start.x
        if horizontal == .left {
            x = start.x
        } else if horizontal == .right {
            x = start.x + getWidth()
        } else if horizontal == .center {
            x = start.x - getWidth() / 2
        } else {
            // centerStem
            x = stemmable.getStemX() - getWidth() / 2
        }

        for symbol in symbolBlocks {
            let isSuper = ChordSymbol.isSuperscript(symbol)
            let isSub = ChordSymbol.isSubscript(symbol)
            var curY = y

            if isSuper { curY += superscriptOffsetValue }
            if isSub { curY += subscriptOffsetValue }

            if symbol.symbolType == .text {
                if isSuper || isSub {
                    ctx.save()
                    if let font = textFont {
                        let sizeValue = Double(font.size.replacingOccurrences(
                            of: "[^0-9.]", with: "", options: .regularExpression
                        )) ?? 12
                        let smallerSize = sizeValue * ChordSymbol.superSubRatio
                        let smallerFont = FontInfo(
                            family: font.family, size: "\(smallerSize)pt",
                            weight: font.weight, style: font.style
                        )
                        ctx.setFont(smallerFont)
                    }
                }
                ctx.fillText(symbol.text, x + symbol.xShift, curY + symbol.yShift)
                if isSuper || isSub {
                    ctx.restore()
                }
            } else if symbol.symbolType == .glyph, let glyph = symbol.glyph {
                curY += symbol.yShift
                glyph.render(ctx: ctx, x: x + symbol.xShift, y: curY)
            } else if symbol.symbolType == .line {
                ctx.beginPath()
                ctx.setLineWidth(1)
                ctx.moveTo(x, y)
                ctx.lineTo(x + symbol.width, curY)
                ctx.stroke()
            }

            x += symbol.width
            if symbol.vAlign {
                x += symbol.xShift
            }
        }

        ctx.closeGroup()
        restoreStyle()
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("ChordSymbol", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
