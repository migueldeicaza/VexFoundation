// VexFoundation - SwiftUI Canvas rendering backend for VexFlow.

import CoreText
import Foundation
import SwiftUI

/// Graphics state snapshot for save/restore.
private struct GraphicsState {
    var fillColor: Color
    var strokeColor: Color
    var fillStyleCSS: String
    var strokeStyleCSS: String
    var lineWidth: Double
    var lineCap: CGLineCap
    var lineDash: [CGFloat]
    var shadowColor: Color
    var shadowBlur: Double
    var fontInfo: FontInfo
    var scaleX: Double
    var scaleY: Double
}

/// A RenderContext implementation that draws into a SwiftUI Canvas GraphicsContext.
///
/// Usage:
/// ```swift
/// Canvas { gc, size in
///     let ctx = SwiftUICanvasContext(graphicsContext: gc, size: size)
///     // Pass ctx to VexFlow draw() calls
/// }
/// ```
public final class SwiftUICanvasContext: RenderContext {

    // MARK: - Backing Store

    private var gc: GraphicsContext
    private var canvasSize: CGSize

    // Current drawing state
    private var currentFillColor: Color = .black
    private var currentStrokeColor: Color = .black
    private var currentFillStyleCSS: String = "#000"
    private var currentStrokeStyleCSS: String = "#000"
    private var currentLineWidth: Double = 1.0
    private var currentLineCap: CGLineCap = .butt
    private var currentLineDash: [CGFloat] = []
    private var currentShadowColor: Color = .clear
    private var currentShadowBlur: Double = 0
    private var currentFontInfo: FontInfo = FontInfo()
    private var currentScaleX: Double = 1.0
    private var currentScaleY: Double = 1.0

    // Path accumulator (immediate-mode drawing like HTML Canvas)
    private var currentPath = Path()

    // State stack for save/restore
    private var stateStack: [GraphicsState] = []

    // MARK: - Init

    public init(graphicsContext: GraphicsContext, size: CGSize) {
        self.gc = graphicsContext
        self.canvasSize = size
    }

    // MARK: - Canvas State

    public func clear() {
        gc.fill(
            Path(CGRect(origin: .zero, size: canvasSize)),
            with: .color(.white)
        )
    }

    @discardableResult
    public func save() -> Self {
        stateStack.append(GraphicsState(
            fillColor: currentFillColor,
            strokeColor: currentStrokeColor,
            fillStyleCSS: currentFillStyleCSS,
            strokeStyleCSS: currentStrokeStyleCSS,
            lineWidth: currentLineWidth,
            lineCap: currentLineCap,
            lineDash: currentLineDash,
            shadowColor: currentShadowColor,
            shadowBlur: currentShadowBlur,
            fontInfo: currentFontInfo,
            scaleX: currentScaleX,
            scaleY: currentScaleY
        ))
        return self
    }

    @discardableResult
    public func restore() -> Self {
        guard let state = stateStack.popLast() else { return self }
        currentFillColor = state.fillColor
        currentStrokeColor = state.strokeColor
        currentFillStyleCSS = state.fillStyleCSS
        currentStrokeStyleCSS = state.strokeStyleCSS
        currentLineWidth = state.lineWidth
        currentLineCap = state.lineCap
        currentLineDash = state.lineDash
        currentShadowColor = state.shadowColor
        currentShadowBlur = state.shadowBlur
        currentFontInfo = state.fontInfo
        currentScaleX = state.scaleX
        currentScaleY = state.scaleY
        return self
    }

    // MARK: - Style Setters

    @discardableResult
    public func setFillStyle(_ style: String) -> Self {
        currentFillStyleCSS = style
        currentFillColor = CSSColor.parse(style)
        return self
    }

    @discardableResult
    public func setBackgroundFillStyle(_ style: String) -> Self {
        // No-op for canvas-like backend (same as VexFlow's CanvasContext)
        return self
    }

    @discardableResult
    public func setStrokeStyle(_ style: String) -> Self {
        currentStrokeStyleCSS = style
        currentStrokeColor = CSSColor.parse(style)
        return self
    }

    @discardableResult
    public func setShadowColor(_ color: String) -> Self {
        currentShadowColor = CSSColor.parse(color)
        return self
    }

