// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum MultiMeasureRestError: Error, LocalizedError, Equatable, Sendable {
    case noStave
    case invalidMeasureCount(Int)

    public var errorDescription: String? {
        switch self {
        case .noStave:
            return "No stave attached to multi-measure rest."
        case .invalidMeasureCount(let count):
            return "Invalid multi-measure rest number: \(count)"
        }
    }
}

// MARK: - MultiMeasureRestRenderOptions

public struct MultiMeasureRestRenderOptions {
    public var numberOfMeasures: Int
    public var useSymbols: Bool = false
    public var symbolSpacing: Double = 0
    public var showNumber: Bool = true
    public var numberLine: Double = -0.5
    public var numberGlyphPoint: Double = Tables.NOTATION_FONT_SCALE
    public var paddingLeft: Double = 0
    public var paddingRight: Double = 0
    public var line: Double = 2
    public var spacingBetweenLinesPx: Double = Tables.STAVE_LINE_DISTANCE
    public var semibreveRestGlyphScale: Double = Tables.NOTATION_FONT_SCALE
    public var lineThickness: Double = 5
    public var serifThickness: Double = 2
    public private(set) var hasPaddingLeft: Bool = false
    public private(set) var hasPaddingRight: Bool = false
    public private(set) var hasLineThickness: Bool = false
    public private(set) var hasSymbolSpacing: Bool = false

    public init(
        numberOfMeasures: Int,
        useSymbols: Bool = false,
        symbolSpacing: Double? = nil,
        showNumber: Bool = true,
        numberLine: Double = -0.5,
        numberGlyphPoint: Double? = nil,
        paddingLeft: Double? = nil,
        paddingRight: Double? = nil,
        line: Double = 2,
        spacingBetweenLinesPx: Double = Tables.STAVE_LINE_DISTANCE,
        semibreveRestGlyphScale: Double = Tables.NOTATION_FONT_SCALE,
        lineThickness: Double? = nil,
        serifThickness: Double = 2
    ) {
        self.numberOfMeasures = numberOfMeasures
        self.useSymbols = useSymbols
        self.symbolSpacing = symbolSpacing ?? 0
        self.showNumber = showNumber
        self.numberLine = numberLine

        let musicFont = Glyph.MUSIC_FONT_STACK.first
        self.numberGlyphPoint = numberGlyphPoint
            ?? (musicFont?.lookupMetric("digits.point") as? Double)
            ?? Tables.NOTATION_FONT_SCALE

        self.paddingLeft = paddingLeft ?? 0
        self.paddingRight = paddingRight ?? 0
        self.line = line
        self.spacingBetweenLinesPx = spacingBetweenLinesPx
        self.semibreveRestGlyphScale = semibreveRestGlyphScale
        self.lineThickness = lineThickness ?? 5
        self.serifThickness = serifThickness
        self.hasPaddingLeft = paddingLeft != nil
        self.hasPaddingRight = paddingRight != nil
        self.hasLineThickness = lineThickness != nil
        self.hasSymbolSpacing = symbolSpacing != nil
    }
}

// MARK: - MultiMeasureRest

/// Renders a multi-measure rest with a thick horizontal line (with serifs)
/// or symbol glyphs (1-bar, 2-bar, 4-bar rest symbols), plus a measure count.
public final class MultiMeasureRest: VexElement {

    override public class var category: String { "MultiMeasureRest" }

    // MARK: - Semibreve Rest Cache

    private struct SemibreveRestInfo {
        var glyphFontScale: Double
        var glyphCode: String
        var width: Double
    }

    private static func getSemibreveRest() -> SemibreveRestInfo {
        let noteHead = NoteHead(noteHeadStruct: NoteHeadStruct(
            duration: .whole, noteType: .rest
        ))
        return SemibreveRestInfo(
            glyphFontScale: noteHead.renderOptions.glyphFontScale,
            glyphCode: noteHead.glyphCode,
            width: noteHead.getWidth()
        )
    }

