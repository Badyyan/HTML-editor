//
//  StatusBarView.swift
//  HTMLEditor
//
//  Bottom status bar: language | encoding | caret position | indentation |
//  zoom | preview toggle.
//

import SwiftUI

struct StatusBarView: View {

    @EnvironmentObject private var workspace: Workspace
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 14) {
            Label(
                workspace.activeDocument?.language.displayName ?? "—",
                systemImage: "chevron.left.forwardslash.chevron.right"
            )

            Text("UTF-8")

            Text("Ln \(workspace.cursorLine), Col \(workspace.cursorColumn)")
                .monospacedDigit()

            Text(settings.insertSpaces
                 ? "Spaces: \(settings.tabWidth)"
                 : "Tabs")

            if workspace.activeDocument?.isModified == true {
                Label("Edited", systemImage: "pencil")
                    .foregroundStyle(.orange)
            }

            Spacer()

            HStack(spacing: 6) {
                Button { settings.zoomOut() } label: {
                    Image(systemName: "minus")
                }
                .help("Zoom out (⌘−)")
                Text("\(Int(settings.editorZoom * 100))%")
                    .monospacedDigit()
                    .frame(width: 40)
                Button { settings.zoomIn() } label: {
                    Image(systemName: "plus")
                }
                .help("Zoom in (⌘+)")
            }

            Toggle(isOn: $settings.wordWrap) {
                Image(systemName: "text.wordspacing")
            }
            .toggleStyle(.button)
            .help("Word wrap")

            Toggle(isOn: $workspace.isPreviewVisible) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .help("Toggle preview pane")
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
