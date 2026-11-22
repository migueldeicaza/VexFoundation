// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/bend.ts` (VexFlow 5.0.0).

import Foundation

public enum BendError: Error, LocalizedError, Equatable, Sendable {
    case missingLastBendState

    public var errorDescription: String? {
        switch self {
        case .missingLastBendState:
            return "Internal bend state missing trailing bend phrase."
        }
    }
}

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
    public var releaseWidth: Double = 8
    public var bendWidth: Double = 8

    public init(releaseWidth: Double = 8, bendWidth: Double = 8) {
        self.releaseWidth = releaseWidth
        self.bendWidth = bendWidth
    }
}

// MARK: - Bend

/// Bend implements tablature bends.
public final class Bend: Modifier {

    override public class var category: String { "Bend" }

    public static let UP = 0
    public static let DOWN = 1

    // MARK: - Static Format

    /// Arrange bends in `ModifierContext`.
    @discardableResult
    public static func format(
        _ bends: [Bend],
        state: inout ModifierContextState
    ) -> Bool {
        if bends.isEmpty { return false }

        var lastWidth: Double = 0
        // Format Bends
        for bend in bends {
            let note = bend.checkAttachedNote()

            if let tabNote = note as? TabNote {
                let stringPos = Double(tabNote.leastString()) - 1
                if state.topTextLine < stringPos {
                    state.topTextLine = stringPos
                }
            }
            _ = bend.setXShift(lastWidth)
            lastWidth = bend.getWidth()
            _ = bend.setTextLine(state.topTextLine)
        }

        state.rightShift += lastWidth
        state.topTextLine += 1
        return true
    }

    // MARK: - Properties

    public var tap: String
    public var phrase: [BendPhrase]
    public var styleLine: ElementStyle = Metrics.getStyle("Bend.line")
    public var renderOptions: BendRenderOptions

    @available(*, deprecated, renamed: "renderOptions")
    public var bendRenderOptions: BendRenderOptions {
        get { renderOptions }
        set { renderOptions = newValue }
    }

    // MARK: - Init

    /// Example of a phrase:
    /// ```
    /// [BendPhrase(type: Bend.UP, text: "whole", width: 8),
    ///  BendPhrase(type: Bend.DOWN, text: "whole", width: 8),
    ///  BendPhrase(type: Bend.UP, text: "half", width: 8)]
    /// ```
    public init(_ phrase: [BendPhrase]) {
        tap = ""
        renderOptions = BendRenderOptions(releaseWidth: 8, bendWidth: 8)
        self.phrase = phrase
        super.init()

        xShift = 0
        updateWidth()
    }

    /// VexFlow 4 constructor: one bend with `text`, plus a release if `release` is true.
    @available(*, deprecated, message: "Use Bend(_ phrase: [BendPhrase]).")
    public convenience init(_ text: String, release: Bool = false, phrase: [BendPhrase]? = nil) {
        if let phrase {
            self.init(phrase)
        } else {
            var phrases: [BendPhrase] = [BendPhrase(type: Bend.UP, text: text)]
            if release {
                phrases.append(BendPhrase(type: Bend.DOWN, text: ""))
            }
            self.init(phrases)
        }
    }

    // MARK: - Setters

    /// Set the element style used for rendering the lines.
    @discardableResult
    public func setStyleLine(_ style: ElementStyle) -> Self {
        styleLine = style
        return self
    }

    /// Get the element style used for rendering the lines.
    public func getStyleLine() -> ElementStyle {
        styleLine
    }

    /// Set horizontal shift in pixels.
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

    public func getTextHeight() -> Double {
        let element = VexElement(category: "Bend")
        element.setText(phrase.first?.text ?? "")
        return element.getHeight()
    }

    // MARK: - Update Width

    /// Recalculate width.
    @discardableResult
    func updateWidth() -> Self {
        func measureText(_ text: String) -> Double {
            let element = VexElement(category: "Bend")
            element.setText(text)
            return element.getWidth()
        }

        var totalWidth: Double = 0
        for i in 0..<phrase.count {
            if let w = phrase[i].width {
                totalWidth += w
            } else {
                let additionalWidth = phrase[i].type == Bend.UP
                    ? renderOptions.bendWidth
                    : renderOptions.releaseWidth

                let w = max(additionalWidth, measureText(phrase[i].text)) + 3
                phrase[i].width = w
                phrase[i].drawWidth = w / 2
                totalWidth += w
            }
        }

        _ = setWidth(totalWidth + xShift)
        return self
    }

