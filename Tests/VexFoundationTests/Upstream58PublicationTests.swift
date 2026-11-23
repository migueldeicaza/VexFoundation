// Logic-level tests for the publication behaviors ported from VexFlow 5.7.0 → 5.8.0 (group "Publication").
// Ported from the 5.8.0 assertions in tests/node/publication-tests.mjs, with the studies of
// tests/engraving/publication-studies.mjs and `sextupletStudy` of tests/engraving/continuous-studies.mjs.
// Upstream renders in a browser and reads the DOM (`querySelector`, `getBoundingClientRect`). These tests read
// the native `SVGNode` page trees. Screen rectangles become ink boxes (`svgInkBox`) with the transforms of the
// ancestor groups applied.

import CoreGraphics
import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func note(_ keys: [String], _ duration: String, id: String? = nil) -> EasyScoreContent {
    // The test inputs are valid literals.
    .note(StaveNoteStruct(parsingDuration: duration, keys: keys)!, id: id)
}

private func metadata(_ page: PublicationPage) throws -> [String: Any] {
    let text = try #require(page.metadata)
    return try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

private func hasClass(_ node: SVGNode, _ name: String) -> Bool {
    (node.getAttribute("class") ?? "").split(separator: " ").contains { $0 == name }
}

private func elements(_ root: SVGNode, _ cls: String) -> [SVGNode] {
    root.descendants().filter { hasClass($0, cls) }
}

/// The text of `node` and its descendants (DOM `textContent`).
private func allText(_ node: SVGNode) -> String {
    (node.textContent ?? "") + node.children.map(allText).joined()
}

/// A page-space ink box: `svgInkBox` with the transforms of the ancestors below the page root.
private func pageBox(_ node: SVGNode) throws -> BoundingBox? {
    guard var box = try svgInkBox(node) else { return nil }
    var ancestor = node.parent
    while let p = ancestor, p.name != "svg" {
        if let m = svgTransform(p) {
            let corners = [
                CGPoint(x: box.x, y: box.y), CGPoint(x: box.x + box.w, y: box.y + box.h),
            ].map { $0.applying(m) }
            let x = corners.map { Double($0.x) }.min()!, y = corners.map { Double($0.y) }.min()!
            box = BoundingBox(
                x: x, y: y, w: corners.map { Double($0.x) }.max()! - x, h: corners.map { Double($0.y) }.max()! - y
            )
        }
        ancestor = p.parent
    }
    return box
}

/// Compare decoded JSON values.
private func same(_ a: Any, _ b: Any) -> Bool {
    (a as AnyObject).isEqual(b)
}

// MARK: - Studies

/// `condensedFlutesStudy()`: two flute desks pass from solo to unison and then divide over the same three bars.
private func condensedFlutesStudy() -> (source: EasyScoreCompositionSpec, condense: PublicationCondense) {
    let pitches: [[[String]]] = [
        [["g/4", "a/4"], ["b/4", "c/5"], ["d/5", "c/5"]],
        [[], ["b/4", "c/5"], ["b/4", "a/4"]],
    ]
    let staves = pitches.enumerated().map { player, bars in
        EasyScoreStaveSpec(
            id: "fl\(player + 1)", time: .meter(2, 4),
            measures: bars.enumerated().map { bar, keys in
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(
                    notes: (keys.isEmpty ? ["b/4"] : keys).enumerated().map { attack, key in
                        note([key], keys.isEmpty ? "hr" : "q", id: "f\(player + 1)m\(bar + 1)n\(attack + 1)")
                    }
                )])
            },
            name: "Flute \(player + 1)"
        )
    }
    return (EasyScoreCompositionSpec(staves: staves), PublicationCondense(players: ["fl1", "fl2"], name: "Flutes"))
}

