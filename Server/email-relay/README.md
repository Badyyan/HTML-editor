# Send-Test Email Relay

A tiny Cloudflare Worker that lets the HTMLStudio editor **send a test email
of your design to yourself**. The editor is a static site and can't send
mail, so it POSTs the built HTML here; the Worker forwards it to
[Resend](https://resend.com) using an API key that never leaves the server.

| Endpoint | Purpose |
| --- | --- |
| `POST /send` | Body `{ to, subject, html }` → sends the email via Resend and returns the API response. |

## Security model

- The **Resend API key** exists only as a Worker secret — never in the repo,
  `localStorage`, or the browser.
- `/send` is open and unauthenticated, so **set `ALLOWED_RECIPIENTS`** to your
  own address(es). When set, the relay refuses to deliver anywhere else,
  which stops it from being used as a spam relay. Also add a Cloudflare
  **Rate Limiting** rule for defence in depth.
- Lock `ALLOWED_ORIGIN` to your editor's origin in production.

## Deploy (about 3 minutes)

```bash
# 1. Scaffold (or reuse an existing worker project)
npm create cloudflare@latest email-relay -- --type hello-world
cd email-relay
# 2. Replace src/index.js with worker.js and wrangler.toml from this folder.

# 3. Create a Resend account (free tier works), grab an API key, store it:
npx wrangler secret put RESEND_API_KEY

# 4. (Recommended) restrict the recipient + set your sender in wrangler.toml:
#    ALLOWED_RECIPIENTS = "you@example.com"
#    FROM_ADDRESS = "HTMLStudio <hello@yourdomain.com>"   # or use the default test sender

# 5. Ship it
npx wrangler deploy
# → https://email-relay.<your-subdomain>.workers.dev
```

Paste that URL into the editor the first time you use **Send test** in the
Builder. Until you verify a domain in Resend, use their test sender and send
only to the address on your Resend account.
