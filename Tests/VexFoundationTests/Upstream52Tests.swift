// Logic-level tests for the behaviors ported from VexFlow 5.1.0 → 5.2.0.
// Ported from tests/node/{proportional-spacing,chord-kerning,metrics,easyscore,easyscore-rendering}-tests.mjs
// and the QUnit asserts in tests/{beam,easyscore,formatter}_tests.ts at 5.2.0.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func close(_ actual: Double, _ expected: Double, tolerance: Double = 1e-7, _ comment: Comment? = nil) {
    #expect(abs(actual - expected) < tolerance, comment ?? "\(actual) ≈ \(expected)")
}

/// Expect `body` to throw an error whose description contains `text`.
private func expectError(_ text: String, sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
    do {
        try body()
        Issue.record("Expected an error containing '\(text)'", sourceLocation: sourceLocation)
    } catch {
        let message = String(describing: error) + " " + error.localizedDescription
        #expect(message.lowercased().contains(text.lowercased()), "\(message)", sourceLocation: sourceLocation)
    }
}

private func expectAnyError(sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void) {
    do {
        try body()
        Issue.record("Expected an error", sourceLocation: sourceLocation)
    } catch {}
}

private func ids(_ elements: [AnyObject]) -> [ObjectIdentifier] { elements.map { ObjectIdentifier($0) } }

// MARK: - Strict proportional spacing (proportional-spacing-tests.mjs)

@Suite("Upstream 5.2.0 port: proportional spacing")
struct Upstream52ProportionalSpacingTests {
    private let rhythm = ["16", "16", "16", "16", "8", "8", "q", "q"]

    /// Build independent fixtures so formatting caches cannot conceal state leaks.
    private func voice(_ durations: [String]? = nil, _ meter: String = "4/4", stave: Stave? = nil) throws -> Voice {
        let stave = stave ?? Stave(x: 10, y: 50, width: 900)
        let notes = try (durations ?? rhythm).map { duration -> StemmableNote in
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: duration))
            _ = note.setStave(stave)
            return note
        }
        _ = try Beam.generateBeams(notes)
        return try Voice(parsingTime: meter).setMode(.soft).addTickablesThrowing(notes).setMode(.strict)
    }

    private func proportional(_ pixelsPerQuarter: Double? = nil) -> VexFoundation.Formatter {
        VexFoundation.Formatter(options: FormatterOptions(spacing: ProportionalSpacing(pixelsPerQuarter: pixelsPerQuarter)))
    }

    private func positions(_ voice: Voice) -> [Double] {
        voice.getTickables().filter { !$0.shouldIgnoreTicks() }.map { ($0 as? Note)?.getTickContext().getX() ?? .nan }
    }

    /// Compare absolute onsets relative to the first anchor, not repeated pixel increments.
    private func onsets(_ voice: Voice, _ expected: [Double], sourceLocation: SourceLocation = #_sourceLocation) {
        let x = positions(voice)
        for (i, offset) in expected.enumerated() {
            #expect(abs((x[i] - x[0]) - offset) < 1e-7, "\(x[i] - x[0]) ≈ \(offset)", sourceLocation: sourceLocation)
        }
    }

    @Test func mixedDurationsRetainExactScaleAndTuningInvariance() throws {
        try isolated {
            let v = try voice()
            let f = try proportional(100).joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: 800)
            onsets(v, [0, 25, 50, 75, 100, 150, 200, 300])
            close(f.getMinTotalWidth(), 404)
            let before = positions(v)
            for _ in 0..<10 { f.tune() }
            #expect(positions(v) == before)
            try f.formatThrowing([v], justifyWidth: 500)
            #expect(positions(v) == before)
        }
    }

    @Test func omittedScaleFitsWidthAndOmittedWidthUsesMinimum() throws {
        try isolated {
            let v = try voice()
            let f = try proportional().joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: 504)
            onsets(v, [0, 31.25, 62.5, 93.75, 125, 187.5, 250, 375])
            let minimum = try f.preCalculateMinTotalWidthThrowing([v])
            try f.formatThrowing([v], justifyWidth: minimum)
            let expected = positions(v)
            try f.formatThrowing([v])
            #expect(positions(v) == expected)
        }
    }

    @Test func oddMetersAndDottedRhythmsRetainRatios() throws {
        try isolated {
            let v = try voice(Array(repeating: "8", count: 7), "7/8")
            try proportional(100).joinVoicesThrowing([v]).formatThrowing([v])
            onsets(v, [0, 50, 100, 150, 200, 250, 300])
            let dotted = try voice(["qd", "8", "h"])
            Dot.buildAndAttach([dotted.getTickables()[0]].compactMap { $0 as? Note })
            try proportional(100).joinVoicesThrowing([dotted]).formatThrowing([dotted])
            onsets(dotted, [0, 150, 200])
        }
    }

    @Test func sharedOnsetsAlignInMultipleVoices() throws {
        try isolated {
            let stave = Stave(x: 10, y: 50, width: 900)
            let upper = try voice(rhythm, stave: stave)
            let lower = try voice(["q", "q", "q", "q"], stave: stave)
            for note in lower.getTickables() { _ = (note as? StemmableNote)?.setStemDirection(.down) }
            let f = try proportional(140).joinVoicesThrowing([upper, lower]).formatThrowing([upper, lower])
            for (beat, index) in [0, 4, 6, 7].enumerated() {
                close(positions(upper)[index], positions(lower)[beat])
            }
            #expect(f.getMinTotalWidth() >= 560)
        }
    }

    @Test func tripletsAndSeptupletsShareRationalEndpoints() throws {
        try isolated {
            let first = try voice(Array(repeating: "8", count: 3) + ["q", "h"])
            let second = try voice(Array(repeating: "8", count: 7) + ["h"])
            _ = try Tuplet(notes: Array(first.getTickables()[0..<3]).compactMap { $0 as? Note },
                           options: TupletOptions(numNotes: 3, notesOccupied: 2))
            _ = try Tuplet(notes: Array(second.getTickables()[0..<7]).compactMap { $0 as? Note },
                           options: TupletOptions(numNotes: 7, notesOccupied: 4))
            let f = try proportional(140).joinVoicesThrowing([first, second]).formatThrowing([first, second])
            onsets(first, [0, 140.0 / 3, 280.0 / 3, 140, 280])
            onsets(second, (0..<7).map { Double($0) * 280 / 7 } + [280])
            close(positions(first)[4], positions(second)[7])
            #expect(f.getTickContexts().resolutionMultiplier % 21 == 0)
        }
    }

    @Test func inlineClefsAndBarlinesOccupySpaceWithoutTime() throws {
        try isolated {
            let stave = Stave(x: 10, y: 50, width: 900)
            let notes = try voice(["q", "q", "q", "q"], stave: stave).getTickables()
            let clefs = [ClefNote(type: .bass, size: .small), ClefNote(type: .treble, size: .small)]
            for clef in clefs { _ = clef.setStave(stave) }
            let end = BarNote()
            _ = end.setStave(stave)
            let v = try Voice(parsingTime: "4/4").addTickablesThrowing([notes[0]] + clefs + Array(notes[1...]) + [end])
            let f = try proportional(130).joinVoicesThrowing([v]).formatThrowing([v])
            onsets(v, [0, 130, 260, 390])
            #expect(clefs[0].getAbsoluteX() < clefs[1].getAbsoluteX())
            #expect(clefs[1].getAbsoluteX() + clefs[1].getWidth() <= (notes[1] as? Note)?.getAbsoluteX() ?? 0)
            let endContext = end.getTickContext()
            close(endContext.getX() - positions(v)[0], 520 - 1 - endContext.getMetrics().notePx)
            let before = v.getTickables().compactMap { ($0 as? Note)?.getAbsoluteX() }
            try f.formatThrowing([v])
            #expect(v.getTickables().compactMap { ($0 as? Note)?.getAbsoluteX() } == before)
        }
    }

    @Test func graceGroupsAndAccidentalsReserveSpaceBeforeFirstAnchor() throws {
        try isolated {
            let v = try voice(["q", "q", "q", "q"])
            let first = try #require(v.getTickables()[0] as? StaveNote)
            _ = first.addModifier(try Accidental(parsing: "##"), index: 0)
            let grace = GraceNote(try GraceNoteStruct(parsingKeys: ["d/5"], duration: "8"))
            _ = first.addModifier(GraceNoteGroup(graceNotes: [grace]), index: 0)
            let f = try proportional(150).joinVoicesThrowing([v]).formatThrowing([v])
            onsets(v, [0, 150, 300, 450])
            #expect(positions(v)[0] > 20)
            #expect(f.getMinTotalWidth() > 620)
        }
    }

    @Test func crowdedChordsAndInsufficientWidthFailWithDimensions() throws {
        try isolated {
            let v = try voice()
            _ = (v.getTickables()[1] as? StaveNote)?.addModifier(try Accidental(parsing: "##"), index: 0)
            do {
                try proportional(10).joinVoicesThrowing([v]).formatThrowing([v])
                Issue.record("Expected InsufficientProportionalSpace")
            } catch let error as VexError {
                #expect(error.code == "InsufficientProportionalSpace")
                #expect(error.message.contains("px/quarter") && error.message.contains("px width"))
            }
            let f = try proportional(200).joinVoicesThrowing([v])
            expectError("InsufficientProportionalSpace") { try f.formatThrowing([v], justifyWidth: 100) }
            try f.formatThrowing([v], justifyWidth: 1000)
            onsets(v, [0, 50, 100, 150, 200, 300, 400, 600])
        }
    }

    @Test func partialVoicesKeepSpanAndSoftOverflowExtendsIt() throws {
        try isolated {
            let partial = try Voice(parsingTime: "4/4").setMode(.soft)
                .addTickablesThrowing(try voice(["q"], "1/4").getTickables())
            let f = try proportional(100).joinVoicesThrowing([partial]).formatThrowing([partial])
            close(f.getMinTotalWidth(), 404)
            let overflow = try Voice(parsingTime: "4/4").setMode(.soft)
                .addTickablesThrowing(try voice(Array(repeating: "q", count: 5), "5/4").getTickables())
            let g = try proportional(100).joinVoicesThrowing([overflow]).formatThrowing([overflow])
            close(g.getMinTotalWidth(), 504)
        }
    }

    @Test func invalidScalesAndWidthsAreRejected() throws {
        try isolated {
            for scale in [0, -1, Double.nan, Double.infinity] {
                let v = try voice()
                expectError("pixelsPerQuarter") { try proportional(scale).joinVoicesThrowing([v]).formatThrowing([v]) }
            }
            for width in [-1, Double.infinity, Double.nan] {
                let v = try voice()
                expectError("Width must") {
                    try proportional(100).joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: width)
                }
            }
            let v = try voice()
            try VexFoundation.Formatter().joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: 500)
            #expect(positions(v)[4] - positions(v)[0] != positions(v)[6] - positions(v)[4])
        }
    }

    @Test func centeredWholeMeasureRestsRetainCentering() throws {
        try isolated {
            let v = try voice(["wr"])
            _ = v.getTickables()[0].setCenterAlignment(true)
            try proportional(100).joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: 800)
            close(v.getTickables()[0].getCenterXShift(), 200)
        }
    }

    @Test func systemAutoWidthAndTuningPreserveFixedSpacing() throws {
        try isolated {
            let factory = Factory(options: FactoryOptions(width: 900, height: 300))
            _ = factory.setContext(SVGRenderContext(width: 900, height: 300))
            let notes = try factory.EasyScore().notesThrowing("C5/16, D5, E5, F5, G5/8, A5, B5/q, C6")
            let v = factory.Voice().addTickables(notes)
            let system = factory.System(options: SystemOptions(
                formatIterations: 5,
                details: SystemFormatterOptions(spacing: ProportionalSpacing(pixelsPerQuarter: 120))
            ))
            system.addStave(SystemStave(voices: [v])).addClef(.treble)
            try factory.draw(retain: true)
            onsets(v, [0, 30, 60, 90, 120, 180, 240, 360])
            #expect(system.getWidth() > 480)
            let before = positions(v)
            try factory.draw(retain: true)
            #expect(positions(v) == before)
        }
    }

    @Test func denseChordBoundsRemainSeparatedAtMinimumWidth() throws {
        try isolated {
            let stave = Stave(x: 10, y: 50, width: 900)
            let notes = try (0..<8).map { _ -> StaveNote in
                let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5", "d/5", "e/5"], duration: "8"))
                _ = note.setStave(stave)
                _ = note.addModifier(try Accidental(parsing: "##"), index: 0).addModifier(try Accidental(parsing: "b"), index: 1)
                return note
            }
            _ = try Beam.generateBeams(notes)
            let v = try Voice(parsingTime: "4/4").addTickablesThrowing(notes)
            let f = try proportional().joinVoicesThrowing([v]).formatThrowing([v])
            for i in 1..<notes.count {
                let previous = notes[i - 1].getMetrics()
                let current = notes[i].getMetrics()
                let right = notes[i - 1].getTickContext().getX() + previous.notePx + previous.modRightPx
                    + previous.rightDisplacedHeadPx
                let left = notes[i].getTickContext().getX() - current.modLeftPx - current.leftDisplacedHeadPx
                #expect(left - right >= 2 - 1e-7)
            }
            let scale = positions(v)[1] - positions(v)[0]
            onsets(v, notes.indices.map { scale * Double($0) })
            #expect(f.getMinTotalWidth().isFinite)
        }
    }

    @Test func stavesSuppliedDuringFormatApplyToInlinePrefixes() throws {
        try isolated {
            let notes = try ["q", "q", "q", "q"].map { StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: $0)) }
            let clef = ClefNote(type: .bass, size: .small)
            let v = try Voice(parsingTime: "4/4").addTickablesThrowing([clef] + notes)
            let stave = Stave(x: 10, y: 50, width: 900)
            try proportional(120).joinVoicesThrowing([v]).formatThrowing([v], justifyWidth: 600, options: FormatParams(stave: stave))
            onsets(v, [0, 120, 240, 360])
            #expect(clef.getAbsoluteX() + clef.getWidth() <= notes[0].getAbsoluteX())
        }
    }

    @Test func unsupportedNumericRangesFailBeforeInfiniteCoordinates() throws {
        try isolated {
            expectError("No voices") { _ = try proportional().preCalculateMinTotalWidthThrowing([]) }
            expectError("No voices") { try proportional().formatThrowing([]) }
            let v = try voice()
            expectError("pixel range") {
                try proportional(Double.greatestFiniteMagnitude).joinVoicesThrowing([v]).formatThrowing([v])
            }
        }
    }

    /// QUnit asserts of `Formatter.Strict_proportional_spacing` (formatter_tests.ts).
    @Test func strictProportionalSpacingVisualAsserts() throws {
        try isolated {
            let factory = Factory(options: FactoryOptions(width: 850, height: 540))
            _ = factory.setContext(SVGRenderContext(width: 850, height: 540))
            let score = factory.EasyScore()
            let notes = score.notes("C5/16, D5, E5, F5, G5/8, A5, B5/q, C6", options: ["stem": "up"])
            score.beam(Array(notes[0..<4]))
            score.beam(Array(notes[4..<6]))
            let quarters = score.notes("C4/q, E4, G4, E4", options: ["stem": "down"])
            let system = factory.System(options: SystemOptions(
                formatIterations: 4, autoWidth: true, x: 25, y: 40,
                details: SystemFormatterOptions(spacing: ProportionalSpacing(pixelsPerQuarter: 140))
            ))
            system.addStave(SystemStave(voices: [score.voice(notes), score.voice(quarters)])).addClef(.treble)
            let thirds = score.notes("C5/8, D5, E5, F5/q, G5/h")
            let sevenths = score.notes("C4/8, D4, E4, F4, G4, A4, B4, C5/h")
            score.tuplet(Array(thirds[0..<3]), options: TupletOptions(numNotes: 3, notesOccupied: 2))
            score.tuplet(Array(sevenths[0..<7]), options: TupletOptions(numNotes: 7, notesOccupied: 4))
            score.beam(Array(thirds[0..<3]))
            score.beam(Array(sevenths[0..<7]))
            system.addStave(SystemStave(voices: [score.voice(thirds)])).addClef(.treble)
            system.addStave(SystemStave(voices: [score.voice(sevenths)])).addClef(.treble)
            try factory.draw()
            let origin = notes[0].getAbsoluteX()
            for (i, offset) in [0.0, 35, 70, 105, 140, 210, 280, 420].enumerated() {
                close(notes[i].getAbsoluteX(), origin + offset, "Fixed onset")
            }
            for (i, note) in quarters.enumerated() { close(note.getAbsoluteX(), origin + Double(i) * 140, "Voices align") }
            close(thirds[4].getAbsoluteX(), sevenths[7].getAbsoluteX(), "Rational endpoints align")
            for note in sevenths[0..<7] {
                #expect(note.getStemDirection() == note.beam?.getStemDirection(), "Tuplet stem agrees with beam")
            }
        }
    }
}

