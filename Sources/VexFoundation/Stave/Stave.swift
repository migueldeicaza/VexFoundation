// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Stave Options

/// Configuration for individual stave lines.
public struct StaveLineConfig {
    public var visible: Bool

    public init(visible: Bool = true) {
        self.visible = visible
    }
}

/// Configuration options for a Stave.
public struct StaveOptions {
    public var bottomTextPosition: Int
    public var lineConfig: [StaveLineConfig]
    public var spaceBelowStaffLn: Int
    public var spaceAboveStaffLn: Int
    public var verticalBarWidth: Double
    public var fillStyle: String
    public var leftBar: Bool
    public var rightBar: Bool
    public var spacingBetweenLinesPx: Double
    public var topTextPosition: Int
    public var numLines: Int

    public init(
        bottomTextPosition: Int = 4,
        lineConfig: [StaveLineConfig] = [],
        spaceBelowStaffLn: Int = 4,
        spaceAboveStaffLn: Int = 4,
        verticalBarWidth: Double = 10,
        fillStyle: String = "#999999",
        leftBar: Bool = true,
        rightBar: Bool = true,
        spacingBetweenLinesPx: Double = Tables.STAVE_LINE_DISTANCE,
        topTextPosition: Int = 1,
        numLines: Int = 5
    ) {
        self.bottomTextPosition = bottomTextPosition
        self.lineConfig = lineConfig
        self.spaceBelowStaffLn = spaceBelowStaffLn
        self.spaceAboveStaffLn = spaceAboveStaffLn
        self.verticalBarWidth = verticalBarWidth
        self.fillStyle = fillStyle
        self.leftBar = leftBar
        self.rightBar = rightBar
        self.spacingBetweenLinesPx = spacingBetweenLinesPx
        self.topTextPosition = topTextPosition
        self.numLines = numLines
    }
}

// MARK: - Sort Orders

private let SORT_ORDER_BEG_MODIFIERS: [String: Int] = [
    "Barline": 0,
    "Clef": 1,
    "KeySignature": 2,
    "TimeSignature": 3,
]

private let SORT_ORDER_END_MODIFIERS: [String: Int] = [
    "TimeSignature": 0,
    "KeySignature": 1,
    "Barline": 2,
    "Clef": 3,
]

// MARK: - Stave

/// Main stave class. Manages modifiers, calculates layout, and renders staff lines.
open class Stave: VexElement {

    override open class var category: String { "Stave" }

    override public class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SANS_SERIF,
            size: 8,
            weight: VexFontWeight.normal.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    /// Default left+right padding used to size staves correctly.
    public static var defaultPadding: Double {
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        let left = (musicFont.lookupMetric("stave.padding") as? Double) ?? 0
        let right = (musicFont.lookupMetric("stave.endPaddingMax") as? Double) ?? 0
        return left + right
    }

    /// Right padding only, used when startX is pre-determined.
    public static var rightPadding: Double {
        let musicFont = Glyph.MUSIC_FONT_STACK.first!
        return (musicFont.lookupMetric("stave.endPaddingMax") as? Double) ?? 0
    }

    // MARK: - Properties

    public var options: StaveOptions
    public var staveX: Double
    public var staveY: Double
    public var staveWidth: Double
    public var staveHeight: Double = 0
    public var startX: Double
    public var endX: Double
    public var formatted: Bool = false
    public var measure: Int = 0
    public var clefName: ClefName = .treble
    public var endClefName: ClefName?
    public var modifiers: [StaveModifier] = []
    public var defaultLedgerLineStyle: ElementStyle

    // MARK: - Init

    public init(x: Double, y: Double, width: Double, options: StaveOptions? = nil) {
        self.staveX = x
        self.staveY = y
        self.staveWidth = width
        self.startX = x + 5
        self.endX = x + width
        self.defaultLedgerLineStyle = ElementStyle(strokeStyle: "#444", lineWidth: 1.4)

        self.options = options ?? StaveOptions()
        super.init()
        resetFont()

        resetLines()

        // Add beginning and ending bar lines
        addModifier(Barline(self.options.leftBar ? .single : .none))
        addEndModifier(Barline(self.options.rightBar ? .single : .none))
    }

    // MARK: - Line Configuration

    public func resetLines() {
        options.lineConfig = (0..<options.numLines).map { _ in StaveLineConfig(visible: true) }
        staveHeight = Double(options.numLines + options.spaceAboveStaffLn) * options.spacingBetweenLinesPx
        options.bottomTextPosition = options.numLines
    }

