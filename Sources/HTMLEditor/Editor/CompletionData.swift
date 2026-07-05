//
//  CompletionData.swift
//  HTMLEditor
//
//  Static IntelliSense catalogs: HTML tags, attributes per tag, CSS
//  properties and HTML snippets.
//

import Foundation

enum CompletionKind {
    case tag, attribute, cssProperty, snippet, closingTag, keyword

    var symbolName: String {
        switch self {
        case .tag: return "chevron.left.forwardslash.chevron.right"
        case .attribute: return "at"
        case .cssProperty: return "paintbrush"
        case .snippet: return "square.on.square"
        case .closingTag: return "arrow.uturn.backward"
        case .keyword: return "k.square"
        }
    }
}

struct CompletionItem {
    let label: String          // shown in the list
    let detail: String         // secondary text
    let kind: CompletionKind
    let insertText: String     // text inserted in place of the typed prefix
    /// Caret offset from the END of insertText after committing
    /// (e.g. -1 puts the caret inside `""`).
    let cursorOffset: Int

    init(label: String, detail: String = "", kind: CompletionKind,
         insertText: String? = nil, cursorOffset: Int = 0) {
        self.label = label
        self.detail = detail
        self.kind = kind
        self.insertText = insertText ?? label
        self.cursorOffset = cursorOffset
    }
}

struct Snippet {
    let trigger: String
    let label: String
    let body: String   // "$0" marks the final caret position
}

enum CompletionData {

    // MARK: - HTML tags

    static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    static let htmlTags: [String] = [
        "a", "abbr", "address", "area", "article", "aside", "audio",
        "b", "base", "bdi", "bdo", "blockquote", "body", "br", "button",
        "canvas", "caption", "cite", "code", "col", "colgroup",
        "data", "datalist", "dd", "del", "details", "dfn", "dialog",
        "div", "dl", "dt", "em", "embed",
        "fieldset", "figcaption", "figure", "footer", "form",
        "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html",
        "i", "iframe", "img", "input", "ins", "kbd", "label", "legend", "li", "link",
        "main", "map", "mark", "menu", "meta", "meter",
        "nav", "noscript", "object", "ol", "optgroup", "option", "output",
        "p", "param", "picture", "pre", "progress", "q",
        "rp", "rt", "ruby", "s", "samp", "script", "section", "select",
        "slot", "small", "source", "span", "strong", "style",
        "sub", "summary", "sup", "table", "tbody", "td", "template",
        "textarea", "tfoot", "th", "thead", "time", "title", "tr", "track",
        "u", "ul", "var", "video", "wbr"
    ]

    // MARK: - Attributes

    static let globalAttributes: [String] = [
        "accesskey", "aria-hidden", "aria-label", "aria-labelledby", "class",
        "contenteditable", "data-", "dir", "draggable", "hidden", "id",
        "lang", "role", "spellcheck", "style", "tabindex", "title", "translate"
    ]

    static let tagAttributes: [String: [String]] = [
        "a": ["href", "target", "rel", "download", "hreflang", "type"],
        "img": ["src", "alt", "width", "height", "loading", "srcset", "sizes", "decoding"],
        "input": ["type", "name", "value", "placeholder", "required", "disabled",
                  "readonly", "checked", "min", "max", "step", "pattern",
                  "autocomplete", "autofocus", "maxlength", "minlength"],
        "form": ["action", "method", "enctype", "target", "novalidate", "autocomplete"],
        "button": ["type", "disabled", "name", "value", "form"],
        "select": ["name", "multiple", "required", "disabled", "size"],
        "option": ["value", "selected", "disabled", "label"],
        "textarea": ["name", "rows", "cols", "placeholder", "required", "maxlength", "wrap"],
        "label": ["for", "form"],
        "link": ["rel", "href", "type", "media", "sizes", "crossorigin", "integrity"],
        "meta": ["name", "content", "charset", "http-equiv", "property"],
        "script": ["src", "type", "defer", "async", "crossorigin", "integrity", "nomodule"],
        "style": ["media", "type"],
        "iframe": ["src", "width", "height", "title", "allow", "allowfullscreen",
                   "loading", "sandbox", "frameborder"],
        "video": ["src", "controls", "autoplay", "loop", "muted", "poster",
                  "width", "height", "playsinline", "preload"],
        "audio": ["src", "controls", "autoplay", "loop", "muted", "preload"],
        "source": ["src", "srcset", "type", "media", "sizes"],
        "table": ["border", "cellpadding", "cellspacing"],
        "td": ["colspan", "rowspan", "headers"],
        "th": ["colspan", "rowspan", "scope", "headers"],
        "ol": ["start", "reversed", "type"],
        "time": ["datetime"],
        "details": ["open"],
        "dialog": ["open"],
        "progress": ["value", "max"],
        "meter": ["value", "min", "max", "low", "high", "optimum"],
        "canvas": ["width", "height"],
        "track": ["src", "kind", "srclang", "label", "default"],
        "html": ["lang", "dir"],
        "body": ["onload"]
    ]

