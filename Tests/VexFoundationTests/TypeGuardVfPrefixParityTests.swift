// VexFoundation - Dedicated parity tests for `typeguard` and `vf_prefix` topics.

import Testing
@testable import VexFoundation

@Suite("TypeGuard & vf_prefix")
struct TypeGuardVfPrefixParityTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    @Test func vfPrefixMatchesVexFlowBehavior() {
        #expect(vexPrefix("test") == "vf-test")
        #expect(vexPrefix("stavenote") == "vf-stavenote")
        #expect(vexPrefix("already-hyphenated") == "vf-already-hyphenated")
    }

    @Test func typedModelRelationshipsAndTypeguardHelpers() {
        let staveNote = StaveNote(StaveNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)),
            duration: .quarter
        ))
        let graceNote = GraceNote(GraceNoteStruct(
            keys: NonEmptyArray(StaffKeySpec(letter: .d, octave: 5)),
            duration: .eighth
        ))
        let tabNote = TabNote(TabNoteStruct(
            positions: [TabNotePosition(str: 2, fret: 1)],
            duration: .quarter
        ))

        let staveAny: Any = graceNote
        let tabAny: Any = tabNote

        #expect(staveAny is GraceNote)
        #expect(staveAny is StaveNote)
        #expect(staveAny is StemmableNote)
        #expect(staveAny is Note)
        #expect(!(staveAny is TabNote))

        #expect(tabAny is TabNote)
        #expect(tabAny is StemmableNote)
        #expect(tabAny is Note)
        #expect(!(tabAny is StaveNote))

        #expect(isCategory(staveAny, .graceNote))
        #expect(isCategory(staveAny, .staveNote))
        #expect(isCategory(staveAny, .note))
        #expect(isCategory(staveAny, .note, checkAncestors: false) == false)
        #expect(isGraceNote(staveAny))
        #expect(isStaveNote(staveAny))
        #expect(isNote(staveAny))

        #expect(isCategory(tabAny, .tabNote))
        #expect(isCategory(tabAny, .stemmableNote))
        #expect(isTabNote(tabAny))
        #expect(isStaveNote(tabAny) == false)

        #expect(isCategory(staveNote, .staveNote, checkAncestors: false))
    }

    @Test func boundaryParsersActAsRuntimeGuards() {
        #expect(StaffKeySpec(parsingOrNil: "c#/4") != nil)
        #expect(StaffKeySpec(parsingOrNil: "h#/4") == nil)

        #expect((try? NoteDurationSpec(parsing: "8dd")) != nil)
        #expect((try? NoteDurationSpec(parsing: "not-a-duration")) == nil)

        #expect(StaveNoteStruct(parsingKeysOrNil: ["c/4"], duration: "q") != nil)
        #expect(StaveNoteStruct(parsingKeysOrNil: ["bad/key"], duration: "q") == nil)
    }
}
