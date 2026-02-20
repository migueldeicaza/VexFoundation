# EasyScore Basics

Use ``EasyScore`` when input is naturally text-based.

## 1. Create ``EasyScore`` from ``Factory``

```swift
let f = Factory()
let score = f.EasyScore()
```

## 2. Parse Notes Quickly

```swift
let notes = score.notes("C#5/q, B4, A4, G#4", options: ["stem": "up"])
let voice = score.voice(notes, time: .meter(4, 4))
```

## 3. Configure Defaults with ``EasyScoreDefaults``

```swift
_ = score.set(defaults: EasyScoreDefaults(
    clef: .treble,
    time: .meter(3, 4),
    stem: "auto"
))

let line = score.notes("C5, D5, E5")
```

## 4. Use Parse Result Directly

```swift
let result = score.parse("(C4 E4 G4)/8, A4/8")
if !result.success {
    // handle parse failure in app code
}
```

## 5. Add Beams and Tuplets

```swift
let run = score.notes("C5/8, D5, E5, F5, G5, A5")
_ = score.beam(Array(run[0..<4]))
_ = score.tuplet(Array(run[3..<6]))
```

## 6. Add a Commit Hook

```swift
score.addCommitHook { options, note, _ in
    if options["id"] == "lead" {
        _ = note.addClass("lead-voice")
    }
}
```

## Notes

``EasyScoreOptions/throwOnError`` enables fatal parse handling. For user-entered data, prefer validating parse success before draw.

## Key Symbols

- ``Factory/EasyScore(options:)``
- ``EasyScore/set(defaults:)``
- ``EasyScore/notes(_:options:)``
- ``EasyScore/voice(_:time:)``
- ``EasyScore/parse(_:options:)``
- ``EasyScore/addCommitHook(_:)``
- ``EasyScoreOptions/throwOnError``

## Next

- <doc:EasyScoreGrammarAndOptions>
- <doc:Troubleshooting>