    // MARK: - Properties

    public var renderOpts: MultiMeasureRestRenderOptions
    public var xs: (left: Double, right: Double) = (left: 0, right: 0)
    public var numberOfMeasures: Int
    public var mmrStave: Stave?
    public private(set) var initError: MultiMeasureRestError?

    private let hasPaddingLeft: Bool
    private let hasPaddingRight: Bool
    private let hasLineThickness: Bool
    private let hasSymbolSpacing: Bool

    // MARK: - Init

    public init(numberOfMeasures: Int, options: MultiMeasureRestRenderOptions) {
        self.numberOfMeasures = numberOfMeasures
        self.renderOpts = options

        self.hasPaddingLeft = options.hasPaddingLeft
        self.hasPaddingRight = options.hasPaddingRight
        self.hasLineThickness = options.hasLineThickness
        self.hasSymbolSpacing = options.hasSymbolSpacing

        if numberOfMeasures <= 0 {
            self.initError = .invalidMeasureCount(numberOfMeasures)
        }
        let musicFont = Glyph.MUSIC_FONT_STACK.first
        let fontLineShift = (musicFont?.lookupMetric("digits.shiftLine") as? Double) ?? 0
        self.renderOpts.numberLine += fontLineShift

        super.init()
    }

    public convenience init(validatingNumberOfMeasures numberOfMeasures: Int, options: MultiMeasureRestRenderOptions) throws {
        self.init(numberOfMeasures: numberOfMeasures, options: options)
        if let initError {
            throw initError
        }
    }

    // MARK: - Accessors

    public func getXs() -> (left: Double, right: Double) { xs }

    @discardableResult
    public func setStave(_ stave: Stave) -> Self {
        mmrStave = stave
        return self
    }

    public func getStave() -> Stave? { mmrStave }

    public func checkStave() -> Stave {
        (try? checkStaveThrowing()) ?? Stave(x: 0, y: 0, width: 0)
    }

    public func checkStaveThrowing() throws -> Stave {
        guard let mmrStave else {
            throw MultiMeasureRestError.noStave
        }
        return mmrStave
    }

    // MARK: - Draw Line

    public func drawLine(stave: Stave, ctx: any RenderContext, left: Double, right: Double, spacingBetweenLines: Double) {
        let options = renderOpts

        let y = stave.getYForLine(options.line)
        let padding = (right - left) * 0.1
        let leftPadded = left + padding
        let rightPadded = right - padding

        let lineThicknessHalf: Double
        if hasLineThickness {
            lineThicknessHalf = options.lineThickness * 0.5
        } else {
            lineThicknessHalf = spacingBetweenLines * 0.25
        }
        let serifThickness = options.serifThickness
        let top = y - spacingBetweenLines
        let bot = y + spacingBetweenLines
        let leftIndented = leftPadded + serifThickness
        let rightIndented = rightPadded - serifThickness
        let lineTop = y - lineThicknessHalf
        let lineBottom = y + lineThicknessHalf

        ctx.save()
        ctx.beginPath()
        ctx.moveTo(leftPadded, top)
        ctx.lineTo(leftIndented, top)
        ctx.lineTo(leftIndented, lineTop)
        ctx.lineTo(rightIndented, lineTop)
        ctx.lineTo(rightIndented, top)
        ctx.lineTo(rightPadded, top)
        ctx.lineTo(rightPadded, bot)
        ctx.lineTo(rightIndented, bot)
        ctx.lineTo(rightIndented, lineBottom)
        ctx.lineTo(leftIndented, lineBottom)
        ctx.lineTo(leftIndented, bot)
        ctx.lineTo(leftPadded, bot)
        ctx.closePath()
        ctx.fill()
    }

    // MARK: - Draw Symbols

