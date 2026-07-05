//
//  SidebarView.swift
//  HTMLEditor
//
//  File explorer sidebar: project tree, assets, favorites and recent files.
//

import SwiftUI
import AppKit

struct SidebarView: View {

    @EnvironmentObject private var workspace: Workspace

    @State private var renamingNode: FileNode?
    @State private var renameText = ""
    @State private var creatingIn: URL?
    @State private var creatingFolder = false
    @State private var newItemName = ""

    var body: some View {
        List {
            projectSection
            assetsSection
            favoritesSection
            recentsSection
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { sidebarFooter }
        // Rename sheet
        .alert("Rename", isPresented: Binding(
            get: { renamingNode != nil },
            set: { if !$0 { renamingNode = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let node = renamingNode, !renameText.isEmpty {
                    workspace.rename(node, to: renameText)
                }
                renamingNode = nil
            }
            Button("Cancel", role: .cancel) { renamingNode = nil }
        }
        // New file/folder sheet
        .alert(creatingFolder ? "New Folder" : "New File", isPresented: Binding(
            get: { creatingIn != nil },
            set: { if !$0 { creatingIn = nil } }
        )) {
            TextField("Name", text: $newItemName)
            Button("Create") {
                if !newItemName.isEmpty {
                    if creatingFolder {
                        workspace.createFolder(named: newItemName, in: creatingIn)
                    } else {
                        workspace.createFile(named: newItemName, in: creatingIn)
                    }
                }
                creatingIn = nil
            }
            Button("Cancel", role: .cancel) { creatingIn = nil }
        }
    }

    // MARK: - Sections

    private var projectSection: some View {
        Section {
            if workspace.fileTree.isEmpty {
                if workspace.rootFolder == nil {
                    Button {
                        workspace.openFolderPanel()
                    } label: {
                        Label("Open Folder…", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Empty folder")
                        .foregroundStyle(.secondary)
                }
            } else {
                OutlineGroup(workspace.fileTree, children: \.children) { node in
                    fileRow(node)
                }
            }
        } header: {
            HStack {
                Text(workspace.rootFolder?.lastPathComponent ?? "Project Files")
                Spacer()
                if workspace.rootFolder != nil {
                    Button {
                        newItemName = "untitled.html"
                        creatingFolder = false
                        creatingIn = workspace.rootFolder
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .buttonStyle(.plain)
                    .help("New file in project root")
                    Button {
                        workspace.refreshFileTree()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                }
            }
        }
    }

    /// Non-code assets (images etc.) collected from the tree.
    private var assetsSection: some View {
        let assets = FileTreeBuilder.flatFiles(in: workspace.fileTree)
            .filter(\.isImage)
        return Group {
            if !assets.isEmpty {
                Section("Assets") {
                    ForEach(assets.prefix(30)) { node in
                        Label(node.name, systemImage: node.symbolName)
                            .onTapGesture { NSWorkspace.shared.open(node.url) }
                            .help(node.url.path)
                    }
                }
            }
        }
    }

    private var favoritesSection: some View {
        Group {
            if !workspace.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(workspace.favorites, id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: "star.fill")
                            .onTapGesture { workspace.open(fileAt: url) }
                            .contextMenu {
                                Button("Remove from Favorites") {
                                    workspace.toggleFavorite(url)
                                }
                            }
                    }
                }
            }
        }
    }

    private var recentsSection: some View {
        Group {
            if !workspace.recentFiles.isEmpty {
                Section("Recent Files") {
                    ForEach(workspace.recentFiles.prefix(6), id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: "clock")
                            .onTapGesture { workspace.open(fileAt: url) }
                            .help(url.path)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func fileRow(_ node: FileNode) -> some View {
        Label(node.name, systemImage: node.symbolName)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onTapGesture {
                if !node.isDirectory { workspace.open(fileAt: node.url) }
            }
            .contextMenu {
                if node.isDirectory {
                    Button("New File…") {
                        newItemName = "untitled.html"
                        creatingFolder = false
                        creatingIn = node.url
                    }
                    Button("New Folder…") {
                        newItemName = "untitled folder"
                        creatingFolder = true
                        creatingIn = node.url
                    }
                    Divider()
                } else {
                    Button("Open") { workspace.open(fileAt: node.url) }
                    Button(
                        workspace.favorites.contains(node.url)
                            ? "Remove from Favorites" : "Add to Favorites"
                    ) {
                        workspace.toggleFavorite(node.url)
                    }
                    Divider()
                }
                Button("Rename…") {
                    renameText = node.name
                    renamingNode = node
                }
                Button("Delete", role: .destructive) { workspace.delete(node) }
                Divider()
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                }
            }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 12) {
            Button {
                workspace.openFolderPanel()
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .help("Open folder")

            Menu {
                ForEach(workspace.recentProjects, id: \.self) { url in
                    Button(url.lastPathComponent) { workspace.openFolder(url) }
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .disabled(workspace.recentProjects.isEmpty)
            .help("Recent projects")

            Spacer()

            if workspace.rootFolder != nil {
                Button {
                    workspace.closeFolder()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Close folder")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}
