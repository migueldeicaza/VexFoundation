// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/modifier.ts` (VexFlow 5.8.0).

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

/// `Modifier` is an abstract interface for notational elements that modify
/// a `Note`. Examples of modifiers are `Accidental`, `Annotation`, `Stroke`, etc.
///
/// For a `Modifier` instance to be positioned correctly, it must be part of
/// a `ModifierContext`. All modifiers in the same context are rendered relative to
/// one another.
///
/// Typically, all modifiers to a note are part of the same `ModifierContext` instance. Also,
/// in multi-voice staves, all modifiers to notes on the same `tick` are part of the same
/// `ModifierContext`. This ensures that multiple voices don't trample all over each other.
///
/// `x`, `y`, `xShift`, `yShift` and `width` are inherited from `VexElement`.
open class Modifier: VexElement {

    /// Modifiers category string. Every modifier has a different category.
    /// The `ModifierContext` uses this to determine the type and order of the modifiers.
    override open class var category: String { "Modifier" }

    /// Modifiers can be positioned almost anywhere, relative to a note.
    public typealias Position = ModifierPosition

    public static let positionString: [String: ModifierPosition] = [
        "center": .center, "above": .above, "below": .below,
        "left": .left, "right": .right,
    ]

    /// Upstream name of `positionString`.
    public static var PositionString: [String: ModifierPosition] { positionString }

    // MARK: - Properties

    // Modifiers are attached to a note and an index. An index is a specific head in a chord.
    public weak var note: Note?
    public var index: Int?

    /// The `textLine` is reserved space above or below a stave.
    public var textLine: Double = 0
    public var position: ModifierPosition = .left

    public var spacingFromNextModifier: Double = 0
    public weak var modifierContext: ModifierContext?

    private static func fallbackNote() -> Note {
        Note(NoteStruct(duration: .quarter))
    }

    // MARK: - Init

    public override init() {
        super.init(category: nil)
        width = 0
        textLine = 0
        position = .left
        spacingFromNextModifier = 0
    }

    /// Source-compatibility alias for `width`.
    @available(*, deprecated, renamed: "width")
    public var modifierWidth: Double {
        get { width }
        set { width = newValue }
    }

    /// Called when position changes.
    open func reset() {
        // DO NOTHING.
    }

    // MARK: - Note

    /// Get attached note (`StaveNote`, `TabNote`, etc.)
    public func getNote() -> Note {
        (try? getNoteThrowing()) ?? Self.fallbackNote()
    }

    public func getNoteThrowing() throws -> Note {
        guard let note else {
            throw ModifierError.noNote
        }
        return note
    }

    /// Used in draw() to check and get the attached note (`StaveNote`, `TabNote`, etc.).
    /// Also verifies that the index is valid.
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

    /// Set attached note.
    @discardableResult
    open func setNote(_ note: Note) -> Self {
        self.note = note
        return self
    }

    // MARK: - Index

    /// Get note index, which is a specific note in a chord.
    public func getIndex() -> Int? { index }

    /// Vertical sort key for a selected pitched head or TAB fret. Higher positions sort first. (VexFlow 5.8.0)
    ///
    /// A TAB fret gives `-str`, because string 1 is the highest string.
    public func getAttachedLine() throws -> Double {
        let note = try checkAttachedNoteThrowing()
        let index = try checkIndexThrowing()
        if let tab = note as? TabNote {
            let positions = tab.getPositions()
            guard index >= 0 && index < positions.count else {
                throw VexError("BadArguments", "TAB modifier index must select a fret position.")
            }
            return -Double(positions[index].str)
        }
        let keyProps = note.getKeyProps()
        guard index >= 0 && index < keyProps.count else {
            throw VexError("BadArguments", "Modifier index must select a notehead.")
        }
        return keyProps[index].line
    }

    /// Check and get note index, which is a specific note in a chord.
    public func checkIndex() -> Int {
        (try? checkIndexThrowing()) ?? 0
    }

    public func checkIndexThrowing() throws -> Int {
        guard let index else {
            throw ModifierError.noIndex
        }
        return index
    }

    /// Set note index, which is a specific note in a chord.
    @discardableResult
    open func setIndex(_ index: Int) -> Self {
        self.index = index
        return self
    }

    // MARK: - Modifier Context

    /// Get `ModifierContext`.
    public func getModifierContext() -> ModifierContext? { modifierContext }

    /// Check and get `ModifierContext`.
    public func checkModifierContext() -> ModifierContext {
        (try? checkModifierContextThrowing()) ?? ModifierContext()
    }

    public func checkModifierContextThrowing() throws -> ModifierContext {
        guard let modifierContext else {
            throw ModifierError.noModifierContext
        }
        return modifierContext
    }

    /// Every modifier must be part of a `ModifierContext`.
    @discardableResult
    public func setModifierContext(_ mc: ModifierContext) -> Self {
        modifierContext = mc
        return self
    }

    // MARK: - Position

    /// Get position.
    public func getPosition() -> ModifierPosition { position }

    /// Set position.
    @discardableResult
    open func setPosition(_ position: ModifierPosition) -> Self {
        self.position = position
        reset()
        return self
    }

    /// Set position from a string: `center`, `left`, `right`, `above` or `below`.
    /// An unknown string leaves the position unchanged.
    @discardableResult
    public func setPosition(_ position: String) -> Self {
        guard let value = Modifier.positionString[position] else { return self }
        return setPosition(value)
    }

    // MARK: - Text Line

    /// Set the `textLine` for the modifier.
    @discardableResult
    public func setTextLine(_ line: Double) -> Self {
        self.textLine = line
        return self
    }

    // MARK: - Spacing

    /// Set spacing from next modifier.
    public func setSpacingFromNextModifier(_ x: Double) {
        spacingFromNextModifier = x
    }

    /// Get spacing from next modifier.
    public func getSpacingFromNextModifier() -> Double {
        spacingFromNextModifier
    }

    // MARK: - Shifts

    /// Shift modifier `x` pixels in the direction of the modifier. Negative values
    /// shift reverse.
    @discardableResult
    override open func setXShift(_ x: Double) -> Self {
        xShift = 0
        if position == .left {
            xShift -= x
        } else {
            xShift += x
        }
        return self
    }

    // MARK: - Draw

    /// Render the modifier onto the canvas.
    override open func draw() throws {
        _ = try checkContext()
        throw ModifierError.notImplemented(getCategory())
    }

    // MARK: - Align Sub Notes

    /// Aligns sub notes of NoteSubGroup (or GraceNoteGroup) to the main note with correct x-offset.
    public func alignSubNotesWithNote(_ subNotes: [Note], _ note: Note, position: ModifierPosition = .left) {
        // Shift over the tick contexts of each note
        let tickContext = note.getTickContext()
        let metrics = tickContext.getMetrics()
        let stave = note.getStave()
        let subNoteXOffset = position == .right
            ? tickContext.getX() + getSpacingFromNextModifier() * Double(subNotes.count) + 10
            : tickContext.getX() - metrics.modLeftPx - metrics.modRightPx + getSpacingFromNextModifier()

        for subNote in subNotes {
            let subTickContext = subNote.getTickContext()
            if let stave { subNote.setStave(stave) }
            subTickContext.setXOffset(subNoteXOffset) // don't touch baseX to avoid shift each render
        }
    }
}