    @discardableResult
    public func setNumLines(_ n: Int) -> Self {
        options.numLines = n
        resetLines()
        return self
    }

    public func getNumLines() -> Int { options.numLines }

    public func getConfigForLines() -> [StaveLineConfig] { options.lineConfig }

    @discardableResult
    public func setConfigForLine(_ lineNumber: Int, config: StaveLineConfig) -> Self {
        guard lineNumber >= 0 && lineNumber < options.numLines else {
            fatalError("[VexError] StaveConfigError: Line number out of range.")
        }
        options.lineConfig[lineNumber] = config
        return self
    }

    @discardableResult
    public func setConfigForLines(_ configs: [StaveLineConfig]) -> Self {
        guard configs.count == options.numLines else {
            fatalError("[VexError] StaveConfigError: Config array length must match num_lines.")
        }
        options.lineConfig = configs
        return self
    }

    // MARK: - Position & Dimensions

    public func getX() -> Double { staveX }

    @discardableResult
    public func setStaveX(_ x: Double) -> Self {
        let shift = x - staveX
        formatted = false
        staveX = x
        startX += shift
        endX += shift
        for mod in modifiers {
            mod.setModifierX(mod.getModifierX() + shift)
        }
        return self
    }

    public func getY() -> Double { staveY }

    @discardableResult
    public func setStaveY(_ y: Double) -> Self {
        staveY = y
        return self
    }

    public func getWidth() -> Double { staveWidth }

    @discardableResult
    public func setStaveWidth(_ width: Double) -> Self {
        formatted = false
        staveWidth = width
        endX = staveX + width
        return self
    }

    public func getHeight() -> Double { staveHeight }

    public func getSpacingBetweenLines() -> Double { options.spacingBetweenLinesPx }

    public func getVerticalBarWidth() -> Double { options.verticalBarWidth }

    /// Convert staff line units to pixels.
    public func space(_ spacing: Double) -> Double {
        options.spacingBetweenLinesPx * spacing
    }

    // MARK: - Y Coordinates

    /// Get Y position for the center of a staff line.
    public func getYForLine(_ line: Double) -> Double {
        staveY + line * options.spacingBetweenLinesPx + Double(options.spaceAboveStaffLn) * options.spacingBetweenLinesPx
    }

    /// Get the line number for a given Y position.
    public func getLineForY(_ y: Double) -> Double {
        (y - staveY) / options.spacingBetweenLinesPx - Double(options.spaceAboveStaffLn)
    }

    public func getYForTopText(_ line: Double = 0) -> Double {
        getYForLine(-line - Double(options.topTextPosition))
    }

    public func getYForBottomText(_ line: Double = 0) -> Double {
        getYForLine(Double(options.bottomTextPosition) + line)
    }

    public func getYForNote(_ line: Double) -> Double {
        staveY + Double(options.spaceAboveStaffLn) * options.spacingBetweenLinesPx
            + 5 * options.spacingBetweenLinesPx - line * options.spacingBetweenLinesPx
    }

    open func getYForGlyphs() -> Double {
        getYForLine(3)
    }

    public func getTopLineTopY() -> Double {
        getYForLine(0) - Tables.STAVE_LINE_THICKNESS / 2
    }

    public func getBottomLineBottomY() -> Double {
        getYForLine(Double(getNumLines() - 1)) + Tables.STAVE_LINE_THICKNESS / 2
    }

    public func getBottomLineY() -> Double {
        getYForLine(Double(options.numLines))
    }

    public func getBottomY() -> Double {
        getYForLine(Double(options.numLines)) + Double(options.spaceBelowStaffLn) * options.spacingBetweenLinesPx
    }

    override public func getStyle() -> ElementStyle? {
        var s = super.getStyle() ?? ElementStyle()
        if s.fillStyle == nil { s.fillStyle = options.fillStyle }
        if s.strokeStyle == nil { s.strokeStyle = options.fillStyle }
        if s.lineWidth == nil { s.lineWidth = Tables.STAVE_LINE_THICKNESS }
        return s
    }

    public func getBBox() -> BoundingBox {
        BoundingBox(x: staveX, y: staveY, w: staveWidth, h: getBottomY() - staveY)
    }

    // MARK: - Note Positions