/// `ossiaRangeStudy()`: an independent source supplies two bars of eighth notes above the printed quarter notes.
private func ossiaRangeStudy() -> (source: EasyScoreCompositionSpec, options: PublicationOptions) {
    func staff(_ id: String, _ bars: [String]) -> EasyScoreStaveSpec {
        EasyScoreStaveSpec(
            id: id, time: .meter(3, 4),
            measures: bars.enumerated().map { m, keys in
                let notes = keys.split(separator: " ").map(String.init)
                return EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(
                    notes: notes.enumerated().map { i, key in
                        note([key + "/4"], notes.count == 6 ? "8" : "q", id: "\(id)-\(m + 1)-\(i + 1)")
                    },
                    autoBeam: EasyScoreAutoBeamOptions()
                )])
            }
        )
    }
    let source = EasyScoreCompositionSpec(staves: [
        staff("melody", ["c d e", "a g e", "f e d", "c e c"]),
        staff("alternate", ["c d e", "a b a g f e", "f g f e d c", "c e c"]),
    ])
    let options = PublicationOptions(
        staves: ["melody"],
        regions: [PublicationRegion(kind: .ossia, staff: "alternate", measure: 2, label: "Ossia", endMeasure: 3)],
        paper: .custom(width: 195, height: 130),
        margins: PublicationMargins(top: 7, right: 7, bottom: 7, left: 7),
        pageNumbers: false
    )
    return (source, options)
}

/// `transposedCueStudy()`: a clarinet quotes a flute in its written key while it keeps its whole rest.
private func transposedCueStudy() -> (source: EasyScoreCompositionSpec, options: PublicationOptions) {
    let source = EasyScoreCompositionSpec(
        staves: [
            EasyScoreStaveSpec(id: "fl", key: "C", measures: [
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("E4/q, F4, G4, A4")]),
            ]),
            EasyScoreStaveSpec(id: "cl", key: "D", measures: [
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [note(["b/4"], "wr", id: "silence")])]),
            ]),
        ],
        accidentals: .keyAware
    )
    let region = PublicationRegion(
        kind: .cue, staff: "fl", measure: 1, label: "Flute", scale: 0.7,
        transpose: CueTransposition(semitones: 2, steps: 1)
    )
    let options = PublicationOptions(
        staves: ["cl"], regions: [region], paper: .custom(width: 120, height: 65),
        margins: PublicationMargins(top: 5, right: 4, bottom: 4, left: 4), pageNumbers: false
    )
    return (source, options)
}

/// `sextupletStudy()` of continuous-studies.mjs: six written eighths on beat four and the following downbeat.
private func sextupletStudy() -> EasyScoreCompositionSpec {
    let pitches = ["g/4", "a/4", "b/4", "c/5", "b/4", "a/4"]
    let member = { (i: Int) in note([pitches[i]], "8", id: "t\(i)") }
    return EasyScoreCompositionSpec(
        staves: [EasyScoreStaveSpec(id: "flute", time: .meter(4, 4), measures: [
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [.notation("G4/q, A4/q, B4/q")] + (0...2).map(member))]),
            EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(
                notes: (3...5).map(member) + [note(["g/4"], "q", id: "next"), .notation("F4/q, G4/q")]
            )]),
        ])],
        sheet: SheetOptions(width: 530, rowGap: 18),
        continuous: ContinuousOptions(
            tuplets: [ContinuousTuplet(id: "six", members: (0...5).map { "t\($0)" }, numNotes: 6, notesOccupied: 4)]
        )
    )
}

// MARK: - Tests

@Suite("Upstream 5.8.0 port: publication")
struct Upstream58PublicationTests {

    // MARK: Condensing

    private struct CondensedView {
        var notes: [(id: String, heads: Int, stem: String?)]
        var labels: [String]
        var events: [[String: Any]]
        var measures: [Int]
        var systems: [[Int]]
        var staves: [String]
        var diagnostics: [PublicationDiagnostic]

        func same(_ other: CondensedView) -> Bool {
            notes.map { "\($0.id) \($0.heads) \($0.stem ?? "-")" } == other.notes.map { "\($0.id) \($0.heads) \($0.stem ?? "-")" }
                && labels == other.labels && measures == other.measures && systems == other.systems
                && staves == other.staves && diagnostics == other.diagnostics
                && (events as NSArray).isEqual(to: other.events)
        }
    }

    private func condensedView(_ book: Publication, _ options: PublicationOptions) throws -> CondensedView {
        let result = try book.render(options)
        let roots = result.pages.map { $0.svg }
        let meta = try result.pages.map(metadata)
        return CondensedView(
            notes: roots.flatMap { s in
                elements(s, "vf-stavenote").map { n in
                    (
                        n.getAttribute("data-vf-id") ?? "",
                        elements(n, "vf-notehead").count,
                        elements(n, "vf-stem").flatMap { $0.descendants() }.first { $0.name == "path" }?.getAttribute("d")
                    )
                }
            },
            labels: roots.flatMap { s in
                s.descendants().filter { $0.name == "text" }.compactMap { $0.textContent }.filter { ["1.", "2.", "a2"].contains($0) }
            },
            events: meta.flatMap { $0["events"] as? [[String: Any]] ?? [] },
            measures: meta.flatMap { $0["measures"] as? [Int] ?? [] },
            systems: result.pages.flatMap { $0.systems.map { $0.measures } },
            staves: meta.first?["staves"] as? [String] ?? [],
            diagnostics: result.diagnostics
        )
    }

