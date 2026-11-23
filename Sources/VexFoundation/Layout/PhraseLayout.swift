// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/phraselayout.ts` (VexFlow 5.8.0).
// Place attachments and lyrics within one formatted system. All solver coordinates are renderer pixels.

import Foundation

/// A syllable owns one event. Hyphens lead to the next syllable; extenders end on a named event.
public struct PhraseSyllable {
    public var note: StaveNote
    public var text: String
    /// A second syllable sung on this attack, joined to the first by an engraved undertie. (VexFlow 5.7.0)
    public var elideWith: String?
    public var hyphenAfter: Bool
    public var extendTo: StaveNote?

    public init(
        note: StaveNote, text: String, hyphenAfter: Bool = false, extendTo: StaveNote? = nil, elideWith: String? = nil
    ) {
        self.note = note
        self.text = text
        self.elideWith = elideWith
        self.hyphenAfter = hyphenAfter
        self.extendTo = extendTo
    }
}

/// A mark that a phrase lane places on a shared baseline: `Annotation`, `StaveHairpin`,
/// `PedalMarking` or `TextBracket` (upstream `PhraseMark` union).
public protocol PhraseMark: VexElement {}
extension Annotation: PhraseMark {}
extension StaveHairpin: PhraseMark {}
extension PedalMarking: PhraseMark {}
extension TextBracket: PhraseMark {}

/// A span that a phrase layout routes: `Curve` or `StaveTie` (upstream `Route` union).
public protocol PhraseRoute: VexElement {
    func setLayoutRise(_ rise: Double)
    func hasManualControls() -> Bool
    func getRouteParts() throws -> [BoundingBox]
}
extension Curve: PhraseRoute {}
extension StaveTie: PhraseRoute {}

public enum PhraseLaneSide: String, Sendable {
    case above, below
}

public struct PhraseLaneOptions {
    public var side: PhraseLaneSide?
    /// Pin the common baseline in staff spaces from the top line, positive downward.
    public var baselineSpaces: Double?

    public init(side: PhraseLaneSide? = nil, baselineSpaces: Double? = nil) {
        self.side = side
        self.baselineSpaces = baselineSpaces
    }
}

/// Verse options. `stanza` prints its text one time at the left margin of the verse. (VexFlow 5.8.0)
public struct PhraseVerseOptions {
    public var side: PhraseLaneSide?
    /// Pin the common baseline in staff spaces from the top line, positive downward.
    public var baselineSpaces: Double?
    public var stanza: String?

    public init(side: PhraseLaneSide? = nil, baselineSpaces: Double? = nil, stanza: String? = nil) {
        self.side = side
        self.baselineSpaces = baselineSpaces
        self.stanza = stanza
    }

    public init(_ lane: PhraseLaneOptions, stanza: String? = nil) {
        self.init(side: lane.side, baselineSpaces: lane.baselineSpaces, stanza: stanza)
    }

    /// The lane options (upstream `PhraseVerseOptions extends PhraseLaneOptions`).
    public var lane: PhraseLaneOptions { PhraseLaneOptions(side: side, baselineSpaces: baselineSpaces) }
}

public struct PhraseDiagnostic: Equatable, Sendable {
    public enum Code: String, Sendable {
        case pinnedCollision = "PinnedCollision"
        case unresolvedCollision = "UnresolvedCollision"
        case crossingSpans = "CrossingSpans"
        case unsupportedGeometry = "UnsupportedGeometry"
        case unsupportedScript = "UnsupportedScript"
        case invalidAnchor = "InvalidAnchor"
        case iterationLimit = "IterationLimit"
        case insufficientLyricSpace = "InsufficientLyricSpace"
    }

    public var code: Code
    public var sources: [String]
}

/// Invalid phrase registration (upstream `RangeError`).
public enum PhraseLayoutError: Error, LocalizedError, Equatable, Sendable {
    case invalidPassLimit
    case duplicateLaneMark
    case invalidLaneBaseline
    case invalidSyllables
    case foreignSyllable
    /// VexFlow 5.7.0.
    case invalidElision
    /// VexFlow 5.8.0.
    case invalidStanza

    public var errorDescription: String? {
        switch self {
        case .invalidPassLimit: return "Phrase pass limit must be 1 to 16."
        case .duplicateLaneMark: return "Each phrase mark must belong to exactly one lane."
        case .invalidLaneBaseline: return "Expected a finite lane baseline."
        case .invalidSyllables: return "Expected syllables with a following syllable for each hyphen."
        case .foreignSyllable: return "A syllable must belong to the requested stave."
        case .invalidElision: return "An elision needs a second syllable."
        case .invalidStanza: return "A stanza label needs text."
        }
    }
}

