// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Tab Note Position

/// A string/fret position on a tab stave.
public struct TabNotePosition {
    /// String number (1-based, e.g., on a 6-string guitar, str ranges from 1 to 6).
    public var str: Int
    /// Fret number or "X" for muted string.
    public var fret: String

    public init(str: Int, fret: String) {
        self.str = str
        self.fret = fret
    }

    public init(str: Int, fret: Int) {
        self.str = str
        self.fret = String(fret)
    }
}

// MARK: - Tab Note Struct

/// Input structure for creating a TabNote.
public struct TabNoteStruct {
    public var positions: [TabNotePosition]
    public var duration: String
    public var dots: Int?
    public var type: String?
    public var stemDirection: Int?

    public init(
        positions: [TabNotePosition],
        duration: String = "q",
        dots: Int? = nil,
        type: String? = nil,
        stemDirection: Int? = nil
    ) {
        self.positions = positions
        self.duration = duration
        self.dots = dots
        self.type = type
        self.stemDirection = stemDirection
    }
}

// MARK: - Helper Functions

/// Gets unused strings grouped together if consecutive.
private func getUnusedStringGroups(numLines: Int, stringsUsed: [Int]) -> [[Int]] {
    var stemThrough: [[Int]] = []
    var group: [Int] = []
    for string in 1...numLines {
        if stringsUsed.contains(string) {
            stemThrough.append(group)
            group = []
        } else {
            group.append(string)
        }
    }
    if !group.isEmpty { stemThrough.append(group) }
    return stemThrough
}

/// Gets groups of points that outline the partial stem lines between fret positions.
private func getPartialStemLines(
    stemY: Double, unusedStrings: [[Int]], stave: Stave, stemDirection: Int
) -> [[Double]] {
    let upStem = stemDirection != 1
    let downStem = stemDirection != -1
    let lineSpacing = stave.getSpacingBetweenLines()
    let totalLines = stave.getNumLines()

    var stemLines: [[Double]] = []

    for var strings in unusedStrings {
        let containsLastString = strings.contains(totalLines)
        let containsFirstString = strings.contains(1)

        if (upStem && containsFirstString) || (downStem && containsLastString) {
            continue
        }

        if strings.count == 1 {
            strings.append(strings[0])
        }

        var lineYs: [Double] = []
        for (index, string) in strings.enumerated() {
            let isTopBound = string == 1
            let isBottomBound = string == totalLines

            var y = stave.getYForLine(Double(string - 1))

            if index == 0 && !isTopBound {
                y -= lineSpacing / 2 - 1
            } else if index == strings.count - 1 && !isBottomBound {
                y += lineSpacing / 2 - 1
            }

            lineYs.append(y)

            if stemDirection == 1 && isTopBound {
                lineYs.append(stemY - 2)
            } else if stemDirection == -1 && isBottomBound {
                lineYs.append(stemY + 2)
            }
        }

        stemLines.append(lineYs.sorted())
    }

    return stemLines
}

// MARK: - TabNote

/// Renders notes for tablature notation. Consists of one or more fret positions,
/// and can be drawn with or without stems.
open class TabNote: StemmableNote {

    override open class var category: String { "TabNote" }

    // MARK: - Properties

    public var ghost: Bool = false
    public var glyphPropsArr: [TabGlyphProps] = []
    public var positions: [TabNotePosition]

    // MARK: - Init

    public init(_ noteStruct: TabNoteStruct, drawStem: Bool = false) {
        self.positions = noteStruct.positions

        let noteInput = NoteStruct(
            keys: noteStruct.positions.map { "\(String($0.fret))/\($0.str)" },
            duration: noteStruct.duration,
            dots: noteStruct.dots,
            type: noteStruct.type
        )

        super.init(noteInput)

        renderOptions.glyphFontScale = Tables.TABLATURE_FONT_SCALE
        renderOptions.drawStem = drawStem
        renderOptions.drawDots = drawStem
        renderOptions.drawStemThroughStave = false
        renderOptions.yShift = 0
        renderOptions.scale = 1.0
        renderOptions.font = "\(VexFont.SIZE)pt \(VexFont.SANS_SERIF)"

        guard let gp = Tables.getGlyphProps(duration: noteDuration, type: noteType) else {
            fatalError("[VexError] BadArguments: No glyph found for duration '\(noteDuration)' and type '\(noteType)'")
        }
        glyphProps = gp

        buildStem()

        if let dir = noteStruct.stemDirection {
            setStemDirection(dir)
        } else {
            setStemDirection(Stem.UP)
        }

        updateWidth()
    }

