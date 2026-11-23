// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/timesignature.ts` (VexFlow 5.3.0).
// Implements time signature glyphs for staves.

import Foundation

// MARK: - TimeSignature

/// A TimeSignature is a StaveModifier that makes its glyphs directly from a
/// provided `timeSpec` such as "4/4", "C|" (cut time), or even something more
/// advanced such as "3/4(6/8)" or "2/4+5/8".
///
/// Numeric time signatures use two text elements (`topText` and `botText`)
/// with the SMuFL digits `timeSig0` (U+E080) + N.
public final class TimeSignature: StaveModifier {

    override public class var category: String { "TimeSignature" }

    // MARK: - Properties

    /// `bottomLine` and `topLine` are used to calculate the position of the
    /// top row of digits in a numeric TimeSignature.
    public var bottomLine: Double
    public var topLine: Double

    public private(set) var timeSpec: TimeSignatureSpec = .default
    public var line: Double = 0
    public let topText: VexElement
    public let botText: VexElement
    public var isNumeric: Bool = true
    public let validateArgs: Bool
    public private(set) var topStartX: Double = 0
    public private(set) var botStartX: Double = 0
    public private(set) var lineShift: Double = 0
    /// Vertical positions of the top and bottom digits, set by `drawAt()`. Used for
    /// the bounding box. (VexFlow 5.1.0)
    public private(set) var topRenderY: Double = 0
    public private(set) var botRenderY: Double = 0

    // MARK: - Init

    public init(timeSpec: TimeSignatureSpec = .default, customPadding: Double = 15, validateArgs: Bool = true) {
        self.topText = VexElement()
        self.botText = VexElement()
        self.validateArgs = validateArgs

        let padding = customPadding

        self.topLine = 1
        self.bottomLine = 3
        super.init()
        setPosition(.begin)
        setTimeSig(timeSpec)
        setPadding(padding)
    }

    /// Create a time signature from a string spec. Return nil for an invalid spec.
    public convenience init?(parsing timeSpec: String, customPadding: Double = 15, validateArgs: Bool = true) {
        guard let spec = TimeSignatureSpec(parsing: timeSpec, validate: validateArgs) else { return nil }
        self.init(timeSpec: spec, customPadding: customPadding, validateArgs: validateArgs)
    }

    // MARK: - Glyph Codes

    /// Return the glyph code for a time signature character (`C`, `C|`, `+`, `-`, `(`, `)` or a digit).
    public static func getTimeSigCode(_ key: String, smallSig: Bool = false) -> String {
        switch key {
        case "C":
            return Glyphs.timeSigCommon
        case "C|":
            return Glyphs.timeSigCutCommon
        case "+":
            return smallSig ? Glyphs.timeSigPlusSmall : Glyphs.timeSigPlus
        case "-":
            return Glyphs.timeSigMinus
        case "(":
            return smallSig ? Glyphs.timeSigParensLeftSmall : Glyphs.timeSigParensLeft
        case ")":
            return smallSig ? Glyphs.timeSigParensRightSmall : Glyphs.timeSigParensRight
        default:
            // timeSigN = Glyphs.timeSig0 + N. JavaScript `Number(' ')` is 0.
            guard let first = key.first else { return Glyphs.null }
            let digit: UInt32
            if let value = first.wholeNumberValue, first.isASCII {
                digit = UInt32(value)
            } else if first == " " {
                digit = 0
            } else {
                return Glyphs.null
            }
            guard let scalar = Unicode.Scalar(0xE080 + digit) else { return Glyphs.null }
            return String(Character(scalar))
        }
    }

    /// Set the top and bottom texts and the width for numeric time signatures.
    public func makeTimeSignatureGlyph(_ topDigits: String, _ botDigits: String) {
        var txt = ""
        var topWidth: Double = 0
        var height: Double = 0
        for ch in topDigits {
            let code = TimeSignature.getTimeSigCode(String(ch), smallSig: !botDigits.isEmpty)
            txt += code
        }
        topText.setText(txt)
        topWidth = topText.getWidth()
        height = topText.getHeight()

        var botWidth: Double = 0
        txt = ""
        for ch in botDigits {
            let code = TimeSignature.getTimeSigCode(String(ch), smallSig: true)
            txt += code
        }
        botText.setText(txt)
        botWidth = botText.getWidth()
        height = max(height, botText.getHeight())

        // If the height of the digits is more than three staff spaces (30), shift half a line line
        // in order to center the digits on lines 1.5 and 4.5 rather than 2 and 4.
        lineShift = height > 30 ? 0.5 : 0

        width = max(topWidth, botWidth)
        topStartX = (width - topWidth) / 2.0
        botStartX = (width - botWidth) / 2.0
    }

    // MARK: - Methods

