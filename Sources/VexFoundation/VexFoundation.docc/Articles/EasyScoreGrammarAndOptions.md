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

For explicit error handling, prefer throwing helpers:

```swift
let parsed = try score.parseThrowing("C4/q, D4/q")
let notes = try score.notesThrowing("C4/q, D4/q")
```

## Related

- <doc:EasyScoreBasics>
- ``EasyScoreOptions``
- ``EasyScore/notes(_:options:)``
- ``EasyScore/notesThrowing(_:options:)``
- ``EasyScore/voice(_:time:)``
- ``EasyScore/parseThrowing(_:options:)``
- ``Parser``