// MARK: - Automatic beam stem policy (beam_tests.ts, easyscore_tests.ts)

@Suite("Upstream 5.2.0 port: beam stem policy")
struct Upstream52BeamStemPolicyTests {
    /// QUnit test `EasyScore: Automatic beam stem policy`.
    @Test func automaticBeamStemPolicy() throws {
        try isolated {
            let factory = Factory(options: FactoryOptions(width: 500, height: 200))
            let score = factory.EasyScore()
            let phrase = "C4/8, D4, E4, F4, G4, A4, B4"
            func directions(_ notes: [StemmableNote]) -> [StemDirection] { notes.map { $0.getStemDirection() } }
            let automatic = score.notes(phrase)
            #expect(Set(directions(automatic)).count == 2, "Unbeamed phrase crosses stem boundary")
            score.beam(automatic)
            #expect(automatic.allSatisfy { $0.getStemDirection() == .up }, "Group chooses up stems")
            #expect(automatic.allSatisfy { $0.isAutoStem() }, "Beaming retains automatic policy")
            let extended = automatic + score.notes("C6/8, C6, C6, C6, C6, C6, C6, C6")
            score.beam(extended)
            #expect(extended.allSatisfy { $0.getStemDirection() == .down }, "Regrouping recalculates direction")

            let explicit = score.notes(phrase, options: ["stem": "down"])
            score.beam(explicit)
            #expect(explicit.allSatisfy { $0.getStemDirection() == .down && !$0.isAutoStem() }, "Explicit voice stays down")
            score.beam(explicit, autoStem: true)
            #expect(explicit.allSatisfy { $0.getStemDirection() == .up }, "Explicit beam override selects group direction")

            let pinned = score.notes("C4/8, D4[stem=\"down\"], E4")
            score.beam(pinned)
            #expect(directions(pinned) == [.down, .down, .down], "Automatic stems follow one explicit pitch")
            #expect(!pinned[1].isAutoStem(), "Per-note override stays explicit")

            let manual = score.notes("C4/8, D4, E4")
            _ = manual[0].setStemDirection(.down)
            score.beam(manual)
            #expect(directions(manual) == [.down, .down, .down], "Setter opts out of automatic direction")

            let mixed = score.notes("C4/8[stem=\"up\"], B4[stem=\"down\"], D4")
            let before = directions(mixed)
            score.beam(mixed)
            #expect(directions(mixed) == before, "Conflicting explicit directions remain mixed")

            let preserved = score.notes(phrase)
            let individual = directions(preserved)
            score.beam(preserved, autoStem: false)
            #expect(directions(preserved) == individual, "Explicit false preserves per-note automatic directions")
            let lowLevel = score.notes(phrase)
            _ = factory.Beam(notes: lowLevel)
            #expect(directions(lowLevel) == individual, "Factory keeps its low-level direction-preserving default")
        }
    }

    /// QUnit asserts of `Beam.Auto_stemmed_tuplets_across_middle_line`.
    @Test func autoStemmedTupletsAcrossMiddleLine() throws {
        try isolated {
            let factory = Factory(options: FactoryOptions(width: 720, height: 650))
            _ = factory.setContext(SVGRenderContext(width: 720, height: 650))
            let score = factory.EasyScore()
            var groups: [[StemmableNote]] = []
            for proportional in [false, true] {
                for phrase in ["C4/8, D4, E4, F4, G4, A4, B4", "A5/8, G5, F5, E5, D5, C5, A4"] {
                    let notes = score.notes(phrase)
                    #expect(Set(notes.map { $0.getStemDirection() }).count == 2, "Fixture crosses stem boundary")
                    score.tuplet(notes, options: TupletOptions(numNotes: 7, notesOccupied: 4, ratioed: true))
                    score.beam(notes)
                    let system = factory.System(options: SystemOptions(
                        x: 25, width: 660, y: 30 + Double(groups.count) * 155,
                        details: SystemFormatterOptions(
                            spacing: proportional ? ProportionalSpacing(pixelsPerQuarter: 200) : nil
                        )
                    ))
                    system.addStave(SystemStave(voices: [score.voice(notes, time: .meter(2, 4))])).addClef(.treble)
                    groups.append(notes)
                }
            }
            try factory.draw(retain: true)
            let positions = groups.map { $0.map { $0.getAbsoluteX() } }
            try factory.draw(retain: true)
            for (row, notes) in groups.enumerated() {
                for (index, note) in notes.enumerated() {
                    let staveNote = try #require(note as? StaveNote)
                    let direction = try #require(note.beam?.getStemDirection())
                    #expect(note.getStemDirection() == direction, "All stems agree with the beam")
                    let head = staveNote.noteHeads[0]
                    #expect(!head.isDisplaced(), "A single head has no chord displacement")
                    let attachment = direction == .up ? head.getAbsoluteX() + head.getWidth() : head.getAbsoluteX()
                    close(note.getStemX(), attachment - direction.signDouble * Stem.WIDTH / 2,
                          "Stem attaches to correct edge of head")
                    #expect(note.getAbsoluteX() == positions[row][index], "Redraw preserves rhythmic anchor")
                }
            }
        }
    }

    @Test func generateBeamsStemPolicies() throws {
        try isolated {
            func notes(_ stems: [StemDirection?]) throws -> [StemmableNote] {
                try stems.map { stem in
                    let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "8", autoStem: stem == nil))
                    if let stem { _ = note.setStemDirection(stem) }
                    return note
                }
            }
            let preserve = try notes([nil, .down])
            let before = preserve.map { $0.getStemDirection() }
            _ = try Beam.generateBeams(preserve, config: BeamConfig(stemPolicy: .preserve))
            #expect(preserve.map { $0.getStemDirection() } == before)
            let explicit = try notes([nil, .down, nil])
            _ = try Beam.generateBeams(explicit, config: BeamConfig(groups: [Fraction(3, 8)], stemPolicy: .explicit))
            #expect(explicit.map { $0.getStemDirection() } == [.down, .down, .down])
            #expect(explicit[0].isAutoStem() && !explicit[1].isAutoStem())
        }
    }
}

// MARK: - Chord kerning (chord-kerning-tests.mjs)

@Suite("Upstream 5.2.0 port: chord kerning")
struct Upstream52ChordKerningTests {
    /// Attach a real note so normal formatter width accounting is exercised.
    private func chord(_ mode: ChordSymbolKerning = .auto, _ family: String = "Academico,Bravura", _ size: Double = 12) throws -> ChordSymbol {
        let symbol = ChordSymbol()
        symbol.setFont(family: family, size: "\(formatJSNumber(size))pt", weight: "normal", style: "normal")
        _ = symbol.setKerning(mode)
        _ = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q")).addModifier(symbol, index: 0)
        return symbol
    }

