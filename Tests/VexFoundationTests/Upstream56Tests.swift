// Logic-level tests for the behaviors ported from VexFlow 5.4.0 → 5.6.1 (releases 5.5.0, 5.6.0 and 5.6.1).
// Ported from the 5.6.1 assertions in tests/font_tests.ts, tests/tabstave_tests.ts, tests/tabnote_tests.ts,
// tests/node/metrics-tests.mjs, tests/node/phrase-layout-tests.mjs, tests/node/engraving-layout-tests.mjs,
// tests/node/easyscore-tests.mjs, tests/node/continuous-score-tests.mjs, tests/node/local-engraving-tests.mjs
// and tests/node/publication-tests.mjs. The browser tests use the SVG string context here.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func makeFactory(width: Double = 600, height: Double = 400) -> (f: Factory, ctx: SVGRenderContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = SVGRenderContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func staveNote(_ keys: [String], _ duration: String, restLine: Double? = nil, stem: StemDirection? = nil,
                       type: String? = nil) -> StaveNote {
    // The test inputs are valid literals.
    var value = StaveNoteStruct(parsingDuration: duration, keys: keys, type: type, stemDirection: stem)!
    value.restLine = restLine
    return StaveNote(value)
}

/// `tabEndingStudy()` from tests/engraving/continuous-studies.mjs (VexFlow 5.6.0): two chords reorder their
/// positions but sustain string two across the barline.
private func tabEndingStudy(_ tie: ContinuousSpan? = nil) -> EasyScoreCompositionSpec {
    let positions = [TabNotePosition(str: 1, fret: 12), TabNotePosition(str: 2, fret: 10)]
    let measures = [positions, positions.reversed()].enumerated().map { i, chord in
        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
            .tab(TabNoteStruct(positions: chord, duration: .quarter), id: "tab\(i)"),
        ])])
    }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "guitar", kind: .tab, time: .meter(1, 4), measures: measures)],
        continuous: ContinuousOptions(spans: [
            tie ?? ContinuousSpan(id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: 1),
            ContinuousSpan(id: "ending", kind: .volta, from: "tab0", to: "tab1", text: "1."),
        ])
    )
}

@Suite("Upstream 5.6.1 port")
struct Upstream56Tests {

    // MARK: - Text defaults (font_tests.ts, metrics-tests.mjs)

    @Test func scoreTextDefaults() {
        isolated {
            Flow.setFonts("Bravura", "Academico")
            let note = TabNote(TabNoteStruct(positions: [TabNotePosition(str: 1, fret: 5)], duration: .quarter))
            let ends = TieNotes(firstNote: note, lastNote: note)
            #expect(abs(ChordSymbol().fontSizeInPoints - 14) < 1e-9)
            #expect(VexFont.convertSizeToPointValue(Metrics.getFontInfo("Annotation.lyric").size) == 12)
            #expect(VexFont.convertSizeToPointValue(Metrics.getFontInfo("Annotation.guitarStroke").size) == 11)
            #expect(VexFont.convertSizeToPointValue(Metrics.getFontInfo("TabNote.text").size) == 11)
            #expect(VexFont.convertSizeToPointValue(Metrics.getFontInfo("Stroke.text").size) == 11)
            #expect(TabTie(notes: ends, text: "H").fontInfo.family.hasPrefix("Arial"))
            #expect(TabTie(notes: ends, text: "H").fontInfo.weight == "bold")
            #expect(StaveTie(notes: ends, text: "H").fontInfo.family.hasPrefix("Academico"))
            #expect(TabTie(notes: ends, text: "hold").fontInfo.family.hasPrefix("Academico"))
        }
    }

    @Test func clearingACategoryClearsItsNestedRoles() {
        isolated {
            let key = "Upstream56Probe"
            Metrics.set(key, ["isText": true, "fontSize": 12.0, "child": [:] as [String: Any]] as [String: Any])
            #expect(VexFont.convertSizeToPointValue(Metrics.getFontInfo(key + ".child").size) == 12)
            Metrics.set(key + ".fontSize", 24.0)
            Metrics.clear(key)
            #expect(VexFont.convertSizeToPointValue(Metrics.getFontInfo(key + ".child").size) == 24)
        }
    }

