// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Raffaele Viglianti, 2012 http://itisnotsound.wordpress.com/
//
// Port of `src/stavehairpin.ts` (VexFlow 5.7.0).
// This class implements hairpins between notes.
// Hairpins can be either crescendo or decrescendo, with an optional circled niente tip.

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
    /// Draw an open niente circle at the closed end of the wedge.
    public var niente: Bool
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
        leftShiftTicks: Double? = 0,
        niente: Bool = false
    ) {
        self.niente = niente
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

        var hairpinOptions = options
        hairpinOptions.leftShiftPx = leftShiftPx
        hairpinOptions.rightShiftPx = rightShiftPx
        hairpinOptions.rightShiftTicks = 0
        hairpinOptions.leftShiftTicks = 0

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

    private struct Edges {
        var top: Double
        var left: Double
        var right: Double
        var height: Double
        var closedX: Double
        var openX: Double
        var tip: NienteTip?
    }

    private func edges(firstX: Double, lastX: Double, firstY: Double, staffHeight: Double) -> Edges {
        let yShift = renderOptions.yShift
        let height = renderOptions.height
        let above = position == .above
        let top: Double
        if let layoutBaseline {
            top = layoutBaseline - height / 2 + (above ? -yShift : yShift)
        } else {
            top = firstY + (above ? 10 - staffHeight - yShift : 20 + yShift)
        }
        let left = firstX + renderOptions.leftShiftPx + layoutLeft
        let right = lastX + renderOptions.rightShiftPx - layoutRight
        let crescendo = hairpin == .crescendo
        let closedX = crescendo ? left : right
        let openX = crescendo ? right : left
        let space = firstNote?.getStave()?.space(1) ?? Tables.STAVE_LINE_DISTANCE
        let side: NienteSide = (right >= left) == crescendo ? .left : .right
        let tip = renderOptions.niente ? nienteTip(closedX, top + height / 2, space, side) : nil
        return Edges(top: top, left: left, right: right, height: height, closedX: closedX, openX: openX, tip: tip)
    }

    private func edges(_ p: Parameters) -> Edges {
        edges(firstX: p.firstX, lastX: p.lastX, firstY: p.firstY, staffHeight: p.staffHeight)
    }

    /// Horizontal extents for spacing adjacent dynamics, including the diameter of a circled tip.
    public func getLayoutEdges() throws -> LayoutEdges {
        let e = edges(try parameters())
        let outerTip = e.tip.map { 2 * $0.x - e.closedX } ?? e.closedX
        return LayoutEdges(
            top: e.top,
            left: hairpin == .crescendo ? outerTip : e.left,
            right: hairpin == .decrescendo ? outerTip : e.right,
            height: e.height
        )
    }

    override public func getBoundingBox() -> BoundingBox? {
        guard let p = try? parameters() else { return nil }
        let e = edges(p)
        let pad = (getStyle()?.lineWidth ?? 1) / 2
        var box = BoundingBox(
            min(e.left, e.right) - pad,
            min(e.top, e.top + e.height) - pad,
            abs(e.right - e.left) + 2 * pad,
            abs(e.height) + 2 * pad
        )
        if let tip = e.tip { box.mergeWith(nienteBounds(tip, pad)) }
        return box
    }

    // MARK: - Render

    public func renderHairpin(firstX: Double, lastX: Double, firstY: Double, lastY: Double,
                              staffHeight: Double) throws {
        let ctx = try checkContext()
        let e = edges(firstX: firstX, lastX: lastX, firstY: firstY, staffHeight: staffHeight)
        let middle = e.top + e.height / 2
        ctx.beginPath()
        ctx.moveTo(e.openX, e.top)
        ctx.lineTo(e.closedX, middle)
        // At a circled tip use separate arms to keep a sharp miter out of the circle.
        if e.tip != nil { ctx.moveTo(e.closedX, middle) }
        ctx.lineTo(e.openX, e.top + e.height)
        ctx.stroke()
        ctx.closePath()
        if let tip = e.tip { drawNienteTip(ctx, tip) }
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
