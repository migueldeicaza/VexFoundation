# Unit-test findings (VexFlow 5.0.0 triage)

This file lists differences between the Swift library and upstream VexFlow 5.0.0 that the unit tests found.
The tests that show a difference use `withKnownIssue` and refer to this file.

## Stem: default direction is UP, upstream default is 0

- Swift: `Sources/VexFoundation/Notes/Stem.swift:99` sets `stemDirection = options?.stemDirection ?? .up`.
- Upstream: `src/stem.ts:89` sets `this.stemDirection = options?.stemDirection ?? 0`.
- Effect: `Stem.getHeight()` multiplies by the direction. A new `Stem()` has height 0 upstream, but -35 / 35 in Swift.
  This occurs when code calls `buildStem()` after `setStemDirection()`. The new stem has no direction until the next `setStemDirection()`.
- Evidence (upstream node build):
  ```
  const n = new VF.StaveNote({keys:['c/4'], duration:'4'});
  n.setStave(new VF.Stave(10,40,300)); n.setStemDirection(1); n.buildStem();
  n.getStem().getHeight()   // 0   (Swift: 35)
  ```
  `Ornament.format` then gives `textLine 5, topTextLine 7` upstream, and `1.5, 3.5` in Swift.
- Cause: `StemDirection` is a Swift enum with only `.up` / `.down`, so it cannot hold 0. A fix needs an optional direction or a third case.
- Test: `OrnamentTremoloHairpinConnectorTests.ornamentFormatStemWithoutDirection` (known issue).

## Not a bug: undocumented Swift extension in Articulation

- `Sources/VexFoundation/Modifiers/Articulation.swift:198` converts a SMuFL glyph name (for example `"fermataAbove"`) to its code point.
  Upstream keeps the string as is. The source marks this as a Swift extension, but `docs/local-deviations.md` does not list it.
- Test: `AccidentalBeamArticulationTests.articulationDirectGlyphCode` expects `Glyphs.fermataAbove`.
