// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
// @author Mohit Cheppudira
//
// Port of `src/element.ts` (VexFlow 5).

import Foundation

public enum ElementError: Error, LocalizedError, Equatable, Sendable {
    case notImplemented(String)
    case parentAlreadyDefined

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let typeName):
            return "\(typeName) must override draw()."
        case .parentAlreadyDefined:
            return "Parent already defined."
        }
    }
}

/// Element attributes (id, type, class).
public struct ElementAttributes {
    public var id: String
    public var type: String
    public var `class`: String

    public init(id: String, type: String, `class`: String = "") {
        self.id = id
        self.type = type
        self.class = `class`
    }
}

/// Base class for all VexFlow drawable objects.
///
/// The element handles style and font properties for itself and its child
/// elements, and works with the `Registry` to create unique ids.
///
/// The `text` is a series of Unicode characters (SMuFL codes included).
/// `fontInfo` holds the information to style the text (family list, size,
/// weight, style). `measureText()` calculates `textMetrics`, `width` and
/// `height`. `renderText(_:x:y:)` draws the text, with `xShift` and `yShift`.
open class VexElement {
    /// Category string identifying the element type.
    open class var category: String { "Element" }

    // MARK: - Properties

    private var context: RenderContext?
    public private(set) var rendered: Bool = false
    public var style: ElementStyle?
    private var attrs: ElementAttributes
    private weak var registry: Registry?

    /// Parent element (set by `addChild`).
    public internal(set) weak var parent: VexElement?
    /// Child elements. Children inherit the style from their parent (`setGroupStyle`).
    public var children: [VexElement] = []

    var _fontInfo: FontInfo
    public internal(set) var fontScale: Double
    var _text: String = ""
    var metricsValid = false
    var _textMetrics = TextMetrics()
    var _height: Double = 0
    var _width: Double = 0

    /// Horizontal shift in pixels (positive is right).
    public var xShift: Double = 0
    /// Vertical shift in pixels (positive is down).
    public var yShift: Double = 0
    /// X coordinate.
    public var x: Double = 0
    /// Y coordinate.
    public var y: Double = 0

    // MARK: - Init

    public convenience init() {
        self.init(category: nil, runtimeContext: VexRuntime.getCurrentContext())
    }

    public convenience init(runtimeContext: VexRuntimeContext) {
        self.init(category: nil, runtimeContext: runtimeContext)
    }

    /// Create an element. `category` overrides the class category for metrics lookup.
    public init(category: String?, runtimeContext: VexRuntimeContext = VexRuntime.getCurrentContext()) {
        let type = category ?? Swift.type(of: self).category
        self.attrs = ElementAttributes(id: runtimeContext.generateElementID(), type: type)
        self._fontInfo = runtimeContext.metrics.getFontInfo(type)
        let style = runtimeContext.metrics.getStyle(type)
        self.style = style.isEmpty ? nil : style
        self.fontScale = Metrics.number(runtimeContext.metrics.get("\(type).fontScale")) ?? 1

        // Newly created elements register automatically when a default registry is enabled.
        runtimeContext.getDefaultRegistry()?.register(self)
    }

    // MARK: - Children

    /// Add a child that inherits the style of this element with `setGroupStyle()`.
    /// Examples of children are noteheads and stems.
    @discardableResult
    public func addChild(_ child: VexElement) -> Self {
        child.parent = self
        children.append(child)
        return self
    }

    /// Source-compatibility alias for `addChild(_:)`.
    @available(*, deprecated, renamed: "addChild(_:)")
    @discardableResult
    public func addChildElement(_ child: VexElement) -> Self {
        addChild(child)
    }

    // MARK: - Category

    public func getCategory() -> String {
        attrs.type
    }

    // MARK: - Style

    @discardableResult
    open func setStyle(_ style: ElementStyle?) -> Self {
        self.style = style
        return self
    }

    /// Set the style of this element and its children.
    @discardableResult
    open func setGroupStyle(_ style: ElementStyle) -> Self {
        self.style = style
        children.forEach { $0.setGroupStyle(style) }
        return self
    }

