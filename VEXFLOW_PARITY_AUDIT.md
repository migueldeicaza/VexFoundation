# VexFlow -> VexFoundation Parity Audit (2026-02-21)

## Scope & Baseline

- Upstream reference: local `vexflow` checkout at commit `a0c4d47a` (`master`).
- Port reference: local `VexFoundation` working tree.
- Method:
1. Compared exported source modules from `vexflow/src/index.ts`.
2. Compared module inventories (`vexflow/src/*.ts` vs `VexFoundation/Sources/VexFoundation/**/*.swift`).
3. Compared upstream test topics (`vexflow/tests/*_tests.ts`) against current VexFoundation suites.
4. Spot-checked concrete behavior parity in key files.

## High-Level Status

- VexFlow exported modules (from `src/index.ts`): `89`
- VexFoundation source files: `103`
- VexFlow test topics (`*_tests.ts`): `70`
- VexFoundation test files: `34`
- Current local `swift test` result: `845` tests passing
- Parity matrix status: modules `85 implemented / 0 partial / 4 intentional omissions`, topics `68 covered / 0 partial / 2 intentional omissions`

## Status Update (2026-02-21)

Completed since initial audit:

- Phase 1 complete: registry lifecycle parity + reachable `try!` removal in core paths.
- Phase 2 complete: beaming, rests/rhythm/three-voice/unison, percussion parity tests.
- Phase 3 complete: `TextFormatter` replacement contract implemented and text metric parity tests added.
- Phase 4 complete: optional compatibility layer added (`Flow`, `Vex`, `Version`) with smoke tests.
- Phase 5.1/5.2 complete: parity matrix generator (`tools/generate_parity_matrix.sh`) and checked-in matrix (`docs/parity-matrix.md`).
- Phase 5.3 complete: CI gate added (`.github/workflows/ci.yml`) for matrix freshness + full `swift test`.
- Phase 5.4 complete: runtime hardening for parity reliability (`Glyph` lazy font bootstrap, `Registry` thread-safe index access).
- Phase 6.1 complete: module-level partials closed with first-class `typeguard` and `timesigglyph` counterparts.
- Phase 6.2 complete: replaced `nonisolated(unsafe)` mutable globals with `VexRuntimeContext`-backed state and context-switching APIs.
- Phase 6.3 complete: threaded explicit runtime contexts through `Factory` / `EasyScore` / `System` constructors and factory creation paths.
- Phase 6.4 complete: hardened accidental string convenience APIs to typed-first + `throwing` / `nil` parse behavior (no trap-based parsing).
- Phase 6.5 complete: hardened `Music` / `KeyManager` string parsing and key/note helpers to `throwing` / `nil` APIs, with failable compatibility wrappers.
- Phase 6.6 complete: hardened `EasyScore.Builder` semantic parse paths to return parse failures instead of trapping, with new throwing helpers (`parseThrowing`/`notesThrowing`).
- Phase 6.7 complete: hardened `Parser` bad-grammar handling to typed errors (`ParserError`/`ParserParseError`) with safe parse failures instead of trapping.
- Phase 6.8 complete: converted remaining `Music` validation-heavy `get*` helpers to typed `throws` APIs and removed associated validation-triggered traps.
- Phase 6.9 complete: removed remaining trap-based failures in high-level `Factory` / `EasyScore` / `System` APIs by introducing typed init/draw errors and direct-init failure diagnostics.
- Phase 7.1 complete: replaced formatting-layer trap paths in `Voice` / `Formatter` / `Beam` / `Tuplet` with typed error models and strict throwing APIs, while retaining non-crashing convenience wrappers.
- Phase 7.2 complete: hardened precondition-heavy paths in `Tickable` / `Note` / `Glyph` with typed errors and strict throwing APIs, and removed module-local `fatalError` calls via non-crashing fallback wrappers.
- Phase 7.3 complete: hardened `StemmableNote` / `StaveNote` / `TabNote` precondition paths with typed errors, strict throwing APIs, validating initializers, and non-crashing convenience wrappers.
- Phase 7.4 complete: removed remaining connector/stave/modifier trap sites with typed errors and strict throwing APIs across `Curve` / `StaveLine` / `StaveTie` / `VibratoBracket` / `TabSlide` and `Modifier`-layer + `Stave` support classes, with compatibility-safe fallback wrappers and new regression coverage.
- Phase 7.5 complete: removed remaining trap sites in core/runtime/tablature boundary modules (`Element`, `Registry`, `Tables`, `TimeSignatureSpec`, `FontLoader`, `TextDynamics`, `Tuning`) using typed errors, strict throwing APIs, and failable convenience wrappers.
- Phase 8.1 complete: added deterministic SVG rendering backend (`SVGRenderContext`), golden SVG snapshot coverage, and `tools/svg_snapshot.sh` workflow for regenerate/check parity validation loops.
- Phase 8.2 in progress: started parity deepening for weakly mapped behavior topics by adding dedicated upstream-style `voice` / `formatter` / `tickcontext` behavioral parity tests.
- Phase 8.2 progress: added dedicated upstream-style `parser` / `factory` / `easyscore` / `registry` parity suite and fixed single-note EasyScore chord semantic handling (`(c5)`-style inputs).
- Phase 8.2 progress: added dedicated upstream-style `music` / `keymanager` / `tuning` parity suite with category-aligned behavioral checks.
- Phase 8.2 progress: added dedicated upstream-style `bend` / `stringnumber` / `strokes` parity suite with focused scenario-level coverage.
- Phase 8.2 progress: added dedicated upstream-style `frethandfinger` parity suite with notation and multi-voice fingering/stroke scenario coverage.
- Phase 8.2 progress: resolved `ModifierContext`/`StringNumber` exclusivity conflict in mixed-modifier multi-voice formatting and restored the full upstream-like `frethandfinger` scenario assertions.
- Phase 8.2 progress: added dedicated upstream-style `fraction` parity suite with arithmetic/comparison/lcmm-gcd coverage and explicit topic mapping.
- Phase 8.2 progress: deepened `clef` / `keysignature` parity with upstream-style parser, variant-render, end-clef key, and inline clef-change scenarios in `KeyClefParityTests`.
- Phase 8.2 progress: added dedicated upstream-style `timesignature` parity suite with parser, additive/alternating/interchangeable/aggregate/complex, multi-stave alignment, and inline change scenarios.
- Phase 8.2 progress: added dedicated upstream-style `stave` / `stavemodifier` parity suite with sort/open-barline, begin/end mutation, repeat/multi-measure, end-modifier grid, and repetition/volta/tempo/text scenarios.
- Phase 8.2 progress: added typed-first `Stave` convenience APIs for section/tempo/text/volta/repetition with throwing + nil-returning string wrappers, and direct parity tests for those entry points.

