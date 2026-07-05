//
//  ContentView.swift
//  HTMLEditor
//
//  Main window: sidebar + (tabs / editor / preview split) + status bar,
//  with the native toolbar.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let openPreviewWindow = Notification.Name("openPreviewWindow")
    static let openHelpWindow = Notification.Name("openHelpWindow")
}

struct ContentView: View {

    @EnvironmentObject private var workspace: Workspace
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 380)
        } detail: {
            VStack(spacing: 0) {
                EditorTabsView()
                Divider()
                if workspace.isFindBarVisible {
                    FindReplaceBar()
                    Divider()
                }
                mainSplit
                Divider()
                StatusBarView()
            }
        }
        .navigationTitle(workspace.activeDocument?.displayName ?? "HTML Editor")
        .toolbar { toolbarContent }
        .onReceive(NotificationCenter.default.publisher(for: .openPreviewWindow)) { _ in
            openWindow(id: "preview")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openHelpWindow)) { _ in
            openWindow(id: "help")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            workspace.handleDrop(of: providers)
        }
        .alert(
            "HTML Editor",
            isPresented: Binding(
                get: { workspace.errorMessage != nil },
                set: { if !$0 { workspace.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspace.errorMessage ?? "")
        }
        .frame(minWidth: 1000, minHeight: 620)
    }

    // MARK: - Editor / preview split

    @ViewBuilder
    private var mainSplit: some View {
        if let document = workspace.activeDocument {
            HSplitView {
                CodeEditorView(
                    document: document, settings: settings, workspace: workspace
                )
                .id(document.id)
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)

                if workspace.isPreviewVisible {
                    PreviewPane()
                        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            WelcomeView()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                workspace.openFolderPanel()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open a folder (⇧⌘O) or file (⌘O)")

            Button {
                workspace.saveActiveDocument()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save (⌘S)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                withAnimation { workspace.isFindBarVisible.toggle() }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .help("Find & Replace (⌘F)")

            Button {
                workspace.refreshPreview()
                workspace.refreshFileTree()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh preview and file tree (⌘R)")

            Button {
                withAnimation { workspace.isPreviewVisible.toggle() }
            } label: {
                Label("Preview", systemImage: workspace.isPreviewVisible
                      ? "eye.fill" : "eye")
            }
            .help("Toggle live preview (⌥⌘P)")

            Button {
                workspace.openInBrowser()
            } label: {
                Label("Browser", systemImage: "safari")
            }
            .help("Open in default browser")

            if let url = workspace.shareableURL {
                ShareLink(item: url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share current file")
            }

            Button {
                SettingsOpener.open()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Settings (⌘,)")

            Button {
                NotificationCenter.default.post(name: .openHelpWindow, object: nil)
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
            .help("Keyboard shortcuts & help")
        }
    }
}

/// Opens the SwiftUI Settings scene. On macOS 13+ the menu item action is
/// "showSettingsWindow:"; sending it to the responder chain is the reliable
/// route from toolbar code.
enum SettingsOpener {
    @MainActor static func open() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
