// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Bend Phrase

public struct BendPhrase {
    public var x: Double?
    public var type: Int
    public var text: String
    public var width: Double?
    public var drawWidth: Double?

    public init(type: Int, text: String, width: Double? = nil, drawWidth: Double? = nil) {
        self.type = type
        self.text = text
        self.width = width
        self.drawWidth = drawWidth
    }
}

// MARK: - Bend Render Options

public struct BendRenderOptions {
    public var lineWidth: Double = 1.5
    public var releaseWidth: Double = 8
    public var bendWidth: Double = 8
    public var lineStyle: String = "#777777"

    public init(
        lineWidth: Double = 1.5,
        releaseWidth: Double = 8,
        bendWidth: Double = 8,
        lineStyle: String = "#777777"
    ) {
        self.lineWidth = lineWidth
        self.releaseWidth = releaseWidth
        self.bendWidth = bendWidth
        self.lineStyle = lineStyle
    }
}

// MARK: - Bend

/// Renders tablature bends on notes with up/down arrows and text.
public final class Bend: Modifier {

    override public class var category: String { "Bend" }

    public static let UP = 0
    public static let DOWN = 1

    // MARK: - Static Format

    @discardableResult
    public static func format(
        _ bends: [Bend],
        state: inout ModifierContextState
    ) -> Bool {
        if bends.isEmpty { return false }

        var lastWidth: Double = 0
        for bend in bends {
            _ = bend.setXShift(lastWidth)
            lastWidth = bend.getWidth()
            _ = bend.setTextLine(state.topTextLine)
        }

        state.rightShift += lastWidth
        state.topTextLine += 1
        return true
    }

    // MARK: - Properties

    public var text: String
    public var tap: String = ""
    public var release: Bool
    public var phrase: [BendPhrase]
    public var bendRenderOptions = BendRenderOptions()

    // MARK: - Init

    public init(_ text: String, release: Bool = false, phrase: [BendPhrase]? = nil) {
        self.text = text
        self.release = release

        if let phrase {
            self.phrase = phrase
        } else {
            var phrases: [BendPhrase] = [BendPhrase(type: Bend.UP, text: text)]
            if release {
                phrases.append(BendPhrase(type: Bend.DOWN, text: ""))
            }
            self.phrase = phrases
        }

        super.init()
        updateWidth()
    }

    // MARK: - Setters

    @discardableResult
    public override func setXShift(_ value: Double) -> Self {
        xShift = value
        updateWidth()
        return self
    }

    @discardableResult
    public func setTap(_ value: String) -> Self {
        tap = value
        return self
    }

    public func getText() -> String { text }

    // MARK: - Update Width

