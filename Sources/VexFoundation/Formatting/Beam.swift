// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/beam.ts` (VexFlow 5.1.0).

import Foundation

public enum BeamError: Error, LocalizedError, Equatable, Sendable {
    case noNotes
    case tooFewNotes
    case notesNotShorterThanQuarter
    case nonMetricalTimeSignature(String)
    case noLastBeamX

    public var errorDescription: String? {
        switch self {
        case .noNotes:
            return "No notes provided for beam."
        case .tooFewNotes:
            return "Too few notes for beam."
        case .notesNotShorterThanQuarter:
            return "Beams can only be applied to notes shorter than a quarter note."
        case .nonMetricalTimeSignature(let raw):
            return "Cannot derive beam groups from \(raw)."
        case .noLastBeamX:
            return "lastBeamX undefined."
        }
    }
}

// MARK: - Partial Beam Direction

public enum PartialBeamDirection: String, Sendable {
    case left = "L"
    case right = "R"
    case both = "B"
}

public let BEAM_LEFT: PartialBeamDirection = .left
public let BEAM_RIGHT: PartialBeamDirection = .right
public let BEAM_BOTH: PartialBeamDirection = .both

// MARK: - Beam Render Options

public struct BeamRenderOptions {
    public var flatBeamOffset: Double?
    public var flatBeams: Bool = false
    public var secondaryBreakTicks: Double?
    public var showStemlets: Bool = false
    public var beamWidth: Double = 5
    public var maxSlope: Double = 0.25
    public var minSlope: Double = -0.25
    public var slopeIterations: Int = 20
    public var slopeCost: Double = 100
    public var stemletExtension: Double = 7
    public var partialBeamLength: Double = 10
    public var minFlatBeamOffset: Double = 15

    public init() {}
}

// MARK: - Beam Config

/// Configuration for `Beam.generateBeams`.
public struct BeamConfig {
    /// Array of `Fraction`s that represent the beat structure to beam the notes.
    public var groups: [Fraction]?
    /// Set to apply the same direction to all notes.
    public var stemDirection: StemDirection?
    /// Set to `true` to include rests in the beams.
    public var beamRests: Bool = false
    /// Set to `true` to only beam rests in the middle of the beat.
    public var beamMiddleOnly: Bool = false
    /// Set to `true` to draw stemlets for rests.
    public var showStemlets: Bool = false
    /// Set to `true` to not apply new stem directions.
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
        for keyProp in note.keyProps {
            lineSum += keyProp.line - 3
        }
    }

    if lineSum >= 0 {
        return Stem.DOWN
    }
    return Stem.UP
}

private func getStemSlope(_ firstNote: StemmableNote, _ lastNote: StemmableNote) -> Double {
    let firstStemTipY = firstNote.getStemExtents().topY
    let firstStemX = firstNote.getStemX()
    let lastStemTipY = lastNote.getStemExtents().topY
    let lastStemX = lastNote.getStemX()
    return (lastStemTipY - firstStemTipY) / (lastStemX - firstStemX)
}

/// JavaScript `parseInt(s, 10)`: leading decimal digits (with sign), `nil` for NaN.
private func jsParseInt(_ s: String) -> Int? {
    let trimmed = s.drop(while: { $0 == " " })
    var digits = ""
    var sign = ""
    for (i, c) in trimmed.enumerated() {
        if i == 0 && (c == "-" || c == "+") {
            sign = c == "-" ? "-" : ""
            continue
        }
        guard c.isASCII, c.isNumber else { break }
        digits.append(c)
    }
    return digits.isEmpty ? nil : Int(sign + digits)
}

// MARK: - Beam

/// `Beams` span over a set of `StemmableNotes`.
public final class Beam: VexElement {

    override public class var category: String { "Beam" }

    // MARK: - Properties

    public var renderOptions = BeamRenderOptions()

    public var notes: [StemmableNote]
    public var postFormatted: Bool = false
    public var slope: Double = 0

    private var _stemDirection: StemDirection
    private let _ticks: Double

    private var breakOnIndexes: [Int] = []
    private var _beamCount: Int = 0
    // note that this is never set and is a private property.
    private var unbeamable: Bool = false

    /// Overrides to default beam directions for secondary-level beams that do not
    /// connect to any other note. See further explanation at `setPartialBeamSideAt`.
    private var forcedPartialDirections: [Int: PartialBeamDirection] = [:]

