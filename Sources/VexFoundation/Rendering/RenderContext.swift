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

    /// Add an invisible rectangle that receives pointer events (SVG). No-op for raster back ends.
    @discardableResult func pointerRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self

    // MARK: - Rotation

    /// Start a rotation of `angleDegrees` around (`x`, `y`) for the next drawing operations.
    func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double)

    /// End the rotation started with `openRotation`.
    func closeRotation()

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
        guard !trimmed.isEmpty else { return setFont(VexFont.validate()) }
        return setFont(VexFont.fromCSSString(trimmed))
    }

    /// Apply an ElementStyle to this context, saving state first.
    @available(*, deprecated, message: "Use ctx.save(); element.applyStyle(context: ctx); ...; ctx.restore().")
    @discardableResult
    public func applyStyle(_ style: ElementStyle?) -> Self {
        guard let style else { return self }
        save()
        VexElement.apply(style, to: self)
        return self
    }

    /// Restore the context after applyStyle.
    @available(*, deprecated, message: "Use ctx.save() / ctx.restore().")
    @discardableResult
    public func restoreStyle(_ style: ElementStyle?) -> Self {
        guard style != nil else { return self }
        return restore()
    }

    /// Default: no pointer rectangle.
    @discardableResult
    public func pointerRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self { self }

    /// Default: rotation is not supported.
    public func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double) {}

    /// Default: rotation is not supported.
    public func closeRotation() {}
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
