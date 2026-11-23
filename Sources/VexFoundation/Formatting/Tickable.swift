// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) 2023-present VexFlow contributors. MIT License.
//
// Port of `src/tickable.ts` (VexFlow 5.1.0).

import Foundation

public enum TickableError: Error, LocalizedError, Equatable, Sendable {
    case unformattedWidth
    case noVoice
    case noTickContext(String)
    case noModifierContext

    public var errorDescription: String? {
        switch self {
        case .unformattedWidth:
            return "Can't call GetWidth on an unformatted note."
        case .noVoice:
            return "Tickable has no voice."
        case .noTickContext(let message):
            return message
        case .noModifierContext:
            return "No modifier context attached to this tickable."
        }
    }
}

// MARK: - Formatter Metrics

/// Formatter metrics. A reference type, so that formatters can change
/// `getFormatterMetrics().space.used` (and so on) in place, as upstream does.
public final class FormatterMetrics {
    /// The simplified rational duration of this tick as a string. It can be
    /// used as an index to a map or hashtable.
    public var duration: String = ""
    /// The freedom of a tickable is the distance it can move without colliding
    /// with neighboring elements. A formatter can set these values during its
    /// formatting pass, which a different formatter can then use to fine tune.
    public var freedom: (left: Double, right: Double) = (0, 0)
    /// The number of formatting iterations undergone.
    public var iterations: Int = 0
    /// The space in pixels allocated by this formatter, along with the mean space
    /// for tickables of this duration, and the deviation from the mean.
    public var space: (used: Double, mean: Double, deviation: Double) = (0, 0, 0)

    public init() {}
}

// MARK: - Tickable

/// Tickable represents a element that sit on a score and
/// has a duration, i.e., Tickables occupy space in the musical rendering dimension.
///
/// `x`, `xShift`, `yShift` and `width` are inherited from `VexElement`.
open class Tickable: VexElement {

    override open class var category: String { "Tickable" }

    // MARK: - Properties

    public var ignoreTicks: Bool = false
    /// The tuplets of this tickable, the most recently added last. Read only:
    /// use `addTuplet`, `removeTuplet`, `setTupletStack` and `clearTuplets`. (VexFlow 5.1.0)
    public private(set) var tupletStack: [Tuplet] = []
    /// Fractional value of ticks.
    public var ticks: Fraction = Fraction(0, 1)
    /// Shift from tick context if center aligned.
    public var centerXShift: Double = 0
    public weak var voice: Voice?
    public var modifierContext: ModifierContext?
    public var tickContext: TickContext?
    public var modifiers: [Modifier] = []
    public var tickMultiplier: Fraction = Fraction(1, 1)
    /// This is a space for an external formatting class or function to maintain metrics.
    public var formatterMetrics = FormatterMetrics()
    /// Floating point value of ticks.
    public var intrinsicTicks: Double = 0
    public var alignCenter: Bool = false

    private var _preFormatted: Bool = false
    private var _postFormatted: Bool = false

    // MARK: - Init

    public override init() {
        super.init(category: nil)
    }

    // MARK: - Source compatibility

    @available(*, deprecated, renamed: "modifiers")
    public var noteModifiers: [Modifier] {
        get { modifiers }
        set { modifiers = newValue }
    }

    @available(*, deprecated, renamed: "width")
    public var tickableWidth: Double {
        get { width }
        set { width = newValue }
    }

    @available(*, deprecated, renamed: "setWidth(_:)")
    public func setTickableWidth(_ width: Double) {
        self.width = width
    }

    @available(*, deprecated, renamed: "getWidth()")
    public func getTickableWidth() -> Double { getWidth() }

    @available(*, deprecated, renamed: "getWidthThrowing()")
    public func getTickableWidthThrowing() throws -> Double { try getWidthThrowing() }

    // MARK: - Reset

    /// Reset the Tickable, this function will be overloaded.
    @discardableResult
    open func reset() -> Self {
        self
    }

    // MARK: - Ticks

    /// Return the ticks.
    public func getTicks() -> Fraction { ticks }

    /// Check if it ignores the ticks.
    open func shouldIgnoreTicks() -> Bool { ignoreTicks }

    /// Ignore the ticks.
    @discardableResult
    public func setIgnoreTicks(_ flag: Bool) -> Self {
        ignoreTicks = flag
        voice?.invalidateTicks()
        return self
    }

    // MARK: - Width

    /// Get width of note. Used by the formatter for positioning.
    /// Upstream throws when the note is not pre-formatted; this returns the
    /// same value without the check. See `getWidthThrowing()`.
    override open func getWidth() -> Double {
        width + (modifierContext?.getWidth() ?? 0)
    }

