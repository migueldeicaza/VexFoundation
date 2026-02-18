// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Formatter Metrics

/// Metrics maintained by the formatter during layout.
public struct FormatterMetrics {
    public var duration: String = ""
    public var freedom: (left: Double, right: Double) = (0, 0)
    public var iterations: Int = 0
    public var space: (used: Double, mean: Double, deviation: Double) = (0, 0, 0)
}

// MARK: - Tickable

/// Base class for elements that sit on a score and have a duration.
/// Tickables occupy space in the musical rendering dimension.
open class Tickable: VexElement {

    override open class var category: String { "Tickable" }

    // MARK: - Properties

    public var ignoreTicks: Bool = false
    public var ticks: Fraction = Fraction(0, 1)
    public var centerXShift: Double = 0
    public weak var voice: Voice?
    public var tickableWidth: Double = 0
    public var xShift: Double = 0
    public var tickContext: TickContext?
    public var noteModifiers: [Modifier] = []
    public var tickMultiplier: Fraction = Fraction(1, 1)
    public var formatterMetrics = FormatterMetrics()
    public var intrinsicTicks: Double = 0
    public var alignCenter: Bool = false
    public var modifierContext: ModifierContext?
    public var tupletStack: [Tuplet] = []

    private var _preFormatted: Bool = false
    private var _postFormatted: Bool = false

    // MARK: - Ticks

    public func getTicks() -> Fraction { ticks }

    public func shouldIgnoreTicks() -> Bool { ignoreTicks }

    @discardableResult
    public func setIgnoreTicks(_ flag: Bool) -> Self {
        ignoreTicks = flag
        return self
    }

    // MARK: - Width

    public func setTickableWidth(_ width: Double) {
        tickableWidth = width
    }

    public func getTickableWidth() -> Double {
        guard _preFormatted else {
            fatalError("[VexError] UnformattedNote: Can't call getWidth on an unformatted note.")
        }
        return tickableWidth + (modifierContext?.getWidth() ?? 0)
    }

    // MARK: - X Position

    @discardableResult
    public func setXShift(_ x: Double) -> Self {
        xShift = x
        return self
    }

    public func getXShift() -> Double { xShift }

    public func getX() -> Double {
        let tc = checkTickContext("Can't getX() without a TickContext.")
        return tc.getX() + xShift
    }

    public func getAbsoluteX() -> Double {
        let tc = checkTickContext("Can't getAbsoluteX() without a TickContext.")
        return tc.getX()
    }

    // MARK: - Formatter Metrics

    public func getFormatterMetrics() -> FormatterMetrics { formatterMetrics }

    // MARK: - Center Alignment

    public func getCenterXShift() -> Double {
        isCenterAligned() ? centerXShift : 0
    }

    @discardableResult
    public func setCenterXShift(_ shift: Double) -> Self {
        centerXShift = shift
        return self
    }

    public func isCenterAligned() -> Bool { alignCenter }

    @discardableResult
    public func setCenterAlignment(_ align: Bool) -> Self {
        alignCenter = align
        return self
    }

    // MARK: - Voice

    public func getVoice() -> Voice {
        guard let voice else {
            fatalError("[VexError] NoVoice: Tickable has no voice.")
        }
        return voice
    }

    public func setVoice(_ voice: Voice) {
        self.voice = voice
    }

    // MARK: - Tick Context

    public func setTickContext(_ tc: TickContext) {
        tickContext = tc
        _preFormatted = false
    }

    public func checkTickContext(_ message: String = "Tickable has no tick context.") -> TickContext {
        guard let tickContext else {
            fatalError("[VexError] NoTickContext: \(message)")
        }
        return tickContext
    }

    // MARK: - Modifier Context

    @discardableResult
    public func setModifierContext(_ mc: ModifierContext?) -> Self {
        modifierContext = mc
        return self
    }

    public func getModifierContext() -> ModifierContext? { modifierContext }

    public func checkModifierContext() -> ModifierContext {
        guard let modifierContext else {
            fatalError("[VexError] NoModifierContext: No modifier context attached to this tickable.")
        }
        return modifierContext
    }

    @discardableResult
    public func addToModifierContext(_ mc: ModifierContext) -> Self {
        modifierContext = mc
        for modifier in noteModifiers {
            mc.addMember(modifier)
        }
        mc.addMember(self)
        _preFormatted = false
        return self
    }

    // MARK: - Modifiers

    @discardableResult
    public func addModifier(_ modifier: Modifier, index: Int = 0) -> Self {
        noteModifiers.append(modifier)
        _preFormatted = false
        return self
    }

    public func getModifiers() -> [Modifier] { noteModifiers }

    // MARK: - PreFormat / PostFormat

    open func preFormat() {
        if _preFormatted { return }
        tickableWidth = 0
        if let mc = modifierContext {
            mc.preFormat()
            tickableWidth += mc.getWidth()
        }
    }

    public var preFormatted: Bool {
        get { _preFormatted }
        set { _preFormatted = newValue }
    }

    @discardableResult
    open func postFormat() -> Self {
        if _postFormatted { return self }
        _postFormatted = true
        return self
    }

    public var postFormatted: Bool {
        get { _postFormatted }
        set { _postFormatted = newValue }
    }

    // MARK: - Intrinsic Ticks

    public func getIntrinsicTicks() -> Double { intrinsicTicks }

    public func getTuplet() -> Tuplet? { tupletStack.last }

    public func getTupletStack() -> [Tuplet] { tupletStack }

    @discardableResult
    public func setTuplet(_ tuplet: Tuplet) -> Self {
        // Remove any existing instance of this tuplet
        tupletStack.removeAll { $0 === tuplet }
        tupletStack.append(tuplet)

        let newNoteCount = Double(tuplet.numNotes)
        let notesOccupied = Double(tuplet.notesOccupied)
        applyTickMultiplier(Int(notesOccupied), Int(newNoteCount))
        return self
    }

    public func resetTuplet(_ tuplet: Tuplet) {
        tupletStack.removeAll { $0 === tuplet }

        let newNoteCount = Double(tuplet.numNotes)
        let notesOccupied = Double(tuplet.notesOccupied)
        // Reverse the tick multiplier
        applyTickMultiplier(Int(newNoteCount), Int(notesOccupied))
    }

    public func setIntrinsicTicks(_ ticks: Double) {
        intrinsicTicks = ticks
        self.ticks = tickMultiplier.clone().multiply(Int(ticks))
    }

    public func getTickMultiplier() -> Fraction { tickMultiplier }

    public func applyTickMultiplier(_ numerator: Int, _ denominator: Int) {
        tickMultiplier.multiply(numerator, denominator)
        ticks = tickMultiplier.clone().multiply(Int(intrinsicTicks))
    }

    public func setDuration(_ duration: Fraction) {
        let t = duration.numerator * (Tables.RESOLUTION / duration.denominator)
        ticks = tickMultiplier.clone().multiply(t)
        intrinsicTicks = ticks.value()
    }

    // MARK: - Abstract (subclasses must implement)

    open func getStave() -> Stave? { nil }

    @discardableResult
    open func setStave(_ stave: Stave) -> Self { self }

    open func getMetrics() -> NoteMetrics {
        NoteMetrics()
    }

    open func getBoundingBox() -> BoundingBox? { nil }
}
