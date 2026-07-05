//
//  Workspace.swift
//  HTMLEditor
//
//  Central view model (MVVM): open folder + file tree, open tabs, the
//  active document, find bar, preview state, recents/favorites, session
//  restore, auto save and export actions.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Preview device modes

enum PreviewDevice: String, CaseIterable, Identifiable {
    case desktop, tablet, mobile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .desktop: return "Desktop"
        case .tablet: return "Tablet"
        case .mobile: return "Mobile"
        }
    }

    var symbolName: String {
        switch self {
        case .desktop: return "desktopcomputer"
        case .tablet: return "ipad"
        case .mobile: return "iphone"
        }
    }

    /// nil means "fill the pane".
    var size: CGSize? {
        switch self {
        case .desktop: return nil
        case .tablet: return CGSize(width: 768, height: 1024)
        case .mobile: return CGSize(width: 390, height: 844)
        }
    }
}

// MARK: - Workspace

@MainActor
final class Workspace: ObservableObject {

    // Project
    @Published private(set) var rootFolder: URL?
    @Published private(set) var fileTree: [FileNode] = []
    @Published var recentProjects: [URL] = []
    @Published var recentFiles: [URL] = []
    @Published var favorites: [URL] = []

    // Tabs
    @Published private(set) var openDocuments: [Document] = []
    @Published var activeDocumentID: UUID? {
        didSet {
            activeEditor = activeDocumentID.flatMap { editors[$0] }
            bindPreview()
            persistSession()
        }
    }

    // Find bar
    @Published var isFindBarVisible = false

    // Preview
    @Published var isPreviewVisible = true
    @Published var previewDevice: PreviewDevice = .desktop
    @Published private(set) var previewHTML = ""
    @Published private(set) var previewBaseURL: URL?
    /// Incremented to force a WKWebView reload even when the HTML is unchanged.
    @Published private(set) var previewReloadToken = 0

    // Status bar
    @Published private(set) var cursorLine = 1
    @Published private(set) var cursorColumn = 1

    // Alerts
    @Published var errorMessage: String?

    // Active editor bridge (find/replace target).
    @Published private(set) var activeEditor: EditorController?
    private var editors: [UUID: EditorController] = [:]

    private let settings = AppSettings.shared
    private var previewCancellable: AnyCancellable?
    private var autoSaveTimer: Timer?

    var activeDocument: Document? {
        openDocuments.first { $0.id == activeDocumentID }
    }

    // MARK: - Init / session

    init() {
        loadPersistedLists()
        if settings.restoreSession {
            restoreSession()
        }
        if openDocuments.isEmpty {
            // Fresh start: greet with an untitled starter page.
            newUntitledDocument()
        }
        startAutoSaveTimer()
        ThemeManager.writeSampleThemeIfNeeded()
    }

