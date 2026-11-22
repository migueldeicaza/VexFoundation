# Port notes: modifiers group (VexFlow 5.0.0)

Files: `Modifiers/Accidental.swift`, `Annotation.swift`, `Articulation.swift`, `Bend.swift`,
`ChordSymbol.swift`, `FretHandFinger.swift`, `GraceNote.swift`, `GraceNoteGroup.swift`,
`Ornament.swift`, `Parenthesis.swift`, `StringNumber.swift`, `Stroke.swift`, `Tremolo.swift`.

All glyphs are drawn as text (`text = Glyphs.x` + `renderText`, or `ctx.setFont` + `fillText`).
No file uses `Glyph`, `TextFormatter`, `textFont`, music-font metrics or the old chord-symbol
metrics cache.

## Cross-file assumptions

### core (Modifier, Tables, Note, Tickable)
- `Modifier.reset()` is `open`, and `setPosition(_:)` calls it. `Accidental` and `Articulation`
  override `reset()`. They do not override `setPosition`.
- `Modifier.checkAttachedNote()` (non-throwing) is used in `format`. `checkAttachedNoteThrowing()`,
  `checkIndexThrowing()` and `checkModifierContextThrowing()` are used in `draw`.
- `Note.getModifierStartXY(position:index:forceFlagRight:)` has a `forceFlagRight` default.
  `Parenthesis` passes `forceFlagRight: true`.
- `Note.getTickContext()` (non-optional), `Tickable.getVoice()`, `checkTickContext()`,
  `Note.tickContext`, `getYs()`, `getKeyProps()`, `getGlyphWidth()`, `getFontScale()`, `checkStaveThrowing()`.
- `Tickable.modifiers` is used by `Accidental.applyAccidentals`. It removes duplicate accidentals in place.
- `Tables.accidentalCodes(_:)`, `hasAccidentalCode(_:)`, `ornamentCodes(_:)`, `articulationCodes(_:)`,
  and `accidentalColumnsTable` with camelCase keys. `ArticulationStruct` is declared in `Tables.swift`.
- `TEXT_HEIGHT_OFFSET_HACK` and `STAVE_LINE_DISTANCE`.
- Internal helpers in `Articulation.swift`: `getTopY`, `getBottomY` (throwing) and `getInitialOffset`.
  `Ornament` uses them.

### notes
- `StaveNote(StaveNoteStruct)` takes `strokePx` and has no `glyphFontScale`.
  `buildNoteHeads()`, `noteHeads`, `getNoteHeadBounds()`, `minNoteheadPadding`,
  `stemExtensionOverride`, and an overridable `getStemExtension()` and `draw()`.
- `StemmableNote.checkStemThrowing()`, `getStem()`, `getStemX()`, and `Stem.getExtents()`.
- The grace note scale comes from the `GraceNote.fontScale` metric (2/3), through `getFontScale()`.

### formatting + connectors
- `Beam(_:) throws`, `beam.slope`, `notes`, `postFormatted`, `postFormat()`, `getBeamYToDraw()`,
  `renderOptions.beamWidth` and `renderOptions.partialBeamLength`.
- `Voice(time: VoiceTime(...)).setStrict(false)` and `Formatter().joinVoices(_:).format(_:justifyWidth:)`.
- `TieNotes(firstNote:lastNote:firstIndexes:lastIndexes:)`, `StaveTie(notes:)`, `TabTie(notes:)`,
  and `renderOptions.cp2` / `renderOptions.yShift`.
- `TickContext.getNextContext(_:)` is used by the breath-mark patch.

### tab
- `TabNote.leastString()` / `greatestString()` (wrapped in `Double(...)`) and `renderOptions.drawStem`.
- `TabNote.getModifierStartXY` must override the 3-argument form. While checking the module, it
  still overrode the 2-argument form, which does not compile.

## Public API decisions

- Accidental: `accidentalData`, `fontScale` and the paren paddings are removed.
  `init(parsing:)` accepts a table key, a SMuFL code point, or a SMuFL glyph name.
  `initError` is set when there is no table mapping.
- Articulation:
  - `articulationData` is renamed to `articulation` (read-only).
  - An unknown type takes its position from the parity of its code point (upstream).
  - A SMuFL glyph name is converted to its code point.
- Annotation, ChordSymbol: added `String` overloads for justification, and the
  `horizontalJustifyString` / `verticalJustifyString` maps.
- Bend: the main init is now `Bend(_ phrase: [BendPhrase])`. `Bend(text, release:)` is deprecated.
  `renderOptions` holds `bendWidth` and `releaseWidth`. `styleLine` comes from the `Bend.line` metric.
- ChordSymbol:
  - `ChordSymbolBlock` is now a `VexElement` subclass.
  - `SymbolType`, the kerning APIs, `addLine(_ width:)` and `addSymbolBlock(symbolType:...)` are
    deprecated shims or are removed.
  - `SymbolModifiers` is a typealias of `SymbolModifier`.
- GraceNote:
  - `GRACE_LEDGER_LINE_OFFSET` stays (Swift cannot redeclare `StaveNote.LEDGER_LINE_OFFSET`).
  - `SCALE` and `getStaveNoteScale()` are deprecated (use `getFontScale()`).
- GraceNoteGroup: `renderOptions.slurYShift` (the `slurYShift` alias is deprecated). Right-position
  groups add to `rightShift`.
- Ornament:
  - The upstream static lists are added (`ornamentNoteTransition`, and so on). The old names are deprecated.
  - `renderOpts` is now `renderOptions: OrnamentRenderOptions`.
  - `reportedWidth` is removed.
- Stroke: the `rasquedo*` cases are renamed to `rasgueado*` (deprecated aliases are kept).
  `strokeRenderOptions` is now `renderOptions`.
- Tremolo: `code`, `ySpacingScale` and `extraStrokeScale` are removed.
- FretHandFinger: `finger` is deprecated (use `getFretHandFinger()`).

## Local deviations kept

- Articulation (VexFlowPatch):
  - Breath mark `"abr"` uses `Glyphs.breathMarkComma` and `breathMarkDistance`.
  - `setXShift` and `setYShift` record the user shifts, because upstream `setOrigin()` overwrites
    `xShift` and `yShift`. The user `yShift` is added to `y` in `draw`. The user `xShift` is used
    only for breath marks.
- Stroke: the wiggle loop stops if the glyph width is 0 (guards against an endless loop when a font is missing).
- Accidental, FretHandFinger, StringNumber: sorts are stable (JavaScript `Array.sort` semantics).
- StringNumber: `format` reads `state` instead of `note.getModifierContext().getState()`.
  This avoids overlapping `inout` access.