    // MARK: - Draw

    /// Draw the bend on the rendering context.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        setRendered()

        var start = note.getModifierStartXY(position: .right, index: index ?? 0)
        start.x += 3
        start.y += 0.5
        let xShift = self.xShift

        let stave = try note.checkStaveThrowing()
        let spacing = stave.getSpacingBetweenLines()
        let lowestY = note.getYs().min() ?? 0
        // this.textLine is relative to top string in the group.
        let bendHeight = start.y - ((textLine + 1) * spacing + start.y - lowestY) + 3
        let annotationY = start.y - ((textLine + 1) * spacing + start.y - lowestY) - 1

        let styleLine = self.styleLine
        let fontInfo = self.fontInfo

        func renderBend(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
            let cpX = x + width
            let cpY = y

            applyStyle(context: ctx, style: styleLine)
            ctx.beginPath()
            ctx.moveTo(x, y)
            ctx.quadraticCurveTo(cpX, cpY, x + width, height)
            ctx.stroke()
        }

        func renderRelease(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
            applyStyle(context: ctx, style: styleLine)
            ctx.beginPath()
            ctx.moveTo(x, height)
            ctx.quadraticCurveTo(x + width, height, x + width, y)
            ctx.stroke()
        }

        func renderArrowHead(_ x: Double, _ y: Double, _ direction: Double) {
            let width: Double = 4
            let yBase = y + width * direction

            ctx.beginPath()
            ctx.moveTo(x, y) // tip of the arrow
            ctx.lineTo(x - width, yBase)
            ctx.lineTo(x + width, yBase)
            ctx.closePath()
            ctx.fill()
        }

        func renderText(_ x: Double, _ text: String) {
            ctx.setFont(fontInfo)
            let renderX = x - ctx.measureText(text).width / 2
            ctx.fillText(text, renderX, annotationY)
        }

        var lastBend: BendPhrase?
        var lastBendDrawWidth: Double = 0
        var lastDrawnWidth: Double = 0
        if !tap.isEmpty {
            let tapStart = note.getModifierStartXY(position: .center, index: index ?? 0)
            renderText(tapStart.x, tap)
        }

        for i in 0..<phrase.count {
            if phrase[i].drawWidth == nil { phrase[i].drawWidth = 0 }
            if i == 0 { phrase[i].drawWidth = (phrase[i].drawWidth ?? 0) + xShift }
            let bendDrawWidth = phrase[i].drawWidth ?? 0

            lastDrawnWidth = bendDrawWidth + lastBendDrawWidth - (i == 1 ? xShift : 0)
            if phrase[i].type == Bend.UP {
                if let lb = lastBend, lb.type == Bend.UP {
                    renderArrowHead(start.x, bendHeight, +1)
                }

                renderBend(start.x, start.y, lastDrawnWidth, bendHeight)
            }

            if phrase[i].type == Bend.DOWN {
                if let lb = lastBend, lb.type == Bend.UP {
                    renderRelease(start.x, start.y, lastDrawnWidth, bendHeight)
                }

                if let lb = lastBend, lb.type == Bend.DOWN {
                    renderArrowHead(start.x, start.y, -1)
                    renderRelease(start.x, start.y, lastDrawnWidth, bendHeight)
                }

                if lastBend == nil {
                    lastDrawnWidth = bendDrawWidth
                    renderRelease(start.x, start.y, lastDrawnWidth, bendHeight)
                }
            }

            renderText(start.x + lastDrawnWidth, phrase[i].text)
            phrase[i].x = start.x
            lastBend = phrase[i]
            lastBendDrawWidth = bendDrawWidth

            start.x += lastDrawnWidth
        }

        guard let lb = lastBend, let lastBendX = lb.x else {
            throw BendError.missingLastBendState
        }

        // Final arrowhead and text
        if lb.type == Bend.UP {
            renderArrowHead(lastBendX + lastDrawnWidth, bendHeight, +1)
        } else if lb.type == Bend.DOWN {
            renderArrowHead(lastBendX + lastDrawnWidth, start.y, -1)
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Bend", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 200) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500, height: 190))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(Bend([BendPhrase(type: Bend.UP, text: "Full")]), index: 0)
        _ = notes[2].addModifier(Bend([BendPhrase(type: Bend.UP, text: "1/2"), BendPhrase(type: Bend.DOWN, text: "")]), index: 0)

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
