//
//  SyntaxHighlighter.swift
//  HTMLEditor
//
//  Regex-based tokenizer for HTML with embedded CSS (<style>) and
//  JavaScript (<script>). Produces (range, token) pairs; a claimed-range
//  index set guarantees tokens never overlap, so priority is simply the
//  order in which passes run (comments first, plain tags last).
//
//  Tokenizing runs off the main thread (see HighlightEngine below); only
//  attribute application touches the text storage.
//

import AppKit

struct SyntaxToken {
    let range: NSRange
    let type: TokenType
}

enum SyntaxHighlighter {

    // MARK: - Compiled patterns

    private static func rx(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        // Patterns are static and known-valid; crash early in development if not.
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let htmlComment = rx(#"<!--[\s\S]*?-->"#)
    private static let doctype = rx(#"<!DOCTYPE[^>]*>"#, [.caseInsensitive])
    private static let scriptBlock = rx(#"(<script\b[^>]*>)([\s\S]*?)(</script\s*>)"#, [.caseInsensitive])
    private static let styleBlock = rx(#"(<style\b[^>]*>)([\s\S]*?)(</style\s*>)"#, [.caseInsensitive])
    private static let htmlTag = rx(#"</?[a-zA-Z][\w.:-]*(?:"[^"]*"|'[^']*'|[^>"'])*/?>?"#)
    private static let tagName = rx(#"</?[a-zA-Z][\w.:-]*"#)
    private static let attrName = rx(#"[\w-]+(?=\s*=)"#)
    private static let quoted = rx(#""[^"]*"|'[^']*'"#)
    private static let entity = rx(#"&#?\w+;"#)

    private static let jsLineComment = rx(#"//[^\n]*"#)
    private static let jsBlockComment = rx(#"/\*[\s\S]*?\*/"#)
    private static let jsString = rx(#""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`"#)
    private static let jsKeyword = rx(#"\b(?:var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|typeof|instanceof|in|of|class|extends|super|this|import|export|from|default|try|catch|finally|throw|async|await|yield|delete|void|null|undefined|true|false|document|window|console)\b"#)
    private static let jsNumber = rx(#"\b\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?\b|\b0[xX][0-9a-fA-F]+\b"#)

    private static let cssComment = rx(#"/\*[\s\S]*?\*/"#)
    private static let cssString = rx(#""[^"\n]*"|'[^'\n]*'"#)
    private static let cssAtRule = rx(#"@[\w-]+"#)
    private static let cssSelector = rx(#"[^{}@/;]+(?=\s*\{)"#)
    private static let cssProperty = rx(#"(?<=[{;])\s*([-a-zA-Z]+)(?=\s*:)|^\s*([-a-zA-Z]+)(?=\s*:)"#)
    private static let cssColorOrNumber = rx(#"#[0-9a-fA-F]{3,8}\b|\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|vmin|vmax|s|ms|fr|deg|pt|ch|ex)?\b"#)
    private static let cssImportant = rx(#"!important\b"#)

    // MARK: - Public API

    /// Tokenizes `text` for `language`. Safe to call from any thread.
    static func tokens(in text: String, language: Language) -> [SyntaxToken] {
        let ns = text as NSString
        // Very large buffers: skip highlighting entirely to stay responsive.
        guard ns.length > 0, ns.length < 4_000_000 else { return [] }

        var state = Tokenizer(ns: ns)
        let full = NSRange(location: 0, length: ns.length)

        switch language {
        case .html, .plain:
            tokenizeHTML(&state, in: full)
        case .css:
            tokenizeCSS(&state, in: full)
        case .javascript, .json:
            tokenizeJS(&state, in: full)
        }
        return state.tokens
    }

    // MARK: - Tokenizer state

    private struct Tokenizer {
        let ns: NSString
        var claimed = IndexSet()
        var tokens: [SyntaxToken] = []

        var string: String { ns as String }

        /// Adds a token if its range does not overlap anything already claimed.
        mutating func claim(_ range: NSRange, _ type: TokenType) {
            guard range.length > 0, let r = Range(range) else { return }
            guard !claimed.intersects(integersIn: r) else { return }
            claimed.insert(integersIn: r)
            tokens.append(SyntaxToken(range: range, type: type))
        }

        /// Reserves a range without emitting a token (e.g. script/style bodies
        /// after their sub-language tokens are placed).
        mutating func reserve(_ range: NSRange) {
            guard range.length > 0, let r = Range(range) else { return }
            claimed.insert(integersIn: r)
        }

        func isFree(_ range: NSRange) -> Bool {
            guard let r = Range(range) else { return false }
            return !claimed.intersects(integersIn: r)
        }
    }

    // MARK: - HTML

    private static func tokenizeHTML(_ state: inout Tokenizer, in range: NSRange) {
        let text = state.string

        htmlComment.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .comment) }
        }
        doctype.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .doctype) }
        }

        // Embedded JavaScript.
        scriptBlock.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let m = match, state.isFree(m.range) else { return }
            tokenizeTagInternals(&state, tag: m.range(at: 1))
            tokenizeJS(&state, in: m.range(at: 2))
            state.reserve(m.range(at: 2))
            tokenizeTagInternals(&state, tag: m.range(at: 3))
        }

        // Embedded CSS.
        styleBlock.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let m = match, state.isFree(m.range) else { return }
            tokenizeTagInternals(&state, tag: m.range(at: 1))
            tokenizeCSS(&state, in: m.range(at: 2))
            state.reserve(m.range(at: 2))
            tokenizeTagInternals(&state, tag: m.range(at: 3))
        }

        // Remaining tags.
        htmlTag.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let m = match, state.isFree(m.range) else { return }
            tokenizeTagInternals(&state, tag: m.range)
        }

        // Entities in text content.
        entity.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .entity) }
        }
    }

    /// Colors the pieces inside a single `<tag attr="value">` span.
    private static func tokenizeTagInternals(_ state: inout Tokenizer, tag: NSRange) {
        guard tag.length > 0 else { return }
        let text = state.string

        tagName.enumerateMatches(in: text, range: tag) { match, _, _ in
            if let m = match { state.claim(m.range, .tag) }
        }
        quoted.enumerateMatches(in: text, range: tag) { match, _, _ in
            if let m = match { state.claim(m.range, .attributeValue) }
        }
        attrName.enumerateMatches(in: text, range: tag) { match, _, _ in
            if let m = match { state.claim(m.range, .attributeName) }
        }
        // Reserve the rest of the tag (>, =, whitespace) so entity/text passes
        // skip it; punctuation keeps the default text color.
        state.reserve(tag)
    }

    // MARK: - JavaScript

    private static func tokenizeJS(_ state: inout Tokenizer, in range: NSRange) {
        guard range.length > 0 else { return }
        let text = state.string

        jsBlockComment.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .comment) }
        }
        jsLineComment.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .comment) }
        }
        jsString.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .string) }
        }
        jsKeyword.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .keyword) }
        }
        jsNumber.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .number) }
        }
    }

    // MARK: - CSS

    private static func tokenizeCSS(_ state: inout Tokenizer, in range: NSRange) {
        guard range.length > 0 else { return }
        let text = state.string

        cssComment.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .comment) }
        }
        cssString.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .string) }
        }
        cssAtRule.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .keyword) }
        }
        cssSelector.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .cssSelector) }
        }
        cssProperty.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let m = match else { return }
            let group = m.range(at: 1).isValid && m.range(at: 1).length > 0
                ? m.range(at: 1) : m.range(at: 2)
            if group.isValid { state.claim(group, .cssProperty) }
        }
        cssImportant.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .keyword) }
        }
        cssColorOrNumber.enumerateMatches(in: text, range: range) { match, _, _ in
            if let m = match { state.claim(m.range, .number) }
        }
    }
}

