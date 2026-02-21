// VexFoundation - Deterministic SVG rendering backend.

import Foundation

/// Options controlling SVG serialization.
public struct SVGRenderOptions: Sendable, Equatable {
    public var precision: Int
    public var includeXMLHeader: Bool
    public var includeViewBox: Bool

    public init(
        precision: Int = 3,
        includeXMLHeader: Bool = false,
        includeViewBox: Bool = true
    ) {
        self.precision = max(0, precision)
        self.includeXMLHeader = includeXMLHeader
        self.includeViewBox = includeViewBox
    }
}

private struct SVGGraphicsState {
    var fillStyle: String
    var strokeStyle: String
    var backgroundFillStyle: String
    var lineWidth: Double
    var lineCap: VexLineCap
    var lineDash: [Double]
    var shadowColor: String
    var shadowBlur: Double
    var fontInfo: FontInfo
    var scaleX: Double
    var scaleY: Double
}

private final class SVGGroupNode {
    let cls: String?
    let id: String?
    var children: [String] = []

    init(cls: String?, id: String?) {
        self.cls = cls
        self.id = id
    }
}

/// `RenderContext` backend that records drawing operations and serializes deterministic SVG.
public final class SVGRenderContext: RenderContext {
    private var canvasWidth: Double
    private var canvasHeight: Double
    private let options: SVGRenderOptions

    private var stateStack: [SVGGraphicsState] = []

    private var currentFillStyle: String = "#000000"
    private var currentStrokeStyle: String = "#000000"
    private var currentBackgroundFillStyle: String = "transparent"
    private var currentLineWidth: Double = 1
    private var currentLineCap: VexLineCap = .butt
    private var currentLineDash: [Double] = []
    private var currentShadowColor: String = "transparent"
    private var currentShadowBlur: Double = 0
    private var currentFontInfo: FontInfo = FontInfo()
    private var currentScaleX: Double = 1
    private var currentScaleY: Double = 1

    private var currentPathCommands: [String] = []
    private var currentPoint: (x: Double, y: Double)?
    private var currentSubpathStart: (x: Double, y: Double)?

    private var rootElements: [String] = []
    private var groupStack: [SVGGroupNode] = []

    public init(width: Double, height: Double, options: SVGRenderOptions = SVGRenderOptions()) {
        self.canvasWidth = max(1, width)
        self.canvasHeight = max(1, height)
        self.options = options
    }

    // MARK: - RenderContext: state

    public func clear() {
        rootElements.removeAll(keepingCapacity: true)
        groupStack.removeAll(keepingCapacity: true)
        currentPathCommands.removeAll(keepingCapacity: true)
        currentPoint = nil
        currentSubpathStart = nil
    }