    @discardableResult
    private func format(_ symbol: ChordSymbol) -> ChordSymbol {
        var state = ModifierContextState()
        ChordSymbol.format([symbol], state: &state)
        return symbol
    }

    private func diminished(_ symbol: ChordSymbol) -> ChordSymbol {
        symbol.addText("A").addGlyph("diminished", symbolModifier: .sup)
    }

    private func legacyWidth(_ symbol: ChordSymbol) -> Double {
        symbol.symbolBlocks.reduce(0) { $0 + $1.getWidth() + ChordSymbol.minPadding }
    }

    @Test(arguments: ["Academico,Bravura", "Petaluma Script,Petaluma"])
    func autoTightensDiminishedAndNoneKeepsLegacyAdvances(family: String) throws {
        try isolated {
            let legacy = format(diminished(try chord(.none, family)))
            let auto = format(diminished(try chord(.auto, family)))
            #expect(auto.getWidth() < legacy.getWidth())
            #expect(legacy.getKerning() == .none)
            close(legacy.getWidth(), legacyWidth(legacy), tolerance: 0.04)
            let families = family.components(separatedBy: ",")
            #expect(auto.kernedRuns?[0].font.family == families[0])
            #expect(auto.kernedRuns?[1].font.family == families[1])
        }
    }

    @Test(arguments: ["Academico,Bravura", "Petaluma Script,Petaluma"])
    func allRootGlyphFixturesHaveContainedInkBounds(family: String) throws {
        try isolated {
            for root in "ABCDEFG" {
                for glyph in ["diminished", "halfDiminished", "majorSeventh", "#", "b"] {
                    let symbol = format(try chord(.auto, family).addText(String(root)).addGlyph(glyph, symbolModifier: .sup))
                    let bounds = try #require(symbol.getBoundingBox())
                    #expect([bounds.x, bounds.y, bounds.w, bounds.h, symbol.getWidth()].allSatisfy { $0.isFinite })
                    #expect(bounds.x >= -0.001 && bounds.x + bounds.w <= symbol.getWidth() + 0.001)
                }
            }
        }
    }

    @Test(arguments: ["Academico,Bravura", "Petaluma Script,Petaluma"])
    func sizesAndRepeatedFormattingDoNotAccumulateShifts(family: String) throws {
        try isolated {
            let small = format(diminished(try chord(.auto, family, 12)))
            let large = format(diminished(try chord(.auto, family, 24)))
            func gap(_ symbol: ChordSymbol) -> Double {
                guard let runs = symbol.kernedRuns, runs.count > 1 else { return .nan }
                return runs[1].x - runs[0].x - runs[0].metrics.width
            }
            close(gap(large), gap(small) * 2, tolerance: 0.04)
            for (i, run) in (small.kernedRuns ?? []).enumerated() {
                let other = try #require(large.kernedRuns?[i])
                close(VexFont.convertSizeToPixelValue(other.font.size), VexFont.convertSizeToPixelValue(run.font.size) * 2,
                      tolerance: 0.04)
                close(other.y, run.y * 2, tolerance: 0.04)
            }
            let before = large.kernedRuns
            for _ in 0..<3 { format(large) }
            #expect(large.kernedRuns == before)
            #expect((large.getBoundingBox()?.x ?? -1) >= 0, "bounds queries never mutate run metrics")
            _ = small.setFontSize(24)
            format(small)
            close(small.getWidth(), large.getWidth(), tolerance: 0.04)
        }
    }

    @Test func textSpansRetainShapingAndAdjacentTextFormsOneRun() throws {
        try isolated {
            let symbol = format(try chord().addText("F").addText("maj7"))
            #expect(symbol.kernedRuns?.count == 1)
            #expect(symbol.kernedRuns?[0].text == "Fmaj7")
            let combined = format(try chord().addGlyphOrText("C#7"))
            #expect(combined.kernedRuns?.map { $0.text } == ["C", Glyphs.csymAccidentalSharp, "7"])
        }
    }

    @Test func stackedScriptGroupsShareAnAnchor() throws {
        try isolated {
            for (first, second) in [(SymbolModifier.sup, SymbolModifier.sub), (.sub, .sup)] {
                let symbol = format(try chord().addText("F7").addGlyphOrText("b9", symbolModifier: first)
                    .addGlyphOrText("#11", symbolModifier: second).addText("sus4"))
                let runs = try #require(symbol.kernedRuns)
                close(runs[1].x, runs[3].x)
                let end = runs[1..<(runs.count - 1)].map { $0.x + $0.metrics.width }.max() ?? 0
                #expect(runs[runs.count - 1].x > end)
                format(symbol)
                #expect(symbol.kernedRuns == runs)
            }
        }
    }

    @Test func unsupportedFontsAndStylesRetainLegacyLayout() throws {
        try isolated {
            for (family, weight, style) in [
                ("Arial,Bravura", "normal", "normal"),
                ("Academico,Bravura", "bold", "normal"),
                ("Academico,Bravura", "normal", "italic"),
            ] {
                func make(_ mode: ChordSymbolKerning) throws -> ChordSymbol {
                    let symbol = try chord(mode, family)
                    symbol.setFont(family: family, size: "12pt", weight: weight, style: style)
                    return format(diminished(symbol))
                }
                let auto = try make(.auto)
                #expect(auto.kernedRuns == nil)
                close(auto.getWidth(), try make(.none).getWidth())
            }
        }
    }

    @Test func reformattingPicksUpFontContentCacheAndModeChanges() throws {
        try isolated {
            let symbol = format(diminished(try chord()))
            symbol.setFont(family: "Petaluma Script,Petaluma", size: "18pt", weight: "normal", style: "normal")
            _ = symbol.addText("7")
            VexElement.clearTextMeasurementCache()
            format(symbol)
            let fresh = format(diminished(try chord(.auto, "Petaluma Script,Petaluma", 18)).addText("7"))
            #expect(symbol.kernedRuns == fresh.kernedRuns)
            format(symbol.setKerning(.none))
            #expect(symbol.kernedRuns == nil)
            // Legacy blocks retain the fonts they had when added.
            close(symbol.getWidth(), legacyWidth(symbol), tolerance: 0.04)
            format(symbol.setKerning(.auto))
            #expect(symbol.kernedRuns == fresh.kernedRuns)
        }
    }

    @Test func customProfilesShiftTheFollowingAdvance() throws {
        try isolated {
            var profile = ChordSymbolKerningProfile(
                textFont: "Academico", musicFont: "Bravura",
                pairs: [ChordSymbolKerningPair(left: "A", right: Glyphs.csymDiminished, position: .superscript, adjustmentEm: 0)]
            )
            func make() throws -> ChordSymbol { diminished(try chord()).addText("7") }
            let base = format(try make().setKerningProfile(profile))
            profile.pairs[0].adjustmentEm = -0.1
            let adjusted = format(try make().setKerningProfile(profile))
            close(base.getWidth() - adjusted.getWidth(), 1.6, tolerance: 0.04)
            close((base.kernedRuns?[2].x ?? 0) - (adjusted.kernedRuns?[2].x ?? 0), 1.6, tolerance: 0.04)
            format(base)
            close(base.getWidth() - adjusted.getWidth(), 1.6, tolerance: 0.04)
            var invalid = profile
            invalid.pairs[0].adjustmentEm = .nan
            expectError("Invalid") { _ = try make().setKerningProfile(invalid) }
            #expect(format(try chord()).getWidth() == 0)
        }
    }

    @Test func rightAlignmentUsesTheComputedWidth() throws {
        try isolated {
            let ctx = SVGRenderContext(width: 600, height: 240)
            let symbol = diminished(ChordSymbol())
            symbol.setFont(family: "Academico,Bravura", size: "18pt", weight: "normal", style: "normal")
            _ = symbol.setKerning(.auto).setHorizontal(.right).setReportWidth(false)
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q"))
            _ = note.addModifier(symbol, index: 0)
            let stave = Stave(x: 30, y: 80, width: 500)
            _ = stave.setContext(ctx)
            _ = note.setStave(stave)
            try VexFoundation.Formatter.FormatAndDraw(ctx: ctx, stave: stave, notes: [note])
            _ = symbol.setContext(ctx)
            try symbol.draw()
            let anchor = note.getModifierStartXY(position: .above, index: 0).x
            let bounds = try #require(symbol.getBoundingBox())
            close(bounds.x + bounds.w, anchor, tolerance: 0.04)
        }
    }
}

// MARK: - Metrics and text cache (metrics-tests.mjs)

@Suite("Upstream 5.2.0 port: metrics")
struct Upstream52MetricsTests {
    @Test func fontAndStyleRecordsAreIndependent() {
        isolated {
            var edited = Metrics.getFontInfo("StaveNote")
            let original = Metrics.getFontInfo("StaveNote")
            edited.size = "99pt"
            #expect(Metrics.getFontInfo("StaveNote") == original)
            let first = VexElement()
            let second = VexElement()
            first.fontInfo.size = "99pt"
            #expect(second.fontInfo.size != "99pt")
        }
    }

    @Test func clearingMetricsAndTheTextCacheKeepsMeasurementsStable() {
        isolated {
            let width = VexElement.measureWidth("same", key: "Element")
            Metrics.clear()
            Metrics.clear("Element")
            VexElement.clearTextMeasurementCache()
            #expect(VexElement.measureWidth("same", key: "Element") == width)
        }
    }
}

// MARK: - Core module changes

@Suite("Upstream 5.2.0 port: core changes")
struct Upstream52CoreTests {
    @Test func keySignatureClefOverrideFollowsInlineClef() throws {
        try isolated {
            let inline = KeySigNote(keySpec: "C", cancelKeySpec: "D", clef: .treble)
            _ = inline.setStave(Stave(x: 0, y: 0, width: 200).addClef(.bass))
            inline.preFormat()
            let native = KeySignature(keySpec: "C", cancelKeySpec: "D")
            native.setStave(Stave(x: 0, y: 0, width: 200).addClef(.treble))
            native.format()
            #expect(inline.keySignature.accList.count == 2)
            #expect(inline.keySignature.accList.map { $0.line } == native.accList.map { $0.line })
        }
    }

    @Test func staveTracksClefModifiersAndOptions() {
        isolated {
            #expect(Stave(x: 0, y: 0, width: 100, options: StaveOptions(clef: .bass)).getClef() == .bass)
            let stave = Stave(x: 0, y: 0, width: 100)
            _ = stave.addModifier(Clef(type: .alto))
            #expect(stave.getClef() == .alto)
            _ = stave.addModifier(Clef(type: .bass), position: .end)
            #expect(stave.getEndClef() == .bass)
            #expect(Clef(type: .tenor).getType() == .tenor)
        }
    }