    // MARK: - TAB clefs and meters (tabstave_tests.ts, 5.6.1)

    @Test func fourStringTabClefFitsTheStave() throws {
        let runtime = Flow.makeRuntimeContext()
        // The gated alignment patch in `Stave.format()` keeps a larger `startX`; upstream recomputes it.
        runtime.upstreamParityMode = true
        try Flow.withRuntimeContext(runtime) {
            for (index, spacing) in [13.0, 9.0].enumerated() {
                let lineWidth = Double(index + 1)
                let stave = TabStave(x: 10, y: 10, width: 145, options: StaveOptions(spacingBetweenLinesPx: spacing, numLines: 6))
                _ = stave.setStyle(ElementStyle(lineWidth: lineWidth)).addClef(.tab).addEndClef(.tab, size: .small)
                let sixStartX = stave.getNoteStartX()
                _ = stave.setNumLines(4)
                let clefs = stave.getModifiers(category: Clef.category).compactMap { $0 as? Clef }
                #expect(stave.getYForGlyphs() == stave.getYForLine(1.5))
                #expect(stave.getNoteStartX() < sixStartX)
                let full = try clefs[0].getInkBounds()
                for clef in clefs {
                    #expect(clef.code == Glyphs.fourStringTabClef)
                    let ink = try clef.getInkBounds()
                    #expect(ink.h > 0)
                    let topString = stave.getYForLine(0) + (lineWidth == 1 ? 0.5 : 0)
                    let bottomString = topString + 3 * spacing
                    let topGap = ink.y - (topString + lineWidth / 2)
                    let bottomGap = bottomString - lineWidth / 2 - (ink.y + ink.h)
                    let minimumGap = lineWidth + spacing / 8 - 0.5
                    #expect(topGap >= minimumGap && bottomGap >= minimumGap)
                    #expect(abs(topGap - bottomGap) < 0.01)
                }
                #expect(try clefs[1].getInkBounds().h < full.h)
                let inline = ClefNote(type: .tab).setStave(stave)
                #expect(inline.getClef().code == clefs[0].code)
                #expect(inline.getClef().getWidth() == clefs[0].getWidth())
                _ = stave.setNumLines(6)
                #expect(clefs[0].code == Glyphs.sixStringTabClef)
                #expect(stave.getNoteStartX() == sixStartX)
            }
            let six = TabStave(x: 330, y: 10, width: 150).addClef(.tab)
            #expect((six.getModifiers(category: Clef.category).first as? Clef)?.line == 2.5)
        }
    }

    @Test func tabClefsAndMetersCenterOnEveryStringCount() throws {
        try isolated {
            for strings in [4, 5, 6, 7] {
                let stave = TabStave(x: 12, y: 25, width: 225, options: StaveOptions(spaceAboveStaffLn: 0, numLines: strings))
                _ = stave.addClef(.tab).addEndClef(.tab, size: .small)
                    .addTimeSignature(.meter(4, 4))
                    .addTimeSignature(.symbol(.common))
                    .addEndTimeSignature(.symbol(.cutCommon))
                stave.format()
                let span = stave.space(Double(strings - 1))
                for clef in stave.getModifiers(category: Clef.category).compactMap({ $0 as? Clef }) {
                    let ink = try clef.getInkBounds()
                    let above = ink.y - (stave.getYForDrawnLine(0) + 0.5)
                    let below = stave.getYForDrawnLine(Double(strings - 1)) - 0.5 - ink.y - ink.h
                    #expect(abs(above - below) < 0.01)
                    #expect(above >= 1 + span / 24 - 0.5 && ink.h > 0)
                }
                for meter in stave.getModifiers(category: TimeSignature.category).compactMap({ $0 as? TimeSignature }) {
                    let ink = try meter.getInkBounds()
                    let center = stave.getYForDrawnLine(Double(strings - 1) / 2)
                    #expect(ink.h > 0 && abs(ink.y + ink.h / 2 - center) < 0.01)
                }
            }
        }
    }

