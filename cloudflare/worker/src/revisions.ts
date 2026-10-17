import validate from './revision-validator.js';
import type { Env, Installation, RevisionModule, RevisionV1 } from './types';

export class ApiError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}

function validateRevision(value: unknown): RevisionV1 {
  if (!validate(value)) throw new ApiError(400, 'invalid_revision');
  const tokens = new Set<string>();
  const modules = new Set<string>();
  for (const module of value.modules) {
    if (modules.has(module.module_id)) throw new ApiError(400, 'invalid_revision');
    modules.add(module.module_id);
    const keys = new Set<string>();
    for (const piece of module.pieces) {
      const token = piece.qr_token.toLowerCase();
      if (tokens.has(token) || keys.has(piece.logical_key)) throw new ApiError(400, 'invalid_revision');
      tokens.add(token); keys.add(piece.logical_key);
    }
  }
  return value;
}

async function checkOwner(env: Env, installation: Installation, projectId: string): Promise<void> {
  const active = await env.DB.prepare('SELECT id FROM installations WHERE id = ? AND revoked_at IS NULL')
    .bind(installation.id).first();
  if (!active) throw new ApiError(401, 'unauthorized');
  const project = await env.DB.prepare('SELECT installation_id FROM projects WHERE id = ?')
    .bind(projectId).first<{ installation_id: string }>();
  if (project && project.installation_id !== installation.id) throw new ApiError(403, 'forbidden');
}

/** Persist an immutable object first; one D1 transaction then publishes its index. */
export async function publishRevision(env: Env, installation: Installation, value: unknown): Promise<void> {
  const revision = validateRevision(value);
  await checkOwner(env, installation, revision.project_id);
  const existing = await env.DB.prepare('SELECT id FROM revisions WHERE project_id = ? AND id = ?')
    .bind(revision.project_id, revision.revision_id).first();
  if (existing) throw new ApiError(409, 'revision_conflict');

  // One bound JSON array avoids a query per piece (D1 Free permits 50 queries
  // per invocation), and keeps the token write inside the publication batch.
  const tokenIndex = JSON.stringify(revision.modules.flatMap((module) => module.pieces.map((piece) => ({
    token: piece.qr_token.toLowerCase(), module_id: module.module_id, logical_key: piece.logical_key,
  }))));
  const conflict = await env.DB.prepare(`SELECT t.token FROM json_each(?) p
    JOIN piece_tokens t ON t.token = json_extract(p.value, '$.token')
    WHERE t.project_id <> ? OR t.module_id <> json_extract(p.value, '$.module_id')
      OR t.logical_key <> json_extract(p.value, '$.logical_key') LIMIT 1`)
    .bind(tokenIndex, revision.project_id).first();
  if (conflict) throw new ApiError(409, 'token_conflict');

  const key = `revisions/${encodeURIComponent(revision.project_id)}/${encodeURIComponent(revision.revision_id)}.json`;
  const body = JSON.stringify(revision);
  try {
    const stored = await env.REVISIONS.put(key, body, {
      onlyIf: { etagDoesNotMatch: '*' },
      httpMetadata: { contentType: 'application/json', cacheControl: 'no-store' },
    });
    // A failed D1 publication can leave an orphan. Allow retrying its identical
    // manifest, but never overwrite a competing upload or a published revision.
    if (!stored && await (await env.REVISIONS.get(key))?.text() !== body) {
      throw new ApiError(409, 'revision_conflict');
    }
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(503, 'storage_unavailable');
  }

  try {
    await env.DB.batch([
      // NULL violates the existing NOT NULL constraint on revocation or an
      // ownership race. The entire batch then rolls back, including the pointer.
      env.DB.prepare(`INSERT INTO projects (id, installation_id)
        VALUES (?, (SELECT id FROM installations WHERE id = ? AND revoked_at IS NULL))
        ON CONFLICT(id) DO UPDATE SET installation_id = CASE
          WHEN projects.installation_id = excluded.installation_id THEN excluded.installation_id
          ELSE NULL END`).bind(revision.project_id, installation.id),
      env.DB.prepare('INSERT INTO revisions (id, project_id, synced_at, r2_key) VALUES (?, ?, ?, ?)')
        .bind(revision.revision_id, revision.project_id, revision.synced_at, key),
      env.DB.prepare(`INSERT INTO piece_tokens (token, project_id, module_id, logical_key)
        SELECT json_extract(value, '$.token'), ?, json_extract(value, '$.module_id'), json_extract(value, '$.logical_key')
        FROM json_each(?) WHERE true
        ON CONFLICT(token) DO UPDATE SET logical_key = CASE
          WHEN piece_tokens.project_id = excluded.project_id AND piece_tokens.module_id = excluded.module_id
            AND piece_tokens.logical_key = excluded.logical_key
          THEN excluded.logical_key ELSE NULL END`)
        .bind(revision.project_id, tokenIndex),
      env.DB.prepare('UPDATE projects SET current_revision_id = ? WHERE id = ? AND installation_id = ?')
        .bind(revision.revision_id, revision.project_id, installation.id),
    ]);
  } catch (error) {
    await checkOwner(env, installation, revision.project_id);
    // Constraint conflicts are safe publication failures, not partial writes.
    if (error instanceof Error && /constraint failed/i.test(error.message)) throw new ApiError(409, 'publication_conflict');
    throw new ApiError(503, 'storage_unavailable');
  }
}

export interface PublicPieceResponse {
  module: RevisionModule;
  selected_piece_key: string;
  synced_at: string;
}

export async function readPublicPiece(env: Env, token: string): Promise<PublicPieceResponse> {
  if (!/^[0-9a-f]{32}$/i.test(token)) throw new ApiError(404, 'not_found');
  const row = await env.DB.prepare(`SELECT r.r2_key, r.project_id, r.id, t.module_id, t.logical_key FROM piece_tokens t
    JOIN projects p ON p.id = t.project_id
    JOIN revisions r ON r.project_id = p.id AND r.id = p.current_revision_id
    WHERE t.token = ?`).bind(token).first<{
      r2_key: string; project_id: string; id: string; module_id: string; logical_key: string;
    }>();
  if (!row) throw new ApiError(404, 'not_found');
  const object = await env.REVISIONS.get(row.r2_key);
  if (!object) throw new ApiError(503, 'storage_unavailable');
  const value: unknown = await object.json();
  if (!validate(value) || value.project_id !== row.project_id || value.revision_id !== row.id) {
    throw new ApiError(503, 'storage_unavailable');
  }
  for (const module of value.modules) {
    if (module.module_id !== row.module_id) continue;
    const piece = module.pieces.find((candidate) => candidate.qr_token.toLowerCase() === token.toLowerCase()
      && candidate.logical_key === row.logical_key);
    if (piece) return { module, selected_piece_key: piece.logical_key, synced_at: value.synced_at };
  }
  // Token history stays reserved, but removed pieces do not resolve publicly.
  throw new ApiError(404, 'not_found');
}
