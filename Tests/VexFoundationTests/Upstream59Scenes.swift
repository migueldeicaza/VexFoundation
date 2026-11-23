// Drawing code of the VexFlow 5.9.0 early-notation visual tests. Both the opt-in SVG parity cases
// (`UpstreamSVGParityTests-*.swift`) and the logic tests (`Upstream59NotationTests.swift`) use these scenes,
// so the asserts run on the same drawing as the reference images. Each scene mirrors one upstream test
// function in tests/keysignature_tests.ts, tests/stavenote_tests.ts, tests/timesignature_tests.ts,
// tests/clef_tests.ts, tests/staveconnector_tests.ts, tests/frenchlutenote_tests.ts,
// tests/germanlutenote_tests.ts, tests/chantphrase_tests.ts or tests/kievannote_tests.ts.

import Foundation
@testable import VexFoundation

/// A context that records text, filled and cleared rectangles and strokes, and forwards all calls to an SVG
/// context. Upstream tests monkey-patch `fillText`, `fillRect`, `clearRect` and `stroke` for the same purpose.
final class Upstream59RecordingContext: RenderContext {
    let inner: SVGRenderContext
    var texts: [(text: String, x: Double, y: Double)] = []
    var filledRects: [(x: Double, y: Double, w: Double, h: Double)] = []
    var clearedRects = 0
    var strokes = 0

    init(width: Double, height: Double) {
        inner = SVGRenderContext(width: width, height: height)
    }

    func resetRecording() {
        texts = []
        filledRects = []
        clearedRects = 0
        strokes = 0
    }

    var fillStyle: String {
        get { inner.fillStyle }
        set { inner.fillStyle = newValue }
    }
    var strokeStyle: String {
        get { inner.strokeStyle }
        set { inner.strokeStyle = newValue }
    }
    func clear() { inner.clear() }
    func setDefaultStyle(_ style: ElementStyle) -> Self { inner.setDefaultStyle(style); return self }
    func getDefaultStyle() -> ElementStyle { inner.getDefaultStyle() }
    func save() -> Self { inner.save(); return self }
    func restore() -> Self { inner.restore(); return self }
    func setFillStyle(_ style: String) -> Self { inner.setFillStyle(style); return self }
    func setBackgroundFillStyle(_ style: String) -> Self { inner.setBackgroundFillStyle(style); return self }
    func setStrokeStyle(_ style: String) -> Self { inner.setStrokeStyle(style); return self }
    func setShadowColor(_ color: String) -> Self { inner.setShadowColor(color); return self }
    func setShadowBlur(_ blur: Double) -> Self { inner.setShadowBlur(blur); return self }
    func setLineWidth(_ width: Double) -> Self { inner.setLineWidth(width); return self }
    func setLineCap(_ capType: VexLineCap) -> Self { inner.setLineCap(capType); return self }
    func setLineDash(_ dashPattern: [Double]) -> Self { inner.setLineDash(dashPattern); return self }
    func scale(_ x: Double, _ y: Double) -> Self { inner.scale(x, y); return self }
    func resize(_ width: Double, _ height: Double) -> Self { inner.resize(width, height); return self }
    func beginPath() -> Self { inner.beginPath(); return self }
    func moveTo(_ x: Double, _ y: Double) -> Self { inner.moveTo(x, y); return self }
    func lineTo(_ x: Double, _ y: Double) -> Self { inner.lineTo(x, y); return self }
    func bezierCurveTo(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double, _ y: Double) -> Self {
        inner.bezierCurveTo(a, b, c, d, x, y)
        return self
    }
    func quadraticCurveTo(_ a: Double, _ b: Double, _ x: Double, _ y: Double) -> Self {
        inner.quadraticCurveTo(a, b, x, y)
        return self
    }
    func arc(_ x: Double, _ y: Double, _ r: Double, _ s: Double, _ e: Double, _ ccw: Bool) -> Self {
        inner.arc(x, y, r, s, e, ccw)
        return self
    }
    func closePath() -> Self { inner.closePath(); return self }
    func fill() -> Self { inner.fill(); return self }
    func stroke() -> Self { strokes += 1; inner.stroke(); return self }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.rect(x, y, w, h); return self }
    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self {
        filledRects.append((x, y, w, h))
        inner.fillRect(x, y, w, h)
        return self
    }
    func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self {
        clearedRects += 1
        inner.clearRect(x, y, w, h)
        return self
    }
    func pointerRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.pointerRect(x, y, w, h); return self }
    func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double) { inner.openRotation(angleDegrees, x, y) }
    func closeRotation() { inner.closeRotation() }
    func fillText(_ text: String, _ x: Double, _ y: Double) -> Self {
        texts.append((text, x, y))
        inner.fillText(text, x, y)
        return self
    }
    func measureText(_ text: String) -> TextMeasure { inner.measureText(text) }
    func setFont(_ family: String?, _ size: Double?, _ weight: String?, _ style: String?) -> Self {
        inner.setFont(family, size, weight, style)
        return self
    }
    func setFont(_ fontInfo: FontInfo) -> Self { inner.setFont(fontInfo); return self }
    func getFont() -> String { inner.getFont() }
    func openGroup(_ cls: String?, _ id: String?) -> Any? { inner.openGroup(cls, id) }
    func closeGroup() { inner.closeGroup() }
    func add(_ child: Any) { inner.add(child) }
}

