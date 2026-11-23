// Logic-level tests for the behaviors ported from VexFlow 5.3.0 → 5.4.0 (part 1).
// Ported from tests/node/phrase-layout-tests.mjs and tests/node/instrument-profile-tests.mjs at 5.4.0.
// The node tests use canvas text measurement and a browser; these tests use the CoreText
// measurement of the bundled fonts and the SVG string context.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func expectError(_ text: String, sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
    do {
        try body()
        Issue.record("Expected an error containing '\(text)'", sourceLocation: sourceLocation)
    } catch {
        let message = String(describing: error) + " " + error.localizedDescription
        #expect(message.lowercased().contains(text.lowercased()), "\(message)", sourceLocation: sourceLocation)
    }
}

private func intersects(_ a: BoundingBox, _ b: BoundingBox) -> Bool {
    a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

private func factory(width: Double = 720, height: Double = 420) -> Factory {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    _ = f.setContext(SVGRenderContext(width: width, height: height))
    return f
}

@discardableResult
private func measured(_ element: VexElement, sourceLocation: SourceLocation = #_sourceLocation) throws -> EngravingGeometry {
    let g = try measureEngraving(element)
    #expect(g.diagnostics.isEmpty, "\(element.getCategory()) \(g.diagnostics)", sourceLocation: sourceLocation)
    return g
}

// MARK: - Phrase layout (phrase-layout-tests.mjs)

@Suite("Upstream 5.4.0 port: phrase layout")
struct Upstream54PhraseLayoutTests {

    private struct Score {
        let f: Factory
        let notes: [StemmableNote]
        let system: System
        let staff: Stave
        let layout: PhraseLayout
    }

    private func score(_ text: String = "G4/q, A4/q, B4/q, A4/q, G4/q") -> Score {
        let f = factory()
        let es = f.EasyScore()
        let notes = es.notes(text, options: ["stem": "down"])
        let system = f.System(options: SystemOptions(spaceBetweenStaves: 4, width: 510, y: 30))
        let staff = system.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
        return Score(f: f, notes: notes, system: system, staff: staff, layout: system.getPhraseLayout())
    }

    private struct Choir {
        let f: Factory
        let system: System
        let layout: PhraseLayout
        let notes: [StemmableNote]
        let staff: Stave
        let bass: Stave
        let lyrics: [[Annotation]]
    }

    /// `makePhraseStudy(VF, f, 'choir')` of tests/engraving/phrase-studies.mjs.
    private func choir(_ f: Factory, width: Double = 615) throws -> Choir {
        let es = f.EasyScore()
        let system = f.System(options: SystemOptions(spaceBetweenStaves: 7, width: width, y: 45))
        let layout = system.getPhraseLayout()
        let soft = { (notes: [StemmableNote]) in es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft)) }
        let notes = es.notes("G4/q, A4/8, B4/8, C5/q, B4/q, A4/h", options: ["stem": "up"])
        let lower = es.notes("E4/h, F4/q, G4/q, E4/h", options: ["stem": "down"])
        let staff = system.addStave(SystemStave(voices: [soft(notes)])).addClef(.treble)
        let bass = system.addStave(SystemStave(voices: [soft(lower)])).addClef(.treble)
        _ = try f.BeamThrowing(notes: Array(notes[1...2]))
        let n = notes.map { $0 as! StaveNote }
        let verses: [[PhraseSyllable]] = [
            [
                PhraseSyllable(note: n[0], text: "Sum", hyphenAfter: true),
                PhraseSyllable(note: n[2], text: "mer", extendTo: n[3]),
                PhraseSyllable(note: n[4], text: "is"),
                PhraseSyllable(note: n[5], text: "here"),
            ],
            [
                PhraseSyllable(note: n[0], text: "É", hyphenAfter: true),
                PhraseSyllable(note: n[1], text: "cou", hyphenAfter: true),
                PhraseSyllable(note: n[3], text: "tez", extendTo: n[4]),
                PhraseSyllable(note: n[5], text: "bien"),
            ],
        ]
        let lyrics = try verses.map { try layout.addVerse(staff, $0) }
        return Choir(f: f, system: system, layout: layout, notes: notes, staff: staff, bass: bass, lyrics: lyrics)
    }

    @Test func wholeSyllablesHyphensAndExtendersStayInTheirVersesAcrossRetainedReflow() throws {
        try isolated {
            let f = factory()
            let c = try choir(f)
            func inspect() throws -> [Double] {
                let rows = try c.lyrics.map { verse in try verse.map { try measured($0) } }
                let baselines = rows.map { $0[0].anchors["baseline"]?.y ?? .nan }
                for (i, row) in rows.enumerated() {
                    #expect(row.allSatisfy { $0.anchors["baseline"]?.y == baselines[i] })
                }
                let upper = rows[0].compactMap(\.ink)
                let lower = rows[1].compactMap(\.ink)
                #expect(upper.allSatisfy { a in lower.allSatisfy { b in a.y + a.h < b.y } })
                let links = c.layout.getLyricConnectors()
                #expect(links.count == 5)
                guard links.count == 5, let first = rows[0][0].ink, let second = rows[0][1].ink else { return [] }
                let (hyphen, extender) = (links[0], links[1])
                #expect(hyphen.x > first.x + first.w && hyphen.x + hyphen.w < second.x)
                let end = c.notes[3] as! StaveNote
                #expect(extender.x + extender.w == end.getNoteHeadBeginX() + end.getGlyphWidth())
                let inks = rows.flatMap { $0 }.compactMap(\.ink)
                #expect(links.allSatisfy { link in inks.allSatisfy { !intersects(link, $0) } })
                #expect(c.bass.getYForLine(0) > links.map { $0.y + $0.h }.max() ?? 0)
                #expect(c.layout.diagnostics.isEmpty, "\(c.layout.diagnostics)")
                let bounds = c.layout.bounds ?? BoundingBox(0, 0, 0, 0)
                return rows.flatMap { $0.compactMap(\.ink) }.flatMap { [$0.x, $0.y, $0.w, $0.h] }
                    + links.flatMap { [$0.x, $0.y, $0.w, $0.h] } + [c.bass.getY(), bounds.x, bounds.y, bounds.w, bounds.h]
            }
            c.system.format()
            let wide = try inspect()
            try f.draw(retain: true)
            #expect(try inspect() == wide)
            c.system.setWidth(390).format()
            #expect(try inspect() != wide)
            c.system.setWidth(615).format()
            #expect(try inspect() == wide)
        }
    }

    @Test func aCubicSlurClearsInternalAccentsWhileWedgePedalAndOttavaRetainTheirAnchors() throws {
        try isolated {
            // `makePhraseStudy(VF, f, 'piano')` of tests/engraving/phrase-studies.mjs.
            let f = factory()
            let es = f.EasyScore()
            let system = f.System(options: SystemOptions(spaceBetweenStaves: 7, width: 615, y: 45))
            let layout = system.getPhraseLayout()
            let soft = { (notes: [StemmableNote]) in es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft)) }
            let notes = es.notes("G4/q, C5/q, B4/q, A4/q, G4/q", options: ["stem": "down"])
            let lower = es.notes("C3/h, E3/h, G3/q", options: ["clef": "bass", "stem": "up"])
            let staff = system.addStave(SystemStave(voices: [soft(notes)])).addClef(.treble)
            let bass = system.addStave(SystemStave(voices: [soft(lower)])).addClef(.bass)
            let slur = f.Curve(from: notes[0], to: notes[4], options: CurveOptions(openingDirection: .down))
            _ = notes[1].addModifier(f.Articulation(type: "a>", position: .above), index: 0)
            _ = notes[2].addModifier(f.Articulation(type: "a.", position: .above), index: 0)
            let dynamics = [(Glyphs.dynamicPiano, 0), (Glyphs.dynamicForte, 4)].map { glyph, i -> Annotation in
                let mark = f.Annotation(text: glyph)
                mark.setFont(notes[i].fontInfo)
                _ = notes[i].addModifier(mark, index: 0)
                return mark
            }
            let hairpin = f.StaveHairpin(from: notes[0], to: notes[4], type: .crescendo)
            let pedal = f.PedalMarking(notes: [lower[0] as! StaveNote, lower[2] as! StaveNote], type: .bracket)
            let octave = f.TextBracket(from: notes[0], to: notes[3], text: "8", superscript: "va", position: .top)
            try layout.route(slur)
                .addLane(staff, dynamics + [hairpin])
                .addLane(bass, [pedal])
                .addLane(staff, [octave], options: PhraseLaneOptions(side: .above))
            for width in [615.0, 390, 615] {
                system.setWidth(width).format()
                try f.draw(retain: true)
                #expect(layout.diagnostics.isEmpty, "\(width) \(layout.diagnostics)")
                let routed = try slur.getRouteParts()
                let anchors = try slur.getAnchors()
                let accent = try #require(try measured(notes[1].getModifiers()[0]).ink)
                #expect(routed.allSatisfy { !intersects($0, accent) })
                let ottava = try #require(try measured(octave).ink)
                #expect(ottava.y + ottava.h < routed.map(\.y).min() ?? 0)
                let p = try #require(try measured(dynamics[0]).ink)
                let forte = try #require(try measured(dynamics[1]).ink)
                let wedge = try #require(try measured(hairpin).ink)
                #expect(p.x + p.w < wedge.x && wedge.x + wedge.w < forte.x)
                #expect((try measured(pedal).ink?.y ?? 0) > bass.getYForLine(4))
                slur.setLayoutRise(0)
                let reset = try slur.getAnchors()
                #expect(reset.start.x == anchors.start.x && reset.start.y == anchors.start.y)
                #expect(reset.end.x == anchors.end.x && reset.end.y == anchors.end.y)
                #expect(try slur.getRouteParts() != routed)
            }
        }
    }

    @Test func pinnedVerseAndStaffCollisionsNameTheirOwnersAndTerminate() throws {
        try isolated {
            let s = score()
            let bottom = s.system.addStave(SystemStave(voices: []))
            s.layout.lockStaffGap(bottom)
            let ids = ["one", "two"]
            for id in ids {
                let mark = try s.layout.addVerse(
                    s.staff, [PhraseSyllable(note: s.notes[0] as! StaveNote, text: "word")],
                    options: PhraseLaneOptions(baselineSpaces: 7)
                )[0]
                _ = mark.setAttribute("id", id)
            }
            s.system.format()
            #expect(s.layout.diagnostics.contains { $0.code == .pinnedCollision && ids.allSatisfy($0.sources.contains) })
            let bottomId = bottom.getAttribute("id") ?? ""
            #expect(s.layout.diagnostics.contains { $0.code == .pinnedCollision && $0.sources.contains(bottomId) })
            for m in s.notes[0].getModifiers() {
                #expect(try measured(m).anchors["baseline"]?.y == s.staff.getYForLine(7))
            }
            #expect(s.layout.passes == 1)
        }
    }

    @Test func aRestrictedPassBudgetLeavesFiniteRepeatableEvidence() throws {
        try isolated {
            let c = try choir(factory())
            try c.layout.setPassLimit(1)
            func inspect() -> ([PhraseDiagnostic], [Double], Int) {
                c.system.format()
                let b = c.layout.bounds ?? BoundingBox(.nan, .nan, .nan, .nan)
                return (c.layout.diagnostics, [b.x, b.y, b.w, b.h], c.layout.passes)
            }
            let first = inspect()
            #expect(first.2 == 1)
            #expect(first.0.contains { $0.code == .iterationLimit })
            #expect(first.1.allSatisfy { $0.isFinite })
            let second = inspect()
            #expect(second.0 == first.0 && second.1 == first.1 && second.2 == first.2)
            try c.layout.setPassLimit(4)
            c.system.format()
            #expect(c.layout.diagnostics.isEmpty, "\(c.layout.diagnostics)")
            expectError("pass limit") { try c.layout.setPassLimit(17) }
        }
    }

    @Test func unsupportedScriptAndInvalidAnchorsNameTheMark() throws {
        try isolated {
            let s = score()
            let texts = ["E\u{0301}", "歌", "سلام"]
            let marks = try s.layout.addVerse(
                s.staff, texts.enumerated().map { PhraseSyllable(note: s.notes[$0] as! StaveNote, text: $1) }
            )
            let detached = s.f.Annotation(text: "detached")
            try s.layout.addLane(s.staff, [detached])
            let truncated = s.f.StaveTie(notes: TieNotes(firstNote: s.notes[3]))
            s.layout.route(truncated)
            s.system.format()
            #expect(marks.map(\.text) == texts)
            #expect(s.layout.diagnostics.filter { $0.code == .unsupportedScript }.map(\.sources)
                == [[marks[2].getAttribute("id") ?? ""]])
            for m in [detached, truncated] as [VexElement] {
                let id = m.getAttribute("id") ?? ""
                #expect(s.layout.diagnostics.contains { $0.code == .invalidAnchor && $0.sources.contains(id) })
            }
            expectError("exactly one lane") { try s.layout.addLane(s.staff, [detached]) }
        }
    }

    @Test func nestedRoutesPreserveTiedChordIndicesManualControlsAndCrossingDiagnostics() throws {
        try isolated {
            let s = score("(G4 B4)/q, (G4 B4)/q, (G4 B4)/q, (G4 B4)/q, (G4 B4)/q")
            let tie = s.f.StaveTie(
                notes: TieNotes(firstNote: s.notes[1], lastNote: s.notes[3], firstIndexes: [1], lastIndexes: [1]),
                direction: .up
            )
            let slur = s.f.Curve(
                from: s.notes[0], to: s.notes[4],
                options: CurveOptions(cps: [(2, 39), (3, 43)], openingDirection: .down)
            )
            s.system.format()
            let manual = try slur.getRouteParts()
            s.layout.route(slur).route(tie)
            s.system.format()
            #expect(try slur.getRouteParts() == manual)
            #expect(tie.getNotes().firstIndexes == [1])
            #expect(try tie.getRouteParts().count > 1)
            #expect(!s.layout.diagnostics.contains { $0.code == .crossingSpans })
            let cross = s.f.Curve(from: s.notes[0], to: s.notes[2])
            s.layout.route(cross)
            s.system.format()
            let id = cross.getAttribute("id") ?? ""
            #expect(s.layout.diagnostics.contains { $0.code == .crossingSpans && $0.sources.contains(id) })
        }
    }

    @Test func aRestClearsInkAnchoredAtAnEarlierAttackAndReportsACollisionWhenPinned() throws {
        for pin in [false, true] {
            try isolated {
                let s = score("G4/q, B4/q/r, G4/q")
                let host = s.notes[0] as! StaveNote
                let rest = s.notes[1] as! StaveNote
                let obstruction = s.f.Annotation(text: "x")
                _ = host.addModifier(obstruction, index: 0)
                s.system.format()
                let b = try #require(try measured(rest).ink)
                let a = try #require(try measured(obstruction).ink)
                _ = obstruction.setXShift(a.x - b.x)
                _ = try obstruction.setTextBaseline(try obstruction.computeY().y + b.y - a.y)
                #expect(rest.isRest())
                let original = rest.getKeyLine(0)
                if pin { s.layout.pin(rest) }
                s.system.format()
                let restInk = try #require(try measured(rest).ink)
                let markInk = try #require(try measured(obstruction).ink)
                #expect(intersects(restInk, markInk) == pin)
                #expect((rest.getKeyLine(0) == original) == pin)
                #expect(s.layout.diagnostics.contains { $0.code == .pinnedCollision } == pin)
                let line = rest.getKeyLine(0)
                s.system.format()
                #expect(rest.getKeyLine(0) == line)
                #expect(host.getStave() === s.staff)
            }
        }
    }

    @Test func clefsKeyAndTimeSignaturesFollowTheLowerStaveOnEachStaffRefit() throws {
        try isolated {
            let c = try choir(factory())
            c.bass.addKeySignature("E").addTimeSignature(try #require(TimeSignatureSpec(parsing: "6/8")))
            let key = try #require(c.bass.getModifiers().compactMap { $0 as? KeySignature }.first)
            let meter = try #require(c.bass.getModifiers().compactMap { $0 as? TimeSignature }.first)
            func inspect() throws -> [Double] {
                c.system.format()
                #expect(c.layout.diagnostics.isEmpty, "\(c.layout.diagnostics)")
                return (key.getInkParts() + [try meter.getInkBounds()]).map { $0.y - c.bass.getY() }
            }
            let initial = try inspect()
            #expect(initial.count == 5)
            c.system.setY(c.system.getY() + 80)
            let moved = try inspect()
            #expect(zip(moved, initial).allSatisfy { abs($0 - $1) < 1e-9 })
        }
    }

    @Test func systemBoundingBoxIncludesThePhraseBounds() throws {
        try isolated {
            let c = try choir(factory())
            c.system.format()
            let phrase = try #require(c.layout.bounds)
            let box = try #require(c.system.getBoundingBox())
            #expect(box.y + box.h >= phrase.y + phrase.h)
            #expect(box.y <= phrase.y)
            let svg = SVGRenderContext(width: 720, height: 420)
            _ = c.f.setContext(svg)
            try c.f.draw()
            // The lyric connectors draw as filled rectangles.
            #expect(svg.getSVG().contains("<rect"))
        }
    }
}

