// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// Co-author: Benjamin W. Bohl
//
// Port of `src/clef.ts` (VexFlow 5.9.0).
// Select, position, and measure native clef glyphs against their attached stave.

import Foundation

// MARK: - Clef Type Definition

/// A clef glyph code (SMuFL code point string) and the default stave line.
public struct ClefType: Sendable {
    public var code: String
    public var line: Double

    public init(code: String, line: Double) {
        self.code = code
        self.line = line
    }
}

public enum ClefSize: String, Sendable {
    case `default` = "default"
    case small = "small"
}

public enum ClefAnnotation: String, Sendable {
    case octaveUp = "8va"
    case octaveDown = "8vb"
    /// Two octaves up (`15ma`). (VexFlow 5.8.0)
    case doubleOctaveUp = "15ma"
    /// Two octaves down (`15mb`). (VexFlow 5.8.0)
    case doubleOctaveDown = "15mb"
}

/// Octave annotations share the G- or F-clef anchor, including clefs on nonstandard lines. (VexFlow 5.8.0)
private let octaveGlyphs: [String: [ClefAnnotation: String]] = [
    Glyphs.gClef: [
        .octaveUp: Glyphs.gClef8va,
        .octaveDown: Glyphs.gClef8vb,
        .doubleOctaveUp: Glyphs.gClef15ma,
        .doubleOctaveDown: Glyphs.gClef15mb,
    ],
    Glyphs.fClef: [
        .octaveUp: Glyphs.fClef8va,
        .octaveDown: Glyphs.fClef8vb,
        .doubleOctaveUp: Glyphs.fClef15ma,
        .doubleOctaveDown: Glyphs.fClef15mb,
    ],
]

/// These composite glyphs can have annotation ink outside their advance. (VexFlow 5.8.0)
private let doubleOctaveGlyphs: Set<String> = [Glyphs.gClef15ma, Glyphs.gClef15mb, Glyphs.fClef15ma, Glyphs.fClef15mb]

// MARK: - Clef

/// Clef implements various types of clefs that can be rendered on a stave.
public final class Clef: StaveModifier {

    /// To enable logging for this class, set `Clef.DEBUG` to `true`.
    nonisolated(unsafe) public static var DEBUG: Bool = false

    override public class var category: String { "Clef" }

    // MARK: - Clef Types

    /// Every clef name is associated with a glyph code from the font file
    /// and a default stave line number.
    public static var types: [ClefName: ClefType] {
        [
            .kievan: ClefType(code: Glyphs.kievanCClef, line: 2),
            .chantC: ClefType(code: Glyphs.chantCclef, line: 1),
            .chantF: ClefType(code: Glyphs.chantFclef, line: 2),
            .treble: ClefType(code: Glyphs.gClef, line: 3),
            .bass: ClefType(code: Glyphs.fClef, line: 1),
            .alto: ClefType(code: Glyphs.cClef, line: 2),
            .tenor: ClefType(code: Glyphs.cClef, line: 1),
            .percussion: ClefType(code: Glyphs.unpitchedPercussionClef1, line: 2),
            .soprano: ClefType(code: Glyphs.cClef, line: 4),
            .mezzoSoprano: ClefType(code: Glyphs.cClef, line: 3),
            .baritoneC: ClefType(code: Glyphs.cClef, line: 0),
            .baritoneF: ClefType(code: Glyphs.fClef, line: 2),
            .subbass: ClefType(code: Glyphs.fClef, line: 0),
            .french: ClefType(code: Glyphs.gClef, line: 4),
            .tab: ClefType(code: Glyphs.sixStringTabClef, line: 2.5),
        ]
    }

    // MARK: - Properties

    /// The glyph code of the clef.
    public var code: String = Glyphs.gClef
    /// The default stave line of the clef.
    public var line: Double = 3

    public internal(set) var size: ClefSize = .default
    public internal(set) var type: ClefName = .treble

    // MARK: - Init

    /// Create a new clef.
    public init(type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) {
        super.init()

        setPosition(.begin)
        setType(type, size: size, annotation: annotation)
        if Clef.DEBUG { print("VexFlow.Clef", "Creating clef:", type.rawValue) }
    }

    /// Create a clef from a clef name string (for example `"treble"`). Return nil for unknown names.
    public convenience init?(parsing type: String, size: String = "default", annotation: String? = nil) {
        guard let clefName = ClefName(parsing: type) else { return nil }
        self.init(
            type: clefName,
            size: ClefSize(rawValue: size) ?? .default,
            annotation: annotation.flatMap(ClefAnnotation.init(rawValue:))
        )
    }

    // MARK: - Methods

