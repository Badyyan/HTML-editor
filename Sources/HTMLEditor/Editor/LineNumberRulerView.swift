//
//  LineNumberRulerView.swift
//  HTMLEditor
//
//  Vertical ruler that draws line numbers next to the code editor.
//  Uses TextKit 1 (NSLayoutManager) line fragments.
//

import AppKit

final class LineNumberRulerView: NSRulerView {

    var theme: EditorTheme = .auroraDark {
        didSet { needsDisplay = true }
    }

    private weak var textView: NSTextView?

    /// Match the flipped coordinate system of NSTextView so line positions
    /// computed from layout fragments map 1:1.
    override var isFlipped: Bool { true }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 44

        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange),
            name: NSText.didChangeNotification, object: textView
        )
        if let contentView = textView.enclosingScrollView?.contentView {
            contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(boundsDidChange),
                name: NSView.boundsDidChangeNotification, object: contentView
            )
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func textDidChange() {
        updateThickness()
        needsDisplay = true
    }

    @objc private func boundsDidChange() {
        needsDisplay = true
    }

    private func updateThickness() {
        guard let textView else { return }
        let lines = max(1, textView.string.reduce(into: 1) { if $1 == "\n" { $0 += 1 } })
        let digits = max(2, String(lines).count)
        let needed = CGFloat(digits) * 9 + 18
        if abs(needed - ruleThickness) > 1 { ruleThickness = needed }
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let container = textView.textContainer
        else { return }

        theme.gutterBackgroundColor.setFill()
        bounds.fill()

        // Hairline separator on the right edge.
        theme.gutterForegroundColor.withAlphaComponent(0.15).setFill()
        NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height).fill()

        let content = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: container)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Line number of the first visible character.
        var lineNumber = 1
        content.enumerateSubstrings(
            in: NSRange(location: 0, length: charRange.location),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in lineNumber += 1 }

        let font = NSFont.monospacedDigitSystemFont(
            ofSize: max(9, (textView.font?.pointSize ?? 13) - 2), weight: .regular
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.gutterForegroundColor
        ]
        let inset = textView.textContainerInset.height

        // Draw a number for every visible line fragment starting a new line.
        var index = charRange.location
        while index < NSMaxRange(charRange) {
            let lineRange = content.lineRange(for: NSRange(location: index, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            var fragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex, effectiveRange: nil
            )
            fragmentRect.origin.y += inset
            drawNumber(lineNumber, at: fragmentRect, in: visibleRect, with: attributes)
            lineNumber += 1
            index = NSMaxRange(lineRange)
            if lineRange.length == 0 { break }
        }

        // Trailing empty line (caret on a fresh last line).
        if content.length == 0 || content.hasSuffix("\n") {
            var extraRect = layoutManager.extraLineFragmentRect
            if extraRect.height > 0 {
                extraRect.origin.y += inset
                drawNumber(lineNumber, at: extraRect, in: visibleRect, with: attributes)
            }
        }
    }

    private func drawNumber(
        _ number: Int,
        at fragmentRect: NSRect,
        in visibleRect: NSRect,
        with attributes: [NSAttributedString.Key: Any]
    ) {
        let label = "\(number)" as NSString
        let size = label.size(withAttributes: attributes)
        let y = fragmentRect.minY - visibleRect.minY + (fragmentRect.height - size.height) / 2
        let x = ruleThickness - size.width - 10
        label.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
    }
}
