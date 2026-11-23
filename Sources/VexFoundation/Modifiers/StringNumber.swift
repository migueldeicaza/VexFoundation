// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Larry Kuhns
//
// Port of `src/stringnumber.ts` (VexFlow 5.8.0). The `StringNumber` class
// renders string number annotations beside notes.

import Foundation

public enum StringNumberError: Error, LocalizedError, Equatable, Sendable {
    case requiresStaveNote
    case invalidPosition(ModifierPosition)

    public var errorDescription: String? {
        switch self {
        case .requiresStaveNote:
            return "String numbers require a pitched note or TAB fret."
        case .invalidPosition(let position):
            return "The position \(position) is invalid."
        }
    }
}

// MARK: - Line End Type

/// Port of `Renderer.LineEndType`.
public enum LineEndType: Int, Sendable {
    /// No leg.
    case none = 1
    /// Upward leg.
    case up = 2
    /// Downward leg.
    case down = 3
}

// MARK: - StringNumber

public final class StringNumber: Modifier {

    override public class var category: String { "StringNumber" }

    // MARK: - Static Format

    /// Arrange string numbers inside a `ModifierContext`.
    @discardableResult
    public static func format(
        _ nums: [StringNumber],
        state: inout ModifierContextState
    ) -> Bool {
        (try? formatThrowing(nums, state: &state)) ?? false
    }

    @discardableResult
    public static func formatThrowing(
        _ nums: [StringNumber],
        state: inout ModifierContextState
    ) throws -> Bool {
        /// The modifier context's leftShift state.
        let leftShift = state.leftShift
        /// The modifier context's rightShift state.
        let rightShift = state.rightShift
        let numSpacing: Double = 1

        if nums.isEmpty { return false }

        struct NumInfo {
            var pos: ModifierPosition
            var note: Note
            var num: StringNumber
            var line: Double
            var shiftL: Double
            var shiftR: Double
        }

        var numsList: [NumInfo] = []
        var prevNote: Note?
        var extraXSpaceForDisplacedNotehead: Double = 0
        var shiftRight: Double = 0

        for num in nums {
            let note = num.getNote()
            let pos = num.getPosition()
            guard note is StaveNote || note is TabNote else {
                throw StringNumberError.requiresStaveNote
            }
            let line = try num.getAttachedLine()
            let verticalSpaceNeeded = (num.radius * 2) / Tables.STAVE_LINE_DISTANCE + 0.5

            // Upstream reads `note.getModifierContext().getState()`. The
            // ModifierContext passes its own state here as `inout`, so read the
            // same values from `state` (avoids overlapping access).
            if note.getModifierContext() != nil {
                if pos == .above {
                    num.textLine = state.topTextLine
                    state.topTextLine += verticalSpaceNeeded
                } else if pos == .below {
                    num.textLine = state.textLine
                    state.textLine += verticalSpaceNeeded
                }
            }

            if note !== prevNote {
                for _ in 0..<note.keys.count {
                    if pos == .left {
                        extraXSpaceForDisplacedNotehead = max(
                            note.getLeftDisplacedHeadPx(), extraXSpaceForDisplacedNotehead
                        )
                    }
                    if rightShift == 0 {
                        shiftRight = max(note.getRightDisplacedHeadPx(), shiftRight)
                    }
                }
                prevNote = note
            }

            numsList.append(NumInfo(
                pos: pos,
                note: note,
                num: num,
                line: line,
                shiftL: extraXSpaceForDisplacedNotehead,
                shiftR: shiftRight
            ))
        }

        // Sort string numbers by line number (stable, like Array.prototype.sort).
        numsList = numsList.enumerated()
            .sorted { $0.element.line != $1.element.line ? $0.element.line > $1.element.line : $0.offset < $1.offset }
            .map(\.element)

        var numShiftR: Double = 0
        var xWidthL: Double = 0
        var xWidthR: Double = 0
        var lastLine: Double?
        var lastNote: Note?
        for item in numsList {
            // Reset the position of the string number every line.
            if item.line != lastLine || item.note !== lastNote {
                numShiftR = rightShift + item.shiftR
            }

            let numWidth = item.num.getWidth() + numSpacing
            var numXShift: Double = 0
            if item.pos == .left {
                _ = item.num.setXShift(leftShift + extraXSpaceForDisplacedNotehead)
                numXShift = numWidth // spacing
                xWidthL = max(numXShift, xWidthL)
            } else if item.pos == .right {
                _ = item.num.setXShift(numShiftR)
                numXShift += numWidth // spacing
                xWidthR = numXShift > xWidthR ? numXShift : xWidthR
            }
            lastLine = item.line
            lastNote = item.note
        }

        state.leftShift += xWidthL
        state.rightShift += xWidthR
        return true
    }

    // MARK: - Properties