    @Test func tupletKeepsExplicitZeroOffsets() throws {
        try isolated {
            let notes = try ["8", "8", "8"].map { StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: $0)) }
            let tuplet = try Tuplet(notes: notes, options: TupletOptions(yOffset: 0, textYOffset: 0))
            #expect(tuplet.yOffset == 0)
            #expect(tuplet.textYOffset == 0)
        }
    }

    @Test func parserReportsFurthestErrorAndRuleRanges() {
        isolated {
            let score = EasyScore.create()
            let result = score.parser.parse("C4/q, D4/q, x")
            #expect(!result.success)
            #expect(result.furthestErrorPos == 12)
            #expect(score.parser.parse("C4/q").furthestErrorPos == -1)
        }
    }

    @Test func registryTransactionRestoresIndexesAndDetachesElements() {
        isolated {
            let registry = Registry()
            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }
            let keep = VexElement()
            var temporary: VexElement?
            #expect(throws: VexError.self) {
                try registry.transaction {
                    temporary = VexElement()
                    throw VexError("Stop")
                }
            }
            #expect(ids(registry.getRegisteredElements()) == ids([keep]))
            _ = temporary?.setAttribute("id", "after")
            #expect(registry.getElementById("after") == nil)
        }
    }

    @Test func noteAndTickableReleaseStagedAssignments() throws {
        try isolated {
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "w"))
            let voice = Voice(time: VoiceTime()).addTickables([note])
            _ = note.setStave(Stave(x: 0, y: 0, width: 100))
            #expect(note.voice === voice)
            note.clearVoice().clearStave()
            #expect(note.voice == nil)
            #expect(note.getStave() == nil)
        }
    }

    @Test func accidentalIsCautionary() throws {
        try isolated {
            let accidental = try Accidental(parsing: "#")
            #expect(!accidental.isCautionary())
            #expect(accidental.setAsCautionary().isCautionary())
        }
    }

    @Test func staveNoteBoundingBoxCanLeaveOutModifiers() throws {
        try isolated {
            let stave = Stave(x: 10, y: 40, width: 300)
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q"))
            _ = note.setStave(stave)
            _ = note.addModifier(Annotation("far"), index: 0)
            try VexFoundation.Formatter.FormatAndDraw(ctx: SVGRenderContext(width: 400, height: 200), stave: stave, notes: [note])
            let core = try #require(note.getBoundingBox(includeModifiers: false))
            let full = try #require(note.getBoundingBox())
            #expect(full.h >= core.h)
        }
    }

    @Test func clefNoteBoundingBoxUsesStaveLine() throws {
        try isolated {
            let stave = Stave(x: 10, y: 40, width: 300)
            let note = ClefNote(type: .bass)
            _ = note.setStave(stave)
            let box = try #require(note.getBoundingBox())
            let clef = note.getClef()
            close(box.y, stave.getYForLine(clef.line) + clef.getYShift() - clef.getTextMetrics().actualBoundingBoxAscent)
        }
    }

    @Test func factoryBracketsApplyAnExplicitZeroLine() throws {
        try isolated {
            let factory = Factory()
            let note = factory.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "q"))
            #expect(factory.TextBracket(from: note, to: note, text: "8", line: 0).line == 0)
            #expect(factory.VibratoBracket(from: note, to: note, line: 0).line == 0)
        }
    }

    @Test func articulationAliasesCodesAndGlyphs() throws {
        let marks = try Articulation.parseEasyScore("staccato, fermata.below, a., fermataAbove, marcato, staccatissimo")
        #expect(marks.map { $0.type } == ["a.", "a@", "a.", Glyphs.fermataAbove, "a^", "av"])
        #expect(marks[1].position == .below)
        #expect(try Articulation.parseEasyScore("a,.below")[0].type == "a,")
        #expect(try Articulation.parseEasyScore("a.")[0].type == "a.")
        expectError("Unknown EasyScore articulation") { _ = try Articulation.parseEasyScore("notAMark") }
    }
}

// MARK: - EasyScore (easyscore-tests.mjs)

@Suite("Upstream 5.2.0 port: EasyScore")
struct Upstream52EasyScoreTests {
    private func create(_ options: EasyScoreOptions = EasyScoreOptions()) -> EasyScore {
        EasyScore.create(options: FactoryOptions(width: 500, height: 240), scoreOptions: options)
    }

    private func queued(_ score: EasyScore) -> Int { score.factory.getRenderQueue().count }

    private func registered(_ registry: Registry) -> Set<ObjectIdentifier> {
        Set(registry.getRegisteredElements().map { ObjectIdentifier($0) })
    }

