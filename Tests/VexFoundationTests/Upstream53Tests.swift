// Logic-level tests for the behaviors ported from VexFlow 5.2.0 → 5.3.0.
// Ported from tests/node/{engraving-layout,proportional-spacing,easyscore}-tests.mjs
// and the QUnit asserts in tests/{bend,curve,formatter,threevoice}_tests.ts at 5.3.0.
// The node tests use canvas text measurement; these tests use the CoreText measurement
// of the bundled fonts.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func close(_ actual: Double, _ expected: Double, tolerance: Double = 1e-7, _ comment: Comment? = nil,
                   sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(actual - expected) < tolerance, comment ?? "\(actual) ≈ \(expected)", sourceLocation: sourceLocation)
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

private func boxValues(_ box: BoundingBox?) -> [Double] {
    guard let box else { return [] }
    return [box.x, box.y, box.w, box.h]
}

// MARK: - Engraving profiles and geometry (engraving-layout-tests.mjs)

@Suite("Upstream 5.3.0 port: engraving layout")
struct Upstream53EngravingTests {

    private func profile(_ family: String, beamThickness: Double? = nil, clearance: Double? = nil) throws -> EngravingProfile {
        try EngravingProfile(
            musicFont: family,
            metadata: EngravingProfile.bundledMetadata(for: family),
            beamThickness: beamThickness,
            clearance: clearance
        )
    }

    private func factory(_ engraving: EngravingProfile? = nil) -> Factory {
        let f = Factory(options: FactoryOptions(width: 800, height: 720, engraving: engraving))
        _ = f.setContext(SVGRenderContext(width: 800, height: 720))
        return f
    }

    @discardableResult
    private func measured(_ element: VexElement, sourceLocation: SourceLocation = #_sourceLocation) throws -> EngravingGeometry {
        let result = try measureEngraving(element)
        #expect(result.diagnostics.isEmpty, "\(element.getCategory()) \(result.diagnostics)", sourceLocation: sourceLocation)
        #expect((result.ink?.w ?? 0) > 0 && (result.ink?.h ?? 0) > 0, "\(element.getCategory())", sourceLocation: sourceLocation)
        return result
    }

    private struct Scene {
        let f: Factory
        let notes: [StemmableNote]
        let system: System
        let beam: Beam
        let curve: VexFoundation.Curve

        func snapshot() throws -> [[Double]] {
            let elements: [VexElement] = [beam] + notes + [curve]
            return try elements.map { element in
                let result = try measureEngraving(element)
                #expect(result.diagnostics.isEmpty, "\(element.getCategory()) \(result.diagnostics)")
                #expect((result.ink?.w ?? 0) > 0 && (result.ink?.h ?? 0) > 0)
                return result.parts.flatMap(boxValues) + boxValues(result.ink)
                    + result.anchors.keys.sorted().flatMap { [result.anchors[$0]!.x, result.anchors[$0]!.y] }
            }
        }
    }

    /// The slur, stacked articulations and slashed grace group stress the same lifecycle as the M0 fixtures.
    private func engravingScene(_ policy: EngravingProfile?) throws -> Scene {
        let f = factory(policy)
        let es = f.EasyScore()
        let notes = es.notes("G4/16, B4/16, (D5 E5)/8, E4/q", options: ["stem": "up"])
        let beam = try f.BeamThrowing(notes: Array(notes[0..<2]))
        let graces = try ["c/5", "a/4"].map {
            f.GraceNote(try GraceNoteStruct(parsingKeys: [$0], duration: "16", slash: true)) as StemmableNote
        }
        let group = f.GraceNoteGroup(notes: graces, slur: true).beamNotes()
        _ = notes[2].addModifier(group, index: 0)
        for type in ["a.", "a>"] {
            _ = notes[3].addModifier(f.Articulation(type: type, position: .below), index: 0)
        }
        let curve = f.Curve(from: notes[0], to: notes[2], options: CurveOptions(openingDirection: .down))
        let system = f.System(options: SystemOptions(width: 450, y: 65))
        _ = system.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
        return Scene(f: f, notes: notes, system: system, beam: beam, curve: curve)
    }

    @Test func geometryIsAvailableBeforeDrawAndRepeatsAcrossMeasureDrawAndReflow() throws {
        try isolated {
            let policy = try profile("Bravura")
            let scene = try engravingScene(policy)
            scene.system.format()
            let baseline = try scene.snapshot()
            #expect(!scene.notes[0].isRendered())
            #expect(try scene.snapshot() == baseline)
            try scene.f.draw(retain: true)
            #expect(try scene.snapshot() == baseline)
            scene.system.setWidth(255).format()
            #expect(try scene.snapshot() != baseline)
            scene.system.setWidth(450).format()
            let fresh = try engravingScene(policy)
            fresh.system.format()
            let current = try scene.snapshot()
            let freshSnapshot = try fresh.snapshot()
            #expect(current == freshSnapshot)
            #expect(try scene.snapshot() == baseline)
        }
    }

