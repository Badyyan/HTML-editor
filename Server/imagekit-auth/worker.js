/**
 * ImageKit auth server for the Aurora email-assets workflow.
 *
 * This is the ONLY place the ImageKit private key exists. It is provided as
 * a deployment secret — never commit it, never ship it to a browser.
 *
 * Endpoints:
 *   GET /auth              → { token, expire, signature } for client-side uploads
 *   GET /list?path=/email  → proxied ImageKit file listing for that folder
 *
 * Deploy on Cloudflare Workers:
 *   npm create cloudflare@latest imagekit-auth -- --type hello-world
 *   (replace src/index.js with this file, copy wrangler.toml from this folder)
 *   npx wrangler secret put IMAGEKIT_PRIVATE_KEY
 *   npx wrangler deploy
 *
 * Optional environment variable:
 *   ALLOWED_ORIGIN — lock CORS to your editor's origin (default "*").
 */

function corsHeaders(env) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

async function hmacSha1Hex(secret, message) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign(
    'HMAC', key, new TextEncoder().encode(message)
  );
  return [...new Uint8Array(signature)]
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const headers = { ...corsHeaders(env), 'content-type': 'application/json' };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders(env) });
    }
    if (!env.IMAGEKIT_PRIVATE_KEY) {
      return new Response(
        JSON.stringify({ error: 'IMAGEKIT_PRIVATE_KEY secret is not configured' }),
        { status: 500, headers }
      );
    }

    // Upload signature: signature = HMACSHA1(token + expire, privateKey).
    // "expire" must be within one hour of the upload reaching ImageKit.
    if (url.pathname === '/auth') {
      const token = crypto.randomUUID();
      const expire = Math.floor(Date.now() / 1000) + 30 * 60;
      const signature = await hmacSha1Hex(
        env.IMAGEKIT_PRIVATE_KEY, token + expire
      );
      return new Response(
        JSON.stringify({ token, expire, signature }),
        { headers }
      );
    }

    // Folder listing proxy — the ImageKit Admin API requires the private key,
    // so the browser can't call it directly.
    if (url.pathname === '/list') {
      // Confine listing to one base folder so this open, unauthenticated
      // proxy can't enumerate the entire ImageKit account. The requested
      // path is normalized and must sit inside BASE_PATH (default
      // /email-assets); anything else falls back to the base folder.
      const base = ('/' + (env.BASE_PATH || '/email-assets').replace(/^\/+|\/+$/g, ''));
      let want = '/' + String(url.searchParams.get('path') || base)
        .replace(/^\/+/, '').replace(/\.\.+/g, '');
      if (want !== base && !want.startsWith(base + '/')) want = base;
      const api = new URL('https://api.imagekit.io/v1/files');
      api.searchParams.set('path', want);
      api.searchParams.set('sort', 'DESC_CREATED');
      api.searchParams.set('limit', url.searchParams.get('limit') || '60');
      api.searchParams.set('fileType', 'image');
      const upstream = await fetch(api, {
        headers: {
          Authorization: 'Basic ' + btoa(env.IMAGEKIT_PRIVATE_KEY + ':'),
        },
      });
      return new Response(await upstream.text(), {
        status: upstream.status,
        headers,
      });
    }

    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers,
    });
  },
};