/// The recorder when the scene runs in a logic test; nil in a parity case.
private func recorder(_ ctx: RenderContext) -> Upstream59RecordingContext? {
    ctx as? Upstream59RecordingContext
}

private func note(_ f: Factory, _ key: String, _ duration: String, clef: ClefName? = nil, autoStem: Bool? = nil)
    throws -> StaveNote {
    f.StaveNote(try StaveNoteStruct(parsingKeys: [key], duration: duration, autoStem: autoStem, clef: clef))
}

enum Upstream59Scenes {

    // MARK: - KeySignature

    struct WrittenKeySigns {
        var stave: Stave
        var signature: KeySignature
        var notes: [StaveNote]
        var entries: [OrderedKeySign]
        /// `[glyph, y]` of every flat and sharp drawn by `f.draw()`, when recorded.
        var drawn: [(String, Double)]
    }

    /// keysignature_tests.ts `writtenKeySigns`.
    static func writtenKeySigns(_ f: Factory, _ ctx: RenderContext) throws -> WrittenKeySigns {
        let stave = f.Stave(x: 10, y: 38, width: 535).addClef(.treble)
        let entries = [OrderedKeySign(type: "b", pitch: "g/4"), OrderedKeySign(type: "#", pitch: "e/4")]
        let signature = try f.KeySignature("C").setOrdered(entries)
        stave.addModifier(signature)
        let notes = try [ClefName.treble, .alto, .treble].map { try note(f, "g/4", "q", clef: $0) }
        let inline = { try f.KeySigNote(key: "C").setOrdered(entries) }
        let voice = f.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables([
            notes[0], f.ClefNote(type: .alto), try inline(), notes[1], f.ClefNote(type: .treble), try inline(), notes[2],
        ])
        _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        recorder(ctx)?.resetRecording()
        try f.draw()
        let drawn = (recorder(ctx)?.texts ?? [])
            .filter { $0.text == Glyphs.accidentalFlat || $0.text == Glyphs.accidentalSharp }
            .map { ($0.text, $0.y) }
        return WrittenKeySigns(stave: stave, signature: signature, notes: notes, entries: entries, drawn: drawn)
    }

    struct NamedMakam {
        var edition: KeySignaturePresets
        var other: KeySignaturePresets
        var drawn: [(String, Double)]
    }

