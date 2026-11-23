# Migrating to the VexFlow 5.9.0 port

VexFoundation was a port of VexFlow 4.2.x (upstream commit `a0c4d47a`). It is now a port of VexFlow 5.9.0. This page lists the changes that affect code that uses the library.

## Fonts and glyphs

- Music glyphs are SMuFL code points drawn as text. Use the constants in `Glyphs` (for example `Glyphs.noteheadBlack`).
- The fonts are bundled OTF files and load automatically. Remove the calls to `FontLoader`.
- Select fonts with `Flow.setFonts("Bravura", "Academico")`: the music font first, then the text font. Use `Flow.setTextFonts(...)` to change the text font only.
- Add your own fonts with `FontRegistry.shared.register(family:url:)`.
- These types were removed: `Glyph`, `GlyphProps` in `Tables`, `TextFormatter`, `TimeSigGlyph`, `FontLoader` and `BoundingBoxComputation`. `VexFont` is now a namespace of CSS font helpers.
- Text measurement uses `TextMeasurer` (CoreText). It returns `TextMetrics` with the same values as the browser `measureText()`.
- When a font has no glyph for a SMuFL code point, the glyph is drawn with Bravura. Browsers use an arbitrary system font in that case.

## Sizes and styles

- Default sizes and paddings come from the `Metrics` tree. Read them with `Metrics.get("ChordSymbol.fontSize")` and change them with `Metrics.set(...)`.
- Each `VexRuntimeContext` has its own `Metrics` tree.
- `VexElement` now holds `x`, `y`, `xShift`, `yShift`, `width`, `height`, `text` and `fontInfo` for every element.
- `applyStyle(context:)` does not save the context any more. Call `ctx.save()` and `ctx.restore()` around it, or use `drawWithStyle()`.
- Some defaults changed with the upstream releases:
  - chord symbols: 14 pt Academico
  - lyrics: 12 pt
  - tab frets: 11 pt, placed across the tick
  - beam slope fitting: changed
  - grace notes: no pointer rectangle

## API

- Most of the renames follow upstream 5.x:
  - `noteStave` → `stave`
  - `noteModifiers` → `modifiers`
  - `StaveModifier.getModifierWidth()` → `getWidth()`
  - `Stave.setText` → `setStaveText`
- Removed members are kept as `@available(*, deprecated, renamed:)` shims where a direct mapping exists.
- The detailed list for each module is in `docs/port-notes/`.
- The Swift-native typed and throwing APIs are kept: `NoteDurationSpec`, `StaffKeySpec`, `ClefName`, `TimeSignatureSpec`, `NonEmptyArray`, and the `…Throwing` / `init(parsing:)` variants.

## New in 5.x

- Layout:
  - `Sheet`
  - continuous layout with system breaks (`ContinuousLayout`, `chooseSystemBreaks`)
  - pagination (`paginate`) and `Publication` (SVG pages, parts, cues, condensed scores)
  - `ScoreNavigation`
  - `PhraseLayout`
  - proportional and optical spacing
  - engraving profiles (`EngravingProfile`, `measureEngraving`)
- EasyScore composition: `EasyScore.create()` and `compose`, independent meters, and continuous spans (beams, glissandi, ties across systems).
- Notation:
  - feathered and French beams, split stems
  - alternating tremolos
  - niente and flared hairpins
  - figured bass, fret diagrams, guitar gestures, tied bends
  - harp pedals, accordion registers, flute fingerings
  - French and German lute tablature, chant, Kievan and white mensural notation
  - four-shape noteheads, makam key signatures
- SVG: `SVGRenderContext.toSVG(portable: true)` converts text glyphs to paths. Attribute names that could run script are rejected.

## Local behavior (not in upstream)

The OSMD-derived patches stay on by default. Set `VexRuntimeContext.upstreamParityMode = true` to turn off the patches marked "gated", so that the output matches upstream exactly. The full list is in `docs/local-deviations.md`.
