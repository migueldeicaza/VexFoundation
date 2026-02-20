# Rendering and Fonts

Rendering depends on context, fonts, and sequencing.

## 1. Rendering Context

Primary APIs:

- ``VexCanvas``
- ``SwiftUICanvasContext``
- ``RenderContext``

Minimal context setup:

```swift
VexCanvas(width: 500, height: 200) { ctx in
    ctx.clear()
}
```

## 2. Font Initialization with ``FontLoader``

```swift
FontLoader.loadDefaultFonts()   // Bravura + Custom
```

Alternative:

```swift
FontLoader.loadAllFonts()
```

## 3. Draw Sequence

```swift
let f = Factory()
_ = f.setContext(ctx)

let system = f.System(options: SystemOptions(factory: f))
// add voices/staves
system.format()
try? f.draw()
```

## 4. Custom Styling via ``RenderContext``

```swift
ctx.setStrokeStyle("#222")
ctx.setLineWidth(1.5)
ctx.beginPath()
ctx.moveTo(10, 10)
ctx.lineTo(300, 10)
ctx.stroke()
```

## 5. Quick Failure Checklist

- Context set via ``Factory/setContext(_:)``.
- Fonts loaded before glyph draw.
- ``System/format()`` called before drawing layout-dependent content.

## Key Symbols

- ``RenderContext``
- ``FontLoader/loadDefaultFonts()``
- ``FontLoader/loadAllFonts()``
- ``Factory/setContext(_:)``
- ``Factory/draw()``
- ``System/format()``

## Related

- <doc:GettingStarted>
- <doc:Troubleshooting>
