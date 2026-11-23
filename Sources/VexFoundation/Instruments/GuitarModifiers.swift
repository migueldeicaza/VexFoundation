// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/guitarmodifiers.ts` (VexFlow 5.6.0).
// Engrave structured guitar actions using native note modifiers on either backend.

import Foundation

/// Both arrow conventions describe the same order of physical strings.
private func printedStroke(_ stroke: GuitarStroke) -> StrokeType {
    let down = (stroke.direction == .bassToTreble) != (stroke.arrows == .hand)
    if stroke.roll == true { return down ? .rasgueadoDown : .rasgueadoUp }
    return down ? .brushDown : .brushUp
}

/// Attach native modifiers once, after a new note has initialized its heads or string positions.
public func attachGuitarGestures(_ note: Note) throws {
    for entry in note.notation {
        if let stroke = entry.stroke {
            note.addModifier(Stroke(type: printedStroke(stroke), allVoices: false), index: 0)
            note.addModifier(
                Annotation(stroke.finger.rawValue + (stroke.golpe == true ? " + golpe" : ""))
                    .setFont(Metrics.getFontInfo("Annotation.guitarStroke"))
                    .setVerticalJustification(.top),
                index: 0
            )
        }
        if let bend = entry.bend, let tab = note as? TabNote {
            guard let index = tab.getPositions().firstIndex(where: { $0.str == bend.string }) else {
                throw VexError("BadArguments", "The bent string must occur in the chord.")
            }
            note.addModifier(try Bend.timed(bend), index: index)
        }
    }
}