    @Test func twoFlutePlayersRetainTheirIndividualAttacksInACondensedConductorPassage() throws {
        try isolated {
            let (source, condense) = condensedFlutesStudy()
            let book = Publication(source)
            let wide = try condensedView(book, PublicationOptions(condense: condense))
            let narrow = try condensedView(book, PublicationOptions(paper: .custom(width: 77, height: 190), condense: condense))
            var passageRequest = condense
            passageRequest.measures = [2, 3]
            let passage = try condensedView(book, PublicationOptions(condense: passageRequest))
            let first = try condensedView(book, PublicationOptions(staves: ["fl1"]))
            let second = try condensedView(book, PublicationOptions(staves: ["fl2"]))
            let restored = try condensedView(book, PublicationOptions(condense: condense))
            #expect(wide.same(restored))
            #expect(wide.staves == ["fl1"])
            #expect(wide.systems == [[1, 2, 3]])
            #expect(narrow.systems.count > 1)
            for view in [wide, narrow] {
                #expect(view.diagnostics == [])
                #expect(view.labels == ["1.", "a2"])
                #expect((view.events.filter { $0["staff"] as? String == "fl1" } as NSArray).isEqual(to: first.events))
                #expect((view.events.filter { $0["staff"] as? String == "fl2" } as NSArray).isEqual(to: second.events))
                #expect(view.notes.map { $0.id }.sorted() == [
                    "vf-f1m1n1", "vf-f1m1n2", "vf-f1m2n1", "vf-f1m2n2", "vf-f1m3n1", "vf-f1m3n2", "vf-f2m3n1", "vf-f2m3n2",
                ].sorted())
                #expect(view.notes.allSatisfy { $0.heads == 1 && $0.stem != nil })
                for note in view.notes where note.id.contains("m3") {
                    let coords = try numbers(try #require(note.stem))
                    #expect(coords.count >= 4)
                    if coords.count >= 4 {
                        #expect((coords[3] - coords[1]).sign == (note.id.contains("f1m") ? .minus : .plus), "\(note)")
                    }
                }
            }
            #expect(second.events.filter { $0["measure"] as? Int == 1 }.map { $0["rest"] as? Bool } == [true])
            #expect(passage.measures == [2, 3])
            #expect(passage.labels == ["a2"])
            #expect((passage.events as NSArray).isEqual(to: wide.events.filter { ($0["measure"] as? Int ?? 0) >= 2 }))
        }
    }

    @Test func invalidCondensingRequestsAreRejected() throws {
        try isolated {
            let (source, condense) = condensedFlutesStudy()
            let book = Publication(source)
            for request in [
                PublicationCondense(players: ["fl1", "fl2"], measures: [3, 2]),
                PublicationCondense(players: ["fl1", "fl2"], measures: [0, 2]),
                PublicationCondense(players: ["fl1", "fl1"]),
                PublicationCondense(players: ["fl1"]),
            ] {
                #expect(throws: VexError.self) { _ = try book.render(PublicationOptions(condense: request)) }
            }
            // A condensed passage needs both players in the printed view.
            #expect(throws: VexError.self) {
                _ = try book.render(PublicationOptions(staves: ["fl1"], condense: condense))
            }
        }
    }

    // MARK: Tuplets in parts

    @Test func extractedPartsRetainOnlyTheRhythmicTupletsBelongingToTheirStaff() throws {
        try isolated {
            var source = sextupletStudy()
            source.staves.append(EasyScoreStaveSpec(id: "bass", measures: [1, 2].map { _ in
                EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("C3/w")])
            }))
            let book = Publication(source)
            let frames = try ["flute", "bass"].map { staff in
                let printed = try book.render(PublicationOptions(staves: [staff], systemBreaks: [2]))
                return try printed.pages.flatMap { try metadata($0)["spans"] as? [[String: Any]] ?? [] }
            }
            #expect(frames[0].map { "\($0["id"] ?? "") \($0["part"] ?? "")" } == ["six first", "six last"])
            #expect(frames[1].isEmpty)
        }
    }

    // MARK: Transposed cue

    private struct Quote {
        var keys: [String]
        var ticks: [String]
        var rest: Bool?
        var label: String?
        var transform: String?
        var sharps: Int
        var naturals: Int
        var diagnostics: [PublicationDiagnostic]
    }

    private func quote(_ book: Publication, _ options: PublicationOptions) throws -> Quote {
        let result = try book.render(options)
        let svg = result.pages[0].svg
        let group = try #require(svg.descendants().first { $0.getAttribute("data-region") == "cue" })
        let meta = try metadata(result.pages[0])
        let regions = meta["regions"] as? [[String: Any]] ?? []
        let events = regions.first?["events"] as? [[String: Any]] ?? []
        let text = allText(group)
        return Quote(
            keys: events.map { (($0["keys"] as? [String])?.first ?? "").lowercased() },
            ticks: events.map { $0["ticks"] as? String ?? "" },
            rest: (meta["events"] as? [[String: Any]])?.first?["rest"] as? Bool,
            label: group.children.first { $0.name == "text" }?.textContent,
            transform: group.descendants().first { $0.name == "g" && $0.getAttribute("transform") != nil }?.getAttribute("transform"),
            sharps: text.filter { String($0) == Glyphs.accidentalSharp }.count,
            naturals: text.filter { String($0) == Glyphs.accidentalNatural }.count,
            diagnostics: result.diagnostics
        )
    }

    @Test func aTransposedFluteCueFollowsTheClarinetSignatureAndRegeneratesFromSource() throws {
        try isolated {
            var (source, options) = transposedCueStudy()
            let original = try quote(Publication(source), options)
            source.staves[0].measures[0].voices[0].notes = ["e/4", "f/4", "g/4", "bb/4"].map { note([$0], "q") }
            let book = Publication(source)
            let edited = try quote(book, options)
            let concert = try metadata(try book.render(PublicationOptions(staves: ["fl"])).pages[0])
            #expect(original.keys == ["f#/4", "g/4", "a/4", "b/4"])
            #expect(edited.keys == ["f#/4", "g/4", "a/4", "c/5"])
            #expect((concert["events"] as? [[String: Any]] ?? []).map { ($0["keys"] as? [String])?.first ?? "" }
                == ["e/4", "f/4", "g/4", "bb/4"])
            for quote in [original, edited] {
                #expect(quote.diagnostics == [])
                #expect(quote.rest == true)
                #expect(quote.label == "Flute")
                #expect(quote.transform?.contains("scale(0.7)") == true)
                #expect(quote.ticks == Array(repeating: "4096/1", count: 4))
                #expect(quote.sharps == 2)
            }
            #expect(original.naturals == 0)
            #expect(edited.naturals == 1)
            // A transposition is for cues only.
            options.regions[0].kind = .ossia
            #expect(throws: VexError.self) { _ = try book.render(options) }
        }
    }

    @Test func writtenCueTransposesTypedNotesGraceAccidentalsKeysAndChords() throws {
        let interval = CueTransposition(semitones: 2, steps: 1)
        let grace = EasyScoreGraceGroupSpec(side: .before, notes: [
            EasyScoreGracePitchSpec(
                GraceNoteStruct(keys: NonEmptyArray(try StaffKeySpec(parsing: "b/4")), duration: .eighth),
                accidentals: [EasyScoreGraceAccidental(index: 0, type: "b")]
            ),
        ])
        let staff = EasyScoreStaveSpec(id: "fl", key: "F", measures: [
            EasyScoreMeasureSpec(
                key: "Bb",
                voices: [EasyScoreVoiceSpec(notes: [
                    .note(StaveNoteStruct(parsingDuration: "q", keys: ["c/4/x2"])!, id: "a", grace: grace),
                    note(["b/4"], "qr"),
                    .change(EasyScoreStaffState(key: "Eb")),
                    .notation("C4/h"),
                ])],
                chords: [EasyScoreLeadMark(note: "a", harmony: ChordHarmony(root: "B", quality: "m7"))]
            ),
        ])
        let written = try writtenCue(staff, interval)
        #expect(written.key == "G")
        #expect(written.measures[0].key == "C")
        #expect(written.measures[0].chords[0].harmony?.root == "C#")
        let notes = written.measures[0].voices[0].notes
        guard case .note(let first, _, _, let g?) = notes[0] else { Issue.record("expected a typed note"); return }
        #expect(first.keys.map { $0.rawValue } == ["d/4/x2"])
        // The head and its explicit sign are spelled independently, as upstream.
        #expect(g.notes[0].note.keys.map { $0.rawValue } == ["c#/5"])
        #expect(g.notes[0].accidentals[0].type == "n")
        guard case .note(let rest, _, _, _) = notes[1] else { Issue.record("expected a rest"); return }
        #expect(rest.keys.map { $0.rawValue } == ["b/4"])
        guard case .change(let change) = notes[2] else { Issue.record("expected a change"); return }
        #expect(change.key == "F")
        guard case .notation(let text) = notes[3] else { Issue.record("expected notation"); return }
        #expect(text == "C4/h")
        #expect(throws: VexError.self) {
            var tab = staff
            tab.measures[0].voices[0].notes = [.tab(TabNoteStruct(parsingDuration: "q", positions: [TabNotePosition(str: 1, fret: 0)])!)]
            _ = try writtenCue(tab, interval)
        }
    }

    // MARK: Ranged ossia

    private struct OssiaView {
        var diagnostics: [PublicationDiagnostic]
        var aligned: Bool
        var widths: [Double]
        var exported: Bool
        var ranges: [[Int?]]
        var noteCounts: [Int]
        var labels: [String]
        var main: [String]
        var alternate: [String]
        var x: [Double]
        var metadata: [String]

        func same(_ o: OssiaView) -> Bool {
            diagnostics == o.diagnostics && aligned == o.aligned && widths == o.widths && exported == o.exported
                && ranges == o.ranges && noteCounts == o.noteCounts && labels == o.labels && main == o.main
                && alternate == o.alternate && x == o.x && metadata == o.metadata
        }
    }

    private func ossiaView(_ book: Publication, _ options: PublicationOptions) throws -> OssiaView {
        let result = try book.render(options)
        let sections = result.pages.flatMap { p in p.svg.descendants().filter { $0.getAttribute("data-region") != nil } }
        let meta = try result.pages.map(metadata)
        var offsets: [[Double]] = []
        for section in sections {
            var system = section.parent
            while let s = system, s.getAttribute("data-system") == nil { system = s.parent }
            let host = try #require(system)
            let hostStaves = elements(try #require(host.children.last), "vf-stave")
            let index = Int(section.getAttribute("data-measure") ?? "0")! - Int(host.getAttribute("data-system") ?? "0")!
            for (i, staff) in elements(section, "vf-stave").enumerated() {
                let inset = try #require(try pageBox(staff))
                let target = try #require(try pageBox(hostStaves[index + i]))
                offsets.append([inset.x - target.x, (inset.x + inset.w) - (target.x + target.w)])
            }
        }
        let exported = try result.pages.allSatisfy { page in
            let svg = try result.toSVG(page.number, portable: true)
            let text = try #require(page.metadata).replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            // Upstream counts the noteheads inside the regions of the parsed export. Here all noteheads are counted.
            let heads = page.svg.descendants().filter { hasClass($0, "vf-notehead") }.count
            return svg.contains("<metadata>" + text + "</metadata>")
                && svg.components(separatedBy: "class=\"vf-notehead\"").count - 1 == heads
        }
        return OssiaView(
            diagnostics: result.diagnostics,
            aligned: offsets.allSatisfy { $0.allSatisfy { abs($0) < 0.01 } },
            widths: try sections.flatMap { el in try elements(el, "vf-stave").map { try pageBox($0)?.w ?? 0 } },
            exported: exported,
            ranges: sections.map { [Int($0.getAttribute("data-measure") ?? ""), Int($0.getAttribute("data-end-measure") ?? "")] },
            noteCounts: sections.map { elements($0, "vf-stavenote").count },
            labels: sections.flatMap { $0.children.filter { $0.name == "text" }.compactMap { $0.textContent } },
            main: meta.flatMap { $0["events"] as? [[String: Any]] ?? [] }.map {
                "\($0["id"] ?? "") \(($0["keys"] as? [String]) ?? []) \($0["ticks"] ?? "")"
            },
            alternate: meta.flatMap { $0["regions"] as? [[String: Any]] ?? [] }.flatMap { r in
                (r["events"] as? [[String: Any]] ?? []).map { "\($0["measure"] ?? "") \($0["id"] ?? "")" }
            },
            x: try sections.flatMap { el in try elements(el, "vf-notehead").map { try pageBox($0)?.x ?? 0 } },
            metadata: result.pages.compactMap { $0.metadata }
        )
    }

    @Test func aRangedOssiaAlignsEachBarContinuesOnTheNextSystemAndRestoresItsLayout() throws {
        try isolated {
            var (source, options) = ossiaRangeStudy()
            var book = Publication(source)
            var controlOptions = options
            controlOptions.regions = []
            let control = try ossiaView(book, controlOptions)
            let wide = try ossiaView(book, options)
            var splitOptions = options
            splitOptions.paper = .custom(width: 150, height: 130)
            splitOptions.systemBreaks = [3]
            let split = try ossiaView(book, splitOptions)
            var pageOptions = options
            pageOptions.pageBreaks = [3]
            let pages = try ossiaView(book, pageOptions)
            let restored = try ossiaView(book, options)
            let invalid = [1, 5].map { endMeasure in
                var bad = options
                bad.regions[0].endMeasure = endMeasure
                return (try? book.render(bad)) == nil
            }
            // An end measure is for an ossia only.
            var cue = options
            cue.regions[0].kind = .cue
            // Unequal intrinsic widths prevent an equal division of the inset from passing the alignment check.
            source.staves[0].measures[2] = EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec("F4/8, G4/8, F4/8, E4/8, D4/8, C4/8")])
            book = Publication(source)
            let uneven = try ossiaView(book, options)
            // Rests under an alternate line still need individually aligned measures.
            source.continuous = ContinuousOptions(compressRests: true)
            let rests = EasyScoreMeasureSpec(voices: [EasyScoreVoiceSpec(notes: [note(["b/4"], "hr"), note(["b/4"], "qr")])])
            source.staves[0].measures = [rests, rests, rests, rests]
            book = Publication(source)
            let resting = try ossiaView(book, options)

            #expect(wide.ranges == [[2, 3]])
            #expect(wide.noteCounts == [12])
            #expect(split.ranges == [[2, 2], [3, 3]])
            #expect(split.noteCounts == [6, 6])
            #expect(pages.ranges == split.ranges)
            #expect(pages.noteCounts == split.noteCounts)
            #expect(wide.same(restored))
            #expect(uneven.aligned && uneven.widths.count == 2 && abs(uneven.widths[0] - uneven.widths[1]) > 1, "\(uneven.widths)")
            #expect(resting.aligned && resting.exported)
            #expect(resting.alternate == wide.alternate)
            #expect(resting.noteCounts == [12])
            let alternate = [2, 3].flatMap { m in (1...6).map { "\(m) alternate-\(m)-\($0)" } }
            for (name, view) in [("wide", wide), ("split", split), ("pages", pages)] {
                #expect(view.aligned && view.exported, "\(name)")
                #expect(view.diagnostics == [], "\(name)")
                #expect(view.labels == ["Ossia"], "\(name)")
                #expect(view.main == control.main, "\(name)")
                #expect(view.alternate == alternate, "\(name)")
            }
            #expect(invalid == [true, true])
            #expect(throws: VexError.self) { _ = try Publication(ossiaRangeStudy().source).render(cue) }
        }
    }

    @Test func sheetAlignToMeasuresChecksItsWidths() throws {
        try isolated {
            let f = Factory(options: FactoryOptions(width: 400, height: 200))
            let sheet = try f.Sheet(options: SheetOptions(width: 380))
            sheet.addSystem()
            sheet.addSystem()
            #expect(throws: VexError.self) { try sheet.alignToMeasures([100]) }
            #expect(throws: VexError.self) { try sheet.alignToMeasures([100, 0]) }
            #expect(throws: VexError.self) { try sheet.alignToMeasures([100, .infinity]) }
            try sheet.alignToMeasures([100, 150])
        }
    }
}

/// The numbers of an SVG path, in order.
private func numbers(_ d: String) throws -> [Double] {
    let regex = try NSRegularExpression(pattern: "-?[\\d.]+")
    return regex.matches(in: d, range: NSRange(d.startIndex..., in: d)).compactMap {
        Range($0.range, in: d).flatMap { Double(d[$0]) }
    }
}