    // MARK: - String Accessors

    /// Return the number of the greatest string (lowest on display).
    public func greatestString() -> Int {
        positions.map { $0.str }.max() ?? 0
    }

    /// Return the number of the least string (highest on display).
    public func leastString() -> Int {
        positions.map { $0.str }.min() ?? 0
    }

    // MARK: - Reset

    @discardableResult
    public func reset() -> Self {
        if let stave = getStave() { _ = setStave(stave) }
        return self
    }

    // MARK: - Ghost

    @discardableResult
    public func setGhost(_ ghost: Bool) -> Self {
        self.ghost = ghost
        updateWidth()
        return self
    }

    // MARK: - Stem

    override public func hasStem() -> Bool {
        renderOptions.drawStem
    }

    override public func getStemExtension() -> Double {
        if let override = stemExtensionOverride {
            return override
        }
        return getStemDirection() == Stem.UP
            ? glyphProps.tabnoteStemUpExtension
            : glyphProps.tabnoteStemDownExtension
    }

    // MARK: - Width

    public func updateWidth() {
        glyphPropsArr = []
        var w: Double = 0
        for i in 0..<positions.count {
            var fret = positions[i].fret
            if ghost { fret = "(\(fret))" }
            let tabGlyph = Tables.tabToGlyphProps(fret, scale: renderOptions.scale)
            glyphPropsArr.append(tabGlyph)
            w = max(tabGlyph.getWidth(), w)
        }
        tickableWidth = w
    }

    // MARK: - Stave

    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        let ctx = stave.getContext()
        if let ctx { setContext(ctx) }

        // Recalculate widths based on the context's font
        if ctx != nil {
            var w: Double = 0
            for i in 0..<glyphPropsArr.count {
                var gp = glyphPropsArr[i]
                let text = gp.text
                if text.uppercased() != "X" {
                    if let font = renderOptions.font {
                        ctx!.save()
                        ctx!.setFont(font)
                        gp.width = ctx!.measureText(text).width
                        ctx!.restore()
                    }
                }
                glyphPropsArr[i] = gp
                w = max(gp.getWidth(), w)
            }
            tickableWidth = w
        }

        // Calculate Y positions
        let ys = positions.map { stave.getYForLine(Double($0.str - 1)) }
        setYs(ys)

        if let stem {
            stem.setYBounds(getStemY(), getStemY())
        }

