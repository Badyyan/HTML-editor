//
//  Language.swift
//  HTMLEditor
//
//  Languages the editor understands, plus file-extension detection.
//

import Foundation

enum Language: String, Codable, CaseIterable {
    case html
    case css
    case javascript
    case json
    case plain

    /// Name shown in the status bar.
    var displayName: String {
        switch self {
        case .html: return "HTML"
        case .css: return "CSS"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .plain: return "Plain Text"
        }
    }

    static func detect(from url: URL?) -> Language {
        guard let ext = url?.pathExtension.lowercased() else { return .html }
        switch ext {
        case "html", "htm", "xhtml": return .html
        case "css": return .css
        case "js", "mjs", "jsx": return .javascript
        case "json": return .json
        case "": return .html
        default: return .plain
        }
    }
}
