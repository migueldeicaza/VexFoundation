# Installation and Platform Support

Add VexFoundation with Swift Package Manager and verify setup.

## Supported Platforms

- Swift tools: `6.0`
- iOS: `16+`
- macOS: `13+`

## Add Dependency

```swift
dependencies: [
    .package(path: "../VexFoundation")
]
```

Then add `"VexFoundation"` to your target dependencies.

## Build Verification

```bash
swift build
swift test
```

## Runtime Verification Snippet

```swift
VexCanvas(width: 320, height: 120) { ctx in
    ctx.clear()
    FontLoader.loadDefaultFonts()

    let f = Factory()
    _ = f.setContext(ctx)
}
```

## Key Symbols

- ``Factory``
- ``FactoryOptions``
- ``Factory/setContext(_:)``
- ``VexCanvas``
- ``FontLoader``
- ``FontLoader/loadDefaultFonts()``

## Related

- <doc:GettingStarted>
- <doc:RenderingAndFonts>
