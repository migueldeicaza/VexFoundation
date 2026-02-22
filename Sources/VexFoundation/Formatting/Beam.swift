// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Partial Beam Direction

public enum BeamError: Error, LocalizedError, Equatable, Sendable {
    case tooFewNotes
    case notesNotShorterThanQuarter
    case nonMetricalTimeSignature(String)

    public var errorDescription: String? {
        switch self {
        case .tooFewNotes:
            return "Too few notes for beam."
        case .notesNotShorterThanQuarter:
            return "Beams can only be applied to notes shorter than a quarter note."
        case .nonMetricalTimeSignature(let raw):
            return "Cannot derive beam groups from \(raw)."
        }
    }
}

public enum PartialBeamDirection: String {
    case left = "L"
    case right = "R"
    case both = "B"
}

// MARK: - Beam Render Options

public struct BeamRenderOptions {
    public var beamWidth: Double = 5
    public var maxSlope: Double = 0.25
    public var minSlope: Double = -0.25
    public var slopeIterations: Int = 20
    public var slopeCost: Double = 100
    public var showStemlets: Bool = false
    public var stemletExtension: Double = 7
    public var partialBeamLength: Double = 10
    public var flatBeams: Bool = false
    public var flatBeamOffset: Double?
    public var minFlatBeamOffset: Double = 15
    public var secondaryBreakTicks: Double?
}

// MARK: - Beam Config

public struct BeamConfig {
    public var groups: [Fraction]?
    public var stemDirection: StemDirection?
    public var beamRests: Bool = false
    public var beamMiddleOnly: Bool = false
    public var showStemlets: Bool = false
    public var maintainStemDirections: Bool = false
    public var flatBeams: Bool = false
    public var flatBeamOffset: Double?
    public var secondaryBreaks: String?

    public init(
        groups: [Fraction]? = nil,
        stemDirection: StemDirection? = nil,
        beamRests: Bool = false,
        beamMiddleOnly: Bool = false,
        showStemlets: Bool = false,
        maintainStemDirections: Bool = false,
        flatBeams: Bool = false,
        flatBeamOffset: Double? = nil,
        secondaryBreaks: String? = nil
    ) {
        self.groups = groups
        self.stemDirection = stemDirection
        self.beamRests = beamRests
        self.beamMiddleOnly = beamMiddleOnly
        self.showStemlets = showStemlets
        self.maintainStemDirections = maintainStemDirections
        self.flatBeams = flatBeams
        self.flatBeamOffset = flatBeamOffset
        self.secondaryBreaks = secondaryBreaks
    }
}

// MARK: - Helper Functions

private func calculateStemDirection(_ notes: [StemmableNote]) -> StemDirection {
    var lineSum: Double = 0
    for note in notes {
        for prop in note.keyProps {
            lineSum += prop.line - 3
        }
    }
    return lineSum >= 0 ? .down : .up
}

private func getStemSlope(_ firstNote: StemmableNote, _ lastNote: StemmableNote) -> Double {
    let firstStemTipY = firstNote.getStemExtents().topY
    let firstStemX = firstNote.getStemX()
    let lastStemTipY = lastNote.getStemExtents().topY
    let lastStemX = lastNote.getStemX()
    guard lastStemX != firstStemX else { return 0 }
    return (lastStemTipY - firstStemTipY) / (lastStemX - firstStemX)
}

// MARK: - Beam

/// Beams span over a set of StemmableNotes, connecting their stems.
public final class Beam: VexElement {

    // MARK: - Properties

    public var notes: [StemmableNote]
    public var postFormatted: Bool = false
    public var slope: Double = 0
    public var renderOptions = BeamRenderOptions()

    private let stemDirection: StemDirection
    private let ticks: Double
    private var yShift: Double = 0
    private var breakOnIndices: [Int] = []
    private var beamCount: Int
    private var unbeamable: Bool = false
    private var forcedPartialDirections: [Int: PartialBeamDirection] = [:]

    // MARK: - Init