private final class Lane {
    let stave: Stave
    let marks: [PhraseMark]
    let options: PhraseLaneOptions
    var syllables: [PhraseSyllable]?
    var stanzaLabel: Annotation?

    init(stave: Stave, marks: [PhraseMark], options: PhraseLaneOptions) {
        self.stave = stave
        self.marks = marks
        self.options = options
    }
}

private struct Obstacle: Bounds {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    let owner: VexElement
    let stave: Stave
    /// Cross-staff stems and beams bridge the gap and cannot themselves set its minimum.
    var bridge: Bool
}

private let supportedText = try? NSRegularExpression(
    pattern: "^[\\p{Script=Latin}\\p{Script=Greek}\\p{Script=Cyrillic}\\p{Script=Han}\\p{Script=Hiragana}"
        + "\\p{Script=Katakana}\\p{Script=Hangul}\\p{M}\\p{N}\\p{P}\\p{Zs}]*$"
)

private func isSupportedText(_ text: String) -> Bool {
    guard let supportedText else { return true }
    return supportedText.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
}

/// Signed clearance tests use visible parts, never pairwise collisions within a single glyph or note.
private func overlaps(_ a: Bounds, _ b: Bounds, _ gap: Double) -> Bool {
    a.x < b.x + b.w + gap && b.x < a.x + a.w + gap && a.y < b.y + b.h + gap && b.y < a.y + a.h + gap
}

private func obstacle(_ box: Bounds, _ owner: VexElement, _ stave: Stave, _ bridge: Bool = false) -> Obstacle {
    Obstacle(x: box.x, y: box.y, w: box.w, h: box.h, owner: owner, stave: stave, bridge: bridge)
}

private func setMarkBaseline(_ mark: PhraseMark, _ y: Double?) {
    switch mark {
    case let m as Annotation: m.setLayoutBaseline(y)
    case let m as StaveHairpin: m.setLayoutBaseline(y)
    case let m as PedalMarking: m.setLayoutBaseline(y)
    case let m as TextBracket: m.setLayoutBaseline(y)
    default: break
    }
}

private func routeNotes(_ span: PhraseRoute) -> (first: Note?, last: Note?) {
    if let curve = span as? Curve {
        let notes = curve.getNotes()
        return (notes.firstNote, notes.lastNote)
    }
    if let tie = span as? StaveTie {
        let notes = tie.getNotes()
        return (notes.firstNote, notes.lastNote)
    }
    return (nil, nil)
}

/// Opt-in system-local layout. Register native spans and outside marks before formatting.
public final class PhraseLayout {
    public private(set) var diagnostics: [PhraseDiagnostic] = []
    private var lanes: [Lane] = []
    private var routes: [PhraseRoute] = []
    private var fixed: [(owner: VexElement, stave: Stave)] = []
    private var pins = Set<ObjectIdentifier>()
    private var managed = Set<ObjectIdentifier>()
    private var restLines: [(note: StaveNote, before: Double, after: Double)] = []
    private var obstacles: [Obstacle] = []
    private var connectors: [BoundingBox] = []
    private var stanzaLabels: [Annotation] = []
    private var messages = Set<String>()
    private var iterationLimit = 4
    private var lockedStaves = Set<ObjectIdentifier>()
    public private(set) var bounds: BoundingBox?
    public private(set) var passes = 0

    public init() {}

    /// Include a native span or additional positioned obstacle, e.g. a tuplet on a second voice.
    @discardableResult
    public func addObstacle(_ stave: Stave, _ owner: VexElement) -> Self {
        fixed.append((owner, stave))
        return self
    }

    /// Keep authored rest lines, mark placement or curve controls. Report any unresolved collision.
    /// Upstream accepts an `Articulation`, `Ornament`, `StaveNote`, `Curve` or `StaveTie`.
    @discardableResult
    public func pin(_ owner: VexElement) -> Self {
        pins.insert(ObjectIdentifier(owner))
        return self
    }

    /// Preserve the configured distance above this stave.
    @discardableResult
    public func lockStaffGap(_ stave: Stave) -> Self {
        lockedStaves.insert(ObjectIdentifier(stave))
        return self
    }

    /// Bound the number of staff-spacing and cross-staff beam refits.
    @discardableResult
    public func setPassLimit(_ limit: Int) throws -> Self {
        if limit < 1 || limit > 16 { throw PhraseLayoutError.invalidPassLimit }
        iterationLimit = limit
        return self
    }

