// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Larry Kuhns 2013. MIT License.

import Foundation

// MARK: - FretHandFinger

/// Renders fret-hand finger numbers on notes.
public final class FretHandFinger: Modifier {

    override public class var category: String { "FretHandFinger" }

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

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("FretHandFinger", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

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
            .addClef("treble")
            .addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