    public init(_ notes: [StemmableNote], autoStem: Bool = false) throws {
        guard notes.count >= 2 else {
            throw BeamError.tooFewNotes
        }

        self.ticks = notes[0].getIntrinsicTicks()

        if let quarterTicks = Tables.durationToTicks("4"), ticks >= Double(quarterTicks) {
            throw BeamError.notesNotShorterThanQuarter
        }

        self.notes = notes
        self.stemDirection = notes[0].getStemDirection()
        self.beamCount = notes.reduce(0) { max($0, $1.getGlyphProps().beamCount) }

        var direction = self.stemDirection
        if autoStem {
            direction = calculateStemDirection(notes)
        }

        super.init()

        // Apply stem directions and attach beam
        for note in notes {
            if autoStem {
                _ = note.setStemDirection(direction)
            }
            _ = note.setBeam(self)
        }
    }

    // MARK: - Accessors

    public func getStemDirection() -> StemDirection { stemDirection }
    public func getNotes() -> [StemmableNote] { notes }

    public func getBeamCount() -> Int {
        notes.reduce(0) { max($0, $1.getGlyphProps().beamCount) }
    }

    @discardableResult
    public func breakSecondaryAt(_ indices: [Int]) -> Self {
        breakOnIndices = indices
        return self
    }

    @discardableResult
    public func setPartialBeamSideAt(_ noteIndex: Int, side: PartialBeamDirection) -> Self {
        forcedPartialDirections[noteIndex] = side
        return self
    }

    @discardableResult
    public func unsetPartialBeamSideAt(_ noteIndex: Int) -> Self {
        forcedPartialDirections.removeValue(forKey: noteIndex)
        return self
    }

    // MARK: - Slope Calculation

    func getSlopeY(_ x: Double, _ firstX: Double, _ firstY: Double, _ slope: Double) -> Double {
        firstY + (x - firstX) * slope
    }

    func calculateSlope() {
        let firstNote = notes[0]
        let initialSlope = getStemSlope(firstNote, notes[notes.count - 1])
        let increment = (renderOptions.maxSlope - renderOptions.minSlope) / Double(renderOptions.slopeIterations)
        var minCost = Double.greatestFiniteMagnitude
        var bestSlope: Double = 0
        var bestYShift: Double = 0

        var slope = renderOptions.minSlope
        while slope <= renderOptions.maxSlope {
            var totalStemExtension: Double = 0
            var yShiftTemp: Double = 0

            for i in 1..<notes.count {
                let note = notes[i]
                if note.hasStem() || note.isRest() {
                    let adjustedStemTipY = getSlopeY(
                        note.getStemX(), firstNote.getStemX(),
                        firstNote.getStemExtents().topY, slope
                    ) + yShiftTemp

                    let stemTipY = note.getStemExtents().topY

                    if stemTipY * stemDirection.signDouble < adjustedStemTipY * stemDirection.signDouble {
                        let diff = abs(stemTipY - adjustedStemTipY)
                        yShiftTemp += diff * -stemDirection.signDouble
                        totalStemExtension += diff * Double(i)
                    } else {
                        totalStemExtension += (stemTipY - adjustedStemTipY) * stemDirection.signDouble
                    }
                }
            }

            let idealSlope = initialSlope / 2
            let distanceFromIdeal = abs(idealSlope - slope)
            let cost = renderOptions.slopeCost * distanceFromIdeal + abs(totalStemExtension)

            if cost < minCost {
                minCost = cost
                bestSlope = slope
                bestYShift = yShiftTemp
            }
            slope += increment
        }

        self.slope = bestSlope
        self.yShift = bestYShift
    }

    func calculateFlatSlope() {
        var total: Double = 0
        var extremeY: Double = 0
        var extremeBeamCount = 0
        var currentExtreme: Double = 0

        for note in notes {
            let stemTipY = note.getStemExtents().topY
            total += stemTipY

            if stemDirection == Stem.DOWN && currentExtreme < stemTipY {
                currentExtreme = stemTipY
                extremeY = note.getYs().max() ?? 0
                extremeBeamCount = note.getBeamCount()
            } else if stemDirection == Stem.UP && (currentExtreme == 0 || currentExtreme > stemTipY) {
                currentExtreme = stemTipY
                extremeY = note.getYs().min() ?? 0
                extremeBeamCount = note.getBeamCount()
            }
        }

        var offset = total / Double(notes.count)
        let beamWidth = renderOptions.beamWidth * 1.5
        let extremeTest = renderOptions.minFlatBeamOffset + Double(extremeBeamCount) * beamWidth
        let newOffset = extremeY + extremeTest * -stemDirection.signDouble

        if stemDirection == Stem.DOWN && offset < newOffset {
            offset = extremeY + extremeTest
        } else if stemDirection == Stem.UP && offset > newOffset {
            offset = extremeY - extremeTest
        }

        if renderOptions.flatBeamOffset == nil {
            renderOptions.flatBeamOffset = offset
        } else if stemDirection == Stem.DOWN && offset > (renderOptions.flatBeamOffset ?? 0) {
            renderOptions.flatBeamOffset = offset
        } else if stemDirection == Stem.UP && offset < (renderOptions.flatBeamOffset ?? 0) {
            renderOptions.flatBeamOffset = offset
        }

        slope = 0
        yShift = 0
    }