    /// Fit ties before slurs. Explicit control points remain authoritative.
    @discardableResult
    public func route(_ span: PhraseRoute) -> Self {
        if !routes.contains(where: { $0 === span }) { routes.append(span) }
        return self
    }

    /// One lane aligns dynamics with wedges, or places a pedal or ottava outside earlier lanes.
    @discardableResult
    public func addLane(_ stave: Stave, _ marks: [PhraseMark], options: PhraseLaneOptions = PhraseLaneOptions()) throws -> Self {
        let ids = marks.map { ObjectIdentifier($0) }
        if marks.isEmpty || Set(ids).count != ids.count || ids.contains(where: { managed.contains($0) }) {
            throw PhraseLayoutError.duplicateLaneMark
        }
        if let spaces = options.baselineSpaces, !spaces.isFinite { throw PhraseLayoutError.invalidLaneBaseline }
        lanes.append(Lane(stave: stave, marks: marks, options: options))
        for mark in marks {
            managed.insert(ObjectIdentifier(mark))
            if let annotation = mark as? Annotation { annotation.phraseManaged = true }
        }
        return self
    }

    /// Each whole syllable uses native text shaping and participates in ModifierContext horizontal spacing.
    @discardableResult
    public func addVerse(
        _ stave: Stave,
        _ syllables: [PhraseSyllable],
        options: PhraseLaneOptions
    ) throws -> [Annotation] {
        try addVerse(stave, syllables, options: PhraseVerseOptions(options))
    }

