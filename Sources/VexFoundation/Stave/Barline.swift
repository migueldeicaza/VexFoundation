// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. Author Larry Kuhns 2011.

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
    ]

    // MARK: - Properties

    private var barlineType: BarlineType = .single
    private var thickness: Double

    private static let widths: [BarlineType: Double] = [
        .single: 5, .double: 5, .end: 5,
        .repeatBegin: 5, .repeatEnd: 5, .repeatBoth: 5, .none: 5,
    ]

    private static let paddings: [BarlineType: Double] = [
        .single: 0, .double: 0, .end: 0,
        .repeatBegin: 15, .repeatEnd: 15, .repeatBoth: 15, .none: 0,
    ]

    private static let layoutMetricsMap: [BarlineType: LayoutMetrics] = [
        .single: LayoutMetrics(xMin: 0, xMax: 1, paddingLeft: 5, paddingRight: 5),
        .double: LayoutMetrics(xMin: -3, xMax: 1, paddingLeft: 5, paddingRight: 5),
        .end: LayoutMetrics(xMin: -5, xMax: 1, paddingLeft: 5, paddingRight: 5),
        .repeatEnd: LayoutMetrics(xMin: -10, xMax: 1, paddingLeft: 5, paddingRight: 5),
        .repeatBegin: LayoutMetrics(xMin: -2, xMax: 10, paddingLeft: 5, paddingRight: 5),
        .repeatBoth: LayoutMetrics(xMin: -10, xMax: 10, paddingLeft: 5, paddingRight: 5),
        .none: LayoutMetrics(xMin: 0, xMax: 0, paddingLeft: 5, paddingRight: 5),
    ]

    // MARK: - Init

    public init(_ type: BarlineType) {
        self.thickness = Tables.STAVE_LINE_THICKNESS
        super.init()
        setPosition(.begin)
        setBarlineType(type)
    }

    // MARK: - Type

    public func getBarlineType() -> BarlineType { barlineType }

    @discardableResult
    public func setBarlineType(_ type: BarlineType) -> Self {
        self.barlineType = type
        self.modifierWidth = Barline.widths[type] ?? 5
        self.padding = Barline.paddings[type] ?? 0
        if let metrics = Barline.layoutMetricsMap[type] {
            self.layoutMetrics = metrics
        }
        return self
    }

    // MARK: - Draw

    override public func drawStave(stave: Stave, xShift: Double = 0) throws {
        let ctx = try stave.checkContext()
        setRendered()
        applyStyle(context: ctx)
        _ = ctx.openGroup("stavebarline", getAttribute("id"))

        switch barlineType {
        case .single:
            try drawVerticalBar(stave: stave, x: modifierX)
        case .double:
            try drawVerticalBar(stave: stave, x: modifierX, doubleBar: true)
        case .end:
            try drawVerticalEndBar(stave: stave, x: modifierX)
        case .repeatBegin:
            try drawRepeatBar(stave: stave, x: modifierX, begin: true)
            if stave.getX() != modifierX {
                try drawVerticalBar(stave: stave, x: stave.getX())
            }
        case .repeatEnd:
            try drawRepeatBar(stave: stave, x: modifierX, begin: false)
        case .repeatBoth:
            try drawRepeatBar(stave: stave, x: modifierX, begin: false)
            try drawRepeatBar(stave: stave, x: modifierX, begin: true)
        case .none:
            break
        }

        ctx.closeGroup()
        restoreStyle(context: ctx)
    }

    // MARK: - Drawing Helpers

    private func drawVerticalBar(stave: Stave, x: Double, doubleBar: Bool = false) throws {
        let ctx = try stave.checkContext()
        let topY = stave.getTopLineTopY()
        let botY = stave.getBottomLineBottomY()
        if doubleBar {
            ctx.fillRect(x - 3, topY, 1, botY - topY)
        }
        ctx.fillRect(x, topY, 1, botY - topY)
    }

    private func drawVerticalEndBar(stave: Stave, x: Double) throws {
        let ctx = try stave.checkContext()
        let topY = stave.getTopLineTopY()
        let botY = stave.getBottomLineBottomY()
        ctx.fillRect(x - 5, topY, 1, botY - topY)
        ctx.fillRect(x - 2, topY, 3, botY - topY)
    }

    private func drawRepeatBar(stave: Stave, x: Double, begin: Bool) throws {
        let ctx = try stave.checkContext()
        let topY = stave.getTopLineTopY()
        let botY = stave.getBottomLineBottomY()

        var xShift: Double = begin ? 3 : -5

        ctx.fillRect(x + xShift, topY, 1, botY - topY)
        ctx.fillRect(x - 2, topY, 3, botY - topY)

        let dotRadius: Double = 2
        if begin {
            xShift += 4
        } else {
            xShift -= 4
        }
        let dotX = x + xShift + dotRadius / 2

        var yOffset = Double(stave.getNumLines() - 1) * stave.getSpacingBetweenLines()
        yOffset = yOffset / 2 - stave.getSpacingBetweenLines() / 2
        var dotY = topY + yOffset + dotRadius / 2

        // Top repeat dot
        ctx.beginPath()
        ctx.arc(dotX, dotY, dotRadius, 0, .pi * 2, false)
        ctx.fill()

        // Bottom repeat dot
        dotY += stave.getSpacingBetweenLines()
        ctx.beginPath()
        ctx.arc(dotX, dotY, dotRadius, 0, .pi * 2, false)
        ctx.fill()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Barline", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 120) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