    /// keysignature_tests.ts `namedMakam`.
    static func namedMakam(_ f: Factory, _ ctx: RenderContext) throws -> NamedMakam {
        var signs = [
            OrderedKeySign(type: Glyphs.accidentalKomaFlat, pitch: "b/4"),
            OrderedKeySign(type: Glyphs.accidentalBakiyeFlat, pitch: "d/5"),
        ]
        let edition = try KeySignaturePresets().register("Sabâ", signs)
        let other = try KeySignaturePresets().register("Sabâ", [signs[1]])
        signs.reverse()
        recorder(ctx)?.resetRecording()
        for (i, source) in [edition, edition, other].enumerated() {
            let stave = f.Stave(x: Double(i) * 225 + 5, y: 38, width: 220).addClef(.treble)
            stave.addModifier(try source.select("Sabâ"))
            let notes = try ["a/4", "b/4", "c/5", "d/5", "c/5"].map { try note(f, $0, "q") }
            let voice = f.Voice(time: VoiceTime(numBeats: 5, beatValue: 4)).addTickables(notes)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
        }
        try f.draw()
        let drawn = (recorder(ctx)?.texts ?? [])
            .filter { $0.text == Glyphs.accidentalKomaFlat || $0.text == Glyphs.accidentalBakiyeFlat }
            .map { ($0.text, $0.y) }
        return NamedMakam(edition: edition, other: other, drawn: drawn)
    }

    // MARK: - StaveNote

    static let fourShapePitches = [
        ["c/4", "d/4", "e/4", "f/4", "g/4", "a/4", "b/4", "c/5"],
        ["d/4", "e/4", "f#/4", "g/4", "a/4", "b/4", "c#/5", "d/5"],
    ]

    /// stavenote_tests.ts `fourShapeScales` (drawing part).
    static func fourShapeScales(_ f: Factory) throws -> [[StaveNote]] {
        let rows = try fourShapePitches.enumerated().map { i, scale -> [StaveNote] in
            let tonic = i == 0 ? "C" : "D"
            let stave = f.Stave(x: 10, y: Double(i) * 115 + 10, width: 550).addClef(.treble).addKeySignature(tonic)
            let notes = try scale.map { try note(f, $0, "q", autoStem: true) }
            try StaveNote.applyFourShape(tonic, notes)
            let voice = f.Voice(time: VoiceTime(numBeats: 8, beatValue: 4)).addTickables(notes)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            return notes
        }
        try f.draw()
        return rows
    }

    // MARK: - TimeSignature

    static let mensuralSigns: [(String, String)] = [
        ("mensural-semicircle", Glyphs.mensuralProlation6),
        ("mensural-circle", Glyphs.mensuralProlation2),
        ("mensural-circle-dot", Glyphs.mensuralProlation1),
        ("mensural-semicircle-dot", Glyphs.mensuralProlation5),
    ]

    struct MensuralRow {
        var stave: Stave
        var sign: TimeSignature
        var notes: [StaveNote]
        var voice: Voice
    }

    /// timesignature_tests.ts `mensuralValuesAndSigns` (drawing part).
    static func mensuralValuesAndSigns(_ f: Factory) throws -> [MensuralRow] {
        var rows: [MensuralRow] = []
        for (i, sign) in mensuralSigns.enumerated() {
            guard let spec = TimeSignatureSpec(parsing: sign.0) else { throw VexError("BadArguments", sign.0) }
            let stave = f.Stave(x: 10, y: Double(i) * 100, width: 475).addTimeSignature(spec)
            guard let timeSignature = stave.getModifiers(category: TimeSignature.category).first as? TimeSignature
            else { throw VexError("BadArguments", "no time signature") }
            let notes = try ["m", "l", "1/2"].enumerated().map { index, duration -> StaveNote in
                var noteStruct = try StaveNoteStruct(parsingKeys: [index == 1 ? "c/5" : "b/4"], duration: duration)
                noteStruct.whiteMensural = true
                return f.StaveNote(noteStruct)
            }
            let voice = f.Voice(time: VoiceTime(numBeats: 14, beatValue: 1)).addTickables(notes)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            rows.append(MensuralRow(stave: stave, sign: timeSignature, notes: notes, voice: voice))
        }
        try f.draw()
        return rows
    }

    // MARK: - Clef (chant)

    struct ChantRow {
        var clef: ChantClef
        var stave: ChantStave
        var anchor: String
        var originalY: Double
        var movedY: Double?
        var bToCLine: Double?
        var notes: [GlyphNote]
        var divisions: [ChantDivision]
        var voice: Voice
        var completeBeforeDraw: Bool
    }

