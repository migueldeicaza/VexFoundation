// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/annotation.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - Annotation Justification

public enum AnnotationHorizontalJustify: Int, Sendable {
    case left = 1
    case center = 2
    case right = 3
    case centerStem = 4
}

public enum AnnotationVerticalJustify: Int, Sendable {
    case top = 1
    case center = 2
    case bottom = 3
    case centerStem = 4
}

// MARK: - Annotation

/// Annotations are modifiers that can be attached to notes.
public final class Annotation: Modifier {

    override public class var category: String { "Annotation" }

    /// Text annotations can be positioned and justified relative to the note.
    public static let horizontalJustifyString: [String: AnnotationHorizontalJustify] = [
        "left": .left,
        "right": .right,
        "center": .center,
        "centerStem": .centerStem,
    ]

    public static let verticalJustifyString: [String: AnnotationVerticalJustify] = [
        "above": .top,
        "top": .top,
        "below": .bottom,
        "bottom": .bottom,
        "center": .center,
        "centerStem": .centerStem,
    ]

    /// Use the same padding for annotations as note head so the
    /// words don't run into each other.
    public static var minAnnotationPadding: Double {
        Metrics.getDouble("NoteHead.minPadding")
    }

    // MARK: - Properties

    public var horizontalJustification: AnnotationHorizontalJustify
    public var verticalJustification: AnnotationVerticalJustify

    // MARK: - Init

    /// Create a new `Annotation` with the string `text`.
    public init(_ text: String) {
        horizontalJustification = .center
        // warning: the default in the constructor is TOP, but in the factory the default is BOTTOM.
        // this is to support legacy application that may expect this.
        verticalJustification = .top
        super.init()
        self.text = text
    }

    // MARK: - Justification

    /// Set vertical position of text (above or below stave).
    @discardableResult
    public func setVerticalJustification(_ just: AnnotationVerticalJustify) -> Self {
        verticalJustification = just
        return self
    }

    /// Set vertical position of text from a string (`above`, `below`, `top`, ...).
    /// Unknown strings leave the justification unchanged.
    @discardableResult
    public func setVerticalJustification(_ just: String) -> Self {
        if let value = Self.verticalJustifyString[just] {
            verticalJustification = value
        }
        return self
    }

    /// Get horizontal justification.
    public func getJustification() -> AnnotationHorizontalJustify {
        horizontalJustification
    }

    /// Set horizontal justification.
    @discardableResult
    public func setJustification(_ just: AnnotationHorizontalJustify) -> Self {
        horizontalJustification = just
        return self
    }

    /// Set horizontal justification from a string (`left`, `right`, `center`, `centerStem`).
    /// Unknown strings leave the justification unchanged.
    @discardableResult
    public func setJustification(_ just: String) -> Self {
        if let value = Self.horizontalJustifyString[just] {
            horizontalJustification = value
        }
        return self
    }

    // MARK: - Static Format

