# ImageKit Auth Server

A ~60-line Cloudflare Worker that lets the Aurora editor upload email assets
to ImageKit **without ever exposing the private key to a browser**.

| Endpoint | Purpose |
| --- | --- |
| `GET /auth` | Returns `{ token, expire, signature }` — the credentials ImageKit requires for a client-side upload. |
| `GET /list?path=/email-assets` | Proxies the ImageKit Admin API to list images in a folder (the Admin API needs the private key, so the browser can't call it directly). |

## Security model

- The **public key** and URL endpoint (`https://ik.imagekit.io/<your_id>`) are safe
  to ship in the editor — they can't do anything without a signature.
- The **private key** exists only as a Worker secret. It is never in this
  repo, never in `localStorage`, never in the page.
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
