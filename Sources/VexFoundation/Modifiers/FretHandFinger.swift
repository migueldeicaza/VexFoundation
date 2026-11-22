// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Larry Kuhns 2013
//
// Port of `src/frethandfinger.ts` (VexFlow 5.0.0).

import Foundation

public enum FretHandFingerError: Error, LocalizedError, Equatable, Sendable {
    case invalidPosition(ModifierPosition)

    public var errorDescription: String? {
        switch self {
        case .invalidPosition(let position):
            return "The position \(position) does not exist."
        }
    }
}

// MARK: - FretHandFinger

/// Renders fret-hand finger numbers on notes.
public final class FretHandFinger: Modifier {

    override public class var category: String { "FretHandFinger" }

    // MARK: - Static Format

    /// Arrange fingerings inside a ModifierContext.
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
        var prevNote: Note?
        var shiftLeft: Double = 0
        var shiftRight: Double = 0

        for num in nums {
            let note = num.getNote()
            let pos = num.getPosition()
            let index = num.checkIndex()
            let props = note.getKeyProps()[index]
            let textHeight = Metrics.getDouble("FretHandFinger.fontSize")
            if num.position == .above {
                state.topTextLine += textHeight / Tables.STAVE_LINE_DISTANCE + 0.5
            }
            if num.position == .below {
                state.textLine += textHeight / Tables.STAVE_LINE_DISTANCE + 0.5
            }

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
                note: note,
                num: num,
                pos: pos,
                line: props.line,
                shiftL: shiftLeft,
                shiftR: shiftRight
            ))
        }

        // Sort fingernumbers by line number (stable, like Array.prototype.sort).
        numsList = numsList.enumerated()
            .sorted { $0.element.line != $1.element.line ? $0.element.line > $1.element.line : $0.offset < $1.offset }
            .map(\.element)

        var numShiftL: Double = 0
        var numShiftR: Double = 0
        var xWidthL: Double = 0
        var xWidthR: Double = 0
        var lastLine: Double?
        var lastNote: Note?

        for item in numsList {
            var numShift: Double = 0

            // Reset the position of the string number every line.
            if item.line != lastLine || item.note !== lastNote {
                numShiftL = leftShift + item.shiftL
                numShiftR = rightShift + item.shiftR
            }

            let numWidth = item.num.getWidth() + numSpacing
            if item.pos == .left {
                _ = item.num.setXShift(leftShift + numShiftL)
                numShift = leftShift + numWidth // spacing
                xWidthL = numShift > xWidthL ? numShift : xWidthL
            } else if item.pos == .right {
                _ = item.num.setXShift(numShiftR)
                numShift = shiftRight + numWidth // spacing
                xWidthR = numShift > xWidthR ? numShift : xWidthR
            }
            lastLine = item.line
            lastNote = item.note
        }

        state.leftShift += xWidthL
        state.rightShift += xWidthR

        return true
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
            guard let first = parts.first else { continue }
            let fingering = FretHandFinger(String(first))
            if parts.count > 1, let pos = Modifier.positionString[String(parts[1])] {
                _ = fingering.setPosition(pos)
            }
            _ = note.addModifier(fingering, index: index)
        }
    }

    // MARK: - Properties

    /// Horizontal offset from default.
    public var xOffset: Double
    /// Vertical offset from default.
    public var yOffset: Double

    @available(*, deprecated, renamed: "getFretHandFinger()")
    public var finger: String { text }

    // MARK: - Init

    public init(_ finger: String) {
        xOffset = 0
        yOffset = 0
        super.init()

        setFretHandFinger(finger)
        position = .left // Default position above stem or note head
    }

    // MARK: - Setters

    @discardableResult
    public func setFretHandFinger(_ finger: String) -> Self {
        text = finger
        return self
    }

    public func getFretHandFinger() -> String { text }

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
        let note = try checkAttachedNoteThrowing()
        setRendered()

        let start = note.getModifierStartXY(position: position, index: index ?? 0)
        var dotX = start.x + xOffset
        var dotY = start.y + yOffset + 5

        switch position {
        case .above:
            dotX -= 4
            dotY -= 12
        case .below:
            dotX -= 2
            dotY += 10
        case .left:
            dotX -= width
        case .right:
            dotX += 1
        default:
            throw FretHandFingerError.invalidPosition(position)
        }

        renderText(ctx, xPos: dotX, yPos: dotY)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("FretHandFinger", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(f.Fingering(number: "1"), index: 0)
        _ = notes[1].addModifier(f.Fingering(number: "2"), index: 0)
        _ = notes[2].addModifier(f.Fingering(number: "3"), index: 0)
        _ = notes[3].addModifier(f.Fingering(number: "4"), index: 0)

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