## Remaining Gaps

### 1) Rendering backend module parity remains intentionally partial

VexFlow exports browser/runtime-specific modules (`renderer`, `canvascontext`, `svgcontext`, `web`).
VexFoundation keeps a Swift-native rendering abstraction:

- `Sources/VexFoundation/Rendering/RenderContext.swift`
- `Sources/VexFoundation/Rendering/SwiftUICanvasContext.swift`

Current decision: these browser modules are intentional out-of-core omissions in the core package.

### 2) Compatibility surface is selective, not exhaustive

`Flow`/`Vex` compatibility APIs exist, but only for high-value migration helpers.
The Swift package intentionally avoids a full JS-style static alias mirror for every exported symbol.

### 3) Ongoing governance requires maintenance discipline

Parity matrix generation and CI freshness enforcement are in place.
Remaining work is continuous: keep mappings and coverage statuses updated as APIs and tests evolve.

### 4) Runtime state still defaults to a shared context unless callers isolate it

The core now supports isolated runtime contexts, but call sites that do not opt in
still share the default runtime context. Further migration can thread explicit
`VexRuntimeContext` values through higher-level entry points for stronger isolation by construction.

## Feature Surface Notes

- `textformatter`: represented by `Sources/VexFoundation/Rendering/TextFormatter.swift`.
- `flow` / `vex` / `version`: represented by `Sources/VexFoundation/Compatibility/Flow.swift`, `Sources/VexFoundation/Compatibility/Vex.swift`, and `Sources/VexFoundation/Compatibility/Version.swift`.
- `renderer` / `canvascontext` / `svgcontext` / `web`: documented non-goals for core Swift-native runtime.
- `stavebarline`, `stavevolta`, `strokes`: represented with renamed Swift modules/types (`Barline`, `Volta`, `Stroke`).
- `timesigglyph`: represented by `Sources/VexFoundation/Stave/TimeSigGlyph.swift` (with `TimeSignatureGlyph` alias).
- `typeguard`: represented by `Sources/VexFoundation/Core/TypeGuard.swift` with `VexCategory` and typed predicates.

## Test Coverage Notes

Direct parity coverage now exists for previously highlighted high-value topics:

- `auto_beam_formatting`, `crossbeam`
- `rests`, `rhythm`, `threevoice`, `unison`
- `percussion`
- `textformatter` (replacement-contract parity)
- `typeguard`, `vf_prefix`
- `bach` (demo/integration scenario)

Intentional test-topic omissions remain:

- `renderer`
- `offscreencanvas`

## Prioritized Next Plan

## Governance Maintenance (continuous)

1. Keep `docs/parity-matrix.md` current when module/test coverage changes.
2. Adjust curated mappings in `tools/generate_parity_matrix.sh` for newly added/renamed symbols.
3. Keep CI green on parity freshness + full test pass.
