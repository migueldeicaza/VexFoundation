// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/flutefingering.ts` (VexFlow 5.9.0).
// Draw and measure a note-attached fingering chart for the six main flute keys.

import Foundation

/// The six main flute keys in top-to-bottom reading order, first the left hand and then the right.
/// (VexFlow 5.9.0)
public enum FluteKey: String, CaseIterable, Sendable {
    case l1 = "L1"
    case l2 = "L2"
    case l3 = "L3"
    case r1 = "R1"
    case r2 = "R2"
    case r3 = "R3"
}

/// The state of one flute key. (VexFlow 5.9.0)
public enum FluteKeyState: String, Sendable {
    case open
    case closed

    var opposite: FluteKeyState { self == .open ? .closed : .open }
}

/// One key alternates from its base state to the opposite state and back. (VexFlow 5.9.0)
public struct FluteTrillKey: Equatable, Sendable {
    public let key: FluteKey
    public let start: FluteKeyState
    public let alternate: FluteKeyState

    public init(key: FluteKey, start: FluteKeyState, alternate: FluteKeyState) {
        self.key = key
        self.start = start
        self.alternate = alternate
    }
}

/// A six-key diagram entered as physical finger positions. Omitted keys are open. (VexFlow 5.9.0)
public final class FluteFingering: Annotation {
    private let states: [FluteKey: FluteKeyState]
    private let scale: Double
    private var trillKey: FluteTrillKey?

    /// Throws when `scale` is not positive and finite.
    public init(_ states: [FluteKey: FluteKeyState], scale: Double = 1) throws {
        guard scale.isFinite, scale > 0 else {
            throw VexError("RangeError", "Expected a positive flute diagram scale.")
        }
        self.scale = scale
        var normalized: [FluteKey: FluteKeyState] = [:]
        for key in FluteKey.allCases { normalized[key] = states[key] ?? .open }
        self.states = normalized
        super.init("")
    }

    /// Return all six named states, independent of the score's written pitch.
    public func getKeyStates() -> [FluteKey: FluteKeyState] {
        states
    }

    private func state(_ key: FluteKey) -> FluteKeyState {
        states[key] ?? .open
    }

    /// Mark a moving key while preserving the six underlying finger positions.
    @discardableResult
    public func setTrillKey(_ trill: FluteTrillKey) throws -> Self {
        let base = state(trill.key)
        if trill.start != base {
            throw VexError("RangeError", "Trill on \(trill.key.rawValue) must start \(base.rawValue).")
        }
        if trill.alternate != trill.start.opposite {
            throw VexError("RangeError", "Trill on \(trill.key.rawValue) must alternate to \(trill.start.opposite.rawValue).")
        }
        trillKey = trill
        return self
    }

    /// Read the moving key and the direction of its first movement.
    public func getTrillKey() -> FluteTrillKey? {
        trillKey
    }

    /// Restore all six base symbols on the attached diagram.
    @discardableResult
    public func clearTrillKey() -> Self {
        trillKey = nil
        return self
    }

    /// Describe the visible chart to screen readers.
    public func getDescription() -> String {
        let base = "Flute fingering. "
            + FluteKey.allCases.map { "\($0.rawValue) \(state($0).rawValue)" }.joined(separator: ", ") + "."
        guard let trillKey else { return base }
        return "\(base) Hatched \(trillKey.key.rawValue) trills from \(trillKey.start.rawValue) to \(trillKey.alternate.rawValue) and back."
    }

    /// Include the left-hand labels and the offset right-hand circles in note spacing.
    override public func getWidth() -> Double {
        28 * scale
    }

    /// Allow five key intervals, a larger hand break and the outer edges of the circles.
    override func getLayoutHeight() -> Double {
        64 * scale
    }

    /// Full diagram height in renderer pixels.
    override public func getHeight() -> Double {
        getLayoutHeight()
    }

    /// Use the diagram's lower edge as the baseline for annotation and tuplet layout.
    override public func getTextInk(_ x: Double, _ y: Double) -> BoundingBox {
        let height = getLayoutHeight()
        return BoundingBox(x: x + getXShift(), y: y + getYShift() - height, w: getWidth(), h: height)
    }

    /// Measure the full diagram from its current note position before or after drawing.
    /// `nil` before the diagram is attached to a formatted note (upstream throws).
    override public func getBoundingBox() -> BoundingBox? {
        guard let x = try? computeX().x, let y = try? computeY().y else { return nil }
        return getTextInk(x, y)
    }

    /// Locate any named key after formatting. The right hand starts below and slightly to the right.
    public func getKeyCenter(_ key: FluteKey) throws -> (x: Double, y: Double) {
        guard let index = FluteKey.allCases.firstIndex(of: key) else {
            throw VexError("RangeError", "Unknown flute key: \(key.rawValue).")
        }
        let rightHand = index >= 3
        let box = getTextInk(try computeX().x, try computeY().y)
        return (
            box.x + (rightHand ? 23.5 : 17.5) * scale,
            box.y + (4.5 + 10 * Double(index) + (rightHand ? 5 : 0)) * scale
        )
    }

    /// Stroke every outline and fill closed keys, keeping the outer radius fixed in both states.
    func drawKey(_ ctx: RenderContext, _ key: FluteKey, _ x: Double, _ y: Double, _ radius: Double) {
        ctx.beginPath()
        ctx.arc(x, y, radius, 0, 2 * Double.pi, false)
        let moving = trillKey?.key == key
        if !moving && state(key) == .closed { ctx.fill() }
        ctx.stroke()

        if moving {
            // Two chords inside the circular outline leave a light gap at the center, including at reduced scale.
            ctx.beginPath()
            for offset in [-radius / 3, radius / 3] {
                let halfChord = (radius * radius - offset * offset).squareRoot()
                ctx.moveTo(x - halfChord, y + offset)
                ctx.lineTo(x + halfChord, y + offset)
            }
            ctx.stroke()
        }
    }

    /// Draw the six labeled keys using the same geometry measured by the score.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        let group = ctx.openGroup("flute-fingering", getAttribute("id"))
        (group as? SVGNode)?.setAttribute("role", "img")
        (group as? SVGNode)?.setAttribute("aria-label", getDescription())
        ctx.save()
        ctx.setFont(VexFont.validate(family: "Arial, sans-serif", size: "\(formatJSNumber(8 * scale))px"))
        ctx.setLineWidth(scale)
        for key in FluteKey.allCases {
            let (x, y) = try getKeyCenter(key)
            ctx.fillText(key.rawValue, x - 17.5 * scale, y + 2.8 * scale)
            drawKey(ctx, key, x, y, 4 * scale)
        }
        ctx.restore()
        drawPointerRect()
        ctx.closeGroup()
    }
}
