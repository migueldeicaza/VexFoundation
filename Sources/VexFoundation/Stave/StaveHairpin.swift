// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Raffaele Viglianti, 2012 http://itisnotsound.wordpress.com/
//
// Port of `src/stavehairpin.ts` (VexFlow 5.4.0).
// This class implements hairpins between notes.
// Hairpins can be either crescendo or decrescendo.

import Foundation

public enum StaveHairpinError: Error, LocalizedError, Equatable, Sendable {
    case requiresStartOrEndNote
    case requiresBothNotesForDraw

    public var errorDescription: String? {
        switch self {
        case .requiresStartOrEndNote:
            return "Hairpin needs to have either firstNote or lastNote set."
        case .requiresBothNotesForDraw:
            return "Notes required to draw"
        }
    }
}

// MARK: - Hairpin Type

public enum HairpinType: Int, Sendable {
    case crescendo = 1
    case decrescendo = 2
}

// MARK: - Hairpin Render Options

public struct HairpinRenderOptions {
    public var rightShiftTicks: Double?
    public var leftShiftTicks: Double?
    public var leftShiftPx: Double
    public var rightShiftPx: Double
    public var height: Double
    public var yShift: Double

    public init(
        leftShiftPx: Double = 0,
        rightShiftPx: Double = 0,
        height: Double = 10,
        yShift: Double = 0,
        rightShiftTicks: Double? = 0,
        leftShiftTicks: Double? = 0
    ) {
        self.leftShiftPx = leftShiftPx
        self.rightShiftPx = rightShiftPx
        self.height = height
        self.yShift = yShift
        self.rightShiftTicks = rightShiftTicks
        self.leftShiftTicks = leftShiftTicks
    }
}

/// Upstream name of the render options.
public typealias StaveHairpinRenderOptions = HairpinRenderOptions

// MARK: - StaveHairpin

/// Renders crescendo and decrescendo hairpins between two notes.
public final class StaveHairpin: VexElement {

    override public class var category: String { "StaveHairpin" }

    // MARK: - Properties

    public var hairpin: HairpinType
    public private(set) var position: ModifierPosition = .below
    public var renderOptions: HairpinRenderOptions
    public var firstNote: Note?
    public var lastNote: Note?
    public private(set) var initError: StaveHairpinError?

    @available(*, deprecated, renamed: "hairpin")
    public var hairpinType: HairpinType {
        get { hairpin }
        set { hairpin = newValue }
    }

    @available(*, deprecated, renamed: "position")
    public var hairpinPosition: ModifierPosition { position }

    // MARK: - Format By Ticks

    /// Helper function to convert ticks into pixels.
    /// Requires a Formatter with voices joined and formatted (to get pixels per tick).
    /// Upstream takes `formatter: { pixelsPerTick }`; pass the value here.
    ///
    /// `options` has `height`, `yShift` (vertical offset), `leftShiftTicks` (left
    /// horizontal offset expressed in ticks) and `rightShiftTicks` (right horizontal
    /// offset expressed in ticks).
    public static func FormatByTicksAndDraw(
        _ ctx: RenderContext,
        pixelsPerTick: Double,
        firstNote: Note?,
        lastNote: Note?,
        type: HairpinType,
        position: ModifierPosition,
        options: HairpinRenderOptions
    ) throws {
        let ppt = pixelsPerTick
        if ppt.isNaN {
            throw VexError("BadArguments", "A valid Formatter must be provide to draw offsets by ticks.")
        }

        let leftShiftPx = ppt * (options.leftShiftTicks ?? 0)
        let rightShiftPx = ppt * (options.rightShiftTicks ?? 0)

        let hairpinOptions = HairpinRenderOptions(
            leftShiftPx: leftShiftPx,
            rightShiftPx: rightShiftPx,
            height: options.height,
            yShift: options.yShift,
            rightShiftTicks: 0,
            leftShiftTicks: 0
        )

        try StaveHairpin(validating: firstNote, lastNote: lastNote, type: type)
            .setContext(ctx)
            .setRenderOptions(hairpinOptions)
            .setPosition(position)
            .drawWithStyle()
    }

    // MARK: - Init

    /// Create a new hairpin from the specified notes.
    public init(firstNote: Note?, lastNote: Note?, type: HairpinType) {
        self.hairpin = type
        self.renderOptions = HairpinRenderOptions(
            leftShiftPx: 0, // left horizontal offset
            rightShiftPx: 0, // right horizontal offset
            height: 10,
            yShift: 0, // vertical offset
            rightShiftTicks: 0,
            leftShiftTicks: 0
        )
        super.init(category: nil)
        do {
            _ = try setNotesThrowing(firstNote: firstNote, lastNote: lastNote)
        } catch {
            initError = .requiresStartOrEndNote
        }
        position = .below
    }

    public convenience init(validating firstNote: Note?, lastNote: Note?, type: HairpinType) throws {
        self.init(firstNote: firstNote, lastNote: lastNote, type: type)
        if let initError {
            throw initError
        }
    }

    // MARK: - Setters

    @discardableResult
    public func setPosition(_ position: ModifierPosition) -> Self {
        if position == .above || position == .below {
            self.position = position
        }
        return self
    }

