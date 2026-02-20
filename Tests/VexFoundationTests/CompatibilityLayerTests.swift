// VexFoundation - Tests for Phase 4.1 compatibility facade (`Flow` / `Vex` / version metadata).

import Testing
@testable import VexFoundation

@Suite("Compatibility Layer")
struct CompatibilityLayerTests {

    init() {
        FontLoader.loadDefaultFonts()
    }

    @Test func flowExposesBuildMetadataAndCoreConstants() {
        let build = Flow.BUILD

        #expect(!build.version.isEmpty)
        #expect(!build.gitCommitID.isEmpty)
        #expect(!build.buildDate.isEmpty)

        #expect(build.version == Version.VERSION)
        #expect(build.gitCommitID == Version.ID)
        #expect(build.buildDate == Version.DATE)

        #expect(Flow.RESOLUTION == Tables.RESOLUTION)
        #expect(Flow.RENDER_PRECISION_PLACES == Tables.RENDER_PRECISION_PLACES)
    }

    @Test func flowDurationAndKeySignatureHelpers() throws {
        #expect(Flow.durationToTicks(.quarter) == Tables.RESOLUTION / 4)
        #expect(try Flow.durationToTicks("4") == Tables.RESOLUTION / 4)
        #expect(try Flow.durationToTicks("8d") == (Tables.RESOLUTION / 8) + (Tables.RESOLUTION / 16))
        #expect(Flow.durationToTicksOrNil("8dd") != nil)

        #expect(Flow.hasKeySignature("D"))
        let dMajor = try Flow.keySignature("D")
        #expect(dMajor.count == 2)
    }

    @Test func flowMusicFontTypedAndStringConvenience() throws {
        let typedFonts = Flow.setMusicFont(.petaluma, .custom)
        #expect(typedFonts.map(\.name) == ["Petaluma", "Custom"])
        #expect(Flow.getMusicFont() == ["Petaluma", "Custom"])

        let parsedFonts = try Flow.setMusicFont(parsing: ["Bravura", "Custom"])
        #expect(parsedFonts.map(\.name) == ["Bravura", "Custom"])
        #expect(Flow.getMusicFont() == ["Bravura", "Custom"])

        let maybeFonts = Flow.setMusicFont(parsingOrNil: ["Gonville", "Custom"])
        #expect(maybeFonts?.map(\.name) == ["Gonville", "Custom"])
        #expect(Flow.setMusicFont(parsingOrNil: ["UnknownFont"]) == nil)
    }

    @Test func vexUtilityHelpersSmokeTest() {
        let unique = Vex.sortAndUnique([3, 1, 2, 2, 1], sortedBy: <, equalBy: ==)
        #expect(unique == [1, 2, 3])

        #expect(Vex.contains(unique, 2))
        #expect(!Vex.contains(unique, 4))

        let stackTrace = Vex.stackTrace()
        #expect(!stackTrace.isEmpty)

        let benchmark = Vex.benchmark {
            unique.reduce(0, +)
        }
        #expect(benchmark.result == 6)
        #expect(benchmark.elapsedMs >= 0)
    }
}