    /// Each whole syllable uses native text shaping and participates in ModifierContext horizontal spacing.
    /// A stanza label shares the lane of the verse. (VexFlow 5.8.0)
    @discardableResult
    public func addVerse(
        _ stave: Stave,
        _ syllables: [PhraseSyllable],
        options: PhraseVerseOptions = PhraseVerseOptions()
    ) throws -> [Annotation] {
        if syllables.isEmpty || syllables.enumerated().contains(where: { i, s in
            s.text.isEmpty || (s.hyphenAfter && (s.extendTo != nil || i == syllables.count - 1))
        }) {
            throw PhraseLayoutError.invalidSyllables
        }
        if syllables.contains(where: { s in
            s.elideWith.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        }) {
            throw PhraseLayoutError.invalidElision
        }
        if syllables.contains(where: { $0.note.getStave() != nil && $0.note.getStave() !== stave }) {
            throw PhraseLayoutError.foreignSyllable
        }
        if let stanza = options.stanza, stanza.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PhraseLayoutError.invalidStanza
        }
        var marks: [Annotation] = []
        for (i, s) in syllables.enumerated() {
            let hyphenated = s.hyphenAfter || (i > 0 && syllables[i - 1].hyphenAfter)
            // Shape and reserve the entire group together. The lyric font stack includes the active music face.
            let text = s.elideWith.map { s.text + Glyphs.lyricsElision + $0 } ?? s.text
            marks.append(try Annotation(text)
                .setFont(Metrics.getFontInfo("Annotation.lyric"))
                .setVerticalJustification(options.side == .above ? .top : .bottom)
                .setConnectorPadding(hyphenated ? stave.space(0.4) : 0))
        }
        // The label shares the lane solver and the baseline of its first note. Only sung text enters the note
        // formatter.
        let label = options.stanza.map { stanza in
            Annotation(stanza)
                .setFont(FontInfo(
                    family: marks[0].fontInfo.family, size: marks[0].fontInfo.size, weight: "bold",
                    style: marks[0].fontInfo.style
                ))
                .setJustification(.left)
                .setPosition(options.side == .above ? .above : .below)
                .setNote(syllables[0].note)
                .setIndex(0)
        }
        try addLane(stave, label.map { marks + [$0] } ?? marks, options: options.lane)
        let lane = lanes[lanes.count - 1]
        lane.syllables = syllables
        lane.stanzaLabel = label
        for (i, mark) in marks.enumerated() { syllables[i].note.addModifier(mark, index: 0) }
        return marks
    }

    /// Width of the shared stanza column, with its side margins in staff spaces. (VexFlow 5.8.0)
    public func getStanzaColumnWidth(_ stave: Stave) -> Double {
        var column = 0.0
        for lane in lanes where lane.stave === stave {
            if let label = lane.stanzaLabel {
                let width = label.getTextInk(0, 0).w
                column = max(column, stave.space(1.2) + width)
            }
        }
        return column
    }

    /// Restore derived rest positions before native formatting; preserve subsequent authored edits.
    public func resetPlacement() {
        for lane in lanes { for mark in lane.marks { setMarkBaseline(mark, nil) } }
        for route in routes { route.setLayoutRise(0) }
        for line in restLines where line.note.restLine == nil && line.note.getKeyLine(0) == line.after {
            line.note.setKeyLine(0, line: line.before)
        }
        restLines.removeAll()
    }

    private func report(_ code: PhraseDiagnostic.Code, _ owners: [VexElement]) {
        var sources: [String] = []
        for owner in owners {
            let id = owner.getAttribute("id") ?? ""
            if !sources.contains(id) { sources.append(id) }
        }
        let key = ([code.rawValue] + sources).joined(separator: "\u{1F}")
        if !messages.contains(key) {
            messages.insert(key)
            diagnostics.append(PhraseDiagnostic(code: code, sources: sources))
        }
    }

    private func report(_ code: PhraseDiagnostic.Code, _ owners: VexElement...) {
        report(code, owners)
    }

    private func addParts(_ owner: VexElement, _ stave: Stave, _ parts: [Bounds], _ bridge: Bool = false) {
        for box in parts { obstacles.append(obstacle(box, owner, stave, bridge)) }
    }

    private func engrave(_ owner: VexElement, _ options: GeometryOptions = GeometryOptions()) -> EngravingGeometry {
        // `measureEngraving` throws only for invalid padding, which phrase layout never passes.
        (try? measureEngraving(owner, options: options))
            ?? EngravingGeometry(parts: [], anchors: [:], ink: nil, layout: nil, diagnostics: [])
    }

    private func measure(_ owner: VexElement, _ stave: Stave) {
        let g = engrave(owner)
        if !g.diagnostics.isEmpty { report(.unsupportedGeometry, owner) }
        addParts(owner, stave, g.parts)
    }

    private func isManaged(_ e: VexElement) -> Bool { managed.contains(ObjectIdentifier(e)) }
    private func isPinned(_ e: VexElement) -> Bool { pins.contains(ObjectIdentifier(e)) }

    /// Collect native ink once per owner. Bare staff lines constrain outside lanes but permit notes and curves.
    private func collect(_ notes: [StaveNote], _ staves: [Stave], _ extras: [Tickable]) {
        var beams: [Beam] = []
        var tuplets: [Tuplet] = []
        var rests: [StaveNote] = []
        var marks: [Modifier] = []
        for n in notes {
            let stave = n.checkStave()
            let beam = n.getBeam()
            if n.renderOptions.draw == false { continue }
            if let beam {
                beam.postFormat()
                if !beams.contains(where: { $0 === beam }) { beams.append(beam) }
            }
            for t in n.getTupletStack() where !tuplets.contains(where: { $0 === t }) { tuplets.append(t) }
            if n.isRest() && beam == nil {
                rests.append(n)
                continue
            }
            let geometry = engrave(n, GeometryOptions(extension: { $0 === n ? nil : EngravingShape() }))
            if !geometry.diagnostics.isEmpty { report(.unsupportedGeometry, n) }
            let bridge = splitStemFor(n)?.owner === n
                || (beam?.getNotes().contains(where: { beamStave($0) !== stave }) ?? false)
            for (i, b) in geometry.parts.enumerated() {
                addParts(n, stave, [b], bridge && i == n.noteHeads.count)
            }
            for m in n.getModifiers() {
                if isManaged(m) { continue }
                if (m is Articulation || m is Ornament) && [.above, .below].contains(m.getPosition()) {
                    marks.append(m)
                } else {
                    measure(m, stave)
                }
            }
        }
        for beam in beams {
            let owners = beam.getNotes()
            var ownerStaves: [Stave] = []
            for n in owners {
                guard let s = beamStave(n) else { continue }
                if !ownerStaves.contains(where: { $0 === s }) { ownerStaves.append(s) }
            }
            let bridge = ownerStaves.count > 1
            let strips = beam.getStripBounds()
            for s in ownerStaves {
                addParts(beam, s, strips, bridge)
                if bridge {
                    for peer in notes {
                        if peer.getStave() !== s || owners.contains(where: { $0 === peer }) || peer.isRest()
                            || peer.renderOptions.draw == false {
                            continue
                        }
                        if peer.getHeadInk().contains(where: { head in strips.contains { overlaps(head, $0, 0) } }) {
                            report(.unresolvedCollision, beam, peer)
                        }
                    }
                }
            }
        }
        for stave in staves {
            for modifier in stave.getModifiers() {
                if let clef = modifier as? Clef {
                    if let ink = try? clef.getInkBounds() { addParts(modifier, stave, [ink]) }
                } else if let time = modifier as? TimeSignature {
                    if let ink = try? time.getInkBounds() { addParts(modifier, stave, [ink]) }
                } else if let key = modifier as? KeySignature {
                    addParts(modifier, stave, key.getInkParts())
                } else if !(modifier is Barline) {
                    report(.unsupportedGeometry, modifier)
                }
            }
        }
        for e in extras {
            if let ghost = e as? GhostNote, ghost.getModifiers().isEmpty { continue }
            if let note = e as? Note, let stave = note.getStave(), !fixed.contains(where: { $0.owner === e }) {
                measure(note, stave)
            }
        }
        for (owner, stave) in fixed where !tuplets.contains(where: { $0 === owner }) { measure(owner, stave) }
        // VexFlow 5.6.0: record authored rest positions first so automatic rests can clear them in either voice
        // order.
        for n in rests where n.restLine != nil { placeRest(n) }
        for n in rests where n.restLine == nil { placeRest(n) }
        for m in marks { placeAttachment(m) }
        for t in tuplets {
            if let first = t.getNotes().first { measure(t, first.checkStave()) }
        }
        for stave in staves {
            let top = stave.getYForLine(0)
            let bottom = stave.getYForLine(Double(stave.getNumLines() - 1))
            addParts(stave, stave, [BoundingBox(stave.getX(), top, stave.getWidth(), bottom - top)])
        }
    }

    private func hits(_ parts: [Bounds], _ stave: Stave, _ gap: Double) -> [Obstacle] {
        obstacles.filter { o in o.stave === stave && parts.contains { overlaps($0, o, gap) } }
    }

    private func placeRest(_ note: StaveNote) {
        let stave = note.checkStave()
        let before = note.getKeyLine(0)
        let gap = stave.space(0.15)
        let options = GeometryOptions(extension: { [unowned self] e in self.isManaged(e) ? EngravingShape() : nil })
        let original = engrave(note, options)
        if !original.diagnostics.isEmpty { report(.unsupportedGeometry, note) }
        var parts: [Bounds] = original.parts
        let pinned = note.restLine != nil || isPinned(note)
        if !hits(parts, stave, gap).isEmpty && !pinned {
            // Try whole staff spaces, nearest first, on both sides of the authored rest.
            let sign = note.getStemDirection().signDouble
            for step in [1.0, -1, 2, -2, 3, -3, 4, -4] {
                let delta = step * sign
                let translated: [Bounds] = parts.map {
                    BoundingBox($0.x, $0.y - stave.space(delta), $0.w, $0.h)
                }
                if !hits(translated, stave, gap).isEmpty { continue }
                note.setKeyLine(0, line: before + delta).preFormat()
                restLines.append((note, before, before + delta))
                parts = engrave(note, options).parts
                break
            }
        }
        let remaining = hits(parts, stave, gap)
        if let first = remaining.first {
            report(pinned ? .pinnedCollision : .unresolvedCollision, note, first.owner)
        }
        addParts(note, stave, parts)
    }

    private func setShift(_ mark: Modifier, _ y: Double) {
        if let a = mark as? Articulation { a.setLayoutShiftY(y) }
        if let o = mark as? Ornament { o.setLayoutShiftY(y) }
    }

    private func placeAttachment(_ mark: Modifier) {
        let stave = mark.checkAttachedNote().checkStave()
        let gap = stave.space(0.2)
        let above = mark.getPosition() == .above
        setShift(mark, 0)
        var parts: [Bounds] = engrave(mark).parts
        var step = 1
        while step <= 12 && !isPinned(mark) && !hits(parts, stave, gap).isEmpty {
            setShift(mark, stave.space(Double(step)) * (above ? -1 : 1))
            parts = engrave(mark).parts
            step += 1
        }
        let found = hits(parts, stave, gap)
        if let first = found.first {
            report(isPinned(mark) ? .pinnedCollision : .unresolvedCollision, mark, first.owner)
        }
        addParts(mark, stave, parts)
    }

    private struct PlacedRoute {
        var span: PhraseRoute
        var first: Note
        var last: Note
        var stave: Stave
        var x: Double
        var end: Double
    }

    /// Inner spans reserve their ribbons first. Ties use modest quadratic lifts, slurs a wider cubic search.
    private func placeRoutes(_ notes: [StaveNote]) {
        let membership = Set(notes.map { ObjectIdentifier($0) })
        func member(_ n: Note) -> Bool { membership.contains(ObjectIdentifier(n)) }
        var candidates: [(index: Int, route: PlacedRoute)] = []
        for (order, span) in routes.enumerated() {
            if let tie = span as? StaveTie, !tie.text.isEmpty { report(.unsupportedGeometry, span) }
            let (first, last) = routeNotes(span)
            guard let first, let last, member(first), member(last), first.getStave() === last.getStave(),
                  last.getAbsoluteX() > first.getAbsoluteX() else {
                report(.invalidAnchor, span)
                continue
            }
            if let tie = span as? StaveTie {
                let tieNotes = tie.getNotes()
                let firstCount = first.getYs().count
                let lastCount = last.getYs().count
                if tieNotes.firstIndexes.contains(where: { $0 < 0 || $0 >= firstCount })
                    || tieNotes.lastIndexes.contains(where: { $0 < 0 || $0 >= lastCount }) {
                    report(.invalidAnchor, span)
                    continue
                }
            }
            candidates.append((order, PlacedRoute(
                span: span, first: first, last: last, stave: first.checkStave(),
                x: first.getAbsoluteX(), end: last.getAbsoluteX()
            )))
        }
        // Stable, as the JavaScript `Array.prototype.sort`.
        let placed = candidates.sorted { a, b in
            let ta = a.route.span is StaveTie ? 1 : 0
            let tb = b.route.span is StaveTie ? 1 : 0
            if ta != tb { return ta > tb }
            let la = a.route.end - a.route.x
            let lb = b.route.end - b.route.x
            if la != lb { return la < lb }
            return a.index < b.index
        }.map(\.route)
        for (index, r) in placed.enumerated() {
            let span = r.span
            let stave = r.stave
            let crossing = placed[..<index].first { p in
                p.stave === stave
                    && ((p.x < r.x && r.x < p.end && p.end < r.end) || (r.x < p.x && p.x < r.end && r.end < p.end))
            }
            if let crossing { report(.crossingSpans, span, crossing.span) }
            let pinned = isPinned(span) || span.hasManualControls()
            let fixed = obstacles.filter { o in
                o.stave === stave && o.owner !== stave && o.owner !== r.first && o.owner !== r.last
            }
            let gap = stave.space(0.2)
            var bestRise: Double = 0
            var bestCost = Int.max
            let limit = pinned || crossing != nil ? 0 : (span is StaveTie ? 6 : 16)
            for step in 0...limit {
                let rise = stave.space(Double(step) / 2)
                span.setLayoutRise(rise)
                let parts = (try? span.getRouteParts()) ?? []
                // Minimize intersecting ribbon sections first, then select the shallowest fit.
                let count = parts.filter { b in fixed.contains { overlaps(b, $0, gap) } }.count
                if count < bestCost {
                    bestCost = count
                    bestRise = rise
                }
                if count == 0 { break }
            }
            span.setLayoutRise(bestRise)
            let parts = (try? span.getRouteParts()) ?? []
            if let hit = fixed.first(where: { o in parts.contains { overlaps($0, o, gap) } }) {
                report(pinned ? .pinnedCollision : .unresolvedCollision, span, hit.owner)
            }
            addParts(span, stave, parts)
        }
    }

    /// Reject detached, reversed and foreign anchors before asking a mark for drawing coordinates.
    private func validLane(_ lane: Lane, _ members: Set<ObjectIdentifier>) -> Bool {
        for mark in lane.marks {
            var anchors: [Note?]
            switch mark {
            case let annotation as Annotation:
                guard let note = try? annotation.checkAttachedNoteThrowing() else { return false }
                anchors = [note]
            case let bracket as TextBracket:
                anchors = [bracket.start, bracket.stop]
            case let hairpin as StaveHairpin:
                anchors = hairpin.getNotes()
            case let pedal as PedalMarking:
                anchors = pedal.getNotes()
            default:
                return false
            }
            if anchors.isEmpty { return false }
            for (i, n) in anchors.enumerated() {
                guard let n, members.contains(ObjectIdentifier(n)), n.getStave() === lane.stave else { return false }
                if i > 0, let previous = anchors[i - 1], n.getAbsoluteX() < previous.getAbsoluteX() { return false }
            }
            if engrave(mark).ink == nil {
                report(.unsupportedGeometry, mark)
                return false
            }
        }
        return true
    }

    private func lyricLines(_ lane: Lane, _ ink: [(owner: PhraseMark, box: BoundingBox)], _ gap: Double) -> [BoundingBox] {
        let stave = lane.stave
        var result: [BoundingBox] = []
        guard let syllables = lane.syllables else { return result }

        for (i, s) in syllables.enumerated() {
            guard let text = ink[i].owner as? Annotation else { continue }
            let origin = ((try? text.computeY().y) ?? 0) + text.getYShift()
            let b = ink[i].box
            if !isSupportedText(s.text) || (s.elideWith.map { !isSupportedText($0) } ?? false) {
                report(.unsupportedScript, text)
            }
            if s.extendTo == nil && !s.hyphenAfter { continue }
            let left = b.x + b.w + gap / 2
            let right: Double
            if let extendTo = s.extendTo {
                right = extendTo.getNoteHeadBeginX() + extendTo.getGlyphWidth()
            } else {
                right = i + 1 < ink.count ? ink[i + 1].box.x - gap / 2 : left
            }
            if right - left < gap {
                report(.insufficientLyricSpace, text)
                continue
            }
            if s.extendTo != nil {
                result.append(BoundingBox(left, origin + 1, right - left, 1))
            } else {
                let width = min(stave.space(0.55), right - left)
                result.append(BoundingBox((left + right - width) / 2, origin - text.fontSizeInPixels * 0.28, width, 1))
            }
        }
        return result
    }

    private func laneIsPinned(_ lane: Lane) -> Bool {
        lane.options.baselineSpaces != nil
            || lane.marks.contains { ($0 as? Annotation)?.getTextBaseline() != nil }
    }

    private func placeLane(_ lane: Lane) {
        let stave = lane.stave
        let marks = lane.marks
        let options = lane.options
        let above = options.side == .above
        let gap = stave.space(0.35)
        if let label = lane.stanzaLabel {
            // Align the visible left edges even when the digits have different side bearings.
            let margin = stave.getNoteStartX() - getStanzaColumnWidth(stave) + stave.space(0.4)
            let x = (try? label.computeX().x) ?? 0
            label.setXShift(margin - x + label.textMetrics.actualBoundingBoxLeft)
            stanzaLabels.append(label)
        }
        let authored = marks.compactMap { $0 as? Annotation }.filter { $0.getTextBaseline() != nil }
        let pinned = options.baselineSpaces != nil || !authored.isEmpty
        var y: Double
        if let spaces = options.baselineSpaces {
            y = stave.getYForLine(0) + stave.space(spaces)
        } else {
            y = authored.first?.getTextBaseline()
                ?? stave.getYForLine(above ? 0 : Double(stave.getNumLines() - 1))
        }
        for m in marks { setMarkBaseline(m, y) }
        let labels = marks.compactMap { $0 as? Annotation }
        let boxes = labels.map { engrave($0).ink ?? BoundingBox(0, 0, 0, 0) }
        // Center wedges on the ink of the dynamics instead of the bottom of their glyphs.
        let middle = boxes.isEmpty ? 0 : boxes.reduce(0) { $0 + $1.y + $1.h / 2 - y } / Double(boxes.count)
        var trims: [ObjectIdentifier: (Double, Double)] = [:]
        for case let m as StaveHairpin in marks {
            guard let edges = try? m.getLayoutEdges() else { continue }
            let (left, right) = (edges.left, edges.right)
            var l: Double = 0
            var r: Double = 0
            for b in boxes {
                if b.x - gap <= left && left <= b.x + b.w + gap { l = max(l, b.x + b.w + gap - left) }
                if b.x - gap <= right && right <= b.x + b.w + gap { r = max(r, right - b.x + gap) }
            }
            trims[ObjectIdentifier(m)] = (l, r)
            if left + l >= right - r { report(.unresolvedCollision, [m] + labels) }
            m.setLayoutBaseline(y + middle, l, r)
        }
        func shapes() -> [(owner: PhraseMark, box: BoundingBox)] {
            marks.map { ($0, engrave($0).ink ?? BoundingBox(0, 0, 0, 0)) }
        }
        let initial = shapes()
        let blocks = initial.map(\.box) + lyricLines(lane, initial, gap)
        if !pinned {
            var shift: Double = 0
            for b in blocks {
                for o in obstacles {
                    if o.stave !== stave || o.x + o.w + gap <= b.x || b.x + b.w + gap <= o.x { continue }
                    shift = above ? min(shift, o.y - gap - b.y - b.h) : max(shift, o.y + o.h + gap - b.y)
                }
            }
            y += shift
        }
        for m in marks {
            if let hairpin = m as? StaveHairpin {
                let (l, r) = trims[ObjectIdentifier(hairpin)] ?? (0, 0)
                hairpin.setLayoutBaseline(y + middle, l, r)
            } else {
                setMarkBaseline(m, y)
            }
            if let annotation = m as? Annotation, let baseline = annotation.getTextBaseline(), abs(baseline - y) > 0.01 {
                report(.pinnedCollision, m)
            }
        }
        let final = shapes()
        for (owner, box) in final {
            for hit in hits([box], stave, 0.01) {
                report(pinned ? .pinnedCollision : .unresolvedCollision, owner, hit.owner)
            }
            addParts(owner, stave, [box])
        }
        for box in lyricLines(lane, final, gap) {
            if let hit = hits([box], stave, 0).first {
                report(pinned ? .pinnedCollision : .unresolvedCollision, marks[0], hit.owner)
            }
            addParts(marks[0], stave, [box])
            connectors.append(box)
        }
    }

    /// Refit from the native staff positions on every format, never from the previous solution.
    public func format(_ staves: [Stave], _ voices: [Voice]) {
        let ticks = voices.flatMap { $0.getTickables() }
        let notes = ticks.compactMap { $0 as? StaveNote }
        let members = Set(notes.map { ObjectIdentifier($0) })
        var beams: [Beam] = []
        for n in notes {
            if let beam = n.getBeam(), !beams.contains(where: { $0 === beam }) { beams.append(beam) }
        }
        var pass = 1
        while pass <= iterationLimit {
            passes = pass
            obstacles = []
            connectors = []
            stanzaLabels = []
            diagnostics.removeAll()
            messages.removeAll()
            collect(notes, staves, ticks.filter { !($0 is StaveNote) })
            var automatic: [Lane] = []
            for lane in lanes {
                let invalidSyllables = lane.syllables?.enumerated().contains { i, s in
                    if !members.contains(ObjectIdentifier(s.note)) || s.note.getStave() !== lane.stave { return true }
                    if i > 0, let syllables = lane.syllables,
                       s.note.getAbsoluteX() <= syllables[i - 1].note.getAbsoluteX() {
                        return true
                    }
                    if let extendTo = s.extendTo,
                       !members.contains(ObjectIdentifier(extendTo)) || extendTo.getStave() !== lane.stave
                        || extendTo.getAbsoluteX() < s.note.getAbsoluteX() {
                        return true
                    }
                    return false
                } ?? false
                if !staves.contains(where: { $0 === lane.stave }) || !validLane(lane, members) || invalidSyllables {
                    report(.invalidAnchor, lane.marks[0])
                    continue
                }
                if laneIsPinned(lane) { placeLane(lane) } else { automatic.append(lane) }
            }
            placeRoutes(notes)
            for lane in automatic { placeLane(lane) }
            // Ignore connecting stems when computing the separation they themselves depend on.
            let envelopes = staves.map { stave -> (top: Double, bottom: Double) in
                let boxes = obstacles.filter { $0.stave === stave && !$0.bridge }
                return (
                    boxes.map(\.y).min() ?? .infinity,
                    boxes.map { $0.y + $0.h }.max() ?? -.infinity
                )
            }
            var shift: Double = 0
            var shifts: [Double] = []
            for (i, s) in staves.enumerated() {
                if i == 0 {
                    shifts.append(0)
                    continue
                }
                let need = envelopes[i - 1].bottom + s.space(0.6) - envelopes[i].top
                if need > 0.01 {
                    if lockedStaves.contains(ObjectIdentifier(s)) {
                        report(.pinnedCollision, staves[i - 1], s)
                    } else {
                        shift += need
                    }
                }
                shifts.append(shift)
            }
            if shift == 0 { break }
            if pass == iterationLimit {
                report(.iterationLimit, staves)
                break
            }
            resetPlacement()
            beams.forEach { $0.resetLayout() }
            for (i, s) in staves.enumerated() { s.setY(s.getY() + shifts[i]) }
            for n in ticks {
                if let s = n.getStave() { n.setStave(s) }
            }
            pass += 1
        }
        bounds = nil
        for box in obstacles {
            let part = BoundingBox(box.x, box.y, box.w, box.h)
            bounds = bounds.map { $0.merged(with: part) } ?? part
        }
    }

    /// Staff-space placement in renderer coordinates. The result is a snapshot after format.
    public func getLyricConnectors() -> [BoundingBox] {
        connectors
    }

    /// Draw stanza labels and connectors. Syllables are drawn by their notes.
    public func draw(_ context: RenderContext) throws {
        for label in stanzaLabels { try label.setContext(context).drawWithStyle() }
        for b in connectors { context.fillRect(b.x, b.y, b.w, b.h) }
    }
}