    /// Get width of note. Throws when the note is not pre-formatted (upstream behavior).
    open func getWidthThrowing() throws -> Double {
        guard _preFormatted else {
            throw TickableError.unformattedWidth
        }
        return width + (modifierContext?.getWidth() ?? 0)
    }

    // MARK: - X Position

    /// Get `x` position of this tick context.
    override open func getX() -> Double {
        let tc = checkTickContext("Can't getX() without a TickContext.")
        return tc.getX() + xShift
    }

    open func getAbsoluteX() -> Double {
        let tc = checkTickContext("Can't getAbsoluteX() without a TickContext.")
        return tc.getX()
    }

    // MARK: - Formatter Metrics

    /// Return the formatterMetrics.
    public func getFormatterMetrics() -> FormatterMetrics { formatterMetrics }

    // MARK: - Center Alignment

    /// Return the center `x` shift.
    public func getCenterXShift() -> Double {
        isCenterAligned() ? centerXShift : 0
    }

    /// Set the center `x` shift.
    @discardableResult
    public func setCenterXShift(_ centerXShift: Double) -> Self {
        self.centerXShift = centerXShift
        return self
    }

    /// Check if tickable is center aligned.
    public func isCenterAligned() -> Bool { alignCenter }

    /// Set/unset center alignment.
    @discardableResult
    public func setCenterAlignment(_ alignCenter: Bool) -> Self {
        self.alignCenter = alignCenter
        return self
    }

    // MARK: - Voice

    /// Return the associated voice. Every tickable must be associated with a voice.
    /// This allows formatters and preFormatter to associate them with the right modifierContexts.
    open func getVoice() -> Voice {
        (try? getVoiceThrowing()) ?? Voice()
    }

    open func getVoiceThrowing() throws -> Voice {
        guard let voice else {
            throw TickableError.noVoice
        }
        return voice
    }

    /// Set the associated voice.
    /// Swift: returns `Self` (upstream `void`) so that `Note` can override it.
    @discardableResult
    open func setVoice(_ voice: Voice) -> Self {
        self.voice = voice
        return self
    }

    // MARK: - Tuplets

    /// Get the Tuplet, if any. If there are multiple Tuplets, the most recently added one is returned.
    public func getTuplet() -> Tuplet? { tupletStack.last }

    /// Return the Tuplets (might be empty).
    public func getTupletStack() -> [Tuplet] { tupletStack }

    /// Remove the given tuplet. Throws if the tuplet is not in the tuplet stack.
    @discardableResult
    open func removeTuplet(_ tuplet: Tuplet) throws -> Self {
        guard let i = tupletStack.firstIndex(where: { $0 === tuplet }) else {
            throw VexError("BadArguments", "Tuplet is not found in this tickable")
        }
        tupletStack.remove(at: i)
        let noteCount = tuplet.getNoteCount()
        let notesOccupied = tuplet.getNotesOccupied()

        // Revert old multiplier by inverting numerator & denominator:
        // to remove a 3:2 tuplet, multiply the previous 2/3 by 3/2 to get 1/1.
        applyTickMultiplier(noteCount, notesOccupied)
        return self
    }

    /// Remove all tuplets from the tickable.
    @discardableResult
    open func clearTuplets() -> Self {
        if tupletStack.isEmpty { return self }
        tupletStack = []
        tickMultiplier = Fraction(1, 1)
        ticks = Fraction(Int(intrinsicTicks), 1)
        voice?.invalidateTicks()
        return self
    }

    /// Reset the specific Tuplet (if this is not provided, all tuplets are reset).
    /// Remove any prior tuplets from the tick calculation and
    /// reset the intrinsic tick value.
    @available(*, deprecated, message: "Use removeTuplet(_:) or clearTuplets().")
    @discardableResult
    open func resetTuplet(_ tuplet: Tuplet? = nil) -> Self {
        if let tuplet {
            // resetTuplet fails silently if the tuplet is missing.
            _ = try? removeTuplet(tuplet)
        } else {
            clearTuplets()
        }
        return self
    }

    /// Set the tuplet to the given Tuplet. Existing tuplets are cleared first. (VexFlow 5.1.0)
    @discardableResult
    open func setTuplet(_ tuplet: Tuplet?) -> Self {
        if !tupletStack.isEmpty {
            clearTuplets()
        }
        guard let tuplet else { return self }
        return addTuplet(tuplet)
    }

    /// Add the given Tuplet to the tuplet stack without clearing it first.
    @discardableResult
    open func addTuplet(_ tuplet: Tuplet) -> Self {
        if tupletStack.contains(where: { $0 === tuplet }) { return self }
        tupletStack.append(tuplet)

        let noteCount = tuplet.getNoteCount()
        let notesOccupied = tuplet.getNotesOccupied()

        // Apply the reciprocal of the tuplet. 3:2 multiplies by 2/3, etc.
        applyTickMultiplier(notesOccupied, noteCount)
        return self
    }