    @discardableResult
    public func save() -> Self {
        stateStack.append(SVGGraphicsState(
            fillStyle: currentFillStyle,
            strokeStyle: currentStrokeStyle,
            backgroundFillStyle: currentBackgroundFillStyle,
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
        currentFillStyle = state.fillStyle
        currentStrokeStyle = state.strokeStyle
        currentBackgroundFillStyle = state.backgroundFillStyle
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

    // MARK: - RenderContext: styles

    @discardableResult
    public func setFillStyle(_ style: String) -> Self {
        currentFillStyle = style
        return self
    }

    @discardableResult
    public func setBackgroundFillStyle(_ style: String) -> Self {
        currentBackgroundFillStyle = style
        return self
    }

    @discardableResult
    public func setStrokeStyle(_ style: String) -> Self {
        currentStrokeStyle = style
        return self
    }

    @discardableResult
    public func setShadowColor(_ color: String) -> Self {
        currentShadowColor = color
        return self
    }

    @discardableResult
    public func setShadowBlur(_ blur: Double) -> Self {
        currentShadowBlur = blur
        return self
    }

    @discardableResult
    public func setLineWidth(_ width: Double) -> Self {
        currentLineWidth = max(0, width)
        return self
    }

    @discardableResult
    public func setLineCap(_ capType: VexLineCap) -> Self {
        currentLineCap = capType
        return self
    }

    @discardableResult
    public func setLineDash(_ dashPattern: [Double]) -> Self {
        currentLineDash = dashPattern
        return self
    }

    public var fillStyle: String {
        get { currentFillStyle }
        set { _ = setFillStyle(newValue) }
    }

    public var strokeStyle: String {
        get { currentStrokeStyle }
        set { _ = setStrokeStyle(newValue) }
    }

    // MARK: - RenderContext: transform

    @discardableResult
    public func scale(_ x: Double, _ y: Double) -> Self {
        currentScaleX *= x
        currentScaleY *= y
        return self
    }

    @discardableResult
    public func resize(_ width: Double, _ height: Double) -> Self {
        canvasWidth = max(1, width)
        canvasHeight = max(1, height)
        return self
    }

    // MARK: - RenderContext: paths

    @discardableResult
    public func beginPath() -> Self {
        currentPathCommands.removeAll(keepingCapacity: true)
        currentPoint = nil
        currentSubpathStart = nil
        return self
    }

    @discardableResult
    public func moveTo(_ x: Double, _ y: Double) -> Self {
        let p = scaled(x, y)
        currentPathCommands.append("M \(fmt(p.x)) \(fmt(p.y))")
        currentPoint = p
        currentSubpathStart = p
        return self
    }

    @discardableResult
    public func lineTo(_ x: Double, _ y: Double) -> Self {
        let p = scaled(x, y)
        if currentPoint == nil {
            currentPathCommands.append("M \(fmt(p.x)) \(fmt(p.y))")
            currentSubpathStart = p
        } else {
            currentPathCommands.append("L \(fmt(p.x)) \(fmt(p.y))")
        }
        currentPoint = p
        return self
    }

    @discardableResult
    public func bezierCurveTo(
        _ cp1x: Double, _ cp1y: Double,
        _ cp2x: Double, _ cp2y: Double,
        _ x: Double, _ y: Double
    ) -> Self {
        let cp1 = scaled(cp1x, cp1y)
        let cp2 = scaled(cp2x, cp2y)
        let p = scaled(x, y)
        if currentPoint == nil {
            currentPathCommands.append("M \(fmt(p.x)) \(fmt(p.y))")
            currentSubpathStart = p
        } else {
            currentPathCommands.append(
                "C \(fmt(cp1.x)) \(fmt(cp1.y)) \(fmt(cp2.x)) \(fmt(cp2.y)) \(fmt(p.x)) \(fmt(p.y))"
            )
        }
        currentPoint = p
        return self
    }

    @discardableResult
    public func quadraticCurveTo(
        _ cpx: Double, _ cpy: Double,
        _ x: Double, _ y: Double
    ) -> Self {
        let cp = scaled(cpx, cpy)
        let p = scaled(x, y)
        if currentPoint == nil {
            currentPathCommands.append("M \(fmt(p.x)) \(fmt(p.y))")
            currentSubpathStart = p
        } else {
            currentPathCommands.append("Q \(fmt(cp.x)) \(fmt(cp.y)) \(fmt(p.x)) \(fmt(p.y))")
        }
        currentPoint = p
        return self
    }

    @discardableResult
    public func arc(
        _ x: Double, _ y: Double,
        _ radius: Double,
        _ startAngle: Double, _ endAngle: Double,
        _ counterclockwise: Bool
    ) -> Self {
        let cx = x * currentScaleX
        let cy = y * currentScaleY
        let rx = abs(radius * currentScaleX)
        let ry = abs(radius * currentScaleY)
        guard rx > 0, ry > 0 else { return self }

        let delta = normalizedArcDelta(startAngle: startAngle, endAngle: endAngle, counterclockwise: counterclockwise)
        if abs(delta) < 1e-10 { return self }

        let startPoint = (
            x: cx + rx * cos(startAngle),
            y: cy + ry * sin(startAngle)
        )
        let endPoint = (
            x: cx + rx * cos(startAngle + delta),
            y: cy + ry * sin(startAngle + delta)
        )

        if let cp = currentPoint {
            if hypot(cp.x - startPoint.x, cp.y - startPoint.y) > 1e-7 {
                currentPathCommands.append("L \(fmt(startPoint.x)) \(fmt(startPoint.y))")
            }
        } else {
            currentPathCommands.append("M \(fmt(startPoint.x)) \(fmt(startPoint.y))")
            currentSubpathStart = startPoint
        }

        let sweepFlag = counterclockwise ? 0 : 1

        if abs(delta) >= (2 * .pi - 1e-9) {
            // Full-circle path as two half arcs.
            let midAngle = startAngle + delta / 2
            let midPoint = (
                x: cx + rx * cos(midAngle),
                y: cy + ry * sin(midAngle)
            )
            currentPathCommands.append(
                "A \(fmt(rx)) \(fmt(ry)) 0 0 \(sweepFlag) \(fmt(midPoint.x)) \(fmt(midPoint.y))"
            )
            currentPathCommands.append(
                "A \(fmt(rx)) \(fmt(ry)) 0 0 \(sweepFlag) \(fmt(endPoint.x)) \(fmt(endPoint.y))"
            )
        } else {
            let largeArcFlag = abs(delta) > .pi ? 1 : 0
            currentPathCommands.append(
                "A \(fmt(rx)) \(fmt(ry)) 0 \(largeArcFlag) \(sweepFlag) \(fmt(endPoint.x)) \(fmt(endPoint.y))"
            )
        }

        currentPoint = endPoint
        return self
    }

    @discardableResult
    public func closePath() -> Self {
        currentPathCommands.append("Z")
        currentPoint = currentSubpathStart
        return self
    }

    @discardableResult
    public func fill() -> Self {
        guard let d = currentPathData() else { return self }
        appendElement(pathElement(
            d: d,
            fill: currentFillStyle,
            stroke: nil,
            includeStrokeAttrs: false
        ))
        return self
    }

    @discardableResult
    public func stroke() -> Self {
        guard let d = currentPathData() else { return self }
        appendElement(pathElement(
            d: d,
            fill: "none",
            stroke: currentStrokeStyle,
            includeStrokeAttrs: true
        ))
        return self
    }

    // MARK: - RenderContext: rectangles

    @discardableResult
    public func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        let r = scaledRect(x, y, width, height)
        currentPathCommands.append("M \(fmt(r.x)) \(fmt(r.y))")
        currentPathCommands.append("L \(fmt(r.x + r.width)) \(fmt(r.y))")
        currentPathCommands.append("L \(fmt(r.x + r.width)) \(fmt(r.y + r.height))")
        currentPathCommands.append("L \(fmt(r.x)) \(fmt(r.y + r.height))")
        currentPathCommands.append("Z")
        currentPoint = (x: r.x, y: r.y)
        currentSubpathStart = (x: r.x, y: r.y)
        return self
    }

    @discardableResult
    public func fillRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        let r = scaledRect(x, y, width, height)
        appendElement(
            "<rect x=\"\(fmt(r.x))\" y=\"\(fmt(r.y))\" width=\"\(fmt(r.width))\" height=\"\(fmt(r.height))\" fill=\"\(escape(currentFillStyle))\" />"
        )
        return self
    }

    @discardableResult
    public func clearRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Self {
        let r = scaledRect(x, y, width, height)
        appendElement(
            "<rect x=\"\(fmt(r.x))\" y=\"\(fmt(r.y))\" width=\"\(fmt(r.width))\" height=\"\(fmt(r.height))\" fill=\"white\" />"
        )
        return self
    }

    // MARK: - RenderContext: text

    @discardableResult
    public func fillText(_ text: String, _ x: Double, _ y: Double) -> Self {
        let p = scaled(x, y)
        let family = escape(primaryFontFamily(from: currentFontInfo.family))
        let sizePx = fmt(VexFont.convertSizeToPixelValue(currentFontInfo.size))
        let style = escape(currentFontInfo.style)
        let weight = escape(currentFontInfo.weight)

        appendElement(
            "<text x=\"\(fmt(p.x))\" y=\"\(fmt(p.y))\" fill=\"\(escape(currentFillStyle))\" font-family=\"\(family)\" font-size=\"\(sizePx)\" font-style=\"\(style)\" font-weight=\"\(weight)\">\(escape(text))</text>"
        )
        return self
    }

    public func measureText(_ text: String) -> TextMeasure {
        let px = max(VexFont.convertSizeToPixelValue(currentFontInfo.size), 1)
        let width = Double(text.count) * 0.6 * px
        let yMin = -px * 0.8
        return TextMeasure(x: 0, y: yMin, width: width, height: px)
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

    // MARK: - RenderContext: grouping

    public func openGroup(_ cls: String?, _ id: String?) -> Any? {
        let group = SVGGroupNode(cls: cls, id: id)
        groupStack.append(group)
        return groupStack.count - 1
    }

    public func closeGroup() {
        guard let group = groupStack.popLast() else { return }
        appendElement(groupElement(group))
    }

    public func add(_ child: Any) {
        if let child = child as? String {
            appendElement(child)
        }
    }

    // MARK: - SVG output

    public func getSVG() -> String {
        while !groupStack.isEmpty {
            closeGroup()
        }

        let width = fmt(canvasWidth)
        let height = fmt(canvasHeight)
        var header = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\""
        if options.includeViewBox {
            header += " viewBox=\"0 0 \(width) \(height)\""
        }
        header += ">"

        let body = rootElements.joined(separator: "\n")
        let footer = "</svg>"

        var output = "\(header)\n\(body)\n\(footer)"
        if options.includeXMLHeader {
            output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + output
        }
        return output + "\n"
    }

    // MARK: - Private helpers

    private func scaled(_ x: Double, _ y: Double) -> (x: Double, y: Double) {
        (x * currentScaleX, y * currentScaleY)
    }

    private func scaledRect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> (x: Double, y: Double, width: Double, height: Double) {
        (
            x: x * currentScaleX,
            y: y * currentScaleY,
            width: width * currentScaleX,
            height: height * currentScaleY
        )
    }

    private func currentPathData() -> String? {
        guard !currentPathCommands.isEmpty else { return nil }
        return currentPathCommands.joined(separator: " ")
    }

    private func pathElement(d: String, fill: String?, stroke: String?, includeStrokeAttrs: Bool) -> String {
        var attrs = "d=\"\(escape(d))\""
        if let fill {
            attrs += " fill=\"\(escape(fill))\""
        }
        if let stroke {
            attrs += " stroke=\"\(escape(stroke))\""
        }
        if includeStrokeAttrs {
            attrs += " stroke-width=\"\(fmt(currentLineWidth * currentScaleX))\""
            attrs += " stroke-linecap=\"\(currentLineCap.rawValue)\""
            if !currentLineDash.isEmpty {
                attrs += " stroke-dasharray=\"\(currentLineDash.map(fmt).joined(separator: ","))\""
            }
        }
        return "<path \(attrs) />"
    }

    private func appendElement(_ element: String) {
        if let group = groupStack.last {
            group.children.append(element)
        } else {
            rootElements.append(element)
        }
    }

    private func groupElement(_ group: SVGGroupNode) -> String {
        var attrs: [String] = []
        if let cls = group.cls, !cls.isEmpty {
            attrs.append("class=\"\(escape(cls))\"")
        }
        if let id = group.id, !id.isEmpty {
            attrs.append("id=\"\(escape(id))\"")
        }
        let open = attrs.isEmpty ? "<g>" : "<g \(attrs.joined(separator: " "))>"
        let body = group.children.joined(separator: "\n")
        return "\(open)\n\(body)\n</g>"
    }

    private func primaryFontFamily(from cssFamily: String) -> String {
        let parts = cssFamily.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return parts.first ?? "Arial"
    }

    private func normalizedArcDelta(startAngle: Double, endAngle: Double, counterclockwise: Bool) -> Double {
        var delta = endAngle - startAngle

        if !counterclockwise {
            while delta < 0 { delta += 2 * .pi }
            while delta > 2 * .pi { delta -= 2 * .pi }
        } else {
            while delta > 0 { delta -= 2 * .pi }
            while delta < -(2 * .pi) { delta += 2 * .pi }
        }

        return delta
    }

    private func fmt(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "0" }
        if options.precision == 0 { return String(Int(value.rounded())) }

        let pow10 = pow(10.0, Double(options.precision))
        let rounded = (value * pow10).rounded() / pow10
        var text = String(rounded)
        if text.contains("e") || text.contains("E") {
            text = String(format: "%.\(options.precision)f", rounded)
        }
        if text.contains(".") {
            while text.last == "0" { text.removeLast() }
            if text.last == "." { text.removeLast() }
        }
        if text == "-0" { return "0" }
        return text
    }

    private func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
