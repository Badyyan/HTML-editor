/**
 * Send-a-test-email relay for HTMLStudio.
 *
 * The editor is a static site, so it can't send email itself. This tiny
 * Cloudflare Worker takes { to, subject, html } and forwards it to Resend
 * (https://resend.com) using an API key that lives only as a Worker secret.
 *
 * Endpoint:
 *   POST /send   body: { "to": "...", "subject": "...", "html": "..." }
 *
 * Deploy:
 *   npx wrangler secret put RESEND_API_KEY
 *   npx wrangler deploy
 *
 * Environment:
 *   RESEND_API_KEY      (secret, required) — your Resend API key.
 *   FROM_ADDRESS        e.g. "HTMLStudio <you@yourdomain.com>". Defaults to
 *                       Resend's test sender for quick trials.
 *   ALLOWED_ORIGIN      lock CORS to your editor's origin (default "*").
 *   ALLOWED_RECIPIENTS  comma-separated allowlist. When set, /send only
 *                       delivers to these addresses — this keeps the open,
 *                       unauthenticated endpoint from being abused as a
 *                       spam relay. Set it to your own address(es).
 */

function cors(env) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}
function json(body, status, headers) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'content-type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    const headers = cors(env);
    if (request.method === 'OPTIONS') return new Response(null, { headers });

    const url = new URL(request.url);
    if (url.pathname !== '/send' || request.method !== 'POST') {
      return json({ error: 'Not found' }, 404, headers);
    }
    if (!env.RESEND_API_KEY) {
      return json({ error: 'RESEND_API_KEY secret is not configured' }, 500, headers);
    }

    let body;
    try { body = await request.json(); }
    catch { return json({ error: 'Invalid JSON body' }, 400, headers); }

    const to = String(body.to || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(to)) {
      return json({ error: 'A valid "to" address is required' }, 400, headers);
    }
    // Anti-abuse: if an allowlist is configured, refuse anything outside it.
    if (env.ALLOWED_RECIPIENTS) {
      const allowed = env.ALLOWED_RECIPIENTS.split(',').map(s => s.trim().toLowerCase());
      if (!allowed.includes(to.toLowerCase())) {
        return json({ error: 'That recipient is not allowed by this relay.' }, 403, headers);
      }
    }
    const subject = String(body.subject || 'Test email').slice(0, 200);
    const html = String(body.html || '');
    if (!html) return json({ error: 'Missing html' }, 400, headers);

    const from = env.FROM_ADDRESS || 'HTMLStudio <onboarding@resend.dev>';
    const upstream = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + env.RESEND_API_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from, to, subject, html }),
    });
    return new Response(await upstream.text(), {
      status: upstream.status,
      headers: { ...headers, 'content-type': 'application/json' },
    });
  },
};
