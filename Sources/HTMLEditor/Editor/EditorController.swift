//
//  EditorController.swift
//  HTMLEditor
//
//  Bridge between SwiftUI (find bar, menu commands) and the AppKit text
//  view: find & replace, match highlighting and navigation.
//

import AppKit
import Combine

@MainActor
final class EditorController: ObservableObject {

    weak var textView: CodeTextView?

    @Published private(set) var matchCount = 0
    @Published private(set) var currentMatchIndex = 0 // 1-based for display

    private var matches: [NSRange] = []
    private var lastQuery = ""
    private var lastCaseSensitive = false
    private var lastUseRegex = false

    // MARK: - Search

    func search(_ query: String, caseSensitive: Bool, useRegex: Bool) {
        lastQuery = query
        lastCaseSensitive = caseSensitive
        lastUseRegex = useRegex
        recomputeMatches()
        highlightMatches()
        if let first = matches.first {
            select(range: first, index: 1)
        }
    }

    func clearSearch() {
        matches = []
        matchCount = 0
        currentMatchIndex = 0
        clearMatchHighlights()
    }

    func findNext() {
        guard !matches.isEmpty, let textView else { return }
        let caret = NSMaxRange(textView.selectedRange())
        if let idx = matches.firstIndex(where: { $0.location >= caret }) {
            select(range: matches[idx], index: idx + 1)
        } else {
            select(range: matches[0], index: 1) // wrap around
        }
    }

    func findPrevious() {
        guard !matches.isEmpty, let textView else { return }
        let caret = textView.selectedRange().location
        if let idx = matches.lastIndex(where: { NSMaxRange($0) <= caret }) {
            select(range: matches[idx], index: idx + 1)
        } else {
            select(range: matches[matches.count - 1], index: matches.count)
        }
    }

    // MARK: - Replace

    func replaceCurrent(with replacement: String) {
        guard let textView, !matches.isEmpty else { return }
        let selection = textView.selectedRange()
        guard let idx = matches.firstIndex(where: { $0 == selection }) else {
            findNext()
            return
        }
        replace(range: matches[idx], with: replacement, in: textView)
        recomputeMatches()
        highlightMatches()
        findNext()
    }

    func replaceAll(with replacement: String) -> Int {
        guard let textView, !matches.isEmpty else { return 0 }
        let count = matches.count
        textView.textStorage?.beginEditing()
        for range in matches.reversed() {
            textView.textStorage?.replaceCharacters(
                in: range, with: resolvedReplacement(replacement, for: range)
            )
        }
        textView.textStorage?.endEditing()
        textView.didChangeText()
        recomputeMatches()
        highlightMatches()
        return count
    }

    private func replace(range: NSRange, with replacement: String, in textView: CodeTextView) {
        let resolved = resolvedReplacement(replacement, for: range)
        if textView.shouldChangeText(in: range, replacementString: resolved) {
            textView.textStorage?.replaceCharacters(in: range, with: resolved)
            textView.didChangeText()
        }
    }

    /// Expands $1…$9 capture references when regex search is active.
    private func resolvedReplacement(_ template: String, for range: NSRange) -> String {
        guard lastUseRegex, let textView,
              let regex = compiledRegex() else { return template }
        let ns = textView.string as NSString
        guard let match = regex.firstMatch(in: textView.string, range: range) else {
            return template
        }
        return regex.replacementString(
            for: match, in: ns as String, offset: 0, template: template
        )
    }

    // MARK: - Internals

    private func compiledRegex() -> NSRegularExpression? {
        var options: NSRegularExpression.Options = []
        if !lastCaseSensitive { options.insert(.caseInsensitive) }
        return try? NSRegularExpression(pattern: lastQuery, options: options)
    }

    private func recomputeMatches() {
        matches = []
        defer {
            matchCount = matches.count
            if matches.isEmpty { currentMatchIndex = 0 }
        }
        guard let textView, !lastQuery.isEmpty else { return }
        let ns = textView.string as NSString
        let full = NSRange(location: 0, length: ns.length)

        if lastUseRegex {
            guard let regex = compiledRegex() else { return }
            regex.enumerateMatches(in: textView.string, range: full) { match, _, _ in
                if let m = match, m.range.length > 0 { matches.append(m.range) }
            }
        } else {
            var searchRange = full
            var options: NSString.CompareOptions = []
            if !lastCaseSensitive { options.insert(.caseInsensitive) }
            while true {
                let found = ns.range(of: lastQuery, options: options, range: searchRange)
                guard found.isValid, found.length > 0 else { break }
                matches.append(found)
                let next = NSMaxRange(found)
                guard next < ns.length else { break }
                searchRange = NSRange(location: next, length: ns.length - next)
            }
        }
    }

    private func select(range: NSRange, index: Int) {
        guard let textView else { return }
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
        currentMatchIndex = index
    }

    private func highlightMatches() {
        guard let textView, let layoutManager = textView.layoutManager else { return }
        clearMatchHighlights()
        let color = NSColor.systemYellow.withAlphaComponent(0.35)
        for range in matches {
            layoutManager.addTemporaryAttribute(
                .backgroundColor, value: color, forCharacterRange: range
            )
        }
    }

    private func clearMatchHighlights() {
        guard let textView, let layoutManager = textView.layoutManager else { return }
        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
    }
}
