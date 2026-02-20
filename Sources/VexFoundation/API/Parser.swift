// VexFoundation - Ported from VexFlow (https://vexflow.com)
// Original: Copyright (c) Mohit Muthanna 2010. MIT License.

import Foundation

// MARK: - Parser Types

/// Result of a match operation, either a string or a nested array.
public indirect enum Match {
    case string(String)
    case array([Match])
    case null
}

/// A function that returns a parsing rule.
public typealias RuleFunction = () -> Rule

/// A trigger function called when a rule matches.
public typealias TriggerFunction = (_ matches: [Match]) -> Void

/// A parsing or lexing rule.
public struct Rule {
    // Lexer rules
    public var token: String?
    public var noSpace: Bool = false

    // Parser rules
    public var expect: [RuleFunction]?
    public var zeroOrMore: Bool = false
    public var oneOrMore: Bool = false
    public var maybe: Bool = false
    public var or: Bool = false
    public var run: TriggerFunction?

    public init(token: String? = nil, noSpace: Bool = false,
                expect: [RuleFunction]? = nil,
                zeroOrMore: Bool = false, oneOrMore: Bool = false,
                maybe: Bool = false, or: Bool = false,
                run: TriggerFunction? = nil) {
        self.token = token
        self.noSpace = noSpace
        self.expect = expect
        self.zeroOrMore = zeroOrMore
        self.oneOrMore = oneOrMore
        self.maybe = maybe
        self.or = or
        self.run = run
    }
}

/// Result of a parse or lex operation.
public struct ParseResult {
    public var success: Bool

    // Lexer results
    public var pos: Int?
    public var incrementPos: Int?
    public var matchedString: String?

    // Parser results
    public var matches: [Match] = []
    public var numMatches: Int?
    public var results: [ParseResultItem] = []
    public var errorPos: Int?
    public var parserError: ParserError?

    public init(success: Bool) {
        self.success = success
    }
}

public enum ParserError: Error, LocalizedError, Equatable, Sendable {
    case invalidGrammarRuleMissingTokenOrExpect

    public var errorDescription: String? {
        switch self {
        case .invalidGrammarRuleMissingTokenOrExpect:
            return "Bad grammar rule: expected either `token` or `expect`."
        }
    }
}

public enum ParserParseError: Error, LocalizedError, Sendable {
    case parseFailed(line: String, errorPos: Int?, parserError: ParserError?)

    public var errorDescription: String? {
        switch self {
        case .parseFailed(let line, let errorPos, let parserError):
            let pos = errorPos.map(String.init) ?? "nil"
            let parserErrorText = parserError?.localizedDescription ?? "none"
            return "Parse failed for line '\(line)' (errorPos: \(pos), parserError: \(parserErrorText))"
        }
    }
}

/// An item in grouped results (either a single result or an array of results).
public enum ParseResultItem {
    case single(ParseResult)
    case group([ParseResultItem])
}

/// Protocol for grammar definitions.
public protocol Grammar: AnyObject {
    func begin() -> RuleFunction
}

// MARK: - Flatten Matches

/// Convert parser results into a flat list of Match values.
private func flattenMatches(_ item: ParseResultItem) -> Match {
    switch item {
    case .single(let r):
        if let ms = r.matchedString {
            return .string(ms)
        }
        if !r.results.isEmpty {
            return flattenMatchesArray(r.results)
        }
        return .null
    case .group(let items):
        return flattenMatchesArray(items)
    }
}

private func flattenMatchesArray(_ items: [ParseResultItem]) -> Match {
    if items.count == 1 {
        return flattenMatches(items[0])
    }
    if items.isEmpty {
        return .null
    }
    return .array(items.map { flattenMatches($0) })
}

// MARK: - Parser

private let NO_ERROR_POS = -1

/// A generic recursive descent parser for context-free grammars.
/// Used as the foundation for EasyScore.
public final class Parser {

    private var grammar: Grammar
    private var line: String = ""
    private var pos: Int = 0
    private var errorPos: Int = NO_ERROR_POS
    public private(set) var lastError: ParserError?

    public init(grammar: Grammar) {
        self.grammar = grammar
    }

    // MARK: - Parse

    /// Parse `line` using the current grammar.
    /// Returns `ParseResult` with `success: true` if parsed correctly.
    public func parse(_ line: String) -> ParseResult {
        self.line = line
        self.pos = 0
        self.errorPos = NO_ERROR_POS
        self.lastError = nil
        var result = expect(grammar.begin())
        if lastError != nil {
            result.success = false
        }
        result.errorPos = errorPos
        result.parserError = lastError
        return result
    }

    public func parseThrowing(_ line: String) throws -> ParseResult {
        let result = parse(line)
        if result.success {
            return result
        }
        throw ParserParseError.parseFailed(line: line, errorPos: result.errorPos, parserError: result.parserError)
    }