// MARK: - Modules used by the phrase layout

@Suite("Upstream 5.4.0 port: layout geometry")
struct Upstream54GeometryTests {

    @Test func ribbonPartsEncloseTheCurveAndStopSubdividingAtSixPixels() {
        let upper = [RibbonPoint(x: 0, y: 0), RibbonPoint(x: 50, y: -20), RibbonPoint(x: 100, y: 0)]
        let lower = [RibbonPoint(x: 0, y: 0), RibbonPoint(x: 50, y: -16), RibbonPoint(x: 100, y: 0)]
        let parts = ribbonParts(upper, lower, padding: 0.5)
        #expect(parts.count == 32)
        #expect(parts.allSatisfy { $0.w <= 7.25 })
        #expect(abs((parts.map(\.x).min() ?? 1) + 0.5) < 1e-9)
        #expect(abs((parts.map { $0.x + $0.w }.max() ?? 0) - 100.5) < 1e-9)
    }

    @Test func hairpinPedalAndTextBracketExposeTheirDrawnGeometry() throws {
        try isolated {
            let f = factory()
            let es = f.EasyScore()
            let notes = es.notes("G4/q, C5/q, B4/q, A4/q", options: ["stem": "down"])
            let lower = es.notes("C3/h, G3/h", options: ["clef": "bass", "stem": "up"])
            let system = f.System(options: SystemOptions(width: 500, y: 40))
            _ = system.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
            _ = system.addStave(SystemStave(voices: [es.voice(lower, options: EasyScoreVoiceOptions(mode: .soft))]))
            let hairpin = f.StaveHairpin(from: notes[0], to: notes[3], type: .crescendo)
            let pedal = f.PedalMarking(notes: lower.map { $0 as! StaveNote }, type: .bracket)
            let octave = f.TextBracket(from: notes[0], to: notes[2], text: "8", superscript: "va")
            system.format()
            for mark in [hairpin, pedal, octave] as [VexElement] {
                let g = try measured(mark)
                #expect((g.ink?.w ?? 0) > 0 && (g.ink?.h ?? 0) > 0, "\(mark.getCategory())")
            }
            let edges = try hairpin.getLayoutEdges()
            hairpin.setLayoutBaseline(200, 3, 4)
            let moved = try hairpin.getLayoutEdges()
            #expect(moved.top == 200 - moved.height / 2)
            #expect(moved.left == edges.left + 3 && moved.right == edges.right - 4)
            pedal.setLayoutBaseline(300)
            #expect(pedal.getYForStave(lower[0].checkStave()) == 300)
            let before = try #require(octave.getBoundingBox())
            octave.setLayoutBaseline(10)
            let after = try #require(octave.getBoundingBox())
            #expect(after.y < before.y)
        }
    }

