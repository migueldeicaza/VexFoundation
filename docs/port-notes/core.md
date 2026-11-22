# Port notes: core group (VexFlow 5.0.0)

Files: `Core/Tables.swift`, `Core/BoundingBox.swift`, `Core/Fraction.swift`, `Core/Util.swift`,
`Core/Registry.swift`, `Core/TypeGuard.swift`, `Notes/Note.swift`, `Formatting/Tickable.swift`,
`Formatting/TickContext.swift`, `Modifiers/Modifier.swift`, `Modifiers/ModifierContext.swift`,
`Theory/Music.swift`, `Theory/KeyManager.swift`.

These files type-check against the foundation files plus stubs for the other groups.

## Initializers

- `Tickable` and `Modifier` have a designated `public init()`. Subclasses call `super.init()`.
- `Note.init(_ noteStruct: NoteStruct)` is unchanged.

## Tables

- `GlyphProps` and `KeyProps` are in `Notes/Note.swift` (upstream `note.ts`).
  - `GlyphProps`: `codeHead`, `stemBeamExtension`, `stem`, `codeFlagUp?`, `beamCount`. All other 4.x fields are removed (`flag`, `rest`, `position`, `dotShiftY`, `lineAbove/Below`, `codeFlagDownstem`, `stemUp/DownExtension`, `tabnoteStem*`, `ledgerCodeHead`).
  - `KeyProps`: `key`, `octave`, `line`, `intValue?`, `code?`, `displaced`. VexFlowPatch fields are kept: `stemUpXOffset`, `stemDownXOffset`, `stemUpYShift`, `stemDownYShift`. Removed: `accidental`, `stroke`, `shiftRight`.
- `Note.getGlyphProps(_ duration: String, _ type: String = "n") -> GlyphProps` (non-optional). Typed overload: `(NoteValue, NoteType)`. `Tables.getGlyphProps(duration:type:)` is a deprecated shim that returns an optional.
- `Tables.durationCodes: [String: GlyphProps]` is public (upstream `Partial<GlyphProps>`, `codeHead == ""`).
- 4.x fix kept: a `256` entry in `durationCodes`, and `codeNoteHead("R", "256") == Glyphs.rest256th`.
- `Tables.codeNoteHead(_ type:, duration:)` returns `Glyphs.*` code points. It returns `Glyphs.null` only for a rest with an unknown duration. In 5.0 the diamond type code is `"DI"` (not `"D"`).
- `Tables.keyProperties(_ key: String, clef: ClefName = .treble, type: String = "N", octaveShift: Int = 0, duration: String = "4") throws -> KeyProps`.
  - Upstream `(key, clef, type, {octaveShift, duration})`. StaveNote must pass `type: noteType` and `duration:`.
  - Overloads: `clef: String` and `StaffKeySpec`.
  - `code` is always set (glyph name = custom code, else type when not "N", else key).
  - The TI patch is gated by `upstreamParityMode`.
- `Tables.clefProperties(_:) -> ClefProperties` (a struct with `lineShift`). The `String` overload throws.
- `Tables.accidentalCodes(_:) -> String` and `Tables.ornamentCodes(_:) -> String` are functions that return the input when the key is unknown (as upstream).
  - Removed: the `accidentalCodes` dictionary, the `AccidentalCode` struct, `parenRightPaddingAdjustment`, `accidentalCode(_:)`, the `ornamentCodes` dictionary and `ornamentCode(_:)`.
  - Swift helpers `hasAccidentalCode(_:)` and `hasOrnamentCode(_:)` exist for validation.
  - Ornament keys are now camelCase: `mordentInverted`, `turnInverted`.
- `Tables.articulationCodes(_:) -> ArticulationStruct?` is a function (the dictionary is removed). `ArticulationStruct` is a top-level struct in `Tables.swift`, and `Tables.ArticulationStruct` is a typealias. The modifiers group must NOT redeclare it in `Articulation.swift`.
- The `accidentalColumnsTable` keys are camelCase: `secondOnBottom`, `spacedOutTetrachord`, and so on.
- `KeySignatureSpec.acc` is renamed to `accidental` (the old name is a deprecated alias). `getKeySignatures()`, `unicode` and `TIME4_4` are added.
- `durationToTicks(String) -> Int?` and a new `durationToTicksThrowing(String)`. Sanitizing is exact (no lowercasing), as upstream.
- Removed: `TabGlyphProps` and `tabToGlyphProps`. VexFlowPatch: `Tables.tabXGlyphCode(useAlternativeXGlyph:)` returns `Glyphs.noteheadXBlack` or `Glyphs.accidentalDoubleSharp`, for `TabNote.tabToElement`.
- `clefLineShifts` keeps `.tab: 0` (not in upstream `clefs`).

