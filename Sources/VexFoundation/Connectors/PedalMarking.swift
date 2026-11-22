// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/pedalmarking.ts` (VexFlow 5.0.0).

import Foundation

// MARK: - Pedal Marking Type

public enum PedalMarkingType: Int, Sendable {
    case text = 1
    case bracket = 2
    case mixed = 3
    /// VexFlowPatch: extended pedal styles
    case mixedOpenEnd = 4
    case bracketOpenBegin = 5
    case bracketOpenEnd = 6
    case bracketOpenBoth = 7
}

// MARK: - Pedal Marking Render Options

public struct PedalMarkingRenderOptions {
    public var color: String = "black"
    public var bracketHeight: Double = 10
    public var textMarginRight: Double = 6
    public var bracketLineWidth: Double = 1

    public init(
        color: String = "black",
        bracketHeight: Double = 10,
        textMarginRight: Double = 6,
        bracketLineWidth: Double = 1
    ) {
        self.color = color
        self.bracketHeight = bracketHeight
        self.textMarginRight = textMarginRight
        self.bracketLineWidth = bracketLineWidth
    }
}

public enum PedalMarkingError: Error, LocalizedError, Equatable, Sendable {
    case notesNotInAscendingOrder

    public var errorDescription: String? {
        switch self {
        case .notesNotInAscendingOrder:
            return "The notes provided must be in order of ascending x positions"
        }
    }
}

// MARK: - PedalMarking

/// PedalMarking implements different types of pedal markings. These notation
/// elements indicate to the performer when to depress and release the a pedal.
///
/// In order to create "Sostenuto", and "una corda" markings, you must set
/// custom text for the release/depress pedal markings.
public final class PedalMarking: VexElement {

    override public class var category: String { "PedalMarking" }

    // MARK: - Glyph Data

    /// Glyph data
    public static let GLYPHS: [String: String] = [
        "pedalDepress": Glyphs.keyboardPedalPed,
        "pedalRelease": Glyphs.keyboardPedalUp,
    ]

    /// Pedal type as string.
    public static let typeString: [String: PedalMarkingType] = [
        "text": .text,
        "bracket": .bracket,
        "mixed": .mixed,
    ]

    // MARK: - Properties

    public var line: Double = 0
    public var type: PedalMarkingType = .text
    public var depressText: String
    public var releaseText: String
    public var renderOptions = PedalMarkingRenderOptions()
    public var notes: [StaveNote]

    /// VexFlowPatch: track pedal marking spanning staves
    public var endsStave: Bool = false
    public var beginsStave: Bool = false
    public var changeBegin: Bool = false
    public var endStave: Stave?
    public var endStaveAddedWidth: Double = 0
    public var startMargin: Double = 0
    public var endMargin: Double = 0

    @available(*, deprecated, renamed: "type")
    public var pedalType: PedalMarkingType {
        get { type }
        set { type = newValue }
    }

    @available(*, deprecated, renamed: "line")
    public var pedalLine: Double {
        get { line }
        set { line = newValue }
    }

    @available(*, deprecated, renamed: "renderOptions")
    public var pedalRenderOptions: PedalMarkingRenderOptions {
        get { renderOptions }
        set { renderOptions = newValue }
    }

    @available(*, deprecated, renamed: "depressText")
    public var customDepressText: String { depressText }

    @available(*, deprecated, renamed: "releaseText")
    public var customReleaseText: String { releaseText }

    // MARK: - Init

    public init(notes: [StaveNote]) {
        self.notes = notes
        // Text for the release/depress markings
        self.depressText = PedalMarking.GLYPHS["pedalDepress"] ?? Glyphs.keyboardPedalPed
        self.releaseText = PedalMarking.GLYPHS["pedalRelease"] ?? Glyphs.keyboardPedalUp
        super.init()
        self.type = .text
        self.line = 0
        self.renderOptions = PedalMarkingRenderOptions(
            color: "black",
            bracketHeight: 10,
            textMarginRight: 6,
            bracketLineWidth: 1
        )
    }

    // MARK: - Factory Methods

    /// Create a sustain pedal marking. Returns the defaults PedalMarking.
    /// Which uses the traditional "Ped" and "*" markings.
    public static func createSustain(notes: [StaveNote]) -> PedalMarking {
        PedalMarking(notes: notes)
    }

    /// Create a sostenuto pedal marking
    public static func createSostenuto(notes: [StaveNote]) -> PedalMarking {
        let pedal = PedalMarking(notes: notes)
        pedal.setType(.mixed)
        pedal.setCustomText("Sost. Ped.")
        return pedal
    }

    /// Create an una corda pedal marking
    public static func createUnaCorda(notes: [StaveNote]) -> PedalMarking {
        let pedal = PedalMarking(notes: notes)
        pedal.setType(.text)
        pedal.setCustomText("una corda", release: "tre corda")
        return pedal
    }

    // MARK: - Setters

    /// Set pedal type.
    @discardableResult
    public func setType(_ type: PedalMarkingType) -> Self {
        self.type = type
        return self
    }

    /// Set pedal type from a string (`"text"`, `"bracket"`, `"mixed"`).
    /// An unknown string does not change the type.
    @discardableResult
    public func setType(_ type: String) -> Self {
        if let t = PedalMarking.typeString[type] {
            self.type = t
        }
        return self
    }

    /// Set custom text for the `depress`/`release` pedal markings. No text is
    /// set if the parameter is empty.
    @discardableResult
    public func setCustomText(_ depress: String, release: String = "") -> Self {
        depressText = depress
        releaseText = release
        setFont(Metrics.getFontInfo("PedalMarking.text"))
        return self
    }

