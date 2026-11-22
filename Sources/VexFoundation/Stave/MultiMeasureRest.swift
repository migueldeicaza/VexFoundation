// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/multimeasurerest.ts` (VexFlow 5.0.0).
// This class implements multiple measure rests.

import Foundation

public enum MultiMeasureRestError: Error, LocalizedError, Equatable, Sendable {
    case noStave
    case invalidMeasureCount(Int)
    case zeroWidthLine

    public var errorDescription: String? {
        switch self {
        case .noStave:
            return "No stave attached to instance."
        case .invalidMeasureCount(let count):
            return "Invalid multi-measure rest number: \(count)"
        case .zeroWidthLine:
            return "Cannot drawLine if width is 0"
        }
    }
}

// MARK: - MultiMeasureRestRenderOptions

public struct MultiMeasureRestRenderOptions {
    /// Extracted by Factory.MultiMeasureRest() and passed to the MultiMeasureRest constructor.
    public var numberOfMeasures: Int
    /// Use rest symbols. Defaults to `false`, which renders a thick horizontal line with serifs at both ends.
    public var useSymbols: Bool = false
    /// Horizontal spacing between rest symbol glyphs (if `useSymbols` is `true`).
    public var symbolSpacing: Double = 0
    /// Show the number of measures at the top. Defaults to `true`.
    public var showNumber: Bool = true
    /// Vertical position of the "number of measures" text (measured in stave lines).
    /// Defaults to -0.5, which is above the stave. 6.5 is below the stave.
    public var numberLine: Double = -0.5
    /// Font size of the "number of measures" text.
    public var numberGlyphPoint: Double
    /// Left padding from `stave.getX()`.
    public var paddingLeft: Double = 0
    /// Right padding from `stave.getX() + stave.getWidth()`.
    public var paddingRight: Double = 0
    /// Vertical position of the rest line or symbols, expressed as stave lines. Default: 2.
    public var line: Double = 2
    /// Defaults to the number of vertical pixels between stave lines.
    public var spacingBetweenLinesPx: Double = Tables.STAVE_LINE_DISTANCE
    /// Size of the semibreve (1-bar) rest symbol.
    public var semibreveRestGlyphScale: Double
    /// Thickness of the rest line. Used when `useSymbols` is false.
    public var lineThickness: Double = 5
    /// Thickness of the rest line's serif. Used when `useSymbols` is false.
    public var serifThickness: Double = 2
    public private(set) var hasPaddingLeft: Bool = false
    public private(set) var hasPaddingRight: Bool = false
    public private(set) var hasLineThickness: Bool = false
    public private(set) var hasSymbolSpacing: Bool = false
    /// True when `numberGlyphPoint` was given.
    public private(set) var hasNumberGlyphPoint: Bool = false

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
        semibreveRestGlyphScale: Double? = nil,
        lineThickness: Double? = nil,
        serifThickness: Double = 2
    ) {
        self.numberOfMeasures = numberOfMeasures
        self.useSymbols = useSymbols
        self.symbolSpacing = symbolSpacing ?? 0
        self.showNumber = showNumber
        self.numberLine = numberLine
        // same as TimeSignature.
        self.numberGlyphPoint = numberGlyphPoint ?? Metrics.getDouble("MultiMeasureRest.fontSize", 30)
        self.paddingLeft = paddingLeft ?? 0
        self.paddingRight = paddingRight ?? 0
        self.line = line
        self.spacingBetweenLinesPx = spacingBetweenLinesPx
        // same as NoteHead.
        self.semibreveRestGlyphScale = semibreveRestGlyphScale ?? Metrics.getDouble("fontSize", 30)
        self.lineThickness = lineThickness ?? 5
        self.serifThickness = serifThickness
        self.hasPaddingLeft = paddingLeft != nil
        self.hasPaddingRight = paddingRight != nil
        self.hasLineThickness = lineThickness != nil
        self.hasSymbolSpacing = symbolSpacing != nil
        self.hasNumberGlyphPoint = numberGlyphPoint != nil
    }
}

// MARK: - MultiMeasureRest

/// Renders a multi-measure rest with a horizontal bar (H-bar glyphs)
/// or symbol glyphs (1-bar, 2-bar, 4-bar rest symbols), plus a measure count.
public final class MultiMeasureRest: VexElement {

    override public class var category: String { "MultiMeasureRest" }

    // MARK: - Properties

    public var renderOptions: MultiMeasureRestRenderOptions
    public var xs: (left: Double, right: Double) = (left: .nan, right: .nan)
    public var numberOfMeasures: Int
    public private(set) var stave: Stave?
    public private(set) var initError: MultiMeasureRestError?

    private let hasPaddingLeft: Bool
    private let hasPaddingRight: Bool
    private let hasLineThickness: Bool
    private let hasSymbolSpacing: Bool

    @available(*, deprecated, renamed: "renderOptions")
    public var renderOpts: MultiMeasureRestRenderOptions {
        get { renderOptions }
        set { renderOptions = newValue }
    }

    // MARK: - Init

