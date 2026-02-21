// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum ModifierError: Error, LocalizedError, Equatable, Sendable {
    case noNote
    case noIndex
    case noModifierContext
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .noNote:
            return "Modifier has no note."
        case .noIndex:
            return "Modifier has an invalid index."
        case .noModifierContext:
            return "Modifier context required."
        case .notImplemented(let category):
            return "draw() not implemented for modifier \(category)."
        }
    }
}

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

    private static func fallbackNote() -> Note {
        Note(NoteStruct(duration: .quarter))
    }

    // MARK: - Width

    public func getWidth() -> Double { modifierWidth }

    @discardableResult
    public func setWidth(_ width: Double) -> Self {
        modifierWidth = width
        return self
    }

    // MARK: - Note

    public func getNote() -> Note {
        (try? getNoteThrowing()) ?? Self.fallbackNote()
    }

    public func getNoteThrowing() throws -> Note {
        guard let note else {
            throw ModifierError.noNote
        }
        return note
    }

    public func checkAttachedNote() -> Note {
        (try? checkAttachedNoteThrowing()) ?? Self.fallbackNote()
    }

    public func checkAttachedNoteThrowing() throws -> Note {
        guard index != nil else {
            throw ModifierError.noIndex
        }
        guard let note else {
            throw ModifierError.noNote
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
        (try? checkIndexThrowing()) ?? 0
    }

    public func checkIndexThrowing() throws -> Int {
        guard let index else {
            throw ModifierError.noIndex
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
        (try? checkModifierContextThrowing()) ?? ModifierContext()
    }

    public func checkModifierContextThrowing() throws -> ModifierContext {
        guard let modifierContext else {
            throw ModifierError.noModifierContext
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
        throw ModifierError.notImplemented(getCategory())
    }
}
