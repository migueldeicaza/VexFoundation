// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/renderer.ts` (VexFlow 5.8.0): only the shared path drawing.
// Canvas and SVG renderer setup and shared path drawing.

import Foundation

/// Port of the shared path drawing of `src/renderer.ts` (VexFlow 5.8.0).
/// The DOM and canvas setup of upstream `Renderer` is not ported.
public enum Renderer {
    /// Draw alternating dashes and gaps in any direction. `[3, 0]` draws a continuous line.
    /// Reject nonfinite geometry (`BadDashLine`) and patterns that would require more than
    /// 16,384 dash or gap segments (`BadDashPattern`). An error leaves the context untouched.
    public static func drawDashedLine(
        _ context: RenderContext,
        _ fromX: Double,
        _ fromY: Double,
        _ toX: Double,
        _ toY: Double,
        _ dashPattern: [Double]
    ) throws {
        let dx = toX - fromX
        let dy = toY - fromY
        let length = hypot(dx, dy)
        if !length.isFinite {
            throw VexError("BadDashLine", "Dashed lines require finite endpoints and a finite length.")
        }
        let stops = try dashStops(length, dashPattern)

        context.beginPath()
        context.moveTo(fromX, fromY)
        for (index, distance) in stops.enumerated() {
            // Measure from the original point so rounding in a small step cannot stall the path.
            let x = distance == length ? toX : fromX + (dx / length) * distance
            let y = distance == length ? toY : fromY + (dy / length) * distance
            if index % 2 == 0 {
                context.lineTo(x, y)
            } else {
                context.moveTo(x, y)
            }
        }
        context.closePath()
        context.stroke()
    }
}
