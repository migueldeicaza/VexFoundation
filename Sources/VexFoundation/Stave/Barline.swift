// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Larry Kuhns 2011
//
// Port of `src/stavebarline.ts` (VexFlow 5.8.0).

import Foundation

// MARK: - Barline Type

/// Types of bar lines that can appear on a stave.
public enum BarlineType: Int, Sendable {
    case single = 1
    case double = 2
    case end = 3
    case repeatBegin = 4
    case repeatEnd = 5
    case repeatBoth = 6
    case none = 7
    /// A dashed (editorial) barline. (VexFlow 5.8.0)
    case dashed = 8
    /// A dotted barline. (VexFlow 5.8.0)
    case dotted = 9
    /// Two heavy strokes. (VexFlow 5.8.0 `DOUBLE_HEAVY`.) The local VexFlowPatch type of the
    /// same name had the raw value 8 and other geometry (see `docs/local-deviations.md`).
    case doubleHeavy = 10
}

/// Optional brackets ("wings") on repeat bar lines (VexFlow 5.1.0).
public enum RepeatBracketType: Int, Sendable {
    case none = 0
    case straight = 1
    case curved = 2
}

// MARK: - Barline

/// Renders bar lines on a stave.
public final class Barline: StaveModifier {

    override public class var category: String { "Barline" }

    /// Map string names to barline types.
    public static let typeString: [String: BarlineType] = [
        "single": .single,
        "double": .double,
        "end": .end,
        "repeatBegin": .repeatBegin,
        "repeatEnd": .repeatEnd,
        "repeatBoth": .repeatBoth,
        "none": .none,
        "dashed": .dashed,
        "dotted": .dotted,
        "doubleHeavy": .doubleHeavy,
    ]

    // MARK: - Properties

    private var widths: [BarlineType: Double] = [:]
    private var paddings: [BarlineType: Double] = [:]
    private var layoutMetricsMap: [BarlineType: LayoutMetrics] = [:]

    public private(set) var thickness: Double
    private var type: BarlineType = .single
    private var repeatBrackets: RepeatBracketType = .none

    // MARK: - Init

    public init(_ type: BarlineType) {
        self.thickness = Tables.STAVE_LINE_THICKNESS
        super.init()

        widths[.single] = 5
        widths[.double] = 5
        widths[.end] = 5
        widths[.repeatBegin] = 5
        widths[.repeatEnd] = 5
        widths[.repeatBoth] = 5
        widths[.none] = 5
        widths[.dashed] = 5
        widths[.dotted] = 5
        widths[.doubleHeavy] = 8

        paddings[.single] = 0
        paddings[.double] = 0
        paddings[.end] = 0
        paddings[.repeatBegin] = 15
        paddings[.repeatEnd] = 15
        paddings[.repeatBoth] = 15
        paddings[.none] = 0
        paddings[.dashed] = 0
        paddings[.dotted] = 0
        paddings[.doubleHeavy] = 0

        layoutMetricsMap[.single] = LayoutMetrics(xMin: 0, xMax: 1, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.double] = LayoutMetrics(xMin: -3, xMax: 1, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.end] = LayoutMetrics(xMin: -5, xMax: 1, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.repeatEnd] = LayoutMetrics(xMin: -10, xMax: 1, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.repeatBegin] = LayoutMetrics(xMin: -2, xMax: 10, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.repeatBoth] = LayoutMetrics(xMin: -10, xMax: 10, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.dashed] = layoutMetricsMap[.single]
        layoutMetricsMap[.dotted] = LayoutMetrics(xMin: -0.5, xMax: 1.5, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.doubleHeavy] = LayoutMetrics(xMin: -7, xMax: 1, paddingLeft: 5, paddingRight: 5)
        layoutMetricsMap[.none] = LayoutMetrics(xMin: 0, xMax: 0, paddingLeft: 5, paddingRight: 5)

        setPosition(.begin)
        setType(type)
    }

    /// Create a barline from a type string (see `typeString`). Unknown strings give `.single`.
    public convenience init(parsing type: String) {
        self.init(Barline.typeString[type] ?? .single)
    }

    // MARK: - Type

    public func getType() -> BarlineType { type }

    @discardableResult
    public func setType(_ type: BarlineType) -> Self {
        self.type = type

        setWidth(widths[type] ?? 5)
        setPadding(paddings[type] ?? 0)
        if let metrics = layoutMetricsMap[type] {
            setLayoutMetrics(metrics)
        }
        return self
    }

