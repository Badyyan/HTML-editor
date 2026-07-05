//
//  CodeTextView.swift
//  HTMLEditor
//
//  NSTextView subclass implementing the "smart" editing behaviors:
//  auto-indentation, auto-closing brackets/quotes, auto-closing HTML tags,
//  and keyboard routing for the completion popup.
//

import AppKit

final class CodeTextView: NSTextView {

    /// IntelliSense controller; owned by the editor coordinator.
    weak var completion: CompletionController?

    private var settings: AppSettings { .shared }

    // MARK: - Keyboard routing for completions

    override func keyDown(with event: NSEvent) {
        if let completion, completion.isVisible {
            switch event.keyCode {
            case 125: completion.moveSelection(by: 1); return   // ↓
            case 126: completion.moveSelection(by: -1); return  // ↑
            case 36, 48: completion.commitSelection(); return   // ⏎, ⇥
            case 53: completion.hide(); return                  // ⎋
            default: break
            }
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        if let completion, completion.isVisible {
            completion.hide()
            return
        }
        super.cancelOperation(sender)
    }

    // MARK: - Auto indentation

    override func insertNewline(_ sender: Any?) {
        guard settings.autoIndent else {
            super.insertNewline(sender)
            return
        }
        let ns = string as NSString
        let selection = selectedRange()
        let lineRange = ns.lineRange(for: NSRange(location: selection.location, length: 0))
        let lineBeforeCaret = ns.substring(
            with: NSRange(location: lineRange.location,
                          length: max(0, selection.location - lineRange.location))
        )
        let indent = lineBeforeCaret.leadingIndentation
        let unit = settings.indentUnit

        let charBefore: String = selection.location > 0
            ? ns.substring(with: NSRange(location: selection.location - 1, length: 1))
            : ""
        let lookahead: String = {
            let remaining = ns.length - selection.location
            guard remaining > 0 else { return "" }
            return ns.substring(
                with: NSRange(location: selection.location, length: min(2, remaining))
            )
        }()

        if charBefore == "{" && lookahead.hasPrefix("}") {
            // { | }  →  expand the block with the caret indented inside.
            insertRaw("\n\(indent)\(unit)\n\(indent)", at: selection)
            setSelectedRange(NSRange(
                location: selection.location + 1 + indent.count + unit.count, length: 0
            ))
        } else if charBefore == ">" && lookahead.hasPrefix("</")
                    && endsWithOpeningTag(lineBeforeCaret) {
            // <div>|</div>  →  same block expansion between tags.
            insertRaw("\n\(indent)\(unit)\n\(indent)", at: selection)
            setSelectedRange(NSRange(
                location: selection.location + 1 + indent.count + unit.count, length: 0
            ))
        } else if charBefore == "{" ||
                    (charBefore == ">" && endsWithOpeningTag(lineBeforeCaret)) {
            insertRaw("\n\(indent)\(unit)", at: selection)
        } else {
            insertRaw("\n\(indent)", at: selection)
        }
    }

    /// True when the text ends with an opening (non-void, non-self-closing) tag.
    private func endsWithOpeningTag(_ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: #"<([a-zA-Z][\w-]*)(?:"[^"]*"|'[^']*'|[^>"'])*>$"#
        ) else { return false }
        let ns = text as NSString
        guard let match = regex.firstMatch(
            in: text, range: NSRange(location: 0, length: ns.length)
        ) else { return false }
        let whole = ns.substring(with: match.range)
        if whole.hasSuffix("/>") { return false }
        let name = ns.substring(with: match.range(at: 1)).lowercased()
        return !CompletionData.voidTags.contains(name)
    }

    // MARK: - Auto-closing pairs & tags

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard let typed = stringValue(of: insertString), typed.count == 1 else {
            super.insertText(insertString, replacementRange: replacementRange)
            completion?.update()
            return
        }

        let selection = selectedRange()
        let ns = string as NSString

        // 1. Typing a closer that is already there → just step over it.
        if settings.autoCloseBrackets,
           ")]}\"'".contains(typed),
           selection.length == 0,
           selection.location < ns.length,
           ns.substring(with: NSRange(location: selection.location, length: 1)) == typed {
            setSelectedRange(NSRange(location: selection.location + 1, length: 0))
            completion?.update()
            return
        }

        // 2. Opening bracket/quote → insert the pair (or wrap the selection).
        if settings.autoCloseBrackets, let closer = pairCloser(for: typed) {
            if selection.length > 0 {
                let selected = ns.substring(with: selection)
                insertRaw("\(typed)\(selected)\(closer)", at: selection)
                setSelectedRange(NSRange(location: selection.location + 1,
                                         length: selection.length))
            } else {
                insertRaw("\(typed)\(closer)", at: selection)
                setSelectedRange(NSRange(location: selection.location + 1, length: 0))
            }
            completion?.update()
            return
        }

        super.insertText(insertString, replacementRange: replacementRange)

        // 3. ">" completes `<tag …>` → append `</tag>`.
        if typed == ">" && settings.autoCloseTags {
            autoCloseTagIfNeeded()
        }
        // 4. "/" right after "<" → auto-complete the matching closing tag.
        if typed == "/" && settings.autoCloseTags {
            autoCompleteClosingTagIfNeeded()
        }

