# Brief: port one upstream VexFlow release

The integrator gives you a release range `FROM..TO` (for example `5.1.0..5.2.0`).

## Read first
- `docs/porting-5.0-guide.md`: conventions. They still apply.
- `docs/local-deviations.md`: local patches that must survive. The patches marked "gated" are off when `VexRuntime.getCurrentContext().upstreamParityMode` is true.
- `docs/porting-5.x-manifest.md`: the section for `TO`.
- `docs/port-notes/<earlier releases>.md`: what earlier passes ported and the decisions they made.

## Upstream
- Repository with all tags: `/Users/miguel/cvs/music/vexflow`.
- Per-file diff: `git -C /Users/miguel/cvs/music/vexflow diff FROM TO -- src/<file>.ts`.
- Full file at `TO`: `git show TO:src/<file>.ts`.
- History: `git log --oneline FROM..TO`.
- Release notes: `git show TO:changelog/CHANGELOG.md`.
- Upstream tests: `git diff FROM TO -- tests/`.

## What to do
1. Port every behavior change to existing modules. Keep the same drawing order and constants.
2. Port each new module as a new Swift file in a fitting folder:
   - `Layout/` for system, sheet, continuous and page layout.
   - `Publication/` for publication code.
   - `Instruments/` for instrument-specific notation.
   - `API/EasyScore/` for the EasyScore submodules.
3. Replace browser-only code (DOM, canvas, fetch) with native code. Use `TextMeasurer`, `SVGRenderContext` and `CoreText`. List what you could not port.
4. Keep `Metrics.defaults` identical to upstream `MetricsDefaults` at `TO`.
5. Keep the Swift-native APIs and the local deviations. Do not use `ProcessInfo` environment checks. Do not use `try!` in reachable code.
6. Tests:
   - Port the upstream logic tests (`tests/*.ts` asserts and `tests/node/*.mjs`) that cover new behavior. Put them in Swift Testing suites named `Upstream<release>Tests.swift`.
   - For each new upstream visual test case, add an opt-in parity case in `UpstreamSVGParityTests-<Module>.swift` that mirrors the upstream test code.
   - Update existing parity cases whose upstream test code changed.
   - Update unit tests whose asserted behavior the release changes on purpose. Give the reason in your notes.
7. Build in your own scratch path:
   - `swift build --scratch-path .build-port`
   - `swift test --scratch-path .build-port --skip UpstreamSVGParityTests` must pass.
8. When `../vexflow-TO/build/images/reference` exists, run the parity suite against it:
   ```
   VEXFOUNDATION_UPSTREAM_SVG_PARITY=1 VEXFOUNDATION_UPSTREAM_TAG=TO \
   VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR=$PWD/.build/upstream-svg-parity/artifacts-port \
   swift test --scratch-path .build-port --filter UpstreamSVGParityTests
   tools/parity_report.py --artifacts .build/upstream-svg-parity/artifacts-port --min 0.1
   ```
   Otherwise, compare against the newest earlier reference set. Explain each change as an intended upstream change.
9. Write `docs/port-notes/TO.md`: what you ported, the new API, what you did not port (with the reason), and the parity results.
10. Do not commit.

## Reply (under 600 words)
- Files changed and added.
- New public API.
- Upstream behavior you did not port.
- Test and parity results.