    /// clef_tests.ts `chantClefsAndDivisions`.
    static func chantClefsAndDivisions(_ f: Factory, _ ctx: RenderContext) throws -> [ChantRow] {
        let kinds: [ChantDivisionKind] = [.minima, .maior, .maxima, .finalis]
        var rows: [ChantRow] = []
        for (i, clef) in [ChantClef.c, .f].enumerated() {
            let anchor = clef == .c ? "c/4" : "f/3"
            let keys = clef == .c
                ? ["c/4", "d/4", "d/4", "e/4", "e/4", "d/4", "d/4", "c/4"]
                : ["f/3", "g/3", "a/3", "g/3", "a/3", "g/3", "g/3", "f/3"]
            let stave = try ChantStave(
                x: 10, y: 5 + Double(i) * 125, width: 600, clef: clef, line: clef == .c ? 3 : 2,
                options: StaveOptions(leftBar: false, rightBar: false, spacingBetweenLinesPx: 12)
            )
            stave.setContext(ctx)
            let originalY = try stave.getYForPitch(anchor)
            var movedY: Double?
            var bToCLine: Double?
            if clef == .c {
                try stave.setChantClef(.c, line: 2)
                movedY = try stave.getYForPitch(anchor)
                try stave.setChantClef(.c, line: 3)
                bToCLine = try stave.getLineForPitch("b/3")
            }
            let notes = try keys.map {
                GlyphNote(
                    glyph: Glyphs.chantPunctum, noteStruct: NoteStruct(duration: .quarter),
                    options: GlyphNoteOptions(line: try stave.getLineForPitch($0))
                )
            }
            let divisions = kinds.map { ChantDivision($0) }
            let voice = f.Voice(time: VoiceTime(numBeats: 8, beatValue: 4))
            for j in divisions.indices {
                voice.addTickables([notes[2 * j], notes[2 * j + 1], divisions[j]])
            }
            let completeBeforeDraw = voice.isComplete()
            divisions[0].setKind(.maior)
            divisions[0].setKind(.minima)
            try stave.draw()
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave, options: FormatParams(stave: stave))
            try voice.draw(context: ctx, stave: stave)
            rows.append(ChantRow(
                clef: clef, stave: stave, anchor: anchor, originalY: originalY, movedY: movedY, bToCLine: bToCLine,
                notes: notes, divisions: divisions, voice: voice, completeBeforeDraw: completeBeforeDraw
            ))
        }
        return rows
    }

    // MARK: - StaveConnector

    struct MensurstricheMeasure {
        var system: System
        var top: Stave
        var bottom: Stave
        var upper: Voice
        var lower: Voice
    }

    /// staveconnector_tests.ts `drawMensurstriche`. `check` runs after each of the two draws.
    static func drawMensurstriche(
        _ f: Factory, _ ctx: RenderContext, check: (Double, [MensurstricheMeasure]) throws -> Void = { _, _ in }
    ) throws {
        let score = f.EasyScore()
        let parts = [("C5/h, B4/h", "C3/h, G2/h"), ("A4/w", "F2/h, A2/h"), ("G4/h, A4/h", "C3/w")]
        var measures: [MensurstricheMeasure] = []
        for (i, part) in parts.enumerated() {
            let system = f.System(options: SystemOptions(spaceBetweenStaves: 8, x: 10 + Double(i) * 215, width: 215, y: 0))
            let upper = score.voice(score.notes(part.0))
            let lower = score.voice(score.notes(part.1, options: ["clef": "bass"]))
            let top = system.addStave(SystemStave(voices: [upper]))
            let bottom = system.addStave(SystemStave(voices: [lower]))
            if i == 0 {
                top.addClef(.treble)
                bottom.addClef(.bass)
                system.addConnector(type: .singleLeft)
            }
            if i == 0 {
                try system.addConnectorThrowing(type: .mensurstrich)
            } else {
                try system.addMensurstriche()
            }
            measures.append(MensurstricheMeasure(system: system, top: top, bottom: bottom, upper: upper, lower: lower))
        }
        for spacing in [8.0, 12] {
            if spacing == 12 { ctx.clear() }
            for measure in measures {
                try measure.system.setOptions(SystemOptions(
                    factory: f, spaceBetweenStaves: spacing, x: measure.system.getX(), width: 215, y: 0
                ))
            }
            recorder(ctx)?.resetRecording()
            try f.draw(retain: true)
            try check(spacing, measures)
        }
    }

    struct MensurstricheGroup {
        var staves: [Stave]
        var connectors: [StaveConnector]
        var singleError: Error?
    }

    /// staveconnector_tests.ts `mensurstricheGroup`.
    static func mensurstricheGroup(_ f: Factory) throws -> MensurstricheGroup {
        let system = f.System(options: SystemOptions(spaceBetweenStaves: 9, width: 220))
        let staves = try [ClefName.treble, .alto, .bass].map { clef -> Stave in
            let voice = f.Voice().addTickables([try note(f, "c/4", "w", clef: clef)])
            return system.addStave(SystemStave(voices: [voice])).addClef(clef)
        }
        var singleError: Error?
        do { try system.addConnectorThrowing(type: .mensurstrich) } catch { singleError = error }
        let connectors = try system.addMensurstriche()
        try f.draw()
        return MensurstricheGroup(staves: staves, connectors: connectors, singleError: singleError)
    }

    // MARK: - FrenchLuteNote

    static var frenchPositions: [TabNotePosition] {
        [0, 1, 2, 8, 9].map { TabNotePosition(str: 1, fret: $0) } + [7, 8, 9].map { TabNotePosition(str: $0, fret: 0) }
    }

    struct FrenchRow {
        var stave: TabStave
        var painted: [String]
        var clearedRects: Int
        var xs: [Double]
    }

    /// frenchlutenote_tests.ts `exercise`. `check` runs after each of the two rows.
    static func frenchLuteExercise(
        _ f: Factory, _ ctx: RenderContext, check: (Int, TabStave, [FrenchLuteNote]) throws -> Void = { _, _, _ in }
    ) throws -> FrenchLuteNote {
        let notes = try frenchPositions.map {
            try f.FrenchLuteNote(TabNoteStruct(positions: [$0], duration: .eighth))
        }
        let voice = f.Voice().addTickables(notes)
        for (row, width) in [490.0, 265].enumerated() {
            let stave = f.TabStave(x: 8, y: 5 + 145 * Double(row), width: width)
            try stave.drawWithStyle()
            voice.setStave(stave)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            recorder(ctx)?.resetRecording()
            try voice.draw(context: ctx, stave: stave)
            try check(row, stave, notes)
        }
        return try f.FrenchLuteNote(TabNoteStruct(
            positions: [TabNotePosition(str: 9, fret: 0), TabNotePosition(str: 6, fret: 3), TabNotePosition(str: 7, fret: 0)],
            duration: .quarter
        ))
    }

    // MARK: - GermanLuteNote

    struct GermanResult {
        var stave: Stave
        var notes: [GermanLuteNote]
        var attacks: [Double]
        var editedAttacks: [Double]
        var shapes: [EngravingShapeResult]
        var flags: [Double]
    }

    struct EngravingShapeResult {
        var parts: [BoundingBox]
        var diagnostics: Int
    }

    /// germanlutenote_tests.ts `principalCourses`. `afterEdit` runs after the first course edit.
    static func germanPrincipalCourses(
        _ f: Factory, _ ctx: RenderContext, afterEdit: ([GermanLuteNote]) throws -> Void = { _ in }
    ) throws -> GermanResult {
        let stave = f.Stave(x: 15, y: 50, width: 430, options: StaveOptions(leftBar: false, rightBar: false, numLines: 0))
        let notes = try [(5, 1), (4, 1), (5, 2), (1, 2)].map {
            try f.GermanLuteNote(GermanLuteNoteStruct(course: $0.0, fret: $0.1, duration: "q"))
        }
        let voice = f.Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables(notes)
        func format() { _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave) }
        format()
        let attacks = notes.map { $0.getAbsoluteX() }
        let shapes = try notes.map { note -> EngravingShapeResult in
            let shape = try measureEngraving(note)
            return EngravingShapeResult(parts: shape.parts, diagnostics: shape.diagnostics.count)
        }
        try notes[0].setPosition(4, 1)
        format()
        let editedAttacks = notes.map { $0.getAbsoluteX() }
        try afterEdit(notes)
        try notes[0].setPosition(5, 1)
        recorder(ctx)?.resetRecording()
        try f.draw()
        let flags = (recorder(ctx)?.texts ?? []).filter { $0.text == Glyphs.luteDurationQuarter }.map { $0.x }
        return GermanResult(
            stave: stave, notes: notes, attacks: attacks, editedAttacks: editedAttacks, shapes: shapes, flags: flags
        )
    }

    // MARK: - KievanNote

    struct KievanResult {
        var stave: Stave
        var notes: [KievanNote]
        var voice: Voice
        var ys: [Double]
        var texts: [String]
        var xs: [Double]
        var ticks: [Double]
        var shapes: [(parts: [BoundingBox], diagnostics: Int, expected: BoundingBox)]
        var edited: (text: String, y: Double, sameY: Double, keys: [String], xs: [Double], ticks: [Double])
        var invalidEditKeys: [String]
        var invalidEditThrew: Bool
        var drawnGlyphs: [String]
        var strokes: Int
    }

    static let kievanPitches = ["c/4", "d/4", "e/4", "f/4", "e/4", "d/4", "c/4"]

    /// kievannote_tests.ts `synodalPhrase`.
    static func kievanSynodalPhrase(_ f: Factory, _ ctx: RenderContext) throws -> KievanResult {
        let stave = f.Stave(x: 12, y: 15, width: 482).addClef(.kievan)
        let notes = try kievanPitches.map { try f.KievanNote(KievanNoteStruct(pitch: $0, duration: "h")) }
        let voice = f.Voice(time: VoiceTime(numBeats: 7, beatValue: 2)).addTickables(notes)
        func format() { _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave) }
        format()
        let ys = notes.map { $0.getYs()[0] }
        let texts = notes.map { $0.text }
        let ticks = notes.map { $0.getTicks().value() }
        let shapes = try notes.map { note in
            let shape = try measureEngraving(note)
            return (shape.parts, shape.diagnostics.count, note.getTextInk(note.getAbsoluteX(), note.getYs()[0]))
        }
        let xs = notes.map { $0.getAbsoluteX() }
        let edited = try notes[1].setPitch("e/4")
        format()
        let editedResult = (
            text: edited.text, y: edited.getYs()[0], sameY: notes[2].getYs()[0], keys: edited.keys,
            xs: notes.map { $0.getAbsoluteX() }, ticks: notes.map { $0.getTicks().value() }
        )
        var invalidEditThrew = false
        do { try edited.setPitch("c/4/invalid") } catch { invalidEditThrew = true }
        let invalidEditKeys = edited.keys
        try edited.setPitch("d/4")
        try stave.draw()
        recorder(ctx)?.resetRecording()
        try voice.draw(context: ctx, stave: stave)
        return KievanResult(
            stave: stave, notes: notes, voice: voice, ys: ys, texts: texts, xs: xs, ticks: ticks,
            shapes: shapes, edited: editedResult, invalidEditKeys: invalidEditKeys, invalidEditThrew: invalidEditThrew,
            drawnGlyphs: (recorder(ctx)?.texts ?? []).map { $0.text }, strokes: recorder(ctx)?.strokes ?? 0
        )
    }

    // MARK: - ChantPhrase

    static let luminaText = [
        ChantSyllable(pitches: ["c/4", "d/4"], syllable: "Lu-"),
        ChantSyllable(pitches: ["e/4", "d/4"], syllable: "mi-"),
        ChantSyllable(pitches: ["c/4"], syllable: "na"),
    ]

    /// chantphrase_tests.ts `lumina` (drawing part): the wide, narrow and repeated wide phrases.
    static func lumina(_ ctx: RenderContext) throws -> (wide: [ChantPhraseRow], narrow: [ChantPhraseRow], again: [ChantPhraseRow]) {
        let phrase = try ChantPhrase(luminaText)
        let draw = { (y: Double, width: Double) in
            try phrase.draw(ctx, ChantPhraseOptions(x: 10, y: y, width: width, clef: .c, line: 3))
        }
        let wide = try draw(0, 310)
        let narrow = try draw(100, 123)
        let again = try draw(270, 310)
        return (wide, narrow, again)
    }
}
