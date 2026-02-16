// VexFoundation - SwiftUI View wrapper for VexFlow rendering.

import SwiftUI

/// A SwiftUI View that provides a VexFlow rendering surface.
///
/// Usage:
/// ```swift
/// VexCanvas(width: 800, height: 200) { ctx in
///     // ctx is a RenderContext — pass it to VexFlow draw calls
///     ctx.setFillStyle("#000")
///     ctx.beginPath()
///     ctx.moveTo(10, 100)
///     ctx.lineTo(790, 100)
///     ctx.stroke()
/// }
/// ```
public struct VexCanvas: View {
    let width: Double
    let height: Double
    let drawCallback: (SwiftUICanvasContext) -> Void

    public init(
        width: Double = 600,
        height: Double = 400,
        draw: @escaping (SwiftUICanvasContext) -> Void
    ) {
        self.width = width
        self.height = height
        self.drawCallback = draw
    }

    public var body: some View {
        Canvas { gc, size in
            let ctx = SwiftUICanvasContext(graphicsContext: gc, size: size)
            drawCallback(ctx)
        }
        .frame(width: width, height: height)
    }
}
