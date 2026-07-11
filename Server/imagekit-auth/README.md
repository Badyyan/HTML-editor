# ImageKit Auth Server

A ~60-line Cloudflare Worker that lets the Aurora editor upload email assets
to ImageKit **without ever exposing the private key to a browser**.

| Endpoint | Purpose |
| --- | --- |
| `GET /auth` | Returns `{ token, expire, signature }` — the credentials ImageKit requires for a client-side upload. The signature is `HMAC-SHA1(token + expire, private_key)` as lowercase hex, exactly as the [ImageKit upload API](https://imagekit.io/docs/api-reference/upload-file/upload-file) specifies. `expire` is a Unix timestamp 30 minutes out (the API allows up to 1 hour). |
| `GET /list?path=/email-assets` | Proxies the ImageKit Admin API to list images in a folder (the Admin API needs the private key, so the browser can't call it directly). |

## Security model

- The **public key** and URL endpoint (`https://ik.imagekit.io/<your_id>`) are safe
  to ship in the editor — they can't do anything without a signature.
- The **private key** exists only as a Worker secret. It is never in this
  repo, never in `localStorage`, never in the page.
- `/list` is **confined to a single base folder** so this open, unauthenticated
  proxy can't be used to enumerate your whole ImageKit account. The base is
  `BASE_PATH` (default `/email-assets`); any requested path is normalized and
  forced to sit inside it. **The editor's *Upload folder* must be `BASE_PATH`
  or a subfolder of it** — otherwise uploads succeed but the listing shows the
  base folder instead. Both default to `/email-assets`, so the default setup
  just works; if you change the editor's upload folder, set `BASE_PATH` to a
  matching ancestor in `wrangler.toml`.
- If the private key has ever been pasted into a chat, email, or ticket,
  **rotate it** in the ImageKit dashboard (Developer options → API keys)
  before deploying.

## Deploy (about 3 minutes)

```bash
# 1. Scaffold a worker project (or reuse an existing one)
npm create cloudflare@latest imagekit-auth -- --type hello-world
cd imagekit-auth

# 2. Replace src/index.js with worker.js from this folder,
#    and wrangler.toml with the one from this folder.

# 3. Store the private key as a secret (paste it when prompted)
npx wrangler secret put IMAGEKIT_PRIVATE_KEY

# 4. Ship it
npx wrangler deploy
# → https://imagekit-auth.<your-subdomain>.workers.dev
```

Paste that URL into the editor: **Email Assets ▸ ⚙ Configure ▸ Auth server URL**.

For production, set `ALLOWED_ORIGIN` in `wrangler.toml` to the exact origin
the editor runs on so other sites can't request upload signatures.

The same file also runs unchanged on Vercel Edge Functions or Deno Deploy
(both expose `fetch`-style handlers and Web Crypto).