    static func attributes(for tag: String) -> [String] {
        let specific = tagAttributes[tag.lowercased()] ?? []
        return (specific + globalAttributes).sorted()
    }

    // MARK: - CSS properties

    static let cssProperties: [String] = [
        "align-content", "align-items", "align-self", "all", "animation",
        "animation-delay", "animation-direction", "animation-duration",
        "animation-fill-mode", "animation-iteration-count", "animation-name",
        "animation-timing-function", "appearance", "aspect-ratio",
        "backdrop-filter", "background", "background-attachment",
        "background-blend-mode", "background-clip", "background-color",
        "background-image", "background-origin", "background-position",
        "background-repeat", "background-size", "border", "border-bottom",
        "border-collapse", "border-color", "border-left", "border-radius",
        "border-right", "border-spacing", "border-style", "border-top",
        "border-width", "bottom", "box-shadow", "box-sizing",
        "caret-color", "clear", "clip-path", "color", "column-gap", "columns",
        "content", "cursor", "direction", "display",
        "filter", "flex", "flex-basis", "flex-direction", "flex-flow",
        "flex-grow", "flex-shrink", "flex-wrap", "float", "font",
        "font-family", "font-size", "font-style", "font-variant", "font-weight",
        "gap", "grid", "grid-area", "grid-auto-columns", "grid-auto-flow",
        "grid-auto-rows", "grid-column", "grid-gap", "grid-row",
        "grid-template", "grid-template-areas", "grid-template-columns",
        "grid-template-rows", "height", "inset", "isolation",
        "justify-content", "justify-items", "justify-self",
        "left", "letter-spacing", "line-height", "list-style",
        "list-style-position", "list-style-type",
        "margin", "margin-bottom", "margin-left", "margin-right", "margin-top",
        "mask", "max-height", "max-width", "min-height", "min-width",
        "mix-blend-mode", "object-fit", "object-position", "opacity", "order",
        "outline", "outline-color", "outline-offset", "outline-style",
        "outline-width", "overflow", "overflow-x", "overflow-y",
        "padding", "padding-bottom", "padding-left", "padding-right",
        "padding-top", "perspective", "place-content", "place-items",
        "place-self", "pointer-events", "position",
        "resize", "right", "row-gap", "scroll-behavior", "scroll-snap-align",
        "scroll-snap-type", "text-align", "text-decoration",
        "text-decoration-color", "text-decoration-line", "text-indent",
        "text-overflow", "text-shadow", "text-transform", "top", "transform",
        "transform-origin", "transition", "transition-delay",
        "transition-duration", "transition-property",
        "transition-timing-function", "user-select", "vertical-align",
        "visibility", "white-space", "width", "will-change", "word-break",
        "word-spacing", "word-wrap", "writing-mode", "z-index"
    ]

    // MARK: - Snippets

    static let snippets: [Snippet] = [
        Snippet(
            trigger: "html5",
            label: "HTML5 boilerplate",
            body: """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>$0</title>
            </head>
            <body>

            </body>
            </html>
            """
        ),
        Snippet(
            trigger: "viewport",
            label: "Viewport meta tag",
            body: #"<meta name="viewport" content="width=device-width, initial-scale=1.0">$0"#
        ),
        Snippet(
            trigger: "css",
            label: "Stylesheet link",
            body: #"<link rel="stylesheet" href="$0">"#
        ),
        Snippet(
            trigger: "js",
            label: "Script tag",
            body: #"<script src="$0"></script>"#
        ),
        Snippet(
            trigger: "nav",
            label: "Navigation bar",
            body: """
            <nav>
                <ul>
                    <li><a href="#">$0</a></li>
                    <li><a href="#"></a></li>
                    <li><a href="#"></a></li>
                </ul>
            </nav>
            """
        ),
        Snippet(
            trigger: "table",
            label: "Table with header",
            body: """
            <table>
                <thead>
                    <tr>
                        <th>$0</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td></td>
                        <td></td>
                    </tr>
                </tbody>
            </table>
            """
        ),
        Snippet(
            trigger: "form",
            label: "Form with input",
            body: """
            <form action="#" method="post">
                <label for="name">$0</label>
                <input type="text" id="name" name="name" required>
                <button type="submit">Submit</button>
            </form>
            """
        ),
        Snippet(
            trigger: "flexcenter",
            label: "Flexbox centering (CSS)",
            body: """
            display: flex;
            align-items: center;
            justify-content: center;$0
            """
        ),
        Snippet(
            trigger: "grid3",
            label: "3-column grid (CSS)",
            body: """
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 16px;$0
            """
        ),
        Snippet(
            trigger: "card",
            label: "Card component",
            body: """
            <div class="card">
                <img src="$0" alt="">
                <h3></h3>
                <p></p>
            </div>
            """
        ),
        Snippet(
            trigger: "video",
            label: "Video element",
            body: """
            <video controls width="640">
                <source src="$0" type="video/mp4">
            </video>
            """
        )
    ]
}
