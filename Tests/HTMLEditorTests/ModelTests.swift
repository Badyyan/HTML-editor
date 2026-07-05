//
//  ModelTests.swift
//  HTMLEditorTests
//
//  Tests for models, settings-independent helpers and completion catalogs.
//

import XCTest
@testable import HTMLEditor

// MARK: - Language

final class LanguageTests: XCTestCase {

    func testDetection() {
        XCTAssertEqual(Language.detect(from: URL(fileURLWithPath: "/a/index.html")), .html)
        XCTAssertEqual(Language.detect(from: URL(fileURLWithPath: "/a/style.css")), .css)
        XCTAssertEqual(Language.detect(from: URL(fileURLWithPath: "/a/app.js")), .javascript)
        XCTAssertEqual(Language.detect(from: URL(fileURLWithPath: "/a/data.json")), .json)
        XCTAssertEqual(Language.detect(from: URL(fileURLWithPath: "/a/readme.txt")), .plain)
        XCTAssertEqual(Language.detect(from: nil), .html) // untitled buffers
    }
}

// MARK: - Themes

final class ThemeTests: XCTestCase {

    func testJSONRoundTrip() throws {
        let original = EditorTheme.midnight
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EditorTheme.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testHexColorParsing() {
        let red = NSColor(hex: "#FF0000")
        XCTAssertEqual(red.redComponent, 1.0, accuracy: 0.001)
        XCTAssertEqual(red.greenComponent, 0.0, accuracy: 0.001)

        let translucent = NSColor(hex: "#00FF0080")
        XCTAssertEqual(translucent.greenComponent, 1.0, accuracy: 0.001)
        XCTAssertEqual(translucent.alphaComponent, 128.0 / 255.0, accuracy: 0.01)
    }

    func testUnknownTokenFallsBackToForeground() {
        var theme = EditorTheme.auroraLight
        theme.tokens = [:]
        XCTAssertEqual(theme.color(for: .keyword), theme.foregroundColor)
    }

    func testBuiltInThemeLookup() {
        XCTAssertEqual(ThemeManager.theme(named: "Aurora Light").name, "Aurora Light")
        // Unknown names fall back to a usable default rather than crashing.
        XCTAssertFalse(ThemeManager.theme(named: "Nope").name.isEmpty)
    }
}

// MARK: - Documents

final class DocumentTests: XCTestCase {

    @MainActor
    func testDirtyTracking() {
        let document = Document(text: "a")
        XCTAssertFalse(document.isModified)
        document.text = "ab"
        XCTAssertTrue(document.isModified)
    }

    @MainActor
    func testSaveAndReopenRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("t-\(UUID().uuidString).html")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = Document(text: "<p>héllo</p>")
        document.text = "<p>héllo</p>"
        try document.save(to: url)
        XCTAssertFalse(document.isModified)
        XCTAssertEqual(document.language, .html)

        let reopened = try Document.open(url: url)
        XCTAssertEqual(reopened.text, "<p>héllo</p>")
        XCTAssertFalse(reopened.isModified)
    }

    @MainActor
    func testUntitledDefaults() {
        let document = Document()
        XCTAssertEqual(document.displayName, "Untitled.html")
        XCTAssertNil(document.baseURL)
    }
}

// MARK: - Completion catalogs

final class CompletionDataTests: XCTestCase {

    func testTagSpecificAttributesIncludeGlobals() {
        let attributes = CompletionData.attributes(for: "img")
        XCTAssertTrue(attributes.contains("src"))
        XCTAssertTrue(attributes.contains("alt"))
        XCTAssertTrue(attributes.contains("class")) // global
    }

    func testVoidTags() {
        XCTAssertTrue(CompletionData.voidTags.contains("br"))
        XCTAssertTrue(CompletionData.voidTags.contains("img"))
        XCTAssertFalse(CompletionData.voidTags.contains("div"))
    }

    func testSnippetTriggersAreUnique() {
        let triggers = CompletionData.snippets.map(\.trigger)
        XCTAssertEqual(triggers.count, Set(triggers).count)
    }

    func testCatalogsAreSorted() {
        XCTAssertEqual(CompletionData.cssProperties, CompletionData.cssProperties.sorted())
    }
}

// MARK: - Helpers

final class ExtensionTests: XCTestCase {

    func testLineAndColumn() {
        let text = "ab\ncd" as NSString
        XCTAssertEqual(text.lineAndColumn(for: 0).line, 1)
        XCTAssertEqual(text.lineAndColumn(for: 0).column, 1)
        XCTAssertEqual(text.lineAndColumn(for: 4).line, 2)
        XCTAssertEqual(text.lineAndColumn(for: 4).column, 2)
        // Past-the-end locations clamp instead of crashing.
        XCTAssertEqual(text.lineAndColumn(for: 99).line, 2)
    }

    func testLeadingIndentation() {
        XCTAssertEqual("  \t<div>".leadingIndentation, "  \t")
        XCTAssertEqual("x".leadingIndentation, "")
        XCTAssertEqual("".leadingIndentation, "")
    }
}
