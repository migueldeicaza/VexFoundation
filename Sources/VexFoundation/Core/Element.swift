// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

public enum ElementError: Error, LocalizedError, Equatable, Sendable {
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .notImplemented(let typeName):
            return "\(typeName) must override draw()."
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
/// Provides style management, text font handling, child element hierarchy,
/// and rendering context binding. Subclass this for every drawable music
/// notation element.
open class VexElement {
    /// Category string identifying the element type.
    open class var category: String { "Element" }

    /// Default text font. Subclasses may override.
    open class var textFont: FontInfo {
        FontInfo(
            family: VexFont.SANS_SERIF,
            size: "\(VexFont.SIZE)pt",
            weight: VexFontWeight.normal.rawValue,
            style: VexFontStyle.normal.rawValue
        )
    }

    // MARK: - Properties

    private var context: RenderContext?
    public private(set) var rendered: Bool = false
    public var style: ElementStyle?
    private var attrs: ElementAttributes
    private weak var registry: Registry?
    public var boundingBox: BoundingBox?
    public var textFont: FontInfo?
    public var children: [VexElement] = []

    // MARK: - Init

    public init() {
        let runtime = VexRuntime.getCurrentContext()
        self.attrs = ElementAttributes(
            id: runtime.generateElementID(),
            type: type(of: self).category
        )

        // Match VexFlow behavior: newly created elements register automatically
        // when a default registry has been enabled.
        runtime.getDefaultRegistry()?.register(self)
    }

    public init(runtimeContext: VexRuntimeContext) {
        let runtime = runtimeContext
        self.attrs = ElementAttributes(
            id: runtime.generateElementID(),
            type: type(of: self).category
        )

        // Match VexFlow behavior: newly created elements register automatically
        // when a default registry has been enabled.
        runtime.getDefaultRegistry()?.register(self)
    }

    // MARK: - Children

    /// Add a child element that inherits style via setGroupStyle().
    @discardableResult
    public func addChildElement(_ child: VexElement) -> Self {
        children.append(child)
        return self
    }

    // MARK: - Category

    public func getCategory() -> String {
        type(of: self).category
    }

    // MARK: - Style

    @discardableResult
    public func setStyle(_ style: ElementStyle?) -> Self {
        self.style = style
        return self
    }

    @discardableResult
    public func setGroupStyle(_ style: ElementStyle) -> Self {
        self.style = style
        children.forEach { $0.setGroupStyle(style) }
        return self
    }

    public func getStyle() -> ElementStyle? {
        style
    }

    /// Apply the element's style to the context, saving state first.
    @discardableResult
    public func applyStyle(
        context ctx: RenderContext? = nil,
        style: ElementStyle? = nil
    ) -> Self {
        let ctx = ctx ?? self.context
        let style = style ?? self.style
        guard let style, let ctx else { return self }
        ctx.save()
        if let sc = style.shadowColor { ctx.setShadowColor(sc) }
        if let sb = style.shadowBlur { ctx.setShadowBlur(sb) }
        if let fs = style.fillStyle { ctx.setFillStyle(fs) }
        if let ss = style.strokeStyle { ctx.setStrokeStyle(ss) }
        if let lw = style.lineWidth { ctx.setLineWidth(lw) }
        return self
    }

    /// Restore context state after applyStyle().
    @discardableResult
    public func restoreStyle(
        context ctx: RenderContext? = nil,
        style: ElementStyle? = nil
    ) -> Self {
        let ctx = ctx ?? self.context
        let style = style ?? self.style
        guard style != nil, let ctx else { return self }
        ctx.restore()
        return self
    }

    /// Draw with the element's style applied.
    public func drawWithStyle() throws {
        _ = try checkContext()
        applyStyle()
        try draw()
        restoreStyle()
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
        _ = registry?.onUpdate(RegistryUpdate(
            id: attrs.id,
            name: "class",
            value: className,
            oldValue: nil
        ))
        return self
    }

    @discardableResult
    public func removeClass(_ className: String) -> Self {
        guard hasClass(className) else { return self }
        var parts = attrs.class.split(separator: " ").map(String.init)
        parts.removeAll { $0 == className }
        attrs.class = parts.joined(separator: " ")
        _ = registry?.onUpdate(RegistryUpdate(
            id: attrs.id,
            name: "class",
            value: nil,
            oldValue: className
        ))
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
            _ = registry?.onUpdate(RegistryUpdate(
                id: oldID,
                name: name,
                value: value,
                oldValue: oldValue
            ))
        }
        return self
    }

    // MARK: - Registry

    /// Called when this element is registered with a Registry.
    open func onRegister(_ registry: Registry) {
        self.registry = registry
    }

    // MARK: - Context

    public func getContext() -> RenderContext? { context }

    @discardableResult
    public func setContext(_ context: RenderContext?) -> Self {
        self.context = context
        return self
    }

    public func checkContext() throws -> RenderContext {
        try defined(context, "NoContext", "No rendering context attached to instance.")
    }

    // MARK: - Font Handling

    @discardableResult
    public func setFont(
        _ font: FontInfo? = nil,
        size: Double? = nil,
        weight: String? = nil,
        style: String? = nil
    ) -> Self {
        let defaults = type(of: self).textFont
        if let font {
            textFont = FontInfo(
                family: font.family.isEmpty ? defaults.family : font.family,
                size: font.size.isEmpty ? defaults.size : font.size,
                weight: font.weight.isEmpty ? defaults.weight : font.weight,
                style: font.style.isEmpty ? defaults.style : font.style
            )
        } else {
            textFont = VexFont.validate(
                family: defaults.family,
                size: size != nil ? "\(size!)pt" : defaults.size,
                weight: weight ?? defaults.weight,
                style: style ?? defaults.style
            )
        }
        return self
    }

    public func getFont() -> String {
        if textFont == nil { resetFont() }
        return VexFont.toCSSString(textFont)
    }

    public func resetFont() {
        setFont()
    }

    public var fontInfo: FontInfo {
        get {
            if textFont == nil { resetFont() }
            return textFont!
        }
        set { setFont(newValue) }
    }

    public var fontSizeInPoints: Double {
        VexFont.convertSizeToPointValue(fontInfo.size)
    }

    public var fontSizeInPixels: Double {
        VexFont.convertSizeToPixelValue(fontInfo.size)
    }
}
