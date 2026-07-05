# HTML Editor for macOS

A native, professional HTML editor for macOS built with **SwiftUI**, **AppKit**
and **WebKit** — multi-tab code editing with syntax highlighting and
IntelliSense on the left, a live, responsive preview on the right.

The UI follows Apple's Human Interface Guidelines: native toolbar, sidebar
file explorer, split-pane layout, rounded corners, material (glass) accents,
SF Pro / SF Mono typography, and full light/dark/custom theming.

```
┌────────────────────────────────────────────────────────────────────┐
│  Open │ Save │ Search │ Refresh │ Preview │ Browser │ ⚙︎ │ ?        │  ← native toolbar
├──────────────┬─────────────────────────────────────────────────────┤
│ ▸ Project    │  index.html ×   styles.css ×   +                    │  ← tab strip
│   Files      ├──────────────────────────┬──────────────────────────┤
│ ▸ Assets     │                          │  🖥  📱  ⟳  ↗            │
│ ▸ Favorites  │   Code editor            │                          │
│ ▸ Recent     │   (highlighting,         │   Live WKWebView         │
│   Files      │    completions,          │   preview                │
│              │    line numbers)         │                          │
├──────────────┴──────────────────────────┴──────────────────────────┤
│ HTML │ UTF-8 │ Ln 25, Col 14 │ Spaces: 4 │ 100% │ wrap │ preview   │  ← status bar
└────────────────────────────────────────────────────────────────────┘
```

## Features

**Editor**
- Multi-tab editing with dirty-state indicators
- Syntax highlighting for HTML, embedded CSS (`<style>`) and JavaScript
  (`<script>`), plus standalone `.css` / `.js` / `.json` files
- Line-number gutter, current-line highlight, bracket matching
- Auto indentation (smart block expansion for `{}` and between tags)
- Auto-closing brackets/quotes and auto-closing HTML tags
  (`>` completes `<div …>` → `</div>`, `</` fills in the open tag)
- Find & Replace with case sensitivity, regular expressions and $1…$9
  capture references, match highlighting and a live counter
- Full native Undo/Redo, smooth scrolling, large-file guard
  (highlighting steps aside above ~4 MB so typing stays instant)

**IntelliSense**
- HTML tag completion (type `<`), attribute suggestions per tag,
  CSS property completion inside `<style>` blocks,
  closing-tag suggestions, and snippets (`html5`, `nav`, `table`,
  `form`, `card`, `flexcenter`, …) — navigate with ↑/↓, accept with ⏎/⇥

**Live Preview**
- Split editor + preview with debounced live updates while typing
- Manual refresh, open preview in a separate window, open in default browser
- Responsive device modes: Desktop / Tablet (768×1024) / Mobile (390×844)
  rendered in a scaled device frame, with independent preview zoom

**Project Management**
- Open folder with a full file-explorer sidebar (Assets, Favorites,
  Recent Files sections), recent projects
- Create / rename / delete files and folders (delete moves to Trash)
- Drag & drop files from Finder onto the window to open them

**App**
- Light / Dark / System appearance + four built-in editor themes
  (Aurora Light, Aurora Dark, Midnight, Sandstone) and JSON custom themes
- Editor zoom (⌘+/⌘−/⌘0), word wrap, configurable tab width/font
- Auto save on an interval + save-on-quit, session restore
- Export HTML, export project as zip, ShareLink sharing, copy generated HTML
- Full keyboard-shortcut coverage and native full-screen support

## Building

Requirements: **macOS 13+**, **Xcode 15+**.

### Option A — open the Swift package (fastest)
1. `git clone` this repository.
2. In Xcode: **File ▸ Open…** and select `Package.swift` (or the repo folder).
3. Select the **HTMLEditor** scheme, destination **My Mac**, press **⌘R**.

### Option B — generate an .app bundle with XcodeGen
```bash
brew install xcodegen
xcodegen generate
open HTMLEditor.xcodeproj      # select the HTMLEditor scheme and Run
```
This produces a proper `.app` with Info.plist, hardened runtime and your
signing identity (set automatically via `CODE_SIGN_STYLE: Automatic`).

> The developer build runs unsandboxed so the editor can freely read and
> write user-chosen folders. For App Store distribution enable the sandbox
> in `project.yml` and adopt security-scoped bookmarks for recents.

## Architecture (MVVM)

