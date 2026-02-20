# VexFlow Parity and Migration

Migrate from VexFlow-style string workflows to typed Swift incrementally.

## 1. Concept Mapping

- VexFlow `Factory` -> ``Factory``
- VexFlow `System` -> ``System``
- VexFlow key strings -> ``StaffKeySpec``
- VexFlow duration strings -> ``NoteDurationSpec``
- VexFlow time strings -> ``TimeSignatureSpec``

## 2. Phase 1: Preserve Behavior

Use ``EasyScore`` and current string constructors while porting screens.

```swift
let score = f.EasyScore()
let notes = score.notes("C4/q, D4, E4, F4")
```

## 3. Phase 2: Introduce Typed Values

```swift
let note = StaveNoteStruct(
    keys: NonEmptyArray(StaffKeySpec(letter: .c, octave: 4)),
    duration: .quarter
)
```

## 4. Phase 3: Keep Parsing at Boundaries

```swift
func parseExternal(key: String, duration: String) throws -> StaveNoteStruct {
    try StaveNoteStruct(parsingKeys: [key], duration: duration)
}
```

## 5. Recommended End State

- External inputs parsed once.
- Domain state is typed.
- Rendering code avoids ad hoc string parsing.

## Related

- <doc:TypedModels>
- <doc:EasyScoreBasics>
- ``Factory/EasyScore(options:)``
- ``EasyScore/notes(_:options:)``
- ``StaffKeySpec``
- ``NoteDurationSpec``