    /// Apply one family to common-time glyphs and both numeric rows, then remeasure. (VexFlow 5.3.0)
    @discardableResult
    public func setMusicFont(_ family: String) -> Self {
        for element in [self, topText, botText] as [VexElement] {
            var font = element.fontInfo
            font.family = family
            element.setFont(font)
        }
        return setTimeSig(timeSpec)
    }

    /// Set a new time signature specification without changing customPadding, etc.
    ///
    /// The getter for this is `getTimeSpec` not `getTimeSig`.
    @discardableResult
    public func setTimeSig(_ timeSpec: TimeSignatureSpec) -> Self {
        self.timeSpec = timeSpec
        switch timeSpec {
        case .symbol(let symbol):
            let code = TimeSignature.getTimeSigCode(symbol.rawValue)
            line = 2
            text = code
            isNumeric = false
        case .numeric(let top, let bottom):
            line = 0
            isNumeric = true
            makeTimeSignatureGlyph(top.rawValue, bottom.rawValue)
        case .topOnly(let top):
            line = 0
            isNumeric = true
            makeTimeSignatureGlyph(top.rawValue, "")
        case .bottomOnly(let bottom):
            line = 0
            isNumeric = true
            makeTimeSignatureGlyph("", bottom.rawValue)
        }
        return self
    }

    /// Return the timeSpec (such as '4/4' or 'C|' or even '2/4+3/8') of the TimeSignature.
    public func getTimeSpec() -> TimeSignatureSpec { timeSpec }

    /// The time spec as a string.
    public func getTimeSpecString() -> String { timeSpec.rawValue }

    /// Return the staff line that the TimeSignature sits on. Generally 0 for numerator/
    /// denominator time signatures such as 3/4 and 2 for cut/common.
    public func getLine() -> Double { line }

    /// Set the line number that the TimeSignature sits on. Half-values are acceptable
    /// for spaces, etc.
    public func setLine(_ line: Double) { self.line = line }

    /// Return true if this TimeSignature is drawn with one or more numbers
    /// (such as 4/4) and not a symbol (as in cut time).
    public func getIsNumeric() -> Bool { isNumeric }

    /// Set whether this TimeSignature is drawn with one or more numbers.
    public func setIsNumeric(_ isNumeric: Bool) { self.isNumeric = isNumeric }

    // MARK: - Draw

    /// Draw the time signature on a Stave using its RenderContext. Both setStave
    /// and setContext must already be run.
    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let ctx = try stave.checkContext()
        setRendered()
        _ = ctx.openGroup(groupClass("timesignature"), getAttribute("id"))
        drawAt(ctx, stave, x)
        drawPointerRect()
        ctx.closeGroup()
    }

    public func drawAt(_ ctx: RenderContext, _ stave: Stave, _ x: Double) {
        setRendered()

        if isNumeric {
            // render top text
            var startX = x + topStartX
            if !botText.getText().isEmpty {
                topRenderY = stave.getYForLine(topLine - lineShift)
            } else {
                topRenderY = (stave.getYForLine(topLine) + stave.getYForLine(bottomLine)) / 2
            }
            topText.renderText(ctx, xPos: startX, yPos: topRenderY)

            // render bottom text
            startX = x + botStartX
            botRenderY = stave.getYForLine(bottomLine + lineShift)
            botText.renderText(ctx, xPos: startX, yPos: botRenderY)
        } else {
            renderText(ctx, xPos: x - self.x, yPos: stave.getYForLine(line))
        }
    }

    /// Combined bounding box of the time signature. Call it after `drawAt()`, which
    /// sets the vertical positions of a numeric signature. (VexFlow 5.1.0)
    override public func getBoundingBox() -> BoundingBox? {
        if isNumeric {
            guard var topBoundingBox = topText.getBoundingBox(),
                  var botBoundingBox = botText.getBoundingBox() else { return nil }
            // Move the boxes to the positions of the text rendered by drawAt().
            topBoundingBox.move(x + topStartX, topRenderY)
            botBoundingBox.move(x + botStartX, botRenderY)
            topBoundingBox.mergeWith(botBoundingBox)
            return topBoundingBox
        }
        // Simple text (like "C" or "C|"): the element bounding box.
        guard var textBoundingBox = super.getBoundingBox(), let stave = getStave() else { return nil }
        textBoundingBox.move(0, stave.getYForLine(line))
        return textBoundingBox
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("TimeSignature", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 150)
        _ = s1.addClef(.treble).addTimeSignature(.meter(4, 4))

        let s2 = f.Stave(x: 170, y: 20, width: 150)
        _ = s2.addClef(.treble).addTimeSignature(.meter(3, 4))

        let s3 = f.Stave(x: 330, y: 20, width: 150)
        _ = s3.addClef(.treble).addTimeSignature(.meter(6, 8))

        try? f.draw()
    }
    .padding()
}
#endif
