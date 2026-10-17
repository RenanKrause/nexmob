import { applyD1Migrations } from 'cloudflare:test';
import { env } from 'cloudflare:workers';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import worker from '../src/index';
import fixture from '../../../contracts/fixtures/revision-v1.json';
import type { Env, RevisionV1 } from '../src/types';

const origin = 'https://nexmob-test.pages.dev';
const token = '0123456789abcdef0123456789abcdef';
let secret: string;
let otherSecret: string;
const bindings = (): Env => ({ ...env, PAGES_ORIGIN: origin });
const revision = (): RevisionV1 => structuredClone(fixture) as RevisionV1;
const get = (qr = token, headers?: HeadersInit) =>
  worker.fetch(new Request(`https://api.example.test/v1/public/pieces/${qr}`, { headers }), bindings());
const post = (payload: unknown = revision(), credential: string | null = secret, customEnv = bindings(), requestOrigin?: string) => {
  const headers = new Headers({ 'Content-Type': 'application/json' });
  if (credential !== null) headers.set('Authorization', `Bearer ${credential}`);
  if (requestOrigin) headers.set('Origin', requestOrigin);
  return worker.fetch(new Request('https://api.example.test/v1/revisions', {
    method: 'POST', headers, body: JSON.stringify(payload),
  }), customEnv);
};
async function current(projectId = fixture.project_id) {
  return env.DB.prepare('SELECT current_revision_id FROM projects WHERE id = ?')
    .bind(projectId).first<{ current_revision_id: string }>();
}
// Real storage is used except at the explicitly injected R2 failure/race boundary.
function duringPut(action: () => Promise<void>, fail = false): Env {
  const bucket = new Proxy(env.REVISIONS, {
    get(target, key) {
      if (key === 'put') return async (...args: Parameters<R2Bucket['put']>) => {
        await action();
        if (fail) throw new Error('private storage details');
        return target.put(...args);
      };
      const value = Reflect.get(target, key);
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
  return { ...bindings(), REVISIONS: bucket };
}

beforeAll(async () => { await applyD1Migrations(env.DB, env.TEST_MIGRATIONS); });
beforeEach(async () => {
  await env.DB.batch([
    env.DB.prepare('DELETE FROM piece_tokens'),
    env.DB.prepare('UPDATE projects SET current_revision_id = NULL'),
    env.DB.prepare('DELETE FROM revisions'),
    env.DB.prepare('DELETE FROM projects'),
    env.DB.prepare('DELETE FROM installations'),
  ]);
  const objects = await env.REVISIONS.list();
  if (objects.objects.length) await env.REVISIONS.delete(objects.objects.map((object) => object.key));
  secret = crypto.randomUUID();
  otherSecret = crypto.randomUUID();
  for (const [id, credential] of [['a', secret], ['b', otherSecret]]) {
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(credential));
    const hash = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
    await env.DB.prepare('INSERT INTO installations (id, token_hash) VALUES (?, ?)').bind(id, hash).run();
  }
});

describe('revision HTTP API', () => {
  it('reports health without exposing bindings or credentials', async () => {
    const response = await worker.fetch(new Request('https://api.example.test/health'), bindings());
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'ok' });
  });

  it('publishes the full manifest and tokens before making the revision current', async () => {
    const response = await post();
    expect(response.status).toBe(201);
    expect((await current())?.current_revision_id).toBe(fixture.revision_id);
    const row = await env.DB.prepare('SELECT r2_key FROM revisions WHERE project_id = ? AND id = ?')
      .bind(fixture.project_id, fixture.revision_id).first<{ r2_key: string }>();
    expect(await (await env.REVISIONS.get(row!.r2_key))!.json()).toEqual(fixture);
    expect((await env.DB.prepare('SELECT token FROM piece_tokens').all()).results).toHaveLength(2);
  });

  it('publishes a complete project with 128 pieces within the free-tier D1 query budget', async () => {
    const payload = revision();
    payload.modules[0].pieces = Array.from({ length: 128 }, (_, i) => ({
      ...structuredClone(payload.modules[0].pieces[0]),
      logical_key: `piece-${i}`, qr_token: i.toString(16).padStart(32, '0'),
    }));
    let queryCount = 0;
    const consume = (count: number) => { if ((queryCount += count) > 50) throw new Error('D1 query limit exceeded'); };
    // Model only the documented free-tier query ceiling; every query still runs
    // on real D1 and every object is written to real local R2.
    const database = new Proxy(env.DB, {
      get(target, key) {
        if (key === 'prepare') return (sql: string) => {
          consume(1);
          return target.prepare(sql);
        };
        const value = Reflect.get(target, key);
        return typeof value === 'function' ? value.bind(target) : value;
      },
    });
    expect((await post(payload, secret, { ...bindings(), DB: database })).status).toBe(201);
    expect((await env.DB.prepare('SELECT token FROM piece_tokens').all()).results).toHaveLength(128);
    expect((await get('0'.repeat(32))).status).toBe(200);
  });

  it('returns only the selected module, its logical key and the current sync date', async () => {
    const payload = revision();
    payload.modules.push({ module_id: 'private-other', name: 'Other furniture', environment: 'Office', pieces: [
      { ...structuredClone(payload.modules[0].pieces[0]), qr_token: 'f'.repeat(32) },
    ] });
    expect((await post(payload)).status).toBe(201);
    const response = await get(token.toUpperCase(), { Origin: origin });
    expect(response.status).toBe(200);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    expect(response.headers.get('Access-Control-Allow-Origin')).toBe(origin);
    expect(await response.json()).toEqual({
      module: fixture.modules[0], selected_piece_key: 'lateral-esquerda', synced_at: '2026-10-17T16:00:00Z',
    });
    // Both modules intentionally use the same logical key. Selection must use
    // the QR token rather than a project-wide logical-key lookup.
    expect(await (await get('f'.repeat(32))).json()).toEqual({
      module: payload.modules[1], selected_piece_key: 'lateral-esquerda', synced_at: '2026-10-17T16:00:00Z',
    });
  });

  it('resolves an old QR against the latest revision and returns 404 for a removed piece', async () => {
    await post();
    const next = revision();
    next.revision_id = 'new'; next.synced_at = '2026-10-17T17:00:00Z';
    next.modules[0].pieces[0].cut_mm = [800, 600, 18];
    next.modules[0].pieces.pop();
    expect((await post(next)).status).toBe(201);
    expect(await (await get()).json()).toMatchObject({
      synced_at: '2026-10-17T17:00:00Z', module: { pieces: [{ cut_mm: [800, 600, 18] }] },
    });
    expect((await get('abcdef0123456789abcdef0123456789')).status).toBe(404);
  });

  it.each(['f'.repeat(32), 'short', 'g'.repeat(32), token + '/extra'])('returns a private 404 for unknown/malformed QR %s', async (qr) => {
    const response = await get(qr);
    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({ error: 'not_found' });
    expect(response.headers.get('Cache-Control')).toBe('no-store');
  });

  it.each([null, 'wrong-secret'])('rejects credentials without persisting anything: %s', async (credential) => {
    expect((await post(revision(), credential)).status).toBe(401);
    expect(await current()).toBeNull();
    expect((await env.REVISIONS.list()).objects).toHaveLength(0);
  });

  it('rejects revoked credentials', async () => {
    await env.DB.prepare("UPDATE installations SET revoked_at = 'now' WHERE id = 'a'").run();
    expect((await post()).status).toBe(401);
    expect(await current()).toBeNull();
  });

  it.each([
    ['missing version', (r: any) => { delete r.schema_version; }],
    ['unknown private field', (r: any) => { r.customer = 'private'; }],
    ['unknown nested field', (r: any) => { r.modules[0].pieces[0].secret = 'private'; }],
    ['nonpositive cut', (r: any) => { r.modules[0].pieces[0].cut_mm[0] = 0; }],
    ['wrong cut tuple', (r: any) => { r.modules[0].pieces[0].cut_mm.pop(); }],
    ['wrong transform tuple', (r: any) => { r.modules[0].pieces[0].transform_mm.push(1); }],
    ['invalid token', (r: any) => { r.modules[0].pieces[0].qr_token = 'g'.repeat(32); }],
    ['wrong boolean', (r: any) => { r.modules[0].pieces[0].visible = 'true'; }],
    ['duplicate token', (r: any) => { r.modules[0].pieces[1].qr_token = token.toUpperCase(); }],
    ['ambiguous logical key', (r: any) => { r.modules[0].pieces[1].logical_key = 'lateral-esquerda'; }],
    ['duplicate module ID', (r: any) => { r.modules.push({ ...r.modules[0], pieces: [] }); }],
  ])('rejects invalid contract data before storage: %s', async (_, mutate) => {
    const payload = revision(); mutate(payload);
    expect((await post(payload)).status).toBe(400);
    expect(await current()).toBeNull();
    expect((await env.REVISIONS.list()).objects).toHaveLength(0);
  });

  it('returns 400 for malformed JSON', async () => {
    const response = await worker.fetch(new Request('https://api.example.test/v1/revisions', {
      method: 'POST', headers: { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/json' }, body: '{',
    }), bindings());
    expect(response.status).toBe(400);
  });

  it('preserves the previous pointer and public scene when R2 fails', async () => {
    await post();
    const next = revision(); next.revision_id = 'failed'; next.modules[0].name = 'Changed';
    const response = await post(next, secret, duringPut(async () => {}, true));
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'storage_unavailable' });
    expect((await current())?.current_revision_id).toBe(fixture.revision_id);
    expect(await (await get()).json()).toMatchObject({ module: { name: 'Balcão inferior' } });
  });

  it('never overwrites an immutable revision or its current R2 object', async () => {
    await post();
    const changed = revision(); changed.modules[0].name = 'Overwrite';
    expect((await post(changed)).status).toBe(409);
    expect(await (await get()).json()).toMatchObject({ module: { name: 'Balcão inferior' } });
  });

  it('preserves a competing immutable R2 upload for the same revision ID', async () => {
    const competing = revision(); competing.modules[0].name = 'Competing upload';
    const custom = duringPut(async () => {
      await env.REVISIONS.put(
        `revisions/project-7c8a/${encodeURIComponent(fixture.revision_id)}.json`, JSON.stringify(competing),
      );
    });
    expect((await post(revision(), secret, custom)).status).toBe(409);
    expect(await current()).toBeNull();
    const object = await env.REVISIONS.get(`revisions/project-7c8a/${encodeURIComponent(fixture.revision_id)}.json`);
    expect(await object!.json()).toEqual(competing);
  });

  it('can retry an identical orphan after a failed D1 publication', async () => {
    const custom = duringPut(async () => {
      await env.DB.prepare("UPDATE installations SET revoked_at = 'now' WHERE id = 'a'").run();
    });
    expect((await post(revision(), secret, custom)).status).toBe(401);
    expect(await current()).toBeNull();
    await env.DB.prepare("UPDATE installations SET revoked_at = NULL WHERE id = 'a'").run();
    expect((await post()).status).toBe(201);
    expect((await get()).status).toBe(200);
  });

  it('does not expose a malformed private object stored under the current revision', async () => {
    await post();
    const corrupt = { ...revision(), private_customer: 'Must never appear publicly' };
    await env.REVISIONS.put(`revisions/project-7c8a/${encodeURIComponent(fixture.revision_id)}.json`, JSON.stringify(corrupt));
    const response = await get();
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'storage_unavailable' });
  });

  it('returns a recoverable error if the current revision object is unavailable', async () => {
    await post();
    await env.REVISIONS.delete(`revisions/project-7c8a/${encodeURIComponent(fixture.revision_id)}.json`);
    const response = await get();
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'storage_unavailable' });
  });

  it('keeps project and revision IDs with path separators isolated in R2', async () => {
    const payload = revision(); payload.project_id = 'project/a'; payload.revision_id = 'rev/a';
    expect((await post(payload)).status).toBe(201);
    expect(await env.REVISIONS.get('revisions/project%2Fa/rev%2Fa.json')).not.toBeNull();
    expect((await get()).status).toBe(200);
  });

  it('denies publishing another installation’s project', async () => {
    await post();
    const changed = revision(); changed.revision_id = 'stolen';
    expect((await post(changed, otherSecret)).status).toBe(403);
    expect((await current())?.current_revision_id).toBe(fixture.revision_id);
  });

  it.each([false, true])('never reassigns an existing token to another project (other installation: %s)', async (otherInstallation) => {
    await post();
    const changed = revision(); changed.project_id = 'other-project';
    expect((await post(changed, otherInstallation ? otherSecret : secret)).status).toBe(409);
    expect(await current('other-project')).toBeNull();
    expect(await (await get()).json()).toMatchObject({ module: { name: 'Balcão inferior' } });
  });

  it('allows the same revision ID in separate projects with different tokens', async () => {
    await post();
    const changed = revision(); changed.project_id = 'other-project';
    changed.modules[0].pieces.forEach((p, i) => { p.qr_token = String(i + 1).repeat(32); });
    expect((await post(changed, otherSecret)).status).toBe(201);
    expect((await current('other-project'))?.current_revision_id).toBe(fixture.revision_id);
  });

  it('rechecks revocation atomically after the R2 write', async () => {
    await post();
    const changed = revision(); changed.revision_id = 'revoked-during-upload';
    const custom = duringPut(async () => {
      await env.DB.prepare("UPDATE installations SET revoked_at = 'now' WHERE id = 'a'").run();
    });
    expect((await post(changed, secret, custom)).status).toBe(401);
    expect((await current())?.current_revision_id).toBe(fixture.revision_id);
  });

  it('rolls back the D1 batch if another project claims a token during R2 upload', async () => {
    await post();
    const changed = revision(); changed.revision_id = 'conflict';
    changed.modules[0].pieces[0].qr_token = 'e'.repeat(32);
    const custom = duringPut(async () => {
      await env.DB.batch([
        env.DB.prepare("INSERT INTO projects (id, installation_id) VALUES ('racer', 'b')"),
        env.DB.prepare('INSERT INTO piece_tokens (token, project_id, logical_key) VALUES (?, ?, ?)')
          .bind('e'.repeat(32), 'racer', 'other'),
      ]);
    });
    expect((await post(changed, secret, custom)).status).toBe(409);
    expect((await current())?.current_revision_id).toBe(fixture.revision_id);
    expect(await env.DB.prepare("SELECT id FROM revisions WHERE id = 'conflict'").first()).toBeNull();
    expect(await (await get()).json()).toMatchObject({ module: { name: 'Balcão inferior' } });
  });

  it('rejects a project ownership race during R2 upload', async () => {
    const custom = duringPut(async () => {
      await env.DB.prepare('INSERT INTO projects (id, installation_id) VALUES (?, ?)')
        .bind(fixture.project_id, 'b').run();
    });
    expect((await post(revision(), secret, custom)).status).toBe(403);
    expect((await current())?.current_revision_id).toBeNull();
    expect((await env.DB.prepare('SELECT * FROM piece_tokens').all()).results).toHaveLength(0);
  });

  it('allows only the configured Pages origin and safe preflight headers', async () => {
    const preflight = (requestOrigin: string, method = 'POST', headers = 'authorization, content-type') =>
      worker.fetch(new Request('https://api.example.test/v1/revisions', {
        method: 'OPTIONS', headers: { Origin: requestOrigin, 'Access-Control-Request-Method': method,
          'Access-Control-Request-Headers': headers },
      }), bindings());
    const allowed = await preflight(origin);
    expect(allowed.status).toBe(204);
    expect(allowed.headers.get('Access-Control-Allow-Origin')).toBe(origin);
    expect(allowed.headers.get('Access-Control-Allow-Headers')?.toLowerCase()).toBe('authorization, content-type');
    expect((await preflight('https://attacker.test')).status).toBe(403);
    expect((await preflight(origin, 'DELETE')).status).toBe(403);
    expect((await preflight(origin, 'POST', 'x-admin')).status).toBe(403);
    const denied = await post(revision(), secret, bindings(), 'https://attacker.test');
    expect(denied.status).toBe(403);
    expect(denied.headers.has('Access-Control-Allow-Origin')).toBe(false);
    expect(await current()).toBeNull();
    const publicPreflight = await worker.fetch(new Request(`https://api.example.test/v1/public/pieces/${token}`, {
      method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': 'GET' },
    }), bindings());
    expect(publicPreflight.status).toBe(204);
    expect(publicPreflight.headers.get('Access-Control-Allow-Methods')).toBe('GET');
    expect(publicPreflight.headers.get('Access-Control-Allow-Origin')).toBe(origin);
  });

  it('omits CORS for other origins on public reads and never permits a wildcard configuration', async () => {
    expect((await get(token, { Origin: 'https://attacker.test' })).headers.has('Access-Control-Allow-Origin')).toBe(false);
    expect((await post(revision(), secret, { ...bindings(), PAGES_ORIGIN: '*' }, origin)).status).toBe(403);
  });
});