    public var radius: Double
    public var drawCircle: Bool
    public var lastNote: Note?
    public var stringNumber: String
    /// Horizontal offset from default.
    public var xOffset: Double
    /// Vertical offset from default.
    public var yOffset: Double
    public var stemOffset: Double
    /// true: draw dashed extension. false: no extension.
    public var dashed: Bool
    /// Draw upward/downward leg at the end of the extension line.
    public var leg: LineEndType

    // MARK: - Init

    public init(_ number: String) {
        stringNumber = number
        stemOffset = 0
        xOffset = 0
        yOffset = 0
        dashed = true
        leg = .none
        radius = 8
        drawCircle = true
        super.init()

        position = .above // Default position above stem or note head
        xShift = 0
        yShift = 0
        textLine = 0
        _ = setWidth(radius * 2 + 4)
    }

    // MARK: - Setters

    @discardableResult
    public func setLineEndType(_ leg: LineEndType) -> Self {
        self.leg = leg
        return self
    }

    @discardableResult
    public func setStringNumber(_ number: String) -> Self {
        stringNumber = number
        return self
    }

    @discardableResult
    public func setOffsetX(_ x: Double) -> Self {
        xOffset = x
        return self
    }

    @discardableResult
    public func setOffsetY(_ y: Double) -> Self {
        yOffset = y
        return self
    }

    @discardableResult
    public func setLastNote(_ note: Note) -> Self {
        lastNote = note
        return self
    }

    @discardableResult
    public func setDashed(_ dashed: Bool) -> Self {
        self.dashed = dashed
        return self
    }

    @discardableResult
    public func setDrawCircle(_ drawCircle: Bool) -> Self {
        self.drawCircle = drawCircle
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()
        let start = note.getModifierStartXY(position: position, index: index ?? 0)
        let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
        var dotX = start.x + xShift + xOffset
        var stemExt: (topY: Double, baseY: Double) = (0, 0)
        if note.hasStem(), let stemmable = note as? StemmableNote {
            stemExt = try stemmable.checkStemThrowing().getExtents()
        }

        var dotY = start.y + yShift + yOffset

        switch position {
        case .above:
            let ys = note.getYs()
            dotY = ys.min() ?? dotY
            if note.hasStem() && stemDirection == Stem.UP {
                dotY = stemExt.topY + Metrics.getDouble("StringNumber.stemPadding")
            }
            dotY -= radius + Metrics.getDouble("StringNumber.verticalPadding")
                + textLine * Tables.STAVE_LINE_DISTANCE
        case .below:
            let ys = note.getYs()
            dotY = ys.max() ?? dotY
            if note.hasStem() && stemDirection == Stem.DOWN {
                dotY = stemExt.topY - Metrics.getDouble("StringNumber.stemPadding")
            }
            dotY += radius + Metrics.getDouble("StringNumber.verticalPadding")
                + textLine * Tables.STAVE_LINE_DISTANCE
        case .left:
            dotX -= radius / 2 + Metrics.getDouble("StringNumber.leftPadding")
        case .right:
            dotX += radius / 2 + Metrics.getDouble("StringNumber.rightPadding")
        default:
            throw StringNumberError.invalidPosition(position)
        }

        if note is TabNote && (position == .left || position == .right) {
            ctx.clearRect(dotX - radius, dotY - 2, 2 * radius, 4)
        }
        if drawCircle {
            ctx.beginPath()
            ctx.arc(dotX, dotY, radius, 0, Double.pi * 2, false)
            ctx.setLineWidth(1.5)
            ctx.stroke()
        }
        ctx.setFont(fontInfo)
        let x = dotX - ctx.measureText(stringNumber).width / 2
        ctx.fillText(stringNumber, x, dotY + 4.5)

        // Only StemmableNote objects have getStemX().
        if let lastNote = lastNote as? StemmableNote {
            let end = lastNote.getStemX() - note.getX() + 5
            ctx.setLineCap(.round)
            ctx.setLineWidth(0.6)
            if dashed {
                try Renderer.drawDashedLine(ctx, dotX + 10, dotY, dotX + end, dotY, [3, 3])
            } else {
                try Renderer.drawDashedLine(ctx, dotX + 10, dotY, dotX + end, dotY, [3, 0])
            }

            switch leg {
            case .up:
                let len: Double = -10
                let pattern: [Double] = dashed ? [3, 3] : [3, 0]
                try Renderer.drawDashedLine(ctx, dotX + end, dotY, dotX + end, dotY + len, pattern)
            case .down:
                let len: Double = 10
                let pattern: [Double] = dashed ? [3, 3] : [3, 0]
                try Renderer.drawDashedLine(ctx, dotX + end, dotY, dotX + end, dotY + len, pattern)
            case .none:
                break
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StringNumber", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 170))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(f.StringNumber(number: "1"), index: 0)
        _ = notes[2].addModifier(f.StringNumber(number: "3"), index: 0)

        let system = f.System(options: SystemOptions(
            factory: f, x: 10, width: 500, y: 10
        ))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