    @discardableResult
    public func setNoteStartX(_ x: Double) -> Self {
        if !formatted { format() }
        startX = x
        return self
    }

    public func getNoteStartX() -> Double {
        if !formatted { format() }
        return startX
    }

    public func getNoteEndX() -> Double {
        if !formatted { format() }
        return endX
    }

    public func getTieStartX() -> Double { startX }
    public func getTieEndX() -> Double { endX }

    // MARK: - Measure

    @discardableResult
    public func setMeasure(_ measure: Int) -> Self {
        self.measure = measure
        return self
    }

    public func getMeasure() -> Int { measure }

    // MARK: - Modifier Management

    @discardableResult
    public func addModifier(_ modifier: StaveModifier, position: StaveModifierPosition? = nil) -> Self {
        if let position {
            modifier.setPosition(position)
        }
        modifier.setStave(self)
        formatted = false
        modifiers.append(modifier)
        return self
    }

    @discardableResult
    public func addEndModifier(_ modifier: StaveModifier) -> Self {
        addModifier(modifier, position: .end)
    }

    public func getModifiers(position: StaveModifierPosition? = nil, category: String? = nil) -> [StaveModifier] {
        if position == nil && category == nil {
            return modifiers
        } else if position == nil {
            return modifiers.filter { $0.getCategory() == category }
        } else if category == nil {
            return modifiers.filter { $0.getPosition() == position }
        } else {
            return modifiers.filter { $0.getPosition() == position && $0.getCategory() == category }
        }
    }

    public func getModifierXShift(_ index: Int = 0) -> Double {
        if !formatted { format() }

        if getModifiers(position: .begin).count == 1 { return 0 }

        if modifiers[index].getPosition() == .right { return 0 }

        var shiftX = startX - staveX
        let begBarline = modifiers[0] as! Barline
        if begBarline.getBarlineType() == .repeatBegin && shiftX > begBarline.getModifierWidth() {
            shiftX -= begBarline.getModifierWidth()
        }
        return shiftX
    }

    // MARK: - Barline Configuration

    @discardableResult
    public func setBegBarType(_ type: BarlineType) -> Self {
        if type == .single || type == .repeatBegin || type == .none {
            (modifiers[0] as! Barline).setBarlineType(type)
            formatted = false
        }
        return self
    }

    @discardableResult
    public func setEndBarType(_ type: BarlineType) -> Self {
        if type != .repeatBegin {
            (modifiers[1] as! Barline).setBarlineType(type)
            formatted = false
        }
        return self
    }

    // MARK: - Clef

    @discardableResult
    public func setClefLines(_ clefSpec: ClefName) -> Self {
        clefName = clefSpec
        return self
    }

    public func getClef() -> ClefName { clefName }

    public func getEndClef() -> ClefName? { endClefName }

    @discardableResult
    public func setClef(_ clefSpec: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil,
                        position: StaveModifierPosition = .begin) -> Self {
        if position == .end {
            endClefName = clefSpec
        } else {
            clefName = clefSpec
        }

        let clefs = getModifiers(position: position, category: Clef.category).compactMap { $0 as? Clef }
        if clefs.isEmpty {
            addClef(clefSpec, size: size, annotation: annotation, position: position)
        } else {
            clefs[0].setClefType(clefSpec, size: size, annotation: annotation)
        }
        return self
    }

    @discardableResult
    public func addClef(_ clef: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil,
                        position: StaveModifierPosition = .begin) -> Self {
        if position == .begin {
            clefName = clef
        } else if position == .end {
            endClefName = clef
        }
        addModifier(Clef(type: clef, size: size, annotation: annotation), position: position)
        return self
    }

    @discardableResult
    public func setEndClef(_ clefSpec: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        setClef(clefSpec, size: size, annotation: annotation, position: .end)
    }

    @discardableResult
    public func addEndClef(_ clef: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        addClef(clef, size: size, annotation: annotation, position: .end)
    }

    // MARK: - Key Signature

    @discardableResult
    public func setKeySignature(_ keySpec: String, cancelKeySpec: String? = nil,
                                position: StaveModifierPosition = .begin) -> Self {
        let keySigs = getModifiers(position: position, category: KeySignature.category).compactMap { $0 as? KeySignature }
        if keySigs.isEmpty {
            addKeySignature(keySpec, cancelKeySpec: cancelKeySpec, position: position)
        } else {
            keySigs[0].setKeySig(keySpec, cancelKeySpec: cancelKeySpec)
        }
        return self
    }

