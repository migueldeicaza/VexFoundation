# EasyScore Grammar and Options

``EasyScore`` parses concise notation strings into ``StemmableNote`` values.

## 1. Basic Parse Flow

```swift
let score = f.EasyScore()
let notes = score.notes("C5/q, D5, E5, F5", options: ["stem": "up"])
let voice = score.voice(notes, time: .meter(4, 4))
```

## 2. Grammar Shapes

- Note token: `C#5`, `Bb4`
- Chord token: `(C4 E4 G4)`
- Duration token: `/q`, `/8`, `/16`
- Dot token: `.` or repeated dots
- Type suffix: rest and other note kinds

Runnable chord example:

```swift
let chordLine = score.notes("(C4 E4 G4)/8, A4/8")
```

## 3. Defaults with ``EasyScoreDefaults``

```swift
_ = score.set(defaults: EasyScoreDefaults(
    clef: .treble,
    time: .meter(4, 4),
    stem: "auto"
))
```

## 4. Parse Result with ``EasyScore/parse(_:options:)``

```swift
let result = score.parse("C4/q, D4/q")
if result.success {
    // safe to proceed
}
```

## 5. Commit Hooks

```swift
score.addCommitHook { options, note, _ in
    if let id = options["id"] {
        _ = note.setAttribute("id", id)
    }
}
```

## 6. Error Mode

``EasyScoreOptions/throwOnError`` switches parse failures into fatal behavior. For user-input flows, keep this off and inspect parse success.

## Related

- <doc:EasyScoreBasics>
- ``EasyScoreOptions``
- ``EasyScoreOptions/throwOnError``
- ``EasyScore/notes(_:options:)``
- ``EasyScore/voice(_:time:)``
- ``Parser``
