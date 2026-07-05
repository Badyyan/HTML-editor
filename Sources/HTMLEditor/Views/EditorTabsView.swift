//
//  EditorTabsView.swift
//  HTMLEditor
//
//  Horizontal tab strip above the editor.
//

import SwiftUI
import AppKit

struct EditorTabsView: View {

    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(workspace.openDocuments) { document in
                        TabChip(
                            document: document,
                            isActive: document.id == workspace.activeDocumentID,
                            activate: { workspace.activeDocumentID = document.id },
                            close: { workspace.close(document) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
            }

            Button {
                workspace.newUntitledDocument()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .help("New tab (⌘N)")
        }
        .background(.bar)
    }
}

private struct TabChip: View {

    @ObservedObject var document: Document
    let isActive: Bool
    let activate: () -> Void
    let close: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)

            Text(document.displayName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)

            Button(action: close) {
                Image(systemName: document.isModified && !isHovering
                      ? "circle.fill" : "xmark")
                    .font(.system(size: document.isModified && !isHovering ? 7 : 9,
                                  weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || document.isModified || isActive ? 1 : 0)
            .help(document.isModified ? "Unsaved changes" : "Close tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isActive
                      ? AnyShapeStyle(.background)
                      : AnyShapeStyle(.clear))
                .shadow(color: .black.opacity(isActive ? 0.12 : 0), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    Color(nsColor: .separatorColor).opacity(isActive ? 0.6 : 0),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: activate)
        .onHover { isHovering = $0 }
        .help(document.url?.path ?? document.displayName)
    }
}
