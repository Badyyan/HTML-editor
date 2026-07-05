//
//  AppCommands.swift
//  HTMLEditor
//
//  Menu bar commands and their keyboard shortcuts.
//

import SwiftUI

struct AppCommands: Commands {

    @ObservedObject var workspace: Workspace
    @ObservedObject var settings: AppSettings

    var body: some Commands {

        // MARK: File

        CommandGroup(replacing: .newItem) {
            Button("New Tab") { workspace.newUntitledDocument() }
                .keyboardShortcut("n")

            Button("Open File…") { workspace.openFilePanel() }
                .keyboardShortcut("o")

            Button("Open Folder…") { workspace.openFolderPanel() }
                .keyboardShortcut("o", modifiers: [.command, .shift])

            Menu("Open Recent Project") {
                ForEach(workspace.recentProjects, id: \.self) { url in
                    Button(url.lastPathComponent) { workspace.openFolder(url) }
                }
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { workspace.saveActiveDocument() }
                .keyboardShortcut("s")
                .disabled(workspace.activeDocument == nil)

            Button("Save As…") { workspace.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(workspace.activeDocument == nil)

            Button("Save All") { workspace.saveAllModified() }
                .keyboardShortcut("s", modifiers: [.command, .option])

            Divider()

            Button("Close Tab") { workspace.closeActiveDocument() }
                .keyboardShortcut("w")
                .disabled(workspace.activeDocument == nil)
        }

        // MARK: Export

        CommandMenu("Export") {
            Button("Export HTML…") { workspace.exportActiveHTML() }
                .disabled(workspace.activeDocument == nil)

            Button("Export Project as Zip…") { workspace.exportProjectArchive() }
                .disabled(workspace.rootFolder == nil)

            Divider()

            Button("Copy Generated HTML") { workspace.copyGeneratedHTML() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(workspace.activeDocument == nil)
        }

        // MARK: Find

        CommandGroup(replacing: .textEditing) {
            Button("Find & Replace…") { workspace.isFindBarVisible = true }
                .keyboardShortcut("f")

            Button("Find Next") { workspace.activeEditor?.findNext() }
                .keyboardShortcut("g")

            Button("Find Previous") { workspace.activeEditor?.findPrevious() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        // MARK: View

        CommandGroup(after: .toolbar) {
            Button(workspace.isPreviewVisible ? "Hide Preview" : "Show Preview") {
                workspace.isPreviewVisible.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .option])

            Button("Refresh Preview") { workspace.refreshPreview() }
                .keyboardShortcut("r")

            Button("Open Preview in New Window") {
                NotificationCenter.default.post(name: .openPreviewWindow, object: nil)
            }

            Button("Open in Browser") { workspace.openInBrowser() }
                .keyboardShortcut("b", modifiers: [.command, .option])

            Divider()

            Button("Zoom In") { settings.zoomIn() }
                .keyboardShortcut("+")

            Button("Zoom Out") { settings.zoomOut() }
                .keyboardShortcut("-")

            Button("Reset Zoom") { settings.zoomReset() }
                .keyboardShortcut("0")

            Divider()

            Toggle("Word Wrap", isOn: $settings.wordWrap)
            Toggle("Line Numbers", isOn: $settings.showLineNumbers)
        }

        // MARK: Help

        CommandGroup(replacing: .help) {
            Button("HTML Editor Help") {
                NotificationCenter.default.post(name: .openHelpWindow, object: nil)
            }
            .keyboardShortcut("?")
        }
    }
}
