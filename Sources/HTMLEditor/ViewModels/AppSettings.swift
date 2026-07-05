//
//  AppSettings.swift
//  HTMLEditor
//
//  User preferences, persisted to UserDefaults. A single shared instance is
//  injected into the SwiftUI environment and read by the AppKit editor layer.
//

import AppKit
import Combine
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: - Appearance & theme

    @Published var appearance: AppAppearance { didSet { save(); applyAppearance() } }
    @Published var themeName: String { didSet { save() } }

    // MARK: - Editor

    @Published var fontName: String { didSet { save() } }
    @Published var fontSize: Double { didSet { save() } }
    @Published var editorZoom: Double { didSet { save() } }
    @Published var tabWidth: Int { didSet { save() } }
    @Published var insertSpaces: Bool { didSet { save() } }
    @Published var wordWrap: Bool { didSet { save() } }
    @Published var showLineNumbers: Bool { didSet { save() } }
    @Published var highlightCurrentLine: Bool { didSet { save() } }
    @Published var autoCloseTags: Bool { didSet { save() } }
    @Published var autoCloseBrackets: Bool { didSet { save() } }
    @Published var autoIndent: Bool { didSet { save() } }
    @Published var showCompletions: Bool { didSet { save() } }

    // MARK: - Files & session

    @Published var autoSave: Bool { didSet { save() } }
    @Published var autoSaveInterval: Double { didSet { save() } }
    @Published var restoreSession: Bool { didSet { save() } }

    // MARK: - Preview

    @Published var livePreview: Bool { didSet { save() } }
    @Published var previewDelay: Double { didSet { save() } }

    // MARK: - Derived

    var theme: EditorTheme { ThemeManager.theme(named: themeName) }

    /// Editor font with zoom applied; falls back to the system mono font.
    var editorFont: NSFont {
        let size = max(8, fontSize * editorZoom)
        if let font = NSFont(name: fontName, size: size) { return font }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// One level of indentation as text.
    var indentUnit: String {
        insertSpaces ? String(repeating: " ", count: max(1, tabWidth)) : "\t"
    }

    func zoomIn() { editorZoom = min(3.0, editorZoom + 0.1) }
    func zoomOut() { editorZoom = max(0.5, editorZoom - 0.1) }
    func zoomReset() { editorZoom = 1.0 }

    // MARK: - Persistence

    private struct Keys {
        static let store = "appSettings.v1"
    }

    private struct Snapshot: Codable {
        var appearance: String
        var themeName: String
        var fontName: String
        var fontSize: Double
        var editorZoom: Double
        var tabWidth: Int
        var insertSpaces: Bool
        var wordWrap: Bool
        var showLineNumbers: Bool
        var highlightCurrentLine: Bool
        var autoCloseTags: Bool
        var autoCloseBrackets: Bool
        var autoIndent: Bool
        var showCompletions: Bool
        var autoSave: Bool
        var autoSaveInterval: Double
        var restoreSession: Bool
        var livePreview: Bool
        var previewDelay: Double
    }

    private var isLoading = true

    private init() {
        let snap: Snapshot?
        if let data = UserDefaults.standard.data(forKey: Keys.store) {
            snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        } else {
            snap = nil
        }
        appearance = AppAppearance(rawValue: snap?.appearance ?? "system") ?? .system
        themeName = snap?.themeName ?? "Aurora Dark"
        fontName = snap?.fontName ?? "SF Mono"
        fontSize = snap?.fontSize ?? 13
        editorZoom = snap?.editorZoom ?? 1.0
        tabWidth = snap?.tabWidth ?? 4
        insertSpaces = snap?.insertSpaces ?? true
        wordWrap = snap?.wordWrap ?? true
        showLineNumbers = snap?.showLineNumbers ?? true
        highlightCurrentLine = snap?.highlightCurrentLine ?? true
        autoCloseTags = snap?.autoCloseTags ?? true
        autoCloseBrackets = snap?.autoCloseBrackets ?? true
        autoIndent = snap?.autoIndent ?? true
        showCompletions = snap?.showCompletions ?? true
        autoSave = snap?.autoSave ?? true
        autoSaveInterval = snap?.autoSaveInterval ?? 30
        restoreSession = snap?.restoreSession ?? true
        livePreview = snap?.livePreview ?? true
        previewDelay = snap?.previewDelay ?? 0.25
        isLoading = false
        applyAppearance()
    }

    private func save() {
        guard !isLoading else { return }
        let snap = Snapshot(
            appearance: appearance.rawValue,
            themeName: themeName,
            fontName: fontName,
            fontSize: fontSize,
            editorZoom: editorZoom,
            tabWidth: tabWidth,
            insertSpaces: insertSpaces,
            wordWrap: wordWrap,
            showLineNumbers: showLineNumbers,
            highlightCurrentLine: highlightCurrentLine,
            autoCloseTags: autoCloseTags,
            autoCloseBrackets: autoCloseBrackets,
            autoIndent: autoIndent,
            showCompletions: showCompletions,
            autoSave: autoSave,
            autoSaveInterval: autoSaveInterval,
            restoreSession: restoreSession,
            livePreview: livePreview,
            previewDelay: previewDelay
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Keys.store)
        }
    }

    private func applyAppearance() {
        switch appearance {
        case .system: NSApp?.appearance = nil
        case .light: NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