    /// Arrange annotations within a `ModifierContext`.
    @discardableResult
    public static func format(_ annotations: [Annotation], state: inout ModifierContextState) -> Bool {
        if annotations.isEmpty { return false }

        var leftWidth: Double = 0
        var rightWidth: Double = 0
        var maxLeftGlyphWidth: Double = 0
        var maxRightGlyphWidth: Double = 0

        for annotation in annotations {
            // Text height is expressed in fractional stave spaces.
            let textLines = (2 + VexFont.convertSizeToPixelValue(annotation.fontInfo.size)) / Tables.STAVE_LINE_DISTANCE
            var verticalSpaceNeeded = textLines

            let note = annotation.checkAttachedNote()
            let glyphWidth = note.getGlyphWidth()
            // Get the text width from the font metrics.
            let textWidth = annotation.getWidth()
            if annotation.horizontalJustification == .right {
                maxLeftGlyphWidth = max(glyphWidth, maxLeftGlyphWidth)
                leftWidth = max(leftWidth, textWidth) + minAnnotationPadding
            } else if annotation.horizontalJustification == .left {
                maxRightGlyphWidth = max(glyphWidth, maxRightGlyphWidth)
                rightWidth = max(rightWidth, textWidth)
            } else {
                leftWidth = max(leftWidth, textWidth / 2) + minAnnotationPadding
                rightWidth = max(rightWidth, textWidth / 2)
                maxLeftGlyphWidth = max(glyphWidth / 2, maxLeftGlyphWidth)
                maxRightGlyphWidth = max(glyphWidth / 2, maxRightGlyphWidth)
            }

            let stave = note.getStave()
            let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
            var stemHeight: Double = 0
            var lines: Double = 5

            if let tabNote = note as? TabNote {
                if tabNote.renderOptions.drawStem {
                    if let stem = tabNote.getStem() {
                        stemHeight = abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
                    }
                } else {
                    stemHeight = 0
                }
            } else if let stemmable = note as? StemmableNote {
                if let stem = stemmable.getStem(), note.getNoteType() == "n" {
                    stemHeight = abs(stem.getHeight()) / Tables.STAVE_LINE_DISTANCE
                }
            }
            if let stave {
                lines = Double(stave.getNumLines())
            }

            if annotation.verticalJustification == .top {
                var noteLine = note.getLineNumber(isTopNote: true)
                if let tabNote = note as? TabNote {
                    noteLine = lines - (Double(tabNote.leastString()) - 0.5)
                }
                if stemDirection == Stem.UP {
                    noteLine += stemHeight
                }
                let curTop = noteLine + state.topTextLine + 0.5
                if curTop < lines {
                    _ = annotation.setTextLine(lines - noteLine)
                    verticalSpaceNeeded += lines - noteLine
                    state.topTextLine = verticalSpaceNeeded
                } else {
                    _ = annotation.setTextLine(state.topTextLine)
                    state.topTextLine += verticalSpaceNeeded
                }
            } else if annotation.verticalJustification == .bottom {
                var noteLine = lines - note.getLineNumber()
                if let tabNote = note as? TabNote {
                    noteLine = Double(tabNote.greatestString()) - 1
                }
                if stemDirection == Stem.DOWN {
                    noteLine += stemHeight
                }
                let curBottom = noteLine + state.textLine + 1
                if curBottom < lines {
                    _ = annotation.setTextLine(lines - curBottom)
                    verticalSpaceNeeded += lines - curBottom
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

    /// Render text beside the note.
    override public func draw() throws {
        let ctx = try checkContext()
        let note = try checkAttachedNoteThrowing()
        let stemDirection = note.hasStem() ? note.getStemDirection() : Stem.UP
        let start = note.getModifierStartXY(position: .above, index: index ?? 0)

        setRendered()
        _ = ctx.openGroup("annotation", getAttribute("id"))

        let textWidth = getWidth()
        let textHeight = VexFont.convertSizeToPixelValue(fontInfo.size)
        var x: Double
        var y: Double

        switch horizontalJustification {
        case .left:
            x = start.x
        case .right:
            x = start.x - textWidth
        case .center:
            x = start.x - textWidth / 2
        case .centerStem:
            x = ((note as? StemmableNote)?.getStemX() ?? start.x) - textWidth / 2
        }

        var stemExt: (topY: Double, baseY: Double) = (0, 0)
        var spacing: Double = 0
        let hasStem = note.hasStem()
        let stave = try note.checkStaveThrowing()

        // The position of the text varies based on whether or not the note
        // has a stem.
        if hasStem, let stemmable = note as? StemmableNote {
            stemExt = try stemmable.checkStemThrowing().getExtents()
            spacing = stave.getSpacingBetweenLines()
        }

        switch verticalJustification {
        case .bottom:
            // Use the largest (lowest) Y value
            let ys = note.getYs()
            y = ys.max() ?? 0
            y += (textLine + 1) * Tables.STAVE_LINE_DISTANCE + textHeight
            if hasStem && stemDirection == Stem.DOWN {
                y = max(y, stemExt.topY + textHeight + spacing * textLine)
            }
        case .center:
            let yt = note.getYForTopText(textLine) - 1
            let yb = stave.getYForBottomText(textLine)
            y = yt + (yb - yt) / 2 + textHeight / 2
        case .top:
            let topY = note.getYs().min() ?? 0
            y = topY - (textLine + 1) * Tables.STAVE_LINE_DISTANCE
            if hasStem && stemDirection == Stem.UP {
                // If the stem is above the stave already, go with default line width vs. actual
                // since the lines between don't really matter.
                spacing = stemExt.topY < stave.getTopLineTopY() ? Tables.STAVE_LINE_DISTANCE : spacing
                y = min(y, stemExt.topY - spacing * (textLine + 1))
            }
        case .centerStem:
            let extents = note.getStemExtents()
            y = extents.topY + (extents.baseY - extents.topY) / 2 + textHeight / 2
        }

        self.x = x
        self.y = y
        renderText(ctx, xPos: 0, yPos: 0)
        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Annotation", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 180) { ctx in
        ctx.clear()

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