    public func getStyle() -> ElementStyle? {
        style
    }

    /// Apply the element style to `context` (default: the element context).
    /// This does not save the context state; callers pair it with
    /// `ctx.save()` / `ctx.restore()` as needed (VexFlow 5 semantics).
    @discardableResult
    public func applyStyle(
        context ctx: RenderContext? = nil,
        style: ElementStyle? = nil
    ) -> Self {
        let ctx = ctx ?? self.context
        let style = style ?? self.style
        guard let style, let ctx else { return self }
        Self.apply(style, to: ctx)
        return self
    }

    /// Write `style` into `ctx` without saving state.
    static func apply(_ style: ElementStyle, to ctx: RenderContext) {
        if let sc = style.shadowColor, !sc.isEmpty { ctx.setShadowColor(sc) }
        if let sb = style.shadowBlur, sb != 0 { ctx.setShadowBlur(sb) }
        if let fs = style.fillStyle, !fs.isEmpty { ctx.setFillStyle(fs) }
        if let ss = style.strokeStyle, !ss.isEmpty { ctx.setStrokeStyle(ss) }
        if let lw = style.lineWidth, lw != 0 { ctx.setLineWidth(lw) }
        if let ld = style.lineDash, !ld.isEmpty {
            ctx.setLineDash(ld.split(separator: " ").compactMap { Double($0) })
        }
    }

    /// Draw the element and its sub-elements with the element style.
    public func drawWithStyle() throws {
        let ctx = try checkContext()
        ctx.save()
        defer { ctx.restore() }
        if let style { Self.apply(style, to: ctx) }
        try draw()
    }

    /// Override in subclasses to perform drawing.
    open func draw() throws {
        throw ElementError.notImplemented(String(describing: type(of: self)))
    }

    // MARK: - Class Labels

    public func hasClass(_ className: String) -> Bool {
        attrs.class.split(separator: " ").contains(Substring(className))
    }

    @discardableResult
    public func addClass(_ className: String) -> Self {
        guard !hasClass(className) else { return self }
        if attrs.class.isEmpty {
            attrs.class = className
        } else {
            attrs.class += " \(className)"
        }
        _ = registry?.onUpdate(RegistryUpdate(id: attrs.id, name: "class", value: className, oldValue: nil))
        return self
    }

    @discardableResult
    public func removeClass(_ className: String) -> Self {
        guard hasClass(className) else { return self }
        var parts = attrs.class.split(separator: " ").map(String.init)
        parts.removeAll { $0 == className }
        attrs.class = parts.joined(separator: " ")
        _ = registry?.onUpdate(RegistryUpdate(id: attrs.id, name: "class", value: nil, oldValue: className))
        return self
    }

    // MARK: - Rendered Status

    public func isRendered() -> Bool { rendered }

    @discardableResult
    public func setRendered(_ rendered: Bool = true) -> Self {
        self.rendered = rendered
        return self
    }

    // MARK: - Attributes

    public func getAttributes() -> ElementAttributes { attrs }

    public func getAttribute(_ name: String) -> String? {
        switch name {
        case "id": return attrs.id
        case "type": return attrs.type
        case "class": return attrs.class
        default: return nil
        }
    }

    @discardableResult
    public func setAttribute(_ name: String, _ value: String?) -> Self {
        let oldID = attrs.id
        var oldValue: String?
        switch name {
        case "id":
            oldValue = attrs.id
            attrs.id = value ?? ""
        case "type":
            oldValue = attrs.type
            attrs.type = value ?? ""
        case "class":
            oldValue = attrs.class
            attrs.class = value ?? ""
        default: break
        }
        if name == "id" || name == "type" || name == "class" {
            _ = registry?.onUpdate(RegistryUpdate(id: oldID, name: name, value: value, oldValue: oldValue))
        }
        return self
    }

    // MARK: - Registry

    /// Called when this element is registered with a Registry.
    open func onRegister(_ registry: Registry) {
        self.registry = registry
    }

    // MARK: - Bounding box

    /// The bounding box of the element text.
    open func getBoundingBox() -> BoundingBox? {
        BoundingBox(
            x: x + xShift,
            y: y + yShift - textMetrics.actualBoundingBoxAscent,
            w: width,
            h: height
        )
    }

