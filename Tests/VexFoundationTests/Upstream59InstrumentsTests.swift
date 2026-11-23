// Ports of the VexFlow 5.9.0 logic tests for guitar, banjo and instrument parts:
// tests/tuning_tests.ts, tests/accordionregister_tests.ts, tests/gracenote_tests.ts (Highland),
// tests/ornament_tests.ts (flute trill key), tests/pedalmarking_tests.ts (harp pedal changes),
// tests/node/instrument-profile-tests.mjs (flute, harp, voicings, horizontal frames),
// tests/node/phrase-layout-tests.mjs and tests/node/continuous-score-tests.mjs (sticking).

import Foundation
import Testing
@testable import VexFoundation

private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func makeFactory(width: Double = 720, height: Double = 420) -> (f: Factory, ctx: SVGRenderContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = SVGRenderContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func errorMessage(_ body: () throws -> Void) -> String? {
    do {
        try body()
        return nil
    } catch let error as VexError {
        return error.message
    } catch {
        return error.localizedDescription
    }
}

/// Records arc centers and line segments, and forwards all calls to an SVG context.
private final class RecordingContext: RenderContext {
    let inner: SVGRenderContext
    var arcs: [[Double]] = []
    var segments: [[Double]] = []
    private var point: [Double] = [0, 0]

    init(width: Double = 360, height: Double = 180) {
        inner = SVGRenderContext(width: width, height: height)
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
    func moveTo(_ x: Double, _ y: Double) -> Self { point = [x, y]; inner.moveTo(x, y); return self }
    func lineTo(_ x: Double, _ y: Double) -> Self { segments.append(point + [x, y]); inner.lineTo(x, y); return self }
    func bezierCurveTo(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double, _ y: Double) -> Self {
        inner.bezierCurveTo(a, b, c, d, x, y)
        return self
    }
    func quadraticCurveTo(_ a: Double, _ b: Double, _ x: Double, _ y: Double) -> Self {
        inner.quadraticCurveTo(a, b, x, y)
        return self
    }
    func arc(_ x: Double, _ y: Double, _ r: Double, _ s: Double, _ e: Double, _ ccw: Bool) -> Self {
        arcs.append([x, y])
        inner.arc(x, y, r, s, e, ccw)
        return self
    }
    func closePath() -> Self { inner.closePath(); return self }
    func fill() -> Self { inner.fill(); return self }
    func stroke() -> Self { inner.stroke(); return self }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.rect(x, y, w, h); return self }
    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.fillRect(x, y, w, h); return self }
    func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.clearRect(x, y, w, h); return self }
    func pointerRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.pointerRect(x, y, w, h); return self }
    func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double) { inner.openRotation(angleDegrees, x, y) }
    func closeRotation() { inner.closeRotation() }
    func fillText(_ text: String, _ x: Double, _ y: Double) -> Self { inner.fillText(text, x, y); return self }
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

private func boxesEqual(_ a: BoundingBox?, _ b: BoundingBox?) -> Bool {
    guard let a, let b else { return a == nil && b == nil }
    return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h
}

@Suite("Upstream 5.9.0 port: Guitar, banjo and instrument parts")
struct Upstream59InstrumentsTests {
    // MARK: - tests/tuning_tests.ts

    @Test func halfStepDownTuningLowersEveryOpenStringByOneSemitone() throws {
        let standard = Tuning("standard")
        let eb = Tuning("eb")
        for string in 1...6 {
            #expect(eb.getValueForString(string) == standard.getValueForString(string) - 1, "String \(string)")
        }
        #expect(try eb.getNoteForFretThrowing(0, stringNum: 6) == "Eb/3" || eb.getNoteForFret(0, stringNum: 6) == "D#/3")
    }

