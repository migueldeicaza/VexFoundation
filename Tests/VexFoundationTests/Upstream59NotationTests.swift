// Logic-level tests for the pitch and early-notation behaviors ported from VexFlow 5.8.0 -> 5.9.0:
// written key signatures and edition presets, movable four-shape heads, white mensural values and
// mensuration signs, chant clefs and divisions, Mensurstriche, French and German lute tablature,
// Kievan half notes and square-notation chant phrases.
// Ported from the 5.9.0 asserts in tests/keysignature_tests.ts, tests/stavenote_tests.ts,
// tests/timesignature_tests.ts, tests/clef_tests.ts, tests/staveconnector_tests.ts,
// tests/frenchlutenote_tests.ts, tests/germanlutenote_tests.ts, tests/kievannote_tests.ts and
// tests/chantphrase_tests.ts. The drawing code is in `Upstream59Scenes`, shared with the parity cases.
// Upstream monkey-patches `fillText`, `fillRect`, `clearRect` and `stroke`; these tests use a recording context.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

/// `VexFlowTests.makeFactory(options, width, height)` with a recording context.
private func makeFactory(_ width: Double, _ height: Double) -> (f: Factory, ctx: Upstream59RecordingContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = Upstream59RecordingContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func pairs(_ list: [(String, Double)]) -> [String] {
    list.map { "\($0.0)@\($0.1)" }
}

private func throwsMessage(_ pattern: String, _ body: () throws -> Void) -> Bool {
    do {
        try body()
        return false
    } catch {
        let message = (error as? VexError)?.message ?? error.localizedDescription
        return message.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

@Suite("Upstream 5.9.0 port: Pitch and early notation")
struct Upstream59NotationTests {

    // MARK: - KeySignature

    /// keysignature_tests.ts: 'Written key signs follow the active clef'.
    @Test func writtenKeySignsFollowTheActiveClef() throws {
        try isolated {
            let (f, ctx) = makeFactory(560, 155)
            let scene = try Upstream59Scenes.writtenKeySigns(f, ctx)
            let stave = scene.stave
            let pair = { (g: Double, e: Double) -> [(String, Double)] in
                [(Glyphs.accidentalFlat, stave.getYForLine(g)), (Glyphs.accidentalSharp, stave.getYForLine(e))]
            }
            #expect(pairs(scene.drawn) == pairs(pair(3, 4) + pair(0, 1) + pair(3, 4)))
            #expect(scene.notes.map { $0.getYs()[0] } == [3.0, 0, 3].map { stave.getYForLine($0) })

            let literal = try KeySignature(keySpec: "C").setStave(stave).setOrdered([
                OrderedKeySign(type: "b", line: 3),
                OrderedKeySign(type: "#", line: 4),
            ])
            scene.signature.setX(0)
            #expect(scene.signature.getInkParts() == literal.getInkParts())
            stave.setClef(.alto)
            #expect(scene.signature.getInkParts() != literal.getInkParts(), "Only written pitches follow the new clef")
            stave.setClef(.treble)
            #expect(scene.signature.getInkParts() == literal.getInkParts(), "Moving back restores the original placement")
            #expect(throwsMessage("written pitch") {
                try scene.signature.setOrdered([OrderedKeySign(type: "b", pitch: "g/4x")])
            })
        }
    }

    /// keysignature_tests.ts: 'Edition-defined Sabâ signatures'.
    @Test func editionDefinedSabaSignatures() throws {
        try isolated {
            let (f, ctx) = makeFactory(690, 150)
            let scene = try Upstream59Scenes.namedMakam(f, ctx)
            let stave = Stave(x: 5, y: 38, width: 220)
            let pair: [(String, Double)] = [
                (Glyphs.accidentalKomaFlat, stave.getYForLine(2)),
                (Glyphs.accidentalBakiyeFlat, stave.getYForLine(1)),
            ]
            #expect(pairs(scene.drawn) == pairs(pair + pair + [pair[1]]))
            #expect(throwsMessage("Unknown key signature preset.*Saba") { _ = try scene.edition.select("Saba") })
            #expect(throwsMessage("written pitch") {
                try scene.edition.register("Sabâ", [OrderedKeySign(type: "b", pitch: "invalid")])
            })
            #expect(try scene.edition.select("Sabâ") !== scene.edition.select("Sabâ"))
        }
    }

    // MARK: - StaveNote

    /// stavenote_tests.ts: 'Movable four-shape major scales'.
    @Test func movableFourShapeMajorScales() throws {
        try isolated {
            let (f, _) = makeFactory(580, 260)
            let rows = try Upstream59Scenes.fourShapeScales(f)
            for (i, notes) in rows.enumerated() {
                let fa = { (n: StaveNote) in
                    n.getStemDirection() == Stem.UP ? Glyphs.noteShapeTriangleLeftBlack : Glyphs.noteShapeTriangleRightBlack
                }
                let sol = Glyphs.noteShapeRoundBlack, la = Glyphs.noteShapeSquareBlack, mi = Glyphs.noteShapeDiamondBlack
                #expect(notes.map { $0.noteHeads[0].text } == [
                    fa(notes[0]), sol, la, fa(notes[3]), sol, la, mi, fa(notes[7]),
                ])
                #expect(notes.map { $0.getKeys()[0] } == Upstream59Scenes.fourShapePitches[i])
                #expect(notes.allSatisfy { $0.getTicks().value() == Double(Tables.RESOLUTION / 4) })
                for n in notes {
                    let head = n.getHeadInk()[0]
                    let edge = n.getStemDirection() == Stem.UP ? head.x + head.w : head.x
                    #expect(abs(n.getStemX() - edge) < 2, "Stem meets the side of the shaped head")
                }
            }
            let fa = rows[0][0]
            fa.setStemDirection(Stem.DOWN)
            #expect(fa.noteHeads[0].text == Glyphs.noteShapeTriangleRightBlack)
            let half = StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "h"))
            let rest = StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr"))
            let before = rest.noteHeads[0].text
            try StaveNote.applyFourShape("C", [half, rest])
            #expect(half.noteHeads[0].text == Glyphs.noteShapeSquareWhite)
            #expect(rest.noteHeads[0].text == before)
            #expect(throwsMessage("tonic") { try StaveNote.applyFourShape("H", rows[0]) })
        }
    }

    // MARK: - TimeSignature

    /// timesignature_tests.ts: 'White mensural long values and signs'.
    @Test func whiteMensuralLongValuesAndSigns() throws {
        try isolated {
            let (f, _) = makeFactory(510, 430)
            let rows = try Upstream59Scenes.mensuralValuesAndSigns(f)
            let glyphs = [Glyphs.mensuralWhiteMaxima, Glyphs.mensuralWhiteLonga, Glyphs.mensuralWhiteBrevis]
            for (i, row) in rows.enumerated() {
                let notes = row.notes
                #expect(row.voice.isComplete(), "four, two and one breves fill the voice")
                #expect(notes.map { $0.getTicks().value() / notes[2].getTicks().value() } == [4, 2, 1])
                #expect(notes.map { $0.noteHeads[0].text } == glyphs)
                #expect(notes.map { $0.getYs()[0] } == [2.0, 1.5, 2].map { row.stave.getYForLine($0) })
                let inks = notes.map { $0.noteHeads[0].getTextInk(0, 0) }
                let (maxima, longa, brevis) = (inks[0], inks[1], inks[2])
                #expect(maxima.w > longa.w && abs(longa.w - brevis.w) < 2, "maxima has the widest body")
                #expect(longa.h > brevis.h * 2 && maxima.h > brevis.h * 2, "maxima and longa include descending stems")
                #expect(notes.allSatisfy { !$0.hasStem() }, "no extra modern stem")
                #expect(row.sign.text == Upstream59Scenes.mensuralSigns[i].1)
                let ink = try row.sign.getInkBounds()
                #expect(ink.w > 0 && ink.x + ink.w < notes[0].getAbsoluteX(), "sign precedes the first attack")
            }
            // An explicitly ternary longa can keep its own duration and its white outline on the same stave.
            var ternaryStruct = try StaveNoteStruct(parsingKeys: ["c/5"], duration: "l", durationOverride: Fraction(6, 1))
            ternaryStruct.whiteMensural = true
            let ternary = StaveNote(ternaryStruct)
            let breve = StaveNote(try StaveNoteStruct(parsingKeys: ["c/5"], duration: "1/2"))
            #expect(ternary.getTicks().value() == breve.getTicks().value() * 3)
            #expect(ternary.noteHeads[0].text == Glyphs.mensuralWhiteLonga)
            var quarter = try StaveNoteStruct(parsingKeys: ["c/5"], duration: "q")
            quarter.whiteMensural = true
            #expect(throwsMessage("maxima, longa or brevis") { _ = try StaveNote(validating: quarter) })
        }
    }

    @Test func mensurationSignsParseAndKeepNoMeter() {
        for (spec, glyph) in Upstream59Scenes.mensuralSigns {
            let parsed = TimeSignatureSpec(parsing: spec)
            #expect(parsed?.rawValue == spec)
            #expect(parsed?.meter == nil)
            #expect(TimeSignature.getTimeSigCode(spec) == glyph)
        }
        #expect(TimeSignatureSpec(parsing: "c|") == .symbol(.cutCommon))
    }

    // MARK: - Clef (chant)

    /// clef_tests.ts: 'Chant clefs and divisions'.
    @Test func chantClefsAndDivisions() throws {
        try isolated {
            let (f, ctx) = makeFactory(620, 280)
            let rows = try Upstream59Scenes.chantClefsAndDivisions(f, ctx)
            let glyphs = [
                Glyphs.chantDivisioMinima, Glyphs.chantDivisioMaior, Glyphs.chantDivisioMaxima, Glyphs.chantDivisioFinalis,
            ]
            let extents: [[Double]] = [[-0.5, 0.5], [0.5, 2.5], [0, 3], [0, 3]]
            for row in rows {
                let stave = row.stave
                if row.clef == .c {
                    #expect(row.movedY == row.originalY + 12, "C follows the clef down one line")
                    #expect(row.bToCLine == 1.5, "B to middle C crosses an octave by a half-space")
                }
                let mark = try #require(stave.getModifiers(category: Clef.category).first as? Clef)
                #expect(mark.code == (row.clef == .c ? Glyphs.chantCclef : Glyphs.chantFclef), "uses the chant clef glyph")
                #expect(try mark.getGlyphY() == row.originalY, "the first punctum sits on its clef line")
                #expect(row.completeBeforeDraw, "strict voice counts only the eight pitches")
                for (j, division) in row.divisions.enumerated() {
                    #expect(division.shouldIgnoreTicks(), "a phrase division has no duration in the voice")
                    #expect(division.getText() == glyphs[j], "uses the requested division glyph")
                }
                #expect(row.voice.getTickables()[1] === row.notes[1], "keeps the preceding pitch")
                #expect(row.voice.getTickables()[3] === row.notes[2], "keeps the following pitch")
                #expect(row.voice.isComplete(), "changing a division preserves musical duration")
                for (j, division) in row.divisions.enumerated() {
                    let box = try #require(division.getBoundingBox())
                    #expect(abs(box.y - stave.getYForLine(extents[j][0])) <= 2, "starts on the specified line or space")
                    if j == 0 {
                        #expect(division.getY() == stave.getYForLine(1.5), "minima uses its SMuFL center-staff origin")
                    } else {
                        #expect(abs(box.y + box.h - stave.getYForLine(extents[j][1])) <= 2, "ends on the specified line")
                    }
                    #expect(division.getAbsoluteX() > row.notes[2 * j + 1].getAbsoluteX(), "division follows its puncta")
                    if j < 3 {
                        #expect(division.getAbsoluteX() < row.notes[2 * j + 2].getAbsoluteX(), "next pair follows")
                    }
                }
            }
            let stave = try ChantStave(x: 0, y: 0, width: 100)
            #expect(throws: VexError.self) { try stave.setChantClef(.c, line: 5) }
            #expect(throws: VexError.self) { try stave.getLineForPitch("c4") }
        }
    }

    // MARK: - StaveConnector

    /// staveconnector_tests.ts: 'Mensurstriche in a three-measure duet'.
    @Test func mensurstricheInAThreeMeasureDuet() throws {
        try isolated {
            let (f, ctx) = makeFactory(680, 230)
            var checked = 0
            try Upstream59Scenes.drawMensurstriche(f, ctx) { spacing, measures in
                let strokes = ctx.filledRects.filter { [225.0, 440].contains($0.x) && $0.w == 1 }.map { [$0.x, $0.y, $0.h] }
                let expected = measures.prefix(2).map { measure -> [Double] in
                    let y = measure.top.getYForDrawnLine(4)
                    return [measure.top.getX() + measure.top.getWidth(), y, measure.bottom.getYForDrawnLine(0) - y]
                }
                #expect(strokes == expected, "Both boundaries stop at the facing lines")
                #expect(strokes.first?[2] == (spacing - 4) * 10, "The same connector follows the new gap")
                let upper = measures[1].upper, lower = measures[1].lower
                #expect(upper.isComplete() && lower.isComplete(), "Both voices fill the second measure")
                let ticks = upper.getTotalTicks().value()
                #expect(upper.getTickables().map { $0.getTicks().value() } == [ticks], "A4 is sustained")
                #expect(lower.getTickables().map { $0.getTicks().value() } == [ticks / 2, ticks / 2], "Two bass attacks")
                checked += 1
            }
            #expect(checked == 2)
        }
    }

    /// staveconnector_tests.ts: 'Mensurstriche in a three-staff group'.
    @Test func mensurstricheInAThreeStaffGroup() throws {
        try isolated {
            let (f, _) = makeFactory(250, 300)
            let group = try Upstream59Scenes.mensurstricheGroup(f)
            let message = (group.singleError as? VexError)?.message ?? ""
            #expect(message.contains("addMensurstriche"))
            #expect(group.connectors.count == 2)
            for (i, connector) in group.connectors.enumerated() {
                #expect(connector.topStave === group.staves[i])
                #expect(connector.bottomStave === group.staves[i + 1])
                #expect(connector.getType() == .mensurstrich)
            }
            #expect(StaveConnector.typeString["mensurstrich"] == .mensurstrich)
            #expect(ConnectorType.mensurstrich.rawValue == 9)
        }
    }

    // MARK: - FrenchLuteNote

    /// frenchlutenote_tests.ts: 'French fret letters and open bass courses'.
    @Test func frenchFretLettersAndOpenBassCourses() throws {
        try isolated {
            let (f, ctx) = makeFactory(520, 320)
            let positions = Upstream59Scenes.frenchPositions
            let expected = [
                Glyphs.luteFrenchFretA, Glyphs.luteFrenchFretB, Glyphs.luteFrenchFretC, Glyphs.luteFrenchFretI,
                Glyphs.luteFrenchFretK, Glyphs.luteFrench7thCourse, Glyphs.luteFrench8thCourse,
                Glyphs.luteFrench9thCourse,
            ]
            var wideLastX = 0.0
            let bassChord = try Upstream59Scenes.frenchLuteExercise(f, ctx) { row, stave, notes in
                #expect(ctx.texts.map(\.text) == expected, "Paint one French letter or diapason per attack")
                #expect(notes.map { "\($0.getPositions()[0].str)/\($0.getPositions()[0].fret)" }
                    == positions.map { "\($0.str)/\($0.fret)" }, "All sounding positions remain numeric")
                #expect(stave.getNumLines() == 6, "Exactly six ruled courses")
                #expect(ctx.clearedRects == 0, "The letters leave the course lines continuous")
                var previousRight = 0.0
                for (i, note) in notes.enumerated() {
                    let firstCourse = positions[i].str == 1
                    let ink = note.getFretInk()[0]
                    #expect(note.getYs()[0] == stave.getYForLine(firstCourse ? 0 : 6.5), "Marks use the correct baseline")
                    #expect(firstCourse ? ink.y < stave.getYForLine(0) : ink.y > stave.getYForLine(5), "Ink on its course")
                    #expect(ink.w > 0 && ink.x > previousRight, "Distinct sign with space before it")
                    previousRight = ink.x + ink.w
                }
                if row == 0 {
                    wideLastX = notes[7].getAbsoluteX()
                } else {
                    #expect(notes[7].getAbsoluteX() < wideLastX, "The last attack follows the narrower measure")
                }
            }
            let ys = bassChord.getYs()
            #expect(ys[1] < ys[2] && ys[2] < ys[0], "Simultaneous basses have separate rows below course six")
        }
    }

    /// frenchlutenote_tests.ts: 'French lute position limits'.
    @Test func frenchLutePositionLimits() throws {
        let make = { (str: Int, fret: String) throws -> FrenchLuteNote in
            try FrenchLuteNote(validating: TabNoteStruct(positions: [TabNotePosition(str: str, fret: fret)], duration: .quarter))
        }
        _ = try make(6, "12")
        _ = try make(10, "0")
        for str in [0, 11] { #expect(throwsMessage("courses") { _ = try make(str, "0") }) }
        for fret in ["-1", "0.5", "13", "X"] { #expect(throwsMessage("frets") { _ = try make(1, fret) }) }
        #expect(throwsMessage("open") { _ = try make(7, "1") })
    }

    // MARK: - GermanLuteNote

    /// germanlutenote_tests.ts: 'Principal courses on one staffless row'.
    @Test func principalCoursesOnOneStafflessRow() throws {
        try isolated {
            let (f, ctx) = makeFactory(470, 150)
            var ticks = 0.0
            let result = try Upstream59Scenes.germanPrincipalCourses(f, ctx) { notes in
                #expect(notes[0].text == Glyphs.luteGermanBLower)
                ticks = notes[0].getTicks().value()
                #expect(throwsMessage("No principal-course") { try notes[0].setPosition(2, 5) }, "Unknown sign is rejected")
                #expect(notes[0].getPosition() == (course: 4, fret: 1), "Rejected edit retains the last valid position")
            }
            #expect(result.stave.getNumLines() == 0, "No course ruling")
            for (i, shape) in result.shapes.enumerated() {
                #expect(shape.diagnostics == 0, "Both signs have pre-draw geometry")
                #expect(result.notes[i].getYs()[0] == result.stave.getYForLine(0), "Common letter baseline")
                #expect(shape.parts[0].y > shape.parts[1].y + shape.parts[1].h, "Rhythm clears the letter")
                #expect(shape.parts.allSatisfy { $0.w > 0 && $0.h > 0 }, "Both signs have ink")
            }
            #expect(result.editedAttacks == result.attacks, "All columns survive a same-fret course edit")
            #expect(ticks == Double(Tables.RESOLUTION / 4), "Attack retains its duration")
            #expect(result.flags == result.attacks, "Each quarter attack draws its lute rhythm sign at the letter origin")
            #expect(throwsMessage("duration") { _ = try GermanLuteNote(GermanLuteNoteStruct(course: 5, fret: 1, duration: "64")) })
            #expect(try GermanLuteNote(GermanLuteNoteStruct(course: 3, fret: 5, duration: "h")).text == Glyphs.luteGermanZLower)
        }
    }

    @Test func germanLuteInitialSigns() throws {
        try isolated {
            let notes = try [(5, 1), (4, 1), (5, 2), (1, 2)].map {
                try GermanLuteNote(GermanLuteNoteStruct(course: $0.0, fret: $0.1, duration: "q"))
            }
            #expect(notes.map(\.text) == [
                Glyphs.luteGermanALower, Glyphs.luteGermanBLower, Glyphs.luteGermanFLower, Glyphs.luteGermanKLower,
            ])
        }
    }

    // MARK: - KievanNote

    /// kievannote_tests.ts: 'Synodal half notes on lines and spaces'.
    @Test func synodalHalfNotesOnLinesAndSpaces() throws {
        try isolated {
            let (f, ctx) = makeFactory(510, 140)
            let result = try Upstream59Scenes.kievanSynodalPhrase(f, ctx)
            let stave = result.stave
            let clef = try #require(stave.getModifiers(category: Clef.category).first as? Clef)
            #expect(clef.code == Glyphs.kievanCClef)
            #expect(try clef.getGlyphY() == stave.getYForLine(2), "The tse-fa-ut clef marks middle C")
            let line = Glyphs.kievanNoteHalfStaffLine, space = Glyphs.kievanNoteHalfStaffSpace
            #expect(result.texts == [line, space, line, space, line, space, line])
            #expect(result.ys == [2.0, 1.5, 1, 0.5, 1, 1.5, 2].map { stave.getYForLine($0) })
            #expect(result.voice.isComplete())
            #expect(result.ticks.allSatisfy { $0 == Double(Tables.RESOLUTION / 2) }, "Every event keeps a half note")
            for shape in result.shapes {
                #expect(shape.diagnostics == 0)
                #expect(shape.parts == [shape.expected], "Pre-draw ink uses the selected form")
            }
            #expect(result.voice.getTickables()[1] === result.notes[1], "The edited note stays in the same voice slot")
            #expect(result.edited.keys == ["e/4"])
            #expect(result.edited.text == line)
            #expect(result.edited.y == result.edited.sameY)
            #expect(result.edited.ticks == result.ticks)
            #expect(result.edited.xs == result.xs, "All attacks keep their columns")
            #expect(result.invalidEditThrew)
            #expect(result.invalidEditKeys == ["e/4"], "An invalid edit preserves the last valid pitch")
            #expect(throwsMessage("half-note") { _ = try KievanNote(KievanNoteStruct(pitch: "c/4", duration: "q")) })
            #expect(result.drawnGlyphs == [line, space, line, space, line, space, line], "One historical sign per event")
            #expect(result.strokes == 0, "Each half note already includes its stem")
        }
    }

    // MARK: - ChantPhrase

    /// chantphrase_tests.ts: 'Lu-mi-na keeps each neume with its syllable'.
    @Test func luminaKeepsEachNeumeWithItsSyllable() throws {
        try isolated {
            let (_, ctx) = makeFactory(400, 370)
            let (wide, narrow, again) = try Upstream59Scenes.lumina(ctx)
            #expect(wide.count == 1)
            #expect(wide[0].groups.map(\.kind) == [.podatus, .clivis, .punctum])
            #expect(narrow.map { $0.groups.map(\.syllable) } == [["Lu-", "mi-"], ["na"]])
            #expect(narrow.flatMap(\.groups).map(\.pitches) == Upstream59Scenes.luminaText.map(\.pitches))
            for row in wide + narrow {
                for group in row.groups {
                    #expect(try group.ys == group.pitches.map { try row.stave.getYForPitch($0) })
                    #expect(group.ys.allSatisfy { $0 < row.lyricY })
                }
            }
            #expect(again[0].groups.map(\.x) == wide[0].groups.map(\.x))
            #expect(throwsMessage("pitches") { _ = try ChantPhrase([ChantSyllable(pitches: [], syllable: "na")]) })
            #expect(throwsMessage("rise or fall") {
                try ChantPhrase([ChantSyllable(pitches: ["c/4", "c/4"], syllable: "na")])
                    .draw(ctx, ChantPhraseOptions(x: 0, y: 0, width: 300, clef: .c, line: 3))
            })
        }
    }
}
