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

#if DEBUG
import SwiftUI

private struct VexCanvasBasicRenderingPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Primitives")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VexCanvas(width: 360, height: 140) { ctx in
                    ctx.clear()

                    ctx.setStrokeStyle("#111")
                    ctx.setLineWidth(2)
                    ctx.beginPath()
                    ctx.moveTo(20, 20)
                    ctx.lineTo(340, 20)
                    ctx.moveTo(20, 60)
                    ctx.quadraticCurveTo(120, 10, 220, 60)
                    ctx.bezierCurveTo(250, 100, 300, 20, 340, 60)
                    ctx.stroke()

                    ctx.setFillStyle("#0B74DE")
                    ctx.beginPath()
                    ctx.arc(70, 105, 16, 0, .pi * 2, false)
                    ctx.fill()

                    ctx.setStrokeStyle("#0B74DE")
                    ctx.setLineWidth(1.5)
                    ctx.beginPath()
                    ctx.rect(120, 90, 60, 30)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.moveTo(230, 120)
                    ctx.lineTo(300, 120)
                    ctx.lineTo(265, 90)
                    ctx.closePath()
                    ctx.setFillStyle("rgba(240,88,34,0.8)")
                    ctx.fill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Styles and Transform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VexCanvas(width: 360, height: 140) { ctx in
                    ctx.clear()

                    ctx.setStrokeStyle("#333")
                    ctx.setLineWidth(8)
                    ctx.setLineCap(.round)
                    ctx.setLineDash([10, 8])
                    ctx.beginPath()
                    ctx.moveTo(24, 30)
                    ctx.lineTo(336, 30)
                    ctx.stroke()

                    ctx.setLineDash([])
                    ctx.save()
                    ctx.scale(1.4, 1.4)
                    ctx.setFillStyle("#98C379")
                    ctx.fillRect(20, 40, 40, 24)
                    ctx.restore()

                    ctx.setShadowColor("rgba(0,0,0,0.35)")
                    ctx.setShadowBlur(6)
                    ctx.setFillStyle("#C678DD")
                    ctx.beginPath()
                    ctx.arc(240, 95, 22, 0, .pi * 2, false)
                    ctx.fill()

                    ctx.setShadowBlur(0)
                    ctx.setStrokeStyle("#C678DD")
                    ctx.setLineWidth(2)
                    ctx.beginPath()
                    ctx.rect(280, 73, 46, 46)
                    ctx.stroke()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Text and Baseline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VexCanvas(width: 360, height: 140) { ctx in
                    ctx.clear()

                    ctx.setStrokeStyle("#D73A49")
                    ctx.setLineWidth(1)
                    ctx.beginPath()
                    ctx.moveTo(20, 70)
                    ctx.lineTo(340, 70)
                    ctx.stroke()
                    drawDot(ctx, x: 20, y: 70, color: "#D73A49")

                    ctx.setFillStyle("#111")
                    ctx.setFont("Georgia", 18, "normal", "normal")
                    let label = "Baseline aligned text"
                    ctx.fillText(label, 20, 70)

                    let measured = ctx.measureText(label)
                    ctx.setStrokeStyle("#0366D6")
                    ctx.beginPath()
                    ctx.rect(20 + measured.x, 70 + measured.y, measured.width, measured.height)
                    ctx.stroke()

                    ctx.setFillStyle("#0366D6")
                    ctx.setFont("Georgia", 14, "bold", "italic")
                    ctx.fillText("Measured bounds shown in blue", 20, 112)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .frame(width: 392)
        .background(Color(white: 0.96))
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("VexCanvas Basic Rendering", traits: .sizeThatFitsLayout) {
    VexCanvasBasicRenderingPreview()
}
#endif