        completion?.update()
    }

    override func deleteBackward(_ sender: Any?) {
        // Deleting the opener of an empty pair removes both characters.
        let selection = selectedRange()
        if settings.autoCloseBrackets, selection.length == 0, selection.location > 0 {
            let ns = string as NSString
            if selection.location < ns.length {
                let before = ns.substring(
                    with: NSRange(location: selection.location - 1, length: 1)
                )
                let after = ns.substring(
                    with: NSRange(location: selection.location, length: 1)
                )
                if let closer = pairCloser(for: before), String(closer) == after {
                    insertRaw("", at: NSRange(location: selection.location - 1, length: 2))
                    completion?.update()
                    return
                }
            }
        }
        super.deleteBackward(sender)
        completion?.update()
    }

    private func pairCloser(for opener: String) -> Character? {
        switch opener {
        case "(": return ")"
        case "[": return "]"
        case "{": return "}"
        case "\"": return "\""
        case "'": return "'"
        default: return nil
        }
    }

    /// After ">" is typed: if it completes an opening tag, insert `</name>`
    /// and keep the caret between the tags.
    private func autoCloseTagIfNeeded() {
        let ns = string as NSString
        let caret = selectedRange().location
        let scanStart = max(0, caret - 512)
        let context = ns.substring(
            with: NSRange(location: scanStart, length: caret - scanStart)
        )
        guard let ltIndex = context.lastIndex(of: "<") else { return }
        let tagText = String(context[context.index(after: ltIndex)...]) // "div class=…>"
        guard !tagText.hasPrefix("/"), !tagText.hasPrefix("!"),
              !tagText.hasSuffix("/>") else { return }
        let name = String(tagText.prefix { $0.isLetter || $0.isNumber || $0 == "-" })
        guard !name.isEmpty,
              !CompletionData.voidTags.contains(name.lowercased()) else { return }

        insertRaw("</\(name)>", at: NSRange(location: caret, length: 0))
        setSelectedRange(NSRange(location: caret, length: 0))
    }

    /// After "</" is typed: fill in the nearest unclosed tag automatically.
    private func autoCompleteClosingTagIfNeeded() {
        let ns = string as NSString
        let caret = selectedRange().location
        guard caret >= 2,
              ns.substring(with: NSRange(location: caret - 2, length: 2)) == "</"
        else { return }
        // Never complete when a tag name already follows the caret.
        if caret < ns.length {
            let next = ns.substring(with: NSRange(location: caret, length: 1))
            if next.first?.isLetter == true { return }
        }
        guard let name = nearestUnclosedTag(before: caret - 2) else { return }
        insertRaw("\(name)>", at: NSRange(location: caret, length: 0))
        setSelectedRange(NSRange(location: caret + name.count + 1, length: 0))
    }

    private func nearestUnclosedTag(before location: Int) -> String? {
        let ns = string as NSString
        let start = max(0, location - 65_536)
        let context = ns.substring(with: NSRange(location: start, length: location - start))
        guard let regex = try? NSRegularExpression(
            pattern: #"<(/?)([a-zA-Z][\w-]*)(?:"[^"]*"|'[^']*'|[^>"'])*(/?)>"#
        ) else { return nil }
        var stack: [String] = []
        let cns = context as NSString
        regex.enumerateMatches(
            in: context, range: NSRange(location: 0, length: cns.length)
        ) { match, _, _ in
            guard let m = match else { return }
            let isClose = cns.substring(with: m.range(at: 1)) == "/"
            let name = cns.substring(with: m.range(at: 2))
            let selfClose = cns.substring(with: m.range(at: 3)) == "/"
            if isClose {
                if let idx = stack.lastIndex(where: { $0.lowercased() == name.lowercased() }) {
                    stack.removeSubrange(idx...)
                }
            } else if !selfClose && !CompletionData.voidTags.contains(name.lowercased()) {
                stack.append(name)
            }
        }
        return stack.last
    }

    // MARK: - Completion commit

    /// Inserts a completion item, replacing the typed prefix. Snippet bodies
    /// are re-indented to the current line and support a `$0` caret marker.
    func commitCompletion(_ item: CompletionItem, replacing prefixRange: NSRange) {
        let ns = string as NSString
        guard NSMaxRange(prefixRange) <= ns.length else { return }

        var body = item.insertText
        if item.kind == .snippet {
            let lineRange = ns.lineRange(
                for: NSRange(location: prefixRange.location, length: 0)
            )
            let line = ns.substring(with: lineRange)
            body = body.replacingOccurrences(
                of: "\n", with: "\n" + line.leadingIndentation
            )
        }

        let caretMarker = (body as NSString).range(of: "$0")
        if caretMarker.isValid {
            body = (body as NSString).replacingCharacters(in: caretMarker, with: "")
        }

        insertRaw(body, at: prefixRange)

        if caretMarker.isValid {
            setSelectedRange(NSRange(
                location: prefixRange.location + caretMarker.location, length: 0
            ))
        } else if item.cursorOffset != 0 {
            let end = prefixRange.location + (body as NSString).length
            setSelectedRange(NSRange(location: end + item.cursorOffset, length: 0))
        }
    }

    // MARK: - Helpers

    /// Undo-friendly primitive replacement used by all smart edits.
    private func insertRaw(_ text: String, at range: NSRange) {
        if shouldChangeText(in: range, replacementString: text) {
            textStorage?.replaceCharacters(in: range, with: text)
            didChangeText()
        }
    }

    private func stringValue(of insertString: Any) -> String? {
        (insertString as? String) ?? (insertString as? NSAttributedString)?.string
    }
}
