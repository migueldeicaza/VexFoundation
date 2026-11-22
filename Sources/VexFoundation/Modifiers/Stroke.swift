// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Larry Kuhns
//
// Port of `src/strokes.ts` (VexFlow 5.0.0). The `Stroke` class renders chord
// strokes that can be arpeggiated, brushed, rasgueado, etc.

import Foundation

// MARK: - Stroke Type

public enum StrokeType: Int, Sendable {
    case brushDown = 1
    case brushUp = 2
    /// Arpeggiated chord.
    case rollDown = 3
    /// Arpeggiated chord.
    case rollUp = 4
    case rasgueadoDown = 5
    case rasgueadoUp = 6
    /// Arpeggiated chord without upwards or downwards arrow.
    case arpeggioDirectionless = 7

    @available(*, deprecated, renamed: "rasgueadoDown")
    public static var rasquedoDown: StrokeType { .rasgueadoDown }

    @available(*, deprecated, renamed: "rasgueadoUp")
    public static var rasquedoUp: StrokeType { .rasgueadoUp }
}

/// Render options for `Stroke`.
public struct StrokeRenderOptions {
    public var fontScale: Double

    public init(fontScale: Double) {
        self.fontScale = fontScale
    }
}

// MARK: - Stroke

public final class Stroke: Modifier {

    override public class var category: String { "Stroke" }

    // MARK: - Static Format

    /// Arrange strokes inside `ModifierContext`.
    @discardableResult
    public static func format(
        _ strokes: [Stroke],
        state: inout ModifierContextState
    ) -> Bool {
        let leftShift = state.leftShift
        let strokeSpacing: Double = 5

        if strokes.isEmpty { return false }

        // Only StaveNote objects have a left displaced head shift. TabNote uses 0.
        let strokeList: [(shift: Double, stroke: Stroke)] = strokes.map { stroke in
            let note = stroke.getNote()
            if let staveNote = note as? StaveNote {
                return (staveNote.getLeftDisplacedHeadPx(), stroke)
            }
            return (0, stroke)
        }

        let strokeShift = leftShift

        // There can only be one stroke .. if more than one, they overlay each other
        let xShift = strokeList.reduce(0.0) { xShift, item in
            _ = item.stroke.setXShift(strokeShift + item.shift)
            return max(item.stroke.getWidth() + strokeSpacing, xShift)
        }

        state.leftShift += xShift

        return true
    }

    // MARK: - Properties

    public var strokeType: StrokeType
    /// Multi voice: span stroke across all voices if true.
    public var allVoices: Bool
    /// Multi voice: end note of stroke.
    public var noteEnd: Note?
    public var renderOptions: StrokeRenderOptions

    // MARK: - Init

    public init(type: StrokeType, allVoices: Bool = true) {
        self.strokeType = type
        self.allVoices = allVoices
        self.renderOptions = StrokeRenderOptions(fontScale: Metrics.getDouble("Stroke.fontSize"))

        super.init()
        position = .left
        _ = setXShift(0)
        _ = setWidth(10)
    }

    // MARK: - Setters

    @discardableResult
    public func addEndNote(_ note: Note) -> Self {
        noteEnd = note
        return self
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        let start = note.getModifierStartXY(position: position, index: index ?? 0)
        var yPositions = note.getYs()
        var topY = start.y
        var botY = start.y
        let x = start.x - 5
        let lineSpace = try note.checkStaveThrowing().getSpacingBetweenLines()

        let notes = try checkModifierContextThrowing().getMembers(note.getCategory())
        for member in notes {
            // Only Note objects have getYs().
            if let memberNote = member as? Note {
                yPositions = memberNote.getYs()
                for y in yPositions {
                    if self.note === member || allVoices {
                        topY = min(topY, y)
                        botY = max(botY, y)
                    }
                }
            }
        }

        var arrow = ""
        var arrowY: Double = 0
        var textY: Double = 0

        switch strokeType {
        case .brushDown, .rollDown, .rasgueadoDown:
            arrow = Glyphs.arrowheadBlackUp
            arrowY = topY
            topY -= lineSpace / 2
            botY += lineSpace / 2
        case .brushUp, .rollUp, .rasgueadoUp:
            arrow = Glyphs.arrowheadBlackDown
            arrowY = botY + lineSpace
            topY -= lineSpace / 2
        case .arpeggioDirectionless:
            topY -= lineSpace / 2
            botY += lineSpace / 2
        }

        // Draw the stroke
        if strokeType == .brushDown || strokeType == .brushUp {
            ctx.fillRect(x + xShift, topY, 1, botY - topY)
        } else {
            // Select the wiggle glyph depending on the arrow direction
            let lineGlyph = arrow == Glyphs.arrowheadBlackDown
                ? Glyphs.wiggleArpeggiatoDown : Glyphs.wiggleArpeggiatoUp
            var txt = ""
            let el = VexElement()
            // add glyphs until the required length is achieved
            while el.getWidth() < botY - topY {
                txt += lineGlyph
                el.setText(txt)
                // Guard: stop if the glyph has no width (missing font).
                if el.getWidth() <= 0 { break }
            }
            if strokeType == .rasgueadoDown || strokeType == .rollDown || strokeType == .arpeggioDirectionless {
                ctx.openRotation(90, x + xShift, topY)
                el.renderText(
                    ctx,
                    xPos: x + xShift,
                    yPos: topY - el.getTextMetrics().actualBoundingBoxDescent + el.getHeight() / 2
                )
                ctx.closeRotation()
                textY = topY + el.getWidth() + 5
            } else {
                ctx.openRotation(-90, x + xShift, botY)
                el.renderText(
                    ctx,
                    xPos: x + xShift,
                    yPos: botY - el.getTextMetrics().actualBoundingBoxDescent + el.getHeight() / 2
                )
                ctx.closeRotation()
                textY = botY - el.getWidth() - 5
            }
        }

        // Draw the arrow head
        if arrowY != 0 {
            let el = VexElement()
            el.setText(arrow)
            el.renderText(
                ctx,
                // Center the arrow head subtracting its width / 2
                xPos: x + xShift - el.getWidth() / 2,
                yPos: arrowY
            )
        }

        // Draw the rasgueado "R"
        if strokeType == .rasgueadoDown || strokeType == .rasgueadoUp {
            let el = VexElement(category: "Stroke.text")
            el.setText("R")
            el.renderText(
                ctx,
                xPos: x + xShift - el.getWidth() / 2,
                yPos: textY + (strokeType == .rasgueadoDown ? el.getHeight() : 0)
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Stroke", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 150))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("(C5 E5 G5)/q, (D5 F5 A5), (E5 G5 B5), (F5 A5 C6)")
        _ = notes[0].addModifier(Stroke(type: .brushDown), index: 0)
        _ = notes[1].addModifier(Stroke(type: .brushUp), index: 0)
        _ = notes[2].addModifier(Stroke(type: .rollDown), index: 0)
        _ = notes[3].addModifier(Stroke(type: .rollUp), index: 0)

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