    // MARK: - Tab frets straddle the tick (tabnote_tests.ts, gracetabnote_tests.ts)

    @Test func tabFretsReserveBothHalvesAndSideModifiersClearThem() throws {
        try isolated {
            let (_, ctx) = makeFactory(width: 280, height: 140)
            let stave = TabStave(x: 10, y: 10, width: 260).addTabGlyph()
            _ = stave.setContext(ctx)
            let positions = [0, 12, 10, 15, 13, 11].enumerated().map { TabNotePosition(str: $0.offset + 1, fret: $0.element) }
            let chord = TabNote(TabNoteStruct(positions: positions, duration: .quarter))
            let small = TabNote(TabNoteStruct(positions: positions, duration: .quarter)).setFontSize(9.0)
            try Formatter.FormatAndDraw(ctx: ctx, stave: stave, notes: [chord, small])
            #expect(chord.getWidth() > small.getWidth())
            for note in [chord, small] {
                #expect(note.getLeftDisplacedHeadPx() == note.getWidth() / 2)
                #expect(note.getRightDisplacedHeadPx() == note.getWidth() / 2)
                #expect(note.getModifierStartXY(position: .above, index: 0).x == note.getAbsoluteX())
                #expect(note.getModifierStartXY(position: .left, index: 0).x == note.getTieLeftX())
                #expect(note.getModifierStartXY(position: .right, index: 0).x == note.getTieRightX())
            }
        }
    }

    // MARK: - Rest positions (phrase-layout-tests.mjs)

    @Test func authoredRestsKeepTheirLedgerGlyphOnEveryStave() {
        isolated {
            let (f, ctx) = makeFactory()
            for lines in [4, 5] {
                let stave = f.Stave(x: 10, y: 40, width: 300, options: StaveOptions(numLines: lines))
                for (duration, plain, ledger) in [
                    ("hr", Glyphs.restHalf, Glyphs.restHalfLegerLine),
                    ("wr", Glyphs.restWhole, Glyphs.restWholeLegerLine),
                ] {
                    let bottom = Double(6 - lines)
                    for line in [bottom - 1, bottom, 3, 5, 6] {
                        let rest = staveNote(["r/4"], duration, restLine: line)
                        let other = staveNote(["b/4"], "w", stem: .down)
                        let voices = [rest, other].map { Voice(timeSignature: .meter(4, 4)).setMode(.soft).addTickable($0) }
                        for _ in 0..<2 {
                            _ = Formatter().joinVoices(voices).formatToStave(voices, stave: stave, options: FormatParams(alignRests: true))
                            for voice in voices { try? voice.draw(context: ctx, stave: stave) }
                            let head = rest.noteHeads[0]
                            #expect(rest.getKeyLine(0) == line)
                            #expect(head.getY() == stave.getYForNote(line))
                            #expect(head.getText() == (line < bottom || line > 5 ? ledger : plain))
                        }
                    }
                }
            }
            let rest = staveNote(["r/4"], "wr", restLine: 1)
            _ = rest.setStave(Stave(x: 0, y: 0, width: 100, options: StaveOptions(numLines: 4)))
            #expect(rest.noteHeads[0].text == Glyphs.restWholeLegerLine)
            _ = rest.setStave(Stave(x: 0, y: 0, width: 100))
            #expect(rest.noteHeads[0].text == Glyphs.restWhole)
        }
    }