    /// - Parameters:
    ///   - numberOfMeasures: Number of measures.
    ///   - options: The options object.
    public init(numberOfMeasures: Int, options: MultiMeasureRestRenderOptions) {
        let fontSize = options.numberGlyphPoint
        self.numberOfMeasures = numberOfMeasures

        // Keep track of whether these four options were provided.
        self.hasPaddingLeft = options.hasPaddingLeft
        self.hasPaddingRight = options.hasPaddingRight
        self.hasLineThickness = options.hasLineThickness
        self.hasSymbolSpacing = options.hasSymbolSpacing

        self.renderOptions = options

        if numberOfMeasures <= 0 {
            self.initError = .invalidMeasureCount(numberOfMeasures)
        }

        super.init(category: nil)

        fontInfo.size = "\(formatJSNumber(fontSize))pt"

        var txt = ""
        for digit in "\(numberOfMeasures)" {
            // 0xe080 is timeSig0. We calculate the code point for timeSigN to assemble the digits via SMuFL glyphs.
            if let value = digit.wholeNumberValue, let scalar = Unicode.Scalar(0xE080 + UInt32(value)) {
                txt += String(Character(scalar))
            }
        }
        text = txt
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
        self.stave = stave
        return self
    }

    public func getStave() -> Stave? { stave }

    /// Return the stave, or a dummy stave. Use `checkStaveThrowing()` for the upstream error.
    public func checkStave() -> Stave {
        (try? checkStaveThrowing()) ?? Stave(x: 0, y: 0, width: 0)
    }

    public func checkStaveThrowing() throws -> Stave {
        guard let stave else {
            throw MultiMeasureRestError.noStave
        }
        return stave
    }

    // MARK: - Draw Line

    public func drawLine(_ stave: Stave, _ ctx: RenderContext, _ left: Double, _ right: Double) throws {
        let options = renderOptions

        let y = stave.getYForLine(options.line)
        let padding = (right - left) * 0.1
        let left = left + padding
        let right = right - padding
        var txt = "\u{E4EF}" /*restHBarLeft*/
        let el = VexElement()
        el.setText(txt)
        // Add middle bars until the right padding is reached
        let elWidth = el.getWidth()
        if elWidth == 0 || elWidth.isNaN {
            throw MultiMeasureRestError.zeroWidthLine
        }
        var i = 1
        while Double(i + 2) * elWidth + left <= right {
            txt += "\u{E4F0}" /*restHBarMiddle*/
            i += 1
        }
        txt += "\u{E4F1}" /*restHBarRight*/

        el.setText(txt)
        el.renderText(ctx, xPos: left + (right - left) * 0.5 - el.getWidth() * 0.5, yPos: y)
    }

    // MARK: - Draw Symbols

    public func drawSymbols(_ stave: Stave, _ ctx: RenderContext, _ left: Double, _ right: Double) {
        let n4 = numberOfMeasures / 4
        let n = numberOfMeasures % 4
        let n2 = n / 2
        let n1 = n % 2

        let options = renderOptions

        let elMiddle = VexElement()
        var txt = ""
        for _ in 0..<max(0, n4) {
            txt += Glyphs.restLonga + " "
        }
        for _ in 0..<max(0, n2) {
            txt += Glyphs.restDoubleWhole + " "
        }
        elMiddle.setText(txt)
        let elTop = VexElement()
        txt = ""
        for _ in 0..<max(0, n1) {
            txt += Glyphs.restWhole + " "
        }
        elTop.setText(txt)

        let width = elMiddle.getWidth() + elTop.getWidth()
        var x = left + (right - left) * 0.5 - width * 0.5
        let line = options.line
        let yTop = stave.getYForLine(line - 1)
        let yMiddle = stave.getYForLine(line)

        elMiddle.renderText(ctx, xPos: x, yPos: yMiddle)
        x += elMiddle.getWidth()
        elTop.renderText(ctx, xPos: x, yPos: yTop)
        x += elTop.getWidth()
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        let stave = try checkStaveThrowing()

        var left = stave.getNoteStartX()
        var right = stave.getNoteEndX()

        // FIXME: getNoteStartX() returns x + 5(barline width)
        //        getNoteEndX() returns x + width(no barline width)
        // See Stave constructor. How do we fix this?
        // Here, we subtract the barline width.
        let begModifiers = stave.getModifiers(position: .begin)
        if begModifiers.count == 1 && begModifiers[0] is Barline {
            left -= begModifiers[0].getWidth()
        }

        let options = renderOptions
        if hasPaddingLeft {
            left = stave.getX() + options.paddingLeft
        }
        if hasPaddingRight {
            right = stave.getX() + stave.getWidth() - options.paddingRight
        }

        xs.left = left
        xs.right = right

        if options.useSymbols {
            drawSymbols(stave, ctx, left, right)
        } else {
            try drawLine(stave, ctx, left, right)
        }

        if options.showNumber {
            renderText(
                ctx,
                xPos: left + (right - left) * 0.5 - width * 0.5,
                yPos: stave.getYForLine(options.numberLine) - height * 0.5
            )
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
