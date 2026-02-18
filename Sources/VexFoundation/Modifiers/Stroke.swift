// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010.
// Author: Larry Kuhns. MIT License.

import Foundation

// MARK: - Stroke Type

public enum StrokeType: Int {
    case brushDown = 1
    case brushUp = 2
    case rollDown = 3
    case rollUp = 4
    case rasquedoDown = 5
    case rasquedoUp = 6
    case arpeggioDirectionless = 7
}

// MARK: - Stroke

/// Renders chord strokes (arpeggiated, brushed, rasquedo, etc.).
public final class Stroke: Modifier {

    override public class var category: String { "Stroke" }

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ strokes: [Stroke],
        state: inout ModifierContextState
    ) -> Bool {
        let leftShift = state.leftShift

        if strokes.isEmpty { return false }

        var xShiftMax: Double = 0
        for stroke in strokes {
            let note = stroke.getNote()
            let shift = note.getLeftDisplacedHeadPx()
            _ = stroke.setXShift(leftShift + shift)
            xShiftMax = max(stroke.getWidth(), xShiftMax)
        }

        state.leftShift += xShiftMax
        return true
    }

    // MARK: - Properties

    public var strokeType: StrokeType
    public var allVoices: Bool
    public var noteEnd: Note?
    public var strokeRenderOptions: (fontScale: Double, ())

    // MARK: - Init

    public init(type: StrokeType, allVoices: Bool = true) {
        self.strokeType = type
        self.allVoices = allVoices
        self.strokeRenderOptions = (fontScale: Tables.NOTATION_FONT_SCALE, ())

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
        let note = checkAttachedNote()
        setRendered()

        let start = note.getModifierStartXY(position: position, index: checkIndex())
        var ys = note.getYs()
        var topY = start.y
        var botY = start.y
        let x = start.x - 5
        let lineSpace = note.checkStave().getSpacingBetweenLines()

        let members = checkModifierContext().getMembers(note.getCategory())
        for member in members {
            if let memberNote = member as? Note {
                ys = memberNote.getYs()
                for y in ys {
                    if self.note === member || allVoices {
                        topY = min(topY, y)
                        botY = max(botY, y)
                    }
                }
            }
        }

        var arrow = ""
        var arrowShiftX: Double = 0
        var arrowY: Double = 0
        var textShiftX: Double = 0
        var textY: Double = 0
        let isStave = note is StaveNote

        switch strokeType {
        case .brushDown:
            arrow = "arrowheadBlackUp"
            arrowShiftX = -3
            arrowY = topY - lineSpace / 2 + 10
            botY += lineSpace / 2
        case .brushUp:
            arrow = "arrowheadBlackDown"
            arrowShiftX = 0.5
            arrowY = botY + lineSpace / 2
            topY -= lineSpace / 2
        case .rollDown, .rasquedoDown:
            arrow = "arrowheadBlackUp"
            arrowShiftX = -3
            textShiftX = xShift + arrowShiftX - 2
            if isStave {
                topY += 1.5 * lineSpace
                if Int(botY - topY) % 2 != 0 {
                    botY += 0.5 * lineSpace
                } else {
                    botY += lineSpace
                }
                arrowY = topY - lineSpace
                textY = botY + lineSpace + 2
            } else {
                topY += 1.5 * lineSpace
                botY += lineSpace
                arrowY = topY - 0.75 * lineSpace
                textY = botY + 0.25 * lineSpace
            }
        case .rollUp, .rasquedoUp:
            arrow = "arrowheadBlackDown"
            arrowShiftX = -4
            textShiftX = xShift + arrowShiftX - 1
            if isStave {
                topY += 0.5 * lineSpace
                if Int(botY - topY) % 2 == 0 {
                    botY += lineSpace / 2
                }
                arrowY = botY + 0.5 * lineSpace
                textY = topY - 1.25 * lineSpace
            } else {
                topY += 0.25 * lineSpace
                botY += 0.5 * lineSpace
                arrowY = botY + 0.25 * lineSpace
                textY = topY - lineSpace
            }
        case .arpeggioDirectionless:
            topY += 0.5 * lineSpace
            botY += lineSpace
        }

        var strokeLine = "straight"
        if strokeType == .brushDown || strokeType == .brushUp {
            ctx.fillRect(x + xShift, topY, 1, botY - topY)
        } else {
            strokeLine = "wiggly"
            var i = topY
            while i <= botY {
                Glyph.renderGlyph(ctx: ctx, xPos: x + xShift - 4, yPos: i,
                                  point: strokeRenderOptions.fontScale, code: "vexWiggleArpeggioUp")
                i += isStave ? lineSpace : 10
            }
            if strokeType == .rasquedoDown && !isStave {
                textY = i + 0.25 * lineSpace
            }
        }

        if strokeType == .arpeggioDirectionless {
            return
        }

        Glyph.renderGlyph(ctx: ctx, xPos: x + xShift + arrowShiftX, yPos: arrowY,
                          point: strokeRenderOptions.fontScale, code: arrow,
                          category: "stroke_\(strokeLine).\(arrow)")

        if strokeType == .rasquedoDown || strokeType == .rasquedoUp {
            ctx.save()
            if let font = textFont { ctx.setFont(font) }
            ctx.fillText("R", x + textShiftX, textY)
            ctx.restore()
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
        FontLoader.loadDefaultFonts()

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
            .addTimeSignature("4/4")

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
