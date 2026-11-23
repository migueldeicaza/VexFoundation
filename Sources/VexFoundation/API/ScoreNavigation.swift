// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/scorenavigation.ts` (VexFlow 5.7.0).
// A renderer-independent reading order and hit index for a formatted EasyScore composition.

import Foundation

/// One timed event in reading order. Rational times are in whole notes. Measure and voice numbers
/// start at one. (VexFlow 5.4.0)
public struct ScoreReadingEvent: Sendable, Equatable {
    public var id: String
    public var source: String?
    public var staff: String
    public var measure: Int
    public var voice: Int
    public var onset: String
    public var duration: String
    public var label: String
}

/// A hit target. Layout coordinates belong to one snapshot. A wrapped relationship can have several
/// regions. (VexFlow 5.4.0)
public struct ScoreHitRegion: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case event
        case span
    }

    public var id: String
    public var kind: Kind
    public var source: String?
    /// Targeted strings for a technique span.
    public var strings: [Int]?
    /// Row index of a continuous span fragment, counted from zero.
    public var row: Int?
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
}

/// Names for common explicitly written signs. Custom notation identities can describe other conventions.
private let signs: [String: String] = [
    "#": "sharp",
    "##": "double sharp",
    "b": "flat",
    "bb": "double flat",
    "n": "natural",
    "+": "quarter sharp",
    "d": "quarter flat",
    "o": "sori",
    "k": "koron",
]

private let lengths: [String: String] = [
    "1/1": "whole",
    "1/2": "half",
    "1/4": "quarter",
    "1/8": "eighth",
    "1/16": "sixteenth",
    "3/4": "dotted half",
    "3/8": "dotted quarter",
    "3/16": "dotted eighth",
]

