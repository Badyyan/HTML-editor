//
//  PreviewWebView.swift
//  HTMLEditor
//
//  WKWebView wrapper that renders the live HTML snapshot. Reloads only
//  when the content actually changed (or a manual refresh is forced).
//

import SwiftUI
import WebKit

struct PreviewWebView: NSViewRepresentable {

    let html: String
    let baseURL: URL?
    /// Changing this value forces a reload even for identical HTML.
    let reloadToken: Int
    var zoom: Double = 1.0

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false
        // Allow relative file:// assets (images, css, js) from the project folder.
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground") // let SwiftUI style the frame
        webView.allowsMagnification = true
        context.coordinator.load(html: html, baseURL: baseURL, into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.pageZoom = zoom
        let coordinator = context.coordinator
        if coordinator.lastHTML != html
            || coordinator.lastToken != reloadToken
            || coordinator.lastBaseURL != baseURL {
            coordinator.lastToken = reloadToken
            coordinator.load(html: html, baseURL: baseURL, into: webView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastHTML = ""
        var lastBaseURL: URL?
        var lastToken = 0

        func load(html: String, baseURL: URL?, into webView: WKWebView) {
            lastHTML = html
            lastBaseURL = baseURL
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }
}
