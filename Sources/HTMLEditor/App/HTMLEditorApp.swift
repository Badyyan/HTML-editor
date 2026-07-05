//
//  HTMLEditorApp.swift
//  HTMLEditor
//
//  App entry point: main window, stand-alone preview window, help window
//  and the Settings scene.
//

import SwiftUI
import AppKit

@main
struct HTMLEditorApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var workspace: Workspace
    @StateObject private var settings: AppSettings

    init() {
        let ws = Workspace()
        _workspace = StateObject(wrappedValue: ws)
        _settings = StateObject(wrappedValue: AppSettings.shared)
        AppDelegate.workspace = ws
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspace)
                .environmentObject(settings)
        }
        .commands {
            AppCommands(workspace: workspace, settings: settings)
        }

        WindowGroup(id: "preview") {
            PreviewWindowView()
                .environmentObject(workspace)
                .environmentObject(settings)
        }

        WindowGroup(id: "help") {
            HelpView()
                .environmentObject(settings)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

/// AppKit-side lifecycle hooks: saves the session and modified files on quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    static weak var workspace: Workspace?

    nonisolated func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.workspace?.persistSession()
        if AppSettings.shared.autoSave {
            Self.workspace?.saveAllModified()
        }
    }
}
