//
//  Extensions.swift
//  HTMLEditor
//
//  Small shared helpers used across the app.
//

import AppKit

extension NSColor {
    /// Creates a color from a hex string like "#RRGGBB" or "#RRGGBBAA".
    convenience init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var rgba: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgba)
        let r, g, b, a: CGFloat
        if value.count == 8 {
            r = CGFloat((rgba & 0xFF00_0000) >> 24) / 255
            g = CGFloat((rgba & 0x00FF_0000) >> 16) / 255
            b = CGFloat((rgba & 0x0000_FF00) >> 8) / 255
            a = CGFloat(rgba & 0x0000_00FF) / 255
        } else {
            r = CGFloat((rgba & 0xFF0000) >> 16) / 255
            g = CGFloat((rgba & 0x00FF00) >> 8) / 255
            b = CGFloat(rgba & 0x0000FF) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

extension NSString {
    /// Line (1-based) and column (1-based) for a character location.
    func lineAndColumn(for location: Int) -> (line: Int, column: Int) {
        let loc = min(location, length)
        var line = 1
        var lastLineStart = 0
        var index = 0
        while index < loc {
            let c = character(at: index)
            if c == 0x0A { // \n
                line += 1
                lastLineStart = index + 1
            }
            index += 1
        }
        return (line, loc - lastLineStart + 1)
    }
}

extension NSRange {
    var isValid: Bool { location != NSNotFound }
}

extension String {
    /// Leading whitespace (spaces/tabs) of the string.
    var leadingIndentation: String {
        String(prefix { $0 == " " || $0 == "\t" })
    }
}

extension URL {
    /// True when the URL points to a directory that exists on disk.
    var isExistingDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}
