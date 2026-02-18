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

    override public class var CATEGORY: String { "Annotation" }

    // MARK: - Properties

    public let text: String
    public var horizontalJustification: AnnotationHorizontalJustify = .center
    public var verticalJustification: AnnotationVerticalJustify = .top

    // MARK: - Init

    public init(_ text: String) {
        self.text = text
        super.init()
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
            let glyphWidth = note.getGlyphWidth()

            // Estimate text dimensions
            let textWidth = annotation.getWidth()
            let textHeight: Double = 12 // approximate line height

            // Distribute width based on justification
            if annotation.horizontalJustification == .left {
                maxLeftGlyphWidth = max(glyphWidth, maxLeftGlyphWidth)
                leftWidth = max(textWidth, leftWidth)
            } else if annotation.horizontalJustification == .right {
                maxRightGlyphWidth = max(glyphWidth, maxRightGlyphWidth)
                rightWidth = max(textWidth, rightWidth)
            } else {
                leftWidth = max(textWidth / 2, leftWidth)
                rightWidth = max(textWidth / 2, rightWidth)
                maxLeftGlyphWidth = max(glyphWidth / 2, maxLeftGlyphWidth)
                maxRightGlyphWidth = max(glyphWidth / 2, maxRightGlyphWidth)
            }

            // Set vertical positioning
            let vJust = annotation.verticalJustification

            if vJust == .top {
                _ = annotation.setTextLine(state.topTextLine)
                state.topTextLine += textHeight / 10 + 1
            } else if vJust == .bottom {
                _ = annotation.setTextLine(state.textLine)
                state.textLine += textHeight / 10 + 1
            }
        }

        let leftOverlap = max(leftWidth - maxLeftGlyphWidth, 0)
        let rightOverlap = max(rightWidth - maxRightGlyphWidth, 0)
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

        let index = checkIndex()

        // Get starting position
        guard let staveNote = note as? StaveNote else { return }
        let start = staveNote.getModifierStartXY(position: position, index: index)

        ctx.save()
        applyStyle(context: ctx, style: getStyle())
        _ = ctx.openGroup("annotation", getAttribute("id") ?? "")
        ctx.setFont(getFont())

        // Estimate text dimensions
        let textWidth = getWidth()
        let textHeight: Double = 12

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
        let spacing = stave.getSpacingBetweenLines()
        var y: Double

        switch verticalJustification {
        case .bottom:
            y = stave.getYForBottomText(textLine)
            if note.hasStem() && stemDirection == Stem.DOWN {
                let extents = note.getStemExtents()
                y = max(y, extents.topY + spacing * (textLine + 2))
            }
        case .center:
            let topY = note.getYForTopText(textLine) - 1
            let bottomY = stave.getYForBottomText(textLine)
            y = (topY + bottomY) / 2 + textHeight / 2
        case .top:
            y = min(
                stave.getYForTopText(textLine),
                note.getYs().min() ?? 0
            )
            if note.hasStem() && stemDirection == Stem.UP {
                y = min(y, note.getStemExtents().topY - 5)
            }
            y -= textHeight / 2 + spacing * textLine
        case .centerStem:
            let extents = note.getStemExtents()
            y = (extents.topY + extents.baseY) / 2 + textHeight / 2
        }

        ctx.fillText(text, x, y)

        ctx.closeGroup()
        restoreStyle(context: ctx, style: getStyle())
        ctx.restore()
    }
}
