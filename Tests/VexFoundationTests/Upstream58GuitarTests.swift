// Logic-level tests for the guitar and figured-bass behaviors ported from VexFlow 5.7.0 → 5.8.0.
// Ported from the 5.8.0 assertions in tests/stringnumber_tests.ts (TAB fingerings), tests/figuredbass_tests.ts
// and tests/node/instrument-profile-tests.mjs (chord-frame fingerings). The upstream tests record `fillText`
// calls on a browser context. These tests read the `<text>` elements of the SVG string context instead.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

private func makeFactory(width: Double, height: Double) -> (f: Factory, ctx: SVGRenderContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = SVGRenderContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

/// One `<text>` element of the SVG output. The SVG context rounds `x` and `y`.
private struct DrawnText: Equatable {
    var label: String
    var x: Double
    var y: Double
    var weight: String?
}

private func attribute(_ name: String, in tag: Substring) -> String? {
    guard let range = tag.range(of: " \(name)=\"") else { return nil }
    let rest = tag[range.upperBound...]
    guard let end = rest.firstIndex(of: "\"") else { return nil }
    return String(rest[..<end])
}

private func drawnText(_ svg: String) -> [DrawnText] {
    var result: [DrawnText] = []
    var rest = svg[...]
    while let open = rest.range(of: "<text") {
        guard let close = rest[open.upperBound...].firstIndex(of: ">"),
              let end = rest[close...].range(of: "</text>") else { break }
        let tag = rest[open.lowerBound...close]
        let label = String(rest[rest.index(after: close)..<end.lowerBound])
        result.append(DrawnText(
            label: label,
            x: Double(attribute("x", in: tag) ?? "") ?? .nan,
            y: Double(attribute("y", in: tag) ?? "") ?? .nan,
            weight: attribute("font-weight", in: tag)
        ))
        rest = rest[end.upperBound...]
    }
    return result
}

private func g2() throws -> StaveNoteStruct {
    try StaveNoteStruct(parsingKeys: ["g/2"], duration: "q", clef: .bass)
}

@Suite("Upstream 5.8.0 port: Guitar and figured bass")
struct Upstream58GuitarTests {

    // MARK: - Modifier.getAttachedLine

    @Test func attachedLineUsesHeadLinesAndTabStrings() throws {
        try isolated {
            let tab = TabNote(TabNoteStruct(positions: [
                TabNotePosition(str: 1, fret: 7), TabNotePosition(str: 3, fret: 10),
            ], duration: .quarter))
            let finger = FretHandFinger("1")
            _ = tab.addModifier(finger, index: 1)
            #expect(try finger.getAttachedLine() == -3)

            let wrong = FretHandFinger("2")
            _ = tab.addModifier(wrong, index: 2)
            #expect(throws: VexError.self) { try wrong.getAttachedLine() }

            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/4", "g/4"], duration: "q"))
            let head = FretHandFinger("3")
            _ = note.addModifier(head, index: 1)
            #expect(try head.getAttachedLine() == note.getKeyProps()[1].line)
        }
    }

    // MARK: - stringnumber_tests.ts: TAB fingerings follow selected fret positions

    @Test func tabFingeringsFollowSelectedFretPositions() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 470, height: 150)
            let stave = f.TabStave(x: 5, y: 0, width: 450).addTabGlyph()
            let positions: [[TabNotePosition]] = [
                [TabNotePosition(str: 2, fret: 3)],
                [TabNotePosition(str: 4, fret: 0)],
                [TabNotePosition(str: 1, fret: 7), TabNotePosition(str: 3, fret: 10)],
            ]
            let notes = positions.map { f.TabNote(TabNoteStruct(positions: $0, duration: .quarter)) }
            let finger = f.Fingering(number: "2", drawCircle: true)
            let open = f.Fingering(number: "0", position: .right)
            let thumb = f.Fingering(number: "T", position: .left)
            let string = f.StringNumber(number: "3", position: .right)
            _ = notes[0].addModifier(finger, index: 0)
            _ = notes[1].addModifier(open, index: 0)
            _ = notes[2].addModifier(thumb, index: 1).addModifier(string, index: 1)
            let voice = f.EasyScore().voice(notes, time: .meter(3, 4)).setStave(stave)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try f.draw()
            let text = drawnText(ctx.getSVG())

            #expect(finger.getFretHandFinger() == "2", "enclosure retains the authored finger")
            #expect(finger.getWidth() > finger.width, "circle extends beyond the text")
            #expect(notes[0].checkModifierContext().getLeftShift() >= finger.getWidth(), "reserves circle width")
            // The SVG context rounds the coordinates. Upstream compares the unrounded values.
            func at(_ label: String, _ note: Int, _ index: Int, _ left: Bool) -> Bool {
                text.contains { t in
                    t.label == label && abs(t.y - notes[note].getYs()[index]) < 7
                        && (left ? t.x < notes[note].getTieLeftX() : t.x + 0.5 >= notes[note].getTieRightX())
                }
            }
            #expect(at("2", 0, 0, true), "enclosed finger 2 beside fret 3 on string 2")
            #expect(at("0", 1, 0, false), "open-string fingering beside the open fret")
            #expect(at("T", 2, 1, true), "thumb beside second chord position")
            #expect(at("3", 2, 1, false), "string number independently labels the same fret")
        }
    }

    @Test func circledFingeringOnPitchedNoteDrawsCircle() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 300, height: 150)
            let stave = f.Stave(x: 10, y: 10, width: 250)
            let note = f.StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "w"))
            let finger = f.Fingering(number: "1", drawCircle: true)
            _ = note.addModifier(finger, index: 0)
            let voice = f.Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables([note])
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try f.draw()
            let svg = ctx.getSVG()
            #expect(finger.getWidth() == max(finger.width, finger.height) + 5)
            #expect(svg.contains("<path"))
            #expect(drawnText(svg).contains { $0.label == "1" })
        }
    }

    @Test func tabFretInkFollowsFretText() throws {
        try isolated {
            let (f, _) = makeFactory(width: 300, height: 150)
            let stave = f.TabStave(x: 10, y: 10, width: 250)
            let note = f.TabNote(TabNoteStruct(positions: [
                TabNotePosition(str: 1, fret: 7), TabNotePosition(str: 3, fret: 10),
            ], duration: .whole))
            let voice = f.Voice(time: VoiceTime(numBeats: 4, beatValue: 4)).addTickables([note])
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            let ink = note.getFretInk()
            #expect(ink.count == 2)
            let ys = note.getYs()
            for (i, box) in ink.enumerated() {
                #expect(box.w > 0 && box.h > 0)
                #expect(box.y < ys[i] && box.y + box.h >= ys[i] - 1)
                #expect(abs(box.x + box.w / 2 - note.getAbsoluteX()) < 2)
            }
            #expect(ink[1].w > ink[0].w, "two digits are wider than one")
        }
    }

    // MARK: - instrument-profile-tests.mjs: chord-frame fingerings follow stopped strings

    @Test func chordFrameFingeringsFollowStoppedStrings() throws {
        try isolated {
            /// The white bold digits that the frame draws, as `[label, centerX, y]`.
            func render(_ frame: FretDiagram) throws -> [DrawnText] {
                let ctx = SVGRenderContext(width: 200, height: 200)
                _ = frame.setContext(ctx)
                try frame.draw()
                return drawnText(ctx.getSVG()).filter { $0.weight == "bold" }.map { t in
                    ctx.setFont(VexFont.validate(family: frame.fontInfo.family, size: "7.5px", weight: "bold"))
                    let width = ctx.measureText(t.label).width
                    return DrawnText(label: t.label, x: t.x + width / 2, y: t.y)
                }
            }
            func near(_ a: [DrawnText], _ b: [(String, Double, Double)]) -> Bool {
                a.count == b.count && zip(a, b).allSatisfy { t, e in
                    t.label == e.0 && abs(t.x - e.1) <= 0.75 && t.y == e.2
                }
            }

            var fingers: [Int?] = [nil, nil, nil, 1, 3, 2]
            let d = try FretDiagram(FretDiagramSpec(
                frets: [.muted, .muted, .fret(0), .fret(2), .fret(3), .fret(2)], fingerings: fingers
            ))
            fingers[3] = nil
            let c = try FretDiagram(FretDiagramSpec(
                frets: [.muted, .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)], fingerings: [nil, 3, 2, nil, 1]
            ))
            let full = try render(d)
            let cleared = try render(try d.setFingerings(fingers))
            let invalid: [[Int?]] = [[1], [nil, nil, 1], [nil, nil, nil, 5], Array(repeating: nil, count: 7)]
            for values in invalid {
                #expect(throws: VexError.self) { try d.setFingerings(values) }
                do {
                    try d.setFingerings(values)
                } catch let error as VexError {
                    #expect(error.code == "BadArguments")
                }
            }
            let afterError = try render(d)
            let plain = try render(try d.setFingerings())
            let cDigits = try render(c)

            #expect(near(full, [("1", 49, 33), ("3", 58, 44), ("2", 67, 33)]))
            #expect(near(cDigits, [("3", 31, 44), ("2", 40, 33), ("1", 58, 22)]))
            #expect(cleared.map(\.label) == ["3", "2"])
            #expect(near(cleared, [("3", 58, 44), ("2", 67, 33)]))
            #expect(afterError == cleared)
            #expect(plain.isEmpty)
        }
    }

    @Test func chordFrameFingeringsEnlargeDotsAndLabelAria() throws {
        try isolated {
            let ctx = SVGRenderContext(width: 200, height: 200)
            let d = try FretDiagram(FretDiagramSpec(
                frets: [.muted, .fret(3), .fret(2), .fret(0), .fret(1), .fret(0)], fingerings: [nil, 3]
            ))
            _ = d.setContext(ctx)
            try d.draw()
            let svg = ctx.getSVG()
            #expect(svg.contains("Chord frame, low to high: x, 3 (finger 3), 2, 0, 1, 0"))
            #expect(svg.contains("fill=\"white\""))
            #expect(throws: VexError.self) {
                try FretDiagram(FretDiagramSpec(frets: [.fret(0), .fret(1)], fingerings: [0]))
            }
        }
    }

    // MARK: - figuredbass_tests.ts: independent figured-bass continuations

    @Test func independentFiguredBassContinuations() throws {
        try isolated {
            let (f, _) = makeFactory(width: 580, height: 185)
            let stave = f.Stave(x: 10, y: 10, width: 300).addClef(.bass)
            let notes = try (0..<4).map { _ in f.StaveNote(try g2()) }
            let (one, two, three, four) = (notes[0], notes[1], notes[2], notes[3])
            let voice = f.Voice().addTickables(notes)
            let bass = try f.FiguredBass(FiguredBassSpec(rows: [
                [
                    FiguredBassFigure(note: one, figure: "6", extendTo: three),
                    FiguredBassFigure(note: four, figure: "5"),
                ],
                [
                    FiguredBassFigure(note: one, figure: "4"),
                    FiguredBassFigure(note: two, figure: "3", extendTo: four),
                ],
            ]))

            func format(_ width: Double) throws -> [BoundingBox] {
                _ = stave.setWidth(width)
                _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
                let geometry = try measureEngraving(bass)
                #expect(geometry.diagnostics.isEmpty)
                #expect(geometry.parts.count == 6, "Four written digits and two lines")
                guard geometry.parts.count == 6 else { return geometry.parts }
                let p = geometry.parts
                let (six, upper, five, lowerFour, lowerThree, lower) = (p[0], p[1], p[2], p[3], p[4], p[5])
                let centers = notes.map { ($0.getNoteHeadBeginX() + $0.getNoteHeadEndX()) / 2 }
                #expect(
                    [six, lowerFour, lowerThree, five].map { ($0.x + $0.w / 2).rounded() }
                        == [centers[0], centers[0], centers[1], centers[3]].map { $0.rounded() },
                    "Each digit is centered on the written attack"
                )
                #expect(six.y > stave.getYForLine(4) && six.y + six.h < lowerFour.y,
                        "The rows clear the staff and each other")
                #expect(upper.x > six.x + six.w && lower.x > lowerThree.x + lowerThree.w, "Lines clear their digits")
                #expect(abs(upper.x + upper.w - centers[2]) < 1e-9, "The 6 holds through the third G")
                #expect(abs(lower.x + lower.w - centers[3]) < 1e-9, "The 3 holds through the fourth G")
                #expect(upper.y < lowerFour.y && lower.y > five.y + five.h,
                        "Continuation lines stay within their rows")
                return geometry.parts
            }
            let narrow = try format(300)
            let wide = try format(550)
            #expect(wide[1].w > narrow[1].w && wide[5].w > narrow[5].w, "Both continuations grow with the bar")
            #expect(try format(300) == narrow, "Restoring the width restores every digit and line")

            let resolution = try FiguredBass(FiguredBassSpec(rows: [[
                FiguredBassFigure(note: one, figure: "10", extendTo: two),
                FiguredBassFigure(note: two, figure: "9"),
            ]]))
            let parts = try resolution.getInkParts()
            #expect(parts.count == 3)
            if parts.count == 3 {
                let (ten, line, nine) = (parts[0], parts[1], parts[2])
                #expect(ten.w > narrow[0].w && line.x + line.w < nine.x, "A multi-digit figure clears its resolution")
            }
            func message(_ body: () throws -> Void) -> String {
                do { try body() } catch let error as VexError { return error.message } catch { return "\(error)" }
                return ""
            }
            #expect(message { _ = try FiguredBass(FiguredBassSpec(rows: [[]])) }.contains("row"), "Reject an empty row")
            #expect(message {
                _ = try FiguredBass(FiguredBassSpec(rows: [[FiguredBassFigure(note: one, figure: "A")]]))
            }.contains("digits"))
            #expect(message {
                _ = try FiguredBass(FiguredBassSpec(rows: [[
                    FiguredBassFigure(note: two, figure: "4", extendTo: one),
                ]])).getInkParts()
            }.contains("extend"))

            try f.draw()
            #expect(bass.isRendered(), "The factory draws every queued row on this backend")
        }
    }

    @Test func figuredBassRejectsUnorderedRowsAndHasCategory() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 400, height: 200)
            let stave = f.Stave(x: 10, y: 10, width: 300)
            let notes = try (0..<4).map { _ in f.StaveNote(try g2()) }
            let voice = f.Voice().addTickables(notes)
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            let unordered = try FiguredBass(FiguredBassSpec(rows: [[
                FiguredBassFigure(note: notes[2], figure: "6"),
                FiguredBassFigure(note: notes[1], figure: "5"),
            ]]))
            #expect(throws: VexError.self) { try unordered.getInkParts() }
            #expect(unordered.getBoundingBox() == nil)
            let ok = try FiguredBass(FiguredBassSpec(rows: [[FiguredBassFigure(note: notes[0], figure: "7")]]))
            #expect(isCategory(ok, .figuredBass))
            #expect(ok.getBoundingBox() == (try ok.getInkParts()).first)
            _ = ok.setContext(ctx)
            try ok.draw()
            #expect(ctx.getSVG().contains("vf-figured-bass"))
            #expect(ctx.getSVG().contains(Glyphs.figbass7))
        }
    }
}