    // MARK: - Context

    public func getContext() -> RenderContext? { context }

    @discardableResult
    open func setContext(_ context: RenderContext?) -> Self {
        self.context = context
        return self
    }

    public func checkContext() throws -> RenderContext {
        try defined(context, "NoContext", "No rendering context attached to instance.")
    }

    // MARK: - Font Handling

    /// Set the element font.
    ///
    /// - `font` given: missing fields take the category defaults.
    /// - Otherwise: the family is the category default and `size`, `weight`
    ///   and `style` replace the defaults when given. With no arguments, the
    ///   font is reset to the category default.
    @discardableResult
    open func setFont(
        _ font: FontInfo? = nil,
        size: Double? = nil,
        weight: String? = nil,
        style: String? = nil
    ) -> Self {
        let defaults = Metrics.getFontInfo(attrs.type)
        metricsValid = false
        if let font {
            _fontInfo = FontInfo(
                family: font.family.isEmpty ? defaults.family : font.family,
                size: font.size.isEmpty ? defaults.size : font.size,
                weight: font.weight.isEmpty ? defaults.weight : font.weight,
                style: font.style.isEmpty ? defaults.style : font.style
            )
        } else {
            _fontInfo = VexFont.validate(
                family: defaults.family,
                size: size.map { "\(formatJSNumber($0))pt" } ?? defaults.size,
                weight: weight ?? defaults.weight,
                style: style ?? defaults.style
            )
        }
        return self
    }

    /// Set the font from a family and CSS size string.
    @discardableResult
    public func setFont(family: String?, size: String?, weight: String? = nil, style: String? = nil) -> Self {
        let defaults = Metrics.getFontInfo(attrs.type)
        metricsValid = false
        _fontInfo = VexFont.validate(
            family: family ?? defaults.family,
            size: size ?? defaults.size,
            weight: weight ?? defaults.weight,
            style: style ?? defaults.style
        )
        return self
    }

    /// Set the font from CSS shorthand (e.g. `"bold 10pt Arial"`).
    @discardableResult
    public func setFont(css: String) -> Self {
        metricsValid = false
        _fontInfo = VexFont.fromCSSString(css)
        return self
    }

    /// The CSS string of the font, e.g. `"bold 10pt Arial"`.
    public func getFont() -> String {
        VexFont.toCSSString(_fontInfo)
    }

    /// Reset the font to the category default.
    public func resetFont() {
        setFont()
    }

    /// The current font.
    public var fontInfo: FontInfo {
        get { _fontInfo }
        set { setFont(newValue) }
    }

    /// Source-compatibility alias for `fontInfo`.
    public var textFont: FontInfo? {
        get { _fontInfo }
        set { if let newValue { setFont(newValue) } else { resetFont() } }
    }

    /// Change the font size and keep the other font fields.
    @discardableResult
    public func setFontSize(_ size: String) -> Self {
        let f = _fontInfo
        return setFont(family: f.family, size: size, weight: f.weight, style: f.style)
    }

    /// Change the font size (in points) and keep the other font fields.
    @discardableResult
    public func setFontSize(_ size: Double) -> Self {
        setFontSize("\(formatJSNumber(size))pt")
    }

    /// The CSS font size (e.g. "18pt").
    public func getFontSize() -> String { _fontInfo.size }

    public func getFontScale() -> Double { fontScale }

    public var fontSizeInPoints: Double { VexFont.convertSizeToPointValue(_fontInfo.size) }
    public var fontSizeInPixels: Double { VexFont.convertSizeToPixelValue(_fontInfo.size) }

    public var fontStyle: String {
        get { _fontInfo.style }
        set { setFont(family: _fontInfo.family, size: _fontInfo.size, weight: _fontInfo.weight, style: newValue) }
    }

    public var fontWeight: String {
        get { _fontInfo.weight }
        set { setFont(family: _fontInfo.family, size: _fontInfo.size, weight: newValue, style: _fontInfo.style) }
    }

    // MARK: - Geometry