    /// Set the type from a type string (see `typeString`). Unknown strings are ignored.
    @discardableResult
    public func setType(_ type: String) -> Self {
        guard let parsed = Barline.typeString[type] else { return self }
        return setType(parsed)
    }

    /// Swift alias of `getType()`.
    public func getBarlineType() -> BarlineType { getType() }

    /// Swift alias of `setType(_:)`.
    @discardableResult
    public func setBarlineType(_ type: BarlineType) -> Self { setType(type) }

    // MARK: - Draw

    override public func draw() throws {
        let stave = try checkStaveThrowing()
        let ctx = try stave.checkContext()
        setRendered()

        _ = ctx.openGroup(groupClass("stavebarline"), getAttribute("id"))
        switch type {
        case .single:
            try drawVerticalBar(stave, x, false)
        case .double:
            try drawVerticalBar(stave, x, true)
        case .dashed, .dotted:
            try drawBrokenBar(stave, x)
        case .doubleHeavy:
            try drawDoubleHeavyBar(stave, x)
        case .end:
            try drawVerticalEndBar(stave, x)
        case .repeatBegin:
            // If the barline is shifted over (in front of clef/time/key)
            // Draw vertical bar at the beginning.
            try drawRepeatBar(stave, x, true)
            if stave.getX() != x {
                try drawVerticalBar(stave, stave.getX())
            }
        case .repeatEnd:
            try drawRepeatBar(stave, x, false)
        case .repeatBoth:
            try drawRepeatBar(stave, x, false)
            try drawRepeatBar(stave, x, true)
        case .none:
            // Default is NONE, so nothing to draw
            break
        }
        drawPointerRect()
        ctx.closeGroup()
    }

    // MARK: - Drawing Helpers

    public func drawVerticalBar(_ stave: Stave, _ x: Double, _ doubleBar: Bool = false) throws {
        let staveCtx = try stave.checkContext()
        let (topY, botY) = try stave.getBarlineBounds()
        if doubleBar {
            staveCtx.fillRect(x - 3, topY, 1, botY - topY)
        }
        staveCtx.fillRect(x, topY, 1, botY - topY)
    }

    /// Fit complete marks symmetrically inside the configured staff span. (VexFlow 5.8.0)
    private func drawBrokenBar(_ stave: Stave, _ x: Double) throws {
        let ctx = try stave.checkContext()
        let (topY, botY) = try stave.getBarlineBounds()
        let height = botY - topY
        let dotted = type == .dotted
        let mark = min(height, dotted ? 2 : 4)
        let count = max(1, Int(Self.jsRound(height / (dotted ? 4 : 7))))
        let step = count > 1 ? (height - mark) / Double(count - 1) : 0
        let firstY = count == 1 ? topY + (height - mark) / 2 : topY
        for i in 0..<count {
            let y = firstY + Double(i) * step
            if dotted {
                ctx.beginPath()
                ctx.arc(x + 0.5, y + mark / 2, mark / 2, 0, 2 * Double.pi, false)
                ctx.fill()
            } else {
                ctx.fillRect(x, y, 1, mark)
            }
        }
    }

    /// Use the final bar's heavy stroke on both sides of a two-pixel gap. (VexFlow 5.8.0)
    private func drawDoubleHeavyBar(_ stave: Stave, _ x: Double) throws {
        let ctx = try stave.checkContext()
        let (topY, botY) = try stave.getBarlineBounds()
        ctx.fillRect(x - 7, topY, 3, botY - topY)
        ctx.fillRect(x - 2, topY, 3, botY - topY)
    }

    public func drawVerticalEndBar(_ stave: Stave, _ x: Double) throws {
        let staveCtx = try stave.checkContext()
        let (topY, botY) = try stave.getBarlineBounds()
        staveCtx.fillRect(x - 5, topY, 1, botY - topY)
        staveCtx.fillRect(x - 2, topY, 3, botY - topY)
    }

    /// Set the repeat bracket style for repeat bar lines.
    @discardableResult
    public func setRepeatBracket(_ value: RepeatBracketType) -> Self {
        repeatBrackets = value
        return self
    }

    public func getRepeatBrackets() -> RepeatBracketType { repeatBrackets }

