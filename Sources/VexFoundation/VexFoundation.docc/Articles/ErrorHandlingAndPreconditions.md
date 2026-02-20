# Error Handling and Preconditions

VexFoundation provides safe parsing APIs, but many rendering paths assume valid preconditions.

## 1. Boundary Parsing APIs

Use throwing/failable initializers:

- ``NoteDurationSpec`` parsing
- ``StaffKeySpec`` parsing
- ``StaveNoteStruct`` parsing
- ``TabNoteStruct`` parsing

```swift
let key = try StaffKeySpec(parsing: "c#/4")
let dur = try NoteDurationSpec(parsing: "8d")
```

## 2. Rendering Preconditions

1. ``Factory/setContext(_:)`` must run before draw.
2. ``FontLoader/loadDefaultFonts()`` must run before glyph rendering.
3. ``System/format()`` should run before draw.
4. Voice ticks must satisfy mode/time constraints.

## 3. Defensive Construction Pattern

```swift
func buildSafeVoice(factory f: Factory, specs: [StaveNoteStruct]) -> Voice {
    let v = f.Voice(timeSignature: .meter(4, 4))
    let notes = specs.map { f.StaveNote($0) as Note }
    _ = v.addTickables(notes)
    return v
}
```

## 4. User Input Strategy

- Parse and validate first.
- Report parse errors before rendering.
- Keep typed values in view model / domain state.

## Related

- <doc:Troubleshooting>
- <doc:TypedModels>
- ``Factory/setContext(_:)``
- ``FontLoader/loadDefaultFonts()``
- ``System/format()``
- ``Voice/setMode(_:)``