    // MARK: - Folder handling

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Open Folder"
        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url)
        }
    }

    func openFolder(_ url: URL) {
        rootFolder = url
        refreshFileTree()
        addRecentProject(url)
        persistSession()
    }

    func closeFolder() {
        rootFolder = nil
        fileTree = []
        persistSession()
    }

    func refreshFileTree() {
        guard let rootFolder else { fileTree = []; return }
        fileTree = FileTreeBuilder.build(at: rootFolder)
    }

    // MARK: - Documents / tabs

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            panel.urls.forEach { open(fileAt: $0) }
        }
    }

    func open(fileAt url: URL) {
        if url.isExistingDirectory {
            openFolder(url)
            return
        }
        if let existing = openDocuments.first(where: { $0.url == url }) {
            activeDocumentID = existing.id
            return
        }
        do {
            let document = try Document.open(url: url)
            openDocuments.append(document)
            activeDocumentID = document.id
            addRecentFile(url)
        } catch {
            errorMessage = "Could not open “\(url.lastPathComponent)”: \(error.localizedDescription)"
        }
    }

    func newUntitledDocument() {
        let starter = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>New Page</title>
        </head>
        <body>
            <h1>Hello, world!</h1>
        </body>
        </html>
        """
        let document = Document(text: starter)
        document.setTextQuietly(starter)
        openDocuments.append(document)
        activeDocumentID = document.id
    }

    func close(_ document: Document) {
        if document.isModified {
            let alert = NSAlert()
            alert.messageText = "“\(document.displayName)” has unsaved changes."
            alert.informativeText = "Do you want to save before closing?"
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn: save(document)
            case .alertThirdButtonReturn: return
            default: break
            }
        }
        editors[document.id] = nil
        openDocuments.removeAll { $0.id == document.id }
        if activeDocumentID == document.id {
            activeDocumentID = openDocuments.last?.id
        }
        persistSession()
    }

    func closeActiveDocument() {
        if let activeDocument { close(activeDocument) }
    }

    // MARK: - Saving

    func saveActiveDocument() {
        if let activeDocument { save(activeDocument) }
    }

    func save(_ document: Document) {
        if document.url == nil {
            saveAs(document)
            return
        }
        do {
            try document.save()
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func saveAs(_ document: Document? = nil) {
        guard let document = document ?? activeDocument else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = document.displayName
        if let type = UTType(filenameExtension: "html") {
            panel.allowedContentTypes = [type, .plainText]
        }
        panel.directoryURL = rootFolder
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try document.save(to: url)
                addRecentFile(url)
                refreshFileTree()
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func saveAllModified() {
        for document in openDocuments where document.isModified && document.url != nil {
            try? document.save()
        }
    }

    private func startAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(
            withTimeInterval: max(5, settings.autoSaveInterval), repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.settings.autoSave else { return }
                self.saveAllModified()
            }
        }
    }

    // MARK: - File operations (explorer)

    func createFile(named name: String, in folder: URL?) {
        guard let target = folder ?? rootFolder else { return }
        let url = target.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "A file named “\(name)” already exists."
            return
        }
        FileManager.default.createFile(atPath: url.path, contents: Data())
        refreshFileTree()
        open(fileAt: url)
    }

    func createFolder(named name: String, in folder: URL?) {
        guard let target = folder ?? rootFolder else { return }
        let url = target.appendingPathComponent(name, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: false
            )
            refreshFileTree()
        } catch {
            errorMessage = "Could not create folder: \(error.localizedDescription)"
        }
    }

    func delete(_ node: FileNode) {
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            if let open = openDocuments.first(where: { $0.url == node.url }) {
                editors[open.id] = nil
                openDocuments.removeAll { $0.id == open.id }
                if activeDocumentID == open.id { activeDocumentID = openDocuments.last?.id }
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not delete: \(error.localizedDescription)"
        }
    }

    func rename(_ node: FileNode, to newName: String) {
        let destination = node.url.deletingLastPathComponent()
            .appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: node.url, to: destination)
            if let open = openDocuments.first(where: { $0.url == node.url }) {
                open.fileWasMoved(to: destination)
            }
            refreshFileTree()
        } catch {
            errorMessage = "Could not rename: \(error.localizedDescription)"
        }
    }

    /// Handles file/folder drops from Finder onto the sidebar or editor.
    func handleDrop(of providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier, options: nil
            ) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                }
                if let url {
                    Task { @MainActor [weak self] in self?.open(fileAt: url) }
                }
            }
        }
        return handled
    }

    // MARK: - Favorites / recents

    func toggleFavorite(_ url: URL) {
        if favorites.contains(url) {
            favorites.removeAll { $0 == url }
        } else {
            favorites.append(url)
        }
        persistLists()
    }

    private func addRecentProject(_ url: URL) {
        recentProjects.removeAll { $0 == url }
        recentProjects.insert(url, at: 0)
        recentProjects = Array(recentProjects.prefix(8))
        persistLists()
    }

    private func addRecentFile(_ url: URL) {
        recentFiles.removeAll { $0 == url }
        recentFiles.insert(url, at: 0)
        recentFiles = Array(recentFiles.prefix(10))
        persistLists()
    }

    // MARK: - Preview

    /// Re-binds the preview pipeline to the active document with debounce.
    private func bindPreview() {
        previewCancellable = nil
        guard let document = activeDocument else {
            previewHTML = ""
            previewBaseURL = nil
            return
        }
        previewHTML = document.text
        previewBaseURL = document.baseURL ?? rootFolder
        previewCancellable = document.$text
            .debounce(
                for: .seconds(max(0.05, settings.previewDelay)),
                scheduler: DispatchQueue.main
            )
            .sink { [weak self] text in
                guard let self, self.settings.livePreview else { return }
                self.previewHTML = text
            }
    }

    func refreshPreview() {
        guard let document = activeDocument else { return }
        previewHTML = document.text
        previewBaseURL = document.baseURL ?? rootFolder
        previewReloadToken += 1
    }

    /// Saves a snapshot to a temp file and opens it in the default browser.
    func openInBrowser() {
        guard let document = activeDocument else { return }
        let url: URL
        if let existing = document.url, !document.isModified {
            url = existing
        } else if let existing = document.url {
            try? document.save()
            url = existing
        } else {
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("preview-\(UUID().uuidString).html")
            try? document.text.data(using: .utf8)?.write(to: temp)
            url = temp
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Export & share

    func exportActiveHTML() {
        guard let document = activeDocument else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = document.displayName
        if let type = UTType(filenameExtension: "html") {
            panel.allowedContentTypes = [type]
        }
        if panel.runModal() == .OK, let url = panel.url {
            try? document.text.data(using: .utf8)?.write(to: url)
        }
    }

    /// Zips the whole project folder with ditto.
    func exportProjectArchive() {
        guard let rootFolder else {
            errorMessage = "Open a folder first to export a project."
            return
        }
        saveAllModified()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = rootFolder.lastPathComponent + ".zip"
        if let zip = UTType(filenameExtension: "zip") {
            panel.allowedContentTypes = [zip]
        }
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        try? FileManager.default.removeItem(at: destination)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", rootFolder.path, destination.path]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                errorMessage = "Export failed (ditto exited with \(process.terminationStatus))."
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            }
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func copyGeneratedHTML() {
        guard let document = activeDocument else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(document.text, forType: .string)
    }

    /// URL offered by the toolbar ShareLink (saved file, or a temp snapshot).
    var shareableURL: URL? {
        guard let document = activeDocument else { return nil }
        if let url = document.url { return url }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(document.displayName)
        try? document.text.data(using: .utf8)?.write(to: temp)
        return temp
    }

    // MARK: - Editor registration & status

    func register(editor: EditorController, for documentID: UUID) {
        editors[documentID] = editor
        if documentID == activeDocumentID {
            activeEditor = editor
        }
    }

    func focusActiveEditor() {
        if let id = activeDocumentID {
            activeEditor = editors[id]
        }
    }

    func updateCursor(line: Int, column: Int) {
        cursorLine = line
        cursorColumn = column
    }

    // MARK: - Persistence

    private struct SessionState: Codable {
        var folder: String?
        var openFiles: [String]
        var activeFile: String?
    }

    private struct PersistedLists: Codable {
        var recentProjects: [String]
        var recentFiles: [String]
        var favorites: [String]
    }

    func persistSession() {
        let state = SessionState(
            folder: rootFolder?.path,
            openFiles: openDocuments.compactMap { $0.url?.path },
            activeFile: activeDocument?.url?.path
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "workspace.session.v1")
        }
    }

    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: "workspace.session.v1"),
              let state = try? JSONDecoder().decode(SessionState.self, from: data)
        else { return }
        let fm = FileManager.default
        if let folder = state.folder, fm.fileExists(atPath: folder) {
            openFolder(URL(fileURLWithPath: folder))
        }
        for path in state.openFiles where fm.fileExists(atPath: path) {
            open(fileAt: URL(fileURLWithPath: path))
        }
        if let active = state.activeFile,
           let document = openDocuments.first(where: { $0.url?.path == active }) {
            activeDocumentID = document.id
        }
    }

    private func persistLists() {
        let lists = PersistedLists(
            recentProjects: recentProjects.map(\.path),
            recentFiles: recentFiles.map(\.path),
            favorites: favorites.map(\.path)
        )
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: "workspace.lists.v1")
        }
    }

    private func loadPersistedLists() {
        guard let data = UserDefaults.standard.data(forKey: "workspace.lists.v1"),
              let lists = try? JSONDecoder().decode(PersistedLists.self, from: data)
        else { return }
        recentProjects = lists.recentProjects.map { URL(fileURLWithPath: $0) }
        recentFiles = lists.recentFiles.map { URL(fileURLWithPath: $0) }
        favorites = lists.favorites.map { URL(fileURLWithPath: $0) }
    }
}
