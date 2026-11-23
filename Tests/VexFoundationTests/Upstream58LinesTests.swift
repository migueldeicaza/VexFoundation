// Logic-level tests for the line behaviors ported from VexFlow 5.7.0 → 5.8.0 (group "Lines").
// Ported from the 5.8.0 assertions in tests/node/rendering-tests.mjs, tests/svgcontext_tests.ts,
// tests/barline_tests.ts, tests/curve_tests.ts, tests/stavetie_tests.ts and tests/textnote_tests.ts.
// The upstream tests replace context methods or read the DOM. These tests use a recording context
// that forwards to the SVG string context, or they read the SVG node tree.

import Foundation
import Testing
@testable import VexFoundation

/// Run `body` in an isolated runtime context.
private func isolated<T>(_ body: () throws -> T) rethrows -> T {
    try Flow.withRuntimeContext(Flow.makeRuntimeContext(), body)
}

/// A context that records the calls and forwards them to an SVG context.
private final class RecordingContext: RenderContext {
    enum Call: Equatable {
        case beginPath
        case moveTo(Double, Double)
        case lineTo(Double, Double)
        case quadraticCurveTo(Double, Double, Double, Double)
        case bezierCurveTo(Double, Double, Double, Double, Double, Double)
        case closePath
        case stroke
        case fill
    }

    let inner: SVGRenderContext
    var calls: [Call] = []
    var dashes: [[Double]] = []
    var texts: [(String, Double, Double)] = []
    /// Boxes of `fillRect` calls and of the filled `arc` calls.
    var shapes: [BoundingBox] = []

    init(width: Double = 800, height: Double = 400) {
        inner = SVGRenderContext(width: width, height: height)
    }

    func reset() {
        calls = []
        dashes = []
        texts = []
        shapes = []
    }

    var fillStyle: String {
        get { inner.fillStyle }
        set { inner.fillStyle = newValue }
    }

    var strokeStyle: String {
        get { inner.strokeStyle }
        set { inner.strokeStyle = newValue }
    }

    func clear() { inner.clear() }
    func setDefaultStyle(_ style: ElementStyle) -> Self { inner.setDefaultStyle(style); return self }
    func getDefaultStyle() -> ElementStyle { inner.getDefaultStyle() }
    func save() -> Self { inner.save(); return self }
    func restore() -> Self { inner.restore(); return self }
    func setFillStyle(_ style: String) -> Self { inner.setFillStyle(style); return self }
    func setBackgroundFillStyle(_ style: String) -> Self { inner.setBackgroundFillStyle(style); return self }
    func setStrokeStyle(_ style: String) -> Self { inner.setStrokeStyle(style); return self }
    func setShadowColor(_ color: String) -> Self { inner.setShadowColor(color); return self }
    func setShadowBlur(_ blur: Double) -> Self { inner.setShadowBlur(blur); return self }
    func setLineWidth(_ width: Double) -> Self { inner.setLineWidth(width); return self }
    func setLineCap(_ capType: VexLineCap) -> Self { inner.setLineCap(capType); return self }
    func setLineDash(_ dashPattern: [Double]) -> Self {
        dashes.append(dashPattern)
        inner.setLineDash(dashPattern)
        return self
    }
    func scale(_ x: Double, _ y: Double) -> Self { inner.scale(x, y); return self }
    func resize(_ width: Double, _ height: Double) -> Self { inner.resize(width, height); return self }
    func beginPath() -> Self { calls.append(.beginPath); inner.beginPath(); return self }
    func moveTo(_ x: Double, _ y: Double) -> Self { calls.append(.moveTo(x, y)); inner.moveTo(x, y); return self }
    func lineTo(_ x: Double, _ y: Double) -> Self { calls.append(.lineTo(x, y)); inner.lineTo(x, y); return self }
    func bezierCurveTo(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ x: Double, _ y: Double) -> Self {
        calls.append(.bezierCurveTo(a, b, c, d, x, y))
        inner.bezierCurveTo(a, b, c, d, x, y)
        return self
    }
    func quadraticCurveTo(_ a: Double, _ b: Double, _ x: Double, _ y: Double) -> Self {
        calls.append(.quadraticCurveTo(a, b, x, y))
        inner.quadraticCurveTo(a, b, x, y)
        return self
    }
    private var pendingArc: BoundingBox?
    func arc(_ x: Double, _ y: Double, _ r: Double, _ s: Double, _ e: Double, _ ccw: Bool) -> Self {
        pendingArc = BoundingBox(x: x - r, y: y - r, w: 2 * r, h: 2 * r)
        inner.arc(x, y, r, s, e, ccw)
        return self
    }
    func closePath() -> Self { calls.append(.closePath); inner.closePath(); return self }
    func fill() -> Self {
        calls.append(.fill)
        if let pendingArc { shapes.append(pendingArc) }
        pendingArc = nil
        inner.fill()
        return self
    }
    func stroke() -> Self { calls.append(.stroke); inner.stroke(); return self }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.rect(x, y, w, h); return self }
    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self {
        shapes.append(BoundingBox(x: x, y: y, w: w, h: h))
        inner.fillRect(x, y, w, h)
        return self
    }
    func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.clearRect(x, y, w, h); return self }
    func pointerRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Self { inner.pointerRect(x, y, w, h); return self }
    func openRotation(_ angleDegrees: Double, _ x: Double, _ y: Double) { inner.openRotation(angleDegrees, x, y) }
    func closeRotation() { inner.closeRotation() }
    func fillText(_ text: String, _ x: Double, _ y: Double) -> Self {
        texts.append((text, x, y))
        inner.fillText(text, x, y)
        return self
    }
    func measureText(_ text: String) -> TextMeasure { inner.measureText(text) }
    func setFont(_ family: String?, _ size: Double?, _ weight: String?, _ style: String?) -> Self {
        inner.setFont(family, size, weight, style)
        return self
    }
    func setFont(_ fontInfo: FontInfo) -> Self { inner.setFont(fontInfo); return self }
    func getFont() -> String { inner.getFont() }
    func openGroup(_ cls: String?, _ id: String?) -> Any? { inner.openGroup(cls, id) }
    func closeGroup() { inner.closeGroup() }
    func add(_ child: Any) { inner.add(child) }
}

