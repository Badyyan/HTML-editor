//
//  CodeEditorView.swift
//  HTMLEditor
//
//  SwiftUI wrapper around the AppKit editor stack (NSScrollView +
//  CodeTextView + line-number ruler). Explicitly builds a TextKit 1 layout
//  stack: the ruler, temporary attributes and the highlighter all rely on
//  NSLayoutManager.
//

import SwiftUI
import AppKit

struct CodeEditorView: NSViewRepresentable {

    @ObservedObject var document: Document
    @ObservedObject var settings: AppSettings
    let workspace: Workspace

    // MARK: - Creation

    func makeNSView(context: Context) -> NSScrollView {
        // TextKit 1 stack, assembled by hand.
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = CodeTextView(frame: .zero, textContainer: container)
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true

        // Gutter.
        let ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = settings.showLineNumbers

        // Wiring.
        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.ruler = ruler
        textView.delegate = coordinator
        textView.completion = coordinator.completionController
        coordinator.completionController.textView = textView
        coordinator.editorController.textView = textView

        textView.string = document.text
        coordinator.applyStyle(to: textView, scrollView: scrollView)
        coordinator.rehighlight()

        // Register this editor as the active one for find/replace & status.
        DispatchQueue.main.async {
            workspace.register(editor: coordinator.editorController, for: document.id)
        }
        return scrollView
    }

    // MARK: - Updates

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let textView = coordinator.textView else { return }

        // External text change (file reload, session restore).
        if textView.string != document.text && !coordinator.isEditing {
            let selection = textView.selectedRange()
            textView.string = document.text
            let limit = (document.text as NSString).length
            textView.setSelectedRange(
                NSRange(location: min(selection.location, limit), length: 0)
            )
            coordinator.rehighlight()
        }

        scrollView.rulersVisible = settings.showLineNumbers
        coordinator.applyStyle(to: textView, scrollView: scrollView)

        // Font/theme changes require a re-highlight pass.
        let styleKey = "\(settings.themeName)|\(settings.fontName)|"
            + "\(settings.fontSize)|\(settings.editorZoom)|\(settings.wordWrap)"
        if styleKey != coordinator.lastStyleKey {
            coordinator.lastStyleKey = styleKey
            coordinator.rehighlight()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, settings: settings, workspace: workspace)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {

        let document: Document
        let settings: AppSettings
        let workspace: Workspace

        weak var textView: CodeTextView?
        weak var ruler: LineNumberRulerView?

        let editorController = EditorController()
        let completionController = CompletionController()
        private let highlighter = HighlightEngine()

        /// Set while the user is typing so updateNSView doesn't echo text back.
        private(set) var isEditing = false
        var lastStyleKey = ""

        /// Temporary-attribute ranges we own (current line + bracket pair),
        /// tracked so clearing them never wipes find-match highlights.
        private var ownedHighlights: [NSRange] = []

        init(document: Document, settings: AppSettings, workspace: Workspace) {
            self.document = document
            self.settings = settings
            self.workspace = workspace
            super.init()
        }

        // MARK: Styling

        func applyStyle(to textView: CodeTextView, scrollView: NSScrollView) {
            let theme = settings.theme
            textView.font = settings.editorFont
            textView.backgroundColor = theme.backgroundColor
            textView.insertionPointColor = theme.caretColor
            textView.selectedTextAttributes = [
                .backgroundColor: theme.selectionColor
            ]
            textView.typingAttributes = [
                .foregroundColor: theme.foregroundColor,
                .font: settings.editorFont
            ]
            scrollView.backgroundColor = theme.backgroundColor
            ruler?.theme = theme

            applyWordWrap(settings.wordWrap, textView: textView, scrollView: scrollView)
        }

        private func applyWordWrap(
            _ wrap: Bool, textView: NSTextView, scrollView: NSScrollView
        ) {
            guard let container = textView.textContainer else { return }
            if wrap {
                container.widthTracksTextView = true
                container.size = NSSize(
                    width: scrollView.contentSize.width,
                    height: .greatestFiniteMagnitude
                )
                textView.isHorizontallyResizable = false
                textView.autoresizingMask = [.width]
                textView.frame.size.width = scrollView.contentSize.width
            } else {
                container.widthTracksTextView = false
                container.size = NSSize(
                    width: .greatestFiniteMagnitude,
                    height: .greatestFiniteMagnitude
                )
                textView.isHorizontallyResizable = true
                textView.autoresizingMask = []
            }
            scrollView.hasHorizontalScroller = !wrap
        }

        // MARK: Highlighting

        func rehighlight() {
            guard let textView else { return }
            highlighter.invalidate(
                textView: textView, language: document.language, settings: settings
            )
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            isEditing = true
            document.text = textView.string
            isEditing = false
            rehighlight()
            ruler?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            let ns = textView.string as NSString
            let caret = textView.selectedRange().location
            let (line, column) = ns.lineAndColumn(for: caret)
            workspace.updateCursor(line: line, column: column)

            refreshOwnedHighlights()
        }

        // MARK: Current line + bracket matching

        private func refreshOwnedHighlights() {
            guard let textView, let layoutManager = textView.layoutManager else { return }
            for range in ownedHighlights {
                layoutManager.removeTemporaryAttribute(
                    .backgroundColor, forCharacterRange: range
                )
            }
            ownedHighlights.removeAll()

            let theme = settings.theme
            let ns = textView.string as NSString
            let selection = textView.selectedRange()

            if settings.highlightCurrentLine, selection.length == 0, ns.length > 0 {
                let lineRange = ns.lineRange(
                    for: NSRange(location: min(selection.location, ns.length), length: 0)
                )
                if lineRange.length > 0 {
                    layoutManager.addTemporaryAttribute(
                        .backgroundColor,
                        value: theme.currentLineColor,
                        forCharacterRange: lineRange
                    )
                    ownedHighlights.append(lineRange)
                }
            }

            if selection.length == 0,
               let (open, close) = matchingBrackets(in: ns, caret: selection.location) {
                let color = theme.selectionColor.withAlphaComponent(0.8)
                for range in [open, close] {
                    layoutManager.addTemporaryAttribute(
                        .backgroundColor, value: color, forCharacterRange: range
                    )
                    ownedHighlights.append(range)
                }
            }
        }

        /// Finds the bracket adjacent to the caret and its counterpart.
        private func matchingBrackets(
            in ns: NSString, caret: Int
        ) -> (NSRange, NSRange)? {
            let pairs: [Character: (Character, Bool)] = [
                "(": (")", true), "[": ("]", true), "{": ("}", true),
                ")": ("(", false), "]": ("[", false), "}": ("{", false)
            ]
            guard caret > 0, caret <= ns.length else { return nil }
            let index = caret - 1
            let char = Character(UnicodeScalar(ns.character(at: index)) ?? " ")
            guard let (counterpart, forward) = pairs[char] else { return nil }

            var depth = 0
            let limit = 200_000 // bail out on pathological documents
            var steps = 0
            var i = index
            while i >= 0 && i < ns.length && steps < limit {
                let c = Character(UnicodeScalar(ns.character(at: i)) ?? " ")
                if c == char { depth += 1 }
                else if c == counterpart {
                    depth -= 1
                    if depth == 0 {
                        return (
                            NSRange(location: index, length: 1),
                            NSRange(location: i, length: 1)
                        )
                    }
                }
                i += forward ? 1 : -1
                steps += 1
            }
            return nil
        }
    }
}