    /// Element width. Measures the text when the metrics are not valid.
    public var width: Double {
        get {
            if !metricsValid { _ = measureText() }
            return _width
        }
        set {
            if !metricsValid { _ = measureText() }
            _width = newValue
        }
    }

    /// Element height (text ascent + descent). Measures the text when needed.
    public var height: Double {
        get {
            if !metricsValid { _ = measureText() }
            return _height
        }
        set {
            if !metricsValid { _ = measureText() }
            _height = newValue
        }
    }

    open func getWidth() -> Double { width }

    @discardableResult
    open func setWidth(_ width: Double) -> Self {
        self.width = width
        return self
    }

    public func getHeight() -> Double { height }

    @discardableResult
    open func setX(_ x: Double) -> Self {
        self.x = x
        return self
    }

    open func getX() -> Double { x }

    open func getY() -> Double { y }

    @discardableResult
    open func setY(_ y: Double) -> Self {
        self.y = y
        return self
    }

    /// Shift element down `yShift` pixels. Negative values shift up.
    @discardableResult
    open func setYShift(_ yShift: Double) -> Self {
        self.yShift = yShift
        return self
    }

    open func getYShift() -> Double { yShift }

    /// Shift element right `xShift` pixels. Negative values shift left.
    @discardableResult
    open func setXShift(_ xShift: Double) -> Self {
        self.xShift = xShift
        return self
    }

    open func getXShift() -> Double { xShift }

    // MARK: - Text

    /// Element text (Unicode, SMuFL code points included).
    public var text: String {
        get { _text }
        set {
            metricsValid = false
            _text = newValue
        }
    }

    @discardableResult
    open func setText(_ text: String) -> Self {
        self.text = text
        return self
    }

    open func getText() -> String { _text }

    /// Render the element text and the text of its children.
    open func renderText(_ ctx: RenderContext, xPos: Double, yPos: Double) {
        ctx.setFont(_fontInfo)
        ctx.fillText(_text, xPos + x + xShift, yPos + y + yShift)
        for child in children {
            ctx.setFont(child.fontInfo)
            ctx.fillText(child.text, xPos + child.x + child.xShift, yPos + child.y + child.yShift)
        }
    }

    /// Measure the text with the element font.
    @discardableResult
    open func measureText() -> TextMetrics {
        _textMetrics = TextMeasurer.measure(_text, fontInfo: VexFont.validate(fontInfo: _fontInfo))
        _height = _textMetrics.actualBoundingBoxAscent + _textMetrics.actualBoundingBoxDescent
        _width = _textMetrics.width
        metricsValid = true
        return _textMetrics
    }

    /// Measure `text` with the font of metrics category `key`.
    public static func measureWidth(_ text: String, key: String = "") -> Double {
        TextMeasurer.measure(text, fontInfo: Metrics.getFontInfo(key)).width
    }

    /// The text metrics. Measures the text when needed.
    public var textMetrics: TextMetrics {
        if !metricsValid { _ = measureText() }
        return _textMetrics
    }

    public func getTextMetrics() -> TextMetrics { textMetrics }

    /// Invalidate the cached text metrics.
    public func invalidateMetrics() { metricsValid = false }

    // MARK: - Origin

    public func setOriginX(_ x: Double) {
        guard let bbox = getBoundingBox(), bbox.w != 0 else { return }
        let originX = abs((bbox.x - xShift) / bbox.w)
        let shift = (x - originX) * bbox.w
        xShift = -shift
    }

    public func setOriginY(_ y: Double) {
        guard let bbox = getBoundingBox(), bbox.h != 0 else { return }
        let originY = abs((bbox.y - yShift) / bbox.h)
        let shift = (y - originY) * bbox.h
        yShift = -shift
    }

    public func setOrigin(_ x: Double, _ y: Double) {
        setOriginX(x)
        setOriginY(y)
    }
}

extension ElementStyle {
    /// True if no field is set.
    public var isEmpty: Bool {
        shadowColor == nil && shadowBlur == nil && fillStyle == nil
            && strokeStyle == nil && lineWidth == nil && lineDash == nil
    }
}
