// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Annotation Justification

public enum AnnotationHorizontalJustify: Int {
    case left = 1
    case center = 2
    case right = 3
    case centerStem = 4
}

public enum AnnotationVerticalJustify: Int {
    case top = 1
    case center = 2
    case bottom = 3
    case centerStem = 4
}

// MARK: - Annotation

/// Modifier that renders text annotations above or below notes.
public final class Annotation: Modifier {

    override public class var category: String { "Annotation" }
    public static var minAnnotationPadding: Double {
        (Glyph.MUSIC_FONT_STACK.first?.lookupMetric("noteHead.minPadding") as? Double) ?? 2
    }

    // MARK: - Properties

    public let text: String
    public var horizontalJustification: AnnotationHorizontalJustify = .center
    public var verticalJustification: AnnotationVerticalJustify = .top

    // MARK: - Init

    public init(_ text: String) {
        self.text = text
        super.init()
        resetFont()
        // Estimate text width
        _ = setWidth(Double(text.count) * 7.0)
    }

    // MARK: - Justification

    @discardableResult
    public func setVerticalJustification(_ just: AnnotationVerticalJustify) -> Self {
        verticalJustification = just
        return self
    }

    public func getJustification() -> AnnotationHorizontalJustify {
        horizontalJustification
    }

    @discardableResult
    public func setJustification(_ just: AnnotationHorizontalJustify) -> Self {
        horizontalJustification = just
        return self
    }

    // MARK: - Static Format

    @discardableResult
    public static func format(_ annotations: [Annotation], state: inout ModifierContextState) -> Bool {
        if annotations.isEmpty { return false }

        var leftWidth: Double = 0
        var rightWidth: Double = 0
        var maxLeftGlyphWidth: Double = 0
        var maxRightGlyphWidth: Double = 0

        for annotation in annotations {
            let note = annotation.checkAttachedNote()
            let textFormatter = TextFormatter.create(
                font: annotation.fontInfo,
                context: note.getStave()?.getContext() ?? annotation.getContext()
            )
            let textWidth = adjustedTextWidth(
                textFormatter.getWidthForTextInPx(annotation.text),
                text: annotation.text,
                font: annotation.fontInfo
            )
            let textHeight = textFormatter.getYForStringInPx(annotation.text).height
            let textLines = (2 + textHeight) / Tables.STAVE_LINE_DISTANCE
            var verticalSpaceNeeded = textLines
            let glyphWidth = note.getGlyphWidth()
            _ = annotation.setWidth(textWidth)

            if annotation.horizontalJustification == .left {
                maxLeftGlyphWidth = max(glyphWidth, maxLeftGlyphWidth)
                leftWidth = max(leftWidth, textWidth) + Self.minAnnotationPadding
            } else if annotation.horizontalJustification == .right {
                maxRightGlyphWidth = max(glyphWidth, maxRightGlyphWidth)
                rightWidth = max(rightWidth, textWidth)
            } else {
                leftWidth = max(leftWidth, textWidth / 2) + Self.minAnnotationPadding
                rightWidth = max(rightWidth, textWidth / 2)
                maxLeftGlyphWidth = max(glyphWidth / 2, maxLeftGlyphWidth)
                maxRightGlyphWidth = max(glyphWidth / 2, maxRightGlyphWidth)
            }

            let stave = note.getStave()
            let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
            var stemHeight: Double = 0
            var lines = 5

            if let tabNote = note as? TabNote {
                if tabNote.renderOptions.drawStem, let stem = tabNote.getStem() {
                    stemHeight = abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
                }
            } else if let stemmable = note as? StemmableNote, let stem = stemmable.getStem(), note.getNoteType() == "n" {
                stemHeight = abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
            }

            if let stave {
                lines = stave.getNumLines()
            }

            if annotation.verticalJustification == .top {
                var noteLine = note.getLineNumber(isTopNote: true)
                if let tabNote = note as? TabNote {
                    noteLine = Double(lines) - (Double(tabNote.leastString()) - 0.5)
                }
                if stemDirection == Stem.UP {
                    noteLine += stemHeight
                }

                let curTop = noteLine + state.topTextLine + 0.5
                if curTop < Double(lines) {
                    _ = annotation.setTextLine(Double(lines) - noteLine)
                    verticalSpaceNeeded += Double(lines) - noteLine
                    state.topTextLine = verticalSpaceNeeded
                } else {
                    _ = annotation.setTextLine(state.topTextLine)
                    state.topTextLine += verticalSpaceNeeded
                }
            } else if annotation.verticalJustification == .bottom {
                var noteLine = Double(lines) - note.getLineNumber()
                if let tabNote = note as? TabNote {
                    noteLine = Double(tabNote.greatestString() - 1)
                }
                if stemDirection == Stem.DOWN {
                    noteLine += stemHeight
                }

                let curBottom = noteLine + state.textLine + 1
                if curBottom < Double(lines) {
                    _ = annotation.setTextLine(Double(lines) - curBottom)
                    verticalSpaceNeeded += Double(lines) - curBottom
                    state.textLine = verticalSpaceNeeded
                } else {
                    _ = annotation.setTextLine(state.textLine)
                    state.textLine += verticalSpaceNeeded
                }
            } else {
                _ = annotation.setTextLine(state.textLine)
            }
        }

        let rightOverlap = min(
            max(rightWidth - maxRightGlyphWidth, 0),
            max(rightWidth - state.rightShift, 0)
        )
        let leftOverlap = min(
            max(leftWidth - maxLeftGlyphWidth, 0),
            max(leftWidth - state.leftShift, 0)
        )
        state.leftShift += leftOverlap
        state.rightShift += rightOverlap
        return true
    }

