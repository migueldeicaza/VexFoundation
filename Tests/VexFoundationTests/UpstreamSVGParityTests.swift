import Foundation
import Testing
@testable import VexFoundation

@Suite("Upstream SVG Parity (Opt-In)")
struct UpstreamSVGParityTests {
    private enum UpstreamSVGParityError: Error {
        case unsupportedFont(String)
    }

    private static let enableEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_PARITY"
    private static let referenceDirEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_REFERENCE_DIR"
    private static let fontsEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_FONTS"
    private static let artifactsDirEnvKey = "VEXFOUNDATION_UPSTREAM_SVG_ARTIFACTS_DIR"

    private let defaultFonts = ["Bravura", "Gonville", "Petaluma", "Leland"]

    @Test("Barline.Simple_BarNotes")
    func barlineSimpleBarNotesMatchesUpstream() throws {
        try runSVGParityCase(module: "Barline", test: "Simple_BarNotes", width: 380, height: 160) { factory in
            let stave = factory.Stave()
            let noteA = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["d/4", "e/4", "f/4"],
                duration: "2",
                stemDirection: .down
            ))
            let bar = factory.BarNote(type: .single)
            let noteB = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["c/4", "f/4", "a/4"],
                duration: "2",
                stemDirection: .down
            ))
            _ = noteB.addModifier(factory.Accidental(type: .natural), index: 0)
            _ = noteB.addModifier(factory.Accidental(type: .sharp), index: 1)

            let voice = factory.Voice()
            _ = voice.addTickables([noteA, bar, noteB])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    @Test("Barline.Style_BarNotes")
    func barlineStyleBarNotesMatchesUpstream() throws {
        try runSVGParityCase(module: "Barline", test: "Style_BarNotes", width: 380, height: 160) { factory in
            let stave = factory.Stave()
            let noteA = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["d/4", "e/4", "f/4"],
                duration: "2",
                stemDirection: .down
            ))
            let bar = factory.BarNote(type: .single)
            let noteB = try factory.StaveNote(StaveNoteStruct(
                parsingKeys: ["c/4", "f/4", "a/4"],
                duration: "2",
                stemDirection: .down
            ))
            _ = noteB.addModifier(factory.Accidental(type: .natural), index: 0)
            _ = noteB.addModifier(factory.Accidental(type: .sharp), index: 1)
            _ = bar.setStyle(ElementStyle(
                shadowColor: "blue",
                shadowBlur: 15,
                fillStyle: "blue",
                strokeStyle: "blue"
            ))

            let voice = factory.Voice()
            _ = voice.addTickables([noteA, bar, noteB])
            _ = factory.Formatter().joinVoices([voice]).formatToStave([voice], stave: stave)
            try factory.draw()
        }
    }

    private var isEnabled: Bool {
        ProcessInfo.processInfo.environment[Self.enableEnvKey] == "1"
    }

    private var configuredFonts: [String] {
        guard let raw = ProcessInfo.processInfo.environment[Self.fontsEnvKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return defaultFonts
        }
        let parsed = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parsed.isEmpty ? defaultFonts : parsed
    }

    private func runSVGParityCase(
        module: String,
        test: String,
        width: Double,
        height: Double,
        draw: (Factory) throws -> Void
    ) throws {
        guard isEnabled else { return }

        for font in configuredFonts {
            try Flow.withRuntimeContext(Flow.makeRuntimeContext()) {
                FontLoader.loadDefaultFonts()
                try applyUpstreamFontStack(fontName: font)

                let context = SVGRenderContext(
                    width: width,
                    height: height,
                    options: SVGRenderOptions(precision: 3)
                )
                let factory = Factory(options: FactoryOptions(width: width, height: height))
                _ = factory.setContext(context)

                try draw(factory)

                let expectedURL = expectedSVGURL(module: module, test: test, font: font)
                guard FileManager.default.fileExists(atPath: expectedURL.path) else {
                    Issue.record("Missing upstream reference: \(expectedURL.path)")
                    return
                }

                let actualSVG = context.getSVG()
                let expectedSVG = try String(contentsOf: expectedURL, encoding: .utf8)
                let actualSignature = drawingSignature(svg: actualSVG)
                let expectedSignature = drawingSignature(svg: expectedSVG)

                if actualSignature != expectedSignature {
                    let artifacts = try writeMismatchArtifacts(
                        module: module,
                        test: test,
                        font: font,
                        actualSVG: actualSVG,
                        expectedSVG: expectedSVG,
                        actualSignature: actualSignature,
                        expectedSignature: expectedSignature
                    )
                    Issue.record(
                        """
                        Upstream SVG mismatch for \(module).\(test).\(font)
                        Expected: \(expectedURL.path)
                        Actual artifact: \(artifacts.actualSVG.path)
                        Expected artifact: \(artifacts.expectedSVG.path)
                        """
                    )
                }
            }
        }
    }

    private func applyUpstreamFontStack(fontName: String) throws {
        switch fontName {
        case "Bravura":
            _ = try Flow.setMusicFont(parsing: ["Bravura", "Custom"])
        case "Gonville":
            _ = try Flow.setMusicFont(parsing: ["Gonville", "Bravura", "Custom"])
        case "Petaluma":
            _ = try Flow.setMusicFont(parsing: ["Petaluma", "Gonville", "Bravura", "Custom"])
        case "Leland":
            _ = try Flow.setMusicFont(parsing: ["Leland", "Bravura", "Custom"])
        default:
            throw UpstreamSVGParityError.unsupportedFont(fontName)
        }
    }

    private func expectedSVGURL(module: String, test: String, font: String) -> URL {
        let fileName = "pptr-\(module).\(test).\(font).svg"
        return referenceSVGDirectory().appendingPathComponent(fileName)
    }

    private func referenceSVGDirectory() -> URL {
        if let explicit = ProcessInfo.processInfo.environment[Self.referenceDirEnvKey],
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true).standardizedFileURL
        }

        let root = packageRoot()
        let candidates = [
            root.appendingPathComponent("../vexmotion/build/images/reference", isDirectory: true).standardizedFileURL,
            root.appendingPathComponent("../vexflow/build/images/reference", isDirectory: true).standardizedFileURL,
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return candidates[1]
    }

    private func packageRoot() -> URL {
        let here = URL(fileURLWithPath: #filePath)
        return here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func artifactsDirectory() -> URL {
        if let explicit = ProcessInfo.processInfo.environment[Self.artifactsDirEnvKey],
           !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: explicit, isDirectory: true).standardizedFileURL
        }
        return packageRoot()
            .appendingPathComponent(".build/upstream-svg-parity/artifacts", isDirectory: true)
            .standardizedFileURL
    }

    private func writeMismatchArtifacts(
        module: String,
        test: String,
        font: String,
        actualSVG: String,
        expectedSVG: String,
        actualSignature: String,
        expectedSignature: String
    ) throws -> (actualSVG: URL, expectedSVG: URL) {
        let dir = artifactsDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let base = "pptr-\(module).\(test).\(font)"
        let actualSVGURL = dir.appendingPathComponent("\(base).actual.svg")
        let expectedSVGURL = dir.appendingPathComponent("\(base).expected.svg")
        let actualSignatureURL = dir.appendingPathComponent("\(base).actual.signature.txt")
        let expectedSignatureURL = dir.appendingPathComponent("\(base).expected.signature.txt")

        try actualSVG.write(to: actualSVGURL, atomically: true, encoding: .utf8)
        try expectedSVG.write(to: expectedSVGURL, atomically: true, encoding: .utf8)
        try actualSignature.write(to: actualSignatureURL, atomically: true, encoding: .utf8)
        try expectedSignature.write(to: expectedSignatureURL, atomically: true, encoding: .utf8)
        return (actualSVG: actualSVGURL, expectedSVG: expectedSVGURL)
    }

    private func drawingSignature(svg: String) -> String {
        let tagPattern = #"<(path|rect|circle|ellipse|line|polygon|polyline)\b[^>]*>"#
        let regex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive])
        guard let regex else { return normalizedSVGText(svg) }

        let nsRange = NSRange(svg.startIndex..<svg.endIndex, in: svg)
        let matches = regex.matches(in: svg, options: [], range: nsRange)
        guard !matches.isEmpty else { return normalizedSVGText(svg) }

        var rows: [String] = []
        for match in matches {
            guard
                let wholeRange = Range(match.range(at: 0), in: svg),
                let tagRange = Range(match.range(at: 1), in: svg)
            else { continue }

            let tag = String(svg[wholeRange])
            let tagName = String(svg[tagRange]).lowercased()
            let attrs = parseAttributes(in: tag)
            switch tagName {
            case "path":
                rows.append("path:d=\(canonicalizePathData(attrs["d"] ?? ""))")
            case "rect":
                rows.append(
                    "rect:x=\(canonicalizeNumericToken(attrs["x"] ?? "0"))" +
                    ",y=\(canonicalizeNumericToken(attrs["y"] ?? "0"))" +
                    ",w=\(canonicalizeNumericToken(attrs["width"] ?? "0"))" +
                    ",h=\(canonicalizeNumericToken(attrs["height"] ?? "0"))"
                )
            case "circle":
                rows.append(
                    "circle:cx=\(canonicalizeNumericToken(attrs["cx"] ?? "0"))" +
                    ",cy=\(canonicalizeNumericToken(attrs["cy"] ?? "0"))" +
                    ",r=\(canonicalizeNumericToken(attrs["r"] ?? "0"))"
                )
            case "ellipse":
                rows.append(
                    "ellipse:cx=\(canonicalizeNumericToken(attrs["cx"] ?? "0"))" +
                    ",cy=\(canonicalizeNumericToken(attrs["cy"] ?? "0"))" +
                    ",rx=\(canonicalizeNumericToken(attrs["rx"] ?? "0"))" +
                    ",ry=\(canonicalizeNumericToken(attrs["ry"] ?? "0"))"
                )
            case "line":
                rows.append(
                    "line:x1=\(canonicalizeNumericToken(attrs["x1"] ?? "0"))" +
                    ",y1=\(canonicalizeNumericToken(attrs["y1"] ?? "0"))" +
                    ",x2=\(canonicalizeNumericToken(attrs["x2"] ?? "0"))" +
                    ",y2=\(canonicalizeNumericToken(attrs["y2"] ?? "0"))"
                )
            case "polygon", "polyline":
                rows.append("\(tagName):points=\(canonicalizeNumericList(attrs["points"] ?? ""))")
            default:
                break
            }
        }

        return rows.joined(separator: "\n")
    }

    private func parseAttributes(in tag: String) -> [String: String] {
        let attrPattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: attrPattern) else { return [:] }
        let nsRange = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        let matches = regex.matches(in: tag, options: [], range: nsRange)
        var result: [String: String] = [:]
        for match in matches {
            guard
                let keyRange = Range(match.range(at: 1), in: tag),
                let valueRange = Range(match.range(at: 2), in: tag)
            else { continue }
            result[String(tag[keyRange])] = String(tag[valueRange])
        }
        return result
    }

    private func canonicalizePathData(_ pathData: String) -> String {
        let tokenPattern = #"[A-Za-z]|[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
            return pathData.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let nsRange = NSRange(pathData.startIndex..<pathData.endIndex, in: pathData)
        let matches = regex.matches(in: pathData, options: [], range: nsRange)
        let tokens: [String] = matches.compactMap { match in
            guard let range = Range(match.range, in: pathData) else { return nil }
            let token = String(pathData[range])
            if token.count == 1, let scalar = token.unicodeScalars.first, CharacterSet.letters.contains(scalar) {
                return token.uppercased()
            }
            return canonicalizeNumericToken(token)
        }
        return tokens.joined(separator: " ")
    }

    private func canonicalizeNumericList(_ value: String) -> String {
        let tokenPattern = #"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"#
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return value }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, options: [], range: nsRange)
        let tokens: [String] = matches.compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return canonicalizeNumericToken(String(value[range]))
        }
        return tokens.joined(separator: " ")
    }

    private func canonicalizeNumericToken(_ token: String) -> String {
        guard let value = Double(token) else {
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let rounded = (value * 1000).rounded() / 1000
        if abs(rounded.rounded() - rounded) < 0.000_000_1 {
            return String(Int(rounded.rounded()))
        }

        var text = String(format: "%.3f", rounded)
        while text.contains("."), text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        return text
    }

    private func normalizedSVGText(_ svg: String) -> String {
        var text = svg.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #" id="[^"]*""#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
