// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum StaveModifierError: Error, LocalizedError, Equatable, Sendable {
    case noStave

    public var errorDescription: String? {
        switch self {
        case .noStave:
            return "No stave attached to modifier."
        }
    }
}

// MARK: - Layout Metrics

/// Metrics used for modifier positioning within the stave layout.
public struct LayoutMetrics: Sendable {
    public var xMin: Double
    public var xMax: Double
    public var paddingLeft: Double
    public var paddingRight: Double

    public init(xMin: Double = 0, xMax: Double = 0, paddingLeft: Double = 0, paddingRight: Double = 0) {
        self.xMin = xMin
        self.xMax = xMax
        self.paddingLeft = paddingLeft
        self.paddingRight = paddingRight
    }
}

// MARK: - StaveModifier Position

/// Positions where modifiers can appear on a stave.
public enum StaveModifierPosition: Int, Sendable {
    case center = 0
    case left = 1
    case right = 2
    case above = 3
    case below = 4
    case begin = 5
    case end = 6

    /// Parse from string labels used by compatibility inputs.
    public init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "center":
            self = .center
        case "left":
            self = .left
        case "right":
            self = .right
        case "above", "top":
            self = .above
        case "below", "bottom":
            self = .below
        case "begin", "start":
            self = .begin
        case "end":
            self = .end
        default:
            return nil
        }
    }
}

// MARK: - StaveModifier

/// Base class for all stave modifiers (barlines, clefs, key signatures, time signatures, etc.).
open class StaveModifier: VexElement {

    override open class var category: String { "StaveModifier" }

    // MARK: - Properties

    public var modifierWidth: Double = 0
    public var modifierX: Double = 0
    public var padding: Double = 10
    public var position: StaveModifierPosition = .above
    public weak var stave: Stave?
    public var layoutMetrics: LayoutMetrics?

    // MARK: - Position

    public func getPosition() -> StaveModifierPosition { position }

    @discardableResult
    public func setPosition(_ position: StaveModifierPosition) -> Self {
        self.position = position
        return self
    }

    // MARK: - Stave

    public func getStave() -> Stave? { stave }

    public func checkStave() -> Stave {
        (try? checkStaveThrowing()) ?? Stave(x: 0, y: 0, width: 0)
    }

    public func checkStaveThrowing() throws -> Stave {
        guard let stave else {
            throw StaveModifierError.noStave
        }
        return stave
    }

    @discardableResult
    public func setStave(_ stave: Stave) -> Self {
        self.stave = stave
        return self
    }

    // MARK: - Width

    public func getModifierWidth() -> Double { modifierWidth }

    @discardableResult
    public func setModifierWidth(_ width: Double) -> Self {
        self.modifierWidth = width
        return self
    }

    // MARK: - X Position

    public func getModifierX() -> Double { modifierX }

    @discardableResult
    public func setModifierX(_ x: Double) -> Self {
        self.modifierX = x
        return self
    }

    // MARK: - Padding

    public func getPadding(_ index: Int) -> Double {
        index < 2 ? 0 : padding
    }

    @discardableResult
    public func setPadding(_ padding: Double) -> Self {
        self.padding = padding
        return self
    }

    // MARK: - Layout Metrics

    public func getLayoutMetrics() -> LayoutMetrics? { layoutMetrics }

    @discardableResult
    public func setLayoutMetrics(_ metrics: LayoutMetrics) -> Self {
        self.layoutMetrics = metrics
        return self
    }

    // MARK: - Glyph Placement

    /// Position a glyph on a staff line using Y-shift.
    public func placeGlyphOnLine(_ glyph: Glyph, stave: Stave, line: Double, customShift: Double = 0) {
        glyph.setYShift(stave.getYForLine(line) - stave.getYForGlyphs() + customShift)
    }

    // MARK: - Draw

    /// Subclasses override to perform drawing. Base version calls `drawStave`.
    public func drawStave(stave: Stave, xShift: Double = 0) throws {
        // Default no-op; subclasses override
    }
}