    // MARK: - Draw

    override public func draw() throws {
        let ctx = try checkContext()
        let note = checkAttachedNote()
        setRendered()

        let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
        let start = note.getModifierStartXY(position: .above, index: checkIndex())

        ctx.save()
        applyStyle(context: ctx, style: getStyle())
        _ = ctx.openGroup("annotation", getAttribute("id") ?? "")
        ctx.setFont(fontInfo)

        let textFormatter = TextFormatter.create(font: fontInfo, context: ctx)
        let textWidth = Self.adjustedTextWidth(
            textFormatter.getWidthForTextInPx(text),
            text: text,
            font: fontInfo
        )
        let textHeight = textFormatter.getYForStringInPx(text).height

        // Calculate x position based on horizontal justification
        var x: Double
        switch horizontalJustification {
        case .left:
            x = start.x
        case .right:
            x = start.x - textWidth
        case .center:
            x = start.x - textWidth / 2
        case .centerStem:
            if let stemmable = note as? StemmableNote {
                x = stemmable.getStemX() - textWidth / 2
            } else {
                x = start.x - textWidth / 2
            }
        }

        // Calculate y position based on vertical justification
        let stave = note.checkStave()
        var stemExtents: (topY: Double, baseY: Double)?
        var spacing: Double = 0
        if note.hasStem() {
            stemExtents = note.getStemExtents()
            spacing = stave.getSpacingBetweenLines()
        }
        var y: Double

        switch verticalJustification {
        case .bottom:
            y = note.getYs().max() ?? start.y
            y += (textLine + 1) * Tables.STAVE_LINE_DISTANCE + textHeight
            if note.hasStem(), stemDirection == Stem.DOWN, let stemExtents {
                y = max(y, stemExtents.topY + textHeight + spacing * textLine)
            }
        case .center:
            let yt = note.getYForTopText(textLine) - 1
            let yb = stave.getYForBottomText(textLine)
            y = yt + (yb - yt) / 2 + textHeight / 2
        case .top:
            let topY = note.getYs().min() ?? start.y
            y = topY - (textLine + 1) * Tables.STAVE_LINE_DISTANCE
            if note.hasStem(), stemDirection == Stem.UP, let stemExtents {
                if stemExtents.topY < stave.getTopLineTopY() {
                    spacing = Tables.STAVE_LINE_DISTANCE
                }
                y = min(y, stemExtents.topY - spacing * (textLine + 1))
            }
        case .centerStem:
            let extents = note.getStemExtents()
            y = extents.topY + (extents.baseY - extents.topY) / 2 + textHeight / 2
        }

        ctx.fillText(text, x, y)

        ctx.closeGroup()
        restoreStyle(context: ctx, style: getStyle())
        ctx.restore()
    }

    private static func adjustedTextWidth(_ width: Double, text: String, font: FontInfo) -> Double {
        // Upstream browser text metrics for default Arial are slightly wider than
        // CoreText-based measurements on macOS. Apply a narrow correction so
        // annotation layout matches upstream modifier spacing.
        let family = font.family.lowercased()
        guard family.contains("arial") else { return width }
        let glyphCount = max(text.count, 1)
        var correction = 1.094 + (4.365 / Double(glyphCount))
        if glyphCount <= 4 { correction += 0.006 }
        return width + correction
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Annotation", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500, height: 170))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let notes = score.notes("C5/q, D5, E5, F5")
        _ = notes[0].addModifier(f.Annotation(text: "p", vJustify: .bottom))
        _ = notes[1].addModifier(f.Annotation(text: "mf", vJustify: .bottom))
        _ = notes[2].addModifier(f.Annotation(text: "f", vJustify: .bottom))
        _ = notes[3].addModifier(f.Annotation(text: "ff", vJustify: .bottom))

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
