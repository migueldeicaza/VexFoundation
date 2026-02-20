// VexFoundation - Dedicated parity tests for `style` topic.

import Testing
@testable import VexFoundation

@Suite("Style")
struct StyleParityTests {

    @Test func elementStoresAndReturnsStyle() {
        let style = ElementStyle(fillStyle: "red", strokeStyle: "blue", lineWidth: 2)
        let element = VexElement()

        _ = element.setStyle(style)

        #expect(element.getStyle()?.fillStyle == "red")
        #expect(element.getStyle()?.strokeStyle == "blue")
        #expect(element.getStyle()?.lineWidth == 2)
    }

    @Test func groupStylePropagatesToChildren() {
        let style = ElementStyle(shadowBlur: 4, fillStyle: "green")

        let parent = VexElement()
        let childA = VexElement()
        let childB = VexElement()

        _ = parent.addChildElement(childA)
        _ = parent.addChildElement(childB)
        _ = parent.setGroupStyle(style)

        #expect(parent.getStyle()?.fillStyle == "green")
        #expect(childA.getStyle()?.fillStyle == "green")
        #expect(childB.getStyle()?.fillStyle == "green")
        #expect(childA.getStyle()?.shadowBlur == 4)
        #expect(childB.getStyle()?.shadowBlur == 4)
    }

    @Test func staveNoteSupportsPerKeyAndStemStyles() {
        let note = StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(
                StaffKeySpec(letter: .c, octave: 4),
                StaffKeySpec(letter: .e, octave: 4)
            ),
            duration: .quarter
        ))

        _ = note.buildNoteHeads()
        _ = note.buildStem()

        let keyStyle = ElementStyle(fillStyle: "orange")
        let stemStyle = ElementStyle(strokeStyle: "purple", lineWidth: 1.5)

        _ = note.setKeyStyle(0, style: keyStyle)
        _ = note.setStemStyle(stemStyle)

        #expect(note.noteHeads[0].getStyle()?.fillStyle == "orange")
        #expect(note.getStemStyle()?.strokeStyle == "purple")
        #expect(note.getStemStyle()?.lineWidth == 1.5)
    }
}