    @Test func barlineSpanShortensTheBarsOfAOneLineStave() throws {
        try isolated {
            let stave = Stave(x: 10, y: 10, width: 300, options: StaveOptions(barlineSpan: StaveBarlineSpan(top: 1, bottom: 3)))
            let bounds = try stave.getBarlineBounds()
            #expect(bounds.botY - bounds.topY == 21)
            let bad = Stave(x: 10, y: 10, width: 300, options: StaveOptions(barlineSpan: StaveBarlineSpan(top: 3, bottom: 1)))
            expectError("StaveConfigError") { _ = try bad.getBarlineBounds() }
        }
    }

    @Test func boundaryModifiersJoinTheStaveModifiersAndCourtesyClef() throws {
        try isolated {
            let stave = Stave(x: 10, y: 10, width: 300)
            let count = stave.getModifiers().count
            let courtesy = Clef(type: .bass)
            courtesy.setPosition(.end)
            stave.setBoundaryModifiers([courtesy])
            #expect(stave.getModifiers().count == count + 1)
            #expect(stave.getEndClef() == .bass)
            stave.setBoundaryModifiers([])
            #expect(stave.getModifiers().count == count)
        }
    }

    @Test func orderedKeySignatureUsesExplicitLines() throws {
        try isolated {
            let stave = Stave(x: 10, y: 10, width: 300)
            let key = KeySignature(keySpec: "C")
            _ = key.setStave(stave)
            try key.setOrdered([(type: "b", line: 2), (type: "#", line: 1.5)])
            let parts = key.getInkParts()
            #expect(parts.count == 2)
            expectError("BadArguments") { try key.setOrdered([(type: "b", line: 0.25)]) }
            key.setKeySig("D")
            #expect(key.getInkParts().count == 2)
        }
    }
}

