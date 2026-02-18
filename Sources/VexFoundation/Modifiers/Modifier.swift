// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Modifier Position

/// Positions where note modifiers can appear.
public enum ModifierPosition: Int, Sendable {
    case center = 0
    case left = 1
    case right = 2
    case above = 3
    case below = 4
}

// MARK: - Modifier

/// Base class for notational elements that modify a `Note`.
/// Examples: Accidental, Annotation, Stroke, Dot, etc.
open class Modifier: VexElement {

    override open class var category: String { "Modifier" }

    public static let positionString: [String: ModifierPosition] = [
        "center": .center, "above": .above, "below": .below,
        "left": .left, "right": .right,
    ]

    // MARK: - Properties

    public weak var note: Note?
    public var index: Int?
    public var modifierWidth: Double = 0
    public var textLine: Double = 0
    public var position: ModifierPosition = .left
    public var yShift: Double = 0
    public var xShift: Double = 0
    public weak var modifierContext: ModifierContext?
    private var spacingFromNextModifier: Double = 0

    // MARK: - Width

    public func getWidth() -> Double { modifierWidth }

    @discardableResult
    public func setWidth(_ width: Double) -> Self {
        modifierWidth = width
        return self
    }

    // MARK: - Note

    public func getNote() -> Note {
        guard let note else {
            fatalError("[VexError] NoNote: Modifier has no note.")
        }
        return note
    }

    public func checkAttachedNote() -> Note {
        guard index != nil else {
            fatalError("[VexError] NoIndex: Can't draw \(getCategory()) without an index.")
        }
        guard let note else {
            fatalError("[VexError] NoNote: Can't draw \(getCategory()) without a note.")
        }
        return note
    }

    @discardableResult
    public func setNote(_ note: Note) -> Self {
        self.note = note
        return self
    }

    // MARK: - Index

    public func getIndex() -> Int? { index }

    public func checkIndex() -> Int {
        guard let index else {
            fatalError("[VexError] NoIndex: Modifier has an invalid index.")
        }
        return index
    }

    @discardableResult
    public func setIndex(_ index: Int) -> Self {
        self.index = index
        return self
    }

    // MARK: - Position

    public func getPosition() -> ModifierPosition { position }

    @discardableResult
    public func setPosition(_ position: ModifierPosition) -> Self {
        self.position = position
        return self
    }

    // MARK: - Text Line

    @discardableResult
    public func setTextLine(_ line: Double) -> Self {
        self.textLine = line
        return self
    }

    // MARK: - Shifts

    @discardableResult
    public func setYShift(_ y: Double) -> Self {
        self.yShift = y
        return self
    }

    @discardableResult
    public func setXShift(_ x: Double) -> Self {
        self.xShift = 0
        if position == .left {
            self.xShift -= x
        } else {
            self.xShift += x
        }
        return self
    }

    public func getXShift() -> Double { xShift }

    // MARK: - Modifier Context

    @discardableResult
    public func setModifierContext(_ mc: ModifierContext) -> Self {
        modifierContext = mc
        return self
    }

    public func getModifierContext() -> ModifierContext? { modifierContext }

    public func checkModifierContext() -> ModifierContext {
        guard let modifierContext else {
            fatalError("[VexError] NoModifierContext: Modifier Context Required.")
        }
        return modifierContext
    }

    // MARK: - Spacing

    public func setSpacingFromNextModifier(_ x: Double) {
        spacingFromNextModifier = x
    }

    public func getSpacingFromNextModifier() -> Double {
        spacingFromNextModifier
    }

    // MARK: - Align Sub Notes

    /// Aligns sub-notes (e.g., grace notes) with the parent note's tick context position.
    public func alignSubNotesWithNote(_ subNotes: [Note], _ note: Note) {
        let tickContext = note.checkTickContext()
        let metrics = tickContext.getMetrics()
        let stave = note.getStave()
        let subNoteXOffset = tickContext.getX() - metrics.modLeftPx - metrics.modRightPx
            + getSpacingFromNextModifier()

        for subNote in subNotes {
            let subTickContext = subNote.checkTickContext()
            if let stave { _ = subNote.setStave(stave) }
            subTickContext.setXOffset(subNoteXOffset)
        }
    }

    // MARK: - Draw

    override open func draw() throws {
        _ = try checkContext()
        fatalError("[VexError] NotImplemented: draw() not implemented for this modifier.")
    }
}