    /// Set the staff line to render the markings on.
    @discardableResult
    public func setLine(_ line: Double) -> Self {
        self.line = line
        return self
    }

    /// VexFlowPatch: set ending stave and calculate width adjustments for
    /// pedal markings spanning multiple staves.
    @discardableResult
    public func setEndStave(_ stave: Stave) -> Self {
        endStave = stave
        endStaveAddedWidth = 0
        startMargin = 0
        endMargin = 0
        for modifier in stave.modifiers {
            if modifier.getPosition() == .end {
                endStaveAddedWidth += modifier.getModifierWidth()
            }
        }
        return self
    }

    // MARK: - Helpers

    /// The absolute x position of the end of `note`: the x of the next note in
    /// the voice, or the end of the stave for the last note of the voice.
    private func noteEndX(_ note: StaveNote) throws -> Double {
        // Get the current note index and the total notes in the associated voice
        let tickables = try note.getVoiceThrowing().getTickables()
        let noteNdx = tickables.firstIndex(where: { $0 === note }) ?? -1
        let voiceNotes = tickables.count
        if noteNdx + 1 < voiceNotes {
            // If the next note is in the same voice, use the x position of the next note
            return tickables[noteNdx + 1].getAbsoluteX()
        }
        // If this is the last note is the voice, use the x position of the next stave
        return (note.getStave()?.getX() ?? 0) + (note.getStave()?.getWidth() ?? 0)
    }

    // MARK: - Draw Bracketed

    /// Draw the bracket based pedal markings.
    public func drawBracketed() throws {
        let ctx = try checkContext()
        var isPedalDepressed = false
        var prevX: Double?
        var prevY: Double?
        var textWidth: Double = 0

        // Iterate through each note
        for (index, note) in notes.enumerated() {
            // Each note triggers the opposite pedal action
            isPedalDepressed = !isPedalDepressed

            // Get the initial coordinates for the note
            let x = note.getAbsoluteX()
            let y = note.checkStave().getYForBottomText(line + 3)

            // Throw if current note is positioned before the previous note
            if let prevX, x < prevX {
                throw PedalMarkingError.notesNotInAscendingOrder
            }

            // Determine if the previous or next note are the same
            // as the current note. We need to keep track of this for
            // when adjustments are made for the release+depress action
            let nextNoteIsSame = index + 1 < notes.count && notes[index + 1] === note
            let prevNoteIsSame = index > 0 && notes[index - 1] === note

            var xShift: Double = 0

            if isPedalDepressed {
                // Adjustment for release+depress
                xShift = prevNoteIsSame ? 5 : 0

                if type == .mixed && !prevNoteIsSame {
                    // For MIXED style, start with text instead of bracket
                    textWidth = ctx.measureText(depressText).width
                    ctx.fillText(depressText, x, y)
                    // Adjust the xShift for the next note
                    xShift = textWidth + renderOptions.textMarginRight
                } else {
                    // Draw start bracket
                    ctx.beginPath()
                    ctx.moveTo(x, y - renderOptions.bracketHeight)
                    ctx.lineTo(x + xShift, y)
                    ctx.stroke()
                    ctx.closePath()
                }
            } else {
                let noteEndX = try noteEndX(note)

                // Draw end bracket
                ctx.beginPath()
                ctx.moveTo(prevX ?? .nan, prevY ?? .nan)
                ctx.lineTo(nextNoteIsSame ? x - 5 : noteEndX - 5, y)
                // No shift if next note is the same
                ctx.lineTo(nextNoteIsSame ? x : noteEndX - 5, y - renderOptions.bracketHeight)
                ctx.stroke()
                ctx.closePath()
            }

            // Store previous coordinates
            prevX = x + xShift
            prevY = y
        }
    }

    // MARK: - Draw Text

    /// Draw the text based pedal markings. This defaults to the traditional
    /// "Ped" and "*" symbols if no custom text has been provided.
    public func drawText() throws {
        let ctx = try checkContext()
        var isPedalDepressed = false
        var textWidth: Double = 0

        // Iterate through each note, placing glyphs or custom text accordingly
        for note in notes {
            isPedalDepressed = !isPedalDepressed
            let stave = note.checkStave()
            let x = note.getAbsoluteX()
            let y = stave.getYForBottomText(line + 3)

            if isPedalDepressed {
                textWidth = ctx.measureText(depressText).width
                ctx.fillText(depressText, x, y)
            } else {
                let noteEndX = try noteEndX(note)
                textWidth = ctx.measureText(releaseText).width
                ctx.fillText(releaseText, noteEndX - textWidth, y)
            }
        }
    }

    // MARK: - Draw

    /// Render the pedal marking in position on the rendering context.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()

        ctx.setStrokeStyle(renderOptions.color)
        ctx.setFillStyle(renderOptions.color)
        ctx.setFont(getFont())

        // VexFlowPatch: handle extended pedal types
        switch type {
        case .bracket, .mixed, .mixedOpenEnd, .bracketOpenBegin, .bracketOpenEnd, .bracketOpenBoth:
            ctx.setLineWidth(renderOptions.bracketLineWidth)
            try drawBracketed()
        case .text:
            try drawText()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("PedalMarking", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 200) { ctx in
        ctx.clear()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 20))
        let notes = score.notes("C5/q, D5, E5, F5")
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble)

        system.format()

        if let first = notes[0] as? StaveNote, let last = notes[3] as? StaveNote {
            _ = f.PedalMarking(notes: [first, last], type: .text)
        }

        try? f.draw()
    }
    .padding()
}
#endif