private func makeFactory(width: Double, height: Double) -> (f: Factory, ctx: RecordingContext) {
    let f = Factory(options: FactoryOptions(width: width, height: height))
    let ctx = RecordingContext(width: width, height: height)
    _ = f.setContext(ctx)
    return (f, ctx)
}

private func errorCode(_ body: () throws -> Void) -> String? {
    do {
        try body()
        return nil
    } catch let error as VexError {
        return error.code
    } catch {
        return "\(error)"
    }
}

/// All nodes of `node` and its descendants with the element name `name`, in document order.
private func nodes(named name: String, in node: SVGNode) -> [SVGNode] {
    var found: [SVGNode] = node.name == name ? [node] : []
    for child in node.children { found += nodes(named: name, in: child) }
    return found
}

@Suite("Upstream 5.8.0 port: Lines")
struct Upstream58LinesTests {

    // MARK: - Dashed lines (tests/node/rendering-tests.mjs)

    /// Reject invalid geometry and patterns before a drawing backend receives any path commands.
    @Test func dashedLinesRejectInvalidOrExcessivePathsBeforeDrawing() {
        let untouched = RecordingContext()
        // Upstream also rejects the sparse array `[3, , 1]`. A Swift array cannot have holes.
        for pattern: [Double] in [[], [0, 0], [-1, 2], [.nan], [1, .infinity], [0.00001]] {
            #expect(errorCode { try Renderer.drawDashedLine(untouched, 0, 0, 10, 0, pattern) } == "BadDashPattern")
        }
        for endpoints: [Double] in [
            [.nan, 0, 1, 1],
            [0, 0, 1, .infinity],
            [-Double.greatestFiniteMagnitude, 0, Double.greatestFiniteMagnitude, 0],
        ] {
            #expect(errorCode {
                try Renderer.drawDashedLine(untouched, endpoints[0], endpoints[1], endpoints[2], endpoints[3], [3])
            } == "BadDashLine")
        }
        #expect(untouched.calls.isEmpty, "invalid line started a path")
    }

    /// Check real path coordinates for gaps of zero, odd-length patterns and reversed diagonal strokes.
    @Test func dashedLinesPreserveAlternatingSegmentsAndFinishOnTheEndpoint() throws {
        let ctx = RecordingContext()
        try Renderer.drawDashedLine(ctx, 0, 4, 5, 4, [3, 0])
        #expect(ctx.calls == [.beginPath, .moveTo(0, 4), .lineTo(3, 4), .moveTo(3, 4), .lineTo(5, 4), .closePath, .stroke])
        ctx.reset()
        try Renderer.drawDashedLine(ctx, 9, 12, 0, 0, [5])
        #expect(ctx.calls == [.beginPath, .moveTo(9, 12), .lineTo(6, 8), .moveTo(3, 4), .lineTo(0, 0), .closePath, .stroke])
        ctx.reset()
        try Renderer.drawDashedLine(ctx, 5, 7, 5, 7, [3])
        #expect(ctx.calls == [.beginPath, .moveTo(5, 7), .closePath, .stroke])
    }

    @Test func dashPatternValidationAndStops() throws {
        #expect(try dashStops(10, [3, 0]) == [3, 3, 6, 6, 9, 9, 10])
        #expect(try dashStops(0, [3]) == [])
        #expect(errorCode { _ = try dashStops(10, [0]) } == "BadDashPattern")
        #expect(errorCode { _ = try dashStops(Double(MAX_DASH_SEGMENTS) + 1, [1]) } == "BadDashPattern")
        #expect(try dashStops(Double(MAX_DASH_SEGMENTS), [1]).count == MAX_DASH_SEGMENTS)
        #expect(throws: Never.self) { try validateDashPattern([0, 2]) }
    }

    /// Validate bracket styles atomically and keep their value independent of the caller's array.
    @Test func textBracketsRetainTheirValidatedDashPattern() throws {
        try isolated {
            let note = StaveNote(try StaveNoteStruct(parsingKeys: ["c/4"], duration: "q"))
            let bracket = TextBracket(start: note, stop: note)
            var pattern: [Double] = [3, 0]
            bracket.setDashed(true, dash: pattern)
            pattern[0] = 0
            #expect(bracket.renderOptions.dash == [3, 0])
            #expect(errorCode { try bracket.setDashedThrowing(false, dash: [0]) } == "BadDashPattern")
            #expect(bracket.renderOptions.dashed == true)
            // The non-throwing variant also leaves the bracket unchanged.
            bracket.setDashed(false, dash: [0])
            #expect(bracket.renderOptions.dashed == true)
            bracket.setDashed(false)
            #expect(bracket.renderOptions.dashed == false)
            #expect(bracket.renderOptions.dash == [3, 0])
        }
    }

    // MARK: - SVG context (tests/svgcontext_tests.ts)

    /// Verify that public attribute records cannot install script-capable SVG attributes.
    @Test func svgContextRejectsExecutableAttributes() throws {
        let context = SVGRenderContext(width: 100, height: 100)
        context.rect(1, 2, 3, 4, attributes: SVGAttributes([
            ("fill", .string("red")),
            ("pointer-events", .string("all")),
            ("oNcLiCk", .string("ignored")),
        ]))
        let rectangle = try #require(nodes(named: "rect", in: context.svg).first)
        #expect(rectangle.getAttribute("oNcLiCk") == nil, "mixed-case event attributes are rejected")
        #expect(rectangle.getAttribute("fill") == "red", "ordinary presentation attributes remain")
        #expect(rectangle.getAttribute("pointer-events") == "all", "pointer rectangles remain interactive")

        context.beginPath().moveTo(0, 0).lineTo(1, 1).fill(attributes: SVGAttributes([
            ("fill", .string("green")),
            ("oNlOaD", .string("ignored")),
            ("style", .string("opacity: 0.5")),
            ("href", .string("#unused")),
            ("xlink:href", .string("#unused")),
            ("stroke", .string("blue")),
        ]))
        let path = try #require(nodes(named: "path", in: context.svg).first)
        #expect(path.getAttribute("oNlOaD") == nil, "path event attributes are rejected")
        #expect(path.getAttribute("fill") == "green", "safe path attributes remain")
        #expect(path.getAttribute("style") == nil, "caller-supplied raw styles are rejected")
        #expect(path.getAttribute("href") == nil, "unqualified links are rejected")
        #expect(path.getAttribute("xlink:href") == nil, "namespaced links are rejected")
        #expect(path.getAttribute("stroke") == "blue", "safe direct attributes remain")

        for name in ["onfocus", "ONLOAD", "style", "STYLE", "href", "xlink:href", "XLink:HREF"] {
            #expect(SVGRenderContext.isUnsafeAttributeName(name), "\(name)")
        }
        for name in ["stroke", "opacity", "pointer-events", "class", "hrefs"] {
            #expect(!SVGRenderContext.isUnsafeAttributeName(name), "\(name)")
        }
    }

    /// Verify that geometry, presentation, paths, and trusted shadow rendering still work.
    @Test func svgContextPreservesPresentationAttributes() throws {
        let context = SVGRenderContext(width: 100, height: 100)
        context.rect(1, 2, 3, 4, attributes: SVGAttributes([
            ("fill", .string("red")),
            ("stroke", .string("blue")),
            ("opacity", .number(0.5)),
        ]))
        let rectangle = try #require(nodes(named: "rect", in: context.svg).first)
        #expect(rectangle.getAttribute("x") == "1", "rectangle geometry remains")
        #expect(rectangle.getAttribute("fill") == "red", "rectangle fill remains")
        #expect(rectangle.getAttribute("stroke") == "blue", "rectangle stroke remains")
        #expect(rectangle.getAttribute("opacity") == "0.5", "rectangle opacity remains")

        context.setShadowBlur(3).setShadowColor("green")
        context.beginPath().moveTo(0, 0).lineTo(2, 2).fill(attributes: SVGAttributes([
            ("fill", .string("purple")),
            ("stroke", .string("none")),
        ]))
        let path = try #require(nodes(named: "path", in: context.svg).first)
        #expect(path.getAttribute("d") == "M0 0L2 2", "path geometry remains")
        #expect(path.getAttribute("fill") == "purple", "path presentation remains")
        // The browser serialization of `path.style.filter = 'drop-shadow(0 0 2px green)'`.
        #expect(path.getAttribute("style") == "filter: drop-shadow(green 0px 0px 2px);")
        #expect(path.attributes.last?.0 == "style", "the reference SVGs write the style last")

        // A stroke has the same shadow. The 5.9.0 reference SVGs show the blur with six digits.
        context.setShadowBlur(4).setShadowColor("blue")
        context.beginPath().moveTo(0, 0).lineTo(2, 2).stroke()
        let stroked = try #require(nodes(named: "path", in: context.svg).last)
        #expect(stroked.getAttribute("style") == "filter: drop-shadow(blue 0px 0px 2.66667px);")
    }

    @Test func cssSerializationOfShadowValues() {
        #expect(SVGRenderContext.cssNumber(2) == "2")
        #expect(SVGRenderContext.cssNumber(2.6666666666666665) == "2.66667")
        #expect(SVGRenderContext.cssNumber(1.3333333333333333) == "1.33333")
        #expect(SVGRenderContext.cssNumber(0.5) == "0.5")
        #expect(SVGRenderContext.cssColor("blue") == "blue")
        #expect(SVGRenderContext.cssColor("#f00") == "rgb(255, 0, 0)")
        #expect(SVGRenderContext.cssColor("#00ff0080") == "rgba(0, 255, 0, 0.5)")
        #expect(SVGRenderContext.cssColor("rgba(1, 2, 3, 0.4)") == "rgba(1, 2, 3, 0.4)")
    }

    // MARK: - Barlines (tests/barline_tests.ts)

    @Test func barlineTypesAndWidths() throws {
        #expect(BarlineType.dashed.rawValue == 8)
        #expect(BarlineType.dotted.rawValue == 9)
        #expect(BarlineType.doubleHeavy.rawValue == 10)
        #expect(Barline.typeString["dashed"] == .dashed)
        #expect(Barline.typeString["dotted"] == .dotted)
        #expect(Barline.typeString["doubleHeavy"] == .doubleHeavy)
        try isolated {
            let expected: [(BarlineType, Double, Double, Double, Double)] = [
                (.dashed, 5, 0, 1, 8),
                (.dotted, 5, -0.5, 1.5, 9),
                (.doubleHeavy, 8, -7, 1, 17),
            ]
            for (type, width, xMin, xMax, noteWidth) in expected {
                let bar = Barline(type)
                #expect(bar.getWidth() == width)
                #expect(bar.getPadding(0) == 0)
                let metrics = try #require(bar.getLayoutMetrics())
                #expect(metrics.xMin == xMin && metrics.xMax == xMax)
                #expect(metrics.paddingLeft == 5 && metrics.paddingRight == 5)
                #expect(BarNote(type: type).getWidth() == noteWidth)
            }
        }
    }

    /// Upstream `measureBoundaries` and `assertBarInk`: inline bars consume no time and the
    /// notes clear them; the end bars have the upstream ink.
    @Test func editorialAndDoubleHeavyBoundaries() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 770, height: 230)
            let rows = try drawUpstreamBarlineMeasureBoundaries(f)
            #expect(rows.count == 10)
            for row in rows {
                let type = try #require(row.stave.getModifiers(position: .end, category: Barline.category).first as? Barline)
                    .getType()
                #expect(row.mark.getType() == type, "inline name selects the same stave boundary")
                #expect(row.mark.shouldIgnoreTicks() && row.voice.isComplete(), "inline bar consumes no musical time")
                let metrics = try #require(Barline(type).getLayoutMetrics())
                #expect(row.left.getNoteHeadEndX() < row.mark.getAbsoluteX() + metrics.xMin, "left note clears inline bar")
                #expect(row.mark.getAbsoluteX() + metrics.xMax < row.right.getNoteHeadBeginX(), "right note clears inline bar")
                #expect(
                    row.right.getNoteHeadEndX() < row.stave.getX() + row.width + metrics.xMin,
                    "last note clears end bar"
                )
            }
            try f.draw()

            // Draw each end bar again and inspect the ink of its components.
            for row in rows {
                let stave = row.stave
                let bar = try #require(stave.getModifiers(position: .end, category: Barline.category).first as? Barline)
                ctx.reset()
                try bar.draw()
                let shapes = ctx.shapes
                let (topY, botY) = try stave.getBarlineBounds()
                let type = bar.getType()
                #expect(shapes.count >= 2, "visible components")
                if type == .dashed || type == .dotted {
                    #expect(shapes.allSatisfy { $0.y >= topY - 0.01 && $0.y + $0.h <= botY + 0.01 }, "inside span")
                    for (i, box) in shapes.enumerated() {
                        #expect(box.x == shapes[0].x, "same vertical column")
                        if i > 0 { #expect(shapes[i - 1].y + shapes[i - 1].h < box.y, "gap between marks") }
                        #expect(type == .dotted ? box.w == box.h : box.h > box.w, "dot or dash proportions")
                    }
                } else {
                    #expect(shapes.count == 2, "two solid strokes")
                    let left = shapes[0], right = shapes[1]
                    #expect(left.x + left.w < right.x, "white gap")
                    let widths: [Double] = type == .doubleHeavy ? [3, 3] : type == .end ? [1, 3] : [1, 1]
                    #expect([left.w, right.w] == widths)
                    #expect(left.h == botY - topY, "strokes fit span")
                }
            }
        }
    }

    // MARK: - Half-dashed slurs (tests/curve_tests.ts, phraseribbon.ts)

    /// An editorial opening and its solid ending share the apex above the middle B.
    @Test func halfDashedSlurAtTwoWidths() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 420, height: 300)
            let rows = try drawUpstreamHalfDashedSlurs(f)
            for (notes, slur) in rows {
                let (start, end) = try slur.getAnchors()
                let center = notes[2].getAbsoluteX() + notes[2].getGlyphWidth() / 2
                #expect(abs((start.x + end.x) / 2 - center) < 1, "midpoint is above the third attack")
            }
            ctx.reset()
            try f.draw()
            let openings = ctx.dashes.enumerated().filter { !$0.element.isEmpty }
            #expect(openings.map(\.element) == [[4, 3], [4, 3]], "one dashed opening at each width")
            for (index, _) in openings {
                #expect(ctx.dashes[index + 1] == [], "the ending has continuous ink")
            }
            // The half-dashed slur has no thickness ribbon: the bounds follow the outer curve only.
            for (_, slur) in rows {
                let parts = try slur.getRouteParts()
                #expect(!parts.isEmpty)
                let box = try #require(slur.getBoundingBox())
                slur.renderOptions.halfDashed = false
                let solid = try #require(slur.getBoundingBox())
                slur.renderOptions.halfDashed = true
                #expect(box.h < solid.h)
            }
        }
    }

    @Test func drawHalfDashedSlurSplitsTheCurveAtTheMiddleOfTheWholeSlur() {
        let points = [
            RibbonPoint(x: 0, y: 0), RibbonPoint(x: 10, y: -20), RibbonPoint(x: 30, y: -20), RibbonPoint(x: 40, y: 0),
        ]
        func cubic(_ t: Double) -> RibbonPoint {
            let u = 1 - t
            func axis(_ k: KeyPath<RibbonPoint, Double>) -> Double {
                u * u * u * points[0][keyPath: k] + 3 * u * u * t * points[1][keyPath: k]
                    + 3 * u * t * t * points[2][keyPath: k] + t * t * t * points[3][keyPath: k]
            }
            return RibbonPoint(x: axis(\.x), y: axis(\.y))
        }

        let ctx = RecordingContext()
        drawHalfDashedSlur(ctx, points, (0, 0.5))
        #expect(ctx.dashes == [[4, 3]])
        ctx.reset()
        drawHalfDashedSlur(ctx, points, (0.5, 1), dash: [2, 2])
        #expect(ctx.dashes == [[]])

        // A fragment from 0.25 to 0.75 of the whole slur splits at its own midpoint.
        ctx.reset()
        drawHalfDashedSlur(ctx, points, (0.25, 0.75))
        #expect(ctx.dashes == [[4, 3], []])
        let ends = ctx.calls.compactMap { call -> RibbonPoint? in
            if case let .bezierCurveTo(_, _, _, _, x, y) = call { return RibbonPoint(x: x, y: y) }
            return nil
        }
        let join = cubic(0.5)
        #expect(ends.count == 2)
        #expect(abs(ends[0].x - join.x) < 1e-9 && abs(ends[0].y - join.y) < 1e-9)
        #expect(ends[1] == points[3])

        // An uneven fragment splits at (0.5 - start) / (end - start).
        ctx.reset()
        drawHalfDashedSlur(ctx, points, (0.4, 0.9))
        let uneven = ctx.calls.compactMap { call -> RibbonPoint? in
            if case let .bezierCurveTo(_, _, _, _, x, y) = call { return RibbonPoint(x: x, y: y) }
            return nil
        }
        let t = cubic(0.2)
        #expect(abs(uneven[0].x - t.x) < 1e-9 && abs(uneven[0].y - t.y) < 1e-9)
    }

    @Test func splitBezierPreservesTheCurve() {
        let points = [RibbonPoint(x: 0, y: 0), RibbonPoint(x: 4, y: 8), RibbonPoint(x: 8, y: 0)]
        let (left, right) = splitBezier(points)
        #expect(left == [RibbonPoint(x: 0, y: 0), RibbonPoint(x: 2, y: 4), RibbonPoint(x: 4, y: 4)])
        #expect(right == [RibbonPoint(x: 4, y: 4), RibbonPoint(x: 6, y: 4), RibbonPoint(x: 8, y: 0)])
        let (l2, r2) = splitBezier(points, 0.25)
        #expect(l2.last == r2.first)
        #expect(l2.last == RibbonPoint(x: 2, y: 3))
    }

    // MARK: - Ties (tests/stavetie_tests.ts)

    /// The editorial tie and its solid control both belong to the lower note of each dyad.
    @Test func dashedTiesOnSelectedHeads() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 510, height: 155)
            let rows = try drawUpstreamDashedPitchTies(f, ctx)
            let groups = nodes(named: "g", in: ctx.inner.svg).filter { $0.getAttribute("class") == "vf-stavetie" }
            #expect(groups.count == 2)
            for (bar, row) in rows.enumerated() {
                #expect(row.tie.getNotes().firstIndexes == [0], "only the lower head starts a tie")
                #expect(row.voice.getTickables().count == 2)
                #expect(row.voice.isComplete())
                let path = try #require(nodes(named: "path", in: groups[bar]).first)
                let d = path.getAttribute("d") ?? ""
                #expect(d.filter { $0 == "Q" }.count == (bar == 0 ? 1 : 2), "open dashed arc or closed solid ribbon")
                if bar == 0 {
                    // The path inherits the dash from its group (upstream reads the computed style).
                    let dash = path.getAttribute("stroke-dasharray") ?? groups[bar].getAttribute("stroke-dasharray")
                    #expect(dash == "4,3", "stroke has visible gaps")
                    #expect(path.getAttribute("fill") == "none")
                }
            }
            // A dashed tie is a stroked arc: the bounds use the top control point and half the line width.
            let dashed = rows[0].tie
            let route = try dashed.getRouteParts()
            let bounds = try dashed.getRibbonBounds()
            let firstX = dashed.getFirstX(), lastX = dashed.getLastX()
            #expect(bounds.x == min(firstX, lastX) - 0.5)
            #expect(bounds.w == abs(lastX - firstX) + 1)
            #expect(route.allSatisfy { $0.x >= bounds.x - 1e-9 && $0.x + $0.w <= bounds.x + bounds.w + 1e-9 })
        }
    }

    /// Keep the open end next to the chosen chord head, including after a width change.
    @Test func laissezVibrerOnOneChordHead() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 600, height: 240)
            let rows = try drawUpstreamLaissezVibrerTies(f, ctx)
            for row in rows {
                for (index, tie) in row.ties.enumerated() {
                    let head = (index == 0 ? row.lower : row.upper).getHeadInk()[index]
                    #expect(tie.getFirstX() == head.x + head.w, "attached to the selected head")
                    #expect(tie.getLastX() - tie.getFirstX() == (index == 0 ? 18 : 22), "free endpoint is local")
                    let box = try #require(tie.getBoundingBox())
                    #expect(box.w == tie.getLastX() - tie.getFirstX(), "layout bounds follow the arc")
                    #expect(tie.getNotes().lastIndexes == [index])
                    #expect(tie.initError == nil)
                }
                #expect(row.ties[0].getLastX() < row.rest.getNoteHeadBeginX(), "rest on beat two clears the local tie")
                #expect(row.voice.isComplete())
                #expect(
                    f.StaveTie(notes: TieNotes(firstNote: row.lower)).getLastX() == row.stave.getTieEndX(),
                    "ordinary partial tie reaches the edge"
                )
            }
        }
    }

    @Test func laissezVibrerRejectsInvalidReachAndHeads() throws {
        try isolated {
            let chord = StaveNote(try StaveNoteStruct(parsingKeys: ["d/4", "a/4"], duration: "q"))
            let other = StaveNote(try StaveNoteStruct(parsingKeys: ["d/4"], duration: "q"))
            let rest = StaveNote(try StaveNoteStruct(parsingKeys: ["b/4"], duration: "qr"))
            let invalid: [TieNotes] = [
                TieNotes(firstNote: chord, laissezVibrer: 0),
                TieNotes(firstNote: chord, laissezVibrer: -1),
                TieNotes(firstNote: chord, laissezVibrer: .nan),
                TieNotes(firstNote: chord, laissezVibrer: .infinity),
                TieNotes(firstNote: chord, lastNote: other, laissezVibrer: 10),
                TieNotes(lastNote: chord, laissezVibrer: 10),
                TieNotes(firstNote: rest, laissezVibrer: 10),
                TieNotes(firstNote: chord, firstIndexes: [0, 1], lastIndexes: [0, 1], laissezVibrer: 10),
                TieNotes(firstNote: chord, firstIndexes: [2], lastIndexes: [2], laissezVibrer: 10),
                TieNotes(firstNote: chord, firstIndexes: [-1], lastIndexes: [-1], laissezVibrer: 10),
            ]
            for notes in invalid {
                let tie = StaveTie(notes: notes)
                #expect(tie.initError == .invalidLaissezVibrer)
                #expect(tie.getNotes().laissezVibrer == nil)
                #expect(throws: StaveTieError.invalidLaissezVibrer) { try StaveTie(validating: notes) }
                #expect(throws: StaveTieError.invalidLaissezVibrer) {
                    try StaveTie(notes: TieNotes(firstNote: chord)).setNotesThrowing(notes)
                }
            }
            let valid = try StaveTie(validating: TieNotes(firstNote: chord, firstIndexes: [1], lastIndexes: [1], laissezVibrer: 12))
            #expect(valid.getNotes().laissezVibrer == 12)
        }
    }

    // MARK: - Hairpins (stavehairpin.ts, flaredhairpin.ts)

    @Test func flaredHairpinDrawsTwoParabolicArms() {
        let ctx = RecordingContext()
        drawFlaredHairpin(
            ctx,
            HairpinPoint(x: 10, y: 50, progress: 0.5),
            HairpinPoint(x: 30, y: 50, progress: 1),
            8
        )
        #expect(ctx.calls == [
            .beginPath,
            .moveTo(10, 48), .quadraticCurveTo(20, 46, 30, 42),
            .moveTo(10, 52), .quadraticCurveTo(20, 54, 30, 58),
            .stroke,
        ])
    }

    @Test func flaredStaveHairpinUsesCurvedArms() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 400, height: 160)
            let stave = f.Stave(x: 10, y: 10, width: 380)
            let notes = f.EasyScore().notes("c4/q, d4, e4, f4")
            let voice = f.EasyScore().voice(notes.map { $0 as Note })
            _ = f.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try f.draw()
            for (type, flared) in [(HairpinType.crescendo, true), (.decrescendo, true), (.crescendo, false)] {
                let hairpin = StaveHairpin(firstNote: notes[0], lastNote: notes[3], type: type)
                hairpin.renderOptions.flared = flared
                _ = hairpin.setContext(ctx)
                _ = hairpin.setPosition(.below)
                ctx.reset()
                try hairpin.draw()
                let curves = ctx.calls.filter { if case .quadraticCurveTo = $0 { return true } else { return false } }
                let lines = ctx.calls.filter { if case .lineTo = $0 { return true } else { return false } }
                #expect(curves.count == (flared ? 2 : 0))
                #expect(lines.count == (flared ? 0 : 2))
                if flared, case let .moveTo(x0, _) = ctx.calls[1], case let .quadraticCurveTo(_, _, x1, _) = ctx.calls[2] {
                    // The arms start at the closed (soft) end.
                    #expect(type == .crescendo ? x0 < x1 : x0 > x1)
                }
            }
        }
    }

    // MARK: - Text dynamics (tests/textnote_tests.ts)

    @Test func textDynamicsKeepsCompoundLettersAndAddsNiente() throws {
        try isolated {
            let sfz = try TextDynamics(validating: TextNoteStruct(duration: .quarter, text: "sfz"))
            sfz.preFormat()
            sfz.preFormat()
            #expect(sfz.getText() == Glyphs.dynamicSforzando + Glyphs.dynamicForte + Glyphs.dynamicZ)
            let niente = try TextDynamics(validating: TextNoteStruct(duration: .quarter, text: "n"))
            niente.preFormat()
            #expect(niente.getText() == Glyphs.dynamicNiente)
            #expect(TextDynamics.GLYPHS["n"] == Glyphs.dynamicNiente)
            // An invalid sequence keeps the previous text.
            let bad = TextDynamics(TextNoteStruct(duration: .quarter, text: "px"))
            #expect(bad.textDynamicsInitError == .invalidDynamicsCharacter("x"))
            #expect(throws: TextDynamicsError.invalidDynamicsCharacter("x")) { try bad.preFormatThrowing() }
            #expect(bad.getText() == "")
        }
    }

    /// Reformat the same two voices and check the glyphs at the first and last attacks.
    @Test func timedPianoAndNiente() throws {
        try isolated {
            let (f, ctx) = makeFactory(width: 500, height: 160)
            let study = try UpstreamTimedNienteStudy(f)

            func draw(_ width: Double) throws -> Double {
                _ = study.stave.setWidth(width)
                let voices = [study.melody, study.dynamics]
                _ = f.Formatter().joinVoices(voices).formatToStave(voices, stave: study.stave)
                ctx.clear()
                try study.stave.drawWithStyle()
                try study.melody.draw(context: ctx, stave: study.stave)
                ctx.reset()
                try study.dynamics.draw(context: ctx, stave: study.stave)
                let baseline = study.stave.getYForLine(7)
                let letters = ctx.texts
                #expect(letters.count == 2, "Exactly one piano and one niente glyph")
                if letters.count == 2 {
                    #expect(letters[0] == (Glyphs.dynamicPiano, study.notes[0].getAbsoluteX(), baseline))
                    #expect(letters[1] == (Glyphs.dynamicNiente, study.notes[3].getAbsoluteX(), baseline))
                }
                return study.niente.getAbsoluteX()
            }

            let wide = try draw(460)
            #expect(try draw(260) < wide, "The final dynamic follows the final G as the stave narrows")
            #expect(try draw(460) == wide, "Restoring the width restores the niente position")
        }
    }
}