        return self
    }

    // MARK: - Positions

    public func getPositions() -> [TabNotePosition] {
        positions
    }

    // MARK: - Modifier Start XY

    override public func getModifierStartXY(position: ModifierPosition, index: Int) -> (x: Double, y: Double) {
        guard preFormatted else {
            fatalError("[VexError] UnformattedNote: Can't call GetModifierStartXY on an unformatted note")
        }
        guard !ys.isEmpty else {
            fatalError("[VexError] NoYValues: No Y-Values calculated for this note.")
        }

        var x: Double = 0
        if position == .left {
            x = -2
        } else if position == .right {
            x = tickableWidth + 2
        } else if position == .below || position == .above {
            x = tickableWidth / 2
        }

        return (x: getAbsoluteX() + x, y: ys[index])
    }

    // MARK: - Rest Line

    override public func getLineForRest() -> Double {
        Double(positions[0].str)
    }

    // MARK: - Pre Format

    override open func preFormat() {
        if preFormatted { return }
        modifierContext?.preFormat()
        preFormatted = true
    }

    // MARK: - Stem Position

    override public func getStemX() -> Double {
        getCenterGlyphX()
    }

    public func getStemY() -> Double {
        let numLines = checkStave().getNumLines()
        let stemUpLine = -0.5
        let stemDownLine = Double(numLines) - 0.5
        let stemStartLine = Stem.UP == getStemDirection() ? stemUpLine : stemDownLine
        return checkStave().getYForLine(stemStartLine)
    }

    override public func getStemExtents() -> (topY: Double, baseY: Double) {
        checkStem().getExtents()
    }

    // MARK: - Draw Flag

    public func drawFlag() {
        guard let context = getContext() else { return }
        let shouldDrawFlag = beam == nil && renderOptions.drawStem

        if glyphProps.flag && shouldDrawFlag {
            let flagX = getStemX()
            let flagY: Double
            if getStemDirection() == Stem.DOWN {
                flagY = getStemY() - checkStem().getHeight()
                    - glyphProps.stemDownExtension
            } else {
                flagY = getStemY() - checkStem().getHeight()
                    + glyphProps.stemUpExtension
            }
            flag?.render(ctx: context, x: flagX, y: flagY)
        }
    }

    // MARK: - Draw Modifiers

    public func drawModifiers() {
        for modifier in noteModifiers {
            if modifier is Dot && !renderOptions.drawDots {
                continue
            }
            modifier.setContext(getContext())
            try? modifier.drawWithStyle()
        }
    }

    // MARK: - Draw Stem Through

    public func drawStemThrough() {
        let stemX = getStemX()
        let stemY = getStemY()
        guard let ctx = getContext() else { return }

        if renderOptions.drawStem && renderOptions.drawStemThroughStave {
            let numLines = checkStave().getNumLines()
            let stringsUsed = positions.map { $0.str }
            let unusedStrings = getUnusedStringGroups(numLines: numLines, stringsUsed: stringsUsed)
            let stemLines = getPartialStemLines(
                stemY: stemY, unusedStrings: unusedStrings,
                stave: checkStave(), stemDirection: getStemDirection()
            )

            ctx.save()
            ctx.setLineWidth(Stem.WIDTH)
            for bounds in stemLines {
                if bounds.isEmpty { continue }
                ctx.beginPath()
                ctx.moveTo(stemX, bounds[0])
                ctx.lineTo(stemX, bounds[bounds.count - 1])
                ctx.stroke()
                ctx.closePath()
            }
            ctx.restore()
        }
    }

    // MARK: - Draw Positions

    public func drawPositions() {
        guard let ctx = getContext() else { return }
        let x = getAbsoluteX()
        let ys = self.ys
        for i in 0..<positions.count {
            let y = ys[i] + renderOptions.yShift
            let glyphProps = glyphPropsArr[i]

            let noteGlyphWidth = tickableWidth
            let tabX = x + noteGlyphWidth / 2 - glyphProps.getWidth() / 2

            ctx.clearRect(tabX - 2, y - 3, glyphProps.getWidth() + 4, 6)

            if let code = glyphProps.code {
                Glyph.renderGlyph(
                    ctx: ctx, xPos: tabX, yPos: y,
                    point: renderOptions.glyphFontScale * renderOptions.scale,
                    code: code
                )
            } else {
                ctx.save()
                if let font = renderOptions.font {
                    ctx.setFont(font)
                }
                let text = glyphProps.text
                ctx.fillText(text, tabX, y + 5 * renderOptions.scale)
                ctx.restore()
            }
        }
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        guard !ys.isEmpty else {
            fatalError("[VexError] NoYValues: Can't draw note without Y values.")
        }

        setRendered()
        let renderStem = beam == nil && renderOptions.drawStem

        applyStyle()
        _ = ctx.openGroup("tabnote", getAttribute("id") ?? "")
        drawPositions()
        drawStemThrough()

        if let stem, renderStem {
            let stemX = getStemX()
            stem.setNoteHeadXBounds(stemX, stemX)
            stem.setContext(ctx)
            try stem.draw()
        }

        drawFlag()
        drawModifiers()
        ctx.closeGroup()
        restoreStyle()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TabNote", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)

        let ts = f.TabStave(x: 10, y: 10, width: 490)
        _ = ts.addTabGlyph()

        let notes: [Note] = [
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 3)], duration: "q")),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5)], duration: "q")),
            f.TabNote(TabNoteStruct(positions: [TabNotePosition(str: 3, fret: 7)], duration: "q")),
            f.TabNote(TabNoteStruct(positions: [
                TabNotePosition(str: 1, fret: 0),
                TabNotePosition(str: 2, fret: 1),
                TabNotePosition(str: 3, fret: 0),
            ], duration: "q")),
        ]

        let voice = f.Voice(timeSpec: "4/4")
        _ = voice.addTickables(notes)

        let formatter = f.Formatter()
        _ = formatter.joinVoices([voice])
        _ = formatter.format([voice], justifyWidth: 400)

        try? f.draw()
    }
    .padding()
}
#endif