    private func updateWidth() {
        var totalWidth: Double = 0
        for i in 0..<phrase.count {
            if let w = phrase[i].width {
                totalWidth += w
            } else {
                let additionalWidth = phrase[i].type == Bend.UP
                    ? bendRenderOptions.bendWidth
                    : bendRenderOptions.releaseWidth
                let textWidth = Double(phrase[i].text.count) * 6 // approximate text width
                let w = max(additionalWidth, textWidth) + 3
                phrase[i].width = w
                phrase[i].drawWidth = w / 2
                totalWidth += w
            }
        }
        _ = setWidth(totalWidth + xShift)
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        var start = note.getModifierStartXY(position: .right, index: checkIndex())
        start.x += 3
        start.y += 0.5
        let xShiftVal = xShift

        let stave = note.checkStave()
        let spacing = stave.getSpacingBetweenLines()
        let lowestY = note.getYs().min() ?? start.y
        let bendHeight = start.y - ((textLine + 1) * spacing + start.y - lowestY) + 3
        let annotationY = start.y - ((textLine + 1) * spacing + start.y - lowestY) - 1

        if !tap.isEmpty {
            let tapStart = note.getModifierStartXY(position: .center, index: checkIndex())
            ctx.save()
            if let font = textFont { ctx.setFont(font) }
            let tw = ctx.measureText(tap).width
            ctx.fillText(tap, tapStart.x - tw / 2, annotationY)
            ctx.restore()
        }

        var lastBend: BendPhrase? = nil
        var lastBendDrawWidth: Double = 0
        var lastDrawnWidth: Double = 0

        for i in 0..<phrase.count {
            if phrase[i].drawWidth == nil { phrase[i].drawWidth = 0 }
            if i == 0 { phrase[i].drawWidth! += xShiftVal }

            lastDrawnWidth = phrase[i].drawWidth! + lastBendDrawWidth - (i == 1 ? xShiftVal : 0)

            if phrase[i].type == Bend.UP {
                if let lb = lastBend, lb.type == Bend.UP {
                    renderArrowHead(ctx: ctx, x: start.x, y: bendHeight, direction: 1)
                }
                renderBend(ctx: ctx, x: start.x, y: start.y, width: lastDrawnWidth, height: bendHeight)
            }

            if phrase[i].type == Bend.DOWN {
                if let lb = lastBend, lb.type == Bend.UP {
                    renderRelease(ctx: ctx, x: start.x, y: start.y, width: lastDrawnWidth, height: bendHeight)
                }
                if let lb = lastBend, lb.type == Bend.DOWN {
                    renderArrowHead(ctx: ctx, x: start.x, y: start.y, direction: -1)
                    renderRelease(ctx: ctx, x: start.x, y: start.y, width: lastDrawnWidth, height: bendHeight)
                }
                if lastBend == nil {
                    lastDrawnWidth = phrase[i].drawWidth!
                    renderRelease(ctx: ctx, x: start.x, y: start.y, width: lastDrawnWidth, height: bendHeight)
                }
            }

            renderText(ctx: ctx, x: start.x + lastDrawnWidth, text: phrase[i].text, y: annotationY)
            phrase[i].x = start.x
            lastBend = phrase[i]
            lastBendDrawWidth = phrase[i].drawWidth!

            start.x += lastDrawnWidth
        }

        guard let lb = lastBend, lb.x != nil else {
            fatalError("[VexError] NoLastBendForBend: Internal error.")
        }

        if lb.type == Bend.UP {
            renderArrowHead(ctx: ctx, x: lb.x! + lastDrawnWidth, y: bendHeight, direction: 1)
        } else if lb.type == Bend.DOWN {
            renderArrowHead(ctx: ctx, x: lb.x! + lastDrawnWidth, y: start.y, direction: -1)
        }
    }

    // MARK: - Private Render Helpers

    private func renderBend(ctx: any RenderContext, x: Double, y: Double, width: Double, height: Double) {
        ctx.save()
        ctx.beginPath()
        ctx.setLineWidth(bendRenderOptions.lineWidth)
        ctx.setStrokeStyle(bendRenderOptions.lineStyle)
        ctx.setFillStyle(bendRenderOptions.lineStyle)
        ctx.moveTo(x, y)
        ctx.quadraticCurveTo(x + width, y, x + width, height)
        ctx.stroke()
        ctx.restore()
    }

    private func renderRelease(ctx: any RenderContext, x: Double, y: Double, width: Double, height: Double) {
        ctx.save()
        ctx.beginPath()
        ctx.setLineWidth(bendRenderOptions.lineWidth)
        ctx.setStrokeStyle(bendRenderOptions.lineStyle)
        ctx.setFillStyle(bendRenderOptions.lineStyle)
        ctx.moveTo(x, height)
        ctx.quadraticCurveTo(x + width, height, x + width, y)
        ctx.stroke()
        ctx.restore()
    }

    private func renderArrowHead(ctx: any RenderContext, x: Double, y: Double, direction: Double) {
        let w: Double = 4
        let yBase = y + w * direction

        ctx.beginPath()
        ctx.moveTo(x, y)
        ctx.lineTo(x - w, yBase)
        ctx.lineTo(x + w, yBase)
        ctx.closePath()
        ctx.fill()
    }

    private func renderText(ctx: any RenderContext, x: Double, text: String, y: Double) {
        ctx.save()
        if let font = textFont { ctx.setFont(font) }
        let renderX = x - ctx.measureText(text).width / 2
        ctx.fillText(text, renderX, y)
        ctx.restore()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Bend", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 200) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 190))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(Bend("Full"), index: 0)
        _ = notes[2].addModifier(Bend("1/2", release: true), index: 0)

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
