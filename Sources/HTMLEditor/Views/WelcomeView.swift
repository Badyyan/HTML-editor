//
//  WelcomeView.swift
//  HTMLEditor
//
//  Shown when no tabs are open: quick actions + recent projects.
//

import SwiftUI

struct WelcomeView: View {

    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 54, weight: .medium))
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("HTML Editor")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Build and preview web pages with live feedback.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    workspace.newUntitledDocument()
                } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                        .frame(width: 150)
                }
                .keyboardShortcut("n")

                Button {
                    workspace.openFolderPanel()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                        .frame(width: 150)
                }
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            if !workspace.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Projects")
                        .font(.headline)
                    ForEach(workspace.recentProjects.prefix(5), id: \.self) { url in
                        Button {
                            workspace.openFolder(url)
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(url.lastPathComponent)
                                Text(url.deletingLastPathComponent().path)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .frame(maxWidth: 420, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.quaternary.opacity(0.4))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