    private func staveNote(_ key: String, _ duration: String = "q", clef: ClefName? = nil, octaveShift: Int? = nil) throws -> StaveNote {
        StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: duration, octaveShift: octaveShift, clef: clef))
    }

    @Test func pureParsingReturnsSourceSpansAndDiagnostics() {
        isolated {
            let score = create()
            var calls = 0
            score.addCommitHook { _, _, _ in calls += 1 }
            let source = "C4/q,\n D4[articulations=\"fermata\"]"
            let parsed = score.parseNotation(source)
            #expect(parsed.success)
            #expect(calls == 0)
            #expect(score.builder.getElements().notes.isEmpty)
            #expect(parsed.pieces.map { $0.duration } == ["q", "q"])
            let span = parsed.pieces[1].source
            #expect(String(Array(source)[span.start..<span.end]) == "D4[articulations=\"fermata\"]")
            for line in ["C4/q, invalid", "C4/999", "C4/q[stem=\"sideways\"]", "C4/q[articulations=\"notAMark\"]"] {
                let result = score.parseNotation(line)
                #expect(!result.success, "\(line)")
                #expect(result.pieces.isEmpty)
                #expect(!(result.diagnostics.first?.code.isEmpty ?? true))
                #expect((result.diagnostics.first?.end ?? -1) >= (result.diagnostics.first?.start ?? 0))
            }
            let bad = score.parseNotation("C4/q,\n X4")
            #expect(bad.diagnostics[0].line == 2)
            #expect(bad.diagnostics[0].column == 2)
        }
    }

    @Test func legacyParseResultsAndCustomBuildersRemainSupported() throws {
        try isolated {
            final class CustomBuilder: Builder {
                var commits = 0
                override func commitPiece(source: EasyScoreSourceSpan?) {
                    commits += 1
                    super.commitPiece(source: source)
                }
            }
            let factory = Factory(options: FactoryOptions(width: 500, height: 240))
            let builder = CustomBuilder(factory: factory)
            let score = factory.EasyScore(options: EasyScoreOptions(builder: builder))
            #expect(!score.parse("C4/q, invalid").success)
            #expect(builder.commits == 1)
            #expect(queued(score) == 1, "legacy non-throwing parse retains its partial result")
            #expect(factory.EasyScore().parse("C4/q[application=\"value\"]").success)
            let strict = factory.EasyScore(options: EasyScoreOptions(builder: builder, throwOnError: true))
            var hooks = 0
            strict.addCommitHook { _, _, _ in hooks += 1 }
            _ = try strict.notesThrowing("D4/q, E4")
            #expect(builder.commits == 3, "preflight does not execute the custom builder")
            #expect(hooks == 2, "hooks execute once per note")
        }
    }

    @Test func validationRespectsReplacedHooksAndLegacyParseDefaults() throws {
        try isolated {
            let factory = Factory(options: FactoryOptions(width: 500, height: 240))
            var custom = ""
            let score = factory.EasyScore(options: EasyScoreOptions(
                commitHooks: [{ options, _, _ in custom = options["articulations"] ?? "" }],
                throwOnError: true
            ))
            _ = try score.notesThrowing("C4/q[articulations=\"application-specific\"]")
            #expect(custom == "application-specific")
            score.set(clef: .bass, stem: "down")
            _ = try score.parseThrowing("C4/q")
            let parsedLine = (score.builder.getElements().notes[0] as? StaveNote)?.keyProps[0].line
            #expect(parsedLine == (try staveNote("c/4", clef: .treble)).keyProps[0].line, "parse retains Builder defaults")
            let noteLine = (try score.notesThrowing("C4/q")[0] as? StaveNote)?.keyProps[0].line
            #expect(noteLine == (try staveNote("c/4", clef: .bass)).keyProps[0].line, "notes applies score defaults")
            #expect(!score.parseNotation("C4/q", options: ["durationOverride": "-1/1"]).success)
        }
    }

    @Test func strictFailuresPreservePriorNotesQueuesAndRegistry() throws {
        try isolated {
            let registry = Registry()
            Registry.enableDefaultRegistry(registry)
            defer { Registry.disableDefaultRegistry() }
            let score = create()
            let existing = try score.notesThrowing("C4/w[id=\"keep\"]")
            let initial = registered(registry)
            for line in ["D4/q, invalid", "D4/9", "D4/q[typo=\"oops\"]"] {
                #expect(throws: EasyScoreError.self) { _ = try score.notesThrowing(line) }
                #expect(queued(score) == 1)
                #expect(registered(registry) == initial)
                #expect(ids(score.builder.getElements().notes) == ids(existing))
            }
            var leaked: StemmableNote?
            score.addCommitHook { options, note, _ in
                leaked = note
                if options["id"] == "fail" { throw VexError("App", "application hook failed") }
            }
            expectError("application hook failed") { _ = try score.notesThrowing("D4/q, E4[id=\"fail\"]") }
            #expect(queued(score) == 1)
            #expect(registered(registry) == initial)
            #expect(registry.getElementById("keep") === existing[0])
            let leakedNote = try #require(leaked)
            #expect(Factory.getOwner(leakedNote) == nil)
            _ = leakedNote.setAttribute("id", "after-failure")
            #expect(registry.getElementById("after-failure") == nil, "failed objects are detached from registry")
            #expect(Registry.getDefaultRegistry() === registry, "ambient registry is not replaced")
        }
    }

    @Test func measureValidationIsAtomicWithCompleteSourceDiagnostics() throws {
        try isolated {
            let score = create(EasyScoreOptions(extensions: ["label"]))
            let good = try score.measures("C4/h[label=\"a|b\"], D4, |, E4, F4")
            // Swift `getDuration()` returns the canonical value ("2"); `durationToken` keeps the token as written.
            #expect(good.map { $0.map { $0.durationToken } } == [["h", "h"], ["h", "h"]])
            let before = queued(score)
            do {
                _ = try score.measures("C4/w |\n invalid")
                Issue.record("Expected an EasyScoreError")
            } catch let error as EasyScoreError {
                #expect(error.diagnostics[0].measure == 2)
                #expect(error.diagnostics[0].line == 2)
                #expect(error.diagnostics[0].column == 2)
            }
            #expect(queued(score) == before)
            score.addCommitHook { options, _, _ in
                if options["id"] == "fail" { throw VexError("App", "measure hook") }
            }
            expectError("measure hook") { _ = try score.measures("C4/w | D4/w[id=\"fail\"]") }
            #expect(queued(score) == before)
            #expect(ids(score.builder.getElements().notes) == ids(good[1]))
            let legacy = Factory(options: FactoryOptions(width: 500, height: 240)).EasyScore()
            #expect(throws: EasyScoreError.self) { _ = try legacy.measures("C4/w | invalid") }
            #expect(queued(legacy) == 0)
        }
    }

    @Test func nativeNoteOptionsAndArticulationVocabulary() throws {
        try isolated {
            let score = create()
            let shifted = try #require(try score.notesThrowing("C4/q", options: ["octaveShift": "1", "alignCenter": "true"])[0] as? StaveNote)
            let native = try staveNote("c/4", octaveShift: 1)
            #expect(shifted.keyProps[0].line == native.keyProps[0].line)
            #expect(shifted.isCenterAligned())
            let inline = try #require(try score.notesThrowing("C4/q[octaveShift=\"1\"]")[0] as? StaveNote)
            #expect(inline.keyProps[0].line == native.keyProps[0].line)
            for (name, code) in [("staccato", "a."), ("fermata", "a@"), ("a.", "a."), ("fermataAbove", Glyphs.fermataAbove)] {
                let note = try score.notesThrowing("C4/q[articulations=\"\(name)\"]")[0]
                #expect((note.getModifiers()[0] as? Articulation)?.type == code, "\(name)")
            }
            let below = try score.notesThrowing("C4/q[articulations=\"fermata.below\"]")[0].getModifiers()[0]
            #expect(below.getPosition() == .below)
            expectError("Unknown EasyScore articulation") { _ = try score.notesThrowing("C4/q[articulations=\"typo\"]") }
        }
    }

    @Test func voiceModesMeterSpacingAndRationalTuplets() throws {
        try isolated {
            let score = create()
            let notes = try score.notesThrowing("C4/h, D4/q, E4")
            let voice = try score.voiceThrowing(notes, options: EasyScoreVoiceOptions(
                time: VoiceTime(numBeats: 4, beatValue: 4, resolution: Tables.RESOLUTION), softmaxFactor: 1
            ))
            for note in notes { close(voice.softmax(note.getTicks().value()), 1.0 / 3) }
            let soft = try score.voiceThrowing(try score.notesThrowing("C4/w, D4/w"), options: EasyScoreVoiceOptions(mode: .soft))
            #expect(soft.getMode() == .soft)
            let full = try score.voiceThrowing(try score.notesThrowing("C4/q"), options: EasyScoreVoiceOptions(mode: .full))
            #expect(full.getMode() == .full)
            let before = score.factory.getVoices().count
            expectError("Too many ticks") {
                _ = try score.voiceThrowing(notes, options: EasyScoreVoiceOptions(time: VoiceTime(numBeats: 1, beatValue: 4)))
            }
            #expect(score.factory.getVoices().count == before)
            #expect(notes[0].voice === voice, "overflow does not reassign already-owned notes")
            let odd = try score.notesThrowing("C5/8, D5, E5, F5, G5, A5, B5")
            #expect(try score.voiceThrowing(odd, options: EasyScoreVoiceOptions(time: VoiceTime(numBeats: 7, beatValue: 8))).isComplete())
            let nested = try score.notesThrowing("C5/8, D5, E5")
            #expect(ids(try score.tupletThrowing(nested)) == ids(nested))
            #expect(ids(try score.tupletThrowing(nested)) == ids(nested))
            let expected = nested.reduce(Fraction(0, 1)) { $0.add($1.getTicks()) }
            #expect(try score.voiceThrowing(nested, options: EasyScoreVoiceOptions(mode: .soft)).getTicksUsed().equals(expected))
        }
    }

    @Test func annotationAttachmentAndTiesHaveValidatedOwnership() throws {
        try isolated {
            let score = create()
            let notes = try score.notesThrowing("(C4 E4 G4)/h, (C4 F4 A4)")
            let annotation = try score.make.annotation(text: "dolce")
            #expect(try score.attach(notes[0], annotation) === notes[0])
            try score.attach(notes[0], annotation)
            #expect(notes[0].getModifiers().count == 1)
            #expect(queued(score) == 2, "attached annotation has no independent draw step")
            let tie = try score.make.tie(from: notes[0], to: notes[1], firstIndexes: [0], lastIndexes: [0])
            #expect(type(of: tie) == StaveTie.self)
            #expect(queued(score) == 3)
            for indices in [[-1], [3], []] {
                expectAnyError { _ = try score.make.tie(from: notes[0], to: notes[1], firstIndexes: indices, lastIndexes: indices) }
            }
            #expect(queued(score) == 3)
            let foreign = create()
            let foreignNote = try foreign.notesThrowing("C4/h")[0]
            expectError("Factory") { _ = try score.make.tie(from: notes[0], to: foreignNote) }
            expectError("Factory") { try score.attach(notes[0], try foreign.make.annotation(text: "wrong")) }
            expectError("already attached") { try score.attach(notes[1], annotation) }
            let native = Annotation("custom")
            try score.attach(notes[1], native)
            #expect(native.getNote() === notes[1])
            score.reset()
            #expect(queued(score) == 0)
            #expect(score.builder.getElements().notes.isEmpty)
        }
    }

    @Test func scoreLocalIDsFollowRenamesAndRejectCollisions() throws {
        try isolated {
            let score = create()
            let other = create()
            let notes = try score.notesThrowing("C4/h[id=\"a\"], D4[id=\"b\"]")
            let (a, b) = (notes[0], notes[1])
            let independent = try other.notesThrowing("E4/w[id=\"a\"]")[0]
            #expect(score.getElement("a") === a)
            #expect(other.getElement("a") === independent)
            #expect(score.getElement("missing") == nil)
            expectError("No note with ID") { _ = try score.getNote("missing") }
            let label = try score.make.annotation(text: "test")
            #expect(score.getElement(label.getAttribute("id") ?? "") === label)
            expectError("No note with ID") { _ = try score.getNote(label.getAttribute("id") ?? "") }
            try a.setAttributeThrowing("id", "renamed")
            #expect(score.getElement("a") == nil)
            #expect(try score.getNote("renamed") === a)
            expectError("Duplicate score element ID") { try a.setAttributeThrowing("id", "b") }
            expectError("nonempty ID") { try a.setAttributeThrowing("id", nil) }
            #expect(a.getAttribute("id") == "renamed")
            #expect(try score.getNote("b") === b)
            score.reset()
            #expect(score.getElement("renamed") == nil)
            try a.setAttributeThrowing("id", "b") // Reset released the local collision subscription.
            #expect(try other.getNote("a") === independent)
        }
    }

    @Test func sourceMappingPreservesCompleteMeasureInput() throws {
        try isolated {
            let score = create()
            let input = "  C4/h[id=\"a\"], D4 |\n E4[articulations=\"staccato\"], F4  "
            let measures = try score.measures(input)
            let note = measures[1][0]
            let source = try #require(score.getSource(note))
            #expect(source.input == input)
            #expect(source.measure == 2)
            #expect(String(Array(input)[source.start..<source.end]) == "E4[articulations=\"staccato\"]")
            #expect(score.getSource(note.getModifiers()[0]) == source)
            #expect(EasyScore.getSource(note) == source)
            #expect(create().getSource(note) == nil)
            _ = note.setAttribute("id", "changed")
            #expect(score.getSource(note) == source)
            let native = try score.adopt(try staveNote("g/4"), role: .note)
            #expect(score.getSource(native) == nil)
            score.reset()
            #expect(score.getSource(note) == nil)
            #expect(EasyScore.getSource(note) == nil)
        }
    }

    @Test func failedConstructionRollsBackReferencesAndSubscriptions() throws {
        try isolated {
            let score = create()
            let keep = try score.notesThrowing("C4/w[id=\"keep\"]")[0]
            var escaped: StemmableNote?
            score.addCommitHook { options, note, _ in
                if options["id"] == "temporary" { escaped = note }
            }
            let registry = Registry()
            registry.register(keep)
            Registry.enableDefaultRegistry(registry)
            do {
                defer { Registry.disableDefaultRegistry() }
                expectError("Duplicate score element ID") {
                    _ = try score.measures("D4/w[id=\"temporary\"] | E4/w[id=\"keep\"]")
                }
                #expect(score.getElement("temporary") == nil)
                #expect(try score.getNote("keep") === keep)
                #expect(queued(score) == 1)
                let escapedNote = try #require(escaped)
                #expect(Factory.getOwner(escapedNote) == nil)
                #expect(EasyScore.getSource(escapedNote) == nil)
                #expect(registered(registry) == [ObjectIdentifier(keep)])
                try escapedNote.setAttributeThrowing("id", "keep") // No leaked local ID validator after rollback.
                _ = keep.setAttribute("id", "retained")
                #expect(registry.getElementById("retained") === keep)
                #expect(try score.getNote("retained") === keep)
            }
            let legacy = Factory(options: FactoryOptions(width: 500, height: 240)).EasyScore()
            let line = "C4/q[id=\"partial\"], invalid"
            #expect(!legacy.parse(line).success)
            #expect(try legacy.getNote("partial") === legacy.builder.elements.notes[0])
            #expect(legacy.getSource(try legacy.getNote("partial"))?.input == line)
        }
    }

    @Test func nativeAdoptionValidatesRolesAndOwnership() throws {
        try isolated {
            let score = create()
            let note = try staveNote("c/4", "w")
            let label = Annotation("native")
            let other = create()
            expectError("Invalid adopted element role") { try score.adopt(note, role: .modifier) }
            expectError("Invalid adopted element role") { try score.adopt(label, role: .drawable) }
            expectError("Invalid adopted element role") { try score.adopt(Clef(type: .treble), role: .drawable) }
            let noteID = note.getAttribute("id") ?? ""
            #expect(score.getElement(noteID) == nil)
            #expect(Factory.getOwner(note) == nil)
            #expect(try score.adopt(note, role: .note) === note)
            try score.adopt(note, role: .note)
            #expect(queued(score) == 1)
            #expect(try score.getNote(noteID) === note)
            expectError("another Factory") { try other.adopt(note, role: .note) }
            #expect(other.getElement(noteID) == nil)
            try score.adopt(label, role: .modifier)
            try score.attach(note, label)
            try score.attach(note, label)
            #expect(queued(score) == 1)
            #expect(note.getModifiers().count == 1)
            #expect(Factory.getOwner(label) === score.factory)
            let voice = try score.voiceThrowing([note], options: EasyScoreVoiceOptions())
            expectError("Invalid adopted element role") { try score.adopt(voice, role: .drawable) }
            #expect(score.getElement(voice.getAttribute("id") ?? "") === voice)
            let conflict = Annotation("conflict").setAttribute("id", noteID)
            expectError("Duplicate score element ID") { try score.adopt(conflict, role: .modifier) }
            #expect(Factory.getOwner(conflict) == nil)
            expectError("later failure") {
                _ = try score.factory.transaction {
                    try score.factory.adopt(note, role: .note)
                    throw VexError("Test", "later failure")
                }
            }
            #expect(Factory.getOwner(note) === score.factory, "rollback preserves prior ownership")
            score.reset()
            #expect(queued(score) == 0)
            try score.adopt(note, role: .note)
            #expect(queued(score) == 1, "explicit readoption queues a note after reset")
        }
    }

    @Test func pureTypedValidatorsRejectCustomOptionsBeforeConstruction() throws {
        try isolated {
            var commits = 0
            let score = create(EasyScoreOptions(extensions: ["label"], validate: { context in
                if let label = context.options["label"], label != "melody" { throw VexError("App", "Unknown label") }
            }))
            score.addCommitHook { _, _, _ in commits += 1 }
            #expect(score.parseNotation("C4/q[label=\"melody\"]").pieces[0].chord[0].key == "C")
            #expect(score.parseNotation("D4/q[label=\"bad\"]").diagnostics[0].message == "Unknown label")
            expectError("Unknown label") { _ = try score.notesThrowing("C4/q[label=\"bad\"]") }
            #expect(commits == 0)
            #expect(queued(score) == 0)
            _ = try score.notesThrowing("C4/w[label=\"melody\"]")
            #expect(commits == 1)
        }
    }

    @Test func sheetsAndNestedBuildGroupsShareOwnershipAndRollback() throws {
        try isolated {
            let score = create()
            score.setContext(SVGRenderContext(width: 500, height: 240))
            let keep = try score.notesThrowing("C4/w[id=\"keep\"]")[0]
            let original = score.builder.elements.notes
            var discarded: Annotation?
            expectError("cancel group") {
                _ = try score.build { score -> Int in
                    _ = try score.notesThrowing("D4/w[id=\"temporary\"]")
                    _ = try score.build { score in discarded = try score.make.annotation(text: "temporary") }
                    _ = try score.sheet(SheetOptions(width: 500)).addSystem()
                    throw VexError("App", "cancel group")
                }
            }
            let discardedLabel = try #require(discarded)
            #expect(score.getElement("temporary") == nil)
            #expect(score.getElement(discardedLabel.getAttribute("id") ?? "") == nil)
            #expect(Factory.getOwner(discardedLabel) == nil)
            #expect(score.factory.getSheets().isEmpty)
            #expect(score.factory.getSystems().isEmpty)
            #expect(ids(score.builder.elements.notes) == ids(original))
            #expect(try score.getNote("keep") === keep)
            let sheet = try score.build { try $0.sheet(SheetOptions(width: 500)) }
            let system = sheet.addSystem()
            let voice = score.voice([keep])
            system.addStave(SystemStave(voices: [voice])).addClef(.treble)
            #expect(Factory.getOwner(system) === score.factory)
            #expect(ids(sheet.getSystems()) == ids([system]))
            #expect(score.factory.getSheets().count == 1)
            try score.draw(retain: true)
            #expect(sheet.getRows().count == 1)
            score.reset()
            #expect(score.factory.getSheets().isEmpty)
        }
    }

    @Test func typedSequencesAndModifierConstructorsPreserveNativeFields() throws {
        try isolated {
            let score = create().set(clef: .bass, stem: "down")
            let note = try score.make.note(try StaveNoteStruct(
                parsingKeys: ["c/3/x"], duration: "q", stemDirection: .up, strokePx: 4, octaveShift: 1
            ))
            #expect(note.getStemDirection() == .up)
            #expect(!note.isAutoStem())
            #expect(note.keyProps[0].code == (try staveNote("c/3/x", clef: .bass, octaveShift: 1)).keyProps[0].code)
            let constructors: [(String, () throws -> Modifier)] = [
                ("accidental", { try score.make.accidental(type: "++") }),
                ("articulation", { try score.make.articulation(type: "fermata.below") }),
                ("ornament", { try score.make.ornament("tr", upperAccidental: "#", delayed: true) }),
                ("dot", { try score.make.dot() }),
                ("parenthesis", { try score.make.parenthesis(.left) }),
                ("stroke", { try score.make.stroke(.rollUp, allVoices: false) }),
                ("tremolo", { try score.make.tremolo(3) }),
                ("vibrato", { try score.make.vibrato() }),
                ("chordSymbol", { try score.make.chordSymbol(fontSize: 14) }),
                ("fingering", { try score.make.fingering(number: "2", position: .left) }),
                ("stringNumber", { try score.make.stringNumber(number: "4", position: .above, drawCircle: false) }),
            ]
            for (name, construct) in constructors {
                let modifier = try construct()
                #expect(Factory.getOwner(modifier) === score.factory, "\(name)")
                try score.attach(note, modifier)
                #expect(modifier.getNote() === note, "\(name)")
            }
            expectError("Unknown EasyScore articulation") { _ = try score.make.articulation(type: "no-such-mark") }
            let ghost = try score.make.ghostNote("q")
            let text = try score.make.textNote(TextNoteStruct(duration: .quarter, text: "rit.", smooth: true, line: 2))
            let sequence = try score.sequence([
                .tickable(note), .tickable(ghost), .tickable(text),
                .note(try StaveNoteStruct(parsingKeys: ["d/3"], duration: "q")),
            ])
            #expect(try score.voiceThrowing(sequence, options: EasyScoreVoiceOptions()).getTicksUsed().value() == Double(Tables.RESOLUTION))
            let count = queued(score)
            let foreign = try create().notesThrowing("D4/q")[0]
            expectError("another Factory") {
                _ = try score.sequence([.notation("C4/q[id=\"rolled-back\"]"), .tickable(foreign)])
            }
            #expect(score.getElement("rolled-back") == nil)
            #expect(queued(score) == count)
        }
    }

    @Test func graceAndSubnoteGroupsOwnChildrenOnce() throws {
        try isolated {
            let score = create()
            let notes = try score.notesThrowing("C4/h, D4")
            let (parent, child) = (notes[0], notes[1])
            let grace = try score.make.graceNote(try GraceNoteStruct(parsingKeys: ["e/4"], duration: "16", slash: true))
            expectError("cancel group") {
                _ = try score.build { score -> Int in
                    _ = try score.make.noteSubGroup(notes: [child])
                    throw VexError("App", "cancel group")
                }
            }
            #expect(Factory.getGroup(child) == nil)
            #expect(child.voice == nil)
            #expect(queued(score) == 2, "batch rollback restores standalone drawing")
            let group = try score.make.graceNoteGroup(notes: [grace], slur: true)
            try score.attach(parent, group)
            #expect(Factory.getGroup(grace) === group)
            expectError("already belongs to a group") { _ = try score.make.graceNoteGroup(notes: [grace]) }
            expectError("Grouped notes") { _ = try score.voiceThrowing([grace], options: EasyScoreVoiceOptions()) }
            expectError("grouped note") { try score.adopt(grace, role: .note) }
            let sub = try score.make.noteSubGroup(notes: [child])
            try score.attach(parent, sub)
            #expect(queued(score) == 1, "subnotes are removed from the standalone queue")
            let foreign = try create().make.graceNote(try GraceNoteStruct(parsingKeys: ["c/4"], duration: "16"))
            expectError("another Factory") { _ = try score.make.graceNoteGroup(notes: [foreign]) }
            let voiced = try score.notesThrowing("F4/w")[0]
            _ = try score.voiceThrowing([voiced], options: EasyScoreVoiceOptions())
            expectError("voiced note") { _ = try score.make.noteSubGroup(notes: [voiced]) }
        }
    }

    @Test func automaticBeamsPreserveExplicitStemsAndRationalTicks() throws {
        try isolated {
            let score = create().set(time: .meter(7, 8))
            let notes = try score.notesThrowing("C4/8[stem=\"down\"], D4, E4, F4, G4, A4, B4")
            let ticks = notes.map { $0.getTicks().description }
            let groups = [Fraction(2, 8), Fraction(2, 8), Fraction(3, 8)]
            let beams = try score.autoBeam(notes, options: EasyScoreAutoBeamOptions(groups: groups, flatBeams: true, flatBeamOffset: 20))
            #expect(beams.map { $0.getNotes().count } == [2, 2, 3])
            #expect(notes.map { $0.getTicks().description } == ticks)
            #expect(groups.map { $0.description } == ["2/8", "2/8", "3/8"])
            #expect(notes[1].getStemDirection() == .down)
            #expect(beams[0].renderOptions.flatBeamOffset == 20)
            #expect(beams.allSatisfy { Factory.getOwner($0) === score.factory })
            _ = try score.voiceThrowing(notes, options: EasyScoreVoiceOptions(time: VoiceTime(numBeats: 7, beatValue: 8)))
            expectError("already belongs") { _ = try score.autoBeam(notes) }
            let mixed = try score.notesThrowing("C4/8[stem=\"down\"], D4[stem=\"up\"]")
            _ = try score.autoBeam(mixed)
            #expect(mixed.map { $0.getStemDirection() } == [.down, .up])
            let preserve = try score.notesThrowing("C4/8, C6")
            let before = preserve.map { $0.getStemDirection() }
            _ = try score.autoBeam(preserve, options: EasyScoreAutoBeamOptions(autoStem: false))
            #expect(preserve.map { $0.getStemDirection() } == before)
            let override = try score.notesThrowing("C4/8[stem=\"down\"], D4[stem=\"down\"]")
            _ = try score.autoBeam(override, options: EasyScoreAutoBeamOptions(autoStem: true))
            #expect(override.map { $0.getStemDirection() } == [.up, .up])
            let rests = try score.notesThrowing("C4/8, B4/8/r, D4/8, E4/8")
            #expect(try score.autoBeam(rests, options: EasyScoreAutoBeamOptions(
                groups: [Fraction(4, 8)], beamRests: true, beamMiddleOnly: true, showStemlets: true
            )).count == 1)
            let untouched = try score.notesThrowing("C4/8, D4")
            expectError("positive finite") {
                _ = try score.autoBeam(untouched, options: EasyScoreAutoBeamOptions(groups: [Fraction(0, 1)]))
            }
            #expect(untouched.allSatisfy { !$0.hasBeam() })
            let foreign = try create().notesThrowing("C4/8")[0]
            expectError("this Factory") { _ = try score.autoBeam([foreign]) }
        }
    }

    @Test func tupletHandlesPreserveNestedRatios() throws {
        try isolated {
            let score = create()
            let notes = try score.notesThrowing("C4/8, D4, E4, F4, G4, A4")
            let inner = try score.make.tuplet(notes: Array(notes[0..<3]), options: TupletOptions(
                numNotes: 3, notesOccupied: 2, yOffset: 0, textYOffset: 0
            ))
            _ = try score.make.tuplet(notes: notes, options: TupletOptions(numNotes: 5, notesOccupied: 4, ratioed: true))
            #expect(inner.yOffset == 0)
            let eighth = Fraction(Tables.RESOLUTION, 8)
            #expect(notes[0].getTicks().equals(eighth.clone().multiply(2, 3).multiply(4, 5)))
            _ = try score.autoBeam(notes, options: EasyScoreAutoBeamOptions(groups: [Fraction(1, 4)]))
            _ = try score.voiceThrowing(notes, options: EasyScoreVoiceOptions(mode: .soft))
            expectError("before inserting") { _ = try score.make.tuplet(notes: notes) }
            let fresh = try score.notesThrowing("C4/8, D4, E4")
            let ticks = fresh.map { $0.getTicks().description }
            expectError("positive integers") {
                _ = try score.make.tuplet(notes: fresh, options: TupletOptions(notesOccupied: 0))
            }
            #expect(fresh.map { $0.getTicks().description } == ticks)
        }
    }

    @Test func relationshipHelpersRejectForeignOrInvalidEndpoints() throws {
        try isolated {
            let score = create()
            let notes = try score.notesThrowing("(C4 E4)/h, (C5 E5)")
            let (from, to) = (notes[0], notes[1])
            var curveOptions = CurveOptions()
            curveOptions.thickness = 3
            let curve = try score.make.curve(from: from, to: to, options: curveOptions)
            let hairpin = try score.make.hairpin(from: from, to: to, type: .crescendo,
                                                 options: HairpinRenderOptions(height: 14, yShift: 0))
            let spans: [VexElement] = [
                curve, hairpin,
                try score.make.line(from: from, to: to, firstIndexes: [1], lastIndexes: [0], text: "gliss."),
                try score.make.textBracket(from: from, to: to, text: "8", superscript: "va", position: .top, line: 0),
                try score.make.vibratoBracket(from: from, to: to, line: 0),
                try score.make.pedalMarking(notes: notes.compactMap { $0 as? StaveNote }, type: .mixed),
            ]
            #expect(spans.allSatisfy { Factory.getOwner($0) === score.factory })
            #expect(curve.renderOptions.thickness == 3)
            #expect(hairpin.renderOptions.height == 14)
            let count = queued(score)
            let foreign = try create().notesThrowing("C4/w")[0]
            let failures: [() throws -> Void] = [
                { _ = try score.make.curve(from: from, to: foreign) },
                { _ = try score.make.hairpin(from: nil, to: nil, type: .crescendo) },
                { _ = try score.make.line(from: from, to: to, firstIndexes: [2], lastIndexes: [0]) },
                { _ = try score.make.textBracket(from: from, to: nil, text: "8", superscript: "va", position: .top) },
                { _ = try score.make.pedalMarking(notes: [foreign].compactMap { $0 as? StaveNote }) },
            ]
            for build in failures { expectAnyError(build) }
            #expect(queued(score) == count)
            _ = try score.make.curve(from: from)
            expectError("endpoint") { _ = try score.make.hairpin(from: nil, to: to, type: .decrescendo) }
            _ = try score.make.vibratoBracket(from: nil, to: to, line: 1)
            #expect(try score.make.crescendo(try NoteStruct(duration: "q")).setDecrescendo(true) is Crescendo)
            expectError("dynamics glyph") { _ = try score.make.textDynamics(TextNoteStruct(text: "bad")) }
        }
    }

    @Test func tabHelpersPreserveNativeOptionsAndValidateSpans() throws {
        try isolated {
            let score = create()
            let options = TabNoteStruct(
                positions: [TabNotePosition(str: 7, fret: "X"), TabNotePosition(str: 2, fret: 12)],
                duration: .quarter, stemDirection: .down
            )
            let from = try score.make.tabNote(options, drawStem: true)
            var toOptions = options
            toOptions.positions = [TabNotePosition(str: 7, fret: 5), TabNotePosition(str: 2, fret: 14)]
            let to = try score.make.tabNote(toOptions)
            #expect(from.getPositions().map { "\($0.str):\($0.fret)" } == ["7:X", "2:12"])
            #expect(from.renderOptions.drawStem)
            #expect(from.getStemDirection() == .down)
            let bend = try score.make.bend([BendPhrase(type: Bend.UP, text: "1/2", width: 25)])
            try score.attach(from, bend, index: 1)
            #expect(bend.getIndex() == 1)
            _ = try score.make.tabTie(TieNotes(firstNote: from, lastNote: to, firstIndexes: [1], lastIndexes: [1]), text: "P")
            _ = try score.make.tabSlide(TieNotes(firstNote: from, lastNote: to), direction: .down)
            _ = try score.make.tabSlide(TieNotes(firstNote: from), direction: .up)
            let grace = try score.make.graceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 2)], duration: .sixteenth))
            let group = try score.make.graceNoteGroup(notes: [grace], slur: true)
            try score.attach(to, group)
            #expect(Factory.getGroup(grace) === group)
            expectError("group") { _ = try score.voiceThrowing([grace], options: EasyScoreVoiceOptions(mode: .soft)) }
            let count = queued(score)
            expectError("position") {
                _ = try score.make.tabNote(TabNoteStruct(positions: [TabNotePosition(str: 0, fret: 2)], duration: .quarter))
            }
            expectError("direction") { _ = try score.make.tabSlide(TieNotes(firstNote: from)) }
            expectError("index") { _ = try score.make.tabTie(TieNotes(firstNote: from, firstIndexes: [2])) }
            let foreignTab = try create().make.tabNote(options)
            expectError("Factory") { _ = try score.make.tabTie(TieNotes(firstNote: foreignTab)) }
            expectError("direction") { _ = try score.make.bend([BendPhrase(type: 5, text: "x")]) }
            #expect(queued(score) == count)
        }
    }

    @Test func staffHelpersAttachOnceWithoutStandaloneDrawing() throws {
        try isolated {
            let score = create()
            let stave = try score.make.stave(x: 10, y: 20, width: 400)
            let count = queued(score)
            let modifiers: [StaveModifier] = [
                try score.make.clef(.bass, size: .small, annotation: .octaveDown),
                try score.make.keySignature("D", cancelKeySpec: "C"),
                try score.make.timeSignature(.meter(7, 8), customPadding: 0),
                try score.make.barline(.double),
                try score.make.repetition(.dc, x: 0, yShift: 0),
                try score.make.volta(.begin, number: "1.", x: 0, yShift: 0),
                try score.make.section("A", x: 0, shiftY: 0, drawRect: false),
                try score.make.tempo(StaveTempoOptions(bpm: 100, duration: .quarter, dots: 1), x: 0, shiftY: 0),
                try score.make.staveText("text", position: .above, shiftX: 0, shiftY: 0),
            ]
            for mark in modifiers {
                try score.attachToStave(stave, mark)
                try score.attachToStave(stave, mark)
                #expect(mark.getStave() === stave)
                #expect(stave.getModifiers().filter { $0 === mark }.count == 1)
                #expect(Factory.getOwner(mark) === score.factory)
                #expect(score.getElement(mark.getAttribute("id") ?? "") === mark)
            }
            #expect(queued(score) == count)
            let other = try score.make.tabStave()
            expectError("already attached") { try score.attachToStave(other, modifiers[0]) }
            expectError("Factory") { try score.attachToStave(stave, try create().make.clef(.treble)) }
            _ = try score.make.connector(topStave: stave, bottomStave: other, type: .single)
            expectError("positive") { _ = try score.make.multiMeasureRest(MultiMeasureRestRenderOptions(numberOfMeasures: 0)) }
            _ = try score.make.multiMeasureRest(MultiMeasureRestRenderOptions(numberOfMeasures: 3)).setStave(stave)
            let inline: [Note] = [
                try score.make.barNote(),
                try score.make.clefNote(),
                try score.make.keySigNote(key: "G"),
                try score.make.timeSigNote(time: .meter(3, 4)),
            ]
            #expect(inline.allSatisfy { $0.shouldIgnoreTicks() })
            let voice = try score.voiceThrowing(inline + (try score.notesThrowing("C4/w")), options: EasyScoreVoiceOptions())
            #expect(voice.getTicksUsed().value() == Double(Tables.RESOLUTION))
            _ = try score.make.glyphNote("\u{E047}", try NoteStruct(duration: "q"))
            _ = try score.make.repeatNote("2", try NoteStruct(duration: "w"))
        }
    }

    // MARK: Composition

    private func measure(_ notation: String, stem: String = "auto", tuplets: [EasyScoreTupletSpec] = [],
                         autoBeam: EasyScoreAutoBeamOptions? = nil) -> EasyScoreVoiceSpec {
        EasyScoreVoiceSpec(notation, stem: stem, tuplets: tuplets, autoBeam: autoBeam)
    }

    @Test func compositionScopesDefaultsValidatesPickupsAndResolvesSpans() throws {
        try isolated {
            let score = create()
            let defaults = score.defaults
            let note = try score.withDefaults(clef: .bass, stem: "down") { try $0.notesThrowing("C3/q")[0] }
            #expect(note.getStemDirection() == .down)
            #expect(score.defaults.clef == defaults.clef && score.defaults.stem == defaults.stem)
            expectError("stop") { _ = try score.withDefaults(clef: .bass) { _ -> Int in throw VexError("App", "stop") } }
            #expect(score.defaults.clef == defaults.clef)
            let result = try score.compose(EasyScoreCompositionSpec(
                staves: [
                    EasyScoreStaveSpec(id: "right", measures: [
                        EasyScoreMeasureSpec(span: VoiceTime(numBeats: 1, beatValue: 4), voices: [measure("C5/q[id=\"pickup\"]")]),
                        EasyScoreMeasureSpec(time: .meter(2, 4), voices: [
                            measure("C5/8[id=\"start\"], D5, E5, F5, G5, A5[id=\"end\"]", stem: "up",
                                    tuplets: [EasyScoreTupletSpec(start: 0, count: 3), EasyScoreTupletSpec(start: 3, count: 3)],
                                    autoBeam: EasyScoreAutoBeamOptions()),
                            measure("G4/h", stem: "down"),
                        ]),
                    ]),
                    EasyScoreStaveSpec(id: "left", clef: .bass, measures: [
                        EasyScoreMeasureSpec(span: VoiceTime(numBeats: 1, beatValue: 4), voices: [measure("C3/q")]),
                        EasyScoreMeasureSpec(time: .meter(2, 4), voices: [measure("C3/h")]),
                    ]),
                ],
                spans: [.curve(from: "start", to: "end")]
            ))
            #expect(result.systems.count == 2)
            #expect(result.voices[1][0].count == 2)
            #expect(result.voices.joined().joined().allSatisfy { $0.isComplete() })
            #expect(result.voices[1][0][0].getTicksUsed().equals(Fraction(Tables.RESOLUTION, 2)))
            #expect(try result.getNote("start") === result.notes[1][0][0][0])
            #expect(result.spans[0] is Curve)
            #expect(score.defaults.clef == defaults.clef && score.defaults.stem == defaults.stem)
        }
    }

    @Test func compositionFailuresRollBackAndEnforceSharedState() throws {
        try isolated {
            let score = create()
            let original = try score.notesThrowing("A4/q[id=\"keep\"]")[0]
            let count = queued(score)
            let specs: [EasyScoreCompositionSpec] = [
                EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "a", measures: [
                    EasyScoreMeasureSpec(voices: [measure("C4/q[id=\"new\"]")]),
                ])]),
                EasyScoreCompositionSpec(
                    staves: [EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [measure("C4/w[id=\"new\"]")])])],
                    spans: [.tie(from: "new", to: "missing")]
                ),
                EasyScoreCompositionSpec(staves: [
                    EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [measure("C4/w")])]),
                    EasyScoreStaveSpec(id: "b", measures: []),
                ]),
                EasyScoreCompositionSpec(staves: [
                    EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [measure("C4/w")])]),
                    EasyScoreStaveSpec(id: "b", measures: [EasyScoreMeasureSpec(time: .meter(3, 4), voices: [measure("C3/h.")])]),
                ]),
                EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [
                    EasyScoreVoiceSpec(notes: [.notation("C4/h"), .change(EasyScoreStaffState(key: "G")), .notation("C4/h")]),
                    measure("C4/w"),
                ])])]),
                EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "a", measures: [EasyScoreMeasureSpec(voices: [
                    EasyScoreVoiceSpec(notes: [.note(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "w"), stave: "missing")]),
                ])])]),
            ]
            for spec in specs {
                expectAnyError { _ = try score.compose(spec) }
                #expect(queued(score) == count)
                #expect(score.getElement("new") == nil)
                #expect(try score.getNote("keep") === original)
                #expect(score.factory.getSheets().isEmpty)
            }
            let native = try score.make.note(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "w"))
            expectAnyError {
                _ = try score.compose(EasyScoreCompositionSpec(
                    staves: [EasyScoreStaveSpec(id: "a", measures: [
                        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [.tickable(native)])]),
                    ])],
                    spans: [.tie(from: "missing")]
                ))
            }
            #expect(native.voice == nil)
            #expect(native.getStave() == nil)
            let result = try score.compose(EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "a", measures: [
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [.tickable(native)])]),
            ])]))
            #expect(result.notes[0][0][0][0] === native)
        }
    }

    private func marks(_ note: Tickable) -> [String] {
        (note as? Note)?.getModifiers().compactMap { ($0 as? Accidental)?.type } ?? []
    }

    @Test func keyAwareCompositionPreservesLiteralPitchesAndExplicitMarks() throws {
        try isolated {
            let score = create()
            let result = try score.compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "a", key: "G", measures: [
                    EasyScoreMeasureSpec(voices: [measure("F#4/q, F#4, F4, F4")]),
                    EasyScoreMeasureSpec(voices: [measure("F#4/q, F4, F#4, F4"), measure("F4/q, F#4, F4, F#4")]),
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                        .notation("F#4/h"), .change(EasyScoreStaffState(key: "C")), .notation("F#4/q, F#4"),
                    ])]),
                ])],
                accidentals: .keyAware
            ))
            #expect(result.notes[0][0][0].map(marks) == [[], [], ["n"], []])
            #expect((result.notes[0][0][0][0] as? Note)?.getKeys()[0].lowercased() == "f#/4")
            #expect(result.notes[1][0][0].map(marks) == [["#"], ["n"], ["#"], ["n"]])
            #expect(result.notes[1][0][1].map(marks) == [["n"], ["#"], ["n"], ["#"]])
            #expect(result.notes[2][0][0].filter { !$0.shouldIgnoreTicks() }.map(marks) == [[], ["#"], []])
            let caution = create(EasyScoreOptions(commitHooks: [{ options, note, _ in
                if options["id"] == "caution" { _ = (note.getModifiers()[0] as? Accidental)?.setAsCautionary() }
                try note.setAttributeThrowing("id", options["id"] ?? note.getAttribute("id"))
            }]))
            let preserved = try caution.compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "a", key: "G", measures: [
                    EasyScoreMeasureSpec(voices: [measure("F#4/q[id=\"caution\"], F++4, F4, F4")]),
                ])],
                accidentals: .keyAware
            ))
            let notes = preserved.notes[0][0][0]
            #expect((notes[0] as? Note)?.getModifiers().compactMap { $0 as? Accidental }.first?.isCautionary() == true)
            #expect(notes.map(marks) == [["#"], ["++"], ["n"], []])
            let rational = try create().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "a", measures: [
                    EasyScoreMeasureSpec(time: .meter(2, 4), voices: [
                        measure("F#4/8, F4, F#4, F4, F#4, F4",
                                tuplets: [EasyScoreTupletSpec(start: 0, count: 3), EasyScoreTupletSpec(start: 3, count: 3)]),
                        measure("C4/q, F4"),
                    ]),
                ])],
                accidentals: .keyAware
            ))
            #expect(marks(rational.notes[0][0][1][1]) == ["n"])
        }
    }

    @Test func compositionSpansAndSignatureRepetitionRequireExplicitPolicies() throws {
        try isolated {
            let spec = EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "a", measures: [
                    EasyScoreMeasureSpec(voices: [measure("C4/w[id=\"first\"]")]),
                    EasyScoreMeasureSpec(voices: [measure("C4/w[id=\"last\"]")]),
                ])],
                spans: [.tie(from: "first", to: "last")]
            )
            expectError("manual segmentation") { _ = try create().compose(spec) }
            var manualSpec = spec
            manualSpec.crossMeasureSpans = .manual
            manualSpec.signatures = .everyMeasure
            let manual = try create().compose(manualSpec)
            #expect(manual.diagnostics.count == 1)
            #expect(manual.diagnostics[0].code == .manualSpan)
            #expect(manual.staves.allSatisfy { $0[0].getModifiers().contains { $0 is Clef } })
        }
    }

    @Test func compositionKeepsCrossStaffPlacementAndTargetAccidentals() throws {
        try isolated {
            let score = create()
            let result = try score.compose(EasyScoreCompositionSpec(
                staves: [
                    EasyScoreStaveSpec(id: "upper", measures: [EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                        .note(try StaveNoteStruct(parsingKeys: ["f/3"], duration: "w", clef: .bass), id: "cross", stave: "lower"),
                    ])])]),
                    EasyScoreStaveSpec(id: "lower", clef: .bass, key: "G", measures: [EasyScoreMeasureSpec(voices: [measure("G2/w")])]),
                ],
                accidentals: .keyAware
            ))
            let note = try result.getNote("cross")
            #expect(note.getStave() === result.staves[0][1])
            #expect(marks(note) == ["n"])
            try result.sheet.format()
            try result.sheet.setWidth(220).format()
            #expect(note.getStave() === result.staves[0][1])
            #expect(note.getYs()[0].isFinite)
        }
    }

    @Test func compositionCarriesClefStateAndCancelsInlineKeys() throws {
        try isolated {
            let score = create()
            let result = try score.compose(EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(
                id: "bass", clef: .bass, key: "G", measures: [
                    EasyScoreMeasureSpec(voices: [measure("G3/w")]),
                    EasyScoreMeasureSpec(key: "D", voices: [EasyScoreVoiceSpec(notes: [
                        .notation("D3/h"), .change(EasyScoreStaffState(clef: .treble, key: "C")), .notation("C5/h"),
                    ])]),
                ]
            )]))
            #expect(result.staves[0][0].getClef() == .bass)
            #expect(result.staves[1][0].getClef() == .bass)
            let inline = try #require(result.notes[1][0][0].first { $0 is KeySigNote } as? KeySigNote)
            inline.preFormat()
            #expect(inline.keySignature.accList.count == 2, "D major is cancelled with two naturals")
            let native = KeySignature(keySpec: "C", cancelKeySpec: "D")
            native.setStave(Stave(x: 0, y: 0, width: 200).addClef(.treble))
            native.format()
            #expect(inline.keySignature.accList.map { "\($0.type)\($0.line)" } == native.accList.map { "\($0.type)\($0.line)" },
                    "inline cancellation follows the new clef")
            let attached = try score.make.stave()
            try score.attachToStave(attached, try score.make.clef(.alto))
            #expect(attached.getClef() == .alto)
        }
    }

    @Test func nonPitchedTimedNotesAcceptModifiersAtTheirSingleIndex() throws {
        try isolated {
            let score = create()
            let note = try score.make.glyphNote("\u{E047}", try NoteStruct(duration: "w"))
            let label = try score.make.annotation(text: "sim.")
            try score.attach(note, label)
            #expect(label.getNote() === note)
            #expect(label.getIndex() == 0)
            expectError("index") { try score.attach(note, try score.make.annotation(text: "bad"), index: 1) }
        }
    }

    @Test func typedGraceNotesRetainExplicitStemDirection() throws {
        try isolated {
            let grace = try create().make.graceNote(try GraceNoteStruct(parsingKeys: ["c/4"], duration: "16", stemDirection: .down))
            #expect(grace.getStemDirection() == .down)
            #expect(!grace.isAutoStem())
        }
    }
}

