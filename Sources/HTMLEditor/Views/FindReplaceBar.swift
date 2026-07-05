//
//  FindReplaceBar.swift
//  HTMLEditor
//
//  Inline find & replace bar shown above the editor (⌘F).
//

import SwiftUI

struct FindReplaceBar: View {

    @EnvironmentObject private var workspace: Workspace

    @State private var query = ""
    @State private var replacement = ""
    @State private var caseSensitive = false
    @State private var useRegex = false
    @State private var showReplace = false

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    withAnimation { showReplace.toggle() }
                } label: {
                    Image(systemName: showReplace ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Toggle replace")

                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Find", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit { workspace.activeEditor?.findNext() }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5))
                )
                .frame(maxWidth: 320)

                matchCounter

                Button { workspace.activeEditor?.findPrevious() } label: {
                    Image(systemName: "chevron.up")
                }
                .help("Previous match (⇧⌘G)")

                Button { workspace.activeEditor?.findNext() } label: {
                    Image(systemName: "chevron.down")
                }
                .help("Next match (⌘G)")

                Toggle("Aa", isOn: $caseSensitive)
                    .toggleStyle(.button)
                    .help("Case sensitive")

                Toggle(".*", isOn: $useRegex)
                    .toggleStyle(.button)
                    .font(.system(size: 11, design: .monospaced))
                    .help("Regular expression")

                Spacer()

                Button {
                    workspace.activeEditor?.clearSearch()
                    workspace.isFindBarVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close (⎋)")
            }

            if showReplace {
                HStack(spacing: 8) {
                    Spacer().frame(width: 18)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                        TextField("Replace", text: $replacement)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                workspace.activeEditor?.replaceCurrent(with: replacement)
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5))
                    )
                    .frame(maxWidth: 320)

                    Button("Replace") {
                        workspace.activeEditor?.replaceCurrent(with: replacement)
                    }
                    Button("Replace All") {
                        _ = workspace.activeEditor?.replaceAll(with: replacement)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .onAppear { searchFocused = true }
        .onExitCommand {
            workspace.activeEditor?.clearSearch()
            workspace.isFindBarVisible = false
        }
        .onChange(of: query) { _ in runSearch() }
        .onChange(of: caseSensitive) { _ in runSearch() }
        .onChange(of: useRegex) { _ in runSearch() }
    }

    private func runSearch() {
        guard let editor = workspace.activeEditor else { return }
        if query.isEmpty {
            editor.clearSearch()
        } else {
            editor.search(query, caseSensitive: caseSensitive, useRegex: useRegex)
        }
    }

    @ViewBuilder
    private var matchCounter: some View {
        if let editor = workspace.activeEditor {
            MatchCountLabel(editor: editor)
        }
    }
}

/// Separate view so it can observe the editor controller's published counts.
private struct MatchCountLabel: View {
    @ObservedObject var editor: EditorController

    var body: some View {
        Text(editor.matchCount == 0
             ? "No results"
             : "\(editor.currentMatchIndex) of \(editor.matchCount)")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(minWidth: 64)
            .monospacedDigit()
    }
}
