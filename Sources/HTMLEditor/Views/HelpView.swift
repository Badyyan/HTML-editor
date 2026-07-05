//
//  HelpView.swift
//  HTMLEditor
//
//  Keyboard shortcut reference window.
//

import SwiftUI

struct HelpView: View {

    private let shortcuts: [(String, String)] = [
        ("⌘N", "New tab"),
        ("⌘O", "Open file"),
        ("⇧⌘O", "Open folder"),
        ("⌘S", "Save"),
        ("⇧⌘S", "Save As…"),
        ("⌘W", "Close tab"),
        ("⌘F", "Find & Replace"),
        ("⌘G / ⇧⌘G", "Next / previous match"),
        ("⌘R", "Refresh preview"),
        ("⌥⌘P", "Toggle preview pane"),
        ("⌥⌘B", "Open in browser"),
        ("⇧⌘C", "Copy generated HTML"),
        ("⌘+ / ⌘− / ⌘0", "Zoom in / out / reset"),
        ("⌘Z / ⇧⌘Z", "Undo / Redo"),
        ("⌃⌘F", "Toggle full screen"),
        ("⌘,", "Settings"),
        ("⎋", "Dismiss completions / find bar")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Keyboard Shortcuts", systemImage: "keyboard")
                .font(.title2.bold())

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 7) {
                ForEach(shortcuts, id: \.0) { key, action in
                    GridRow {
                        Text(key)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(action)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            Text("Tips")
                .font(.headline)
            VStack(alignment: .leading, spacing: 5) {
                Text("• Type `<` to see tag completions; type a space inside a tag for attributes.")
                Text("• Type `html5` in an empty file and accept the snippet for a full boilerplate.")
                Text("• Typing `>` after an opening tag inserts the closing tag automatically.")
                Text("• Custom themes: Settings ▸ Themes ▸ Open Themes Folder.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 420)
    }
}
