//
//  EditorTheme.swift
//  HTMLEditor
//
//  Editor color themes: token colors + chrome colors. Themes are Codable so
//  custom themes can be dropped as JSON files into
//  ~/Library/Application Support/HTMLEditor/Themes/.
//

import AppKit

/// Token categories produced by the syntax highlighter.
enum TokenType: String, Codable, CaseIterable {
    case text
    case tag
    case attributeName
    case attributeValue
    case comment
    case keyword
    case string
    case number
    case cssSelector
    case cssProperty
    case cssValue
    case doctype
    case entity
}

struct EditorTheme: Codable, Identifiable, Hashable {
    var id: String { name }

    var name: String
    /// True when the theme is designed for dark backgrounds.
    var isDark: Bool

    // Chrome (stored as hex strings so themes stay plain JSON).
    var background: String
    var foreground: String
    var currentLine: String
    var selection: String
    var gutterBackground: String
    var gutterForeground: String
    var caret: String

    /// Token color table, keyed by TokenType raw value.
    var tokens: [String: String]

    // MARK: - Resolved colors

    var backgroundColor: NSColor { NSColor(hex: background) }
    var foregroundColor: NSColor { NSColor(hex: foreground) }
    var currentLineColor: NSColor { NSColor(hex: currentLine) }
    var selectionColor: NSColor { NSColor(hex: selection) }
    var gutterBackgroundColor: NSColor { NSColor(hex: gutterBackground) }
    var gutterForegroundColor: NSColor { NSColor(hex: gutterForeground) }
    var caretColor: NSColor { NSColor(hex: caret) }

    func color(for token: TokenType) -> NSColor {
        if let hex = tokens[token.rawValue] { return NSColor(hex: hex) }
        return foregroundColor
    }

    // MARK: - Built-in themes

    static let auroraLight = EditorTheme(
        name: "Aurora Light",
        isDark: false,
        background: "#FFFFFF",
        foreground: "#24292F",
        currentLine: "#F3F6FA",
        selection: "#B9D6F2",
        gutterBackground: "#FAFBFC",
        gutterForeground: "#9AA4B2",
        caret: "#0969DA",
        tokens: [
            "tag": "#116329",
            "attributeName": "#953800",
            "attributeValue": "#0A3069",
            "comment": "#6E7781",
            "keyword": "#CF222E",
            "string": "#0A3069",
            "number": "#0550AE",
            "cssSelector": "#116329",
            "cssProperty": "#0550AE",
            "cssValue": "#953800",
            "doctype": "#8250DF",
            "entity": "#8250DF"
        ]
    )

    static let auroraDark = EditorTheme(
        name: "Aurora Dark",
        isDark: true,
        background: "#1E2227",
        foreground: "#D6DEE7",
        currentLine: "#262B33",
        selection: "#31445E",
        gutterBackground: "#1A1E23",
        gutterForeground: "#5B6672",
        caret: "#58A6FF",
        tokens: [
            "tag": "#7EE787",
            "attributeName": "#FFA657",
            "attributeValue": "#A5D6FF",
            "comment": "#767E87",
            "keyword": "#FF7B72",
            "string": "#A5D6FF",
            "number": "#79C0FF",
            "cssSelector": "#7EE787",
            "cssProperty": "#79C0FF",
            "cssValue": "#FFA657",
            "doctype": "#D2A8FF",
            "entity": "#D2A8FF"
        ]
    )

    static let midnight = EditorTheme(
        name: "Midnight",
        isDark: true,
        background: "#12131C",
        foreground: "#C8CCE0",
        currentLine: "#1A1C29",
        selection: "#2E3560",
        gutterBackground: "#0F1017",
        gutterForeground: "#4C5270",
        caret: "#8B9BFF",
        tokens: [
            "tag": "#8B9BFF",
            "attributeName": "#F2B36B",
            "attributeValue": "#8FE0C0",
            "comment": "#5A6080",
            "keyword": "#E77CB6",
            "string": "#8FE0C0",
            "number": "#F2B36B",
            "cssSelector": "#8B9BFF",
            "cssProperty": "#7FD4F5",
            "cssValue": "#F2B36B",
            "doctype": "#B48BFF",
            "entity": "#B48BFF"
        ]
    )

    static let sandstone = EditorTheme(
        name: "Sandstone",
        isDark: false,
        background: "#FBF7EF",
        foreground: "#4A4237",
        currentLine: "#F3EDE0",
        selection: "#E4D6B8",
        gutterBackground: "#F6F1E6",
        gutterForeground: "#A99F8C",
        caret: "#B05A2E",
        tokens: [
            "tag": "#2E6E4E",
            "attributeName": "#B05A2E",
            "attributeValue": "#1E5F8A",
            "comment": "#98917F",
            "keyword": "#A83250",
            "string": "#1E5F8A",
            "number": "#7A4CB0",
            "cssSelector": "#2E6E4E",
            "cssProperty": "#1E5F8A",
            "cssValue": "#B05A2E",
            "doctype": "#7A4CB0",
            "entity": "#7A4CB0"
        ]
    )

    static let builtIn: [EditorTheme] = [auroraLight, auroraDark, midnight, sandstone]
}

/// Loads built-in and user themes. User themes are JSON files with the same
/// shape as EditorTheme, placed in Application Support/HTMLEditor/Themes.
enum ThemeManager {

    static var themesDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return base.appendingPathComponent("HTMLEditor/Themes", isDirectory: true)
    }

    static func allThemes() -> [EditorTheme] {
        var themes = EditorTheme.builtIn
        let fm = FileManager.default
        try? fm.createDirectory(at: themesDirectory, withIntermediateDirectories: true)
        if let files = try? fm.contentsOfDirectory(
            at: themesDirectory, includingPropertiesForKeys: nil
        ) {
            for file in files where file.pathExtension.lowercased() == "json" {
                if let data = try? Data(contentsOf: file),
                   let theme = try? JSONDecoder().decode(EditorTheme.self, from: data),
                   !themes.contains(where: { $0.name == theme.name }) {
                    themes.append(theme)
                }
            }
        }
        return themes
    }

    static func theme(named name: String) -> EditorTheme {
        allThemes().first { $0.name == name } ?? .auroraDark
    }

    /// Writes a starter custom theme so users have an example to edit.
    static func writeSampleThemeIfNeeded() {
        let sample = themesDirectory.appendingPathComponent("My Theme.json")
        guard !FileManager.default.fileExists(atPath: sample.path) else { return }
        try? FileManager.default.createDirectory(
            at: themesDirectory, withIntermediateDirectories: true
        )
        var custom = EditorTheme.midnight
        custom.name = "My Theme"
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(custom) {
            try? data.write(to: sample)
        }
    }
}
