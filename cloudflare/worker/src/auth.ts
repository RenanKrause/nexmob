import type { Env, Installation } from './types';

interface InstallationRow extends Installation {
  token_hash: string;
}

/** Authenticate private sync credentials, independently of public piece tokens. */
export async function authenticateInstallation(
  request: Request,
  env: Env,
): Promise<Installation | null> {
  const authorization = request.headers.get('Authorization');
  const match = authorization?.match(/^Bearer +([A-Za-z0-9\-._~+/]+=*)$/i);
  if (!match) return null;

  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(match[1]));
  const hash = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
  // D1 only receives the digest, never the submitted secret.
  const row = await env.DB.prepare(
    'SELECT id, token_hash, revoked_at FROM installations WHERE token_hash = ?',
  ).bind(hash).first<InstallationRow>();

  // A fixed-size dummy comparison also covers an unknown digest. The indexed D1
  // lookup is not constant-time; no plaintext secrets are compared or persisted.
  const expected = row
    ? Uint8Array.from(row.token_hash.match(/../g)!, (byte) => Number.parseInt(byte, 16))
    : new Uint8Array(32);
  const matches = crypto.subtle.timingSafeEqual(digest, expected);
  if (!matches || !row || row.revoked_at !== null) return null;

  return { id: row.id, revoked_at: row.revoked_at };
}
