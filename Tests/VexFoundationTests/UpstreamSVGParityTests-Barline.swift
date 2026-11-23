import Testing
@testable import VexFoundation

// VexFlow 5.8.0 tests/barline_tests.ts cases that are not in UpstreamSVGParityTests.swift.
extension UpstreamSVGParityTests {
    /// Upstream `measureBoundaries`: end each staff with a control or new style and repeat the
    /// same mark between two notes. (VexFlow 5.8.0)
    @Test("Barline.Editorial_and_double_heavy_boundaries")
    func barlineEditorialAndDoubleHeavyBoundariesMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Barline",
            test: "Editorial_and_double_heavy_boundaries",
            width: 770,
            height: 230
        ) { factory, _ in
            try drawUpstreamBarlineMeasureBoundaries(factory)
            try factory.draw()
        }
    }
}

/// The staves, notes and inline bars of upstream `measureBoundaries` (barline_tests.ts, VexFlow 5.8.0).
/// The caller draws the factory.
@discardableResult
func drawUpstreamBarlineMeasureBoundaries(
    _ f: Factory
) throws -> [(stave: Stave, left: StaveNote, mark: BarNote, right: StaveNote, voice: Voice, width: Double)] {
    let styles = ["dashed", "dotted", "doubleHeavy", "double", "end"]
    let pitches = [
        ["g/4", "a/4"],
        ["b/4", "a/4"],
        ["g/4", "e/4"],
    ]
    var result: [(stave: Stave, left: StaveNote, mark: BarNote, right: StaveNote, voice: Voice, width: Double)] = []
    for (row, width) in [145.0, 109.0].enumerated() {
        for (index, style) in styles.enumerated() {
            let stave = f.Stave(
                x: 12 + Double(index) * width,
                y: 6 + Double(row) * 108,
                width: width,
                options: StaveOptions(
                    leftBar: index == 0,
                    barlineSpan: row != 0 ? StaveBarlineSpan(top: 1, bottom: 3) : nil
                )
            )
            let type = Barline.typeString[style] ?? .single
            _ = stave.setEndBarType(type)
            let pair = pitches[index % pitches.count]
            let left = f.StaveNote(try StaveNoteStruct(parsingKeys: [pair[0]], duration: "q"))
            let right = f.StaveNote(try StaveNoteStruct(parsingKeys: [pair[1]], duration: "q"))
            let mark = f.BarNote(type: type)
            let voice = f.Voice(time: VoiceTime(numBeats: 2, beatValue: 4)).addTickables([left, mark, right])
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            result.append((stave, left, mark, right, voice, width))
        }
    }
    return result
}