    /// Get the direction of the beam
    public func getStemDirection() -> StemDirection { _stemDirection }

    // MARK: - Default Beam Groups

    /// Get the default beam groups for a provided time signature.
    /// Attempt to guess if the time signature is not found in table.
    /// Currently this is fairly naive.
    public static func getDefaultBeamGroups(_ timeSig: String) -> [Fraction] {
        var timeSig = timeSig
        if timeSig.isEmpty || timeSig == "c" {
            timeSig = "4/4"
        }

        let defaults: [String: [String]] = [
            "1/2": ["1/2"],
            "2/2": ["1/2"],
            "3/2": ["1/2"],
            "4/2": ["1/2"],

            "1/4": ["1/4"],
            "2/4": ["1/4"],
            "3/4": ["1/4"],
            "4/4": ["1/4"],

            "1/8": ["1/8"],
            "2/8": ["2/8"],
            "3/8": ["3/8"],
            "4/8": ["2/8"],

            "1/16": ["1/16"],
            "2/16": ["2/16"],
            "3/16": ["3/16"],
            "4/16": ["2/16"],
        ]

        if let groups = defaults[timeSig] {
            return groups.map { Fraction().parse($0) }
        }

        // If no beam groups found, naively determine
        // the beam groupings from the time signature
        let parts = timeSig.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let beatTotal = jsParseInt(parts.first ?? "")
        let beatValue = jsParseInt(parts.count > 1 ? parts[1] : "")

        if let beatTotal, let beatValue {
            let tripleMeter = beatTotal % 3 == 0

            if tripleMeter {
                return [Fraction(3, beatValue)]
            } else if beatValue > 4 {
                return [Fraction(2, beatValue)]
            } else if beatValue <= 4 {
                return [Fraction(1, beatValue)]
            }
        }

        return [Fraction(1, 4)]
    }

    /// Typed variant of `getDefaultBeamGroups(_:)`. Throws for a non-metrical time signature.
    public static func getDefaultBeamGroups(_ timeSignature: TimeSignatureSpec) throws -> [Fraction] {
        guard let meter = timeSignature.meter else {
            throw BeamError.nonMetricalTimeSignature(timeSignature.rawValue)
        }
        return getDefaultBeamGroups(meter.rawValue)
    }

    // MARK: - Auto Beaming

    /// A helper function to automatically build basic beams for a voice. For more
    /// complex auto-beaming use `Beam.generateBeams()`.
    /// - Parameters:
    ///   - voice: the voice to generate the beams for
    ///   - stemDirection: a stem direction to apply to the entire voice
    ///   - groups: an array of `Fraction` representing beat groupings for the beam
    public static func applyAndGetBeams(
        _ voice: Voice,
        stemDirection: StemDirection? = nil,
        groups: [Fraction]? = nil
    ) throws -> [Beam] {
        let notes = voice.getTickables().compactMap { $0 as? StemmableNote }
        return try generateBeams(notes, config: BeamConfig(groups: groups, stemDirection: stemDirection))
    }