    @discardableResult
    public func setRenderOptions(_ options: HairpinRenderOptions) -> Self {
        renderOptions = options
        return self
    }

    /// Set the notes to attach this hairpin to. Invalid input is ignored.
    @discardableResult
    public func setNotes(firstNote: Note?, lastNote: Note?) -> Self {
        _ = try? setNotesThrowing(firstNote: firstNote, lastNote: lastNote)
        return self
    }

    /// Set the notes to attach this hairpin to.
    @discardableResult
    public func setNotesThrowing(firstNote: Note?, lastNote: Note?) throws -> Self {
        if firstNote == nil && lastNote == nil {
            throw StaveHairpinError.requiresStartOrEndNote
        }

        self.firstNote = firstNote
        self.lastNote = lastNote
        return self
    }

    // MARK: - Layout (VexFlow 5.4.0)

    /// Both endpoints are required for a complete wedge on a single system.
    public func getNotes() -> [Note?] {
        [firstNote, lastNote]
    }

    private var layoutBaseline: Double?
    private var layoutLeft: Double = 0
    private var layoutRight: Double = 0

    /// A phrase baseline passes through the middle of the wedge; trims clear adjacent dynamics.
    public func setLayoutBaseline(_ y: Double?, _ left: Double = 0, _ right: Double = 0) {
        layoutBaseline = y
        layoutLeft = left
        layoutRight = right
    }

    private struct Parameters {
        var firstX: Double
        var lastX: Double
        var firstY: Double
        var lastY: Double
        var staffHeight: Double
    }

    private func parameters() throws -> Parameters {
        guard let first = firstNote, let last = lastNote else {
            throw StaveHairpinError.requiresBothNotesForDraw
        }
        let firstStave = try first.checkStaveThrowing()
        let lastStave = try last.checkStaveThrowing()
        return Parameters(
            firstX: first.getModifierStartXY(position: position, index: 0).x,
            lastX: last.getModifierStartXY(position: position, index: 0).x,
            firstY: firstStave.getY() + firstStave.getHeight(),
            lastY: lastStave.getY() + lastStave.getHeight(),
            staffHeight: firstStave.getHeight()
        )
    }

    /// Wedge edges: `top` and `height` of the opening, `left` and `right` of the tips.
    public struct LayoutEdges: Equatable, Sendable {
        public var top: Double
        public var left: Double
        public var right: Double
        public var height: Double
    }

    private func edges(firstX: Double, lastX: Double, firstY: Double, staffHeight: Double) -> LayoutEdges {
        let yShift = renderOptions.yShift
        let height = renderOptions.height
        let above = position == .above
        let top: Double
        if let layoutBaseline {
            top = layoutBaseline - height / 2 + (above ? -yShift : yShift)
        } else {
            top = firstY + (above ? 10 - staffHeight - yShift : 20 + yShift)
        }
        return LayoutEdges(
            top: top,
            left: firstX + renderOptions.leftShiftPx + layoutLeft,
            right: lastX + renderOptions.rightShiftPx - layoutRight,
            height: height
        )
    }

    /// Signed endpoint order is available to diagnose a wedge squeezed between two dynamics.
    public func getLayoutEdges() throws -> LayoutEdges {
        let p = try parameters()
        return edges(firstX: p.firstX, lastX: p.lastX, firstY: p.firstY, staffHeight: p.staffHeight)
    }

    override public func getBoundingBox() -> BoundingBox? {
        guard let e = try? getLayoutEdges() else { return nil }
        let pad = (getStyle()?.lineWidth ?? 1) / 2
        return BoundingBox(
            min(e.left, e.right) - pad,
            min(e.top, e.top + e.height) - pad,
            abs(e.right - e.left) + 2 * pad,
            abs(e.height) + 2 * pad
        )
    }

    // MARK: - Render

    public func renderHairpin(firstX: Double, lastX: Double, firstY: Double, lastY: Double,
                              staffHeight: Double) throws {
        let ctx = try checkContext()
        let e = edges(firstX: firstX, lastX: lastX, firstY: firstY, staffHeight: staffHeight)
        ctx.beginPath()

        switch hairpin {
        case .crescendo:
            ctx.moveTo(e.right, e.top)
            ctx.lineTo(e.left, e.top + e.height / 2)
            ctx.lineTo(e.right, e.top + e.height)
        case .decrescendo:
            ctx.moveTo(e.left, e.top)
            ctx.lineTo(e.right, e.top + e.height / 2)
            ctx.lineTo(e.left, e.top + e.height)
        }

        ctx.stroke()
        ctx.closePath()
    }

    // MARK: - Draw

    override public func draw() throws {
        _ = try checkContext()
        setRendered()
        let p = try parameters()
        try renderHairpin(
            firstX: p.firstX, lastX: p.lastX, firstY: p.firstY, lastY: p.lastY, staffHeight: p.staffHeight
        )
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StaveHairpin", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 150) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()

        let hp = StaveHairpin(firstNote: notes[0], lastNote: notes[1], type: .crescendo)
        _ = hp.setContext(ctx)

        let hp2 = StaveHairpin(firstNote: notes[2], lastNote: notes[3], type: .decrescendo)
        _ = hp2.setContext(ctx)

        try? f.draw()
        try? hp.draw()
        try? hp2.draw()
    }
    .padding()
}
#endif
