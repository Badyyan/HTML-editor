# Aurora — Zero-Install Email Studio (Web)

A complete static website: marketing landing page, account flow, dashboard,
and the full editor. No build step — every page is plain HTML/CSS/JS served
as-is.

| Page | Purpose |
| --- | --- |
| `index.html` | Landing page with features and Sign up / Log in CTAs |
| `signup.html`, `login.html`, `reset.html` | Account flow (see note below) |
| `dashboard.html` | Signed-in home: workspace stats + quick actions |
| `editor.html` | The studio: drag-and-drop builder, code editor, live preview, template library, UTM builder, ImageKit assets |
| `auth.js`, `aurora.css` | Shared account module and site design system |

## Running locally

Serve the folder with any static server and open `index.html`:

```bash
cd WebApp && python3 -m http.server 8080
# → http://localhost:8080
```

(Opening files directly with `file://` also works for the editor, but the
auth redirects behave best over HTTP.)

## About the authentication

This is a **front-end-only** account system, honestly scoped:

- Accounts live in the visitor's own browser (`localStorage`); passwords are
  salted and SHA-256-hashed via WebCrypto before storage; sessions are local.
- Because a static site has no server, this is a complete *flow*, not
  server-enforced security: accounts don't sync between devices, and the
  password-reset code is displayed on screen (where a hosted backend would
  email it).
- To upgrade to real multi-device auth, connect a service like Supabase,
  Clerk, or Auth.js and swap the storage calls inside `auth.js` — every page
  already goes through that one module.

## Editor highlights

- Builder mode: 11 email-safe blocks, drag to arrange, per-block inspector,
  custom saved blocks, RTL/LTR, exports responsive 600px table HTML
- Code mode: HTML/CSS/JS highlighting, IntelliSense, snippets, find & replace
  with regex, multi-cursor, themes, zoom, word wrap
- Live preview with desktop/tablet/mobile device frames
- Template library (starters + your saved designs)
- UTM builder with manageable quick presets (pin, reorder, defaults)
- Optional ImageKit integration for CDN-hosted images — bring your own
  account; see `../Server/imagekit-auth` for the required auth worker

## Deployment

Any static host works (Vercel, Netlify, GitHub Pages, Cloudflare Pages,
Tiiny Host…). The repo root `vercel.json` is preconfigured to serve this
folder — connecting the GitHub repo to Vercel gives automatic deploys on
every push.