    // MARK: - Beam Y

    func getBeamYToDraw() -> Double {
        let firstStemTipY = notes[0].getStemExtents().topY
        var beamY = firstStemTipY

        if renderOptions.flatBeams, let offset = renderOptions.flatBeamOffset {
            beamY = offset
        }
        return beamY
    }

    // MARK: - Stem Extensions

    func applyStemExtensions() {
        let firstNote = notes[0]
        let firstStemTipY = getBeamYToDraw()
        let firstStemX = firstNote.getStemX()

        for note in notes {
            guard let stem = note.getStem() else { continue }
            let stemX = note.getStemX()
            let stemTipY = note.getStemExtents().topY
            let beamedStemTipY = getSlopeY(stemX, firstStemX, firstStemTipY, slope) + yShift
            let preBeamExtension = stem.getExtension()
            let beamExtension = note.getStemDirection() == Stem.UP
                ? stemTipY - beamedStemTipY
                : beamedStemTipY - stemTipY

            var crossStemExtension: Double = 0
            if note.getStemDirection() != stemDirection {
                let noteBeamCount = note.getGlyphProps().beamCount
                crossStemExtension = (1 + Double(noteBeamCount - 1) * 1.5) * renderOptions.beamWidth
            }

            stem.setExtension(preBeamExtension + beamExtension + crossStemExtension)
            stem.adjustHeightForBeam()

            if note.isRest() && renderOptions.showStemlets {
                let totalBeamWidth = Double(beamCount - 1) * renderOptions.beamWidth * 1.5 + renderOptions.beamWidth
                _ = stem.setVisibility(true).setStemlet(true, height: totalBeamWidth + renderOptions.stemletExtension)
            }
        }
    }

    // MARK: - Beam Direction Lookup

    func lookupBeamDirection(
        _ duration: String,
        prevTick: Double,
        tick: Double,
        nextTick: Double,
        noteIndex: Int
    ) -> PartialBeamDirection {
        if duration == "4" { return .left }

        if let forced = forcedPartialDirections[noteIndex] { return forced }

        let lookupDur = "\(Tables.durationToNumber(duration) / 2)"
        guard let lookupTicks = Tables.durationToTicks(lookupDur) else { return .left }
        let lookupTicksD = Double(lookupTicks)

        let prevGetsBeam = prevTick < lookupTicksD
        let nextGetsBeam = nextTick < lookupTicksD
        let noteGetsBeam = tick < lookupTicksD

        if prevGetsBeam && nextGetsBeam && noteGetsBeam { return .both }
        if prevGetsBeam && !nextGetsBeam && noteGetsBeam { return .left }
        if !prevGetsBeam && nextGetsBeam && noteGetsBeam { return .right }

        return lookupBeamDirection(lookupDur, prevTick: prevTick, tick: tick, nextTick: nextTick, noteIndex: noteIndex)
    }

    // MARK: - Beam Lines

    struct BeamLine {
        var start: Double
        var end: Double?
    }