```
Sources/HTMLEditor/
├── App/
│   ├── HTMLEditorApp.swift      @main; window scenes, Settings scene, AppDelegate
│   └── AppCommands.swift        menu bar + keyboard shortcuts
├── Models/
│   ├── Document.swift           an open buffer (text, URL, dirty state)
│   ├── FileNode.swift           file-explorer tree + builder
│   ├── Language.swift           language detection
│   └── EditorTheme.swift        theme model, built-ins, JSON theme loader
├── ViewModels/
│   ├── Workspace.swift          tabs, file ops, preview pipeline, session,
│   │                            recents/favorites, export & share
│   └── AppSettings.swift        persisted user preferences (single source)
├── Editor/                      reusable editor component (AppKit core)
│   ├── CodeEditorView.swift     NSViewRepresentable + Coordinator (delegate)
│   ├── CodeTextView.swift       smart typing: auto-indent, pairs, tag close
│   ├── SyntaxHighlighter.swift  tokenizer + debounced background engine
│   ├── CompletionController.swift  IntelliSense context detection + panel
│   ├── CompletionData.swift     tags / attributes / CSS / snippets catalogs
│   ├── EditorController.swift   find & replace bridge (SwiftUI ⇄ AppKit)
│   └── LineNumberRulerView.swift  gutter
├── Views/                       SwiftUI layer
│   ├── ContentView.swift        NavigationSplitView + toolbar + status bar
│   ├── SidebarView.swift        file explorer / assets / favorites / recents
│   ├── EditorTabsView.swift     tab strip
│   ├── FindReplaceBar.swift     inline find & replace UI
│   ├── PreviewPane.swift        device modes + preview chrome (+ window)
│   ├── PreviewWebView.swift     WKWebView wrapper
│   ├── StatusBarView.swift, WelcomeView.swift, SettingsView.swift, HelpView.swift
└── Support/Extensions.swift     shared helpers
```

Key design decisions:

- **TextKit 1, assembled explicitly.** The editor builds its
  NSTextStorage → NSLayoutManager → NSTextContainer stack by hand so the
  line-number ruler, temporary-attribute highlights (current line, bracket
  match, search matches) and the highlighter all target a stable API.
- **Highlighting off the main thread.** Edits are debounced (120 ms), the
  tokenizer runs on a utility queue over an immutable snapshot, and a version
  counter discards stale results — typing latency is never coupled to
  document size.
- **Non-overlapping tokens by construction.** The tokenizer claims ranges in
  an `IndexSet` in priority order (comments → script/style bodies → tags →
  entities), so embedded CSS/JS highlighting composes without conflicts.
- **One preview pipeline.** `Workspace` re-binds a Combine `debounce` to the
  active document's `$text`; the WKWebView reloads only when content actually
  changed, with a token to force manual refreshes. Relative assets resolve
  against the file's folder.
- **Session & preferences** are plain Codable snapshots in `UserDefaults`.

## Custom themes

Settings ▸ Themes ▸ **Open Themes Folder** creates
`~/Library/Application Support/HTMLEditor/Themes/My Theme.json`.
Duplicate it, edit the hex colors, then **Reload Themes**:

```json
{
  "name": "My Theme",
  "isDark": true,
  "background": "#12131C",
  "foreground": "#C8CCE0",
  "currentLine": "#1A1C29",
  "selection": "#2E3560",
  "gutterBackground": "#0F1017",
  "gutterForeground": "#4C5270",
  "caret": "#8B9BFF",
  "tokens": { "tag": "#8B9BFF", "string": "#8FE0C0", "comment": "#5A6080" }
}
```

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N / ⌘O / ⇧⌘O | New tab / Open file / Open folder |
| ⌘S / ⇧⌘S / ⌥⌘S | Save / Save As / Save All |
| ⌘W | Close tab |
| ⌘F, ⌘G, ⇧⌘G | Find & replace, next, previous |
| ⌘R | Refresh preview |
| ⌥⌘P / ⌥⌘B | Toggle preview / open in browser |
| ⇧⌘C | Copy generated HTML |
| ⌘+ / ⌘− / ⌘0 | Editor zoom |
| ⌃⌘F | Full screen |

## Roadmap

Deliberately not in v1: code folding, minimap and multiple cursors (the
TextKit 1 architecture supports adding them; folding is the planned first
addition), plus a Git gutter and Emmet-style abbreviations.