    /// Return the named clef so staff attachments can retain musical state. (VexFlow 5.2.0)
    public func getType() -> ClefName { type }

    /// Set clef type, size and annotation.
    @discardableResult
    public func setType(_ type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        self.type = type
        let clefType = Clef.types[type] ?? ClefType(code: Glyphs.gClef, line: 3)
        code = clefType.code
        line = clefType.line
        self.size = size

        // Octave clefs use complete SMuFL glyphs at the ordinary written-pitch anchor.
        if let annotation {
            code = octaveGlyphs[code]?[annotation] ?? code
        }
        text = code
        fontInfo.size = "\(formatJSNumber(floor(Clef.getPoint(self.size))))pt"

        if let stave, type == .tab { setStave(stave) }
        return self
    }

    /// Swift alias of `setType(_:size:annotation:)`.
    @discardableResult
    public func setClefType(_ type: ClefName, size: ClefSize = .default, annotation: ClefAnnotation? = nil) -> Self {
        setType(type, size: size, annotation: annotation)
    }

    /// Get point for clefs.
    public static func getPoint(_ size: ClefSize?) -> Double {
        // for sizes other than 'default', clef is 2/3 of the default value
        let fontSize = Metrics.getDouble("fontSize", 30)
        return size == .default ? fontSize : (fontSize * 2) / 3
    }

    /// Set associated stave.
    @discardableResult
    override public func setStave(_ stave: Stave) -> Self {
        super.setStave(stave)
        guard type == .tab else { return self }

        // VexFlow 5.6.1: select the TAB glyph for the string count and fit it between the outer strings.
        let strings = stave.getNumLines()
        code = strings == 4 ? Glyphs.fourStringTabClef : Glyphs.sixStringTabClef
        text = code
        let spaces = max(0, strings - 1)
        line = Double(spaces) / 2
        setFontSize(floor(Clef.getPoint(size)))
        // A single string has a center but no vertical span to fit.
        if spaces == 0 { return self }

        // Measure the selected music face before fitting its ink between the outer strings.
        let reference = Clef.getPoint(.default)
        fontInfo.size = "\(formatJSNumber(reference))pt"
        let metrics = measureText()
        let inkHeight = metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent
        if inkHeight > 0 {
            let lineWidth = stave.getStyle()?.lineWidth ?? 1
            let span = stave.space(Double(spaces))
            // Keep a stroke width plus 1/24 of the full span clear at each end.
            let clearance = lineWidth + span / 24
            let height = max(1, span - lineWidth - 2 * clearance)
            let targetHeight = (height * Clef.getPoint(size)) / reference
            let points = (reference * targetHeight) / inkHeight
            setFontSize(points)
            // Font hinting can round ink outwards at the fitted size. Allow one pixel for that rounding.
            let fitted = getTextMetrics()
            let fittedHeight = fitted.actualBoundingBoxAscent + fitted.actualBoundingBoxDescent
            if fittedHeight > targetHeight + 0.5 {
                setFontSize((points * max(1, targetHeight - 1)) / fittedHeight)
            }
        }
        return self
    }

    /// Baseline shared by drawing and hit testing. TAB fonts can have asymmetric ink. (VexFlow 5.6.1)
    public func getGlyphY() throws -> Double {
        let stave = try checkStaveThrowing()
        if type != .tab { return stave.getYForLine(line) }
        let metrics = textMetrics
        return stave.getYForDrawnLine(line) + (metrics.actualBoundingBoxAscent - metrics.actualBoundingBoxDescent) / 2
    }

    /// Positioned glyph ink, including an octave annotation if present. (VexFlow 5.4.0)
    public func getInkBounds() throws -> BoundingBox {
        getTextInk(getX(), try getGlyphY())
    }

    /// The "15" can extend beyond the advance width in some fonts. Include its actual ink in hit testing.
    /// (VexFlow 5.8.0)
    override public func getBoundingBox() -> BoundingBox? {
        if stave != nil && doubleOctaveGlyphs.contains(code), let ink = try? getInkBounds() {
            return ink
        }
        return super.getBoundingBox()
    }

    // MARK: - Draw

    /// Render clef.
    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let ctx = try stave.checkContext()
        setRendered()

        _ = ctx.openGroup(groupClass("clef"), getAttribute("id"))

        y = try getGlyphY()
        renderText(ctx, xPos: 0, yPos: 0)
        drawPointerRect()
        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Clef", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 150)
        _ = s1.addClef(.treble)

        let s2 = f.Stave(x: 170, y: 20, width: 150)
        _ = s2.addClef(.bass)

        let s3 = f.Stave(x: 330, y: 20, width: 150)
        _ = s3.addClef(.alto)

        try? f.draw()
    }
    .padding()
}
#endif