// MARK: - EasyScore rendering (easyscore-rendering-tests.mjs)

@Suite("Upstream 5.2.0 port: EasyScore rendering")
struct Upstream52EasyScoreRenderingTests {
    /// SVG markup without the element IDs, which depend on construction order.
    private func markup(_ ctx: SVGRenderContext) -> String {
        ctx.getSVG().replacingOccurrences(of: #" id="[^"]*""#, with: "", options: .regularExpression)
    }

    private func geometry(_ notes: [StemmableNote]) -> [String] {
        notes.map { note in
            let box = note.getBoundingBox()
            return "\(note.getAbsoluteX()) \(note.getYs()) \(note.getStemDirection()) \(note.getTicks().value()) "
                + "\(box?.x ?? 0) \(box?.y ?? 0) \(box?.w ?? 0) \(box?.h ?? 0)"
        }
    }

    @Test func firstEasyScoreExampleMatchesNativeRendering() throws {
        try isolated {
            let ink = "#24312c"
            // Native construction.
            let nativeContext = SVGRenderContext(width: 500, height: 240)
            let factory = Factory(options: FactoryOptions(width: 500, height: 240))
            _ = factory.setContext(nativeContext)
            factory.setStyle(ElementStyle(fillStyle: ink, strokeStyle: ink))
            let nativeNotes = try [["c/4", "e/4", "g/4"], ["c/4", "f/4", "a/4"]].map { keys in
                factory.StaveNote(try StaveNoteStruct(parsingKeys: keys, duration: "h", autoStem: true, clef: .treble))
            }
            _ = nativeNotes[0].addModifier(factory.Annotation(text: "dolce", vJustify: .top), index: 0)
            _ = factory.StaveTie(notes: TieNotes(firstNote: nativeNotes[0], lastNote: nativeNotes[1]))
            let nativeVoice = factory.Voice(time: VoiceTime()).addTickables(nativeNotes)
            factory.System(options: SystemOptions(x: 20, width: 460, y: 70))
                .addStave(SystemStave(voices: [nativeVoice])).addClef(.treble).addTimeSignature(.meter(4, 4))
            try factory.draw(retain: true)

            // EasyScore construction (tools/easyscore-example.mjs).
            let sharedContext = SVGRenderContext(width: 500, height: 240)
            let score = EasyScore.create(options: FactoryOptions(width: 500, height: 240))
            score.setContext(sharedContext)
            score.setStyle(ElementStyle(fillStyle: ink, strokeStyle: ink))
            let notes = try score.notesThrowing("(C4 E4 G4)/h, (C4 F4 A4)")
            let annotation = try score.make.annotation(text: "dolce", vJustify: .top)
            try score.attach(notes[0], annotation, index: 0)
            _ = try score.make.tie(from: notes[0], to: notes[1], firstIndexes: [0], lastIndexes: [0])
            let voice = try score.voiceThrowing(notes, options: EasyScoreVoiceOptions(time: VoiceTime(), mode: .strict))
            try score.system(SystemOptions(x: 20, width: 460, y: 70))
                .addStave(SystemStave(voices: [voice])).addClef(.treble).addTimeSignature(.meter(4, 4))
            try score.draw(retain: true)

            #expect(geometry(notes) == geometry(nativeNotes), "native and EasyScore geometry match")
            #expect(markup(sharedContext) == markup(nativeContext), "native and EasyScore output match")
            #expect(throws: EasyScoreError.self) { _ = try score.notesThrowing("C4/q, invalid") }

            // Theme round trip on a retained score preserves output.
            let original = markup(sharedContext)
            for color in ["#b74632", ink] {
                sharedContext.clear()
                score.setStyle(ElementStyle(fillStyle: color, strokeStyle: color))
                try score.draw(retain: true)
            }
            #expect(markup(sharedContext) == original, "theme round trip preserves output")
        }
    }

    @Test func adoptedNativeNotationMatchesRenderingAndRetainedRedraw() throws {
        try isolated {
            let ink = "#24312c"
            let nativeContext = SVGRenderContext(width: 500, height: 240)
            let factory = Factory(options: FactoryOptions(width: 500, height: 240))
            _ = factory.setContext(nativeContext)
            factory.setStyle(ElementStyle(fillStyle: ink, strokeStyle: ink))
            let nativeNotes = try [("c/4", "h"), ("c/4", "q"), ("e/4", "q")].map { key, duration in
                factory.StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: duration, autoStem: true))
            }
            _ = nativeNotes[0].addModifier(factory.Annotation(text: "dolce", vJustify: .top), index: 0)
            _ = factory.StaveTie(notes: TieNotes(firstNote: nativeNotes[0], lastNote: nativeNotes[1]))
            _ = factory.Curve(from: nativeNotes[1], to: nativeNotes[2])
            let nativeVoice = factory.Voice(time: VoiceTime()).addTickables(nativeNotes)
            factory.System(options: SystemOptions(x: 20, width: 460, y: 70))
                .addStave(SystemStave(voices: [nativeVoice])).addClef(.treble).addTimeSignature(.meter(4, 4))
            try factory.draw(retain: true)

            // tools/easyscore-references-example.mjs
            let context = SVGRenderContext(width: 500, height: 240)
            let score = EasyScore.create(options: FactoryOptions(width: 500, height: 240))
            score.setContext(context)
            score.setStyle(ElementStyle(fillStyle: ink, strokeStyle: ink))
            var notes: [Note] = try score.notesThrowing("C4/h[id=\"start\"], C4/q[id=\"end\"]")
            let native = try score.adopt(StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "q", autoStem: true)), role: .note)
            _ = native.setAttribute("id", "native")
            notes.append(native)
            // Upstream subclasses Annotation; the Swift Annotation is final, so configure a native one.
            let label = try score.adopt(Annotation("dolce").setVerticalJustification(.top), role: .modifier)
            try score.attach(try score.getNote("start"), label)
            _ = try score.make.tie(from: try score.getNote("start"), to: try score.getNote("end"))
            let curve = try score.adopt(Curve(from: try score.getNote("end"), to: native), role: .drawable)
            let voice = try score.voiceThrowing(notes, options: EasyScoreVoiceOptions(time: VoiceTime()))
            try score.system(SystemOptions(x: 20, width: 460, y: 70))
                .addStave(SystemStave(voices: [voice])).addClef(.treble).addTimeSignature(.meter(4, 4))
            try score.draw(retain: true)
            #expect(markup(context) == markup(nativeContext), "native extensions preserve rendered output")

            // Repeated adoption and attachment do not add drawing owners.
            let original = markup(context)
            try score.adopt(curve, role: .drawable)
            try score.adopt(native, role: .note)
            try score.adopt(label, role: .modifier)
            try score.attach(try score.getNote("start"), label)
            context.clear()
            try score.draw(retain: true)
            #expect(try score.getNote("start") === notes[0])
            #expect(score.getSource(notes[0]) != nil)
            #expect(markup(context) == original, "retained redraw is identical")

            context.clear()
            try score.draw() // Default drawing clears queues but preserves references for inspection.
            #expect(try score.getNote("start") === notes[0])
            score.reset()
            #expect(score.getElement("start") == nil)
            #expect(EasyScore.getSource(notes[0]) == nil)
        }
    }
}
