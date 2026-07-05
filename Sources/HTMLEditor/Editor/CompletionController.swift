//
//  CompletionController.swift
//  HTMLEditor
//
//  IntelliSense: inspects the text around the caret to decide which
//  completions apply (tags, attributes, CSS properties, closing tags,
//  snippets) and shows them in a floating, non-activating panel.
//

import AppKit

@MainActor
final class CompletionController: NSObject {

    weak var textView: CodeTextView?

    private let panel: NSPanel
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var items: [CompletionItem] = []
    /// Range of the already-typed prefix that a commit replaces.
    private var prefixRange = NSRange(location: 0, length: 0)

    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.becomesKeyOnlyIfNeeded = true

        let column = NSTableColumn(identifier: .init("item"))
        column.width = 320
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 22
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(commitSelection)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.borderWidth = 0.5
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        panel.contentView = scrollView
    }

    // MARK: - Context detection

    /// Re-evaluates completions after an edit or caret move.
    func update() {
        guard let textView, AppSettings.shared.showCompletions else { hide(); return }
        let ns = textView.string as NSString
        let caret = textView.selectedRange().location
        guard textView.selectedRange().length == 0, caret <= ns.length else { hide(); return }

        // Word prefix directly before the caret.
        var start = caret
        while start > 0 {
            let c = Character(UnicodeScalar(ns.character(at: start - 1)) ?? " ")
            if c.isLetter || c.isNumber || c == "-" { start -= 1 } else { break }
        }
        let prefix = ns.substring(with: NSRange(location: start, length: caret - start))

        // Locate the innermost "<" that has no ">" after it → we're inside a tag.
        let before = NSRange(location: 0, length: caret)
        let lastLT = ns.range(of: "<", options: .backwards, range: before)
        let lastGT = ns.range(of: ">", options: .backwards, range: before)
        let insideTag = lastLT.isValid &&
            (!lastGT.isValid || lastGT.location < lastLT.location)

        var found: [CompletionItem] = []
        var replaceRange = NSRange(location: start, length: caret - start)

        if insideTag {
            let tagContent = ns.substring(
                with: NSRange(location: lastLT.location + 1,
                              length: caret - lastLT.location - 1)
            )
            if tagContent.hasPrefix("/") {
                // </… → suggest the matching open tag.
                if let open = unclosedTag(in: ns, before: lastLT.location) {
                    found = [CompletionItem(
                        label: "</\(open)>",
                        detail: "close tag",
                        kind: .closingTag,
                        insertText: "\(open)>"
                    )]
                    replaceRange = NSRange(location: start, length: caret - start)
                }
            } else if !tagContent.contains(where: { $0 == " " || $0 == "\n" || $0 == "\t" }) {
                // <div… → tag name completion.
                found = CompletionData.htmlTags
                    .filter { tagContent.isEmpty || $0.hasPrefix(tagContent.lowercased()) }
                    .map { CompletionItem(label: $0, detail: "tag", kind: .tag) }
                replaceRange = NSRange(location: lastLT.location + 1,
                                       length: caret - lastLT.location - 1)
            } else if quoteBalance(of: tagContent) {
                // Inside the tag but outside quotes → attribute completion.
                let tagName = String(tagContent.prefix { $0.isLetter || $0.isNumber || $0 == "-" })
                found = CompletionData.attributes(for: tagName)
                    .filter { prefix.isEmpty || $0.hasPrefix(prefix.lowercased()) }
                    .map {
                        CompletionItem(label: $0, detail: "attribute", kind: .attribute,
                                       insertText: "\($0)=\"\"", cursorOffset: -1)
                    }
            }
            // Inside a quoted attribute value: no completions.
        } else if isInsideStyleBlock(ns, at: caret) {
            if !prefix.isEmpty {
                found = CompletionData.cssProperties
                    .filter { $0.hasPrefix(prefix.lowercased()) }
                    .map {
                        CompletionItem(label: $0, detail: "css", kind: .cssProperty,
                                       insertText: "\($0): ;", cursorOffset: -1)
                    }
            }
        } else if !prefix.isEmpty {
            // Plain text context → snippets.
            found = CompletionData.snippets
                .filter { $0.trigger.hasPrefix(prefix.lowercased()) }
                .map {
                    CompletionItem(label: $0.trigger, detail: $0.label,
                                   kind: .snippet, insertText: $0.body)
                }
        }

        guard !found.isEmpty else { hide(); return }
        show(items: Array(found.prefix(60)), prefixRange: replaceRange)
    }

    /// True when quotes inside a tag are balanced (caret is not inside "…").
    private func quoteBalance(of s: String) -> Bool {
        var dq = 0, sq = 0
        for c in s {
            if c == "\"" { dq += 1 } else if c == "'" { sq += 1 }
        }
        return dq % 2 == 0 && sq % 2 == 0
    }

    /// Scans backwards for the nearest unclosed tag name (bounded).
    private func unclosedTag(in ns: NSString, before location: Int) -> String? {
        let start = max(0, location - 65_536)
        let context = ns.substring(with: NSRange(location: start, length: location - start))
        guard let regex = try? NSRegularExpression(
            pattern: #"<(/?)([a-zA-Z][\w-]*)(?:"[^"]*"|'[^']*'|[^>"'])*(/?)>"#
        ) else { return nil }
        var stack: [String] = []
        regex.enumerateMatches(
            in: context,
            range: NSRange(location: 0, length: (context as NSString).length)
        ) { match, _, _ in
            guard let m = match else { return }
            let cns = context as NSString
            let isClose = cns.substring(with: m.range(at: 1)) == "/"
            let name = cns.substring(with: m.range(at: 2)).lowercased()
            let selfClose = cns.substring(with: m.range(at: 3)) == "/"
            if isClose {
                if let idx = stack.lastIndex(of: name) { stack.removeSubrange(idx...) }
            } else if !selfClose && !CompletionData.voidTags.contains(name) {
                stack.append(name)
            }
        }
        return stack.last
    }

    /// True when the caret sits inside a <style>…</style> block.
    private func isInsideStyleBlock(_ ns: NSString, at location: Int) -> Bool {
        let before = NSRange(location: 0, length: location)
        let open = ns.range(of: "<style", options: [.backwards, .caseInsensitive], range: before)
        guard open.isValid else { return false }
        let close = ns.range(of: "</style", options: [.backwards, .caseInsensitive], range: before)
        return !close.isValid || close.location < open.location
    }

    // MARK: - Panel management

    private func show(items newItems: [CompletionItem], prefixRange range: NSRange) {
        guard let textView, let window = textView.window else { return }
        items = newItems
        prefixRange = range
        tableView.reloadData()
        tableView.selectRowIndexes([0], byExtendingSelection: false)
        tableView.scrollRowToVisible(0)

        scrollView.backgroundColor = AppSettings.shared.theme.backgroundColor
        tableView.backgroundColor = .clear

        // Anchor the panel below the start of the typed prefix.
        let anchor = NSRange(location: range.location, length: 0)
        var rect = textView.firstRect(forCharacterRange: anchor, actualRange: nil)
        if rect == .zero {
            rect = window.convertToScreen(
                textView.convert(textView.bounds, to: nil)
            )
        }
        let height = min(CGFloat(items.count) * 23 + 8, 200)
        let size = NSSize(width: 340, height: height)
        var origin = NSPoint(x: rect.minX, y: rect.minY - height - 4)
        if let screen = window.screen {
            origin.x = min(origin.x, screen.visibleFrame.maxX - size.width - 8)
            if origin.y < screen.visibleFrame.minY {
                origin.y = rect.maxY + 4 // flip above the caret
            }
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        panel.orderFront(nil)
    }

    func hide() {
        if panel.isVisible { panel.orderOut(nil) }
        items = []
    }

    // MARK: - Keyboard handling (routed from CodeTextView)

    func moveSelection(by delta: Int) {
        guard !items.isEmpty else { return }
        let row = max(0, min(items.count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes([row], byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    @objc func commitSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < items.count, let textView else { hide(); return }
        let item = items[row]
        hide()
        textView.commitCompletion(item, replacing: prefixRange)
    }
}

// MARK: - Table plumbing

extension CompletionController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let item = items[row]
        let theme = AppSettings.shared.theme

        let cell = NSStackView()
        cell.orientation = .horizontal
        cell.spacing = 6
        cell.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: item.kind.symbolName, accessibilityDescription: nil
        )
        icon.contentTintColor = theme.color(for: .tag)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = NSTextField(labelWithString: item.label)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = theme.foregroundColor
        label.lineBreakMode = .byTruncatingTail

        let detail = NSTextField(labelWithString: item.detail)
        detail.font = .systemFont(ofSize: 10)
        detail.textColor = theme.gutterForegroundColor
        detail.setContentHuggingPriority(.required, for: .horizontal)

        cell.addArrangedSubview(icon)
        cell.addArrangedSubview(label)
        cell.addArrangedSubview(NSView()) // spacer
        cell.addArrangedSubview(detail)
        return cell
    }
}
