// Logic-level tests for the behaviors ported from VexFlow 5.0.0 → 5.1.0.

import Foundation
import Testing
@testable import VexFoundation

@Suite("Upstream 5.1.0 port")
struct Upstream51Tests {
    /// Run `body` in an isolated runtime context.
    private func isolated<T>(_ body: () throws -> T) rethrows -> T {
        try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
    }

    private func note(_ key: String, _ duration: String, stem: StemDirection = .up) throws -> StaveNote {
        StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: duration, stemDirection: stem))
    }

    // MARK: - Metrics and text fonts

    @Test func metricsDefaultsHaveTextKeys() {
        let d = Metrics.defaults
        #expect(d["textFontFamily"] as? String == "Academico,Bravura")
        #expect(d["pointerRect"] as? Bool == false)
        #expect((d["StaveNote"] as? [String: Any])?["pointerRect"] as? Bool == true)
        let tuplet = d["Tuplet"] as? [String: Any]
        #expect(tuplet?["pointerRect"] as? Bool == true)
        #expect((tuplet?["bracket"] as? [String: Any])?["legLength"] as? Double == 10)
        #expect((tuplet?["suffix"] as? [String: Any])?["fontScale"] as? Double == 0.5)
        #expect((d["Annotation"] as? [String: Any])?["isText"] as? Bool == true)
        let tempo = d["StaveTempo"] as? [String: Any]
        #expect((tempo?["glyph"] as? [String: Any])?["isText"] as? Bool == false)
    }

    @Test func textElementsUseTextFonts() {
        isolated {
            Flow.setFonts("Bravura", "Academico")
            #expect(Flow.getTextFonts() == ["Academico", "Bravura"])
            #expect(Annotation("Sing").fontInfo.family == "Academico,Bravura")
            #expect(Accidental(.sharp).fontInfo.family == "Bravura,Academico")
            #expect(Metrics.getFontInfo("StaveTempo.glyph").family == "Bravura,Academico")
            #expect(Metrics.getFontInfo("StaveTempo").family == "Academico,Bravura")

            Flow.setTextFonts("Courier New")
            #expect(Annotation("Custom").fontInfo.family.hasPrefix("Courier New"))

            Flow.setFonts("Petaluma", "Bravura", "Leland")
            #expect(Accidental(.sharp).fontInfo.family == "Petaluma,Bravura,Leland")
            // A music-only stack keeps Academico as its text face.
            #expect(Flow.getTextFonts().first == "Academico")

            Metrics.set("Annotation.fontFamily", "Georgia")
            #expect(Annotation("Class override").fontInfo.family == "Georgia")
        }
    }

    // MARK: - Durations and key signatures

    @Test func newDurations() throws {
        #expect(Tables.durationToTicks("m") == Tables.RESOLUTION * 8)
        #expect(Tables.durationToTicks("l") == Tables.RESOLUTION * 4)
        #expect(Tables.durationToTicks("1024") == Tables.RESOLUTION / 1024)
        #expect(Tables.durationCodes["512"]?.beamCount == 7)
        #expect(Tables.codeNoteHead("R", duration: "1/8") == Glyphs.restMaxima)
        #expect(Tables.codeNoteHead("N", duration: "1/4") == Glyphs.mensuralNoteheadLongaBlack)
        let n = try note("c/5", "1024")
        #expect(n.getStemMinimumLength() == 70)
        #expect(Note.parseDuration(String(repeating: "4", count: 65)) == nil)
        #expect(Note.durationToken(of: "8r") == "8")
        #expect(Note.durationToken(of: "8x9") == nil)
    }

    @Test func keySignaturesWithDoubleAccidentals() throws {
        #expect(try Tables.keySignature("flats_0").isEmpty)
        // More than 7: the first (n - 7) positions become double accidentals.
        let nine = try Tables.keySignature("sharps_9")
        #expect(nine.count == 7)
        #expect(nine.filter { $0.type == "##" }.map(\.line) == [0, 1.5])
        #expect(nine.prefix(5).allSatisfy { $0.type == "#" })
        #expect(try Tables.keySignature("Dbm").filter { $0.type == "bb" }.count == 1)
        #expect((try? Tables.keySignature("flats_15")) == nil)
    }

    @Test func xNoteheadStemAnchors() throws {
        let stave = Stave(x: 10, y: 10, width: 300)
        let x = StaveNote(try StaveNoteStruct(parsingKeys: ["g/4/x2"], duration: "4"))
        _ = x.setStave(stave)
        let bounds = x.getStemYBounds()
        let head = try #require(x.noteHeads.first)
        #expect(abs(bounds.yTop - (head.getY() - 4.44)) < 1e-9)
    }

    // MARK: - Tuplets and voices

    @Test func tupletStackAPI() throws {
        let notes = try (0..<3).map { _ in try note("c/4", "8") }
        let a = try Tuplet(notes: notes)
        let b = try Tuplet(notes: notes)
        #expect(notes[0].getTupletStack().count == 2)
        #expect(notes[0].getTuplet() === b)
        notes[0].setTuplet(a)
        #expect(notes[0].getTupletStack().count == 1)
        #expect(notes[0].getTicks().value() == Double(Tables.RESOLUTION / 8) * 2 / 3)
        notes[0].addTuplet(a)
        #expect(notes[0].getTupletStack().count == 1)
        try notes[0].removeTuplet(a)
        #expect(throws: (any Error).self) { try notes[0].removeTuplet(a) }
        notes[1].clearTuplets()
        #expect(notes[1].getTicks().value() == Double(Tables.RESOLUTION / 8))
        #expect(b.getNestedTupletCount() == 1)
    }

    @Test func voiceRefreshesTicksAfterDurationEdits() throws {
        let notes = try (0..<3).map { _ in try note("c/4", "8") }
        let voice = Voice(time: "1/4").setStrict(false).addTickables(notes)
        #expect(voice.getTicksUsed().value() == 6144)
        let tuplet = try Tuplet(notes: notes, options: TupletOptions(numNotes: 3, notesOccupied: 2))
        #expect(voice.getTicksUsed().value() == 4096)
        #expect(voice.isComplete())
        tuplet.attach()
        notes[0].addTuplet(tuplet)
        #expect(voice.getTicksUsed().value() == 4096)
        #expect(voice.getResolutionMultiplier() == 3)
        let nested = try Tuplet(notes: notes, options: TupletOptions(numNotes: 3, notesOccupied: 2))
        #expect(abs(voice.getTicksUsed().value() - 4096 * 2 / 3) < 1e-9)
        notes[0].setDuration(Fraction(1, 4))
        nested.detach()
        tuplet.detach()
        #expect(voice.getTicksUsed().value() == 8192)
        notes.forEach { $0.clearTuplets() }
        #expect(voice.getTicksUsed().value() == 8192)
    }

    @Test func voiceTimeValidation() {
        #expect(throws: (any Error).self) { try Voice(parsingTime: "4/0") }
        #expect(throws: (any Error).self) { try Voice(parsingTime: "x4/4") }
        #expect(throws: (any Error).self) { try Voice(validating: VoiceTime(numBeats: 0)) }
        #expect((try? Voice(parsingTime: "3/8"))?.getTotalTicks().value() == 3 * 2048)
        #expect(throws: (any Error).self) { try Fraction().setThrowing(1, 0) }
    }

    @Test func tupletSuffixAndBoundingBox() throws {
        let ctx = SVGRenderContext(width: 400, height: 150)
        let stave = Stave(x: 10, y: 10, width: 350)
        _ = stave.setContext(ctx)
        let notes = try (0..<3).map { _ in try note("g/4", "4") }
        let tuplet = try Tuplet(notes: notes, options: TupletOptions(ratioed: true, suffix: Glyphs.metNoteQuarterUp))
        let voice = Voice(time: "2/4").addTickables(notes)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        try voice.draw(context: ctx, stave: stave)
        try tuplet.setContext(ctx).draw()
        #expect(tuplet.suffixElement.getText() == Glyphs.metNoteQuarterUp)
        let bb = try #require(tuplet.getBoundingBox())
        let ratio = try #require(tuplet.textElement.getBoundingBox())
        #expect(bb.x <= ratio.x && bb.x + bb.w >= ratio.x + ratio.w)
        #expect(bb.h >= 10)
        // Tuplets draw a pointer rectangle (metrics `Tuplet.pointerRect`).
        #expect(ctx.getSVG().contains("pointer-events=\"auto\""))
    }

    // MARK: - Layout and modifiers

    @Test func restClearanceAgainstTallChord() throws {
        for direction in [StemDirection.up, .down] {
            let stave = Stave(x: 20, y: 100, width: 500)
            let rest = StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr", stemDirection: direction))
            _ = rest.setStave(stave)
            let chord = StaveNote(try StaveNoteStruct(
                parsingKeys: direction == .up ? ["g/4", "c/5", "g/5"] : ["c/4", "e/4", "g/4"],
                duration: "q",
                stemDirection: direction == .up ? .down : .up
            ))
            _ = chord.setStave(stave)
            let voices = (direction == .up ? [rest, chord] : [chord, rest]).map { Voice(time: "1/4").addTickables([$0]) }
            _ = Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            let a = try #require(rest.getBoundingBox())
            let b = try #require(chord.getBoundingBox())
            #expect(direction == .up ? a.y + a.h <= b.y : a.y >= b.y + b.h)
        }
    }

    @Test func lyricsDoNotPushTies() throws {
        func offset(lyric: Bool, nearby: String) throws -> Double {
            let stave = Stave(x: 10, y: 10, width: 600)
            let notes = try (0..<2).map { _ in try note("c/4", "h") }
            notes.forEach { _ = $0.setStave(stave) }
            if lyric {
                let annotation = Annotation("A very long lyric")
                    .setVerticalJustification(nearby == "inline" ? .center : .bottom)
                _ = notes[0].addModifier(annotation, index: 0)
            }
            if nearby == "dot" { Dot.buildAndAttach([notes[0]]) }
            let voice = Voice(time: "4/4").addTickables(notes)
            _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            return notes[0].getTieRightX() - notes[0].getAbsoluteX()
        }
        for nearby in ["", "dot"] {
            #expect(try offset(lyric: true, nearby: nearby) == offset(lyric: false, nearby: nearby))
        }
        #expect(try offset(lyric: true, nearby: "inline") > offset(lyric: false, nearby: ""))
    }

    @Test func annotationComputedPositionsAndBaseline() throws {
        let stave = Stave(x: 10, y: 10, width: 300)
        let n = try note("c/4", "4")
        _ = n.setStave(stave)
        let annotation = Annotation("la").setVerticalJustification(.bottom)
        _ = n.addModifier(annotation, index: 0)
        let voice = Voice(time: "1/4").addTickables([n])
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        let auto = try annotation.computeY().y
        try annotation.setTextBaseline(200)
        #expect(try annotation.computeY().y == 200)
        try annotation.setTextBaseline(nil)
        #expect(try annotation.computeY().y == auto)
        #expect(throws: (any Error).self) { try annotation.setTextBaseline(.infinity) }
        #expect(try annotation.computeX().textWidth == annotation.getWidth())
    }

    @Test func pedalMarkingClearsBottomAnnotations() throws {
        let stave = Stave(x: 10, y: 10, width: 400)
        let notes = try (0..<4).map { _ in try note("c/4", "4") }
        notes.forEach { _ = $0.setStave(stave) }
        let voice = Voice(time: "4/4").addTickables(notes)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        let pedal = PedalMarking(notes: [notes[0], notes[3]])
        let plain = pedal.getYForStave(stave)
        let lyric = Annotation("lyric").setVerticalJustification(.bottom)
        _ = notes[1].addModifier(lyric, index: 0)
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        #expect(pedal.getYForStave(stave) > plain)
        #expect(PedalMarkingRenderOptions().color == nil)
    }

    @Test func graceNoteGroupBoundsBeforeDrawing() throws {
        let stave = Stave(x: 10, y: 10, width: 250)
        let graceNotes = try ["e/4", "f/4", "g/5"].map {
            GraceNote(try GraceNoteStruct(parsingKeys: [$0], duration: "16"))
        }
        let group = GraceNoteGroup(graceNotes: graceNotes)
        group.beamNotes()
        let n = try note("b/4", "q")
        _ = n.setStave(stave)
        graceNotes.forEach { _ = $0.setStave(stave) }
        _ = n.addModifier(group, index: 0)
        let voice = Voice(time: "1/4").setStrict(false).addTickables([n])
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        let bb = try #require(group.getBoundingBox())
        #expect(bb.x > 0 && bb.y > 0)
        #expect(bb.x + bb.w <= n.getAbsoluteX())
    }

    @Test func curveBoundingBoxFitsExtrema() {
        let values = Curve.bezierExtrema(0, 10, 10, 0)
        #expect(values.contains(0))
        #expect(abs((values.max() ?? 0) - 7.5) < 1e-9)
    }

    @Test func textDynamicsBoundingBoxBeforeDrawing() throws {
        let stave = Stave(x: 10, y: 10, width: 300)
        let dyn = TextDynamics(TextNoteStruct(duration: .quarter, text: "ff"))
        _ = dyn.setStave(stave)
        let voice = Voice(time: "1/4").addTickables([dyn])
        _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        let bb = try #require(dyn.getBoundingBox())
        #expect(bb.w > 0 && bb.y > stave.getYForLine(0) - 100)
    }

    // MARK: - Barlines, registry, tab notes

    @Test func repeatBracketsDrawExtraPaths() throws {
        func svg(_ bracket: RepeatBracketType) throws -> String {
            let ctx = SVGRenderContext(width: 300, height: 120)
            let stave = Stave(x: 10, y: 10, width: 250)
                .setBegBarType(.repeatBegin, repeatBracket: bracket)
                .setEndBarType(.repeatEnd, repeatBracket: bracket)
            try stave.setContext(ctx).draw()
            return ctx.getSVG()
        }
        let plain = try svg(.none)
        let straight = try svg(.straight)
        let curved = try svg(.curved)
        let count = { (s: String) in s.components(separatedBy: "<path").count }
        #expect(count(straight) == count(plain) + 4)
        #expect(curved.contains("Q"))
    }

    @Test func registryIgnoresUnknownIndexes() {
        let registry = Registry()
        let element = VexElement()
        registry.register(element, id: "a")
        registry.setIndexValue(name: "__proto__", value: "x", id: "a", elem: element)
        #expect(registry.getElementsByAttribute("__proto__", value: "x").isEmpty)
        #expect(Registry.isValidIndexName("class"))
    }

    @Test func graceTabNoteFretsUseGraceScale() throws {
        let tab = TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: "9")], duration: .quarter))
        let grace = GraceTabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: "9")], duration: .eighth))
        #expect(tab.fretElement[0].fontSizeInPoints == 9)
        #expect(abs(grace.fretElement[0].fontSizeInPoints - 6) < 1e-9)
        _ = tab.setFontSize(12.0)
        #expect(tab.fretElement[0].fontSizeInPoints == 12)
    }

    // MARK: - Score style, retained draw, Sheet, EasyScore measures

    @Test func factoryScoreStyleAndRetainedDraw() throws {
        let ctx = SVGRenderContext(width: 300, height: 120)
        let factory = Factory(options: FactoryOptions(width: 300, height: 120))
        _ = factory.setContext(ctx)
        _ = factory.setStyle(ElementStyle(fillStyle: "red", strokeStyle: "red"))
        let stave = factory.Stave()
        let explicit = factory.Stave(y: 40).setStyle(ElementStyle(strokeStyle: "blue"))
        try factory.draw(retain: true)
        let svg = ctx.getSVG()
        // Built-in metric colors yield to the score colors; explicit styles win.
        #expect(!svg.contains("#999999"))
        #expect(svg.contains("stroke=\"blue\""))
        #expect(ctx.getDefaultStyle().strokeStyle == nil)
        _ = stave
        _ = explicit
        // A retained score can be drawn again.
        try factory.draw()
    }

    @Test func easyScoreMeasuresCarryDuration() throws {
        let factory = Factory(options: FactoryOptions(width: 500, height: 200))
        let score = factory.EasyScore()
        let measures = try score.measures("c4/q, d4, e4, f4 | g4, a4, b4, c5 | c5/h, c5")
        #expect(measures.count == 3)
        #expect(measures[1].allSatisfy { $0.getDuration() == "4" })
        #expect(measures[2].count == 2)
        let quoted = try score.measures("c4/w[id=\"a|b\"]")
        #expect(quoted.count == 1)
        #expect(throws: (any Error).self) { try score.measures("c4/w | | c4/w") }
        let initial = try score.measures("c4, d4", options: ["duration": "h"])
        #expect(initial[0].allSatisfy { $0.getDuration() == "2" })
    }

    @Test func sheetWrapsMeasures() throws {
        let ctx = SVGRenderContext(width: 400, height: 600)
        let factory = Factory(options: FactoryOptions(width: 400, height: 600))
        _ = factory.setContext(ctx)
        let score = factory.EasyScore()
        let sheet = try factory.Sheet(options: SheetOptions(width: 400))
        for line in try score.measures("c4/q, d4, e4, f4 | g4, a4, b4, c5 | c5/8, b4, a4, g4, f4, e4, d4, c4 | c4/w") {
            let system = sheet.addSystem()
            _ = system.addStave(SystemStave(voices: [score.voice(line.map { $0 as Note })]))
        }
        #expect(throws: (any Error).self) { try sheet.setWidth(0) }
        try sheet.format()
        let wide = sheet.getRows()
        #expect(wide.count >= 2)
        #expect(wide.flatMap(\.systems).count == 4)
        for row in wide where row.systems.count > 1 {
            #expect(abs(row.width - 400) < 1e-6) // justified
        }
        try sheet.setWidth(150).format()
        #expect(sheet.getRows().count == 4)
        #expect(sheet.getHeight() > wide.last.map { $0.y + $0.height } ?? 0)
        try factory.draw()
        #expect(ctx.getSVG().contains("vf-stavenote"))
    }

    @Test func systemWidthAPI() throws {
        let factory = Factory(options: FactoryOptions(width: 500, height: 200))
        let system = factory.System()
        #expect(throws: (any Error).self) { try system.setWidthThrowing(-1) }
        system.setWidth(320)
        #expect(system.getWidth() == 320)
    }

    // MARK: - Portable SVG export

    @Test func portableSVGExportConvertsTextToPaths() throws {
        let ctx = SVGRenderContext(width: 300, height: 120)
        let stave = Stave(x: 10, y: 10, width: 250).addClef(.treble)
        try stave.setContext(ctx).draw()
        ctx.setFont(FontInfo(family: "Academico", size: "12pt", weight: "normal", style: "normal"))
        ctx.fillText("Hi", 20, 100)
        let live = try ctx.toSVG()
        #expect(live == ctx.getSVG())
        #expect(live.contains("<text"))
        let portable = try ctx.toSVG(portable: true)
        #expect(!portable.contains("<text"))
        #expect(portable.components(separatedBy: "<path").count > live.components(separatedBy: "<path").count)
        #expect(portable.contains("d=\"M"))
        // The live drawing is unchanged.
        #expect(ctx.getSVG() == live)
    }
}