    @discardableResult
    public func addKeySignature(_ keySpec: String, cancelKeySpec: String? = nil,
                                position: StaveModifierPosition = .begin) -> Self {
        let ks = KeySignature(keySpec: keySpec, cancelKeySpec: cancelKeySpec)
        ks.setPosition(position)
        addModifier(ks, position: position)
        return self
    }

    @discardableResult
    public func setEndKeySignature(_ keySpec: String, cancelKeySpec: String? = nil) -> Self {
        setKeySignature(keySpec, cancelKeySpec: cancelKeySpec, position: .end)
    }

    // MARK: - Time Signature

    @discardableResult
    public func setTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil,
                                 position: StaveModifierPosition = .begin) -> Self {
        let timeSigs = getModifiers(position: position, category: TimeSignature.category).compactMap { $0 as? TimeSignature }
        if timeSigs.isEmpty {
            addTimeSignature(timeSpec, customPadding: customPadding, position: position)
        } else {
            timeSigs[0].setTimeSig(timeSpec)
        }
        return self
    }

    @discardableResult
    public func addTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil,
                                 position: StaveModifierPosition = .begin) -> Self {
        let ts = TimeSignature(timeSpec: timeSpec, customPadding: customPadding ?? 15)
        addModifier(ts, position: position)
        return self
    }

    @discardableResult
    public func setEndTimeSignature(_ timeSpec: TimeSignatureSpec, customPadding: Double? = nil) -> Self {
        setTimeSignature(timeSpec, customPadding: customPadding, position: .end)
    }

    // MARK: - Ledger Lines

    public func setDefaultLedgerLineStyle(_ style: ElementStyle) {
        defaultLedgerLineStyle = style
    }

    public func getDefaultLedgerLineStyle() -> ElementStyle {
        var s = getStyle() ?? ElementStyle()
        if let ss = defaultLedgerLineStyle.strokeStyle { s.strokeStyle = ss }
        if let lw = defaultLedgerLineStyle.lineWidth { s.lineWidth = lw }
        return s
    }

    // MARK: - Format

    /// Position all modifiers and calculate note area bounds.
    public func format() {
        let begBarline = modifiers[0] as! Barline
        let endBarline = modifiers[1]

        var begModifiers = getModifiers(position: .begin)
        var endModifiers = getModifiers(position: .end)

        sortByCategory(&begModifiers, order: SORT_ORDER_BEG_MODIFIERS)
        sortByCategory(&endModifiers, order: SORT_ORDER_END_MODIFIERS)

        // Handle REPEAT_BEGIN: move repeat bar to end of begin modifiers
        if begModifiers.count > 1 && begBarline.getBarlineType() == .repeatBegin {
            let first = begModifiers.removeFirst()
            begModifiers.append(first)
            begModifiers.insert(Barline(.single), at: 0)
        }

        // Handle end modifiers barline position
        if let idx = endModifiers.firstIndex(where: { $0 === endBarline }), idx > 0 {
            endModifiers.insert(Barline(.none), at: 0)
        }

        // Layout begin modifiers (left to right)
        var x = staveX
        var offset = 0
        for i in 0..<begModifiers.count {
            let modifier = begModifiers[i]
            let pad = modifier.getPadding(i + offset)
            let width = modifier.getModifierWidth()
            x += pad
            modifier.setModifierX(x)
            x += width
            if pad + width == 0 { offset -= 1 }
        }
        startX = x

        // Layout end modifiers (right to left)
        x = staveX + staveWidth

        var widths = (left: 0.0, right: 0.0, paddingLeft: 0.0, paddingRight: 0.0)
        var lastBarlineIdx = 0

        for i in 0..<endModifiers.count {
            let modifier = endModifiers[i]
            if modifier is Barline { lastBarlineIdx = i }

            widths = (0, 0, 0, 0)
            let lm = modifier.getLayoutMetrics()

            if let lm {
                if i != 0 {
                    widths.right = lm.xMax
                    widths.paddingRight = lm.paddingRight
                }
                widths.left = -lm.xMin
                widths.paddingLeft = lm.paddingLeft
                if i == endModifiers.count - 1 {
                    widths.paddingLeft = 0
                }
            } else {
                widths.paddingRight = modifier.getPadding(i - lastBarlineIdx)
                if i != 0 {
                    widths.right = modifier.getModifierWidth()
                }
                if i == 0 {
                    widths.left = modifier.getModifierWidth()
                }
            }

            x -= widths.paddingRight
            x -= widths.right
            modifier.setModifierX(x)
            x -= widths.left
            x -= widths.paddingLeft
        }

        endX = endModifiers.count == 1 ? staveX + staveWidth : x
        formatted = true
    }

    private func sortByCategory(_ items: inout [StaveModifier], order: [String: Int]) {
        items.sort { a, b in
            (order[a.getCategory()] ?? 99) < (order[b.getCategory()] ?? 99)
        }
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        applyStyle(context: ctx)
        _ = ctx.openGroup("stave", getAttribute("id"))
        if !formatted { format() }

        // Render staff lines
        for line in 0..<options.numLines {
            let y = getYForLine(Double(line))
            if options.lineConfig[line].visible {
                ctx.beginPath()
                ctx.moveTo(staveX, y)
                ctx.lineTo(staveX + staveWidth, y)
                ctx.stroke()
            }
        }

        ctx.closeGroup()
        restoreStyle(context: ctx)

        // Draw modifiers
        for i in 0..<modifiers.count {
            let modifier = modifiers[i]
            modifier.applyStyle(context: ctx)
            try modifier.drawStave(stave: self, xShift: getModifierXShift(i))
            modifier.restoreStyle(context: ctx)
        }

        // Render measure numbers
        if measure > 0 {
            ctx.save()
            ctx.setFont(fontInfo)
            let textWidth = ctx.measureText("\(measure)").width
            let y = getYForTopText(0) + 3
            ctx.fillText("\(measure)", staveX - textWidth / 2, y)
            ctx.restore()
        }
    }

    // MARK: - Format Beginning Modifiers Across Staves

    /// Align beginning modifiers across multiple staves.
    public static func formatBegModifiers(_ staves: [Stave]) {
        // Ensure all staves are formatted
        for stave in staves {
            if !stave.formatted { stave.format() }
        }

        func adjustCategoryStartX(_ category: String) {
            var minStartX: Double = 0
            for stave in staves {
                let mods = stave.getModifiers(position: .begin, category: category)
                if let first = mods.first, first.getModifierX() > minStartX {
                    minStartX = first.getModifierX()
                }
            }

            for stave in staves {
                var adjustX: Double = 0
                let mods = stave.getModifiers(position: .begin, category: category)
                for mod in mods {
                    if minStartX - mod.getModifierX() > adjustX {
                        adjustX = minStartX - mod.getModifierX()
                    }
                }
                let allMods = stave.getModifiers(position: .begin)
                var shouldAdjust = false
                for mod in allMods {
                    if mod.getCategory() == category { shouldAdjust = true }
                    if shouldAdjust && adjustX > 0 {
                        mod.setModifierX(mod.getModifierX() + adjustX)
                    }
                }
                stave.setNoteStartX(stave.getNoteStartX() + adjustX)
            }
        }

        adjustCategoryStartX("Clef")
        adjustCategoryStartX("KeySignature")
        adjustCategoryStartX("TimeSignature")

        // Align note start
        var maxX: Double = 0
        for stave in staves {
            maxX = max(maxX, stave.getNoteStartX())
        }
        for stave in staves {
            stave.setNoteStartX(maxX)
        }

        // Align REPEAT_BEGIN
        maxX = 0
        for stave in staves {
            let mods = stave.getModifiers(position: .begin, category: "Barline")
            for mod in mods {
                if let barline = mod as? Barline, barline.getBarlineType() == .repeatBegin {
                    maxX = max(maxX, mod.getModifierX())
                }
            }
        }
        if maxX > 0 {
            for stave in staves {
                let mods = stave.getModifiers(position: .begin, category: "Barline")
                for mod in mods {
                    if let barline = mod as? Barline, barline.getBarlineType() == .repeatBegin {
                        mod.setModifierX(maxX)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Stave", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 500, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let factory = Factory(options: FactoryOptions(width: 480, height: 150))
        _ = factory.setContext(ctx)
        let score = factory.EasyScore()

        let system = factory.System(options: SystemOptions(
            factory: factory, x: 10, width: 480, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [
                score.voice(score.notes("C5/q, D5, E5, F5"))
            ]
        ))
            .addClef(.treble)
            .addKeySignature("G")
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? factory.draw()
    }
    .padding()
}
#endif