    @Test func automaticRestsClearAFixedRestAndResumeAfterRelease() throws {
        try isolated {
            let (f, _) = makeFactory()
            let next = staveNote(["d/5"], "q")
            let fixed = staveNote(["r/4"], "qr", restLine: 3)
            Formatter.AlignRestsToNotes([fixed, next], alignAllNotes: true)
            #expect(fixed.getKeyLine(0) == 3)
            let auto = staveNote(["r/4"], "qr")
            let stave = f.Stave(x: 10, y: 40, width: 300)
            let voices = [fixed, auto].map { Voice(timeSignature: .meter(4, 4)).setMode(.soft).addTickable($0) }
            _ = Formatter().joinVoices(voices).formatToStave(voices, stave: stave)
            #expect(fixed.getKeyLine(0) == 3)
            #expect(auto.getKeyLine(0) != 3)
            #expect(auto.renderOptions.draw != false)
            try fixed.setRestLine(0).setRestLine(nil)
            Formatter.AlignRestsToNotes([fixed, next], alignAllNotes: true)
            #expect(fixed.getKeyLine(0) == next.getLineForRest())
            #expect(throws: VexError.self) { try next.setRestLine(1) }
            #expect(throws: VexError.self) { try auto.setRestLine(.nan) }
            #expect(staveNote(["c/4"], "q", restLine: 1).staveInitError == .badRestPosition)
        }
    }

    // MARK: - Bravura slash stems (engraving-layout-tests.mjs)