// MARK: - HighlightEngine

/// Debounces edits, tokenizes on a background queue and applies colors on the
/// main thread. A version counter discards stale results when the user keeps
/// typing while a pass is in flight.
@MainActor
final class HighlightEngine {

    private var version = 0
    private let queue = DispatchQueue(label: "editor.highlight", qos: .userInitiated)
    private var pending: DispatchWorkItem?

    /// Schedules a re-highlight for the text view's current content.
    func invalidate(textView: NSTextView, language: Language, settings: AppSettings) {
        version &+= 1
        let currentVersion = version
        let snapshot = textView.string
        let theme = settings.theme
        let font = settings.editorFont

        pending?.cancel()
        let work = DispatchWorkItem { [weak self, weak textView] in
            let tokens = SyntaxHighlighter.tokens(in: snapshot, language: language)
            Task { @MainActor in
                guard let self, let textView else { return }
                guard currentVersion == self.version,
                      let storage = textView.textStorage,
                      storage.length == (snapshot as NSString).length
                else { return }
                Self.apply(tokens, to: storage, theme: theme, font: font)
            }
        }
        pending = work
        queue.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    /// Applies base attributes and token colors in one editing transaction.
    private static func apply(
        _ tokens: [SyntaxToken],
        to storage: NSTextStorage,
        theme: EditorTheme,
        font: NSFont
    ) {
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([
            .foregroundColor: theme.foregroundColor,
            .font: font
        ], range: full)
        for token in tokens where NSMaxRange(token.range) <= storage.length {
            storage.addAttribute(
                .foregroundColor,
                value: theme.color(for: token.type),
                range: token.range
            )
        }
        storage.endEditing()
    }
}