    @discardableResult
    public func setShadowBlur(_ blur: Double) -> Self {
        currentShadowBlur = blur
        return self
    }

    @discardableResult
    public func setLineWidth(_ width: Double) -> Self {
        currentLineWidth = width
        return self
    }

    @discardableResult
    public func setLineCap(_ capType: VexLineCap) -> Self {
        switch capType {
        case .butt: currentLineCap = .butt
        case .round: currentLineCap = .round
        case .square: currentLineCap = .square
        }
        return self
    }

    @discardableResult
    public func setLineDash(_ dashPattern: [Double]) -> Self {
        currentLineDash = dashPattern.map { CGFloat($0) }
        return self
    }

    // MARK: - Style Properties

    public var fillStyle: String {
        get { currentFillStyleCSS }
        set { setFillStyle(newValue) }
    }

    public var strokeStyle: String {
        get { currentStrokeStyleCSS }
        set { setStrokeStyle(newValue) }
    }

    // MARK: - Transform

    @discardableResult
    public func scale(_ x: Double, _ y: Double) -> Self {
        currentScaleX *= x
        currentScaleY *= y
        return self
    }

    @discardableResult
    public func resize(_ width: Double, _ height: Double) -> Self {
        canvasSize = CGSize(width: width, height: height)
        return self
    }

    // MARK: - Path Operations

    @discardableResult
    public func beginPath() -> Self {
        currentPath = Path()
        return self
    }

    @discardableResult
    public func moveTo(_ x: Double, _ y: Double) -> Self {
        currentPath.move(to: scaled(x, y))
        return self
    }

    @discardableResult
    public func lineTo(_ x: Double, _ y: Double) -> Self {
        currentPath.addLine(to: scaled(x, y))
        return self
    }

    @discardableResult
    public func bezierCurveTo(
        _ cp1x: Double, _ cp1y: Double,
        _ cp2x: Double, _ cp2y: Double,
        _ x: Double, _ y: Double
    ) -> Self {
        currentPath.addCurve(
            to: scaled(x, y),
            control1: scaled(cp1x, cp1y),
            control2: scaled(cp2x, cp2y)
        )
        return self
    }

    @discardableResult
    public func quadraticCurveTo(
        _ cpx: Double, _ cpy: Double,
        _ x: Double, _ y: Double
    ) -> Self {
        currentPath.addQuadCurve(
            to: scaled(x, y),
            control: scaled(cpx, cpy)
        )
        return self
    }

    @discardableResult
    public func arc(
        _ x: Double, _ y: Double,
        _ radius: Double,
        _ startAngle: Double, _ endAngle: Double,
        _ counterclockwise: Bool
    ) -> Self {
        // SwiftUI Path.addArc uses clockwise in the default (flipped) coordinate system,
        // but VexFlow uses HTML Canvas conventions where y increases downward.
        // In that coordinate system, the sense of "clockwise" is flipped from math convention.
        // HTML Canvas: counterclockwise=false means clockwise in screen coords.
        // SwiftUI Path: clockwise=true means clockwise in the default (y-down) coordinate system.
        currentPath.addArc(
            center: scaled(x, y),
            radius: radius * currentScaleX,
            startAngle: .radians(startAngle),
            endAngle: .radians(endAngle),
            clockwise: counterclockwise
        )
        return self
    }

    @discardableResult
    public func closePath() -> Self {
        currentPath.closeSubpath()
        return self
    }

    @discardableResult
    public func fill() -> Self {
        applyShadowIfNeeded()
        gc.fill(currentPath, with: .color(currentFillColor))
        clearShadow()
        return self
    }

    @discardableResult
    public func stroke() -> Self {
        applyShadowIfNeeded()
        gc.stroke(
            currentPath,
            with: .color(currentStrokeColor),
            style: StrokeStyle(
                lineWidth: currentLineWidth * currentScaleX,
                lineCap: currentLineCap,
                dash: currentLineDash
            )
        )
        clearShadow()
        return self
    }

    // MARK: - Rectangles

