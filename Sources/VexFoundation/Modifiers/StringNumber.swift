// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Larry Kuhns 2013. MIT License.

import Foundation

// MARK: - Line End Type

public enum LineEndType: Int {
    case none = 1
    case up = 2
    case down = 3
}

// MARK: - StringNumber

/// Renders circled string number annotations beside notes.
public final class StringNumber: Modifier {

    override public class var category: String { "StringNumber" }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ nums: [StringNumber],
        state: inout ModifierContextState
    ) -> Bool {
        let leftShift = state.leftShift
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
        var prevNote: Note? = nil
        var extraXSpaceForDisplaced: Double = 0
        var shiftRight: Double = 0

        for num in nums {
            let note = num.getNote()
            let pos = num.getPosition()
            guard let staveNote = note as? StaveNote else {
                fatalError("[VexError] NoStaveNote: StringNumber requires a StaveNote.")
            }
            let index = num.checkIndex()
            let props = staveNote.getKeyProps()[index]
            let verticalSpaceNeeded = (num.radius * 2) / Tables.STAVE_LINE_DISTANCE + 0.5

            if let mc = note.getModifierContext() {
                if pos == .above {
                    num.textLine = mc.getState().topTextLine
                    state.topTextLine += verticalSpaceNeeded
                } else if pos == .below {
                    num.textLine = mc.getState().textLine
                    state.textLine += verticalSpaceNeeded
                }
            }

            if note !== prevNote {
                for _ in 0..<note.keys.count {
                    if pos == .left {
                        extraXSpaceForDisplaced = max(note.getLeftDisplacedHeadPx(), extraXSpaceForDisplaced)
                    }
                    if rightShift == 0 {
                        shiftRight = max(note.getRightDisplacedHeadPx(), shiftRight)
                    }
                }
                prevNote = note
            }

            numsList.append(NumInfo(
                pos: pos, note: note, num: num, line: props.line,
                shiftL: extraXSpaceForDisplaced, shiftR: shiftRight
            ))
        }

        numsList.sort { $0.line > $1.line }

        var numShiftR: Double = 0
        var xWidthL: Double = 0
        var xWidthR: Double = 0
        var lastLine: Double? = nil
        var lastNote: Note? = nil

        for item in numsList {
            if item.line != lastLine || item.note !== lastNote {
                numShiftR = rightShift + item.shiftR
            }

            let numWidth = item.num.getWidth() + numSpacing
            if item.pos == .left {
                _ = item.num.setXShift(leftShift + extraXSpaceForDisplaced)
                xWidthL = max(numWidth, xWidthL)
            } else if item.pos == .right {
                _ = item.num.setXShift(numShiftR)
                xWidthR = max(numWidth, xWidthR)
            }
            lastLine = item.line
            lastNote = item.note
        }

        state.leftShift += xWidthL
        state.rightShift += xWidthR
        return true
    }

    // MARK: - Properties

    public var radius: Double = 8
    public var drawCircle: Bool = true
    public var stringNumber: String
    public var xOffset: Double = 0
    public var yOffset: Double = 0
    public var stemOffset: Double = 0
    public var dashed: Bool = true
    public var leg: LineEndType = .none
    public var lastNote: Note?

    // MARK: - Init

    public init(_ number: String) {
        self.stringNumber = number
        super.init()
        position = .above
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
        let note = checkAttachedNote()
        setRendered()

        let start = note.getModifierStartXY(position: position, index: checkIndex())
        let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
        var dotX = start.x + xShift + xOffset
        var dotY = start.y + yShift + yOffset

        switch position {
        case .above:
            let ys = note.getYs()
            dotY = ys.min() ?? dotY
            if note.hasStem() && stemDirection == Stem.UP {
                if let stemmable = note as? StemmableNote {
                    dotY = stemmable.checkStem().getExtents().topY
                }
            }
            dotY -= radius + textLine * Tables.STAVE_LINE_DISTANCE
        case .below:
            let ys = note.getYs()
            dotY = ys.max() ?? dotY
            if note.hasStem() && stemDirection == Stem.DOWN {
                if let stemmable = note as? StemmableNote {
                    dotY = stemmable.checkStem().getExtents().topY
                }
            }
            dotY += radius + textLine * Tables.STAVE_LINE_DISTANCE
        case .left:
            dotX -= radius / 2
        case .right:
            dotX += radius / 2
        default:
            fatalError("[VexError] InvalidPosition: The position \(position) is invalid")
        }

        ctx.save()
        if drawCircle {
            ctx.beginPath()
            ctx.arc(dotX, dotY, radius, 0, Double.pi * 2, false)
            ctx.setLineWidth(1.5)
            ctx.stroke()
        }
        if let font = textFont { ctx.setFont(font) }
        let x = dotX - ctx.measureText(stringNumber).width / 2
        ctx.fillText(stringNumber, x, dotY + 4.5)

        if let ln = lastNote, let stemmable = ln as? StemmableNote {
            let endX = stemmable.getStemX() - note.getX() + 5
            ctx.setStrokeStyle("#000000")
            ctx.setLineCap(.round)
            ctx.setLineWidth(0.6)
            if dashed {
                ctx.setLineDash([3, 3])
            }
            ctx.beginPath()
            ctx.moveTo(dotX + 10, dotY)
            ctx.lineTo(dotX + endX, dotY)
            ctx.stroke()

            switch leg {
            case .up:
                ctx.beginPath()
                ctx.moveTo(dotX + endX, dotY)
                ctx.lineTo(dotX + endX, dotY - 10)
                ctx.stroke()
            case .down:
                ctx.beginPath()
                ctx.moveTo(dotX + endX, dotY)
                ctx.lineTo(dotX + endX, dotY + 10)
                ctx.stroke()
            case .none:
                break
            }

            ctx.setLineDash([])
        }

        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("StringNumber", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