/// Speak the explicit head accidental when present, otherwise use the authored key spelling.
private func spokenPitch(_ key: String, _ sign: Accidental?) -> String {
    let pieces = key.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    let name = pieces[0]
    let octave = pieces.count > 1 ? pieces[1] : ""
    let accidental = sign?.type ?? String(name.dropFirst()).lowercased()
    return [name.prefix(1).uppercased(), signs[accidental] ?? accidental, octave]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

/// Describe written attacks. Unpitched instruments are named in place of their display keys.
private func describe(_ note: Note) -> String {
    if note.isRest() { return "" }
    let marks = note.notation.map { $0.label }
    if let tab = note as? TabNote {
        let positions = tab.getPositions().map { "string \($0.str) fret \($0.fret)" }
        return (positions + tab.notation.filter { $0.kind != .tuning }.map { $0.label }).joined(separator: ", ")
    }
    // A dead string in a mixed chord has a display position but no sounding pitch.
    let unpitched = note.notation.filter { $0.kind == .unpitched }
    if unpitched.contains(where: { $0.index == nil }) { return marks.joined(separator: ", ") }
    let accidentals = note.getModifiers().compactMap { $0 as? Accidental }
    let pitches = note.getKeys().enumerated().compactMap { i, key -> String? in
        unpitched.contains { $0.index == i } ? nil : spokenPitch(key, accidentals.first { $0.getIndex() == i })
    }
    return (pitches + marks).joined(separator: ", ")
}

/// Get the painted note envelope or the string/fret target on TAB. Hidden events remain in reading order.
private func noteRegion(_ note: Note, _ diagnostics: inout [GeometryDiagnostic]) -> BoundingBox? {
    if let note = note as? StaveNote {
        guard let measured = try? measureEngraving(note) else { return nil }
        diagnostics.append(contentsOf: measured.diagnostics)
        return measured.ink
    }
    let ys = note.getYs()
    guard let top = ys.min(), let bottom = ys.max() else { return nil }
    let half = note.checkStave().getSpacingBetweenLines() / 2
    return BoundingBox(x: note.getAbsoluteX() - note.getWidth() / 2, y: top - half, w: note.getWidth(), h: bottom - top + 2 * half)
}

/// A reading order and hit index of a formatted composition. Build after layout; rebuild after reflow
/// and retain selection by authored ID across snapshots. (VexFlow 5.4.0)
public final class ScoreNavigation {
    public let events: [ScoreReadingEvent]
    public let regions: [ScoreHitRegion]
    public let diagnostics: [GeometryDiagnostic]

    /// `staves` are the composition staves in order. `sources` maps event and span IDs to caller sources.
    public convenience init(
        _ score: EasyScoreComposition, staves: [EasyScoreStaveSpec], sources: [String: String] = [:]
    ) throws {
        try self.init(score, staffNames: staves.map { (id: $0.id, name: $0.name) }, sources: sources)
    }

    /// `staffNames` are the IDs and names of the composition staves in order.
    public init(
        _ score: EasyScoreComposition, staffNames staves: [(id: String, name: String?)], sources: [String: String] = [:]
    ) throws {
        var regions: [ScoreHitRegion] = []
        var diagnostics: [GeometryDiagnostic] = []
        var events: [ScoreReadingEvent] = []
        var seen = Set<String>()
        let layout = score.sheet.getContinuousLayout()
        var techniqueLabels: [String: [String]] = [:]
        for fragment in layout?.fragments ?? [] {
            guard let strings = fragment.strings else { continue }
            let text = (strings.count == 1 ? "string " : "strings ") + strings.map(String.init).joined(separator: ", ")
            if fragment.kind != .palmMute && fragment.bend == nil { continue }
            let labels: [String]
            if let amount = fragment.bend?.envelope.semitones {
                labels = ["Bend \(formatJSNumber(amount)) semitone\(amount == 1 ? "" : "s") on ", "Sustain and release tied "]
            } else {
                labels = ["Begin palm mute on ", "Last palm-muted attack on "]
            }
            for (id, prefix) in [(fragment.from, labels[0]), (fragment.to, labels[1])] {
                if let id, !id.isEmpty { techniqueLabels[id, default: []].append(prefix + text) }
            }
        }
        for (measure, staffNotes) in score.notes.enumerated() {
            if staffNotes.count != staves.count {
                throw VexError("BadArguments", "Pass the staves in composition order.")
            }
            var ordered: [(time: Fraction, event: ScoreReadingEvent)] = []
            for (index, voices) in staffNotes.enumerated() {
                let staff = staves[index]
                for (voice, notes) in voices.enumerated() {
                    let clock = Fraction(0, 1)
                    for tickable in notes {
                        if tickable.shouldIgnoreTicks() { continue }
                        let time = clock.clone()
                        clock.add(tickable.getTicks())
                        guard let note = tickable as? Note, note is StaveNote || note is TabNote else { continue }
                        let id = note.getAttribute("id") ?? ""
                        if seen.contains(id) { throw VexError("DuplicateID", "Duplicate score event: \(id)") }
                        seen.insert(id)
                        let onset = time.clone().divide(Tables.RESOLUTION).simplify().toString()
                        let duration = note.getTicks().clone().divide(Tables.RESOLUTION).simplify().toString()
                        let length = lengths[duration] ?? duration + " of a whole"
                        let label = [
                            "Measure \(measure + 1)",
                            (staff.name?.isEmpty == false ? staff.name! : staff.id),
                            "voice \(voice + 1)",
                            describe(note),
                            length + (note.isRest() ? " rest" : " note"),
                        ] + (techniqueLabels[id] ?? [])
                        ordered.append((time, ScoreReadingEvent(
                            id: id,
                            source: sources[id],
                            staff: staff.id,
                            measure: measure + 1,
                            voice: voice + 1,
                            onset: onset,
                            duration: duration,
                            label: label.filter { !$0.isEmpty }.joined(separator: ", ")
                        )))
                        if layout?.isHidden(note) == true { continue }
                        if let box = noteRegion(note, &diagnostics) {
                            regions.append(ScoreHitRegion(
                                id: id, kind: .event, source: sources[id], x: box.x, y: box.y, w: box.w, h: box.h
                            ))
                        }
                    }
                }
            }
            // A stable sort keeps staff and voice order for simultaneous events.
            let sorted = ordered.enumerated().sorted { a, b in
                if a.element.time.equals(b.element.time) { return a.offset < b.offset }
                return a.element.time.lessThan(b.element.time)
            }
            events.append(contentsOf: sorted.map { $0.element.event })
        }
        for fragment in layout?.fragments ?? [] {
            if seen.contains(fragment.id) {
                throw VexError("DuplicateID", "Span shares a score event ID: \(fragment.id)")
            }
            // A conservative target includes the curve and enough space to select a thin stroke.
            let pad = max(fragment.space, abs(fragment.rise ?? 0))
            var bounds = BoundingBox(
                min(fragment.x1, fragment.x2),
                min(fragment.y1, fragment.y2) - pad,
                abs(fragment.x2 - fragment.x1),
                abs(fragment.y2 - fragment.y1) + 2 * pad
            )
            if let bend = fragment.bend { bounds.mergeWith(bend.bounds) }
            if let tip = fragment.nienteTip { bounds.mergeWith(nienteBounds(tip, 0.5)) }
            regions.append(ScoreHitRegion(
                id: fragment.id,
                kind: .span,
                source: sources[fragment.id],
                strings: fragment.strings,
                row: fragment.row,
                x: bounds.x,
                y: bounds.y,
                w: bounds.w,
                h: bounds.h
            ))
        }
        self.events = events
        self.regions = regions
        self.diagnostics = diagnostics
    }

    /// Points use score coordinates. Event targets precede spanners; prefer the smallest overlapping target.
    public func hitTest(_ x: Double, _ y: Double) -> ScoreHitRegion? {
        if !x.isFinite || !y.isFinite { return nil }
        var best: ScoreHitRegion?
        for r in regions {
            if x < r.x || x > r.x + r.w || y < r.y || y > r.y + r.h { continue }
            if let b = best {
                if (b.kind == .span && r.kind == .event) || (b.kind == r.kind && r.w * r.h < b.w * b.h) { best = r }
            } else {
                best = r
            }
        }
        return best
    }
}