// MARK: - Instrument profiles (instrument-profile-tests.mjs)

@Suite("Upstream 5.4.0 port: instrument profiles")
struct Upstream54InstrumentTests {

    @Test func percussionKeepsMixedHeadIdentitiesAndStems() throws {
        try isolated {
            let kit = try PercussionMap()
            let attack = try kit.note(["snare", "hat"], duration: "q")
            let native = StaveNote(attack)
            #expect(native.getKeyProps().map(\.line) == [3.5, 5.5])
            #expect(native.noteHeads[0].getText() != native.noteHeads[1].getText())
            #expect(try kit.note(["kick"], duration: "q").stemDirection == .down)
            #expect(try kit.note(["kick"], duration: "q", stem: .up).stemDirection == .up)
            #expect(native.notation.map { [$0.id, "\($0.index ?? -1)"] } == [["snare", "0"], ["hat", "1"]])
            expectError("Unknown percussion") { _ = try kit.note(["missing"], duration: "q") }
            expectError("Duplicate") {
                _ = try PercussionMap([PercussionMap.kit[0], PercussionMap.kit[0]])
            }

            // The SVG group of the note carries the spoken names.
            let f = factory()
            let note = f.StaveNote(attack)
            let system = f.System(options: SystemOptions(width: 300, y: 20))
            _ = system.addStave(SystemStave(voices: [f.EasyScore().voice([note], options: EasyScoreVoiceOptions(mode: .soft))]))
                .addClef(.percussion)
            let svg = SVGRenderContext(width: 400, height: 200)
            _ = f.setContext(svg)
            try f.draw()
            #expect(svg.getSVG().contains("aria-label=\"Snare drum, Closed hi-hat\""))
        }
    }