    /// A helper function to automatically build beams for a voice with
    /// configuration options.
    public static func generateBeams(
        _ notes: [StemmableNote],
        config: BeamConfig = BeamConfig()
    ) throws -> [Beam] {
        var config = config
        if config.groups == nil || config.groups?.isEmpty == true {
            config.groups = [Fraction(2, 8)]
        }

        // Convert beam groups to tick amounts
        let tickGroups = (config.groups ?? []).map { group -> Fraction in
            group.clone().multiply(Tables.RESOLUTION, 1)
        }

        let unprocessedNotes: [StemmableNote] = notes
        var currentTickGroup = 0
        var noteGroups: [[StemmableNote]] = []
        var currentGroup: [StemmableNote] = []

        func getTotalTicks(_ notes: [Note]) -> Fraction {
            notes.reduce(Fraction(0, 1)) { memo, note in
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

        func createGroups() {
            var nextGroup: [StemmableNote] = []
            // number of ticks in current group
            var currentGroupTotalTicks = Fraction(0, 1)
            for unprocessedNote in unprocessedNotes {
                nextGroup = []
                if unprocessedNote.shouldIgnoreTicks() {
                    noteGroups.append(currentGroup)
                    currentGroup = nextGroup
                    continue // Ignore untickables (like bar notes)
                }
                currentGroup.append(unprocessedNote)
                let ticksPerGroup = tickGroups[currentTickGroup].clone()
                let totalTicks = getTotalTicks(currentGroup).add(currentGroupTotalTicks)

                // Double the amount of ticks in a group, if it's an unbeamable tuplet
                let unbeamable = Tables.durationToNumber(unprocessedNote.getDuration()) < 8
                if unbeamable && unprocessedNote.getTuplet() != nil {
                    ticksPerGroup.numerator *= 2
                }

                // If the note that was just added overflows the group tick total
                if totalTicks.greaterThan(ticksPerGroup) {
                    // If the overflow note can be beamed, start the next group
                    // with it. Unbeamable notes leave the group overflowed.
                    if !unbeamable {
                        if let note = currentGroup.popLast() {
                            nextGroup.append(note)
                        }
                    }
                    noteGroups.append(currentGroup)

                    // We have overflown, so we're going to next tick group. As we might have
                    // overflown by more than 1 group, we need to go forward as many times as
                    // needed, decreasing currentGroupTotalTicks by as many ticks as there are
                    // in current groups as we go forward.
                    repeat {
                        currentGroupTotalTicks = totalTicks.subtract(tickGroups[currentTickGroup])
                        nextTickGroup()
                    } while currentGroupTotalTicks.greaterThanEquals(tickGroups[currentTickGroup])
                    currentGroup = nextGroup
                } else if totalTicks.equals(ticksPerGroup) {
                    noteGroups.append(currentGroup)
                    currentGroupTotalTicks = Fraction(0, 1)
                    currentGroup = nextGroup
                    nextTickGroup()
                }
            }

            // Adds any remainder notes beam
            if !currentGroup.isEmpty {
                noteGroups.append(currentGroup)
            }
        }

        func getBeamGroups() -> [[StemmableNote]] {
            let quarterTicks = Double(Tables.durationToTicks("4") ?? 0)
            return noteGroups.filter { group in
                if group.count > 1 {
                    var beamable = true
                    for note in group where note.getIntrinsicTicks() >= quarterTicks {
                        beamable = false
                    }
                    return beamable
                }
                return false
            }
        }

        // Splits up groups by Rest
        func sanitizeGroups() {
            var sanitizedGroups: [[StemmableNote]] = []
            for group in noteGroups {
                var tempGroup: [StemmableNote] = []
                for (index, note) in group.enumerated() {
                    let isFirstOrLast = index == 0 || index == group.count - 1
                    let prevNote: StemmableNote? = index > 0 ? group[index - 1] : nil

                    let breaksOnEachRest = !config.beamRests && note.isRest()
                    let breaksOnFirstOrLastRest =
                        config.beamRests && config.beamMiddleOnly && note.isRest() && isFirstOrLast

                    var breakOnStemChange = false
                    if config.maintainStemDirections, let prevNote, !note.isRest(), !prevNote.isRest() {
                        let prevDirection = prevNote.getStemDirection()
                        let currentDirection = note.getStemDirection()
                        breakOnStemChange = currentDirection != prevDirection
                    }

                    let isUnbeamableDuration = (jsParseInt(note.getDuration()).map { $0 < 8 }) ?? false

                    // Determine if the group should be broken at this note
                    let shouldBreak =
                        breaksOnEachRest || breaksOnFirstOrLastRest || breakOnStemChange || isUnbeamableDuration

                    if shouldBreak {
                        // Add current group
                        if !tempGroup.isEmpty {
                            sanitizedGroups.append(tempGroup)
                        }

                        // Start a new group. Include the current note if the group
                        // was broken up by stem direction, as that note needs to start
                        // the next group of notes
                        tempGroup = breakOnStemChange ? [note] : []
                    } else {
                        // Add note to group
                        tempGroup.append(note)
                    }
                }

                // If there is a remaining group, add it as well
                if !tempGroup.isEmpty {
                    sanitizedGroups.append(tempGroup)
                }
            }

            noteGroups = sanitizedGroups
        }

        func findFirstNote(_ group: [StemmableNote]) -> StemmableNote? {
            group.first { !$0.isRest() }
        }

        func applyStemDirection(_ group: [StemmableNote], _ direction: StemDirection) {
            for note in group {
                _ = note.setStemDirection(direction)
            }
        }

        func formatStems() {
            for group in noteGroups {
                let stemDirection: StemDirection
                if config.maintainStemDirections {
                    let note = findFirstNote(group)
                    stemDirection = note?.getStemDirection() ?? Stem.UP
                } else {
                    if let configDirection = config.stemDirection {
                        stemDirection = configDirection
                    } else {
                        stemDirection = calculateStemDirection(group)
                    }
                }
                applyStemDirection(group, stemDirection)
            }
        }

        // Get all of the tuplets in all of the note groups
        func getTuplets() -> [Tuplet] {
            var uniqueTuplets: [Tuplet] = []

            // Go through all of the note groups and inspect for tuplets
            for group in noteGroups {
                var tuplet: Tuplet?
                for note in group {
                    if let noteTuplet = note.getTuplet(), tuplet !== noteTuplet {
                        tuplet = noteTuplet
                        uniqueTuplets.append(noteTuplet)
                    }
                }
            }
            return uniqueTuplets
        }

        createGroups()
        sanitizeGroups()
        formatStems()

        // Get the notes to be beamed
        let beamedNoteGroups = getBeamGroups()

        // Get the tuplets in order to format them accurately
        let allTuplets = getTuplets()

        // Create a Beam from each group of notes to be beamed
        var beams: [Beam] = []
        for group in beamedNoteGroups {
            let beam = try Beam(group)

            if config.showStemlets {
                beam.renderOptions.showStemlets = true
            }
            if let secondaryBreaks = config.secondaryBreaks, !secondaryBreaks.isEmpty {
                beam.renderOptions.secondaryBreakTicks = Tables.durationToTicks(secondaryBreaks).map(Double.init)
            }
            if config.flatBeams {
                beam.renderOptions.flatBeams = true
                beam.renderOptions.flatBeamOffset = config.flatBeamOffset
            }
            beams.append(beam)
        }

        // Reformat tuplets
        for tuplet in allTuplets {
            // Set the tuplet location based on the stem direction
            let firstStemDirection = (tuplet.notes[0] as? StemmableNote)?.getStemDirection()
            let direction: TupletLocation = firstStemDirection == Stem.DOWN ? .bottom : .top
            tuplet.setTupletLocation(direction)

            // If any of the notes in the tuplet are not beamed, draw a bracket.
            var bracketed = false
            for note in tuplet.notes where !note.hasBeam() {
                bracketed = true
                break
            }
            tuplet.setBracketed(bracketed)
        }

        return beams
    }

    // MARK: - Init

    public init(_ notes: [StemmableNote], autoStem: Bool = false) throws {
        if notes.isEmpty {
            throw BeamError.noNotes
        }

        if notes.count == 1 {
            throw BeamError.tooFewNotes
        }

        // Validate beam line, direction and ticks.
        self._ticks = notes[0].getIntrinsicTicks()

        if let quarterTicks = Tables.durationToTicks("4"), _ticks >= Double(quarterTicks) {
            // Q(MSAC) -- what about beamed half-note measured tremolos?
            throw BeamError.notesNotShorterThanQuarter
        }

        self._stemDirection = notes[0].getStemDirection()
        self.notes = notes

        super.init()

        var stemDirection = _stemDirection
        // Figure out optimal stem direction based on given notes
        if autoStem && isStaveNote(notes[0]) {
            stemDirection = calculateStemDirection(notes)
        } else if autoStem && isTabNote(notes[0]) {
            // Auto Stem TabNotes
            let stemWeight = notes.reduce(0) { $0 + $1.getStemDirection().sign }
            stemDirection = stemWeight > -1 ? Stem.UP : Stem.DOWN
        }

        // Apply stem directions and attach beam to notes
        for note in notes {
            if autoStem {
                _ = note.setStemDirection(stemDirection)
                _stemDirection = stemDirection
            }
            _ = note.setBeam(self)
        }

        postFormatted = false
        _beamCount = getBeamCount()
        breakOnIndexes = []
        renderOptions = BeamRenderOptions()
    }

    // MARK: - Accessors

    /// Get the notes in this beam.
    public func getNotes() -> [StemmableNote] { notes }

    /// Get the max number of beams in the set of notes.
    public func getBeamCount() -> Int {
        let beamCounts = notes.map { $0.getGlyphProps().beamCount }
        return beamCounts.reduce(beamCounts.first ?? 0) { $1 > $0 ? $1 : $0 }
    }

    /// Set which note `indexes` to break the secondary beam at.
    @discardableResult
    public func breakSecondaryAt(_ indexes: [Int]) -> Self {
        breakOnIndexes = indexes
        return self
    }

    /// Forces the direction of a partial beam (a secondary-level beam that exists
    /// on one note only of the beam group). This is useful in rhythms such as 6/8
    /// eighth-sixteenth-eighth-sixteenth, where the direction of the beam on the
    /// first sixteenth note can help imply whether the rhythm is to be felt as
    /// three groups of eighth notes (typical) or as two groups of three-sixteenths
    /// (less common).
    @discardableResult
    public func setPartialBeamSideAt(_ noteIndex: Int, side: PartialBeamDirection) -> Self {
        forcedPartialDirections[noteIndex] = side
        return self
    }

    /// Restore the default direction of a partial beam (a secondary-level beam
    /// that does not connect to any other notes).
    @discardableResult
    public func unsetPartialBeamSideAt(_ noteIndex: Int) -> Self {
        forcedPartialDirections.removeValue(forKey: noteIndex)
        return self
    }

    // MARK: - Slope Calculation

    /// `firstX` and `firstY` are specified in pixels.
    /// Return the y coordinate for linear function.
    public func getSlopeY(_ x: Double, _ firstX: Double, _ firstY: Double, _ slope: Double) -> Double {
        firstY + (x - firstX) * slope
    }

    /// Calculate the best possible slope for the provided notes.
    public func calculateSlope() {
        let maxSlope = renderOptions.maxSlope
        let minSlope = renderOptions.minSlope
        let slopeIterations = Double(renderOptions.slopeIterations)
        let slopeCost = renderOptions.slopeCost

        let stemDirection = _stemDirection.signDouble

        let firstNote = notes[0]
        let initialSlope = getStemSlope(firstNote, notes[notes.count - 1])
        let increment = (maxSlope - minSlope) / slopeIterations
        var minCost = Double.greatestFiniteMagnitude
        var bestSlope: Double = 0
        var yShift: Double = 0

        // iterate through slope values to find best weighted fit
        var slope = minSlope
        while slope <= maxSlope {
            var totalStemExtension: Double = 0
            var yShiftTemp: Double = 0

            // iterate through notes, calculating y shift and stem extension
            for i in 1..<notes.count {
                let note = notes[i]
                if note.hasStem() || note.isRest() {
                    let adjustedStemTipY =
                        getSlopeY(note.getStemX(), firstNote.getStemX(), firstNote.getStemExtents().topY, slope)
                        + yShiftTemp

                    let stemTipY = note.getStemExtents().topY
                    // beam needs to be shifted up to accommodate note
                    if stemTipY * stemDirection < adjustedStemTipY * stemDirection {
                        let diff = abs(stemTipY - adjustedStemTipY)
                        yShiftTemp += diff * -stemDirection
                        totalStemExtension += diff * Double(i)
                    } else {
                        // beam overshoots note, account for the difference
                        totalStemExtension += (stemTipY - adjustedStemTipY) * stemDirection
                    }
                }
            }

            // most engraving books suggest aiming for a slope about half the angle of the
            // difference between the first and last notes' stem length;
            let idealSlope = initialSlope / 2
            let distanceFromIdeal = abs(idealSlope - slope)

            // This tries to align most beams to something closer to the idealSlope, but
            // doesn't go crazy. To disable, set renderOptions.slopeCost = 0
            let cost = slopeCost * distanceFromIdeal + abs(totalStemExtension)

            // update state when a more ideal slope is found
            if cost < minCost {
                minCost = cost
                bestSlope = slope
                yShift = yShiftTemp
            }
            slope += increment
        }

        self.slope = bestSlope
        self.yShift = yShift
    }

    /// Calculate a slope and y-shift for flat beams.
    public func calculateFlatSlope() {
        let beamWidth = renderOptions.beamWidth
        let minFlatBeamOffset = renderOptions.minFlatBeamOffset
        let flatBeamOffset = renderOptions.flatBeamOffset

        let stemDirection = _stemDirection

        // If a flat beam offset has not yet been supplied or calculated,
        // generate one based on the notes in this particular note group
        var total: Double = 0
        var extremeY: Double = 0 // Store the highest or lowest note here
        var extremeBeamCount = 0 // The beam count of the extreme note
        var currentExtreme: Double = 0
        for note in notes {
            // Total up all of the offsets so we can average them out later
            let stemTipY = note.getStemExtents().topY
            total += stemTipY

            // Store the highest (stems-up) or lowest (stems-down) note so the
            //  offset can be adjusted in case the average isn't enough
            if stemDirection == Stem.DOWN && currentExtreme < stemTipY {
                currentExtreme = stemTipY
                extremeY = note.getYs().max() ?? -Double.infinity
                extremeBeamCount = note.getBeamCount()
            } else if stemDirection == Stem.UP && (currentExtreme == 0 || currentExtreme > stemTipY) {
                currentExtreme = stemTipY
                extremeY = note.getYs().min() ?? Double.infinity
                extremeBeamCount = note.getBeamCount()
            }
        }

        // Average the offsets to try and come up with a reasonable one that
        // works for all of the notes in the beam group.
        var offset = total / Double(notes.count)

        // In case the average isn't long enough, add or subtract some more
        // based on the highest or lowest note (again, based on the stem
        // direction). This also takes into account the added height due to
        // the width of the beams.
        let extremeTest = minFlatBeamOffset + Double(extremeBeamCount) * beamWidth * 1.5
        let newOffset = extremeY + extremeTest * -stemDirection.signDouble
        if stemDirection == Stem.DOWN && offset < newOffset {
            offset = extremeY + extremeTest
        } else if stemDirection == Stem.UP && offset > newOffset {
            offset = extremeY - extremeTest
        }

        if flatBeamOffset == nil || flatBeamOffset == 0 || flatBeamOffset?.isNaN == true {
            // Set the offset for the group based on the calculations above.
            renderOptions.flatBeamOffset = offset
        } else if let flatBeamOffset, stemDirection == Stem.DOWN && offset > flatBeamOffset {
            renderOptions.flatBeamOffset = offset
        } else if let flatBeamOffset, stemDirection == Stem.UP && offset < flatBeamOffset {
            renderOptions.flatBeamOffset = offset
        }

        // For flat beams, the slope and yShift are 0.
        slope = 0
        yShift = 0
    }

    /// Return the Beam y offset.
    public func getBeamYToDraw() -> Double {
        let firstNote = notes[0]
        let firstStemTipY = firstNote.getStemExtents().topY
        var beamY = firstStemTipY

        // For flat beams, set the first and last Y to the offset, rather than
        //  using the note's stem extents.
        if renderOptions.flatBeams, let offset = renderOptions.flatBeamOffset, offset != 0, !offset.isNaN {
            beamY = offset
        }
        return beamY
    }

    /// Create new stems for the notes in the beam, so that each stem
    /// extends into the beams.
    public func applyStemExtensions() {
        let showStemlets = renderOptions.showStemlets
        let stemletExtension = renderOptions.stemletExtension
        let beamWidth = renderOptions.beamWidth

        let yShift = self.yShift
        let beamCount = _beamCount

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
            // Determine necessary extension for cross-stave notes in the beam group
            var crossStemExtension: Double = 0
            if note.getStemDirection() != _stemDirection {
                let noteBeamCount = note.getGlyphProps().beamCount
                crossStemExtension = (1 + Double(noteBeamCount - 1) * 1.5) * renderOptions.beamWidth
            }

            stem.setExtension(preBeamExtension + beamExtension + crossStemExtension)
            stem.adjustHeightForBeam()

            if note.isRest() && showStemlets {
                let totalBeamWidth = Double(beamCount - 1) * beamWidth * 1.5 + beamWidth
                _ = stem.setVisibility(true).setStemlet(true, height: totalBeamWidth + stemletExtension)
            }
        }
    }

    // MARK: - Beam Direction Lookup

    /// Return upper level beam direction.
    public func lookupBeamDirection(
        _ duration: String,
        prevTick: Double,
        tick: Double,
        nextTick: Double,
        noteIndex: Int
    ) -> PartialBeamDirection {
        if duration == "4" {
            return BEAM_LEFT
        }

        if let forcedBeamDirection = forcedPartialDirections[noteIndex] {
            return forcedBeamDirection
        }

        let lookupDuration = formatJSNumber(Tables.durationToNumber(duration) / 2)
        let lookupTicks = Tables.durationToTicks(lookupDuration).map(Double.init) ?? .nan
        let prevNoteGetsBeam = prevTick < lookupTicks
        let nextNoteGetsBeam = nextTick < lookupTicks
        let noteGetsBeam = tick < lookupTicks

        if prevNoteGetsBeam && nextNoteGetsBeam && noteGetsBeam {
            return BEAM_BOTH
        } else if prevNoteGetsBeam && !nextNoteGetsBeam && noteGetsBeam {
            return BEAM_LEFT
        } else if !prevNoteGetsBeam && nextNoteGetsBeam && noteGetsBeam {
            return BEAM_RIGHT
        }

        // Guard against unbounded recursion on durations that cannot be looked up.
        if lookupTicks.isNaN || lookupDuration == duration {
            return BEAM_LEFT
        }
        return lookupBeamDirection(lookupDuration, prevTick: prevTick, tick: tick, nextTick: nextTick, noteIndex: noteIndex)
    }

    // MARK: - Beam Lines

    public struct BeamLine {
        public var start: Double
        public var end: Double?
    }

    /// Get the x coordinates for the beam lines of specific `duration`.
    public func getBeamLines(_ duration: String) -> [BeamLine] {
        let tickOfDuration = Tables.durationToTicks(duration).map(Double.init) ?? .nan
        var beamStarted = false

        var beamLines: [BeamLine] = []
        let partialBeamLength = renderOptions.partialBeamLength
        var previousShouldBreak = false
        var tickTally: Double = 0
        for i in 0..<notes.count {
            let note = notes[i]

            // See if we need to break secondary beams on this note.
            let ticks = note.getTicks().value()
            tickTally += ticks
            var shouldBreak = false

            // 8th note beams are always drawn.
            if let d = jsParseInt(duration), d >= 8 {
                // First, check to see if any indexes were set up through breakSecondaryAt()
                shouldBreak = breakOnIndexes.contains(i)

                // If the secondary breaks were auto-configured in the render options,
                //  handle that as well.
                if let secondaryBreakTicks = renderOptions.secondaryBreakTicks, secondaryBreakTicks != 0,
                   tickTally >= secondaryBreakTicks {
                    tickTally = 0
                    shouldBreak = true
                }
            }
            let noteGetsBeam = note.getIntrinsicTicks() < tickOfDuration

            let stemX = note.getStemX() - Stem.WIDTH / 2

            // Check to see if the next note in the group will get a beam at this
            //  level. This will help to inform the partial beam logic below.
            let prevNote: StemmableNote? = i > 0 ? notes[i - 1] : nil
            let nextNote: StemmableNote? = i + 1 < notes.count ? notes[i + 1] : nil
            let nextNoteGetsBeam = nextNote.map { $0.getIntrinsicTicks() < tickOfDuration } ?? false
            let prevNoteGetsBeam = prevNote.map { $0.getIntrinsicTicks() < tickOfDuration } ?? false
            let beamAlone = prevNote != nil && nextNote != nil && noteGetsBeam && !prevNoteGetsBeam && !nextNoteGetsBeam
            if noteGetsBeam {
                // This note gets a beam at the current level
                if beamStarted {
                    // We're currently in the middle of a beam. Just continue it on to
                    //  the stem X of the current note.
                    let last = beamLines.count - 1
                    beamLines[last].end = stemX

                    // If a secondary beam break is set up, end the beam right now.
                    if shouldBreak {
                        beamStarted = false
                        if nextNote != nil && !nextNoteGetsBeam && beamLines[last].end == nil {
                            // This note gets a beam, but the next one does not. This means
                            //  we need a partial pointing right.
                            beamLines[last].end = beamLines[last].start - partialBeamLength
                        }
                    }
                } else {
                    // No beam started yet. Start a new one.
                    var currentBeam = BeamLine(start: stemX, end: nil)
                    beamStarted = true

                    if beamAlone, let prevNote, let nextNote {
                        // previous and next beam exists and does not get a beam but current gets it.
                        let prevTick = prevNote.getIntrinsicTicks()
                        let nextTick = nextNote.getIntrinsicTicks()
                        let tick = note.getIntrinsicTicks()
                        let beamDirection = lookupBeamDirection(
                            duration, prevTick: prevTick, tick: tick, nextTick: nextTick, noteIndex: i
                        )

                        if beamDirection == BEAM_LEFT || beamDirection == BEAM_BOTH {
                            currentBeam.end = currentBeam.start - partialBeamLength
                        } else {
                            currentBeam.end = currentBeam.start + partialBeamLength
                        }
                    } else if !nextNoteGetsBeam {
                        // The next note doesn't get a beam. Draw a partial.
                        if (previousShouldBreak || i == 0) && nextNote != nil {
                            // This is the first note (but not the last one), or it is
                            //  following a secondary break. Draw a partial to the right.
                            currentBeam.end = currentBeam.start + partialBeamLength
                        } else {
                            // By default, draw a partial to the left.
                            currentBeam.end = currentBeam.start - partialBeamLength
                        }
                    } else if shouldBreak {
                        // This note should have a secondary break after it. Even though
                        //  we just started a beam, it needs to end immediately.
                        currentBeam.end = currentBeam.start - partialBeamLength
                        beamStarted = false
                    }
                    beamLines.append(currentBeam)
                }
            } else {
                // The current note does not get a beam.
                beamStarted = false
            }

            // Store the secondary break flag to inform the partial beam logic in
            //  the next iteration of the loop.
            previousShouldBreak = shouldBreak
        }

        // Add a partial beam pointing left if this is the last note in the group
        if let last = beamLines.indices.last, beamLines[last].end == nil {
            beamLines[last].end = beamLines[last].start - partialBeamLength
        }
        return beamLines
    }

    // MARK: - Draw

    /// Render the stems for each note.
    func drawStems(_ ctx: RenderContext) throws {
        for note in notes {
            if let stem = note.getStem() {
                let stemX = note.getStemX()
                _ = stem.setNoteHeadXBounds(stemX, stemX)
                stem.setContext(ctx)
                try stem.drawWithStyle()
            }
        }
    }

    /// Render the beam lines.
    func drawBeamLines(_ ctx: RenderContext) throws {
        let validBeamDurations = ["4", "8", "16", "32", "64", "128", "256", "512", "1024"]

        let firstNote = notes[0]
        var beamY = getBeamYToDraw()
        let firstStemX = firstNote.getStemX()
        let beamThickness = renderOptions.beamWidth * _stemDirection.signDouble

        // Draw the beams.
        for duration in validBeamDurations {
            let beamLines = getBeamLines(duration)

            for beamLine in beamLines {
                let startBeamX = beamLine.start

                let startBeamY = getSlopeY(startBeamX, firstStemX, beamY, slope)
                if let lastBeamX = beamLine.end, lastBeamX != 0, !lastBeamX.isNaN {
                    let lastBeamY = getSlopeY(lastBeamX, firstStemX, beamY, slope)

                    ctx.beginPath()
                    ctx.moveTo(startBeamX, startBeamY)
                    ctx.lineTo(startBeamX, startBeamY + beamThickness)
                    ctx.lineTo(lastBeamX + 1, lastBeamY + beamThickness)
                    ctx.lineTo(lastBeamX + 1, lastBeamY)
                    ctx.closePath()
                    ctx.fill()
                } else {
                    throw BeamError.noLastBeamX
                }
            }

            beamY += beamThickness * 1.5
        }
    }

    /// Pre-format the beam.
    @discardableResult
    public func preFormat() -> Self {
        self
    }

    /// Post-format the beam. This can only be called after
    /// the notes in the beam have both `x` and `y` values. ie: they've
    /// been formatted and have staves.
    public func postFormat() {
        if postFormatted { return }

        // VexFlowPatch: reset stem extensions to base values before recalculating.
        // This ensures idempotent beam rendering when beams are recreated
        // but notes/stems are reused (prevents extension accumulation).
        for note in notes {
            if let stem = note.getStem() {
                stem.setExtension(note.getStemExtension())
            }
        }

        // Calculate a smart slope if we're not forcing the beams to be flat.
        if isTabNote(notes[0]) || renderOptions.flatBeams {
            calculateFlatSlope()
        } else {
            calculateSlope()
        }
        applyStemExtensions()

        postFormatted = true
    }

    /// Render the beam to the canvas context.
    override public func draw() throws {
        let ctx = try checkContext()
        setRendered()
        if unbeamable { return }

        if !postFormatted {
            postFormat()
        }

        // Local change (1af03ba): apply the element style in draw().
        ctx.save()
        defer { ctx.restore() }
        applyStyle(context: ctx)

        _ = ctx.openGroup(groupClass("beam"), getAttribute("id"))
        try drawStems(ctx)
        try drawBeamLines(ctx)
        drawPointerRect()
        ctx.closeGroup()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
#Preview("Beam", traits: .sizeThatFitsLayout) {
    VexCanvas(width: 520, height: 160) { ctx in
        ctx.clear()

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