    @discardableResult
    public func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        currentPath.addRect(scaledRect(x, y, width, height))
        return self
    }

    @discardableResult
    public func fillRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        gc.fill(Path(scaledRect(x, y, width, height)), with: .color(currentFillColor))
        return self
    }

    @discardableResult
    public func clearRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        // "Clear" by filling with white (SwiftUI Canvas doesn't have a clearRect equivalent)
        gc.fill(Path(scaledRect(x, y, width, height)), with: .color(.white))
        return self
    }

    // MARK: - Text

    @discardableResult
    public func fillText(_ text: String, _ x: Double, _ y: Double) -> Self {
        let resolved = gc.resolve(makeText(text))
        // SwiftUI draws text with the origin at the top-left of the text bounds.
        // VexFlow (like HTML Canvas) draws text at the baseline.
        // We offset by the ascent to align baselines.
        let ascent = resolvedAscent(text)
        gc.draw(resolved, at: scaled(x, y - ascent))
        return self
    }

    public func measureText(_ text: String) -> TextMeasure {
        let ctFont = makeCTFont()
        let attrString = NSAttributedString(
            string: text,
            attributes: [.font: ctFont]
        )
        let line = CTLineCreateWithAttributedString(attrString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let height = ascent + descent
        return TextMeasure(
            x: 0,
            y: -Double(ascent),
            width: Double(width),
            height: Double(height)
        )
    }

    @discardableResult
    public func setFont(
        _ family: String?,
        _ size: Double?,
        _ weight: String?,
        _ style: String?
    ) -> Self {
        currentFontInfo = VexFont.validate(
            family: family,
            size: size != nil ? "\(size!)pt" : nil,
            weight: weight,
            style: style
        )
        return self
    }

    @discardableResult
    public func setFont(_ fontInfo: FontInfo) -> Self {
        currentFontInfo = VexFont.validate(fontInfo: fontInfo)
        return self
    }

    public func getFont() -> String {
        VexFont.toCSSString(currentFontInfo)
    }

    // MARK: - Grouping (no-op)

    public func openGroup(_ cls: String?, _ id: String?) -> Any? { nil }
    public func closeGroup() {}
    public func add(_ child: Any) {}

    // MARK: - Private Helpers

    private func scaled(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * currentScaleX, y: y * currentScaleY)
    }

    private func scaledRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(
            x: x * currentScaleX,
            y: y * currentScaleY,
            width: w * currentScaleX,
            height: h * currentScaleY
        )
    }

    private func applyShadowIfNeeded() {
        guard currentShadowBlur > 0 else { return }
        gc.addFilter(.shadow(
            color: currentShadowColor,
            radius: currentShadowBlur * currentScaleX
        ))
    }

    private func clearShadow() {
        // Reset shadow by not applying it on next draw.
        // GraphicsContext filters are applied per-draw, so we don't need explicit cleanup.
    }

    private func makeText(_ text: String) -> Text {
        let sizeInPt = VexFont.convertSizeToPointValue(currentFontInfo.size)
        var swiftFont = Font.system(size: sizeInPt)

        let family = currentFontInfo.family
        if !family.isEmpty && !family.contains("sans-serif") && !family.contains("serif") {
            // Try to use the specific font family
            let primaryFamily = family.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? family
            swiftFont = Font.custom(primaryFamily, size: sizeInPt)
        }

        if VexFont.isBold(currentFontInfo.weight) {
            swiftFont = swiftFont.bold()
        }
        if VexFont.isItalic(currentFontInfo.style) {
            swiftFont = swiftFont.italic()
        }

        return Text(text)
            .font(swiftFont)
            .foregroundColor(currentFillColor)
    }

    private func makeCTFont() -> CTFont {
        let sizeInPt = VexFont.convertSizeToPointValue(currentFontInfo.size)
        var traits: CTFontSymbolicTraits = []
        if VexFont.isBold(currentFontInfo.weight) {
            traits.insert(.boldTrait)
        }
        if VexFont.isItalic(currentFontInfo.style) {
            traits.insert(.italicTrait)
        }

        let family = currentFontInfo.family
            .split(separator: ",").first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? "Arial"

        let baseFont = CTFontCreateWithName(family as CFString, sizeInPt, nil)
        if traits.isEmpty {
            return baseFont
        }
        if let modified = CTFontCreateCopyWithSymbolicTraits(baseFont, sizeInPt, nil, traits, traits) {
            return modified
        }
        return baseFont
    }

    private func resolvedAscent(_ text: String) -> Double {
        let ctFont = makeCTFont()
        return Double(CTFontGetAscent(ctFont))
    }
}
