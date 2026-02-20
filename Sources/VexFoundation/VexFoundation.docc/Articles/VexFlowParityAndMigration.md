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

VexFoundation now ships a Swift-native ``TextFormatter`` replacement contract.
It is intentionally not a strict browser-module port, but provides equivalent text metric behavior for layout flows.

Core contract:

- ``RenderContext/measureText(_:)`` for width/height/ascent/descent metrics.
- ``TextMeasure`` as the typed metric payload.
- ``FontInfo`` and ``VexFont`` for normalized text-font inputs.
- ``TextFormatter`` for cached measurement helpers (`measure`, width px/em, y extents).

This contract is validated by parity tests in `Phase18Tests`.

## 7. Optional Compatibility Layer

For incremental migrations, VexFoundation includes lightweight compatibility facades:

- ``Flow``: selected constants/utilities, font-stack helpers, build metadata bridge.
- ``Vex``: selected helper functions (`sortAndUnique`, `contains`, `stackTrace`, `benchmark`).
- ``Version`` / ``VexVersion``: build/version metadata.

These APIs keep typed-first pathways as the default and keep string convenience methods explicit (`throws` or failable).

## Related

- <doc:TypedModels>
- <doc:EasyScoreBasics>
- ``Factory/EasyScore(options:)``
- ``EasyScore/notes(_:options:)``
- ``StaffKeySpec``
- ``NoteDurationSpec``