    func getBeamLines(_ duration: String) -> [BeamLine] {
        guard let tickOfDuration = Tables.durationToTicks(duration) else { return [] }
        let tickOfDurationD = Double(tickOfDuration)
        var beamStarted = false
        var beamLines: [BeamLine] = []
        var previousShouldBreak = false
        var tickTally: Double = 0

        for i in 0..<notes.count {
            let note = notes[i]
            let ticks = note.getTicks().value()
            tickTally += ticks
            var shouldBreak = false

            if let durNum = Int(duration), durNum >= 8 {
                shouldBreak = breakOnIndices.contains(i)
                if let secondaryBreakTicks = renderOptions.secondaryBreakTicks,
                   tickTally >= secondaryBreakTicks {
                    tickTally = 0
                    shouldBreak = true
                }
            }

            let noteGetsBeam = note.getIntrinsicTicks() < tickOfDurationD
            let stemX = note.getStemX() - Stem.WIDTH / 2

            let prevNote: StemmableNote? = i > 0 ? notes[i - 1] : nil
            let nextNote: StemmableNote? = i + 1 < notes.count ? notes[i + 1] : nil
            let nextNoteGetsBeam = nextNote.map { $0.getIntrinsicTicks() < tickOfDurationD } ?? false
            let prevNoteGetsBeam = prevNote.map { $0.getIntrinsicTicks() < tickOfDurationD } ?? false
            let beamAlone = prevNote != nil && nextNote != nil && noteGetsBeam && !prevNoteGetsBeam && !nextNoteGetsBeam

            if noteGetsBeam {
                if beamStarted {
                    // Continue existing beam
                    beamLines[beamLines.count - 1].end = stemX

                    if shouldBreak {
                        beamStarted = false
                    }
                } else {
                    // Start new beam
                    var newBeam = BeamLine(start: stemX, end: nil)
                    beamStarted = true

                    if beamAlone {
                        let prevTick = prevNote!.getIntrinsicTicks()
                        let nextTick = nextNote!.getIntrinsicTicks()
                        let tick = note.getIntrinsicTicks()
                        let direction = lookupBeamDirection(duration, prevTick: prevTick, tick: tick, nextTick: nextTick, noteIndex: i)

                        if direction == .left || direction == .both {
                            newBeam.end = newBeam.start - renderOptions.partialBeamLength
                        } else {
                            newBeam.end = newBeam.start + renderOptions.partialBeamLength
                        }
                    } else if !nextNoteGetsBeam {
                        if (previousShouldBreak || i == 0) && nextNote != nil {
                            newBeam.end = newBeam.start + renderOptions.partialBeamLength
                        } else {
                            newBeam.end = newBeam.start - renderOptions.partialBeamLength
                        }
                    } else if shouldBreak {
                        newBeam.end = newBeam.start - renderOptions.partialBeamLength
                        beamStarted = false
                    }

                    beamLines.append(newBeam)
                }
            } else {
                beamStarted = false
            }

            previousShouldBreak = shouldBreak
        }

        // Add partial beam for last note if needed
        if let lastIdx = beamLines.indices.last, beamLines[lastIdx].end == nil {
            beamLines[lastIdx].end = beamLines[lastIdx].start - renderOptions.partialBeamLength
        }

        return beamLines
    }

    // MARK: - PostFormat

    public func postFormat() {
        if postFormatted { return }

        if renderOptions.flatBeams {
            calculateFlatSlope()
        } else {
            calculateSlope()
        }
        applyStemExtensions()

        postFormatted = true
    }

    // MARK: - Draw

    func drawStems(_ ctx: RenderContext) {
        for note in notes {
            if let stem = note.getStem() {
                let stemX = note.getStemX()
                stem.setNoteHeadXBounds(stemX, stemX)
                stem.setContext(ctx)
                try? stem.draw()
            }
        }
    }

