import Testing
@testable import VexFoundation

@Suite("Voice, Formatter, TickContext Parity")
struct VoiceFormatterTickContextParityTests {
    private static let beat = Tables.RESOLUTION / 4

    private final class MockTickable: Tickable {
        private let mockWidth: Double

        init(ticks: Int, width: Double = 0, ignoreTicks: Bool = false) {
            self.mockWidth = width
            super.init()
            setIntrinsicTicks(Double(ticks))
            setTickableWidth(width)
            _ = setIgnoreTicks(ignoreTicks)
        }

        override func preFormat() {
            preFormatted = true
        }

        override func getMetrics() -> NoteMetrics {
            var m = NoteMetrics()
            m.width = mockWidth
            m.notePx = mockWidth
            return m
        }
    }

    @Test func voiceStrictModeTickAccountingParity() throws {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        #expect(voice.getTotalTicks().value() == Double(Self.beat * 4))
        #expect(voice.getTicksUsed().value() == 0)

        _ = try voice.addTickablesThrowing([
            MockTickable(ticks: Self.beat),
            MockTickable(ticks: Self.beat),
            MockTickable(ticks: Self.beat),
        ])
        #expect(voice.getTicksUsed().value() == Double(Self.beat * 3))

        _ = try voice.addTickableThrowing(MockTickable(ticks: Self.beat))
        #expect(voice.getTicksUsed().value() == Double(Self.beat * 4))
        #expect(voice.isComplete())

        let numeratorBeforeOverflow = voice.getTicksUsed().numerator
        do {
            _ = try voice.addTickableThrowing(MockTickable(ticks: Self.beat))
            #expect(Bool(false))
        } catch {
            #expect(error as? VoiceError == .tooManyTicks)
        }

        // Upstream parity expectation: rejected note must not mutate ticksUsed.
        #expect(voice.getTicksUsed().numerator == numeratorBeforeOverflow)
        #expect(voice.getTickables().count == 4)
        #expect(voice.getSmallestTickCount().value() == Double(Self.beat))
    }

    @Test func voiceIgnoreTicksParity() throws {
        let voice = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = try voice.addTickablesThrowing([
            MockTickable(ticks: Self.beat),
            MockTickable(ticks: Self.beat),
            MockTickable(ticks: Self.beat, ignoreTicks: true),
            MockTickable(ticks: Self.beat),
            MockTickable(ticks: Self.beat, ignoreTicks: true),
            MockTickable(ticks: Self.beat),
        ])

        #expect(voice.getTickables().count == 6)
        #expect(voice.getTicksUsed().value() == Double(Self.beat * 4))
        #expect(voice.isComplete())
    }

    @Test func tickContextTrackingParity() {
        let tickables = [
            MockTickable(ticks: Self.beat, width: 10),
            MockTickable(ticks: Self.beat * 2, width: 20),
            MockTickable(ticks: Self.beat, width: 30),
        ]

        let tc = TickContext()
        _ = tc.setPadding(0)
        #expect(tc.getCurrentTick().value() == 0)

        _ = tc.addTickable(tickables[0])
        #expect(tc.getMaxTicks().value() == Double(Self.beat))

        _ = tc.addTickable(tickables[1])
        #expect(tc.getMaxTicks().value() == Double(Self.beat * 2))

        _ = tc.addTickable(tickables[2])
        #expect(tc.getMaxTicks().value() == Double(Self.beat * 2))

        #expect(tc.getWidth() == 0)
        _ = tc.preFormat()
        #expect(tc.getWidth() == 30)
    }

    @Test func formatterTickContextBuildParity() throws {
        let voice1Tickables = [
            MockTickable(ticks: Self.beat, width: 10),
            MockTickable(ticks: Self.beat * 2, width: 20),
            MockTickable(ticks: Self.beat, width: 30),
        ]
        let voice2Tickables = [
            MockTickable(ticks: Self.beat * 2, width: 10),
            MockTickable(ticks: Self.beat, width: 20),
            MockTickable(ticks: Self.beat, width: 30),
        ]

        let voice1 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        let voice2 = Voice(time: VoiceTime(numBeats: 4, beatValue: 4))
        _ = try voice1.addTickablesThrowing(voice1Tickables)
        _ = try voice2.addTickablesThrowing(voice2Tickables)

        let formatter = Formatter()
        let contexts = formatter.createTickContexts([voice1, voice2])
        #expect(contexts.list.count == 4)

        do {
            _ = try formatter.getMinTotalWidthThrowing()
            #expect(Bool(false))
        } catch {
            #expect(error as? FormatterError == .minTotalWidthUnavailable)
        }

        let minWidth = formatter.preCalculateMinTotalWidth([voice1, voice2])
        #expect(minWidth > 0)

        _ = formatter.preFormat()

        #expect(voice1Tickables[0].getX() == voice2Tickables[0].getX())
        #expect(voice1Tickables[2].getX() == voice2Tickables[2].getX())
        #expect(voice1Tickables[1].getX() < voice2Tickables[1].getX())
    }
}