    @Test func bravuraSlashStemsMeetThePublishedAnchors() throws {
        try isolated {
            Flow.setFonts("Bravura", "Academico")
            let (f, ctx) = makeFactory()
            let anchors: [String: (up: (Double, Double), down: (Double, Double))] = [
                Glyphs.noteheadSlashVerticalEnds: ((1.46, 0.656), (0, -0.664)),
                Glyphs.noteheadSlashWhiteHalf: ((3.12, 1), (0, -1)),
            ]
            for duration in ["q", "8", "h"] {
                for direction in [StemDirection.up, .down] {
                    let note = staveNote(["b/4"], duration, stem: direction, type: "s")
                    let stave = f.Stave(x: 10, y: 60, width: 240)
                    try Formatter.FormatAndDraw(ctx: ctx, stave: stave, notes: [note])
                    let head = note.noteHeads[0]
                    let anchor = try #require(anchors[head.text])
                    let (x, y) = direction == .up ? anchor.up : anchor.down
                    let space = head.fontSizeInPixels / 4
                    let stem = try #require(note.getStem()).getSegment()
                    #expect(abs(stem.x - (note.getNoteHeadBeginX() + head.getXShift() + x * space
                        - direction.signDouble * Stem.WIDTH / 2)) < 1e-9)
                    #expect(abs(stem.baseY - (head.getY() - y * space)) < 1e-9)
                }
            }
            // Another first family does not use the Bravura anchors.
            var value = StaveNoteStruct(parsingDuration: "q", keys: ["b/4"], type: "s", stemDirection: .up)!
            value.musicFont = "Petaluma, Bravura"
            let note = StaveNote(value)
            try Formatter.FormatAndDraw(ctx: ctx, stave: f.Stave(x: 10, y: 60, width: 240), notes: [note])
            #expect(try #require(note.getStem()).getSegment().baseY == note.noteHeads[0].getY())
        }
    }

    // MARK: - Rehearsal frames and tie text (local-engraving-tests.mjs)

    @Test func sectionFrameMatchesItsBoundingBoxAndTieTextRestoresTheFont() throws {
        try isolated {
            Flow.setFonts("Bravura", "Academico")
            let ctx = SVGRenderContext(width: 400, height: 200)
            let stave = Stave(x: 20, y: 80, width: 350)
            _ = stave.setContext(ctx)
            _ = stave.setSection("Bridge", y: 0)
            let label = try #require(stave.getModifiers().last as? StaveSection)
            for (dx, dy) in [(0.0, 0.0), (17.0, -9.0)] {
                _ = label.setXShift(dx).setYShift(dy)
                let before = try #require(label.getBoundingBox())
                try label.draw()
                let m = label.getTextMetrics()
                let ink = label.getTextInk(label.getX(), label.getY())
                #expect(abs(ink.x - before.x - label.padding) < 1e-9)
                #expect(abs(before.w - (m.actualBoundingBoxLeft + m.actualBoundingBoxRight + 2 * label.padding)) < 1e-9)
            }
            let note = StaveNote(StaveNoteStruct(parsingDuration: "q", keys: ["c/4"])!)
            _ = note.setStave(stave)
            for tie in [StaveTie(notes: TieNotes(firstNote: note), text: "H"), TabTie(notes: TieNotes(firstNote: note), text: "H")] {
                _ = tie.setContext(ctx)
                for size in [8.0, 32.0] {
                    _ = ctx.setFont("monospace", size, nil, nil)
                    let previous = ctx.getFont()
                    try tie.renderTieText(firstX: 30, lastX: 140)
                    #expect(ctx.getFont() == previous)
                }
            }
        }
    }

    // MARK: - EasyScore composition (easyscore-tests.mjs, publication-tests.mjs)

    @Test func hiddenMeterChangesStaySilentAndCanBeRevealed() throws {
        try isolated {
            let (f, _) = makeFactory()
            let spec = EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "melody", time: .meter(2, 4), measures: [
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("C4/h")]),
                    EasyScoreMeasureSpec(time: .meter(6, 8), voices: [EasyScoreVoiceSpec("D4/q., G4/q.")], showTimeSignature: false),
                    EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("F4/q., D4/q.")], showTimeSignature: true),
                ])],
                continuous: ContinuousOptions(boundaries: [ContinuousBoundary(measure: 2, breakBefore: .force)])
            )
            let score = try f.EasyScore().compose(spec)
            _ = try score.sheet.format()
            #expect(score.staves.map { $0[0].getModifiers().filter { $0 is TimeSignature }.count } == [1, 0, 1])
        }
    }

    @Test func invalidLeadMarkAnchorsRestoreACallerOwnedNote() throws {
        try isolated {
            let (f, _) = makeFactory()
            let easyScore = f.EasyScore()
            let note = try easyScore.make.note(StaveNoteStruct(parsingDuration: "w", keys: ["c/4"])!)
            try note.setAttributeThrowing("id", "owned")
            let existing = try easyScore.make.annotation(text: "dolce")
            _ = try easyScore.attach(note, existing)
            let spec = EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "melody", measures: [
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [.tickable(note)])],
                                     chords: [EasyScoreLeadMark(note: "owned", text: "C")]),
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("D4/w")],
                                     verses: [[EasyScoreLyricMark(note: "owned", text: "wrong bar")]]),
            ])])
            #expect(throws: VexError.self) { _ = try easyScore.compose(spec) }
            #expect(note.getModifiers().count == 1 && note.getModifiers()[0] === existing)
            #expect(note.getStave() == nil)
        }
    }

    @Test func leadMarksAndEndBarlinesBuildNativeLanes() throws {
        try isolated {
            let (f, _) = makeFactory()
            let spec = EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "melody", measures: [
                EasyScoreMeasureSpec(
                    voices: [EasyScoreVoiceSpec(#"C4/h[id="a"], E4/h[id="b"]"#)],
                    endBarline: .double,
                    chords: [EasyScoreLeadMark(note: "a", text: "C"), EasyScoreLeadMark(note: "b", text: "Am")],
                    verses: [[EasyScoreLyricMark(note: "a", text: "Hel", hyphenAfter: true), EasyScoreLyricMark(note: "b", text: "lo")]]
                ),
            ])])
            let score = try f.EasyScore().compose(spec)
            let a = try score.getNote("a")
            let texts = a.getModifiers().compactMap { ($0 as? Annotation)?.getText() }
            #expect(texts.contains("C") && texts.contains("Hel"))
            let chord = try #require(a.getModifiers().compactMap { $0 as? Annotation }.first { $0.getText() == "C" })
            #expect(chord.fontInfo.size == Metrics.getFontInfo("ChordSymbol").size)
            let bar = score.staves[0][0].getModifiers(position: .end, category: Barline.category).first as? Barline
            #expect(bar?.getType() == .double)
        }
    }

    @Test func structuredNotesAndRhythmicTabEngraveWrittenDots() throws {
        try isolated {
            let (f, _) = makeFactory()
            let positions = [TabNotePosition(str: 1, fret: 12), TabNotePosition(str: 2, fret: 10)]
            func notes(_ kind: EasyScoreStaveKind) -> [EasyScoreContent] {
                ([1, 2] as [Int]).map { dots in
                    kind == .tab
                        ? .tab(TabNoteStruct(positions: positions, duration: .quarter, dots: dots), id: "tab\(dots)", drawStem: true)
                        : .note(StaveNoteStruct(parsingDuration: "q", keys: ["c/4", "e/4"], dots: dots)!, id: "stave\(dots)")
                }
            }
            let spec = EasyScoreCompositionSpec(staves: [EasyScoreStaveKind.stave, .tab].map { kind in
                EasyScoreStaveSpec(
                    id: kind == .tab ? "tab" : "stave", kind: kind, time: TimeSignatureSpec(parsing: "13/16"),
                    measures: [EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: notes(kind))])]
                )
            })
            let score = try f.EasyScore().compose(spec)
            func dots(_ id: String) throws -> Int { try score.getNote(id).getModifiers().filter { $0 is Dot }.count }
            #expect(try dots("stave1") == 2)
            #expect(try dots("stave2") == 4)
            #expect(try dots("tab1") == 1)
            #expect(try dots("tab2") == 2)
            #expect(try score.getNote("stave2").writtenDots == 2)
        }
    }

    // MARK: - Continuous layout (continuous-score-tests.mjs)

    @Test func tabTiesStayOnTheSelectedStringThroughReflow() throws {
        try isolated {
            let selectors: [(string: Int?, fromHead: Int?, toHead: Int?)] = [
                (2, nil, nil), (nil, 1, nil), (nil, nil, 0), (nil, 1, 0), (nil, nil, nil),
            ]
            for selector in selectors {
                let tie = ContinuousSpan(
                    id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: selector.fromHead,
                    toHead: selector.toHead, string: selector.string
                )
                let string = selector == (nil, nil, nil) ? 1 : 2
                let (f, _) = makeFactory()
                let score = try f.EasyScore().compose(tabEndingStudy(tie))
                let layout = try #require(score.sheet.getContinuousLayout())
                func frame(_ width: Double) throws -> [SpanFragment] {
                    _ = try score.sheet.setWidth(width)
                    try f.draw(retain: true)
                    #expect(layout.diagnostics.isEmpty)
                    return layout.fragments
                }
                let wide = try frame(420)
                #expect(wide.map(\.part) == [.single, .single])
                let narrow = try frame(122)
                for kind in [ContinuousSpanKind.tie, .volta] {
                    #expect(narrow.filter { $0.kind == kind }.map(\.part) == [.first, .last])
                }
                for fragment in narrow where fragment.kind == .tie {
                    let stave = score.staves[fragment.row][0]
                    #expect(fragment.strings == [string])
                    #expect(fragment.x2 - fragment.x1 >= stave.space(1))
                    let line = stave.getYForLine(Double(string - 1))
                    #expect(fragment.y1 < line && fragment.y1 > line - stave.space(0.5))
                    #expect(fragment.y1 == fragment.y2)
                }
                #expect(try frame(420) == wide)
            }
        }
    }

    @Test func tabTiesRejectUnmatchedStringsAndFrets() {
        isolated {
            let invalid: [ContinuousSpan] = [
                ContinuousSpan(id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: 1, string: 7),
                ContinuousSpan(id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: 1, string: 3),
                ContinuousSpan(id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: -1),
                ContinuousSpan(id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: 1, toHead: 2),
                ContinuousSpan(id: "hold", kind: .tie, from: "tab0", to: "tab1", fromHead: 1, toHead: 1),
            ]
            for span in invalid {
                #expect(throws: VexError.self) { _ = try makeFactory().f.EasyScore().compose(tabEndingStudy(span)) }
            }
        }
    }

    @Test func anchoredLyricExtenderResolvesItsSyllable() throws {
        try isolated {
            func compose(_ span: ContinuousSpan) throws -> (Factory, EasyScoreComposition) {
                let (f, _) = makeFactory()
                let spec = EasyScoreCompositionSpec(
                    staves: [EasyScoreStaveSpec(id: "v", measures: [
                        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(#"C4/w[id="n0"]"#)]),
                        EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(#"D4/w[id="n1"]"#)]),
                    ])],
                    continuous: ContinuousOptions(spans: [span])
                )
                return (f, try f.EasyScore().compose(spec))
            }
            let span = ContinuousSpan(id: "hold", kind: .lyric, from: "n0", to: "n1", syllableId: "word")
            for bad in [
                ContinuousSpan(id: "hold", kind: .lyric, from: "n0", to: "n1", text: "duplicate", syllableId: "word"),
                ContinuousSpan(id: "hold", kind: .tie, from: "n0", to: "n1", syllableId: "word"),
                ContinuousSpan(id: "hold", kind: .lyric, from: "n0", to: "n1", syllableId: ""),
            ] {
                #expect(throws: VexError.self) { _ = try compose(bad) }
            }
            let (_, c) = try compose(span)
            #expect(throws: VexError.self) { _ = try c.sheet.setWidth(600).format() }
            let source = try c.getNote("n0")
            func word() throws -> Annotation {
                let a = Annotation("word")
                try a.setAttributeThrowing("id", "word")
                return a
            }
            _ = source.addModifier(try word(), index: 0)
            _ = try c.sheet.setWidth(600).format()
            let fragment = try #require(c.sheet.getContinuousLayout()?.fragments.first { $0.id == "hold" })
            #expect(fragment.x2 > fragment.x1)
            _ = source.addModifier(try word(), index: 0)
            #expect(throws: VexError.self) { _ = try c.sheet.setWidth(600).format() }
        }
    }

    @Test func authoredRestStaysVisibleAndBreaksACompressedRun() throws {
        try isolated {
            let measures = (0..<3).map { i in
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [
                    .note({ var v = StaveNoteStruct(parsingDuration: "wr", keys: ["r/4"])!; if i == 1 { v.restLine = 0 }; return v }()),
                ])])
            }
            let (f, _) = makeFactory()
            let score = try f.EasyScore().compose(EasyScoreCompositionSpec(
                staves: [EasyScoreStaveSpec(id: "rest", measures: measures)],
                continuous: ContinuousOptions(hideEmptyStaves: true, compressRests: true)
            ))
            _ = try score.sheet.format()
            #expect(score.sheet.getContinuousLayout()?.rows.flatMap(\.restGroups).isEmpty == true)
        }
    }

    @Test func lyricSpanLabelsUseTheLyricSizeOrAnExplicitSize() {
        isolated {
            let lyric = spanLabel(ContinuousSpan(id: "l", kind: .lyric, from: "a", to: "b", text: "la"))
            #expect(lyric?.fontSizeInPoints == 12)
            let sized = spanLabel(ContinuousSpan(id: "l", kind: .lyric, from: "a", to: "b", text: "la", labelFontSize: 15))
            #expect(sized?.fontSizeInPoints == 15)
            let volta = spanLabel(ContinuousSpan(id: "v", kind: .volta, from: "a", to: "b"))
            #expect(volta?.fontSizeInPoints == 10)
        }
    }

    // MARK: - Publication (publication-tests.mjs, 5.5.0)

    @Test func publicationAppliesNoteHooksToEveryView() throws {
        try isolated {
            let source = EasyScoreCompositionSpec(staves: [EasyScoreStaveSpec(id: "fl", measures: [
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(#"C5/q[mark="yes"], D5, E5, F5"#)]),
            ])])
            var calls = 0
            let hook: CommitHook = { options, note, _ in
                if options["mark"] == "yes" {
                    calls += 1
                    note.addModifier(Annotation("cue"), index: 0)
                }
            }
            let options = PublicationOptions(staves: ["fl"], noteHooks: [hook])
            let result = try Publication(source).render(options)
            #expect(calls >= 1)
            #expect((1...result.pages.count).contains { (try? result.toSVG($0))?.contains(">cue<") == true })
            #expect(options != PublicationOptions(staves: ["fl"]))
        }
    }
}