    // MARK: - Match Helpers

    private func matchFail(_ returnPos: Int) {
        if errorPos == NO_ERROR_POS { errorPos = pos }
        pos = returnPos
    }

    private func matchSuccess() {
        errorPos = NO_ERROR_POS
    }

    // MARK: - Match Token

    /// Look for `token` regex at current position.
    private func matchToken(_ token: String, noSpace: Bool = false) -> ParseResult {
        let pattern = noSpace ? "^((\(token)))" : "^((\(token))\\s*)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return ParseResult(success: false)
        }

        let workingLine = String(line.dropFirst(pos))
        let range = NSRange(workingLine.startIndex..., in: workingLine)
        guard let match = regex.firstMatch(in: workingLine, range: range) else {
            var r = ParseResult(success: false)
            r.pos = pos
            return r
        }

        // Group 2 is the actual matched content (without trailing whitespace)
        let matchedRange = Range(match.range(at: 2), in: workingLine)!
        let fullRange = Range(match.range(at: 1), in: workingLine)!

        var r = ParseResult(success: true)
        r.matchedString = String(workingLine[matchedRange])
        r.incrementPos = workingLine.distance(from: workingLine.startIndex, to: fullRange.upperBound)
        r.pos = pos
        return r
    }

    // MARK: - Expect One

    /// Execute rule to match a sequence of tokens.
    private func expectOne(_ rule: Rule, maybe: Bool = false) -> ParseResult {
        var results: [ParseResultItem] = []
        let savedPos = pos
        var allMatches = true
        var oneMatch = false
        let isMaybe = maybe || rule.maybe

        if let expects = rule.expect {
            for next in expects {
                let localPos = pos
                let result = expect(next)

                if result.success {
                    results.append(.single(result))
                    oneMatch = true
                    if rule.or { break }
                } else {
                    allMatches = false
                    if !rule.or {
                        pos = localPos
                        break
                    }
                }
            }
        }

        let gotOne = (rule.or && oneMatch) || allMatches
        let success = gotOne || isMaybe
        let numMatches = gotOne ? 1 : 0
        if isMaybe && !gotOne { pos = savedPos }
        if success {
            matchSuccess()
        } else {
            matchFail(savedPos)
        }

        var r = ParseResult(success: success)
        r.results = results
        r.numMatches = numMatches
        return r
    }

    // MARK: - Expect One Or More

    /// Match one or more instances of the rule.
    private func expectOneOrMore(_ rule: Rule, maybe: Bool = false) -> ParseResult {
        var results: [ParseResultItem] = []
        let savedPos = pos
        var numMatches = 0
        var more = true

        repeat {
            let result = expectOne(rule)
            if result.success && !result.results.isEmpty {
                numMatches += 1
                results.append(.group(result.results))
            } else {
                more = false
            }
        } while more

        let success = numMatches > 0 || maybe
        if maybe && numMatches == 0 { pos = savedPos }
        if success {
            matchSuccess()
        } else {
            matchFail(savedPos)
        }

        var r = ParseResult(success: success)
        r.results = results
        r.numMatches = numMatches
        return r
    }

    // MARK: - Expect Zero Or More

    private func expectZeroOrMore(_ rule: Rule) -> ParseResult {
        expectOneOrMore(rule, maybe: true)
    }

    // MARK: - Expect

    /// Execute the rule produced by the provided rule function.
    private func expect(_ ruleFunc: RuleFunction) -> ParseResult {
        if lastError != nil {
            var failed = ParseResult(success: false)
            failed.pos = pos
            failed.errorPos = errorPos
            failed.parserError = lastError
            return failed
        }

        let rule = ruleFunc()
        var result: ParseResult

        if let token = rule.token {
            // Lexer rule
            result = matchToken(token, noSpace: rule.noSpace)
            if result.success {
                pos += result.incrementPos ?? 0
            }
        } else if rule.expect != nil {
            // Parser rule
            if rule.oneOrMore {
                result = expectOneOrMore(rule)
            } else if rule.zeroOrMore {
                result = expectZeroOrMore(rule)
            } else {
                result = expectOne(rule)
            }
        } else {
            if errorPos == NO_ERROR_POS { errorPos = pos }
            lastError = .invalidGrammarRuleMissingTokenOrExpect
            var failed = ParseResult(success: false)
            failed.pos = pos
            failed.errorPos = errorPos
            failed.parserError = lastError
            return failed
        }

        // Build matches from results
        var matches: [Match] = []
        for r in result.results {
            matches.append(flattenMatches(r))
        }
        result.matches = matches

        // Execute trigger
        if let run = rule.run, result.success {
            run(matches)
        }

        if lastError != nil {
            result.success = false
            result.parserError = lastError
        }

        return result
    }
}