    /// JavaScript `Math.round`.
    private static func jsRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }

    public func drawStraightBrackets(
        _ stave: Stave, _ startX: Double, _ startY: Double, _ yDirection: Double, _ xDirection: Double
    ) throws {
        let staveCtx = try stave.checkContext()
        let rptBracketW = Self.jsRound(1.5 * Tables.STAVE_LINE_DISTANCE) * xDirection
        let rptBracketH = Self.jsRound(0.6 * Tables.STAVE_LINE_DISTANCE)
        let rptBracketMH = Self.jsRound(rptBracketH / 2)
        let brY = startY + yDirection
        let brX = xDirection > 0 ? startX - 2 : startX
        staveCtx.moveTo(brX, brY)
        staveCtx.lineTo(brX, brY + rptBracketH * (-1 * yDirection))
        staveCtx.lineTo(brX + rptBracketW, brY + rptBracketH * yDirection)
        staveCtx.lineTo(brX + rptBracketW, brY + yDirection * (rptBracketH + rptBracketMH))
        staveCtx.lineTo(brX, brY)
        staveCtx.fill()
    }

    public func drawCurvedBrackets(
        _ stave: Stave, _ startX: Double, _ startY: Double, _ yDirection: Double, _ xDirection: Double
    ) throws {
        let staveCtx = try stave.checkContext()
        let rptBracketW = Self.jsRound(1.5 * Tables.STAVE_LINE_DISTANCE) * xDirection
        let rptBracketH = Self.jsRound(0.6 * Tables.STAVE_LINE_DISTANCE)
        let rptBracketMH = Self.jsRound(rptBracketH / 2)
        let brY = startY + yDirection
        let brX = xDirection > 0 ? startX - 2 : startX

        staveCtx.moveTo(brX, brY)
        staveCtx.lineTo(brX, brY + rptBracketH * (-1 * yDirection))
        staveCtx.quadraticCurveTo(
            brX + rptBracketW / 2,
            brY + rptBracketH * (-1 * yDirection),
            brX + rptBracketW,
            brY + rptBracketH * yDirection
        )
        staveCtx.lineTo(brX + rptBracketW, brY + yDirection * (rptBracketH + rptBracketMH))
        staveCtx.quadraticCurveTo(brX + rptBracketW / 2, brY, brX, brY)
        staveCtx.fill()
    }

    public func drawRepeatBar(_ stave: Stave, _ x: Double, _ begin: Bool) throws {
        let staveCtx = try stave.checkContext()

        let (topY, botY) = try stave.getBarlineBounds()
        var xShift: Double = 3

        if !begin {
            xShift = -5
        }

        let xBracketDir: Double = begin ? 1 : -1
        staveCtx.fillRect(x + xShift, topY, 1, botY - topY)
        staveCtx.fillRect(x - 2, topY, 3, botY - topY)
        if repeatBrackets == .curved {
            try drawCurvedBrackets(stave, x, topY, -1, xBracketDir)
            try drawCurvedBrackets(stave, x, botY, 1, xBracketDir)
        } else if repeatBrackets == .straight {
            try drawStraightBrackets(stave, x, topY, -1, xBracketDir)
            try drawStraightBrackets(stave, x, botY, 1, xBracketDir)
        }

        let dotRadius: Double = 2

        // Shift dots left or right
        if begin {
            xShift += 4
        } else {
            xShift -= 4
        }

        let dotX = x + xShift + dotRadius / 2

        // calculate the y offset based on number of stave lines
        let span = stave.options.barlineSpan
        var yOffset = (span.map { $0.bottom - $0.top } ?? Double(stave.getNumLines() - 1)) * stave.getSpacingBetweenLines()
        yOffset = yOffset / 2 - stave.getSpacingBetweenLines() / 2
        var dotY = topY + yOffset + dotRadius / 2

        // draw the top repeat dot
        staveCtx.beginPath()
        staveCtx.arc(dotX, dotY, dotRadius, 0, .pi * 2, false)
        staveCtx.fill()

        // draw the bottom repeat dot
        dotY += stave.getSpacingBetweenLines()
        staveCtx.beginPath()
        staveCtx.arc(dotX, dotY, dotRadius, 0, .pi * 2, false)
        staveCtx.fill()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Barline", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()

        let f = Factory()
        _ = f.setContext(ctx)

        let s1 = f.Stave(x: 10, y: 20, width: 120)
        _ = s1.setBegBarType(.single)
        _ = s1.setEndBarType(.double)

        let s2 = f.Stave(x: 140, y: 20, width: 120)
        _ = s2.setBegBarType(.repeatBegin)
        _ = s2.setEndBarType(.repeatEnd)

        let s3 = f.Stave(x: 270, y: 20, width: 120)
        _ = s3.setBegBarType(.repeatBoth)
        _ = s3.setEndBarType(.end)

        try? f.draw()
    }
    .padding()
}
#endif