    @Test func tremoloDividesWrittenDurationWhileRetainingStrokesAndRejectsUnrelatedEndpoints() throws {
        try isolated {
            let f = factory()
            let spec = try StaveNoteStruct(parsingKeys: ["c/4"], duration: "h")
            let notes = try [spec, spec, spec, spec].map { f.StaveNote(try AlternatingTremolo.endpoint($0, strokes: 3)) }
            #expect(notes[0].getDuration() == "2")
            #expect((notes[0].getTicks().value() + notes[1].getTicks().value()) / Double(Tables.RESOLUTION) == 0.5)
            let system = f.System(options: SystemOptions(width: 400, y: 20))
            _ = system.addStave(SystemStave(voices: [f.EasyScore().voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
            let tremolo = try AlternatingTremolo(first: notes[0], last: notes[1], strokes: 3)
            let svg = SVGRenderContext(width: 500, height: 200)
            _ = f.setContext(svg)
            try f.draw()
            _ = tremolo.setContext(svg)
            try tremolo.draw()
            let output = svg.getSVG()
            let group = try #require(output.range(of: "class=\"vf-alternating-tremolo\""))
            #expect(output[group.upperBound...].components(separatedBy: "</g>")[0].components(separatedBy: "<path").count - 1 == 3)
            let bad = try AlternatingTremolo(first: notes[0], last: notes[2], strokes: 3)
            _ = bad.setContext(svg)
            expectError("BadArguments") { try bad.draw() }
            expectError("BadArguments") { _ = try AlternatingTremolo(first: notes[0], last: notes[1], strokes: 5) }
            expectError("BadArguments") {
                _ = try AlternatingTremolo.endpoint(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "8"), strokes: 1)
            }
        }
    }

    @Test func tuningAndCapoPreserveDisplayedFretsAndTheDiagramEncodesStrings() throws {
        try isolated {
            let guitar = try FrettedInstrument("dropd", capo: 2)
            let pair = try guitar.attack([.fret(str: 6, fret: 0), .fret(str: 2, fret: 3)], duration: "q")
            #expect(pair.note.keys.array.map(\.rawValue).map { $0.lowercased() } == ["e/3", "e/5"])
            #expect(pair.tab.positions.map(\.fret) == ["0", "3"])
            expectError("BadArguments") { _ = try FrettedInstrument().attack([.fret(str: 1, fret: -1)], duration: "q") }
            expectError("BadArguments") { _ = try FretDiagram(FretDiagramSpec(frets: [.muted, .fret(9)])) }

            let frame = try FretDiagram(FretDiagramSpec(
                frets: [.muted, .fret(0), .fret(2), .fret(2), .fret(2), .fret(0)],
                barre: FretDiagramSpec.Barre(fret: 2, from: 2, to: 4)
            ))
            let svg = SVGRenderContext(width: 200, height: 200)
            _ = frame.setX(20).setY(20)
            _ = frame.setContext(svg)
            try frame.draw()
            #expect(svg.getSVG().contains("Chord frame, low to high: x, 0, 2, 2, 2, 0, barre at fret 2"))
            #expect((frame.getBoundingBox()?.w ?? 0) > 30)
        }
    }

    @Test func rasgueadoAndTimedBendsAttachNativeModifiers() throws {
        try isolated {
            let guitar = try FrettedInstrument()
            let strokes = try guitar.rasgueado(
                [.fret(str: 1, fret: 0), .fret(str: 2, fret: 1)],
                [
                    (GuitarStroke(finger: .i, direction: .bassToTreble), "8"),
                    (GuitarStroke(finger: .m, direction: .trebleToBass, golpe: true), "8"),
                ]
            )
            #expect(strokes.map { $0.offset.value() } == [0, 0.125])
            let note = StaveNote(strokes[1].note)
            #expect(note.getModifiers().contains { $0 is Stroke })
            let fingers = note.getModifiers().compactMap { $0 as? Annotation }.map(\.text)
            #expect(fingers == ["m + golpe"])
            #expect(strokes[1].note.notation.last?.label == "Rasgueado, m, treble to bass, simultaneous golpe")

            let bend = TimedStringBend(string: 2, semitones: 2, rise: (1, 4), hold: (1, 2), release: (3, 4))
            let attack = try guitar.bentAttack([.fret(str: 2, fret: 5)], duration: "q", bend)
            #expect(attack.note.notation.last?.label
                == "String 2, bend 2 semitones by 1/4, hold to 1/2, release to pitch by 3/4")
            let tab = TabNote(attack.tab)
            #expect(tab.tabInitError == nil)
            let timed = try #require(tab.getModifiers().compactMap { $0 as? Bend }.first)
            #expect(timed.getWidth() >= 48)
            expectError("BadArguments") {
                _ = try copyBend(TimedStringBend(string: 1, semitones: 1, rise: (1, 2), hold: (1, 4)))
            }
            #expect(bendAmount(TimedStringBend(string: 1, semitones: 1, rise: (1, 2))) == "½")
            #expect(bendAmount(TimedStringBend(string: 1, semitones: 3, rise: (1, 2))) == "3 st")
            // A bent string outside the chord is reported on the tab note.
            var wrong = attack.tab
            wrong.positions = [TabNotePosition(str: 3, fret: 5)]
            #expect(TabNote(wrong).tabInitError != nil)
        }
    }

    @Test func writtenAccidentalStateKeepsOrderCancellationAndOctaveMemory() throws {
        let state = WrittenAccidentalState(signature: ["g": "o"])
        var sequence = [
            try state.sign("g/4", "o"),
            try state.sign("g/4", "n"),
            try state.sign("g/5", "o"),
            try state.sign("g/4", "n", cautionary: true),
        ]
        state.reset()
        sequence.append(try state.sign("g/4", "o"))
        #expect(sequence == [nil, "n", nil, "n", nil])
        expectError("BadArguments") { _ = try state.sign("h/4", "n") }
    }

    @Test func pitchKeyAndRhythmChangesAreOptInAndPreserveExplicitSpelling() throws {
        #expect(try ["b/4", "db/5"].map { try NotationSpelling.transpose($0, semitones: 2, steps: 1) } == ["c#/5", "eb/5"])
        #expect(try NotationSpelling.transpose("c/4", semitones: 1, steps: 1) == "db/4")
        #expect(try NotationSpelling.transposeKey("Fm", semitones: 2, steps: 1) == "Gm")
        let parts = try NotationSpelling.rhythm(48, 40, cuts: [80, 64, 80])
        #expect(parts.map { "\($0.start) \($0.duration) \($0.tieNext)" } == ["48 4 true", "64 4 true", "80 8 false"])
        #expect(try NotationSpelling.rhythm(10, 24, cuts: [16, 32], rest: true).allSatisfy { !$0.tieNext })
        expectError("BadArguments") { _ = try NotationSpelling.transpose("c/4", semitones: 9, steps: 0) }
        expectError("BadArguments") { _ = try NotationSpelling.rhythm(1, 0) }
    }
}
