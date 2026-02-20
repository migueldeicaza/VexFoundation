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

## 6. Rendering and Text Scope (P3.1 Decision)

VexFoundation intentionally does not pursue a 1:1 runtime parity layer for browser-specific VexFlow rendering modules in core.

### Intentional Omissions in Core API

- `renderer`
- `canvascontext`
- `svgcontext`
- `web`
- `offscreencanvas` test-surface equivalents

Reason: these modules are tied to browser/DOM runtime concerns that do not map cleanly to Swift-native app platforms.

### Swift-Native Replacement Contract

- Use ``RenderContext`` as the backend abstraction.
- Use ``SwiftUICanvasContext`` as the primary in-repo backend.
- Keep rendering logic backend-agnostic above ``RenderContext``.
- Treat web/canvas/svg facades as optional compatibility adapters (out-of-core scope).

### Text Layout Replacement Contract

VexFoundation does not currently ship a direct `TextFormatter` port as a module.
The replacement contract is:

- ``RenderContext/measureText(_:)`` for width/height/ascent/descent metrics.
- ``TextMeasure`` as the typed metric payload.
- ``FontInfo`` and ``VexFont`` for normalized text-font inputs.

This contract is the baseline for P3.2/P3.3 work (text formatting API + metric parity tests).

## Related

- <doc:TypedModels>
- <doc:EasyScoreBasics>
- ``Factory/EasyScore(options:)``
- ``EasyScore/notes(_:options:)``
- ``StaffKeySpec``
- ``NoteDurationSpec``