    /// Set all the tuplets of the tickable. The array is copied.
    @discardableResult
    open func setTupletStack(_ tupletStack: [Tuplet]) -> Self {
        clearTuplets()
        for tuplet in tupletStack {
            addTuplet(tuplet)
        }
        return self
    }

    // MARK: - Modifier Context

    /// Add self to the provided ModifierContext `mc`.
    /// If this tickable has modifiers, set modifierContext.
    @discardableResult
    open func addToModifierContext(_ mc: ModifierContext) -> Self {
        modifierContext = mc
        for modifier in modifiers {
            mc.addMember(modifier)
        }
        mc.addMember(self)
        _preFormatted = false
        return self
    }

    /// Optional, if tickable has modifiers, associate a Modifier.
    @discardableResult
    open func addModifier(_ modifier: Modifier, index: Int = 0) -> Self {
        modifiers.append(modifier)
        _preFormatted = false
        return self
    }

    /// Get the list of associated modifiers.
    public func getModifiers() -> [Modifier] { modifiers }

    // MARK: - Tick Context

    /// Set the Tick Context.
    /// Swift: returns `Self` (upstream `void`) so that `Note` can override it.
    @discardableResult
    open func setTickContext(_ tc: TickContext) -> Self {
        tickContext = tc
        _preFormatted = false
        return self
    }

    /// Check and get the tick context. Returns an empty `TickContext` when
    /// none is attached; see `checkTickContextThrowing(_:)`.
    public func checkTickContext(_ message: String = "Tickable has no tick context.") -> TickContext {
        (try? checkTickContextThrowing(message)) ?? TickContext()
    }

    public func checkTickContextThrowing(_ message: String = "Tickable has no tick context.") throws -> TickContext {
        guard let tickContext else {
            throw TickableError.noTickContext(message)
        }
        return tickContext
    }

    // MARK: - PreFormat / PostFormat

    /// Preformat the Tickable.
    open func preFormat() {
        if _preFormatted { return }

        width = 0
        if let mc = modifierContext {
            mc.preFormat()
            width += mc.getWidth()
        }
    }

    /// Preformatted status.
    public var preFormatted: Bool {
        get { _preFormatted }
        set { _preFormatted = newValue }
    }

    /// Postformat the Tickable.
    @discardableResult
    open func postFormat() -> Self {
        if _postFormatted { return self }
        _postFormatted = true
        return self
    }

    /// Postformatted status.
    public var postFormatted: Bool {
        get { _postFormatted }
        set { _postFormatted = newValue }
    }

    // MARK: - Intrinsic Ticks

    /// Return the intrinsic ticks.
    public func getIntrinsicTicks() -> Double { intrinsicTicks }

    /// Set the intrinsic ticks.
    open func setIntrinsicTicks(_ intrinsicTicks: Double) {
        self.intrinsicTicks = intrinsicTicks
        ticks = tickMultiplier.clone().multiply(Int(intrinsicTicks))
        voice?.invalidateTicks()
    }

    /// Get the tick multiplier.
    public func getTickMultiplier() -> Fraction { tickMultiplier }

    /// Apply a tick multiplier.
    open func applyTickMultiplier(_ numerator: Int, _ denominator: Int) {
        tickMultiplier.multiply(numerator, denominator)
        ticks = tickMultiplier.clone().multiply(Int(intrinsicTicks))
        voice?.invalidateTicks()
    }

    /// Set the duration.
    open func setDuration(_ duration: Fraction) {
        let t = duration.numerator * (Tables.RESOLUTION / duration.denominator)
        ticks = tickMultiplier.clone().multiply(t)
        // Keep the unscaled duration so later tuplets do not apply the ratio twice.
        intrinsicTicks = Double(t)
        voice?.invalidateTicks()
    }

    // MARK: - Modifier Context accessors

    /// Attach this note to a modifier context.
    @discardableResult
    public func setModifierContext(_ mc: ModifierContext?) -> Self {
        modifierContext = mc
        return self
    }

    /// Get `ModifierContext`.
    public func getModifierContext() -> ModifierContext? { modifierContext }

    /// Check and get `ModifierContext`.
    public func checkModifierContext() -> ModifierContext {
        (try? checkModifierContextThrowing()) ?? ModifierContext()
    }

    public func checkModifierContextThrowing() throws -> ModifierContext {
        guard let modifierContext else {
            throw TickableError.noModifierContext
        }
        return modifierContext
    }

    // MARK: - Abstract (subclasses must implement)

    /// Get the target stave.
    open func getStave() -> Stave? { nil }

    /// Set the target stave.
    @discardableResult
    open func setStave(_ stave: Stave) -> Self { self }

    open func getMetrics() -> NoteMetrics {
        NoteMetrics()
    }
}
