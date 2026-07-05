//
//  PreviewPane.swift
//  HTMLEditor
//
//  Right split pane: device mode picker + live preview. Tablet/mobile modes
//  render inside a scaled device frame; desktop fills the pane.
//

import SwiftUI
import AppKit

struct PreviewPane: View {

    @EnvironmentObject private var workspace: Workspace
    @EnvironmentObject private var settings: AppSettings

    @State private var previewZoom: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Picker("", selection: $workspace.previewDevice) {
                ForEach(PreviewDevice.allCases) { device in
                    Image(systemName: device.symbolName)
                        .help(device.label)
                        .tag(device)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            if !settings.livePreview {
                Text("Live preview off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                previewZoom = max(0.5, previewZoom - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom out preview")

            Text("\(Int(previewZoom * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40)

            Button {
                previewZoom = min(3, previewZoom + 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom in preview")

            Button {
                workspace.refreshPreview()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh preview")

            Button {
                NotificationCenter.default.post(name: .openPreviewWindow, object: nil)
            } label: {
                Image(systemName: "rectangle.badge.plus")
            }
            .help("Open preview in new window")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let webView = PreviewWebView(
            html: workspace.previewHTML,
            baseURL: workspace.previewBaseURL,
            reloadToken: workspace.previewReloadToken,
            zoom: previewZoom
        )

        if let size = workspace.previewDevice.size {
            GeometryReader { proxy in
                let scale = min(
                    1,
                    (proxy.size.width - 48) / size.width,
                    (proxy.size.height - 48) / size.height
                )
                ZStack {
                    webView
                        .frame(width: size.width, height: size.height)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.black.opacity(0.25), lineWidth: 6)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                        .scaleEffect(max(0.2, scale))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            webView
                .background(Color.white)
        }
    }
}

/// Stand-alone preview window (⌘⌥N or the pane button).
struct PreviewWindowView: View {

    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            PreviewWebView(
                html: workspace.previewHTML,
                baseURL: workspace.previewBaseURL,
                reloadToken: workspace.previewReloadToken
            )
        }
        .frame(minWidth: 480, minHeight: 360)
        .navigationTitle("Preview — \(workspace.activeDocument?.displayName ?? "HTML Editor")")
    }
}
