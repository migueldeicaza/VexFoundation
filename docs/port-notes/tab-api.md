# Port notes: tab+api group (VexFlow 5.0.0)

Files: `Tablature/*`, `API/*`, `Compatibility/*`, `SamplePreview.swift`, `Rendering/VexCanvas.swift`.

## Cross-file assumptions (APIs that other groups must provide)

### core (Tickable, Note, Tables)
- `Tickable`/`Note` width is the `VexElement.width` (no `tickableWidth`). TabNote writes `width = ...`.
- `Tickable` has `@discardableResult open func reset() -> Self` (upstream `reset()`), and
  `StemmableNote.setStemDirection` calls `reset()` dynamically (no `as? TabNote` cast).
  `TabNote` overrides it: `super.reset()`, then `setStave(stave)` if a stave is set.
- `getModifiers() -> [Modifier]` exists (TabNote uses it, not `noteModifiers`).
- `Note.getGlyphWidth()` returns 0 for TabNote (upstream base returns 0). TabNote no longer overrides it.
- `GlyphProps.codeFlagUp: String?` (upstream 5.0 field). TabNote.drawFlag checks it.
- `NoteRenderOptions` keeps `drawStem`, `drawDots`, `drawStemThroughStave`, `yShift`.
  TabNote no longer uses `glyphFontScale`, `scale`, `font`, `useAlternativeXNoteheadGlyph`.
- `Note.checkStaveThrowing()`, `checkStave()`, `ys`, `beam`, `preFormatted` (settable),
  `modifierContext`, `stemExtensionOverride`, `glyphProps`, `getCenterGlyphX()` keep their names.
- `NoteStruct(keys: [], duration:dots:type:)` is accepted (TabNote passes empty keys, as upstream).
- `Tables.RESOLUTION`, `NOTATION_FONT_SCALE`, and so on: `Flow` reads them only (no setters).
  `Tables.UNISON` stays a runtime-backed `static var`.
- `Tables.tabToGlyphProps` and `TabGlyphProps` can be removed: replaced by `TabNote.tabToElement`.
  The VexFlowPatch alternative X glyph moved to `TabNote.useAlternativeXNoteheadGlyph`
  (a TabNote property) and `TabNote.tabToElement(_:useAlternativeXGlyph:)`.
- `Metrics.number(_:)` stays internal-accessible (used by `Flow.STAVE_LINE_THICKNESS`).

### notes (StemmableNote, Stem, Flag)
- `StemmableNote.flag` is a non-optional `Flag` (a `VexElement`), as upstream `protected flag = new Flag()`.
  TabNote uses `flag.getHeight()` and `flag.setContext(ctx).setX(x).setY(y)` + `try flag.drawWithStyle()`.
- `Stem.HEIGHT`, `Stem.WIDTH`, `Stem.UP`, `Stem.DOWN`, `stem.setYBounds`, `setNoteHeadXBounds`, `getExtents()`.

### stave
- `Stave.setX(_:)`, `setY(_:)`, `setWidth(_:)` are the upstream names (overrides of `VexElement`).
  `System` calls them instead of `setStaveX`/`setStaveY`/`setStaveWidth`.
- `StaveOptions.spacingBetweenLinesPxWasSpecified` stays (local commit 252b9a7).
- `Stave.formatBegModifiers`, `space(_:)`, `getNoteStartX`, `setNoteStartX`, `rightPadding`, `defaultPadding`.

### formatting + connectors
- `Voice` and `System` are `VexElement` subclasses: `voice.setContext(ctx).drawWithStyle()`.
  `Voice.setContext` accepts an optional context (base signature).
- `StaveTie.renderTie(direction: TieDirection, firstX: Double, lastX: Double, firstYs: [Double], lastYs: [Double]) throws`
  (upstream param names `firstX`/`lastX`). `TabSlide` overrides it.
- `TieNotes.firstIndexes` / `lastIndexes` (upstream 5.0 rename of `firstIndices`).
- `StaveTie.draw()` calls the overridable `renderTie`, then `renderTieText` (upstream). TabSlide no longer
  overrides `draw()`, so the "sl." text is drawn as upstream does.
- `StaveTieError.noYValues`, `.badIndices` stay.
- `Curve(from: Note?, to: Note?, options:)`.
- `VibratoBracket.setVibratoCode(_ code: Int)` (replaces `setHarsh`).
- `Formatter.tune(options:)` keeps the current Swift call form `(alpha: Double, ())`.

### modifiers
- `ChordSymbol`: no `setEnableKerning`/`setReportWidth`.
- `Ornament.setPosition(ModifierPosition)`, `setUpperAccidental(String)`, `setLowerAccidental(String)`, `setDelayed(Bool)`.
- `Articulation.setPosition(ModifierPosition)`, `setBetweenLines(Bool)`.

### notes
- `GlyphNote(glyph: String, noteStruct:options:)` (5.0: glyph is a SMuFL string).

## Behavior notes
- `TabNote.drawStemThrough` no longer wraps in `save()/restore()` (upstream does not).
- `TabNote.draw` no longer applies its style itself (callers use `drawWithStyle()`).
- `Factory.draw()` uses `drawWithStyle()` for staves, voices, render queue and systems.
- `Factory.reset()` now also clears the `formatSystems()` flag.
- `GraceTabNote` no longer has the 4.x scale 0.6 / 7.5pt font. Upstream 5.0 has only `yShift = 0.3`.
