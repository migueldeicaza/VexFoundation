// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

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

    // MARK: - Properties

    public var state = ModifierContextState()
    public var members: [String: [VexElement]] = [:]
    public var preFormatted: Bool = false
    public var postFormatted: Bool = false
    public var formatted: Bool = false
    public var width: Double = 0
    public var spacing: Double = 0

    // MARK: - Members

    @discardableResult
    public func addMember(_ member: VexElement) -> Self {
        let category = member.getCategory()
        if members[category] == nil {
            members[category] = []
        }
        members[category]!.append(member)

        // Set modifier context on the member
        if let tickable = member as? Tickable {
            tickable.modifierContext = self
        }
        if let modifier = member as? Modifier {
            modifier.modifierContext = self
        }

        preFormatted = false
        return self
    }

    public func getMembers(_ category: String) -> [VexElement] {
        members[category] ?? []
    }

    // MARK: - Accessors

    public func getWidth() -> Double { width }

    public func getLeftShift() -> Double { state.leftShift }

    public func getRightShift() -> Double { state.rightShift }

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
        Annotation.format(getMembers("Annotation") as? [Annotation] ?? [], state: &state)

        // Format ChordSymbol (chord symbols above/below notes)
        ChordSymbol.format(getMembers("ChordSymbol") as? [ChordSymbol] ?? [], state: &state)

        // Format Bend (tablature bends)
        Bend.format(getMembers("Bend") as? [Bend] ?? [], state: &state)

        // Format Vibrato (vibrato waves)
        Vibrato.format(
            getMembers("Vibrato") as? [Vibrato] ?? [], state: &state, context: self
        )

        width = state.leftShift + state.rightShift
        preFormatted = true
        formatted = true
    }

    // MARK: - PostFormat

    public func postFormat() {
        if postFormatted { return }
        StaveNote.postFormat(getMembers("StaveNote") as? [Note] ?? [])
        postFormatted = true
    }
}
