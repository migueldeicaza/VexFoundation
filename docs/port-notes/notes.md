# Port notes: notes group (VexFlow 5.0.0)

Files: `Notes/NoteHead.swift`, `Stem.swift`, `StemmableNote.swift`, `StaveNote.swift`, `GhostNote.swift`,
`GlyphNote.swift`, `BarNote.swift`, `ClefNote.swift`, `KeySigNote.swift`, `TimeSigNote.swift`,
`RepeatNote.swift`, `TextNote.swift`, `TextDynamics.swift`, `Modifiers/Dot.swift`.
New file: `Notes/Flag.swift` (port of `flag.ts`; no group owned it).

All files type-check (`swift-frontend -typecheck -primary-file`) against the other groups' files as of this port.

## Cross-file assumptions

### core (Note, Tickable, Tables)
- `Note.stave`, `Note.duration`, `Tickable.modifiers` (not `noteStave`, `noteDuration`, `noteModifiers`).
- `Note.getGlyphProps(_ duration: String, _ type: String)` returns a non-optional `GlyphProps`
  with `codeHead`, `stem`, `beamCount`, `stemBeamExtension`, `codeFlagUp: String?`.
- `Note.getModifierStartXY(position:index:forceFlagRight:)` and `getModifierStartXYThrowing(...)` are `open`.
  `StaveNote` overrides both. `Dot` calls the 3-argument form on any note.
- `Note.getFirstDotPx()` lives in `Note` (5.0). `StaveNote` no longer defines it.
- `Note.getGlyphWidth()`, `getTieRightX/LeftX`, `getBoundingBox`, `setBeam`, `setYs` are `open`.
- `Tickable.reset() -> Self` is `open`. `StemmableNote.setStemDirection` calls `reset()` dynamically.
- `Tickable.getWidth()` overrides `VexElement.getWidth()` (formatted width). `NoteHead.getWidth()` returns `width`.
- `Tables.keyProperties(_:clef:type:octaveShift:duration:)` (5.0 `type` argument).
- `KeyProps` keeps the VexFlowPatch fields `stemUpXOffset`, `stemDownXOffset`, `stemUpYShift`, `stemDownYShift`.
- `NoteRenderOptions.draw` and `strokePx`, `annotationSpacing` exist. `glyphFontScale` is not used.

### stave
- `Clef.line`, `Clef(type:size:annotation:)`, `Clef.renderText`, `Clef.getBoundingBox()`.
- `Barline.setType(BarlineType)`, `Barline.typeString`.
- `TimeSignature.drawAt(_ ctx:, _ stave:, _ x:)`, `TimeSignature.getWidth()`.
- `KeySignature.setStave`, `getWidth()`, `drawWithStyle()`.
- `Stave.getDefaultLedgerLineStyle() -> ElementStyle`, `Stave.checkContext()`, `getNumLines()`.

### modifiers
- `Modifier.setNote` is `open` (Dot overrides it). `Modifier.getWidth()` is the element width
  (Dot width is the measured `augmentationDot` glyph).
- `GraceNote.getStaveNoteScale()` no longer overrides anything: `StaveNote.getStaveNoteScale()` was removed (5.0).

### tab
- `StemmableNote.flag` is `Flag!` (IUO). It is created after `super.init` so element ids follow the upstream order.
- `StemmableNote.drawStem(_ stemOptions: StemOptions? = nil) throws` is `open`.

## API changes in this group
- `Flag` class (new). `StemmableNote.flag: Flag!` replaces `Glyph?`. `buildFlag()` has no `category:` argument.
- `Stem.getHeight()` overrides `VexElement.getHeight()`. `Stem.getBoundingBox()` returns nil (upstream throws).
- `Stem.draw()` no longer saves/applies the style; callers use `drawWithStyle()`.
- `NoteHead`: uses `VexElement` `x`/`y`/`text`. Removed `glyphCode`, `headX`, `headY`, `setHeadX`, `getHeadY`,
  `headStemDirection` (now `stemDirection`), `headIndex` (now `index`), the bounding box override and the
  slash drawing code (5.0 draws slash noteheads as glyphs).
  `NoteHeadStruct` lost `glyphFontScale` and `xShift`.
- `StaveNote`: `noteHeads` is `private(set)`; `sortedKeyProps` is `private(set)`; `ledgerLineStyle` is non-optional;
  `drawStem(_:)` replaces `drawStemForNote` (deprecated shim kept); `drawModifiers` throws; `setStyle` sets the
  group style (5.0); `getYForBottomText` override; `StaveNoteFormatSettings` is public.
  `StaveNoteStruct` lost `stemDownXOffset`, `stemUpXOffset`, `glyphFontScale` (removed upstream).
  Removed `getStaveNoteScale()`, `getFirstDotPx()` (moved to Note), `getBoundingBoxThrowing()`.
- `StaveNote.setKeyLine` updates `sortedKeyProps` in place without re-sort (upstream shares the objects).
- `GlyphNote(glyph: String, noteStruct:options:)`; property `options` (was `glyphNoteOptions`); `noteGlyph` removed.
- `ClefNote.getClef() -> Clef` (was `ClefType`); `clefDef`, `clefAnnotation`, `clefTypeName`, `clefSize` removed.
- `BarNote.type` (was `barlineType`), `widths`, `setType(String)`, `init(typeString:)`.
- `TextNote`: `text` is the element text; `GLYPHS: [String: String]` with 5.0 camelCase keys
  (`mordentUpper`, `pedalOpen`, `caesuraStraight`, `turnInverted`, ...). `TextNoteStruct.font` added.
  `superscript`/`subscript` are `VexElement`s. `noteGlyph` removed.
- `TextDynamics.GLYPHS: [Character: String]`; `line` is public.
- `Dot`: draws the `augmentationDot` glyph; `radius` removed; `buildAndAttach` no longer sets `dotShiftY`
  from glyph props (5.0).

## Local deviations kept
- StaveNote `paddingRight` (preFormat width). The 4.x bounding-box subtraction is gone: the 5.0 bounding box
  does not use the formatted width.
- StaveNote keeps notehead types across `reset()`: a notehead whose `noteType` differs from the note type keeps
  its `noteType` and its glyph `text`.
- StaveNote ledger lines: 5.0 style merge (`getDefaultLedgerLineStyle` + `ledgerLineStyle`) plus the
  `ledgers` SVG group (not gated).
- NoteHead `stemUpYShift`/`stemDownYShift` (y offset in `renderText`), and `stemUpXOffset`/`stemDownXOffset`
  for the gated TI notehead patch (applied only when non-zero).
- BarNote 198b8021: one persistent `Barline` and the `barnote` group.
- d5d26994 (half-rest dot): 5.0 handles rest dot shifts in `StaveNote.getModifierStartXY` (`restShift`).
  Needs a visual check.

## Behavior notes
- Removed the 4.x TextNote center-justification hack (`modLeftPx / 2`); it is not upstream.
- Removed the `#Preview` blocks (they used `FontLoader`, which was removed).
