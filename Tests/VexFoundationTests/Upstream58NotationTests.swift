// Logic-level tests for the notation behaviors ported from VexFlow 5.7.0 -> 5.8.0:
// bounded beam slope fitting, French beams, double-octave clefs, editorial accidentals,
// shared accidentals at unisons, parenthesized turns and pitched trills.
// Ported from the 5.8.0 asserts in tests/node/engraving-layout-tests.mjs, tests/accidental_tests.ts,
// tests/clef_tests.ts and tests/ornament_tests.ts. Upstream monkey-patches draw calls to count glyphs.
// These tests read the SVG output or the Swift state instead.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

/// `factory()` of the node tests.
private func factory(width: Double = 800, height: Double = 720) -> (f: Factory, ctx: SVGRenderContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = SVGRenderContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

/// One `<text>` element of the SVG output.
private struct SVGText: Equatable {
    var text: String
    var x: Double
    var y: Double
}

/// Read every `<text>` element of an SVG string, in document order.
private func svgTexts(_ svg: String) -> [SVGText] {
    let pattern = try! NSRegularExpression(pattern: "<text([^>]*)>([^<]*)</text>")
    let attribute = { (attrs: String, name: String) -> Double in
        guard let regex = try? NSRegularExpression(pattern: "\\s\(name)=\"([^\"]*)\""),
              let match = regex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
              let range = Range(match.range(at: 1), in: attrs) else { return .nan }
        return Double(attrs[range]) ?? .nan
    }
    return pattern.matches(in: svg, range: NSRange(svg.startIndex..., in: svg)).compactMap { match in
        guard let a = Range(match.range(at: 1), in: svg), let t = Range(match.range(at: 2), in: svg) else { return nil }
        let attrs = String(svg[a])
        return SVGText(text: String(svg[t]), x: attribute(attrs, "x"), y: attribute(attrs, "y"))
    }
}

/// The SVG source of the group with the element id (a group without nested groups).
private func svgGroup(_ svg: String, id: String) -> String? {
    guard let start = svg.range(of: "id=\"vf-\(id)\"") else { return nil }
    guard let end = svg.range(of: "</g>", range: start.upperBound..<svg.endIndex) else { return nil }
    return String(svg[start.lowerBound..<end.lowerBound])
}

private func occurrences(_ text: String, _ needle: String) -> Int {
    text.components(separatedBy: needle).count - 1
}

// MARK: - Beams

@Suite("Upstream 5.8.0 port: Notation")
struct Upstream58NotationTests {

    /// engraving-layout-tests.mjs: 'beam slope options are validated before reading note geometry'.
    @Test func beamSlopeOptionsAreValidatedBeforeReadingNoteGeometry() throws {
        try isolated {
            let (f, _) = factory()
            let beam = try f.BeamThrowing(notes: f.EasyScore().notes("C4/8, E4", options: ["stem": "up"]))
            let defaults = beam.renderOptions
            // Swift `slopeIterations` is an `Int`: the fractional, NaN and infinite upstream cases cannot occur.
            for iterations in [0, -1, 1001, Int.max] {
                beam.renderOptions = defaults
                beam.renderOptions.slopeIterations = iterations
                #expect(throws: BeamError.badSlopeIterations) { try beam.calculateSlope() }
            }
            let bounds: [(Double, Double)] = [
                (.nan, defaults.maxSlope), (-.infinity, defaults.maxSlope), (defaults.minSlope, .infinity), (0.2, 0.1),
            ]
            for (minSlope, maxSlope) in bounds {
                beam.renderOptions = defaults
                beam.renderOptions.minSlope = minSlope
                beam.renderOptions.maxSlope = maxSlope
                #expect(throws: BeamError.badSlopeBounds) { try beam.calculateSlope() }
            }
            // draw() reports the error of the postFormat() fit.
            beam.renderOptions = defaults
            beam.renderOptions.slopeIterations = 0
            beam.postFormat()
            #expect(beam.slopeError as? BeamError == .badSlopeIterations)
            #expect(throws: BeamError.badSlopeIterations) { try beam.draw() }
        }
    }

    /// engraving-layout-tests.mjs: 'beam fitting includes both endpoints, honors fixed slopes, and preserves the default fit'.
    @Test func beamFittingIncludesBothEndpointsAndHonorsFixedSlopes() throws {
        try isolated {
            let ascending = "C4/8, F4, D5, G5"
            let descending = "D6/8, F5, D4, G3"
            func fit(_ pitches: String, _ settings: (inout BeamRenderOptions) -> Void = { _ in }) throws -> Double {
                let (f, _) = factory()
                let score = f.EasyScore()
                let notes = score.notes(pitches, options: ["stem": "up"])
                let beam = try f.BeamThrowing(notes: notes)
                settings(&beam.renderOptions)
                let system = f.System(options: SystemOptions(width: 350, y: 60))
                _ = system.addStave(SystemStave(voices: [score.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))]))
                    .addClef(.treble)
                system.format()
                beam.postFormat()
                return beam.slope
            }

            // These two steep contours favored opposite endpoints of the original default range.
            let up = try fit(ascending)
            let down = try fit(descending)
            #expect(up == -0.25)
            #expect(down == 0.25)
            for slopeIterations in [1, 3, 1000] {
                let bounds = { (o: inout BeamRenderOptions) in
                    o.minSlope = -0.1
                    o.maxSlope = 0.2
                    o.slopeIterations = slopeIterations
                }
                let boundedUp = try fit(ascending, bounds)
                let boundedDown = try fit(descending, bounds)
                #expect(boundedUp == -0.1)
                #expect(boundedDown == 0.2)
            }
            let fixed = try fit(ascending) { $0.minSlope = 0.125; $0.maxSlope = 0.125 }
            #expect(fixed == 0.125)
        }
    }

    /// engraving-layout-tests.mjs: 'default slope fitting preserves the chosen angle when several candidates have the same cost'.
    @Test func defaultSlopeFittingPreservesTheChosenAngleOnACostPlateau() throws {
        try isolated {
            let (f, _) = factory()
            let notes = f.EasyScore().notes("G4/8, F4, E4, C4", options: ["stem": "up"])
            let beam = try f.BeamThrowing(notes: notes)
            let stave = f.Stave(y: 65)
            // Four equally spaced attacks put neighboring slopes on the same cost plateau.
            // On a plateau, the last bits of the stem x decide the tie. Upstream measures the
            // Bravura notehead with node-canvas: the first stem is at x = 58.0498046875. The
            // Swift metrics give 58.05. Move the attacks by that difference to compare the
            // same floating-point inputs.
            var contexts: [TickContext] = []
            for (index, note) in notes.enumerated() {
                _ = note.setStave(stave)
                contexts.append(TickContext().addTickable(note).preFormat().setX(30 + 30 * Double(index)))
            }
            let shift = 58.0498046875 - notes[0].getStemX()
            for (index, context) in contexts.enumerated() { _ = context.setX(30 + 30 * Double(index) + shift) }
            #expect(notes[0].getStemX() == 58.0498046875)
            try beam.calculateSlope()
            #expect(abs(beam.slope - 0.15) < 1e-12)
        }
    }

    /// The candidates include both bounds exactly and stay inside the range.
    @Test func beamSlopeCandidatesIncludeExactEndpoints() {
        let slopes = beamSlopes(-0.25, 0.25, 20)
        #expect(slopes.count == 21)
        #expect(slopes.first == -0.25)
        #expect(slopes.last == 0.25)
        #expect(zip(slopes, slopes.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(beamSlopes(0.125, 0.125, 20) == [0.125])
        #expect(beamSlopes(-0.1, 0.2, 1) == [-0.1, 0.2])
        // A narrow range that rounds away the step still ends at the upper bound.
        let narrow = beamSlopes(1, 1 + 4 * Double.ulpOfOne, 1000)
        #expect(narrow.first == 1 && narrow.last == 1 + 4 * Double.ulpOfOne)
        #expect(narrow.allSatisfy { $0 >= 1 && $0 <= 1 + 4 * Double.ulpOfOne })
    }

    /// engraving-layout-tests.mjs: 'French beaming leaves the gap open only at interior stems on uninterrupted strips'.
    @Test func frenchBeamingLeavesTheGapOpenOnlyAtInteriorStems() throws {
        try isolated {
            struct Fit { var insets: [Double]; var width: Double; var ticks: Double }
            func fit(
                _ stem: String, _ pitches: String, french: Bool = false, breaks: [Int] = [],
                feathered: FeatheredBeamDirection? = nil, automatic: Bool = false
            ) throws -> Fit {
                let (f, _) = factory()
                let es = f.EasyScore()
                let notes = es.notes(pitches, options: ["stem": stem])
                let beam = automatic
                    ? try es.autoBeam(notes, options: EasyScoreAutoBeamOptions(frenchBeams: french))[0]
                    : try f.BeamThrowing(notes: notes, secondaryBeamBreaks: breaks, feathered: feathered, frenchBeams: french)
                let voice = es.voice(notes, options: EasyScoreVoiceOptions(mode: .soft))
                let system = f.System(options: SystemOptions(width: 360, y: 65))
                _ = system.addStave(SystemStave(voices: [voice]))
                system.format()
                beam.postFormat()
                // The logical primary fit stays in place. Compare the actual drawn tip against that edge.
                let insets = try notes.map { note -> Double in
                    let topY = note.getStemExtents().topY
                    let segment = try #require((note as? StaveNote)?.getStemSegment())
                    let inset = (segment.tipY - topY) * note.getStemDirection().signDouble - Stem.WIDTH / 2
                    return (inset * 1000).rounded() / 1000
                }
                return Fit(insets: insets, width: beam.renderOptions.beamWidth, ticks: voice.getTicksUsed().value())
            }

            for direction in ["up", "down"] {
                let pitches = "G4/16, A4, B4, C5"
                let automatic = try fit(direction, pitches, french: true, automatic: true)
                let width = automatic.width
                #expect(automatic.ticks == Double(Tables.RESOLUTION / 4))
                #expect(automatic.insets == [0, 1.5 * width, 1.5 * width, 0])
                #expect(try fit(direction, pitches).insets == [0, 0, 0, 0])
                #expect(try fit(direction, "G4/8, A4, B4, C5", french: true).insets == [0, 0, 0, 0])
                #expect(try fit(direction, pitches, french: true, breaks: [1]).insets == [0, 0, 0, 0])

                // A hook still hangs from its stem, even when the next strip runs through the note.
                let mixed = try fit(direction, "G4/16, A4/32, B4/16, C5/8", french: true)
                #expect(mixed.insets == [0, 1.5 * width, 0, 0])
                let fan = try fit(direction, pitches, french: true, feathered: .right)
                #expect(fan.insets[1] > 0 && fan.insets[1] < fan.insets[2] && fan.insets[2] < 1.5 * width)
            }
        }
    }

    @Test func stemBeamInsetMovesTheDrawnTip() {
        let stem = Stem(options: StemOptions(stemDirection: .up))
        stem.adjustHeightForBeam()
        let plain = stem.getSegment().tipY
        stem.adjustHeightForBeam(4)
        #expect(abs(stem.getSegment().tipY - (plain + 4)) < 1e-9)
    }

    // MARK: - Accidentals

    /// accidental_tests.ts 'Square editorial enclosures'.
    @Test func squareEditorialEnclosures() throws {
        try isolated {
            let (f, ctx) = factory(width: 520, height: 250)
            for (row, width) in [475.0, 275.0].enumerated() {
                let stave = f.Stave(x: 10, y: 5 + 110 * Double(row), width: width).addClef(.treble)
                let sharp = { f.Accidental(type: .sharp) }
                let plain = sharp()
                let round = sharp().setAsCautionary()
                let square = sharp().setAsCautionary(.brackets)
                let natural = f.Accidental(type: .natural).setAsCautionary(.brackets)
                let flat = f.Accidental(type: .flat).setAsCautionary(.brackets)
                func note(_ keys: [String]) throws -> StaveNote {
                    f.StaveNote(try StaveNoteStruct(parsingKeys: keys, duration: "q"))
                }
                let chord = try note(["g/4", "b/4"]).addModifier(plain, index: 0).addModifier(natural, index: 1)
                let notes: [StaveNote] = [
                    try note(["f/4"]).addModifier(round, index: 0),
                    try note(["f/4"]).addModifier(square, index: 0),
                    try note(["b/4"]).addModifier(flat, index: 0),
                    chord,
                ]
                let voice = f.Voice().addTickables(notes)
                _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                _ = voice.setStave(stave)
                notes.forEach { _ = $0.setStave(stave) }
                #expect(round.getText() == Glyphs.accidentalParensLeft + Glyphs.accidentalSharp + Glyphs.accidentalParensRight)
                for (sign, glyph) in [(square, Glyphs.accidentalSharp), (flat, Glyphs.accidentalFlat), (natural, Glyphs.accidentalNatural)] {
                    #expect(sign.getText() == Glyphs.accidentalBracketLeft + glyph + Glyphs.accidentalBracketRight)
                }
                #expect(natural.type == "n", "preserves the accidental type")
                #expect(square.enclosure == .brackets && round.enclosure == .parentheses)
                #expect(notes[0].getYs()[0] == notes[1].getYs()[0], "enclosure preserves staff position")
                let left = try plain.getInkBounds()
                let right = try natural.getInkBounds()
                #expect(left.x + left.w < right.x || right.x + right.w < left.x, "the two chord signs have a gap")
                #expect(max(left.x + left.w, right.x + right.w) < chord.getNoteHeadBeginX(), "both signs clear the heads")
            }
            try f.draw()
            let svg = ctx.getSVG()
            #expect(occurrences(svg, Glyphs.accidentalBracketLeft) == 6)
            #expect(occurrences(svg, Glyphs.accidentalParensLeft) == 2)
        }
    }

    /// engraving-layout-tests.mjs: 'key-aware accidentals share one sign only at the same printed unison head'.
    @Test func keyAwareAccidentalsShareOneSignOnlyAtTheSamePrintedUnisonHead() throws {
        try isolated {
            func voice(_ id: String, _ key: String = "e#/5") throws -> EasyScoreVoiceSpec {
                EasyScoreVoiceSpec(notes: [.note(
                    try StaveNoteStruct(parsingKeys: [key], duration: "q", stemDirection: id == "upper" ? .up : .down),
                    id: id
                )])
            }
            struct Rendered { var drawn: [Accidental]; var notes: [StaveNote]; var marks: [Accidental]; var svg: String }
            func render(
                _ parts: [[EasyScoreVoiceSpec]], _ prepare: ([StaveNote], [Accidental]) -> Void = { _, _ in }
            ) throws -> Rendered {
                let (f, ctx) = factory()
                let spec = EasyScoreCompositionSpec(
                    staves: parts.enumerated().map { i, voices in
                        EasyScoreStaveSpec(
                            id: "staff\(i)", key: "Bm", time: .meter(1, 4),
                            measures: [EasyScoreMeasureSpec(voices: voices)]
                        )
                    },
                    accidentals: .keyAware,
                    continuous: ContinuousOptions()
                )
                let score = try f.EasyScore().compose(spec)
                let notes = score.notes[0].flatMap { $0.flatMap { $0 } }.compactMap { $0 as? StaveNote }
                let marks = notes.flatMap { $0.getModifiers().compactMap { $0 as? Accidental } }
                prepare(notes, marks)
                var last: [ObjectIdentifier]?
                var drawn: [Accidental] = []
                var svg = ""
                for width in [350.0, 180.0, 350.0] {
                    ctx.clear()
                    _ = try score.sheet.setWidth(width)
                    try f.draw(retain: true)
                    drawn = marks.filter { !$0.isShared }
                    svg = ctx.getSVG()
                    let ids = drawn.map(ObjectIdentifier.init)
                    if let last { #expect(ids == last) }
                    last = ids
                }
                return Rendered(drawn: drawn, notes: notes, marks: marks, svg: svg)
            }
            // The two B minor signatures are not part of the count.
            func sharps(_ r: Rendered, staves: Int) -> Int {
                occurrences(r.svg, Glyphs.accidentalSharp) - 2 * staves
            }
            let both = [try voice("upper"), try voice("lower")]
            let shared = try render([both])
            #expect(shared.drawn.count == 1)
            #expect(sharps(shared, staves: 1) == 1)
            let inks = try shared.marks.map { try $0.getInkBounds() }
            #expect(inks == [try shared.drawn[0].getInkBounds(), try shared.drawn[0].getInkBounds()])
            #expect(shared.marks.allSatisfy { $0.getBoundingBox() == shared.drawn[0].getBoundingBox() })
            #expect(shared.notes.map { $0.getKeys() } == [["e#/5"], ["e#/5"]])
            #expect(shared.notes.map { $0.getStemDirection() } == [.up, .down])
            #expect(shared.notes.map { $0.getTicks().value() } == [Double(Tables.RESOLUTION / 4), Double(Tables.RESOLUTION / 4)])
            for v in both { #expect(try render([[v]]).drawn.count == 1) }
            #expect(try render([[try voice("upper"), try voice("lower", "eb/5")]]).drawn.count == 2)
            let separateStaves = try render(both.map { [$0] })
            #expect(separateStaves.drawn.count == 2)
            #expect(sharps(separateStaves, staves: 2) == 2)
            #expect(try render([both]) { notes, _ in _ = notes[1].noteHeads[0].setXShift(12) }.drawn.count == 2)
            let caution = try render([both]) { _, marks in _ = marks[1].setAsCautionary() }
            #expect(caution.drawn.map(ObjectIdentifier.init) == [ObjectIdentifier(caution.marks[1])])
            #expect(caution.drawn[0].isCautionary())
            #expect(try render([both]) { _, marks in marks.forEach { _ = $0.setAsCautionary() } }.drawn.count == 2)
            let unison = Flow.UNISON
            defer { Flow.UNISON = unison }
            Flow.UNISON = false
            let separate = try render([both])
            #expect(separate.notes[0].getNoteHeadBeginX() != separate.notes[1].getNoteHeadBeginX())
            #expect(separate.drawn.count == 2)
        }
    }

    // MARK: - Clefs

    /// clef_tests.ts 'Double-octave clefs'.
    @Test func doubleOctaveClefs() throws {
        try isolated {
            let (f, ctx) = factory(width: 620, height: 270)
            let forms: [(ClefName, ClefAnnotation, String)] = [
                (.treble, .doubleOctaveUp, Glyphs.gClef15ma),
                (.treble, .doubleOctaveDown, Glyphs.gClef15mb),
                (.bass, .doubleOctaveUp, Glyphs.fClef15ma),
                (.bass, .doubleOctaveDown, Glyphs.fClef15mb),
            ]
            for (index, form) in forms.enumerated() {
                let (type, annotation, glyph) = form
                let stave = f.Stave(x: 15 + 290 * Double(index % 2), y: 12 + 120 * Double(index / 2), width: 270)
                    .addClef(type, size: .default, annotation: annotation)
                let start = try #require(stave.getModifiers(category: Clef.category).first as? Clef)
                let inline = f.ClefNote(type: type, size: .small, annotation: annotation)
                let key = type == .treble ? "g/4" : "f/3"
                let quarter = f.StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: "q", clef: type))
                let voice = f.Voice(time: VoiceTime(numBeats: 1, beatValue: 4)).addTickables([inline, quarter])
                _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                // Both clefs need their final drawn position for the bounds check.
                try stave.draw()
                try voice.draw(context: ctx, stave: stave)
                let small = inline.getClef()
                for clef in [start, small] {
                    #expect(clef.code == glyph, "selects the complete double-octave glyph")
                    #expect(try clef.getGlyphY() == stave.getYForLine(Clef.types[type]!.line), "retains the ordinary anchor")
                }
                let ink = try small.getInkBounds()
                let box = try #require(inline.getBoundingBox())
                let startInk = try start.getInkBounds()
                #expect(ink.w > 0 && ink.h > 0 && ink.h < startInk.h, "inline glyph is visibly smaller")
                #expect(
                    box.x <= ink.x + 1 && box.x + box.w >= ink.x + ink.w - 1
                        && box.y <= ink.y + 1 && box.y + box.h >= ink.y + ink.h - 1,
                    "measured box encloses the ink"
                )
                #expect(ink.x + ink.w < quarter.getNoteHeadBeginX(), "\(type) \(annotation) clears the next notehead")
                // The stave clef reports its ink as its bounding box.
                #expect(start.getBoundingBox() == startInk)
            }
            #expect(Clef(parsing: "bass", annotation: "15mb")?.code == Glyphs.fClef15mb)
            // Clefs without an octave form keep their glyph.
            #expect(Clef(type: .alto, annotation: .doubleOctaveUp).code == Glyphs.cClef)
        }
    }

    // MARK: - Ornaments

    /// ornament_tests.ts 'Parenthesized editorial turn'.
    @Test func parenthesizedEditorialTurn() throws {
        try isolated {
            let (f, ctx) = factory(width: 300, height: 155)
            let stave = f.Stave(x: 10, y: 30, width: 280).addClef(.treble)
            let notes = try (0..<2).map { _ in
                f.StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q", stemDirection: .down))
            }
            let bare = Ornament("turn")
            let marked = f.Ornament("turn", parenthesized: true)
            _ = notes[0].addModifier(bare, index: 0)
            _ = notes[1].addModifier(marked, index: 0)
            let voice = f.Voice(time: VoiceTime(numBeats: 2, beatValue: 4)).addTickables(notes)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)

            let wanted = [Glyphs.ornamentTurn, Glyphs.noteheadParenthesisLeft, Glyphs.noteheadParenthesisRight]
            func draw() throws -> [SVGText] {
                ctx.clear()
                try stave.draw()
                try voice.draw(context: ctx, stave: stave)
                return svgTexts(ctx.getSVG()).filter { wanted.contains($0.text) }
            }
            let glyphs = try draw()
            #expect(glyphs.map(\.text) == [
                Glyphs.ornamentTurn, Glyphs.ornamentTurn, Glyphs.noteheadParenthesisLeft, Glyphs.noteheadParenthesisRight,
            ], "one bare turn and one enclosed turn")
            let boxes = glyphs.dropFirst().map {
                VexElement().setFont(marked.fontInfo).setText($0.text).getTextInk($0.x, $0.y)
            }
            if boxes.count == 3 {
                var (turn, left, right) = (boxes[0], boxes[1], boxes[2])
                let box = try #require(marked.getBoundingBox())
                #expect(left.x + left.w < turn.x && turn.x + turn.w < right.x, "both parentheses clear the turn")
                #expect(box.y + box.h < notes[1].getYs()[0], "enclosure stays above the written G")
                // The SVG output rounds the coordinates. Compare with a small tolerance.
                var merged = turn
                _ = merged.mergeWith(left)
                _ = merged.mergeWith(right)
                #expect(abs(box.x - merged.x) < 0.01 && abs(box.w - merged.w) < 0.01, "bounds match the three painted signs")
                #expect(abs(box.y - merged.y) < 0.01 && abs(box.h - merged.h) < 0.01)
            }
            #expect(marked.getWidth() > bare.getWidth(), "formatting reserves room for the pair")
            #expect(marked.getNote() === notes[1], "the editorial turn remains attached to its principal")
            #expect(try draw() == glyphs, "redrawing preserves every glyph position")
            marked.setParenthesized(false)
            #expect(try draw().count == 2, "removing the pair leaves the two turn glyphs")
            marked.setParenthesized().setParenthesized()
            #expect(try draw() == glyphs, "the native setter restores exactly one pair")
        }
    }

    /// ornament_tests.ts 'Pitched trill partners'.
    @Test func pitchedTrillPartners() throws {
        try isolated {
            let (f, ctx) = factory(width: 620, height: 280)
            for (row, width) in [290.0, 170.0].enumerated() {
                for (i, pitch) in ["bb/4", "a/4"].enumerated() {
                    let stave = f.Stave(x: 12 + Double(i) * width, y: 20 + Double(row) * 130, width: width).addClef(.treble)
                    let principal = f.StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "h", stemDirection: .down))
                    let trill = try f.OrnamentThrowing("tr", auxiliaryPitch: pitch)
                    _ = principal.addModifier(trill, index: 0)
                    let next = f.StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "q"))
                    let voice = f.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables([principal, next])
                    _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                    ctx.clear()
                    try stave.draw()
                    try voice.draw(context: ctx, stave: stave)
                    #expect(voice.isComplete() && voice.getTickables().count == 2, "the cue occupies no beat")
                    let box = try #require(trill.getBoundingBox())
                    #expect(box.x + box.w < next.getNoteHeadBeginX(), "cue clears the next attack")
                    let group = try #require(svgGroup(ctx.getSVG(), id: trill.getAttribute("id") ?? ""))
                    let texts = svgTexts(group)
                    #expect(texts.count == 2)
                    if texts.count == 2 {
                        let cue = texts[1]
                        let expectedY = principal.getYs()[0] - stave.getSpacingBetweenLines() * (i == 0 ? 1 : 0.5)
                        #expect(abs(cue.y - expectedY) < 0.01, "written cue staff position")
                        #expect(cue.text.contains(Glyphs.accidentalFlat) == (i == 0), "accidental follows written pitch")
                        #expect(cue.text.hasPrefix(Glyphs.accidentalParensLeft) && cue.text.hasSuffix(Glyphs.accidentalParensRight))
                        #expect(cue.x > principal.getNoteHeadEndX(), "cue clears the principal head")
                    }
                }
            }
        }
    }

    /// ornament_tests.ts 'Changing a pitched trill partner'.
    @Test func changingAPitchedTrillPartner() throws {
        try isolated {
            let (f, ctx) = factory(width: 300, height: 220)
            let stave = f.Stave(y: 65).addClef(.treble)
            let principal = f.StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "h"))
            let trill = f.Ornament("tr")
            _ = principal.addModifier(trill, index: 0)
            let next = f.StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "q"))
            let voice = f.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables([principal, next])
            for pitch in [nil, "bb/4", "a/4", "d/6"] as [String?] {
                try trill.setAuxiliaryPitch(pitch)
                #expect(trill.auxiliaryPitch == pitch)
                _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                ctx.clear()
                try stave.draw()
                try voice.draw(context: ctx, stave: stave)
                let group = try #require(svgGroup(ctx.getSVG(), id: trill.getAttribute("id") ?? ""))
                #expect(svgTexts(group).count == (pitch == nil ? 1 : 2))
                #expect(occurrences(group, "<rect") == (pitch == "d/6" ? 2 : 0), "only the high partner needs ledger lines")
                #expect(voice.isComplete() && voice.getTickables()[0] === principal)
            }
        }
    }

    @Test func pitchedTrillValidation() throws {
        try isolated {
            let trill = Ornament("tr")
            for pitch in ["bb/4", "A#/5", "an/4", "c/-1", "G##/3"] {
                #expect(throws: Never.self) { try trill.setAuxiliaryPitch(pitch) }
            }
            #expect(trill.auxiliaryPitch == "g##/3")
            for pitch in ["h/4", "bbbb/4", "b/45", "b4", "b/", "", "b/x"] {
                #expect(throws: VexError.self) { try trill.setAuxiliaryPitch(pitch) }
            }
            #expect(throws: VexError.self) { try Ornament("turn").setAuxiliaryPitch("a/4") }
            // The factory form drops a bad pitch; the throwing form reports it.
            let (f, _) = factory()
            #expect(f.Ornament("tr", auxiliaryPitch: "x/4").auxiliaryPitch == nil)
            #expect(throws: VexError.self) { try f.OrnamentThrowing("tr", auxiliaryPitch: "x/4") }
        }
    }
}
