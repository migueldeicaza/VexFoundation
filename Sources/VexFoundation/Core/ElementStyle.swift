// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Visual style applied to elements during rendering.
/// Colors are CSS color strings (e.g., "red", "#ff0000", "rgba(255,0,0,0.5)").
public struct ElementStyle: Sendable {
    public var shadowColor: String?
    public var shadowBlur: Double?
    public var fillStyle: String?
    public var strokeStyle: String?
    public var lineWidth: Double?

    public init(
        shadowColor: String? = nil,
        shadowBlur: Double? = nil,
        fillStyle: String? = nil,
        strokeStyle: String? = nil,
        lineWidth: Double? = nil
    ) {
        self.shadowColor = shadowColor
        self.shadowBlur = shadowBlur
        self.fillStyle = fillStyle
        self.strokeStyle = strokeStyle
        self.lineWidth = lineWidth
    }
}
