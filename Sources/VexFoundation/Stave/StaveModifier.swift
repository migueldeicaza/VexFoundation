// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/stavemodifier.ts` (VexFlow 5.0.0).
// A base class for stave modifiers (e.g. clefs, key signatures).

import Foundation

public enum StaveModifierError: Error, LocalizedError, Equatable, Sendable {
    case noStave

    public var errorDescription: String? {
        switch self {
        case .noStave:
            return "No stave attached to instance."
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
///
/// The position (`x`) and the width (`width`) are stored in `VexElement`.
open class StaveModifier: VexElement {

    override open class var category: String { "StaveModifier" }

    public typealias Position = StaveModifierPosition

    // MARK: - Properties

    public var padding: Double = 10
    public var position: StaveModifierPosition = .above
    /// The stave. Weak: the stave holds its modifiers.
    public weak var stave: Stave?
    public var layoutMetrics: LayoutMetrics?

    // MARK: - Init

    public override init() {
        super.init(category: nil)
    }

    // MARK: - Position

    open func getPosition() -> StaveModifierPosition { position }

    @discardableResult
    open func setPosition(_ position: StaveModifierPosition) -> Self {
        self.position = position
        return self
    }

    // MARK: - Stave

    public func getStave() -> Stave? { stave }

    /// Return the stave. If no stave is attached, return a dummy stave.
    /// Use `checkStaveThrowing()` to get the upstream `NoStave` error.
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
    open func setStave(_ stave: Stave) -> Self {
        self.stave = stave
        return self
    }

    // MARK: - Padding

    open func getPadding(_ index: Int) -> Double {
        index < 2 ? 0 : padding
    }

    @discardableResult
    public func setPadding(_ padding: Double) -> Self {
        self.padding = padding
        return self
    }

    // MARK: - Layout Metrics

    @discardableResult
    public func setLayoutMetrics(_ layoutMetrics: LayoutMetrics) -> Self {
        self.layoutMetrics = layoutMetrics
        return self
    }

    public func getLayoutMetrics() -> LayoutMetrics? { layoutMetrics }

    // MARK: - Deprecated 4.x API

    @available(*, deprecated, message: "Use width / getWidth().")
    public var modifierWidth: Double {
        get { getWidth() }
        set { setWidth(newValue) }
    }

    @available(*, deprecated, message: "Use x / getX().")
    public var modifierX: Double {
        get { getX() }
        set { setX(newValue) }
    }

    @available(*, deprecated, renamed: "getWidth()")
    public func getModifierWidth() -> Double { getWidth() }

    @available(*, deprecated, renamed: "setWidth(_:)")
    @discardableResult
    public func setModifierWidth(_ width: Double) -> Self { setWidth(width) }

    @available(*, deprecated, renamed: "getX()")
    public func getModifierX() -> Double { getX() }

    @available(*, deprecated, renamed: "setX(_:)")
    @discardableResult
    public func setModifierX(_ x: Double) -> Self { setX(x) }

    /// 4.x drawing entry point. VexFlow 5 uses `setStave`, `setContext` and `drawWithStyle()`.
    @available(*, deprecated, message: "Use setStave(_:), setContext(_:) and drawWithStyle().")
    public func drawStave(stave: Stave, xShift: Double = 0) throws {
        setStave(stave)
        setContext(try stave.checkContext())
        try drawWithStyle()
    }
}
