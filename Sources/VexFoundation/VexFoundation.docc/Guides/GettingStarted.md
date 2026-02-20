# Getting Started

Build and render your first score with SwiftUI and VexFoundation.

## 1. Create a Drawing Surface

Use ``VexCanvas`` to receive a ``SwiftUICanvasContext`` inside a draw closure.

```swift
import SwiftUI
import VexFoundation

struct ScoreView: View {
    var body: some View {
        VexCanvas(width: 500, height: 200) { ctx in
            ctx.clear()
            FontLoader.loadDefaultFonts()
        }
    }
}
```

## 2. Create Factory and Context

Use ``Factory`` and call ``Factory/setContext(_:)`` before drawing.

```swift
let f = Factory(options: FactoryOptions(width: 500, height: 200))
_ = f.setContext(ctx)
```

## 3. Add Typed Notes and Voice

Use ``StaveNoteStruct`` + ``StaffKeySpec`` + ``NoteDurationSpec``.

```swift
let c4 = StaffKeySpec(letter: .c, octave: 4)
let e4 = StaffKeySpec(letter: .e, octave: 4)
let g4 = StaffKeySpec(letter: .g, octave: 4)

let n1 = f.StaveNote(StaveNoteStruct(keys: NonEmptyArray(c4), duration: .quarter))
let n2 = f.StaveNote(StaveNoteStruct(keys: NonEmptyArray(e4), duration: .quarter))
let n3 = f.StaveNote(StaveNoteStruct(keys: NonEmptyArray(g4), duration: .half))

let voice = f.Voice(timeSignature: .meter(4, 4))
_ = voice.addTickables([n1, n2, n3])
```

## 4. Add System and Draw

Use ``System`` + ``SystemStave`` and format before draw.

```swift
let system = f.System(options: SystemOptions(factory: f, x: 10, width: 480, y: 10))
_ = system.addStave(SystemStave(voices: [voice]))
    .addClef(.treble)
    .addTimeSignature(.meter(4, 4))

system.format()
try? f.draw()
```

## Full Minimal Example

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

            let c4 = StaffKeySpec(letter: .c, octave: 4)
            let e4 = StaffKeySpec(letter: .e, octave: 4)
            let g4 = StaffKeySpec(letter: .g, octave: 4)

            let n1 = f.StaveNote(StaveNoteStruct(keys: NonEmptyArray(c4), duration: .quarter))
            let n2 = f.StaveNote(StaveNoteStruct(keys: NonEmptyArray(e4), duration: .quarter))
            let n3 = f.StaveNote(StaveNoteStruct(keys: NonEmptyArray(g4), duration: .half))

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

## Key Symbols

- ``Factory/setContext(_:)``
- ``Factory/StaveNote(_:)``
- ``Factory/Voice(timeSignature:)``
- ``Factory/System(options:)``
- ``System/addStave(_:)``
- ``System/format()``
- ``Factory/draw()``

## Next

- <doc:TypedAPIBasics>
- <doc:EasyScoreBasics>
