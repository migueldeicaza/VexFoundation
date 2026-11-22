# Porting guide: VexFlow 4.x port → VexFlow 5.0.0

Read this guide before you port a module. All porting work follows it.

## Sources

- Upstream target: `../vexflow-5.0.0/src/*.ts` (tag 5.0.0). This is the source of truth.
- Upstream base of the current Swift code: `../vexflow` (commit `a0c4d47a`, 4.x branch).
- 3-way view for a file `X.ts`:
  - `git -C ../vexflow diff 58206a63 5.0.0 -- src/X.ts` gives the upstream changes from 4.2.2 to 5.0.0.
  - `git -C ../vexflow diff 58206a63 a0c4d47a -- src/X.ts` gives the 4.x-only fixes that the Swift code already has. Keep them if 5.0.0 does not have them.
- Local deviations that must survive: `docs/local-deviations.md`. Search for `VexFlowPatch` comments in the file you port and keep each patch, adapted to the 5.0 code.

## Goal

Make each Swift file a faithful port of the 5.0.0 TypeScript file:
- Use the same algorithms, constants, call order and drawing order.
- Make the drawing calls (`ctx.*`) and their order identical to upstream. SVG output is compared with the upstream reference SVGs.
- Port new public methods and options. Remove members that upstream removed. Keep a `@available(*, deprecated, ...)` shim only when it is trivial.

## Foundation that is already ported (do not change these files)

- `Core/Element.swift` (`VexElement`, port of `element.ts`):
  - **Stored in the base class:** `x`, `y`, `xShift`, `yShift`, `text`, `width`/`height` (lazy text measurement), `fontInfo`, `fontScale`, `children`, `parent`, `style`.
  - **Do not redeclare these in subclasses.** Remove the subclass copies.
  - **Open methods. Use `override` when a subclass overrides them, as upstream does:** `getWidth()`, `setWidth(_:)`, `getX()`, `setX(_:)`, `getY()`, `setY(_:)`, `getXShift()`, `setXShift(_:)`, `getYShift()`, `setYShift(_:)`, `getText()`, `setText(_:)`, `getBoundingBox() -> BoundingBox?`, `measureText() -> TextMetrics`, `renderText(_ ctx:, xPos:, yPos:)`, `setFont(_:size:weight:style:)`, `draw() throws`, `setContext(_:)`, `setStyle(_:)`, `setGroupStyle(_:)`.
  - **Other members:**
    - `addChild(_:)`
    - `textMetrics`
    - `setFont(family:size:weight:style:)` with a CSS size string
    - `setFont(css:)`
    - `setFontSize(_:)`
    - `getFont()`
    - `fontSizeInPixels`, `fontSizeInPoints`
    - `static measureWidth(_ text:, key:)`
    - `invalidateMetrics()`
  - **Category:** `class var category` gives the metrics key. `init(category:)` lets a caller pass a category (upstream `super(category)`).
  - **Upstream `this.width = ...`** maps to `width = ...` (the setter measures first, as upstream does). Upstream `this._width = ...` maps to `_width = ...` (internal).
  - **`applyStyle(context:style:)` does NOT save the context any more.** It now has upstream semantics. Port the upstream `ctx.save()` / `applyStyle` / `ctx.restore()` calls literally. `restoreStyle` was removed.
  - `drawWithStyle()` does save, apply, `draw()`, restore.
- `Core/Metrics.swift`:
  - `Metrics.get(key)`, `getDouble`, `getString`, `getBool`, `getFontInfo(key)`, `getStyle(key)`, `Metrics.set(key, value)`.
  - `Metrics.defaults` is the 5.0.0 `MetricsDefaults` tree.
- `Rendering/Glyphs.swift`:
  - `Glyphs.noteheadBlack` and so on are `String` constants (SMuFL code points).
  - `Glyphs.code(named:)` looks up a glyph by name.
- `Rendering/TextMetrics.swift`:
  - `TextMetrics`, the browser-like struct: `width`, `actualBoundingBoxAscent`/`Descent`/`Left`/`Right`, `fontBoundingBoxAscent`/`Descent`.
  - `TextMeasurer.measure(_:fontInfo:)` and `TextMeasurer.layout`.
- `Rendering/VexFont.swift`:
  - CSS helpers: `VexFont.validate`, `fromCSSString`, `toCSSString`, `convertSizeToPixelValue`/`PointValue`, `scaleSize`, `isBold`, `isItalic`.
  - `formatJSNumber(_:)` formats a number like JavaScript (`30` not `30.0`). Use it when you build `"\(n)pt"` strings.
- `Rendering/FontRegistry.swift`: bundled OTF fonts (Bravura, Academico, Gonville, Petaluma, Petaluma Script, Leland, Edwin).
- `Rendering/RenderContext.swift`:
  - Adds `pointerRect`, `openRotation(_:_:_:)` and `closeRotation()` (with default no-op implementations).
  - `setFont(_ fontInfo:)`, `setFont(_ css: String)`, `setFont(_ family:_ size:_ weight:_ style:)`.
- `Rendering/SVGRenderContext.swift`: a faithful port of `svgcontext.ts`.
- `Core/VexRuntimeContext.swift`:
  - `VexRuntime.getCurrentContext()`.
  - `.metrics`, `.setFonts([...])`, `.getFonts()`.
  - `.upstreamParityMode`: `true` disables the OSMD `VexFlowPatch` deviations that are marked "(gated)" in `docs/local-deviations.md`.

## Removed. Do not use

- `Glyph`, `GlyphProps` from Tables, `Glyph.renderGlyph`, `Glyph.getWidth`, `TextFormatter`, `TimeSigGlyph`, `FontLoader`, `BoundingBoxComputation`.
- `VexFont` instances: `VexFont` is now a caseless enum.
- `musicFontStack`, `Tables.currentMusicFont()`, `textFont` class vars.
- Music glyphs are drawn as text:
  - Set `text = Glyphs.xxx` on an element and call `renderText(ctx, xPos:, yPos:)`.
  - Alternatively, call `ctx.fillText` after `ctx.setFont(fontInfo)`, as upstream does.
- Glyph sizes come from `textMetrics` and `width`.

## Swift conventions

- `public` API, `open class` where upstream classes are subclassed.
- `Double` for numbers. Methods that return `this` become `@discardableResult ... -> Self`.
- Upstream `throw new RuntimeError(code, msg)` maps to `throw VexError(code, msg)`. Keep the existing error type in the file if it has one.
- Keep the Swift-native typed APIs that already exist in the file:
  - Typed specs: `NoteDurationSpec`, `StaffKeySpec`, `ClefName`, `TimeSignatureSpec`, `NonEmptyArray`.
  - Throwing and failable `…Throwing` / `init(parsing:)` variants.
  Adapt their implementation to the new code.
- Keep the existing Swift method names and argument labels when the upstream method has the same name. Use the upstream 5.0 name for renamed or new methods.
- Use `VexRuntime.getCurrentContext()` for global state. Never use `ProcessInfo` environment checks.
- Do not use `try!` or force unwraps in reachable code paths.
- A file header names the upstream file and the 5.0.0 version.

## Scope rules for parallel work

- Edit only the files assigned to you.
- If your file needs something from a file owned by another agent, use the upstream 5.0.0 name and signature. That agent ports the same upstream API.
- Write any cross-file assumption to `docs/port-notes/<your-group>.md`.
- The package does not compile until all groups finish. Use `swiftc -parse <file>` to check syntax. Do not try to fix other groups' files.
- Do not edit tests. Tests are updated after integration.
