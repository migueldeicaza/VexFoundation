// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/chordspacing.ts` (VexFlow 5.7.0).
// Measure chord ink at adjacent barlines after the native formatters have placed their notes.

import Foundation

/// EasyScore lead-sheet chords are ordinary annotations with native phrase-lane placement.
/// Swift deviation: upstream keeps a module `WeakSet`; here each annotation holds a flag.
func addLeadChordAnnotation(_ mark: Annotation) {
    mark.isLeadChord = true
}

/// Absolute ink edges on one side of one staff.
private struct ChordEdges {
    var left: Double
    var right: Double
    var clearance: Double
}

/// Ignore other annotations, including lyrics that share a chord's note.
private func chordEdges(_ system: System) throws -> [Int: ChordEdges] {
    var lanes: [Int: ChordEdges] = [:]
    for voice in system.getVoices() {
        for note in voice.getTickables() {
            for mark in note.getModifiers() {
                let left: Double
                let right: Double
                let above: Bool
                if let symbol = mark as? ChordSymbol {
                    (left, right) = try symbol.getHorizontalInk()
                    above = symbol.getVertical() == .top
                } else if let annotation = mark as? Annotation, annotation.isLeadChord {
                    let ink = annotation.getTextInk(try annotation.computeX().x, 0)
                    left = ink.x
                    right = ink.x + ink.w
                    above = annotation.getVerticalJustification() == .top
                } else {
                    continue
                }
                if !(right > left) { continue }
                let owner = try mark.checkAttachedNoteThrowing()
                if owner.renderOptions.draw == false { continue }
                let stave = try owner.checkStaveThrowing()
                guard let staff = system.getStaves().firstIndex(where: { $0 === stave }) else { continue }
                let key = staff * 2 + (above ? 1 : 0)
                if var edges = lanes[key] {
                    edges.left = min(edges.left, left)
                    edges.right = max(edges.right, right)
                    lanes[key] = edges
                } else {
                    lanes[key] = ChordEdges(left: left, right: right, clearance: stave.space(0.5))
                }
            }
        }
    }
    return lanes
}

/// Increase only the space inside a bar that still collides with the following bar on this row.
/// Each reservation moves the next measure while preserving the preceding note anchors. Repacking can
/// spend some of the row's justification surplus or move the boundary to a break, where it costs zero.
/// `rows` holds the systems of each row. `padding` is keyed by `ObjectIdentifier(system)`.
func reserveChordSpacing(_ rows: [[System]], _ padding: inout [ObjectIdentifier: Double]) throws -> Bool {
    var changed = false
    for systems in rows {
        if systems.count < 2 { continue }
        var prior = try chordEdges(systems[0])
        for i in 1..<systems.count {
            let next = try chordEdges(systems[i])
            var missing: Double = 0
            for (lane, first) in prior {
                if let second = next[lane] {
                    missing = max(missing, first.right + max(first.clearance, second.clearance) - second.left)
                }
            }
            if missing > 0.01 {
                let previous = ObjectIdentifier(systems[i - 1])
                padding[previous, default: 0] += missing.rounded(.up)
                changed = true
            }
            prior = next
        }
    }
    return changed
}
