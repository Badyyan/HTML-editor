//
//  Document.swift
//  HTMLEditor
//
//  Model for a single open editor tab: text content, file URL and dirty state.
//

import Foundation
import Combine

@MainActor
final class Document: ObservableObject, Identifiable {

    let id = UUID()

    /// File on disk; nil for a new untitled buffer.
    @Published private(set) var url: URL?

    /// Full text of the buffer. Every keystroke updates this.
    @Published var text: String {
        didSet {
            if !isRestoring { isModified = true }
        }
    }

    @Published private(set) var isModified = false
    @Published private(set) var language: Language

    /// Suppresses the dirty flag while loading/saving programmatically.
    private var isRestoring = false

    var displayName: String {
        url?.lastPathComponent ?? "Untitled.html"
    }

    /// Base URL used by the live preview so relative assets resolve.
    var baseURL: URL? {
        url?.deletingLastPathComponent()
    }

    init(url: URL? = nil, text: String = "") {
        self.url = url
        self.text = text
        self.language = Language.detect(from: url)
    }

    // MARK: - File I/O

    static func open(url: URL) throws -> Document {
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
            ?? String(decoding: data, as: UTF8.self)
        return Document(url: url, text: text)
    }

    func save() throws {
        guard let url else { return }
        try write(to: url)
    }

    func save(to destination: URL) throws {
        try write(to: destination)
        url = destination
        language = Language.detect(from: destination)
    }

    private func write(to destination: URL) throws {
        try text.data(using: .utf8)?.write(to: destination, options: .atomic)
        isRestoring = true
        isModified = false
        isRestoring = false
    }

    /// Replaces content without marking the document dirty (session restore).
    func setTextQuietly(_ newText: String) {
        isRestoring = true
        text = newText
        isModified = false
        isRestoring = false
    }

    /// Called after a rename on disk so the tab title and language follow.
    func fileWasMoved(to newURL: URL) {
        url = newURL
        language = Language.detect(from: newURL)
    }
}

extension Document: Hashable {
    nonisolated static func == (lhs: Document, rhs: Document) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
