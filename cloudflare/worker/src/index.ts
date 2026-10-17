import { authenticateInstallation } from './auth';
import { ApiError, publishRevision, readPublicPiece } from './revisions';
import type { Env } from './types';

function configuredOrigin(value: string): string | null {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.origin === value ? value : null;
  } catch { return null; }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const path = new URL(request.url).pathname;
    const origin = request.headers.get('Origin');
    const allowedOrigin = configuredOrigin(env.PAGES_ORIGIN);
    const headers = new Headers({ 'Cache-Control': 'no-store', Vary: 'Origin', 'X-Content-Type-Options': 'nosniff' });
    if (origin && origin === allowedOrigin) headers.set('Access-Control-Allow-Origin', origin);
    const json = (body: unknown, status = 200) => Response.json(body, { status, headers });
    try {
      if (request.method === 'OPTIONS') {
        const method = request.headers.get('Access-Control-Request-Method');
        const requested = (request.headers.get('Access-Control-Request-Headers') ?? '')
          .split(',').map((header) => header.trim().toLowerCase()).filter(Boolean);
        const validRoute = path === '/v1/revisions' && method === 'POST'
          || (path === '/health' || /^\/v1\/public\/pieces\/[^/]+$/.test(path)) && method === 'GET';
        const permittedHeaders = method === 'POST' ? ['authorization', 'content-type'] : [];
        if (!origin || origin !== allowedOrigin || !validRoute || requested.some((header) => !permittedHeaders.includes(header))) {
          throw new ApiError(403, 'forbidden');
        }
        headers.set('Access-Control-Allow-Methods', method!);
        if (method === 'POST') headers.set('Access-Control-Allow-Headers', 'authorization, content-type');
        headers.set('Vary', 'Origin, Access-Control-Request-Method, Access-Control-Request-Headers');
        return new Response(null, { status: 204, headers });
      }
      if (request.method === 'GET' && path === '/health') return json({ status: 'ok' });
      if (request.method === 'POST' && path === '/v1/revisions') {
        if (origin && origin !== allowedOrigin) throw new ApiError(403, 'forbidden');
        const installation = await authenticateInstallation(request, env);
        if (!installation) throw new ApiError(401, 'unauthorized');
        let revision: unknown;
        try { revision = await request.json(); } catch { throw new ApiError(400, 'invalid_revision'); }
        await publishRevision(env, installation, revision);
        return json({ status: 'published' }, 201);
      }
      const match = path.match(/^\/v1\/public\/pieces\/([^/]+)$/);
      if (request.method === 'GET' && match) return json(await readPublicPiece(env, match[1]));
      throw new ApiError(404, 'not_found');
    } catch (error) {
      if (error instanceof ApiError) return json({ error: error.code }, error.status);
      // Do not expose SQL errors, bucket keys, request payloads or credentials.
      return json({ error: 'storage_unavailable' }, 503);
    }
  },
};