    public func drawSymbols(stave: Stave, ctx: any RenderContext, left: Double, right: Double, spacingBetweenLines: Double) {
        let n4 = numberOfMeasures / 4
        let remainder = numberOfMeasures % 4
        let n2 = remainder / 2
        let n1 = remainder % 2

        let options = renderOpts

        let rest = MultiMeasureRest.getSemibreveRest()
        let restScale = options.semibreveRestGlyphScale
        let restWidth = rest.width * (restScale / rest.glyphFontScale)

        let glyphs2Width = restWidth * 0.5
        let glyphs2Height = spacingBetweenLines
        let glyphs1Width = restWidth

        let spacing = hasSymbolSpacing ? options.symbolSpacing : 10

        let totalCount = n4 + n2 + n1
        let width = Double(n4) * glyphs2Width + Double(n2) * glyphs2Width + Double(n1) * glyphs1Width + Double(totalCount - 1) * spacing
        var x = left + (right - left) * 0.5 - width * 0.5
        let line = options.line
        let yTop = stave.getYForLine(line - 1)
        let yMiddle = stave.getYForLine(line)
        let yBottom = stave.getYForLine(line + 1)

        ctx.save()
        ctx.setStrokeStyle("none")
        ctx.setLineWidth(0)

        for _ in 0..<n4 {
            ctx.fillRect(x, yMiddle - glyphs2Height, glyphs2Width, glyphs2Height)
            ctx.fillRect(x, yBottom - glyphs2Height, glyphs2Width, glyphs2Height)
            x += glyphs2Width + spacing
        }
        for _ in 0..<n2 {
            ctx.fillRect(x, yMiddle - glyphs2Height, glyphs2Width, glyphs2Height)
            x += glyphs2Width + spacing
        }
        for _ in 0..<n1 {
            Glyph.renderGlyph(ctx: ctx, xPos: x, yPos: yTop, point: restScale, code: rest.glyphCode)
            x += glyphs1Width + spacing
        }

        ctx.restore()
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let stave = try checkStaveThrowing()

        var left = stave.getNoteStartX()
        var right = stave.getNoteEndX()

        // Adjust for barline width at beginning
        let begModifiers = stave.getModifiers(position: .begin)
        if begModifiers.count == 1 && begModifiers[0] is Barline {
            left -= begModifiers[0].getModifierWidth()
        }

        let options = renderOpts
        if hasPaddingLeft {
            left = stave.getX() + options.paddingLeft
        }
        if hasPaddingRight {
            right = stave.getX() + stave.getWidth() - options.paddingRight
        }

        xs.left = left
        xs.right = right

        let spacingBetweenLines = options.spacingBetweenLinesPx
        if options.useSymbols {
            drawSymbols(stave: stave, ctx: ctx, left: left, right: right, spacingBetweenLines: spacingBetweenLines)
        } else {
            drawLine(stave: stave, ctx: ctx, left: left, right: right, spacingBetweenLines: spacingBetweenLines)
        }

        if options.showNumber {
            guard let numberDigits = TimeSignatureDigits(rawValue: String(numberOfMeasures)) else {
                throw MultiMeasureRestError.invalidMeasureCount(numberOfMeasures)
            }
            let timeSpec: TimeSignatureSpec = .bottomOnly(numberDigits)
            let timeSig = TimeSignature(timeSpec: timeSpec, customPadding: 0)
            timeSig.tsPoint = options.numberGlyphPoint
            _ = timeSig.setTimeSig(timeSpec)
            _ = timeSig.setStave(stave)
            timeSig.modifierX = left + (right - left) * 0.5 - timeSig.getModifierWidth() * 0.5
            timeSig.bottomLine = options.numberLine
            _ = timeSig.setContext(ctx)
            try timeSig.drawStave(stave: stave)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("MultiMeasureRest", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 140) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let stave = f.Stave(x: 10, y: 30, width: 490)
        _ = stave.addClef(.treble)

        let mmr = f.MultiMeasureRest(
            numberOfMeasures: 4,
            options: MultiMeasureRestRenderOptions(numberOfMeasures: 4)
        )
        _ = mmr.setStave(stave)

        try? f.draw()
    }
    .padding()
}
#endif