    @Test func twoLiveScoresIndependentlyConsumeGlyphMetricsAnchorsAndBeamPolicy() throws {
        try isolated {
            let a = try engravingScene(try profile("Bravura"))
            let b = try engravingScene(try profile("Petaluma", beamThickness: 0.7, clearance: 0.5))
            a.system.format()
            let original = try a.snapshot()
            b.system.format()
            try b.f.draw(retain: true)
            #expect(try a.snapshot() == original)
            let headA = (a.notes[0] as? StaveNote)?.noteHeads[0]
            let headB = (b.notes[0] as? StaveNote)?.noteHeads[0]
            #expect(headA?.fontInfo.family == "Bravura")
            #expect(headB?.fontInfo.family == "Petaluma")
            #expect(a.beam.renderOptions.beamWidth == 5)
            close(b.beam.renderOptions.beamWidth, 7)
            #expect((b.notes[0] as? StaveNote)?.getHeadInk()[0].w != (a.notes[0] as? StaveNote)?.getHeadInk()[0].w)
            let glyph = Glyphs.noteheadBlack
            #expect(try profile("Petaluma").stemAnchor(glyph, direction: .up) == EngravingAnchor(x: 1.336, y: 0.288))
            let invalid: [String: Any] = [
                "fontName": "Petaluma",
                "engravingDefaults": ["beamThickness": Double.infinity],
                "glyphsWithAnchors": ["noteheadBlack": ["stemUpSE": [0, Double.nan]]],
            ]
            for metadata in [nil, [String: Any](), invalid] as [[String: Any]?] {
                let fallback = try EngravingProfile(musicFont: "Petaluma", metadata: metadata)
                #expect(fallback.stemAnchor(glyph, direction: .up) == nil)
                #expect(fallback.beamThickness == 0.5)
                let scene = try engravingScene(fallback)
                scene.system.format()
                _ = try scene.snapshot()
            }
            #expect(throws: EngravingProfileError.invalidDistance) { try profile("Bravura", beamThickness: .nan) }
            #expect(throws: EngravingProfileError.missingMusicFont) { try EngravingProfile(musicFont: " ") }
            // Metadata of another family is ignored.
            let other = try EngravingProfile(musicFont: "Bravura", metadata: EngravingProfile.bundledMetadata(for: "Petaluma"))
            #expect(other.stemAnchor(glyph, direction: .up) == nil)
        }
    }

    @Test func bundledMetadataCoversBravuraPetalumaAndLeland() throws {
        for family in ["Bravura", "Petaluma", "Leland"] {
            let metadata = try #require(EngravingProfile.bundledMetadata(for: family))
            #expect(metadata["fontName"] as? String == family)
            let profile = try EngravingProfile.bundled(musicFont: family)
            #expect(profile.beamThickness == 0.5)
            #expect(profile.stemAnchor(Glyphs.noteheadBlack, direction: .up) != nil)
            #expect(profile.stemAnchor(Glyphs.noteheadBlack, direction: .down) != nil)
        }
        #expect(EngravingProfile.bundledMetadata(for: "Gonville") == nil)
    }

