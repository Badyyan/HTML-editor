//
//  FileNode.swift
//  HTMLEditor
//
//  Tree node for the file explorer sidebar.
//

import Foundation

struct FileNode: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    /// nil for files (OutlineGroup treats nil children as a leaf).
    var children: [FileNode]?

    var id: String { url.path }
    var name: String { url.lastPathComponent }

    /// SF Symbol used in the sidebar.
    var symbolName: String {
        if isDirectory { return "folder" }
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "chevron.left.forwardslash.chevron.right"
        case "css": return "paintbrush"
        case "js", "mjs": return "curlybraces"
        case "json": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico": return "photo"
        case "md": return "text.alignleft"
        default: return "doc"
        }
    }

    var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "svg", "webp", "ico"]
            .contains(url.pathExtension.lowercased())
    }
}

enum FileTreeBuilder {

    /// Builds a sorted tree (folders first, then files, alphabetical),
    /// skipping hidden files. Depth-limited to keep huge folders responsive.
    static func build(at root: URL, depth: Int = 12) -> [FileNode] {
        guard depth > 0 else { return [] }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var nodes: [FileNode] = entries.map { url in
            let isDir = url.isExistingDirectory
            return FileNode(
                url: url,
                isDirectory: isDir,
                children: isDir ? build(at: url, depth: depth - 1) : nil
            )
        }
        nodes.sort {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return nodes
    }

    /// Flattens the tree to all non-directory nodes (used for the Assets group).
    static func flatFiles(in nodes: [FileNode]) -> [FileNode] {
        nodes.flatMap { node -> [FileNode] in
            if node.isDirectory { return flatFiles(in: node.children ?? []) }
            return [node]
        }
    }
}
