// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

/// Line cap style, matching the HTML Canvas CanvasLineCap type.
public enum VexLineCap: String, Sendable {
    case butt = "butt"
    case round = "round"
    case square = "square"
}

/// Abstract rendering context protocol. All VexFlow drawing flows through this interface.
///
/// This is the single abstraction layer between the music notation engine and the
/// rendering backend. Implement this protocol to render VexFlow output to any target
/// (SwiftUI Canvas, CoreGraphics, PDF, etc.).
///
/// Methods return `Self` to support method chaining.
public protocol RenderContext: AnyObject {

    // MARK: - Canvas State

    /// Clear the entire rendering surface.
    func clear()

    /// Save the current graphics state (colors, line width, font, etc.) onto a stack.
    @discardableResult func save() -> Self

    /// Restore the most recently saved graphics state.
    @discardableResult func restore() -> Self

    // MARK: - Style Setters

    /// Set the fill color using a CSS color string.
    @discardableResult func setFillStyle(_ style: String) -> Self

    /// Set the background fill style. May be ignored by some backends.
    @discardableResult func setBackgroundFillStyle(_ style: String) -> Self

    /// Set the stroke color using a CSS color string.
    @discardableResult func setStrokeStyle(_ style: String) -> Self

    /// Set the shadow color.
    @discardableResult func setShadowColor(_ color: String) -> Self

    /// Set the shadow blur radius.
    @discardableResult func setShadowBlur(_ blur: Double) -> Self

    /// Set the line width for stroke operations.
    @discardableResult func setLineWidth(_ width: Double) -> Self

    /// Set the line cap style.
    @discardableResult func setLineCap(_ capType: VexLineCap) -> Self

    /// Set the dash pattern for stroked lines.
    @discardableResult func setLineDash(_ dashPattern: [Double]) -> Self

    // MARK: - Style Properties

    var fillStyle: String { get set }
    var strokeStyle: String { get set }

    // MARK: - Transform

    /// Scale the coordinate system.
    @discardableResult func scale(_ x: Double, _ y: Double) -> Self

    /// Resize the rendering surface.
    @discardableResult func resize(_ width: Double, _ height: Double) -> Self

    // MARK: - Path Operations

    /// Begin a new path, discarding any existing path.
    @discardableResult func beginPath() -> Self

    /// Move the current point to (x, y) without drawing.
    @discardableResult func moveTo(_ x: Double, _ y: Double) -> Self

    /// Draw a line from the current point to (x, y).
    @discardableResult func lineTo(_ x: Double, _ y: Double) -> Self

    /// Draw a cubic Bezier curve from the current point to (x, y) using two control points.
    @discardableResult func bezierCurveTo(
        _ cp1x: Double, _ cp1y: Double,
        _ cp2x: Double, _ cp2y: Double,
        _ x: Double, _ y: Double
    ) -> Self

    /// Draw a quadratic Bezier curve from the current point to (x, y) using one control point.
    @discardableResult func quadraticCurveTo(
        _ cpx: Double, _ cpy: Double,
        _ x: Double, _ y: Double
    ) -> Self

    /// Draw an arc.
    @discardableResult func arc(
        _ x: Double, _ y: Double,
        _ radius: Double,
        _ startAngle: Double, _ endAngle: Double,
        _ counterclockwise: Bool
    ) -> Self

    /// Close the current path by drawing a line back to the start.
    @discardableResult func closePath() -> Self

    /// Fill the current path.
    @discardableResult func fill() -> Self

    /// Stroke the current path.
    @discardableResult func stroke() -> Self

    // MARK: - Rectangles

    /// Add a rectangle to the current path.
    @discardableResult func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self

    /// Fill a rectangle (immediate, does not affect the current path).
    @discardableResult func fillRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self

    /// Clear a rectangle to transparent.
    @discardableResult func clearRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self

    // MARK: - Text

    /// Draw filled text at the given position (baseline origin).
    @discardableResult func fillText(_ text: String, _ x: Double, _ y: Double) -> Self

    /// Measure the given text using the current font and return its bounding box.
    func measureText(_ text: String) -> TextMeasure

    /// Set the text font using individual parameters.
    @discardableResult func setFont(
        _ family: String?,
        _ size: Double?,
        _ weight: String?,
        _ style: String?
    ) -> Self

    /// Set the text font from a FontInfo struct.
    @discardableResult func setFont(_ fontInfo: FontInfo) -> Self

    /// Get the current font as a CSS font shorthand string.
    func getFont() -> String

    // MARK: - Grouping (SVG-specific, no-op for canvas backends)

    /// Open a logical group. Returns an opaque group identifier (or nil).
    func openGroup(_ cls: String?, _ id: String?) -> Any?

    /// Close the current logical group.
    func closeGroup()

    /// Add a child element to the current group.
    func add(_ child: Any)
}

// MARK: - Convenience Extensions

extension RenderContext {
    /// Set the font from a CSS shorthand string (e.g., "bold 10pt Arial").
    @discardableResult
    public func setFont(_ cssString: String) -> Self {
        let trimmed = cssString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return setFont(VexFont.validate())
        }

        let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard
            let sizeIndex = tokens.firstIndex(where: {
                $0.range(of: #"^[0-9]*\.?[0-9]+(pt|px|em|%|in|mm|cm)$"#, options: .regularExpression) != nil
            })
        else {
            let info = VexFont.validate(family: trimmed)
            return setFont(info)
        }

        var style: String?
        var weight: String?
        if sizeIndex > 0 {
            for token in tokens[0..<sizeIndex] {
                let lower = token.lowercased()
                if ["italic", "oblique"].contains(lower) {
                    style = token
                    continue
                }
                if lower == "normal" {
                    if style == nil {
                        style = token
                    } else if weight == nil {
                        weight = token
                    }
                    continue
                }
                if lower == "bold" || Int(lower) != nil {
                    weight = token
                }
            }
        }

        let size = tokens[sizeIndex]
        let family = sizeIndex + 1 < tokens.count
            ? tokens[(sizeIndex + 1)...].joined(separator: " ")
            : trimmed

        let info = VexFont.validate(
            family: family,
            size: size,
            weight: weight,
            style: style
        )
        return setFont(info)
    }

    /// Apply an ElementStyle to this context, saving state first.
    @discardableResult
    public func applyStyle(_ style: ElementStyle?) -> Self {
        guard let style else { return self }
        save()
        if let sc = style.shadowColor { setShadowColor(sc) }
        if let sb = style.shadowBlur { setShadowBlur(sb) }
        if let fs = style.fillStyle { setFillStyle(fs) }
        if let ss = style.strokeStyle { setStrokeStyle(ss) }
        if let lw = style.lineWidth { setLineWidth(lw) }
        return self
    }

    /// Restore the context after applyStyle.
    @discardableResult
    public func restoreStyle(_ style: ElementStyle?) -> Self {
        guard style != nil else { return self }
        return restore()
    }
}

// MARK: - Debug Helper

/// Draw a tiny dot marker on the specified context. A great debugging aid.
public func drawDot(_ ctx: RenderContext, x: Double, y: Double, color: String = "#F55") {
    ctx.save()
    ctx.setFillStyle(color)
    ctx.beginPath()
    ctx.arc(x, y, 3, 0, .pi * 2, false)
    ctx.closePath()
    ctx.fill()
    ctx.restore()
}