    @Test func beamClearsAHeadWhoseAttackFallsStrictlyBetweenItsStems() throws {
        try isolated {
            func build(_ peerKey: String) throws -> (strip: BoundingBox, obstacle: BoundingBox) {
                let f = factory()
                let es = f.EasyScore()
                let notes = es.notes("C4/8, C4/8", options: ["stem": "up"])
                let others = try zip(["b/4", peerKey, "b/4"], ["16r", "16", "8r"]).map { key, duration in
                    f.StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: duration, stemDirection: .down))
                }
                let beam = try f.BeamThrowing(notes: notes)
                let system = f.System(options: SystemOptions(width: 360, y: 50))
                _ = system.addStave(SystemStave(voices: [
                    es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft)),
                    es.voice(others, options: EasyScoreVoiceOptions(mode: .soft)),
                ]))
                system.format()
                return (try #require(try measured(beam).ink), others[1].getHeadInk()[0])
            }
            let control = try build("g/5")
            let actual = try build("c/5")
            #expect(actual.obstacle.x > actual.strip.x
                    && actual.obstacle.x + actual.obstacle.w < actual.strip.x + actual.strip.w)
            #expect(control.strip.y < actual.obstacle.y + actual.obstacle.h
                    && control.strip.y + control.strip.h > actual.obstacle.y)
            #expect(actual.strip.y >= actual.obstacle.y + actual.obstacle.h)
        }
    }

    @Test func lyricsAndCrossStaffStemsConsumeThePreDrawCoordinates() throws {
        try isolated {
            let f = factory()
            let es = f.EasyScore()
            let notes = es.notes("G4/8, C5/8", options: ["stem": "down"])
            let system = f.System(options: SystemOptions(width: 330, y: 10))
            let top = system.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
            let bottom = system.addStave(SystemStave(voices: []))
            _ = notes[1].setStave(bottom)
            let beam = try f.BeamThrowing(notes: notes)
            let lyrics = notes.enumerated().map { i, n -> Annotation in
                let mark = f.Annotation(text: ["sum", "mer"][i], vJustify: .bottom)
                _ = n.addModifier(mark, index: 0)
                return mark
            }
            system.format()
            let obstacle = try measured(beam)
            #expect(notes[0].getStave() === top)
            #expect(notes[1].getStave() === bottom)
            for (i, n) in notes.enumerated() {
                let tip = try #require(try measured(n).anchors["stemTip"])
                close(try #require(obstacle.anchors["stem\(i)"]).y, tip.y + Stem.WIDTH / 2)
            }
            // Place one lyric row below the occupied area. Exclude its own old baseline on a second pass.
            func placeLyricRow() throws -> Double {
                let options = GeometryOptions(extension: { element in
                    lyrics.contains { $0 === element } ? EngravingShape() : nil
                })
                let obstacles = try ([beam] + notes as [VexElement]).compactMap { try measureEngraving($0, options: options).layout }
                let baseline = (obstacles.map { $0.y + $0.h }.max() ?? 0) + top.getSpacingBetweenLines()
                    + (lyrics.map { $0.getTextMetrics().actualBoundingBoxAscent }.max() ?? 0)
                for mark in lyrics { _ = try mark.setTextBaseline(baseline) }
                return baseline
            }
            let baseline = try placeLyricRow()
            #expect(try placeLyricRow() == baseline)
            #expect(try lyrics.map { try #require(try measured($0).anchors["baseline"]).y } == [baseline, baseline])
        }
    }

    @Test func unsupportedChildrenAndOverflowAreAttributedToTheirSource() throws {
        try isolated {
            let scene = try engravingScene(nil)
            scene.system.format()
            let n = scene.notes[0]
            let extra = Modifier()
            extra.setAttribute("id", "extension")
            _ = n.addModifier(extra, index: 0)
            let d = try measureEngraving(n, options: GeometryOptions(viewport: BoundingBox(x: 0, y: 0, w: 1, h: 1)))
            #expect(d.diagnostics.map { [$0.code.rawValue, $0.sourceId] } == [
                ["UnsupportedGeometry", "extension"],
                ["LayoutOverflow", n.getAttribute("id") ?? ""],
            ])
            let custom = try measureEngraving(extra, options: GeometryOptions(
                extension: { _ in EngravingShape(parts: [BoundingBox(x: 3, y: 5, w: 8, h: 6)]) },
                paddingPx: 2
            ))
            #expect(custom.layout == BoundingBox(x: 1, y: 3, w: 12, h: 10))
            let invalid = try measureEngraving(extra, options: GeometryOptions(
                extension: { _ in EngravingShape(anchors: ["tip": EngravingPoint(x: .infinity, y: 0)]) }
            ))
            #expect(invalid.diagnostics == [GeometryDiagnostic(
                code: .invalidGeometry, phase: "measure", severity: .error, sourceId: "extension"
            )])
            let lone = StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "q"))
            #expect(try measureEngraving(lone).diagnostics.first?.code == .unformattedGeometry)
            #expect(throws: EngravingGeometryError.invalidPadding) {
                try measureEngraving(extra, options: GeometryOptions(paddingPx: -1))
            }
        }
    }

    /// The node test compares the measured box with raster ink. Here, compare with the drawn SVG path and text rows.
    @Test func measuredInkEnclosesTheStemsAndHeadsForBothDirectionsAndFonts() throws {
        try isolated {
            for family in ["Bravura", "Petaluma"] {
                for direction in [StemDirection.up, .down] {
                    let f = factory(try profile(family))
                    let notes = try [["d/6", "e/6"], ["f/4"]].map { keys in
                        f.StaveNote(try StaveNoteStruct(parsingKeys: keys, duration: "16", stemDirection: direction))
                    }
                    _ = notes[0].addModifier(
                        f.Articulation(type: "a.", position: direction == .up ? .above : .below), index: 0
                    )
                    let system = f.System(options: SystemOptions(width: 400, y: 120))
                    _ = system.addStave(SystemStave(voices: [
                        f.EasyScore().voice(notes, options: EasyScoreVoiceOptions(mode: .soft)),
                    ]))
                    system.format()
                    for note in notes {
                        let ink = try #require(try measured(note).ink)
                        for head in note.getHeadInk() {
                            #expect(head.x >= ink.x - 1e-9 && head.x + head.w <= ink.x + ink.w + 1e-9)
                        }
                        let segment = try #require(note.getStemSegment())
                        #expect(segment.x >= ink.x && segment.x <= ink.x + ink.w)
                        #expect(min(segment.baseY, segment.tipY) >= ink.y - 1e-9)
                        #expect(max(segment.baseY, segment.tipY) <= ink.y + ink.h + 1e-9)
                        // Drawing does not change the measured geometry.
                        let ctx = SVGRenderContext(width: 800, height: 720)
                        _ = note.setContext(ctx)
                        try note.drawWithStyle()
                        #expect(try measured(note).ink == ink)
                    }
                    let curve = f.Curve(from: notes[0], to: notes[1], options: CurveOptions(openingDirection: .up))
                    try measured(curve)
                }
            }
        }
    }

    @Test func profileStemAnchorsMoveStemsToTheFontAnchor() throws {
        try isolated {
            let policy = try profile("Petaluma")
            let f = factory(policy)
            let up = f.StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .up))
            let down = f.StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q", stemDirection: .down))
            let system = f.System(options: SystemOptions(width: 300, y: 40))
            _ = system.addStave(SystemStave(voices: [f.EasyScore().voice([up, down], options: EasyScoreVoiceOptions(mode: .soft))]))
            system.format()
            let head = up.noteHeads[0]
            let anchor = try #require(policy.stemAnchor(head.text, direction: .up))
            close(up.getStemX(), up.getNoteHeadBeginX() + anchor.x * head.fontSizeInPixels / 4 - Stem.WIDTH / 2)
            let downAnchor = try #require(policy.stemAnchor(down.noteHeads[0].text, direction: .down))
            close(down.getStemX(),
                  down.getNoteHeadBeginX() + downAnchor.x * down.noteHeads[0].fontSizeInPixels / 4 + Stem.WIDTH / 2)
            // Factory glyphs follow the profile family.
            #expect(f.Accidental(type: .sharp).fontInfo.family == "Petaluma")
            #expect(f.TimeSignature(.meter(3, 4)).topText.fontInfo.family == "Petaluma")
            #expect(f.Clef(.treble).fontInfo.family == "Petaluma")
        }
    }

    @Test func contourBeamsPreserveMembershipMinimumStemsBeamletsAndEndpoints() throws {
        try isolated {
            for width in [190.0, 340, 790] {
                for stem in ["up", "down"] {
                    let f = factory()
                    let es = f.EasyScore()
                    let notes = es.notes("G4/8, A4/16, B4/8, C4/8", options: ["stem": stem])
                    let beam = try f.BeamThrowing(notes: notes)
                    beam.renderOptions.contourSlope = true
                    beam.setPartialBeamSideAt(1, side: .right)
                    let sys = f.System(options: SystemOptions(width: width, y: 60))
                    _ = sys.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
                    sys.format()
                    try measured(beam)
                    #expect(beam.getNotes().map { ObjectIdentifier($0) } == notes.map { ObjectIdentifier($0) })
                    let first = notes[0], last = notes[notes.count - 1]
                    #expect(beam.slope * (last.getYs()[0] - first.getYs()[0]) >= -1e-7)
                    for n in notes {
                        let tip = n.getStemExtents().topY
                        let expected = beam.getBeamYToDraw() + beam.slope * (n.getStemX() - first.getStemX())
                        #expect(abs(tip - expected) < 1e-6)
                        #expect(abs(tip - n.getYs()[0]) >= n.getStemMinimumLength() - 1)
                    }
                    let beamlet = try #require(beam.getBeamLines("8").first)
                    #expect((beamlet.end ?? .nan) - beamlet.start == beam.renderOptions.partialBeamLength)
                }
            }
        }
    }

    @Test func beforeAndAfterGraceGroupsOnTwoStavesClearTheirHosts() throws {
        try isolated {
            let f = factory()
            let es = f.EasyScore()
            let sys = f.System(options: SystemOptions(width: 650))
            var groups: [(host: StaveNote, before: GraceNoteGroup, after: GraceNoteGroup)] = []
            for key in ["c/5", "e/4"] {
                let host = f.StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: "w"))
                var sides: [GraceNoteGroup] = []
                for (i, side) in [ModifierPosition.left, .right].enumerated() {
                    let graces = try (0...i).map { _ in
                        f.GraceNote(try GraceNoteStruct(parsingKeys: [key], duration: "16", slash: true)) as StemmableNote
                    }
                    let grace = f.GraceNoteGroup(notes: graces, slur: true).setPosition(side)
                    if i > 0 { grace.beamNotes() }
                    _ = host.addModifier(grace, index: 0)
                    sides.append(grace)
                }
                _ = sys.addStave(SystemStave(voices: [es.voice([host])]))
                groups.append((host, sides[0], sides[1]))
            }
            sys.format()
            for (host, before, after) in groups {
                try measured(before)
                try measured(after)
                let head = host.getHeadInk()[0]
                let pre = try #require((before.getGraceNotes().last as? StaveNote)?.getHeadInk().first)
                let post = try #require((after.getGraceNotes().first as? StaveNote)?.getHeadInk().first)
                #expect(pre.x + pre.w < head.x)
                #expect(post.x > head.x + head.w)
                #expect(pre.x >= host.checkStave().getX())
                for (group, offset) in [(before, 0.0), (after, host.getGlyphWidth())] {
                    let slur = try #require(try group.getLayoutElements().last as? StaveTie)
                    let start = slur.getFirstX() + slur.renderOptions.firstXShift - slur.renderOptions.tieSpacing
                    #expect(abs(start - host.getNoteHeadBeginX() - offset) < 1e-7)
                }
                #expect(after.getGraceNotes()[0].getStave() === host.getStave())
            }
        }
    }

    @Test func fourVoiceColumnsAvoidHeadsAndRestsAndRepeatForReversedInput() throws {
        try isolated {
            func passage(_ reverse: Bool) throws -> [[[Double]]] {
                let f = factory()
                let es = f.EasyScore()
                let entries = try ["F5/q, G5/q", "E5/8, C5/8, D5/q", "D5/q, E5/q", "B4/q/r, B4/q"].enumerated().map { i, input in
                    let notes = es.notes(input, options: ["stem": i % 2 == 1 ? "down" : "up"])
                    if i == 0 { Dot.buildAndAttach([notes[0]]) }
                    if i == 2 { _ = notes[0].addModifier(try Accidental(parsing: "#"), index: 0) }
                    return (notes: notes, voice: es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft)))
                }
                let sys = f.System(options: SystemOptions(width: 490))
                let voices = entries.map { $0.voice }
                _ = sys.addStave(SystemStave(voices: reverse ? voices.reversed() : voices))
                sys.format()
                var boxes: [BoundingBox] = []
                for entry in entries {
                    for n in entry.notes {
                        guard let note = n as? StaveNote else { continue }
                        boxes.append(contentsOf: note.getHeadInk())
                        for m in note.getModifiers() {
                            if let dot = m as? Dot { boxes.append(dot.getInkBounds()) }
                            if let accidental = m as? Accidental { boxes.append(try accidental.getInkBounds()) }
                        }
                    }
                }
                for (i, a) in boxes.enumerated() {
                    for b in boxes[(i + 1)...] {
                        #expect(a.x + a.w <= b.x + 1 || b.x + b.w <= a.x + 1 || a.y + a.h <= b.y + 1 || b.y + b.h <= a.y + 1,
                                "voice head, rest, dot or sign overlapped")
                    }
                }
                return entries.map { e in e.notes.map { n in [(n as? StaveNote)?.getNoteHeadBeginX() ?? .nan, n.getYs()[0]] } }
            }
            let reversed = try passage(true)
            let ordered = try passage(false)
            #expect(reversed == ordered)
        }
    }

    @Test func bracketAndLabelClearUpperAndLowerOrnamentSigns() throws {
        try isolated {
            for (position, location) in [(ModifierPosition.above, TupletLocation.top), (.below, .bottom)] {
                let f = factory()
                let es = f.EasyScore()
                let notes = es.notes("G4/8, A4/8, B4/8")
                let mark = Ornament("turn").setPosition(position).setUpperAccidental("#").setLowerAccidental("b")
                _ = notes[1].addModifier(mark, index: 0)
                let tuplet = try f.TupletThrowing(notes: notes, options: TupletOptions(bracketed: true, location: location))
                let system = f.System(options: SystemOptions(width: 430, y: 80))
                _ = system.addStave(SystemStave(voices: [es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
                for width in [430.0, 260, 430] {
                    system.setWidth(width).format()
                    let bracket = try #require(try measured(tuplet).ink)
                    let sign = try #require(try measured(mark).ink)
                    let gap = location == .top ? sign.y - bracket.y - bracket.h : bracket.y - sign.y - sign.h
                    #expect(gap >= 2, "Bracket clears nearest auxiliary accidental by at least two pixels")
                }
            }
        }
    }

    @Test func tupletDisplayRatioIsIndependentOfTiming() throws {
        try isolated {
            let notes = try ["c/4", "d/4", "e/4"].map {
                StaveNote(try StaveNoteStruct(parsingKeys: [$0], duration: "8"))
            }
            let tuplet = try Tuplet(notes: notes, options: TupletOptions(
                numNotes: 3, notesOccupied: 2, ratioed: true, displayRatio: (numerator: 6, denominator: 4)
            ))
            #expect(tuplet.textElement.text == "\u{E886}\u{E88A}\u{E884}")
            #expect(notes[0].getTicks().equals(Fraction(Tables.RESOLUTION / 8 * 2, 3)))
            tuplet.setRatioed(false)
            #expect(tuplet.textElement.text == "\u{E886}")
            expectError("two positive integers") {
                _ = try Tuplet(notes: notes, options: TupletOptions(displayRatio: (numerator: 0, denominator: 4)))
            }
        }
    }

    @Test func unisonSpellingsKeepTheirOwnHeadColumns() throws {
        try isolated {
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c#/5", "c/5", "cb/5"], duration: "q", stemDirection: .up))
            let stave = Stave(x: 10, y: 40, width: 300)
            let voice = Voice(time: VoiceTime(numBeats: 1, beatValue: 4)).addTickables([note])
            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            let xs = Set(note.getHeadInk().map { $0.x })
            #expect(xs.count == 3)
            #expect(note.getVoiceShiftWidth() == note.getGlyphWidth() * 3)
            // Ledger lines enclose all heads.
            let high = StaveNote(try StaveNoteStruct(parsingKeys: ["c#/6", "c/6", "cb/6"], duration: "q"))
            let voice2 = Voice(time: VoiceTime(numBeats: 1, beatValue: 4)).addTickables([high])
            _ = Formatter().joinVoices([voice2]).formatToStave([voice2], stave: stave)
            let heads = high.getHeadInk()
            let ledger = try #require(high.getLedgerLines().last)
            let left = heads.map { $0.x }.min() ?? 0
            let right = heads.map { $0.x + $0.w }.max() ?? 0
            #expect(ledger.x <= left && ledger.x + ledger.width >= right - 0.5)
        }
    }
}

// MARK: - Optical spacing (proportional-spacing-tests.mjs)

@Suite("Upstream 5.3.0 port: optical spacing")
struct Upstream53OpticalSpacingTests {
    private func positions(_ voice: Voice) -> [Double] {
        voice.getTickables().filter { !$0.shouldIgnoreTicks() }.map { ($0 as? Note)?.getTickContext().getX() ?? .nan }
    }

    private func voice(_ durations: [String]) throws -> Voice {
        let stave = Stave(x: 10, y: 50, width: 900)
        let notes = try durations.map { duration -> StemmableNote in
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: duration))
            _ = note.setStave(stave)
            return note
        }
        _ = try Beam.generateBeams(notes)
        return try Voice(parsingTime: "4/4").setMode(.soft).addTickablesThrowing(notes).setMode(.strict)
    }

    @Test func opticalSpacingFitsObstaclesThenStretchesWithoutMovingClefsIntoNotes() throws {
        try isolated {
            let stave = Stave(x: 10, y: 50, width: 900)
            let notes = try ["q", "q", "8", "16", "32", "64"].map { duration in
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: duration)).setStave(stave)
            }
            _ = notes[0].addModifier(Annotation("crescendo"), index: 0)
            let graces = try ["d/5", "e/5", "f/5"].map {
                GraceNote(try GraceNoteStruct(parsingKeys: [$0], duration: "16")) as StemmableNote
            }
            _ = notes[1].addModifier(GraceNoteGroup(graceNotes: graces), index: 0)
            _ = notes[2].addModifier(ChordSymbol().addText("Cmaj7/G"), index: 0)
            _ = notes[3].addModifier(try Accidental(parsing: "##"), index: 0)
            let clef = ClefNote(type: .bass, size: .small).setStave(stave)
            let v = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).setStrict(false)
                .addTickables([notes[0], clef] + Array(notes[1...]))
            let f = VexFoundation.Formatter(options: FormatterOptions(spacing: .optical)).joinVoices([v])
            let minimum = try f.preCalculateMinTotalWidthThrowing([v])
            expectError("Optical spacing requires at least") { try f.formatThrowing([v], justifyWidth: minimum - 1) }
            try f.formatThrowing([v], justifyWidth: minimum)
            let tight = positions(v)
            for i in 1..<notes.count {
                let prev = notes[i - 1].getMetrics(), curr = notes[i].getMetrics()
                #expect(tight[i] - curr.modLeftPx - curr.leftDisplacedHeadPx
                        >= tight[i - 1] + prev.notePx + prev.rightDisplacedHeadPx + prev.modRightPx + 2 - 1e-7)
            }
            #expect(clef.getAbsoluteX() + clef.getWidth() <= notes[1].getAbsoluteX())
            try f.formatThrowing([v], justifyWidth: minimum + 200)
            let loose = positions(v)
            func extra(_ i: Int) -> Double { loose[i] - loose[i - 1] - (tight[i] - tight[i - 1]) }
            close(extra(3) / extra(4), 2.0.squareRoot())
            f.tune()
            #expect(positions(v) == loose)
        }
    }

    @Test func nestedTupletsPreserveEveryExactOnsetThroughReformat() throws {
        try isolated {
            let stave = Stave(x: 10, y: 50, width: 900)
            let notes = try (0..<5).map { _ in
                StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "8")).setStave(stave) as Note
            }
            _ = try Tuplet(notes: notes, options: TupletOptions(numNotes: 5, notesOccupied: 4))
            _ = try Tuplet(notes: Array(notes[1..<4]), options: TupletOptions(numNotes: 3, notesOccupied: 2))
            let v = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).setStrict(false).addTickables(notes)
            let f = try VexFoundation.Formatter(options: FormatterOptions(spacing: .proportional(pixelsPerQuarter: 200)))
                .joinVoicesThrowing([v]).formatThrowing([v])
            let expected: [Int] = [0, 6, 10, 14, 18] // units of one fifteenth of a quarter
            let elapsed = Fraction(0, 1)
            for (i, n) in notes.enumerated() {
                #expect(elapsed.equals(Fraction(expected[i] * 4096, 15)))
                elapsed.add(n.getTicks())
            }
            #expect(elapsed.equals(Fraction(24 * 4096, 15)))
            func onsets() {
                let x = positions(v)
                for (i, value) in expected.enumerated() { close(x[i] - x[0], Double(value) * 200 / 15) }
            }
            onsets()
            try f.formatThrowing([v], justifyWidth: 1600)
            onsets()
        }
    }

    @Test func opticalAndExactPoliciesExposeDifferentMinimaForAShortFinalAttack() throws {
        try isolated {
            let durations = ["h", "q", "8", "16", "32", "64", "64"]
            func run(_ spacing: MeasuredSpacing?) throws -> Double {
                let v = try voice(durations)
                let f = try VexFoundation.Formatter(options: FormatterOptions(spacing: spacing)).joinVoicesThrowing([v])
                let minimum = try f.preCalculateMinTotalWidthThrowing([v])
                try f.formatThrowing([v], justifyWidth: minimum)
                #expect(positions(v).allSatisfy { $0.isFinite })
                return minimum
            }
            let optical = try run(.optical)
            let exact = try run(.proportional())
            let legacy = try run(nil)
            #expect(optical < exact)
            #expect(legacy > 0)
            let v = try voice(durations)
            expectError("InsufficientProportionalSpace") {
                try VexFoundation.Formatter(options: FormatterOptions(spacing: .proportional()))
                    .joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: optical)
            }
        }
    }
}