    func drawBeamLines(_ ctx: RenderContext) {
        let validDurations = ["4", "8", "16", "32", "64"]
        let firstStemX = notes[0].getStemX()
        var beamY = getBeamYToDraw()
        let beamThickness = renderOptions.beamWidth * stemDirection.signDouble

        for duration in validDurations {
            let beamLines = getBeamLines(duration)

            for beamLine in beamLines {
                let startX = beamLine.start
                let startY = getSlopeY(startX, firstStemX, beamY, slope)

                if let endX = beamLine.end {
                    let endY = getSlopeY(endX, firstStemX, beamY, slope)

                    ctx.beginPath()
                    ctx.moveTo(startX, startY)
                    ctx.lineTo(startX, startY + beamThickness)
                    ctx.lineTo(endX + 1, endY + beamThickness)
                    ctx.lineTo(endX + 1, endY)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            beamY += beamThickness * 1.5
        }
    }

    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        if unbeamable { return }

        if !postFormatted {
            postFormat()
        }

        drawStems(ctx)
        _ = ctx.openGroup("beam", getAttribute("id"))
        drawBeamLines(ctx)
        ctx.closeGroup()
    }

    // MARK: - Static Helpers

    /// Get default beam groups for a time signature.
    public static func getDefaultBeamGroups(_ timeSignature: TimeSignatureSpec) throws -> [Fraction] {
        guard let meter = timeSignature.meter else {
            throw BeamError.nonMetricalTimeSignature(timeSignature.rawValue)
        }

        let sig = meter.rawValue
        let defaults: [String: [String]] = [
            "1/2": ["1/2"], "2/2": ["1/2"], "3/2": ["1/2"], "4/2": ["1/2"],
            "1/4": ["1/4"], "2/4": ["1/4"], "3/4": ["1/4"], "4/4": ["1/4"],
            "1/8": ["1/8"], "2/8": ["2/8"], "3/8": ["3/8"], "4/8": ["2/8"],
            "1/16": ["1/16"], "2/16": ["2/16"], "3/16": ["3/16"], "4/16": ["2/16"],
        ]

        if let groups = defaults[sig] {
            return groups.map { Fraction().parse($0) }
        }

        if meter.numerator % 3 == 0 {
            return [Fraction(3, meter.denominator)]
        } else if meter.denominator > 4 {
            return [Fraction(2, meter.denominator)]
        } else {
            return [Fraction(1, meter.denominator)]
        }
    }

    /// Generate beams for an array of notes with configuration.
    public static func generateBeams(
        _ notes: [StemmableNote],
        config: BeamConfig = BeamConfig()
    ) throws -> [Beam] {
        let groups = config.groups ?? [Fraction(2, 8)]

        // Convert beat groups to ticks
        let tickGroups = groups.map { group -> Fraction in
            group.clone().multiply(Tables.RESOLUTION, 1)
        }

        var currentTickGroup = 0
        var noteGroups: [[StemmableNote]] = []
        var currentGroup: [StemmableNote] = []

        func getTotalTicks(_ vfNotes: [StemmableNote]) -> Fraction {
            vfNotes.reduce(Fraction(0, 1)) { memo, note in
                note.getTicks().clone().add(memo)
            }
        }

        func nextTickGroup() {
            if tickGroups.count - 1 > currentTickGroup {
                currentTickGroup += 1
            } else {
                currentTickGroup = 0
            }
        }

        // Create groups
        var currentGroupTotalTicks = Fraction(0, 1)
        for note in notes {
            if note.shouldIgnoreTicks() {
                noteGroups.append(currentGroup)
                currentGroup = []
                continue
            }

            currentGroup.append(note)
            let ticksPerGroup = tickGroups[currentTickGroup].clone()
            let totalTicks = getTotalTicks(currentGroup).add(currentGroupTotalTicks)

            let unbeamable = Tables.durationToNumber(note.getDuration()) < 8
            if unbeamable, note.getTuplet() != nil {
                ticksPerGroup.numerator *= 2
            }

            if totalTicks > ticksPerGroup {
                if !unbeamable {
                    if let last = currentGroup.popLast() {
                        noteGroups.append(currentGroup)
                        currentGroup = [last]
                    }
                } else {
                    noteGroups.append(currentGroup)
                    currentGroup = []
                }
                // Advance tick groups
                repeat {
                    currentGroupTotalTicks = totalTicks.subtract(tickGroups[currentTickGroup])
                    nextTickGroup()
                } while currentGroupTotalTicks >= tickGroups[currentTickGroup]
            } else if totalTicks == ticksPerGroup {
                noteGroups.append(currentGroup)
                currentGroupTotalTicks = Fraction(0, 1)
                currentGroup = []
                nextTickGroup()
            }
        }
        if !currentGroup.isEmpty {
            noteGroups.append(currentGroup)
        }

        // Sanitize groups (break on rests, stem changes, unbeamable durations)
        var sanitizedGroups: [[StemmableNote]] = []
        for group in noteGroups {
            var tempGroup: [StemmableNote] = []
            for (index, note) in group.enumerated() {
                let isFirstOrLast = index == 0 || index == group.count - 1

                let breaksOnEachRest = !config.beamRests && note.isRest()
                let breaksOnFirstOrLastRest = config.beamRests && config.beamMiddleOnly && note.isRest() && isFirstOrLast

                var breakOnStemChange = false
                if config.maintainStemDirections && index > 0 && !note.isRest() && !group[index - 1].isRest() {
                    breakOnStemChange = note.getStemDirection() != group[index - 1].getStemDirection()
                }

                let isUnbeamableDuration = (Int(note.getDuration()) ?? 0) < 8

                let shouldBreak = breaksOnEachRest || breaksOnFirstOrLastRest || breakOnStemChange || isUnbeamableDuration

                if shouldBreak {
                    if !tempGroup.isEmpty {
                        sanitizedGroups.append(tempGroup)
                    }
                    tempGroup = breakOnStemChange ? [note] : []
                } else {
                    tempGroup.append(note)
                }
            }
            if !tempGroup.isEmpty {
                sanitizedGroups.append(tempGroup)
            }
        }
        noteGroups = sanitizedGroups

        // Format stems
        for group in noteGroups {
            let direction: StemDirection
            if config.maintainStemDirections {
                direction = group.first(where: { !$0.isRest() })?.getStemDirection() ?? Stem.UP
            } else if let configDir = config.stemDirection {
                direction = configDir
            } else {
                direction = calculateStemDirection(group)
            }
            for note in group {
                _ = note.setStemDirection(direction)
            }
        }

        // Filter beamable groups (count > 1, all notes shorter than quarter)
        let quarterTicks = Double(Tables.durationToTicks("4") ?? 4096)
        let beamedGroups = noteGroups.filter { group in
            guard group.count > 1 else { return false }
            return group.allSatisfy { $0.getIntrinsicTicks() < quarterTicks }
        }

        // Collect tuplets in group order so we can normalize location/bracketing
        // once beam ownership is finalized.
        var allTuplets: [Tuplet] = []
        for group in noteGroups {
            var tuplet: Tuplet?
            for note in group {
                let noteTuplet = note.getTuplet()
                if let noteTuplet, tuplet !== noteTuplet {
                    tuplet = noteTuplet
                    allTuplets.append(noteTuplet)
                }
            }
        }

        // Create Beam objects
        var beams: [Beam] = []
        for group in beamedGroups {
            let beam = try Beam(group)
            if config.showStemlets {
                beam.renderOptions.showStemlets = true
            }
            if let secondaryBreaks = config.secondaryBreaks,
               let breakTicks = Tables.durationToTicks(secondaryBreaks) {
                beam.renderOptions.secondaryBreakTicks = Double(breakTicks)
            }
            if config.flatBeams {
                beam.renderOptions.flatBeams = true
                beam.renderOptions.flatBeamOffset = config.flatBeamOffset
            }
            beams.append(beam)
        }

        // Reformat tuplets after beams have been attached to notes.
        for tuplet in allTuplets {
            if let first = tuplet.notes.first as? StemmableNote {
                let location: TupletLocation = first.getStemDirection() == Stem.DOWN ? .bottom : .top
                _ = tuplet.setTupletLocation(location)
            }

            var bracketed = false
            for note in tuplet.notes where !note.hasBeam() {
                bracketed = true
                break
            }
            _ = tuplet.setBracketed(bracketed)
        }

        return beams
    }

    /// Convenience: build beams for a voice.
    public static func applyAndGetBeams(
        _ voice: Voice,
        stemDirection: StemDirection? = nil,
        groups: [Fraction]? = nil
    ) throws -> [Beam] {
        let notes = voice.getTickables().compactMap { $0 as? StemmableNote }
        return try generateBeams(notes, config: BeamConfig(groups: groups, stemDirection: stemDirection))
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Beam", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()
        FontLoader.loadDefaultFonts()

        let f = Factory(options: FactoryOptions(width: 500))
        _ = f.setContext(ctx)
        let score = f.EasyScore()

        let system = f.System(options: SystemOptions(factory: f, x: 10, width: 500, y: 10))
        let notes = score.notes("C5/8, D5, E5, F5, G5, A5, B5, C6")
        _ = score.beam(Array(notes[0..<4]))
        _ = score.beam(Array(notes[4..<8]))
        _ = system.addStave(SystemStave(
            voices: [score.voice(notes)]
        )).addClef(.treble).addTimeSignature(.meter(4, 4))

        system.format()
        try? f.draw()
    }
    .padding()
}
#endif
