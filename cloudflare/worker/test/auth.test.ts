import { applyD1Migrations } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { authenticateInstallation } from '../src/auth';

let secret: string;
let tokenHash: string;

function request(authorization?: string): Request {
  return new Request('https://api.example.test/v1/revisions', {
    method: 'POST',
    headers: authorization === undefined ? {} : { Authorization: authorization },
  });
}

beforeAll(async () => {
  await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
});

beforeEach(async () => {
  await env.DB.batch([
    env.DB.prepare('DELETE FROM piece_tokens'),
    env.DB.prepare('UPDATE projects SET current_revision_id = NULL'),
    env.DB.prepare('DELETE FROM revisions'),
    env.DB.prepare('DELETE FROM projects'),
    env.DB.prepare('DELETE FROM installations'),
  ]);
  secret = crypto.randomUUID() + crypto.randomUUID();
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  tokenHash = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
  await env.DB.prepare('INSERT INTO installations (id, token_hash) VALUES (?, ?)')
    .bind('installation-a', tokenHash).run();
});

describe('authenticateInstallation', () => {
  it('authenticates the Bearer secret when D1 stores only its SHA-256 hash', async () => {
    expect(await authenticateInstallation(request(`Bearer ${secret}`), env)).toEqual({
      id: 'installation-a', revoked_at: null,
    });
    const stored = await env.DB.prepare('SELECT token_hash FROM installations WHERE id = ?')
      .bind('installation-a').first<{ token_hash: string }>();
    expect(stored?.token_hash).toBe(tokenHash);
    expect(stored?.token_hash).not.toBe(secret);
  });

  it.each([
    undefined,
    '',
    'Bearer',
    'Bearer ',
    'Basic unrelated',
    'Bearer wrong-secret',
    'Bearer two secrets',
    'Bearer first, Bearer second',
  ])('rejects absent, malformed or different credentials: %s', async (authorization) => {
    expect(await authenticateInstallation(request(authorization), env)).toBeNull();
  });

  it('accepts the case-insensitive HTTP Bearer scheme', async () => {
    expect((await authenticateInstallation(request(`bearer ${secret}`), env))?.id)
      .toBe('installation-a');
  });

  it('rejects a revoked installation even with the correct secret', async () => {
    await env.DB.prepare('UPDATE installations SET revoked_at = ? WHERE id = ?')
      .bind('2026-10-17T12:00:00Z', 'installation-a').run();
    expect(await authenticateInstallation(request(`Bearer ${secret}`), env)).toBeNull();
  });

  it('rejects a hash submitted as if it were the installation secret', async () => {
    expect(await authenticateInstallation(request(`Bearer ${tokenHash}`), env)).toBeNull();
  });

  it('does not use a public QR token as an installation credential', async () => {
    const qrToken = crypto.randomUUID().replaceAll('-', '');
    await env.DB.prepare('INSERT INTO projects (id, installation_id) VALUES (?, ?)')
      .bind('project-a', 'installation-a').run();
    await env.DB.prepare('INSERT INTO piece_tokens (token, project_id, module_id, logical_key) VALUES (?, ?, ?, ?)')
      .bind(qrToken, 'project-a', 'module-a', 'left').run();
    expect(await authenticateInstallation(request(`Bearer ${qrToken}`), env)).toBeNull();
  });

  it('does not authenticate a secret placed in the URL without a Bearer header', async () => {
    const queryRequest = new Request(`https://api.example.test/v1/revisions?token=${secret}`);
    expect(await authenticateInstallation(queryRequest, env)).toBeNull();
  });
});