// MARK: - EasyScore grace accidentals (easyscore-tests.mjs)

@Suite("Upstream 5.3.0 port: EasyScore grace groups")
struct Upstream53EasyScoreTests {
    private func create() -> EasyScore {
        EasyScore.create(options: FactoryOptions(width: 500, height: 240))
    }

    private func marks(_ note: Note) -> [String] {
        note.getModifiers().compactMap { ($0 as? Accidental)?.type }
    }

    private func voice(_ side: EasyScoreGraceSide, _ pitches: [String]) throws -> EasyScoreVoiceSpec {
        EasyScoreVoiceSpec(notes: [
            .note(
                try StaveNoteStruct(parsingKeys: ["f#/4"], duration: "h"),
                grace: EasyScoreGraceGroupSpec(side: side, notes: try pitches.map {
                    EasyScoreGracePitchSpec(try GraceNoteStruct(parsingKeys: [$0], duration: "16"))
                })
            ),
            .notation("F4/h"),
        ])
    }

    private func arrays(_ voices: [EasyScoreVoiceSpec], _ policy: EasyScoreGraceAccidentalPolicy) throws -> [[[[String]]]] {
        let result = try create().compose(EasyScoreCompositionSpec(
            staves: [EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: voices)])],
            accidentals: .keyAware,
            graceAccidentals: policy
        ))
        return try result.notes[0][0].map { notes in
            let host = try #require(notes[0] as? Note)
            let last = try #require(notes[1] as? Note)
            let grace = try #require(host.getModifiers().compactMap { $0 as? GraceNoteGroup }.first)
            return [grace.getGraceNotes().map(marks), [marks(host)], [marks(last)]]
        }
    }

    @Test func graceOrderIsExplicitAndSimultaneousSignsAreIndependentOfVoiceInsertion() throws {
        try isolated {
            let early = try voice(.before, ["f/4", "f#/4"])
            let conflict = try voice(.before, ["fb/4"])
            let expected: [[[[String]]]] = [
                [[[], ["#"]], [["#"]], [["n"]]],
                [[["b"]], [["#"]], [["n"]]],
            ]
            #expect(try arrays([early, conflict], .ordered) == expected)
            #expect(try arrays([conflict, early], .ordered) == Array(expected.reversed()))
            #expect(try arrays([early], .explicit) == [[[[], []], [["#"]], [["n"]]]])
            #expect(try arrays([try voice(.after, ["f/4", "f#/4"])], .ordered) == [[[["n"], ["#"]], [["#"]], [["n"]]]])
            expectError("Ordered grace accidentals require key-aware accidentals") {
                _ = try create().compose(EasyScoreCompositionSpec(
                    staves: [EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [early])])],
                    graceAccidentals: .ordered
                ))
            }
        }
    }

    @Test func explicitGraceCautionariesSurviveOrderedGenerationAndSuppressRedundantHostSigns() throws {
        try isolated {
            let result = try create().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [
                    EasyScoreVoiceSpec(notes: [.note(
                        try StaveNoteStruct(parsingKeys: ["f#/4"], duration: "w"),
                        grace: EasyScoreGraceGroupSpec(side: .before, notes: [EasyScoreGracePitchSpec(
                            try GraceNoteStruct(parsingKeys: ["f#/4"], duration: "8"),
                            accidentals: [EasyScoreGraceAccidental(index: 0, type: "#", cautionary: true)]
                        )])
                    )]),
                ])])],
                accidentals: .keyAware,
                graceAccidentals: .ordered
            ))
            let host = try #require(result.notes[0][0][0][0] as? Note)
            #expect(host.getModifiers().count == 1)
            let group = try #require(host.getModifiers()[0] as? GraceNoteGroup)
            let signs = group.getGraceNotes()[0].getModifiers().compactMap { $0 as? Accidental }
            #expect(signs.map { [$0.type, String($0.isCautionary())] } == [["#", "true"]])
        }
    }
}

