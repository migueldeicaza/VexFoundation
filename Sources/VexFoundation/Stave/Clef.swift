// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// Co-author: Benjamin W. Bohl
//
// Port of `src/clef.ts` (VexFlow 5.4.0).

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
}

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

        // If an annotation, such as 8va, is specified, add it to the Clef object.
        if annotation == .octaveUp {
            if code == Glyphs.gClef {
                code = Glyphs.gClef8va
            }
            if code == Glyphs.fClef {
                code = Glyphs.fClef8va
            }
        }
        if annotation == .octaveDown {
            if code == Glyphs.gClef {
                code = Glyphs.gClef8vb
            }
            if code == Glyphs.fClef {
                code = Glyphs.fClef8vb
            }
        }
        text = code
        fontInfo.size = "\(formatJSNumber(floor(Clef.getPoint(self.size))))pt"

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
        self.stave = stave
        return self
    }

    /// Positioned glyph ink, including an octave annotation if present. (VexFlow 5.4.0)
    public func getInkBounds() throws -> BoundingBox {
        let stave = try checkStaveThrowing()
        return getTextInk(getX(), stave.getYForLine(line))
    }

    // MARK: - Draw

    /// Render clef.
    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let ctx = try stave.checkContext()
        setRendered()

        _ = ctx.openGroup(groupClass("clef"), getAttribute("id"))

        y = stave.getYForLine(line)
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