    @Test func shortFifthStringAndPairedBanjoTab() throws {
        let tuning = Tuning("standardBanjo")
        #expect(tuning.getNoteForFret(0, stringNum: 5) == "G/5")
        #expect(tuning.getNoteForFret(7, stringNum: 5) == "A/5")
        #expect(tuning.getNoteForFret(7, stringNum: 1) == "A/5")
        #expect(errorMessage { _ = try tuning.getNoteForFretThrowing(2, stringNum: 5) }?.contains("below the nut") == true)
        #expect(tuning.getNoteForFret(0, stringNum: 5, capo: 2) == "G/5")
        #expect(tuning.getNoteForFret(0, stringNum: 5, capo: 7) == "A/5")
        #expect(tuning.getNoteForFret(5, stringNum: 5, capo: 2) == "A/5")

        let banjo = try FrettedInstrument("standardBanjo")
        let positions: [FrettedPosition] = [.fret(str: 5, fret: 7), .fret(str: 2, fret: 0)]
        let played = try banjo.attack(positions, duration: "q")
        #expect(played.note.keys.map { $0.rawValue.uppercased() } == ["A/5", "B/4"])
        #expect(played.tab.positions.map(\.str) == [5, 2])
        #expect(played.tab.positions.map(\.fret) == ["7", "0"])
        #expect(errorMessage { _ = try banjo.attack([.fret(str: 5, fret: 2)], duration: "q") }?.contains("below the nut") == true)

        try tuning.setTuningThrowing(Tuning.names["standardBanjo"]!)
        #expect(tuning.getNoteForFret(7, stringNum: 5) == "D/6", "Custom pitches default to full-length strings")
        try tuning.setTuningThrowing("D/5,G/5", nutFrets: [0, 5])
        #expect(errorMessage { try tuning.setTuningThrowing("D/5,G/5", nutFrets: [5]) }?.contains("nut fret for each string") == true)
        #expect(tuning.getNoteForFret(7, stringNum: 2) == "A/5", "A failed update preserves the prior tuning")
    }

    @Test func localBanjoTuningsRemainFullLength() {
        // The 4.x-only banjo presets keep full-length strings: only `standardBanjo` has a default nut.
        for name in ["doubleCBanjo", "doubleDBanjo", "sawmillBanjo"] {
            let tuning = Tuning(name)
            #expect(tuning.initError == nil)
            #expect(tuning.nutFrets.isEmpty)
        }
        #expect(Tuning("standardBanjo").nutFrets == [0, 0, 0, 0, 5])
    }

    // MARK: - instrument-profile-tests.mjs: guitar voicings

