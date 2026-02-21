import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Dot.Basic")
    func dotBasicMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Dot", test: "Basic", width: 1000, height: 240) { _, context in
            let stave = Stave(x: 10, y: 10, width: 975)
            _ = stave.setContext(context)
            try stave.draw()

            let notes = try makeDotBasicNotes()
            Dot.buildAndAttach(notes.map { $0 as Note }, all: true)
            Dot.buildAndAttach([notes[7], notes[8], notes[9]].map { $0 as Note }, all: true)
            Dot.buildAndAttach([notes[8], notes[9]].map { $0 as Note }, all: true)

            let beam = try Beam([notes[11], notes[12]].map { $0 as StemmableNote })

            for (index, note) in notes.enumerated() {
                try drawUpstreamDotNote(note, stave: stave, context: context, x: 30 + Double(index) * 65)
                drawUpstreamNoteMetrics(context: context, note: note, yPos: 140)
            }

            _ = beam.setContext(context)
            try beam.draw()
            drawUpstreamNoteWidthLegend(context: context, x: 890, y: 140)
        }
    }

    private func makeDotBasicNotes() throws -> [StaveNote] {
        [
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["c/4", "e/4", "a/4", "b/4"], duration: "w")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["a/4", "b/4", "c/5"], duration: "4", stemDirection: .up)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4", "a/4", "b/4"], duration: "4", stemDirection: .down)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "f/4", "b/4", "c/5"], duration: "4")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4", "a/4", "d/5", "e/5", "g/5"], duration: "4", stemDirection: .down)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["g/4", "b/4", "d/5", "e/5"], duration: "4", stemDirection: .down)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "g/4", "b/4", "c/5"], duration: "4", stemDirection: .up)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["d/4", "e/4", "f/4", "a/4", "c/5", "e/5", "g/5"], duration: "2")),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4", "c/5", "e/5", "g/5"], duration: "16", stemDirection: .down)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["f/4", "g/4", "a/4", "b/4", "c/5", "e/5", "g/5"], duration: "16", stemDirection: .up)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "g/4", "a/4", "b/4", "c/5", "e/5", "f/5"], duration: "16", stemDirection: .up)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "g/4", "a/4", "b/4", "c/5"], duration: "16", stemDirection: .up)),
            try StaveNote(validating: StaveNoteStruct(parsingKeys: ["e/4", "a/4", "b/4", "c/5"], duration: "16", stemDirection: .up)),
        ]
    }

    private func drawUpstreamDotNote(_ note: StaveNote, stave: Stave, context: SVGRenderContext, x: Double) throws {
        let modifierContext = ModifierContext()
        _ = note.setStave(stave).addToModifierContext(modifierContext)
        _ = TickContext().addTickable(note).preFormat().setX(x)
        _ = note.setContext(context)
        try note.draw()
    }

    private func drawUpstreamNoteMetrics(context: SVGRenderContext, note: Note, yPos: Double) {
        let metrics = note.getMetrics()
        let xStart = note.getAbsoluteX() - metrics.modLeftPx - metrics.leftDisplacedHeadPx
        let xPre1 = note.getAbsoluteX() - metrics.leftDisplacedHeadPx
        let xAbs = note.getAbsoluteX()
        let xPost1 = note.getAbsoluteX() + metrics.notePx
        let xPost2 = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx
        let xEnd = note.getAbsoluteX() + metrics.notePx + metrics.rightDisplacedHeadPx + metrics.modRightPx
        let xFreedomRight = xEnd + note.getFormatterMetrics().freedom.right
        let xWidth = xEnd - xStart

        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))
        _ = context.fillText("\(Int(xWidth.rounded()))px", xStart + note.getXShift(), yPos)

        let y = yPos + 7
        func stroke(_ x1: Double, _ x2: Double, _ color: String, _ yy: Double = y) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(3)
            _ = context.moveTo(x1 + note.getXShift(), yy)
            _ = context.lineTo(x2 + note.getXShift(), yy)
            _ = context.stroke()
        }

        stroke(xStart, xPre1, "red")
        stroke(xPre1, xAbs, "#999")
        stroke(xAbs, xPost1, "green")
        stroke(xPost1, xPost2, "#999")
        stroke(xPost2, xEnd, "red")
        stroke(xEnd, xFreedomRight, "#DD0")
        stroke(xStart - note.getXShift(), xStart, "#BBB")
        drawUpstreamDot(context: context, x: xAbs + note.getXShift(), y: y, color: "blue")

        let formatterMetrics = note.getFormatterMetrics()
        if formatterMetrics.iterations > 0 {
            let spaceDeviation = formatterMetrics.space.deviation
            let prefix = spaceDeviation >= 0 ? "+" : ""
            _ = context.setFillStyle("red")
            _ = context.fillText("\(prefix)\(Int(spaceDeviation.rounded()))", xAbs + note.getXShift(), yPos - 10)
        }

        _ = context.restore()
    }

    private func drawUpstreamDot(context: SVGRenderContext, x: Double, y: Double, color: String = "#F55") {
        _ = context.save()
        _ = context.setFillStyle(color)
        _ = context.beginPath()
        _ = context.arc(x, y, 3, 0, Double.pi * 2, false)
        _ = context.closePath()
        _ = context.fill()
        _ = context.restore()
    }

    private func drawUpstreamNoteWidthLegend(context: SVGRenderContext, x: Double, y: Double) {
        _ = context.save()
        _ = context.setFont(FontInfo(family: VexFont.SANS_SERIF, size: "8pt"))
        let spacing = 12.0
        var lastY = y

        func legend(_ color: String, _ text: String) {
            _ = context.beginPath()
            _ = context.setStrokeStyle(color)
            _ = context.setFillStyle(color)
            _ = context.setLineWidth(10)
            _ = context.moveTo(x, lastY - 4)
            _ = context.lineTo(x + 10, lastY - 4)
            _ = context.stroke()
            _ = context.setFillStyle("black")
            _ = context.fillText(text, x + 15, lastY)
            lastY += spacing
        }

        legend("green", "Note + Flag")
        legend("red", "Modifiers")
        legend("#999", "Displaced Head")
        legend("#DDD", "Formatter Shift")
        _ = context.restore()
    }
}