// MARK: - QUnit asserts (bend, curve, formatter, threevoice tests)

@Suite("Upstream 5.3.0 port: visual test asserts")
struct Upstream53VisualAssertTests {

    /// bend_tests.ts reverseBends: bends attached lower string first; the lower string uses the outer curve.
    @Test func simultaneousBendsUseTheOuterCurveForTheLowerString() throws {
        try isolated {
            let stave = TabStave(x: 10, y: 10, width: 450)
            func bend(_ text: String) -> Bend { Bend([BendPhrase(type: Bend.UP, text: text)]) }
            // Upstream attaches the lower string (index 1) first.
            let notes = [
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 10), TabNotePosition(str: 4, fret: 9)], duration: .whole))
                    .addModifier(bend("Full"), index: 1).addModifier(bend("1/2"), index: 0),
                TabNote(TabNoteStruct(positions: [TabNotePosition(str: 2, fret: 5), TabNotePosition(str: 3, fret: 5)], duration: .whole))
                    .addModifier(bend("1/4"), index: 1).addModifier(bend("1/4"), index: 0),
            ]
            let quadratic = try NSRegularExpression(pattern: "Q[-0-9.]+ [-0-9.]+,([-0-9.]+) [-0-9.]+")
            for (i, note) in notes.enumerated() {
                let mc = ModifierContext()
                _ = note.addToModifierContext(mc)
                let tickContext = TickContext()
                _ = tickContext.addTickable(note).preFormat().setX(75 * Double(i))
                let ctx = SVGRenderContext(width: 500, height: 240)
                _ = stave.setContext(ctx)
                _ = note.setStave(stave)
                _ = note.setContext(ctx)
                try note.drawWithStyle()
                let svg = ctx.getSVG()
                let arrowXs = quadratic.matches(in: svg, range: NSRange(svg.startIndex..., in: svg)).compactMap { match in
                    Range(match.range(at: 1), in: svg).flatMap { Double(svg[$0]) }
                }
                #expect(arrowXs.count >= 2)
                if arrowXs.count >= 2 { #expect(arrowXs[0] > arrowXs[1], "Lower string uses the outer curve") }
            }
        }
    }

    private func curveScene(
        _ group1: (String, String), _ group2: (String, String),
        _ setup: (Factory, [StemmableNote]) -> VexFoundation.Curve
    ) throws -> (VexFoundation.Curve, [StemmableNote]) {
        let f = Factory(options: FactoryOptions(width: 350, height: 200))
        _ = f.setContext(SVGRenderContext(width: 350, height: 200))
        let stave = f.Stave(y: 50)
        let score = f.EasyScore()
        let n1 = score.notes(group1.0, options: ["stem": group1.1])
        let n2 = score.notes(group2.0, options: ["stem": group2.1])
        _ = score.beam(n1)
        _ = score.beam(n2)
        let notes = n1 + n2
        let curve = setup(f, notes)
        let voices = [score.voice(notes.map { $0 as Note }, time: .meter(4, 4))]
        _ = f.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
        try f.draw()
        return (curve, notes)
    }

    /// curve_tests.ts: opening-up and opening-down slurs clear the beams on their stem side.
    @Test func openingDirectionSlursClearTheBeamOnTheirStemSide() throws {
        try isolated {
            let (lower, upNotes) = try curveScene(("c4/8, f5, d5, g5", "up"), ("d6/8, f5, d5, g5", "down")) { f, notes in
                _ = f.Curve(from: notes[0], to: notes[3], options: CurveOptions(openingDirection: .up))
                return f.Curve(from: notes[4], to: notes[7], options: CurveOptions(openingDirection: .up))
            }
            let tips = [upNotes[4], upNotes[7]].map { $0.getStemExtents().topY }
            #expect(try #require(lower.getBoundingBox()).y > tips.min()!, "Opening-up slur clears the down-stem beam")

            let (upper, downNotes) = try curveScene(("c4/8, f5, d5, g5", "up"), ("d6/8, f5, d5, g5", "down")) { f, notes in
                let upper = f.Curve(from: notes[0], to: notes[3], options: CurveOptions(openingDirection: .down))
                _ = f.Curve(from: notes[4], to: notes[7], options: CurveOptions(openingDirection: .down))
                return upper
            }
            let upTips = [downNotes[0], downNotes[3]].map { $0.getStemExtents().topY }
            let bounds = try #require(upper.getBoundingBox())
            #expect(bounds.y + bounds.h < upTips.max()!, "Opening-down slur clears the up-stem beam")
        }
    }

    /// threevoice_tests.ts threeVoices2: the middle double beam clears the second head of the lowest voice.
    @Test func middleBeamClearsTheLowerVoiceHead() throws {
        try isolated {
            let factory = Factory(options: FactoryOptions(width: 600, height: 200))
            _ = factory.setContext(SVGRenderContext(width: 600, height: 200))
            let stave = factory.Stave().addClef(.treble).addTimeSignature(.meter(4, 4))
            let score = factory.EasyScore()
            let groups = [
                score.notes("(a4 e5)/16, e5, e5, e5, e5/8, e5, e5/2", options: ["stem": "up"]),
                score.notes("(d4 d#5)/16, (b4 c5), d5, e5, (d4 a4 c5)/8, b4, (d4 a4 c5), b4, (d4 a4 c5), b4",
                            options: ["stem": "down"]),
                score.notes("b3/8, b3, e3/4, f3, a3", options: ["stem": "down"]),
            ]
            let voices = groups.map { score.voice($0.map { $0 as Note }) }
            if let n = voices[0].getTickables()[0] as? Note {
                _ = n.addModifier(factory.Fingering(number: "2", position: .left), index: 0)
                    .addModifier(factory.Fingering(number: "0", position: .above), index: 1)
            }
            if let n = voices[1].getTickables()[0] as? Note {
                _ = n.addModifier(factory.Fingering(number: "0", position: .left), index: 0)
                    .addModifier(factory.Fingering(number: "4", position: .left), index: 1)
            }
            let beams = try Beam.applyAndGetBeams(voices[0], stemDirection: .up)
                + Beam.applyAndGetBeams(voices[1], stemDirection: .down)
                + Beam.applyAndGetBeams(voices[2], stemDirection: .down)
            _ = factory.Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            try factory.draw()
            let ctx = try #require(factory.getContext())
            for beam in beams { _ = beam.setContext(ctx); try beam.drawWithStyle() }
            let beam = try #require(groups[1][0].getBeam())
            let first = beam.getNotes()[0]
            let lower = try #require(groups[2][1] as? StaveNote)
            let headTop = try #require(lower.noteHeads[0].getBoundingBox()).y
            for x in [lower.getNoteHeadBeginX(), lower.getNoteHeadEndX()] {
                let edge = beam.getSlopeY(x, first.getStemX(), beam.getBeamYToDraw(), beam.slope)
                #expect(edge < headTop, "Middle beam edge at \(edge) clears lower head at \(headTop) (x=\(x))")
            }
        }
    }
}
