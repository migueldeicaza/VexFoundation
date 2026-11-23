// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/modifiercontext.ts` (VexFlow 5.1.0).
//
// This class implements various types of members to notes (e.g. bends,
// fingering positions etc.). The ModifierContext works with tickables
// that are at the same tick to ensure that they and their modifiers
// all have proper alignment. (Note that the ModifierContext also
// runs the spacing of the tickable).

import Foundation

public enum ModifierContextError: Error, LocalizedError, Equatable, Sendable {
    case unformattedMember

    public var errorDescription: String? {
        switch self {
        case .unformattedMember:
            return "Unformatted member has no metrics."
        }
    }
}

// MARK: - Modifier Context State

/// Shared formatting state passed through modifier format methods.
public struct ModifierContextState {
    public var leftShift: Double = 0
    public var rightShift: Double = 0
    public var textLine: Double = 0
    public var topTextLine: Double = 0
}

/// Metrics returned by a formatted ModifierContext.
public struct ModifierContextMetrics {
    public var width: Double = 0
    public var spacing: Double = 0
}

// MARK: - Modifier Context

/// Coordinates formatting of all modifiers at a single tick position.
/// Groups modifiers by category and formats them in the correct order.
public final class ModifierContext {
    public nonisolated(unsafe) static var DEBUG: Bool = false

    private static func L(_ args: Any...) {
        if DEBUG { vexLog("VexFlow.ModifierContext", args) }
    }

    public init() {}

    // MARK: - Properties

    public var state = ModifierContextState()
    public var members: [String: [VexElement]] = [:]
    public var preFormatted: Bool = false
    public var postFormatted: Bool = false
    public var formatted: Bool = false
    public var width: Double = 0
    public var spacing: Double = 0
    /// Horizontal space added only for annotations above or below the note (VexFlow 5.1.0).
    public private(set) var annotationRightShift: Double = 0

    // MARK: - Members

    @available(*, deprecated, renamed: "addMember(_:)")
    @discardableResult
    public func addModifier(_ member: VexElement) -> Self {
        Self.L("addModifier is deprecated, use addMember instead.")
        return addMember(member)
    }

    /// `members` maps category strings to arrays of Tickable | Modifier | StaveNote | TabNote.
    /// Add a new member to `members`, and create a new array if needed.
    @discardableResult
    public func addMember(_ member: VexElement) -> Self {
        let category = member.getCategory()
        members[category, default: []].append(member)

        if let tickable = member as? Tickable {
            tickable.setModifierContext(self)
        } else if let modifier = member as? Modifier {
            modifier.setModifierContext(self)
        }

        preFormatted = false
        return self
    }

    @available(*, deprecated, renamed: "getMembers(_:)")
    public func getModifiers(_ category: String) -> [VexElement] {
        Self.L("getModifiers is deprecated, use getMembers instead.")
        return getMembers(category)
    }

    public func getMembers(_ category: String) -> [VexElement] {
        members[category] ?? []
    }

    // MARK: - Accessors

    public func getWidth() -> Double { width }

    public func getLeftShift() -> Double { state.leftShift }

    public func getRightShift() -> Double { state.rightShift }

    /// Ties clear nearby modifiers, but must not start beyond a lyric's text box.
    public func getRightShiftForTie() -> Double { state.rightShift - annotationRightShift }

    public func getState() -> ModifierContextState { state }

    public func getMetrics() -> ModifierContextMetrics {
        (try? getMetricsThrowing()) ?? ModifierContextMetrics(
            width: state.leftShift + state.rightShift + spacing,
            spacing: spacing
        )
    }

    public func getMetricsThrowing() throws -> ModifierContextMetrics {
        guard formatted else {
            throw ModifierContextError.unformattedMember
        }
        return ModifierContextMetrics(
            width: state.leftShift + state.rightShift + spacing,
            spacing: spacing
        )
    }

    // MARK: - PreFormat

    /// Format all members in the correct order.
    /// The ordering determines when different modifier types are formatted and rendered.
    public func preFormat() {
        if preFormatted { return }
        Self.L("Preformatting ModifierContext")

        // Format StaveNote first (calculates note displacements)
        StaveNote.format(getMembers("StaveNote") as? [StaveNote] ?? [], state: &state)

        // Format Parenthesis (parentheses around noteheads)
        Parenthesis.format(getMembers("Parenthesis") as? [Parenthesis] ?? [], state: &state)

        // Format Dot (right-side positioning)
        Dot.format(getMembers("Dot") as? [Dot] ?? [], state: &state)

        // Format FretHandFinger (finger numbers)
        FretHandFinger.format(
            getMembers("FretHandFinger") as? [FretHandFinger] ?? [], state: &state
        )

        // Format Accidental (left-side positioning with collision avoidance)
        Accidental.format(getMembers("Accidental") as? [Accidental] ?? [], state: &state)

        // Format Stroke (chord strokes)
        Stroke.format(getMembers("Stroke") as? [Stroke] ?? [], state: &state)

        // Format GraceNoteGroup (grace notes before main notes)
        GraceNoteGroup.format(
            getMembers("GraceNoteGroup") as? [GraceNoteGroup] ?? [], state: &state
        )

        // Format NoteSubGroup (inline notes like clef/time signature changes)
        NoteSubGroup.format(
            getMembers("NoteSubGroup") as? [NoteSubGroup] ?? [], state: &state
        )

        // Format StringNumber (string number annotations)
        StringNumber.format(
            getMembers("StringNumber") as? [StringNumber] ?? [], state: &state
        )

        // Format Articulation (above/below positioning)
        Articulation.format(getMembers("Articulation") as? [Articulation] ?? [], state: &state)

        // Format Ornament (trills, mordents, turns, jazz ornaments)
        Ornament.format(getMembers("Ornament") as? [Ornament] ?? [], state: &state)

        // Format Annotation (text above/below notes)
        let annotations = getMembers("Annotation") as? [Annotation] ?? []
        let isOutsideNote: (Annotation) -> Bool = {
            $0.getVerticalJustification() == .top || $0.getVerticalJustification() == .bottom
        }
        Annotation.format(annotations.filter { !isOutsideNote($0) }, state: &state)
        let rightShiftBeforeAnnotations = state.rightShift
        Annotation.format(annotations.filter(isOutsideNote), state: &state)
        let rightShiftWithAnnotations = state.rightShift
        // Keep annotation vertical placement in its original stage. Its horizontal
        // text box must not push nearby modifiers away from the notehead.
        state.rightShift = rightShiftBeforeAnnotations

        // Format ChordSymbol (chord symbols above/below notes)
        ChordSymbol.format(getMembers("ChordSymbol") as? [ChordSymbol] ?? [], state: &state)

        // Format Bend (tablature bends)
        Bend.format(getMembers("Bend") as? [Bend] ?? [], state: &state)

        // Format Vibrato (vibrato waves)
        Vibrato.format(
            getMembers("Vibrato") as? [Vibrato] ?? [], state: &state, context: self
        )

        // Reserve enough note spacing for both the lyric and nearby modifiers.
        annotationRightShift = max(0, rightShiftWithAnnotations - state.rightShift)
        state.rightShift += annotationRightShift

        // Update width of this member context
        width = state.leftShift + state.rightShift
        preFormatted = true
    }

    // MARK: - PostFormat

    public func postFormat() {
        if postFormatted { return }
        Self.L("Postformatting ModifierContext")

        // If post-formatting is required for an element, add more lines below.
        StaveNote.postFormat(getMembers("StaveNote") as? [Note] ?? [])
    }
}
