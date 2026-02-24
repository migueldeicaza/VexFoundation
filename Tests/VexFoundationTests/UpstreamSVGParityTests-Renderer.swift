import Testing
@testable import VexFoundation

extension UpstreamSVGParityTests {
    @Test("Renderer.Random")
    func rendererRandomMatchesUpstream() throws {
        try runCategorySVGParityCase(module: "Renderer", test: "Random", width: 700, height: 100) { factory, context in
            try drawUpstreamRendererBaseline(factory: factory, context: context)
        }
    }

    @Test("Renderer.Renderer_API_with_element_ID_string")
    func rendererAPIWithElementIDStringMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Renderer",
            test: "Renderer_API_with_element_ID_string",
            width: 700,
            height: 100
        ) { factory, context in
            try drawUpstreamRendererBaseline(factory: factory, context: context)
        }
    }

    @Test("Renderer.Renderer_API_with_canvas_or_div")
    func rendererAPIWithCanvasOrDivMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Renderer",
            test: "Renderer_API_with_canvas_or_div",
            width: 700,
            height: 100
        ) { factory, context in
            try drawUpstreamRendererBaseline(factory: factory, context: context)
        }
    }

    @Test("Renderer.Renderer_API_with_context")
    func rendererAPIWithContextMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Renderer",
            test: "Renderer_API_with_context",
            width: 700,
            height: 100
        ) { factory, context in
            try drawUpstreamRendererBaseline(factory: factory, context: context)
        }
    }

    @Test("Renderer.Factory_API_with_element_ID_string")
    func rendererFactoryAPIWithElementIDStringMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Renderer",
            test: "Factory_API_with_element_ID_string",
            width: 700,
            height: 100
        ) { factory, context in
            try drawUpstreamRendererBaseline(factory: factory, context: context)
        }
    }

    @Test("Renderer.Factory_API_with_canvas_or_div")
    func rendererFactoryAPIWithCanvasOrDivMatchesUpstream() throws {
        try runCategorySVGParityCase(
            module: "Renderer",
            test: "Factory_API_with_canvas_or_div",
            width: 700,
            height: 100
        ) { factory, context in
            try drawUpstreamRendererBaseline(factory: factory, context: context)
        }
    }

    private func drawUpstreamRendererBaseline(factory: Factory, context: SVGRenderContext) throws {
        let stave = factory.Stave()
            .addClef(.bass)
            .addTimeSignature(.meter(3, 4))
        try stave.draw()

        let notes: [StaveNote] = try [
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["C/4"], duration: "4")),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["E/4"], duration: "4")),
            factory.StaveNote(StaveNoteStruct(parsingKeys: ["G/4"], duration: "4")),
        ]

        _ = try Formatter.FormatAndDraw(ctx: context, stave: stave, notes: notes)
    }
}
