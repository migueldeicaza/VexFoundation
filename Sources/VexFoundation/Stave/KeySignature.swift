// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. Author: Cyril Silverman. MIT License.

import Foundation

/// Renders key signatures (sharps/flats) on a stave.
public final class KeySignature: StaveModifier {

    override public class var category: String { "KeySignature" }

    // MARK: - Accidental Spacing

    /// Spacing between a natural and the next accidental, based on vertical position.
    public static let accidentalSpacing: [String: (above: Double, below: Double)] = [
        "#": (above: 6, below: 4),
        "b": (above: 4, below: 7),
        "n": (above: 4, below: 1),
        "##": (above: 6, below: 4),
        "bb": (above: 4, below: 7),
        "db": (above: 4, below: 7),
        "d": (above: 4, below: 7),
        "bbs": (above: 4, below: 7),
        "++": (above: 6, below: 4),
        "+": (above: 6, below: 4),
        "+-": (above: 6, below: 4),
        "++-": (above: 6, below: 4),
        "bs": (above: 4, below: 10),
        "bss": (above: 4, below: 10),
    ]

    // MARK: - Properties

    public var glyphFontScale: Double
    public var glyphs: [Glyph] = []
    public var xPositions: [Double] = [0]
    public var paddingForced: Bool = false
    public var formatted: Bool = false
    public var cancelKeySpec: String?
    public var accList: [(type: String, line: Double)] = []
    public var keySpec: String?
    public var alterKeySpec: [String]?

    // MARK: - Init

    public init(keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) {
        self.glyphFontScale = Tables.NOTATION_FONT_SCALE
        super.init()
        setKeySig(keySpec, cancelKeySpec: cancelKeySpec, alterKeySpec: alterKeySpec)
        setPosition(.begin)
    }

    // MARK: - Configuration

    @discardableResult
    public func setKeySig(_ keySpec: String, cancelKeySpec: String? = nil, alterKeySpec: [String]? = nil) -> Self {
        self.formatted = false
        self.keySpec = keySpec
        self.cancelKeySpec = cancelKeySpec
        self.alterKeySpec = alterKeySpec
        return self
    }

    @discardableResult
    public func cancelKey(_ spec: String) -> Self {
        self.formatted = false
        self.cancelKeySpec = spec
        return self
    }

    @discardableResult
    public func alterKey(_ specs: [String]) -> Self {
        self.formatted = false
        self.alterKeySpec = specs
        return self
    }

    /// Mirror VexFlow's `addToStave` behavior where key signatures always
    /// include inter-modifier padding (used by certain upstream tests).
    @discardableResult
    public func addToStave(_ stave: Stave) -> Self {
        paddingForced = true
        _ = stave.addModifier(self)
        return self
    }

    // MARK: - Formatting

    override public func getPadding(_ index: Int) -> Double {
        if !formatted { format() }
        return glyphs.isEmpty || (!paddingForced && index < 2) ? 0 : padding
    }

    override public func getModifierWidth() -> Double {
        if !formatted { format() }
        return modifierWidth
    }

    public func getGlyphs() -> [Glyph] {
        if !formatted { format() }
        return glyphs
    }

    /// Build the glyph array by processing the key, cancel key, and alterations.
    public func format() {
        let stave = checkStave()
        modifierWidth = 0
        glyphs = []
        xPositions = [0]

        guard let keySpec else { formatted = true; return }
        accList = (try? Tables.keySignature(keySpec)) ?? []

        let firstAccType = accList.first?.type

        var cancelResult: (accList: [(type: String, line: Double)], type: String)?
        if let cancelKeySpec {
            cancelResult = convertToCancelAccList(cancelKeySpec)
        }
        if let alterKeySpec {
            convertToAlterAccList(alterKeySpec)
        }

        if !accList.isEmpty {
            let clef: ClefName
            if position == .end {
                clef = stave.getEndClef() ?? stave.getClef()
            } else {
                clef = stave.getClef()
            }

            let cancelCount = cancelResult?.accList.count ?? 0

            if let cancelResult {
                var cancelAccs = cancelResult.accList
                convertAccLines(clef: clef, type: cancelResult.type, accList: &cancelAccs)
                // Update the cancel portion in our accList
                for i in 0..<cancelAccs.count {
                    accList[i] = cancelAccs[i]
                }
            }

            // VexFlow formats cancel accidentals separately from the main list.
            // Only the main segment should receive the second clef conversion.
            var mainAccs = Array(accList.dropFirst(cancelCount))
            convertAccLines(clef: clef, type: firstAccType, accList: &mainAccs)
            for i in 0..<mainAccs.count {
                accList[cancelCount + i] = mainAccs[i]
            }

            for i in 0..<accList.count {
                let nextAcc = i + 1 < accList.count ? accList[i + 1] : nil
                convertToGlyph(acc: accList[i], nextAcc: nextAcc, stave: stave)
            }
        }

        formatted = true
    }