    @Test func guitarVoicingsRetainTheRequestedTuningChordTonesAndSlashBass() throws {
        let tuning = Tuning("standard")
        let c = ChordHarmony(root: "C")
        let open = try #require(try FretDiagram.lookupVoicing(c, tuning: "standard"))
        let inversion = try #require(
            try FretDiagram.lookupVoicing(ChordHarmony(root: "c", quality: "major", bass: "e"), tuning: "standard")
        )
        var barre = try #require(try FretDiagram.lookupVoicing(c, tuning: "standard", name: "third-position"))
        let original = barre
        // A consumer can edit a returned frame without affecting the catalog.
        barre.frets[1] = .fret(0)
        barre.barre?.from = 6
        func pitches(_ frame: FretDiagramSpec) -> [Int] {
            frame.frets.enumerated().compactMap { i, fret in
                guard case .fret(let n) = fret else { return nil }
                return tuning.getValueForFret(n, stringNum: frame.frets.count - i)
            }
        }
        let sounded = try [
            open, inversion, original,
            #require(try FretDiagram.lookupVoicing(ChordHarmony(root: "D"), tuning: "standard")),
            #require(try FretDiagram.lookupVoicing(ChordHarmony(root: "G"), tuning: "standard")),
        ].map(pitches)
        #expect(open.frets == [.muted, .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)])
        #expect(inversion.frets == [.fret(0), .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)])
        #expect(original.frets == [.muted, .fret(3), .fret(5), .fret(5), .fret(5), .fret(3)])
        #expect(sounded.map { $0.map { $0 % 12 } } == [
            [0, 4, 7, 0, 4],
            [4, 0, 4, 7, 0, 4],
            [0, 7, 0, 4, 7],
            [2, 9, 2, 6],
            [7, 11, 2, 7, 11, 7],
        ])
        #expect(sounded.map { ($0.min() ?? 0) % 12 } == [0, 4, 0, 2, 7])
        #expect(try FretDiagram.lookupVoicing(c, tuning: Tuning.names["standard"]!, name: "third-position") == original)
        #expect(try FretDiagram.lookupVoicing(c, tuning: "standard", name: "open") == open)
        let unknown = try [
            FretDiagram.lookupVoicing(c, tuning: "dropd"),
            FretDiagram.lookupVoicing(c, tuning: Tuning.names["dropd"]!),
            FretDiagram.lookupVoicing(c, tuning: "standardBanjo"),
            FretDiagram.lookupVoicing(ChordHarmony(root: "C", quality: "m"), tuning: "standard"),
            FretDiagram.lookupVoicing(ChordHarmony(root: "C", bass: "G"), tuning: "standard"),
            FretDiagram.lookupVoicing(ChordHarmony(root: "C", quality: "/E"), tuning: "standard"),
            FretDiagram.lookupVoicing(c, tuning: "standard", name: "missing"),
        ]
        #expect(unknown.allSatisfy { $0 == nil })
    }

    // MARK: - instrument-profile-tests.mjs: horizontal chord frames

    @Test func horizontalChordFramesKeepStringAssignmentsBarreEndpointsAndBounds() throws {
        try isolated {
            let ctx = RecordingContext()
            let frame = try FretDiagram(FretDiagramSpec(
                orientation: .horizontal, frets: [.muted, .muted, .fret(0), .fret(2), .fret(3), .fret(2)]
            ))
            _ = frame.setContext(ctx)
            try frame.draw()
            #expect(ctx.arcs == [[8.5, 33], [30.5, 24], [41.5, 15], [30.5, 6]])
            let crosses = ctx.segments.filter { abs($0[2] - $0[0]) == 5 && abs($0[3] - $0[1]) == 5 }
            #expect(crosses.count == 4)
            #expect(crosses.allSatisfy { max($0[0], $0[2]) < 14 })

            let bar = try FretDiagram(FretDiagramSpec(
                orientation: .horizontal,
                frets: [.muted, .fret(0), .fret(7), .fret(5), .fret(5), .fret(5)],
                firstFret: 5,
                rows: 7,
                barre: .init(fret: 5, from: 1, to: 3)
            ))
            _ = bar.setX(12)
            _ = bar.setY(8)
            _ = bar.setContext(ctx)
            try bar.draw()
            #expect(ctx.segments.last == [31.5, 14, 31.5, 32])
            let box = try #require(bar.getBoundingBox())
            // The label sits below the strings and inside the box.
            #expect(box.h > 12 + 5 * 9)
            _ = frame.setX(box.x + box.w)
            _ = frame.setY(box.y)
            try frame.draw()
            #expect(frame.getBoundingBox()?.x == box.x + box.w)
        }
    }

    @Test func verticalFramesKeepTheirGeometry() throws {
        try isolated {
            let frame = try FretDiagram(FretDiagramSpec(frets: [.muted, .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)]))
            let box = try #require(frame.getBoundingBox())
            let expected: [Double] = [0, 0, 73, 61]
            #expect([box.x, box.y, box.w, box.h] == expected)
            let labelled = try FretDiagram(FretDiagramSpec(frets: [.muted, .fret(3), .fret(5), .fret(5), .fret(5), .fret(3)], firstFret: 3))
            #expect(labelled.getText() == "3")
        }
    }

    // MARK: - instrument-profile-tests.mjs: flute fingerings

    @Test func sixFluteKeysKeepTheirHandGroupsAndOnlyL3ChangesAtTheNextEntrance() throws {
        try isolated {
            let authored: [FluteKey: FluteKeyState] = [.l1: .closed, .l2: .closed, .l3: .open, .r1: .closed]
            var second = authored
            second[.l3] = .closed
            let charts = [try FluteFingering(authored), try FluteFingering(second)]
            #expect(errorMessage { _ = try FluteFingering([.l1: .closed], scale: 0) } != nil)

            let ctx = SVGRenderContext(width: 500, height: 300)
            let stave = Stave(x: 12, y: 105, width: 350)
            _ = stave.setContext(ctx)
            let notes = try charts.map { chart in
                StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "h")).setStave(stave).addModifier(chart, index: 0)
            }
            let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables(notes)
            struct Layout {
                var center: Double, anchor: Double, above: Bool, reserved: Bool, geometryMatches: Bool
                var centers: [[Double]]
            }
            func layout(_ width: Double) throws -> [Layout] {
                _ = stave.setWidth(width)
                _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                return try charts.enumerated().map { i, chart in
                    let box = try #require(chart.getBoundingBox())
                    let state = try #require(notes[i].getModifierContext()).getState()
                    let halfHead = notes[i].getGlyphWidth() / 2
                    let anchor = notes[i].getModifierStartXY(position: .above, index: 0)
                    let geometry = try measureEngraving(chart)
                    return Layout(
                        center: box.x + box.w / 2,
                        anchor: anchor.x,
                        above: box.y + box.h < stave.getYForLine(0),
                        reserved: state.leftShift + halfHead >= box.w / 2
                            && state.rightShift + halfHead >= box.w / 2
                            && state.topTextLine * 10 >= box.h,
                        geometryMatches: boxesEqual(geometry.ink, box),
                        centers: try FluteKey.allCases.map { key in
                            let point = try chart.getKeyCenter(key)
                            return [point.x - box.x, point.y - box.y]
                        }
                    )
                }
            }
            let widths = [try layout(240), try layout(410)]
            try voice.draw(context: ctx, stave: stave)
            let svg = ctx.getSVG()
            #expect(svg.contains("L1 closed, L2 closed, L3 open, R1 closed, R2 open, R3 open."))
            #expect(svg.contains("L3 closed"))
            #expect(charts[0].getKeyStates() == [.l1: .closed, .l2: .closed, .l3: .open, .r1: .closed, .r2: .open, .r3: .open])
            var expected = charts[0].getKeyStates()
            expected[.l3] = .closed
            #expect(charts[1].getKeyStates() == expected)
            #expect(widths[1][1].center > widths[0][1].center)
            for (a, b) in zip(widths[0], widths[1]) {
                #expect(a.centers == b.centers)
                #expect(a.centers[3][0] > a.centers[0][0], "Right hand sits to the right of the left hand")
                #expect(a.centers[3][1] - a.centers[2][1] > a.centers[1][1] - a.centers[0][1], "Gap between the hands")
                for chart in [a, b] {
                    #expect(chart.geometryMatches)
                    #expect(chart.center == chart.anchor)
                    #expect(chart.above && chart.reserved)
                }
            }
        }
    }

    // MARK: - tests/ornament_tests.ts: moving flute trill key

    @Test func movingFluteTrillKey() throws {
        try isolated {
            let (factory, _) = makeFactory(width: 400, height: 215)
            let stave = factory.Stave(x: 10, y: 94, width: 380).addClef(.treble)
            let pattern: [FluteKey: FluteKeyState] = [.l1: .closed, .l2: .closed, .r1: .closed]
            let notes = try [1.0, 0.75].map { scale in
                let note = factory.StaveNote(try StaveNoteStruct(parsingKeys: ["e/4"], duration: "h"))
                _ = note.addModifier(try FluteFingering(pattern, scale: scale), index: 0)
                return note
            }
            let voice = factory.Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables(notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            for note in notes {
                let diagram = try #require(note.getModifiers().first as? FluteFingering)
                let base = diagram.getKeyStates()
                let box = diagram.getBoundingBox()
                let description = diagram.getDescription()
                let moving = FluteTrillKey(key: .r2, start: .open, alternate: .closed)
                try diagram.setTrillKey(moving)
                #expect(diagram.getTrillKey() == moving, "Alternating key and both states retained")
                #expect(diagram.getKeyStates() == base, "All six base positions retained")
                #expect(boxesEqual(diagram.getBoundingBox(), box), "Hatching fits in the key outline")
                #expect(diagram.getNote() === note, "The original score anchor is retained")
                #expect(diagram.getDescription().contains("Hatched R2 trills from open to closed and back."))
                #expect(errorMessage { try diagram.setTrillKey(FluteTrillKey(key: .l1, start: .open, alternate: .closed)) }?
                    .contains("must start closed") == true)
                #expect(errorMessage { try diagram.setTrillKey(FluteTrillKey(key: .r2, start: .open, alternate: .open)) }?
                    .contains("must alternate to closed") == true)
                #expect(diagram.getTrillKey() == moving, "Invalid requests preserve the prior overlay")
                try diagram.setTrillKey(FluteTrillKey(key: .l1, start: .closed, alternate: .open))
                #expect(diagram.getDescription().contains("Hatched L1 trills from closed to open and back."))
                diagram.clearTrillKey()
                #expect(diagram.getTrillKey() == nil)
                #expect(diagram.getDescription() == description, "Clearing restores the base fingering")
                try diagram.setTrillKey(moving)
            }
            try factory.draw()
        }
    }

    // MARK: - instrument-profile-tests.mjs: harp pedal diagrams

    @Test func sevenHarpPedalsShareOneRailAndPreserveTheNoteAnchorAtTwoScales() throws {
        try isolated {
            let raw = ["A": "flat", "B": "flat", "C": "sharp", "D": "natural", "E": "natural", "F": "sharp", "G": "natural"]
            let settings = try HarpPedalSettings(parsing: raw)
            var bad1 = raw
            bad1["F"] = "double-sharp"
            var bad2 = raw
            bad2["H"] = "flat"
            for bad in [bad1, bad2, ["A": "flat"]] {
                #expect(errorMessage { _ = try HarpPedalSettings(parsing: bad) } != nil)
            }
            #expect(errorMessage { _ = try HarpPedalDiagram(settings, scale: -1) } != nil)

            struct Panel { var glyphs: [String]; var settingF: HarpPedalPosition; var ok: Bool; var width: Double; var height: Double }
            var panels: [Panel] = []
            for scale in [1.0, 1.5] {
                let ctx = SVGRenderContext(width: 500, height: 300)
                let stave = Stave(x: 10, y: 80, width: 380)
                _ = stave.setContext(ctx)
                let notes = try ["d/4", "d/4"].map { StaveNote(try StaveNoteStruct(parsingKeys: [$0], duration: "h")).setStave(stave) }
                let changed = settings.merging([.f: .natural])
                let diagrams = try [settings, changed].enumerated().map { i, s in
                    let diagram = try HarpPedalDiagram(s, scale: scale)
                    _ = notes[i].addModifier(diagram, index: 0)
                    return diagram
                }
                let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables(notes)
                _ = Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                let before = try diagrams.map { try #require($0.getBoundingBox()) }
                try voice.draw(context: ctx, stave: stave)
                let after = try diagrams.map { try #require($0.getBoundingBox()) }
                let stable = zip(before, after).allSatisfy { $0.x == $1.x && $0.y == $1.y }
                let reserved = try before.enumerated().allSatisfy { i, b in
                    let state = try #require(notes[i].getModifierContext()).getState()
                    let halfHead = notes[i].getGlyphWidth() / 2
                    return state.leftShift + halfHead >= b.w / 2 - 1
                        && state.rightShift + halfHead >= b.w / 2 - 1
                        && state.topTextLine * 10 >= b.h
                }
                let clear = before[0].x + before[0].w < before[1].x
                let geometry = try diagrams.allSatisfy { try measureEngraving($0).diagnostics.isEmpty }
                panels.append(Panel(
                    glyphs: diagrams.map { $0.getText() },
                    settingF: diagrams[1].settings[.f],
                    ok: stable && reserved && clear && geometry,
                    width: before[0].w,
                    height: before[0].h
                ))
            }
            for panel in panels {
                #expect(panel.glyphs == [
                    "\u{E681}\u{E682}\u{E680}\u{E683}\u{E681}\u{E682}\u{E681}\u{E680}",
                    "\u{E681}\u{E682}\u{E680}\u{E683}\u{E681}\u{E681}\u{E681}\u{E680}",
                ])
                #expect(panel.settingF == .natural)
                #expect(panel.ok)
            }
            #expect(abs(panels[1].width / panels[0].width - 1.5) < 0.05)
            #expect(abs(panels[1].height / panels[0].height - 1.5) < 0.1)
        }
    }

    // MARK: - tests/pedalmarking_tests.ts: harp pedal changes

    @Test func harpPedalChangesAtARestAndEntrance() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 420, height: 155)
            let initial = try HarpPedalSettings(Dictionary(uniqueKeysWithValues: HarpPedalName.allCases.map { ($0, .natural) }))
            let pedals = HarpPedalChanges(initial)
            let notes = [
                f.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "q")),
                f.StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr")),
                f.StaveNote(try StaveNoteStruct(parsingKeys: ["g/4"], duration: "q")),
                f.StaveNote(try StaveNoteStruct(parsingKeys: ["f/4"], duration: "q")),
            ]
            let first = try #require(pedals.apply(notes[1], [.f: .sharp, .b: .flat]))
            #expect(first.getText() == "B\u{266D}\u{2002}F\u{266F}", "Changed names follow pedal order")
            #expect(pedals.getSettings() == initial.merging([.b: .flat, .f: .sharp]), "Other pedals stay natural")
            #expect(pedals.apply(notes[2], [:]) == nil, "Repeated full setting is silent")
            #expect(notes[2].getModifiers().isEmpty, "No space reserved for an empty change")
            let last = try #require(pedals.apply(notes[3], [.f: .natural]))
            #expect(last.getText() == "F\u{266E}")
            #expect(pedals.getSettings() == initial.merging([.b: .flat]), "B remains flat after resetting F")

            let dynamic = f.TextDynamics(TextNoteStruct(duration: .quarter, text: "mf", line: 10))
            let dynamics: [Tickable] = [
                f.GhostNote(duration: .quarter), f.GhostNote(duration: .quarter), dynamic, f.GhostNote(duration: .quarter),
            ]
            let system = f.System(options: SystemOptions(x: 12, width: 400, y: 10))
            _ = system.addStave(SystemStave(voices: [f.Voice().addTickables(notes), f.Voice().addTickables(dynamics)]))
                .addClef(.treble)
            var restXs: [Double] = []
            for width in [400.0, 260] {
                _ = system.setWidth(width)
                ctx.clear()
                try f.draw(retain: true)
                for label in [first, last] {
                    let box = try #require(label.getBoundingBox())
                    let note = label.checkAttachedNote()
                    let anchor = note.getModifierStartXY(position: .below, index: 0)
                    #expect(abs(box.x + box.w / 2 - anchor.x) < 0.01, "Instruction stays centered at the anchor")
                    let space = try #require(note.getModifierContext()).getState()
                    #expect(space.leftShift + note.getGlyphWidth() + space.rightShift >= box.w, "The full label has space")
                }
                let rest = try #require(first.getBoundingBox())
                let mf = try #require(dynamic.getBoundingBox())
                let lastBox = try #require(last.getBoundingBox())
                #expect(rest.x + rest.w < mf.x && mf.x + mf.w < lastBox.x, "Both labels clear the dynamic")
                restXs.append(rest.x)
            }
            #expect(restXs[1] < restXs[0], "The rest and its label moved when the system narrowed")
        }
    }

    // MARK: - tests/accordionregister_tests.ts

    @Test func activeReedRanksFollowTheirEntrances() throws {
        try isolated {
            let (f, _) = makeFactory(width: 470, height: 205)
            let stave = f.Stave(x: 10, y: 65, width: 440).addClef(.treble)
            let notes = try ["c/5", "a/4", "b/4"].map { f.StaveNote(try StaveNoteStruct(parsingKeys: [$0], duration: "q")) }
            let voice = f.Voice(time: VoiceTime(numBeats: 3, beatValue: 4)).addTickables(notes)
            let marks = [
                try f.AccordionRegister(AccordionRanks(middle: 1)),
                try f.AccordionRegister(AccordionRanks(high: true, low: true)),
                try f.AccordionRegister(AccordionRanks(middle: 2)),
            ]
            let fingering = f.Fingering(number: "2", position: .above)
            _ = notes[1].addModifier(fingering, index: 0)
            for (i, note) in notes.enumerated() { _ = note.addModifier(marks[i], index: 0) }
            let signs = [Glyphs.accdnRH3RanksClarinet, Glyphs.accdnRH3RanksOrgan, Glyphs.accdnRH3RanksTwoChoirs]
            let ranks = [AccordionRanks(middle: 1), AccordionRanks(high: true, low: true), AccordionRanks(middle: 2)]
            func format(_ width: Double) throws -> [Double] {
                _ = stave.setWidth(width)
                _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                let boxes = try marks.enumerated().map { i, mark in
                    let box = try #require(mark.getBoundingBox())
                    let note = notes[i]
                    let anchor = note.getModifierStartXY(position: .above, index: 0)
                    let geometry = try measureEngraving(mark)
                    #expect(geometry.diagnostics.isEmpty, "The register participates in score geometry")
                    #expect(boxesEqual(geometry.parts.first, box), "Ink can be measured before drawing")
                    #expect(abs(box.x + box.w / 2 - anchor.x) < 2, "Sign centered at its entrance")
                    #expect(box.h > 0 && box.w > 0 && box.y + box.h < anchor.y, "Full sign above the notehead")
                    let spacing = try #require(note.getModifierContext()).getState()
                    #expect(spacing.leftShift + note.getGlyphWidth() / 2 + 1 >= box.w / 2, "Space to the left")
                    #expect(spacing.rightShift + note.getGlyphWidth() / 2 + 1 >= box.w / 2, "Space to the right")
                    return box
                }
                let fingerAnchor = notes[1].getModifierStartXY(position: .above, index: 0)
                let fingerInk = fingering.getTextInk(fingerAnchor.x - 4, fingerAnchor.y - 7)
                #expect(boxes[1].y + boxes[1].h < fingerInk.y, "The outer-band sign clears the finger number")
                #expect(marks.map { $0.getRanks() } == ranks, "Stable reed settings")
                #expect(marks.map { $0.getText() } == signs, "The signs specify the same reed settings")
                return boxes.map(\.x)
            }
            let narrow = try format(260)
            let wide = try format(440)
            #expect(wide[1] > narrow[1] && wide[2] > narrow[2], "Later switches move with the bar")
            try f.draw()
            #expect(marks.allSatisfy { $0.isRendered() }, "All three register signs are drawn")
            #expect(try AccordionRegister(AccordionRanks(middle: 3)).getText() == Glyphs.accdnRH3RanksAuthenticMusette)
            #expect(try AccordionRegister(AccordionRanks()).getText() == Glyphs.accdnCombRH3RanksEmpty)
            for middle in [-1, 4] {
                #expect(errorMessage { _ = try AccordionRegister(AccordionRanks(middle: middle)) }?.contains("middle") == true)
            }
        }
    }

    // MARK: - tests/gracenote_tests.ts: Highland embellishments

    @Test func namedHighlandGripAndTaorluath() throws {
        try isolated {
            let (factory, _) = makeFactory(width: 420, height: 155)
            let stave = factory.Stave(x: 10, y: 35, width: 390).addClef(.treble)
            let grip = try GraceNoteGroup.highland(.grip)
            let taorluath = try GraceNoteGroup.highland(.taorluath)
            let groups = [grip, taorluath]
            let notes = try groups.map { group in
                factory.StaveNote(try StaveNoteStruct(parsingKeys: ["a/4"], duration: "h")).addModifier(group, index: 0)
            }
            let voice = factory.Voice().addTickables(notes)
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()

            func keys(_ group: GraceNoteGroup) -> [String] {
                group.graceNotes.map { ($0 as? StaveNote)?.keys.first ?? "" }
            }
            #expect(keys(grip) == ["g/4", "d/5", "g/4"])
            #expect(keys(taorluath) == ["g/4", "d/5", "g/4", "e/5"])
            #expect(groups.map { $0.getHighlandName() } == [.grip, .taorluath])
            #expect(taorluath.getWidth() > grip.getWidth(), "The extra E reserves horizontal room")
            #expect(voice.getTickables().map { ObjectIdentifier($0) } == notes.map { ObjectIdentifier($0) })
            #expect(notes.map { $0.getTicks().value() } == [Double(Tables.RESOLUTION / 2), Double(Tables.RESOLUTION / 2)])
            #expect(notes.map { $0.checkTickContext().getTickID() } == [0, Tables.RESOLUTION / 2])
            for (i, group) in groups.enumerated() {
                let beam = try #require(group.beams.first, "Grace notes are beamed together")
                #expect(beam.getNotes().map { ObjectIdentifier($0) } == group.graceNotes.map { ObjectIdentifier($0) })
                #expect(group.graceNotes.allSatisfy { $0.getAbsoluteX() < notes[i].getAbsoluteX() })
            }
            #expect(keys(try GraceNoteGroup.highland(.grip, pitches: ["b/4", "g/4"])) == ["b/4", "g/4"], "Exact variant")
            let explicit = GraceNoteGroup(graceNotes: [GraceNote(try GraceNoteStruct(parsingKeys: ["e/5"], duration: "16"))])
            #expect(keys(explicit) == ["e/5"])
            #expect(explicit.getHighlandName() == nil)
            #expect(errorMessage { _ = try GraceNoteGroup.highland(.grip, pitches: []) }?.contains("nonempty") == true)
        }
    }

    // MARK: - phrase-layout-tests.mjs + tests/engraving/sticking-study.mjs

    /// `makeStickingStudy(V, f, aligned, rowGap)`: a side-drum paradiddle in two measures with a final rest.
    private func makeStickingStudy(_ f: Factory, rowGap: Double = 8) throws
        -> (sheet: Sheet, notes: [StaveNote], rest: StaveNote, marks: [Annotation], hands: [String]) {
        let sheet = try f.Sheet(options: SheetOptions(width: 460, x: 10, y: 8, rowGap: rowGap))
        let hands = ["R", "L", "R", "R", "L", "R", "L", "L"]
        let drum = try PercussionMap([PercussionInstrument(id: "snare", label: "Side drum", line: 5, stem: .up)])
        let notes = try hands.map { _ in f.StaveNote(try drum.note(["snare"], duration: "8")) }
        let rest = try f.StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "8r")).setRestLine(5)
        for start in stride(from: 0, to: notes.count, by: 4) {
            let group = Array(notes[start..<start + 4])
            _ = f.Beam(notes: group)
            let tickables: [Tickable] = start > 0 ? group + [rest] : group
            let voice = f.EasyScore().voice(tickables, options: EasyScoreVoiceOptions(mode: .soft))
            _ = sheet.addSystem(SystemOptions(spaceBetweenStaves: 3)).addStave(SystemStave(
                voices: [voice],
                options: StaveOptions(numLines: 1, barlineSpan: StaveBarlineSpan(top: -0.8, bottom: 0.8))
            ))
        }
        var assignments = notes.enumerated().map { i, note in
            StickingAssignment(note: note, hand: StickingHand(rawValue: hands[i]))
        }
        assignments.append(StickingAssignment(note: rest))
        let marks = try sheet.addStickingLine(assignments)
        return (sheet, notes, rest, marks, hands)
    }

    @Test func aParadiddleSharesOneStickingBaselinePerPrintedRowThroughAnAccentBreakAndRejoin() throws {
        try isolated {
            let (f, _) = makeFactory()
            let (sheet, notes, rest, marks, hands) = try makeStickingStudy(f, rowGap: 0)
            func baselines() throws -> [Double] { try marks.map { try $0.computeY().y } }
            func checkAnchors() throws {
                #expect(marks.map { $0.getText() } == hands)
                for (i, mark) in marks.enumerated() {
                    #expect(mark.checkAttachedNote() === notes[i])
                    let (x, textWidth) = try mark.computeX()
                    #expect(x + textWidth / 2 == notes[i].getModifierStartXY(position: .below, index: 0).x)
                }
                #expect(rest.getModifiers().isEmpty)
            }
            func checkRows() throws {
                for row in sheet.getRows() {
                    let members = row.systems.flatMap { $0.getStaves() }
                    for mark in marks where members.contains(where: { $0 === mark.checkAttachedNote().getStave() }) {
                        let geometry = try measureEngraving(mark)
                        #expect(geometry.diagnostics.isEmpty)
                        let ink = try #require(geometry.ink)
                        #expect(ink.y >= row.y && ink.y + ink.h <= row.y + row.height, "The row contains the sticking ink")
                    }
                }
            }
            try sheet.format()
            #expect(sheet.getRows().count == 1)
            let plain = try baselines()[0]
            #expect(try baselines() == Array(repeating: plain, count: 8))
            let originalX = try marks.map { try $0.computeX().x }
            try sheet.setWidth(145).format()
            try checkRows()
            try sheet.setWidth(460).format()
            #expect(try marks.map { try $0.computeX().x } == originalX)
            #expect(try baselines() == Array(repeating: plain, count: 8))

            let accent = f.Articulation(type: "a>", position: .below)
            _ = notes[2].addModifier(accent)
            try sheet.format()
            let accented = try baselines()[0]
            #expect(accented > plain)
            #expect(try baselines() == Array(repeating: accented, count: 8))
            let accentInk = try #require(try measureEngraving(accent).ink)
            let markInk = try #require(try measureEngraving(marks[2]).ink)
            #expect(accentInk.y + accentInk.h < markInk.y)
            try checkAnchors()

            try sheet.setWidth(145).format()
            #expect(sheet.getRows().count == 2)
            try checkRows()
            let rows = sheet.getRows()
            #expect(rows[0].y + rows[0].height == rows[1].y)
            let split = try baselines()
            #expect(Array(split[0..<4]) == Array(repeating: split[0], count: 4))
            #expect(Array(split[4...]) == Array(repeating: split[4], count: 4))
            func relative(_ i: Int) -> Double { split[i] - notes[i].checkStave().getYForLine(0) }
            #expect(relative(4) < relative(0), "The second row no longer needs space for the first row's accent")
            try checkAnchors()
            try sheet.setWidth(460).format()
            #expect(sheet.getRows().count == 1)
            #expect(try baselines() == Array(repeating: accented, count: 8))
            try checkAnchors()

            // Malformed later entries cannot leave an earlier label attached.
            let count = notes[0].getModifiers().count
            let first = StickingAssignment(note: notes[0], hand: .right)
            #expect(errorMessage { _ = try sheet.addStickingLine([first, first]) }?.contains("distinct") == true)
            let stranger = f.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "q"))
            #expect(errorMessage { _ = try sheet.addStickingLine([first, StickingAssignment(note: stranger)]) }?
                .contains("sheet") == true)
            #expect(notes[0].getModifiers().count == count)
        }
    }

    // MARK: - continuous-score-tests.mjs

    @Test func continuousScoreBreaksRetainCenteredDrumHandsAndEncloseTheStickingInEachRow() throws {
        try isolated {
            let (f, _) = makeFactory(width: 960, height: 1100)
            var source = EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "staff", measures: (0..<3).map { i in
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                        .note(StaveNoteStruct(parsingDuration: "w", keys: ["c/5"])!, id: "n\(i)"),
                    ])])
                })],
                continuous: ContinuousOptions(boundaries: [ContinuousBoundary(measure: 3, breakBefore: .force)])
            )
            source.sheet = SheetOptions(width: 600, rowGap: 0)
            let c = try f.EasyScore().compose(source)
            let notes = try (0..<3).map { try #require(try c.getNote("n\($0)") as? StaveNote) }
            _ = notes[0].addModifier(f.Articulation(type: "a>", position: .below))
            let marks = try c.sheet.addStickingLine(notes.enumerated().map { i, note in
                StickingAssignment(note: note, hand: i == 1 ? .left : .right)
            })
            try c.sheet.format()
            let rows = c.sheet.getRows()
            #expect(rows[0].systems.count == 2)
            #expect(rows[1].systems.count == 1)
            #expect(try marks[0].computeY().y == marks[1].computeY().y)
            for (i, mark) in marks.enumerated() {
                let row = i < 2 ? rows[0] : rows[1]
                #expect(mark.getNote() === notes[i])
                let ink = try #require(try measureEngraving(mark).ink)
                #expect(ink.y >= row.y && ink.y + ink.h <= row.y + row.height)
            }
        }
    }
}