## Tickable

- Removed: `xShift` (inherited) and `tickableWidth` (use `width`).
- Deprecated aliases: `tickableWidth`, `setTickableWidth`, `getTickableWidth()`, `getTickableWidthThrowing()`, and `noteModifiers` (renamed to `modifiers`, as upstream).
- `getWidth()` overrides `VexElement.getWidth()`: `width + modifierContext width`. `getWidthThrowing()` throws when the tickable is not pre-formatted.
- `getX()` is an override (tick context x + xShift).
- `preFormat()` sets `width = 0`, then adds the modifier context width.
- `FormatterMetrics` is now a final class (reference semantics). `getFormatterMetrics().space.used = ...` works as upstream.
- `setVoice(_:)` and `setTickContext(_:)` return `Self` (upstream `void`) so that `Note` can override them.
- `tuplet` is stored. `setTuplet(_ tuplet: Tuplet?)` appends without dedupe, as upstream. `resetTuplet(_ tuplet: Tuplet? = nil)` resets all tuplets when the argument is nil. These use `Tuplet.getNoteCount()` and `getNotesOccupied()` (Int).
- `reset() -> Self` was added.
- `getBoundingBox()` is no longer overridden (the Element default applies).

## TickContext

- `formatterMetrics` is a `TickContextFormatterMetrics` class with a `freedom` tuple.
- New: `move(_ shift:, _ prev:, _ next:)`, `getDeviationCost()` and `getAverageDeviationCost()`.
- `preFormat()` no longer sets `preFormatted = true` (as upstream).

## Note

- Renamed: `noteStave` is now `stave`, and `noteDuration` is now `duration` (deprecated aliases are kept). The typed `noteValue` and `noteTypeValue` stay.
- `NoteRenderOptions` no longer has `glyphFontScale`, `scale` or `font`. `useAlternativeXNoteheadGlyph` (VexFlowPatch) stays.
- `getGlyphWidth()` is open and returns 0 (as upstream). Subclasses override it.
- `getModifierStartXY(position:index:forceFlagRight: Bool = false)` is the single overridable signature. StaveNote and TabNote must override this form. A throwing variant also exists.
- Added:
  - `addStroke(_:_:)`, `getFirstDotPx()` (open), `isDotted()`, `getBeam()`, `checkBeam() throws` and `getTickContext()`.
  - `getBoundingBox()`: merges the modifier boxes.
  - `setVoice` override.
  - `Note.plotMetrics(_:_:_:)`.
- `getAbsoluteX()` uses `Metrics.getDouble("Stave.padding", 0)`.
- `getMetrics()` uses `getWidth()` (includes the modifier context width).
- `getTieRightX`/`getTieLeftX` use the raw `width`.
- `parseNoteStruct`: `customTypes` is filled only when no explicit `type` is given (as upstream).
- Removed: `Note.getPoint`.

## Modifier

- Removed: `xShift`, `yShift`, `modifierWidth` (deprecated alias to `width`), and the `getWidth`/`setWidth` duplicates.
- `init()` sets `width = 0`.
- `setXShift` is an override (direction-aware).
- `setPosition(_ String)` was added. `setPosition(_:)` calls the new open `reset()`.
- `alignSubNotesWithNote(_:_:position:)` was added, with right-position support.
- `spacingFromNextModifier` is public. `Modifier.Position` is a typealias.

## ModifierContext

- Added: `public init()`, the deprecated `addModifier` and `getModifiers`, and `DEBUG`.
- `formatted` and `postFormatted` are no longer set (as upstream). `getMetrics()` (non-throwing) returns the same values.
- `addMember` calls `setModifierContext` on the member.

## Other

- `BoundingBox` stays a struct. It has `getX/getY/getW/getH`, the setters, `move(_:_:)`, `clone()`, `copy(_:)`, the positional init, and a `Bounds` protocol.
- `Fraction`:
  - Added: `equals`, `greaterThan`, `greaterThanEquals`, `lessThan`, `lessThanEquals`, `toString`, and `GCD`/`LCM`/`LCMM` aliases.
  - `quotient()` rounds down (Math.floor).
- `Util`: added `upperFirst`, `vexLog` and `vexWarn`.
- `TypeGuard`:
  - `isCategory` walks the class chain with the static `category` (upstream semantics).
  - `.flag` was added.
  - `Fraction` and `RenderContext` are handled.
- `Music.rootIndices` is renamed to `rootIndexes` (deprecated alias kept).
