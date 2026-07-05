# Aurora Editor — Browser Version

A zero-install HTML/CSS/JS editor that runs entirely in a browser tab. No build step, no dependencies, no server required — `index.html` is the whole app.

## Run it

Just open `index.html` in a browser: double-click the file, or serve the folder with any static file server. Nothing to install.

## What it does

- Multi-tab editing with syntax highlighting for HTML (incl. embedded `<style>`/`<script>`), CSS, and JavaScript
- Line numbers, current-line highlight, auto-indent, auto-closing tags/brackets
- IntelliSense: tag/attribute/CSS-property completions and snippets (type `html5` + Tab for a boilerplate)
- Live preview with Desktop/Tablet/Mobile device frames
- Find & Replace (case-sensitive, regex, replace all)
- Three built-in themes (Aurora Dark/Light, Midnight) plus font size, zoom, word wrap
- ⌘D multi-word-select, ⌘-driven keyboard shortcuts (press ⇧⌘/ for the full list)

## Saving files

- **Chrome/Edge**: File ▸ Open Folder gives real read/write access to a folder on disk via the File System Access API — Save writes directly back.
- **Other browsers** (Safari, Firefox): folders open read-only via a file picker; Save downloads the file instead. The app detects this automatically and shows a banner.

Work in untitled/opened tabs is cached to `localStorage` so a reload doesn't lose it (this degrades gracefully if the browser blocks storage, e.g. private browsing).

## Design

Same "Aurora" color identity as the native macOS app (`Sources/HTMLEditor`), reimplemented independently for the browser — a considered dark ink / warm paper neutral pair, an indigo accent, and a teal reserved strictly for "live" preview-sync states.
