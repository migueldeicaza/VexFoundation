# VexFoundation

VexFoundation is a Swift port of [VexFlow](https://vexflow.com), focused on music notation rendering with Swift-native APIs and stronger type safety than the original TypeScript surface.

The project keeps VexFlow concepts (`Factory`, `EasyScore`, `System`, notes, modifiers, beams, tuplets, tablature, etc.) while intentionally preferring typed models over stringly-typed inputs.

## Status

- Swift Package (`swift-tools-version: 6.0`)
- Platforms: iOS 16+, macOS 13+
- Active port: API parity with VexFlow is in progress and APIs may evolve
- Current test suite: `774` passing tests

## Installation

Add the package as a local dependency in `Package.swift`:

```swift
dependencies: [
    .package(path: "../VexFoundation")
]
```

Then add `"VexFoundation"` to your target dependencies.

## Quick Start (SwiftUI + EasyScore)

```swift
import SwiftUI
import VexFoundation

struct ScoreView: View {
    var body: some View {
        VexCanvas(width: 500, height: 200) { ctx in
            ctx.clear()
            FontLoader.loadDefaultFonts()

            let f = Factory(options: FactoryOptions(width: 500, height: 200))
            _ = f.setContext(ctx)

            let score = f.EasyScore()
            let system = f.System(options: SystemOptions(factory: f, x: 10, width: 480, y: 10))

            let upper = score.notes("C#5/q, B4, A4, G#4", options: ["stem": "up"])
            let lower = score.notes("C#4/h, C#4", options: ["stem": "down"])

            _ = system.addStave(SystemStave(
                voices: [
                    score.voice(upper.map { $0 as Note }),
                    score.voice(lower.map { $0 as Note })
                ]
            ))
            .addClef(.treble)
            .addTimeSignature(.meter(4, 4))

            system.format()
            try? f.draw()
        }
    }
}
```

## Native Typed API (Without EasyScore Strings)

```swift
import SwiftUI
import VexFoundation

struct TypedScoreView: View {
    var body: some View {
        VexCanvas(width: 500, height: 200) { ctx in
            ctx.clear()
            FontLoader.loadDefaultFonts()

            let f = Factory(options: FactoryOptions(width: 500, height: 200))
            _ = f.setContext(ctx)

            let c4 = StaffKeySpec(letter: .c, octave: 4)
            let e4 = StaffKeySpec(letter: .e, octave: 4)
            let g4 = StaffKeySpec(letter: .g, octave: 4)

            let n1 = f.StaveNote(StaveNoteStruct(
                keys: NonEmptyArray(c4),
                duration: .quarter
            ))
            let n2 = f.StaveNote(StaveNoteStruct(
                keys: NonEmptyArray(e4),
                duration: .quarter
            ))
            let n3 = f.StaveNote(StaveNoteStruct(
                keys: NonEmptyArray(g4),
                duration: .half
            ))

            let voice = f.Voice(timeSignature: .meter(4, 4))
            _ = voice.addTickables([n1, n2, n3])

            let system = f.System(options: SystemOptions(factory: f, x: 10, width: 480, y: 10))
            _ = system.addStave(SystemStave(voices: [voice]))
                .addClef(.treble)
                .addTimeSignature(.meter(4, 4))

            system.format()
            try? f.draw()
        }
    }
}
```

## Strongly Typed API (Preferred)

VexFoundation favors typed specs over free-form strings:

- `NoteDurationSpec` instead of raw duration strings
- `StaffKeySpec` instead of raw key tokens
- `TimeSignatureSpec` instead of raw time signature strings
- `NonEmptyArray` where empty collections are invalid (for example, stave/grace note keys)

```swift
import VexFoundation

let cSharp4 = StaffKeySpec(letter: .c, accidental: .sharp, octave: 4)
let e4 = StaffKeySpec(letter: .e, octave: 4)

let sn = StaveNote(StaveNoteStruct(
    keys: NonEmptyArray(cSharp4, e4),
    duration: .quarter
))
```

## String Parsing at API Boundaries

String constructors / factory paths are still available, but explicit:

- Throwing parse APIs for recoverable errors
- Failable parse APIs when you want `nil` on failure
- Typed APIs remain the recommended default

```swift
import VexFoundation

// Throwing parse API
let parsed = try StaveNoteStruct(
    parsingKeys: ["c#/4", "e/4"],
    duration: "8dr"
)

// Failable parse API
let maybeParsed = StaveNoteStruct(
    parsingKeysOrNil: ["c#/4", "e/4"],
    duration: .eighth
)

// Duration-only parse examples
let ghost = try GhostNote("8r")
let maybeGhost = GhostNote(parsingDuration: "8r")

// Factory string convenience (throwing / failable)
let f = Factory()
let sharp = try f.Accidental(parsing: "#")
let maybeAccidental = f.Accidental(parsingOrNil: "invalid")
```

## Compatibility Layer (Optional)

VexFoundation ships lightweight compatibility symbols for migration scenarios:

- `Flow`: selected constants/utilities and music-font helpers.
- `Vex`: selected helper utilities.
- `Version` / `VexVersion`: build metadata.

String convenience APIs remain explicit and safe:

```swift
import VexFoundation

_ = try Flow.setMusicFont(parsing: ["Bravura", "Custom"])
let maybeFonts = Flow.setMusicFont(parsingOrNil: ["Petaluma", "Custom"])
```

## Runtime Context (State Isolation)

Mutable runtime state is now scoped through `VexRuntimeContext`:

- Default registry (`Registry.enableDefaultRegistry`)
- Music font stack and glyph cache
- Auto-generated element IDs
- Runtime flags such as `Tables.UNISON`

Use isolated contexts to avoid cross-test or cross-session leakage:

```swift
import VexFoundation

let context = Flow.makeRuntimeContext()

Flow.withRuntimeContext(context) {
    FontLoader.loadDefaultFonts()
    Tables.UNISON = false

    let reg = Registry()
    Registry.enableDefaultRegistry(reg)

    let e = VexElement()
    print(e.getAttribute("id") ?? "")
}
```

Constructor-level runtime threading is also available:

```swift
import VexFoundation

let runtime = Flow.makeRuntimeContext()
let factory = Factory(runtimeContext: runtime)
let score = factory.EasyScore(options: EasyScoreOptions(runtimeContext: runtime))
let system = factory.System(options: SystemOptions(runtimeContext: runtime, x: 10, width: 480, y: 20))
```

## Key Differences from VexFlow

- API redesign favors compile-time validation.
- Invalid states are reduced via typed enums/specs and non-empty collections.
- Parsing is explicit at boundaries, not implicit throughout the API.
- Lightweight `Flow`/`Vex` compatibility facades are available for incremental migration.
- SwiftUI rendering backend (`VexCanvas` / `SwiftUICanvasContext`) is provided for app integration.
- Core scope is Swift-native rendering abstractions (`RenderContext`) rather than 1:1 browser modules (`renderer`, `canvascontext`, `svgcontext`, `web`).

## Development

```bash
swift build
swift test
tools/generate_parity_matrix.sh
```

CI verifies parity matrix freshness with:

```bash
tools/generate_parity_matrix.sh --check
```

## Documentation (DocC)

Generate local documentation:

```bash
swift package \
  --allow-writing-to-directory docs-site \
  generate-documentation \
  --target VexFoundation \
  --disable-indexing \
  --transform-for-static-hosting \
  --hosting-base-path VexFoundation \
  --output-path docs-site
```

The package includes `swift-docc-plugin` support in `Package.swift`.

### GitHub Pages publishing

Docs are published by `.github/workflows/docs.yml` on pushes to `main` (and manually via `workflow_dispatch`).

Published docs:

- https://migueldeicaza.github.io/VexFoundation/

## Attribution

VexFoundation is derived from VexFlow and preserves original attribution:

- VexFlow: https://github.com/vexflow/vexflow
- Original author: Mohit Muthanna Cheppudira

## License

MIT (see `LICENSE`).