    // MARK: - Internal Conversion

    private func convertToGlyph(
        acc: (type: String, line: Double),
        nextAcc: (type: String, line: Double)?,
        stave: Stave
    ) {
        guard let accCode = Tables.accidentalCode(acc.type) else { return }
        let glyph = Glyph(code: accCode.code, point: glyphFontScale)

        var extraWidth: Double = 1
        if acc.type == "n", let nextAcc {
            if let spacing = KeySignature.accidentalSpacing[nextAcc.type] {
                let isAbove = nextAcc.line >= acc.line
                extraWidth = isAbove ? spacing.above : spacing.below
            }
        }

        placeGlyphOnLine(glyph, stave: stave, line: acc.line)
        glyphs.append(glyph)

        let xPosition = xPositions.last ?? 0
        let glyphWidth = glyph.getMetrics().width + extraWidth
        xPositions.append(xPosition + glyphWidth)
        modifierWidth += glyphWidth
    }

    private func convertToCancelAccList(_ spec: String) -> (accList: [(type: String, line: Double)], type: String)? {
        guard let cancelAccList = try? Tables.keySignature(spec) else { return nil }

        let differentTypes = !accList.isEmpty && !cancelAccList.isEmpty
            && cancelAccList[0].type != accList[0].type

        let naturals = differentTypes ? cancelAccList.count : cancelAccList.count - accList.count
        guard naturals >= 1 else { return nil }

        var cancelled: [(type: String, line: Double)] = []
        for i in 0..<naturals {
            let index = differentTypes ? i : (cancelAccList.count - naturals + i)
            cancelled.append((type: "n", line: cancelAccList[index].line))
        }

        accList = cancelled + accList
        return (accList: cancelled, type: cancelAccList[0].type)
    }

    private func convertAccLines(clef: ClefName, type: String?, accList: inout [(type: String, line: Double)]) {
        var offset: Double = 0
        var customLines: [Double]?

        switch clef {
        case .soprano:
            if type == "#" { customLines = [2.5, 0.5, 2, 0, 1.5, -0.5, 1] }
            else { offset = -1 }
        case .mezzoSoprano:
            if type == "b" { customLines = [0, 2, 0.5, 2.5, 1, 3, 1.5] }
            else { offset = 1.5 }
        case .alto:
            offset = 0.5
        case .tenor:
            if type == "#" { customLines = [3, 1, 2.5, 0.5, 2, 0, 1.5] }
            else { offset = -0.5 }
        case .baritoneF, .baritoneC:
            if type == "b" { customLines = [0.5, 2.5, 1, 3, 1.5, 3.5, 2] }
            else { offset = 2 }
        case .bass, .french:
            offset = 1
        default:
            break
        }

        if let customLines {
            for i in 0..<accList.count where i < customLines.count {
                accList[i].line = customLines[i]
            }
        } else if offset != 0 {
            for i in 0..<accList.count {
                accList[i].line += offset
            }
        }
    }

    private func convertToAlterAccList(_ specs: [String]) {
        let max = min(specs.count, accList.count)
        for i in 0..<max {
            if !specs[i].isEmpty {
                accList[i].type = specs[i]
            }
        }
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        if !formatted { format() }
        setRendered()

        applyStyle(context: ctx)
        _ = ctx.openGroup("keysignature", getAttribute("id"))

        for i in 0..<glyphs.count {
            let glyph = glyphs[i]
            let x = modifierX + xPositions[i]
            glyph.setStave(stave)
            glyph.setContext(ctx)
            glyph.renderToStave(x: x)
        }

        ctx.closeGroup()
        restoreStyle(context: ctx)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("KeySignature", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 240)
        _ = s1.addClef(.treble).addKeySignature("A")

        let s2 = f.Stave(x: 260, y: 20, width: 240)
        _ = s2.addClef(.treble).addKeySignature("Bb")

        try? f.draw()
    }
    .padding()
}
#endif
