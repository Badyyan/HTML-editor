//
//  SettingsView.swift
//  HTMLEditor
//
//  Preferences window (⌘,): General, Editor, Themes, Preview.
//

import SwiftUI
import AppKit

struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            EditorSettings()
                .tabItem { Label("Editor", systemImage: "text.cursor") }
            ThemeSettings()
                .tabItem { Label("Themes", systemImage: "paintpalette") }
            PreviewSettings()
                .tabItem { Label("Preview", systemImage: "eye") }
        }
        .frame(width: 460)
        .padding(.bottom, 8)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Auto save open files", isOn: $settings.autoSave)
            if settings.autoSave {
                Slider(value: $settings.autoSaveInterval, in: 5...120, step: 5) {
                    Text("Every \(Int(settings.autoSaveInterval))s")
                }
            }
            Toggle("Restore session at launch", isOn: $settings.restoreSession)
        }
        .padding(20)
    }
}

// MARK: - Editor

private struct EditorSettings: View {
    @EnvironmentObject private var settings: AppSettings

    private let fontOptions = ["SF Mono", "Menlo", "Monaco", "Courier New"]

    var body: some View {
        Form {
            Picker("Font", selection: $settings.fontName) {
                ForEach(fontOptions, id: \.self) { Text($0) }
            }
            Stepper(
                "Font size: \(Int(settings.fontSize)) pt",
                value: $settings.fontSize, in: 9...28
            )
            Stepper(
                "Tab width: \(settings.tabWidth)",
                value: $settings.tabWidth, in: 2...8
            )
            Toggle("Insert spaces instead of tabs", isOn: $settings.insertSpaces)

            Divider()

            Toggle("Word wrap", isOn: $settings.wordWrap)
            Toggle("Show line numbers", isOn: $settings.showLineNumbers)
            Toggle("Highlight current line", isOn: $settings.highlightCurrentLine)

            Divider()

            Toggle("Auto indent", isOn: $settings.autoIndent)
            Toggle("Auto-close brackets and quotes", isOn: $settings.autoCloseBrackets)
            Toggle("Auto-close HTML tags", isOn: $settings.autoCloseTags)
            Toggle("Show completions while typing", isOn: $settings.showCompletions)
        }
        .padding(20)
    }
}

// MARK: - Themes

private struct ThemeSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var themes = ThemeManager.allThemes()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editor Theme")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 10) {
                ForEach(themes) { theme in
                    ThemeSwatch(
                        theme: theme,
                        isSelected: theme.name == settings.themeName
                    )
                    .onTapGesture { settings.themeName = theme.name }
                }
            }

            Divider()

            HStack {
                Button("Reload Themes") { themes = ThemeManager.allThemes() }
                Button("Open Themes Folder") {
                    ThemeManager.writeSampleThemeIfNeeded()
                    NSWorkspace.shared.open(ThemeManager.themesDirectory)
                }
            }
            Text("Drop .json theme files into the themes folder to add custom themes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

private struct ThemeSwatch: View {
    let theme: EditorTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Miniature code preview using the theme's own colors.
            VStack(alignment: .leading, spacing: 3) {
                swatchLine(theme.color(for: .tag), width: 60)
                swatchLine(theme.color(for: .attributeName), width: 84)
                swatchLine(theme.color(for: .string), width: 48)
                swatchLine(theme.color(for: .comment), width: 72)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: theme.backgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(theme.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
    }

    private func swatchLine(_ color: NSColor, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(nsColor: color))
            .frame(width: width, height: 5)
    }
}

// MARK: - Preview

private struct PreviewSettings: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Live preview while typing", isOn: $settings.livePreview)
            Slider(value: $settings.previewDelay, in: 0.05...2, step: 0.05) {
                Text("Update delay: \(String(format: "%.2f", settings.previewDelay))s")
            }
            Text("Lower values feel more instant; higher values reduce work on large pages.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
