//
//  SyntaxHighlighterTests.swift
//  HTMLEditorTests
//
//  Behavior tests for the tokenizer: token classification for HTML with
//  embedded CSS/JS, plus structural invariants (no overlapping tokens,
//  large-file guard).
//

import XCTest
@testable import HTMLEditor

final class SyntaxHighlighterTests: XCTestCase {

    /// Maps tokens to (substring, type) pairs for easy assertions.
    private func lexemes(_ text: String, _ language: Language) -> [(String, TokenType)] {
        let ns = text as NSString
        return SyntaxHighlighter.tokens(in: text, language: language)
            .map { (ns.substring(with: $0.range), $0.type) }
    }

    private func assertContains(
        _ tokens: [(String, TokenType)],
        _ lexeme: String,
        _ type: TokenType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            tokens.contains { $0.0 == lexeme && $0.1 == type },
            "expected \(type) token '\(lexeme)' in \(tokens)",
            file: file, line: line
        )
    }

    // MARK: - HTML

    func testTagAttributeAndValue() {
        let tokens = lexemes(#"<a href="page.html" class="btn">Go</a>"#, .html)
        assertContains(tokens, "<a", .tag)
        assertContains(tokens, "href", .attributeName)
        assertContains(tokens, "\"page.html\"", .attributeValue)
        assertContains(tokens, "class", .attributeName)
        assertContains(tokens, "</a", .tag)
    }

    func testCommentBeatsTagColoring() {
        let tokens = lexemes("<!-- <div> not a tag --><p>x</p>", .html)
        assertContains(tokens, "<!-- <div> not a tag -->", .comment)
        assertContains(tokens, "<p", .tag)
        // The <div> inside the comment must not appear as a tag token.
        XCTAssertFalse(tokens.contains { $0.0 == "<div" && $0.1 == .tag })
    }

    func testDoctypeAndEntity() {
        let tokens = lexemes("<!DOCTYPE html><p>a &amp; b</p>", .html)
        assertContains(tokens, "<!DOCTYPE html>", .doctype)
        assertContains(tokens, "&amp;", .entity)
    }

    // MARK: - Embedded languages

    func testScriptBlockGetsJavaScriptTokens() {
        let html = """
        <script>
        // note
        const n = 42;
        </script>
        """
        let tokens = lexemes(html, .html)
        assertContains(tokens, "<script", .tag)
        assertContains(tokens, "// note", .comment)
        assertContains(tokens, "const", .keyword)
        assertContains(tokens, "42", .number)
        assertContains(tokens, "</script", .tag)
    }

    func testStyleBlockGetsCSSTokens() {
        let html = """
        <style>
        body { color: #ff0000; margin: 8px; }
        </style>
        """
        let tokens = lexemes(html, .html)
        assertContains(tokens, "color", .cssProperty)
        assertContains(tokens, "margin", .cssProperty)
        assertContains(tokens, "#ff0000", .number)
        XCTAssertTrue(
            tokens.contains { $0.0.contains("body") && $0.1 == .cssSelector },
            "expected a selector token covering 'body'"
        )
    }

    // MARK: - Standalone languages

    func testStandaloneCSS() {
        let tokens = lexemes("/* c */ .card { display: flex; }", .css)
        assertContains(tokens, "/* c */", .comment)
        assertContains(tokens, "display", .cssProperty)
    }

    func testStandaloneJavaScriptStrings() {
        let tokens = lexemes(#"let s = "hi"; let t = `tpl`;"#, .javascript)
        assertContains(tokens, "\"hi\"", .string)
        assertContains(tokens, "`tpl`", .string)
        assertContains(tokens, "let", .keyword)
    }

    // MARK: - Invariants

    func testTokensNeverOverlap() {
        let html = """
        <!DOCTYPE html><!-- comment with <b> -->
        <html><head><style>a:hover { color: red; }</style>
        <script>const x = "</fake>"; // tricky</script></head>
        <body class="main">&copy; <b>bold</b></body></html>
        """
        let tokens = SyntaxHighlighter.tokens(in: html, language: .html)
            .sorted { $0.range.location < $1.range.location }
        for (previous, next) in zip(tokens, tokens.dropFirst()) {
            XCTAssertLessThanOrEqual(
                NSMaxRange(previous.range), next.range.location,
                "overlapping tokens: \(previous.range) and \(next.range)"
            )
        }
    }

    func testHugeDocumentSkipsHighlighting() {
        // ~4.8M characters: above the guard threshold → no tokens, fast.
        let huge = String(repeating: "<div>abc</div>", count: 400_000)
        XCTAssertTrue(SyntaxHighlighter.tokens(in: huge, language: .html).isEmpty)
    }

    func testEmptyDocument() {
        XCTAssertTrue(SyntaxHighlighter.tokens(in: "", language: .html).isEmpty)
    }
}
