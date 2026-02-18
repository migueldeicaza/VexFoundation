// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Larry Kuhns 2013. MIT License.

import Foundation

// MARK: - FretHandFinger

/// Renders fret-hand finger numbers on notes.
public final class FretHandFinger: Modifier {

    override public class var CATEGORY: String { "FretHandFinger" }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ nums: [FretHandFinger],
        state: inout ModifierContextState
    ) -> Bool {
        let leftShift = state.leftShift
        let rightShift = state.rightShift
        let numSpacing: Double = 1

        if nums.isEmpty { return false }

        struct NumInfo {
            var note: Note
            var num: FretHandFinger
            var pos: ModifierPosition
            var line: Double
            var shiftL: Double
            var shiftR: Double
        }

        var numsList: [NumInfo] = []
        var prevNote: Note? = nil
        var shiftLeft: Double = 0
        var shiftRight: Double = 0

        for num in nums {
            let note = num.getNote()
            let pos = num.getPosition()
            let index = num.checkIndex()
            let props = note.getKeyProps()[index]

            if note !== prevNote {
                for _ in 0..<note.keys.count {
                    if leftShift == 0 {
                        shiftLeft = max(note.getLeftDisplacedHeadPx(), shiftLeft)
                    }
                    if rightShift == 0 {
                        shiftRight = max(note.getRightDisplacedHeadPx(), shiftRight)
                    }
                }
                prevNote = note
            }

            numsList.append(NumInfo(
                note: note, num: num, pos: pos, line: props.line,
                shiftL: shiftLeft, shiftR: shiftRight
            ))
        }

        numsList.sort { $0.line > $1.line }

        var numShiftL: Double = 0
        var numShiftR: Double = 0
        var xWidthL: Double = 0
        var xWidthR: Double = 0
        var lastLine: Double? = nil
        var lastNote: Note? = nil

        for item in numsList {
            if item.line != lastLine || item.note !== lastNote {
                numShiftL = leftShift + item.shiftL
                numShiftR = rightShift + item.shiftR
            }

            let numWidth = item.num.getWidth() + numSpacing
            if item.pos == .left {
                _ = item.num.setXShift(leftShift + numShiftL)
                let numShift = leftShift + numWidth
                xWidthL = max(numShift, xWidthL)
            } else if item.pos == .right {
                _ = item.num.setXShift(numShiftR)
                let numShift = item.shiftR + numWidth
                xWidthR = max(numShift, xWidthR)
            }
            lastLine = item.line
            lastNote = item.note
        }

        state.leftShift += xWidthL
        state.rightShift += xWidthR

        return true
    }

    // MARK: - Properties

    public var finger: String
    public var xOffset: Double = 0
    public var yOffset: Double = 0

    // MARK: - Init

    public init(_ finger: String) {
        self.finger = finger
        super.init()
        _ = setWidth(7)
        position = .left
    }

    // MARK: - Setters

    @discardableResult
    public func setFretHandFinger(_ finger: String) -> Self {
        self.finger = finger
        return self
    }

    public func getFretHandFinger() -> String { finger }

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

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        let start = note.getModifierStartXY(position: position, index: checkIndex())
        var dotX = start.x + xShift + xOffset
        var dotY = start.y + yShift + yOffset + 5

        switch position {
        case .above:
            dotX -= 4
            dotY -= 12
        case .below:
            dotX -= 2
            dotY += 10
        case .left:
            dotX -= getWidth()
        case .right:
            dotX += 1
        default:
            fatalError("[VexError] InvalidPosition: The position \(position) does not exist")
        }

        ctx.save()
        if let font = textFont { ctx.setFont(font) }
        ctx.fillText(finger, dotX, dotY)
        ctx.restore()
    }

    // MARK: - EasyScore Hook

    /// Commit hook for EasyScore to auto-add fingerings.
    public static func easyScoreHook(
        options: [String: String],
        note: StemmableNote,
        builder: Builder
    ) {
        guard let fingeringsStr = options["fingerings"] else { return }

        for (index, fingeringString) in fingeringsStr.split(separator: ",").enumerated() {
            let parts = fingeringString.trimmingCharacters(in: .whitespaces).split(separator: ".")
            let number = String(parts[0])
            let fingering = FretHandFinger(number)
            if parts.count > 1 {
                if let pos = Modifier.positionString[String(parts[1])] {
                    _ = fingering.setPosition(pos)
                }
            }
            _ = note.addModifier(fingering, index: index)
        }
    }
}
