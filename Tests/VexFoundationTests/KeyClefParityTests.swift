// VexFoundation - Dedicated parity tests for `key_clef` topic.

import Testing
@testable import VexFoundation

@Suite("Key & Clef")
struct KeyClefParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    private func firstGlyphYShift(
        clef: ClefName,
        key: String,
        position: StaveModifierPosition = .begin,
        endClef: ClefName? = nil
    ) -> Double? {
        let stave = Stave(x: 10, y: 40, width: 300)
        _ = stave.addClef(clef)
        if let endClef {
            _ = stave.setEndClef(endClef)
        }
        _ = stave.addKeySignature(key, position: position)

        let keySig = stave.getModifiers(position: position, category: KeySignature.category).first as? KeySignature
        keySig?.format()
        return keySig?.getGlyphs().first?.getYShift()
    }

    @Test func keySignaturePlacementDependsOnClef() {
        let trebleY = firstGlyphYShift(clef: .treble, key: "G")
        let bassY = firstGlyphYShift(clef: .bass, key: "G")

        #expect(trebleY != nil)
        #expect(bassY != nil)
        #expect(trebleY != bassY)
    }

    @Test func endKeySignatureUsesEndClefContext() {
        let trebleEndY = firstGlyphYShift(clef: .treble, key: "G", position: .end, endClef: .treble)
        let bassEndY = firstGlyphYShift(clef: .treble, key: "G", position: .end, endClef: .bass)

        #expect(trebleEndY != nil)
        #expect(bassEndY != nil)
        #expect(trebleEndY != bassEndY)
    }
}
