import { afterEach, describe, expect, it, vi } from 'vitest';
import fixture from '../../contracts/fixtures/revision-v1.json';
import { fetchPublicPiece } from './api';

const token = '0123456789abcdef0123456789abcdef';
const payload = () => ({ module: structuredClone(fixture.modules[0]), selected_piece_key: 'lateral-esquerda', synced_at: fixture.synced_at });

afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); });

describe('fetchPublicPiece', () => {
  it('resolves the public module on the configured Worker origin without credentials or cache', async () => {
    vi.stubEnv('VITE_API_ORIGIN', 'https://api.example.com');
    vi.stubGlobal('fetch', async (url: string, options: RequestInit) => {
      expect(url).toBe('https://api.example.com/v1/public/pieces/0123456789abcdef0123456789abcdef');
      expect(options.credentials).toBe('omit');
      expect(options.cache).toBe('no-store');
      expect(options.headers).toBeUndefined();
      return Response.json(payload());
    });
    const result = await fetchPublicPiece(token);
    expect(result.module.name).toBe('Balcão inferior');
    expect(result.selected_piece_key).toBe('lateral-esquerda');
    expect(result.module.pieces).toHaveLength(2);
  });

  it('uses the same origin by default', async () => {
    vi.stubEnv('VITE_API_ORIGIN', '');
    vi.stubGlobal('fetch', async (url: string) => {
      expect(url).toBe('/v1/public/pieces/0123456789abcdef0123456789abcdef');
      return Response.json(payload());
    });
    await fetchPublicPiece(token);
  });

  it('turns 404 into the QR not found state', async () => {
    vi.stubGlobal('fetch', async () => new Response(null, { status: 404 }));
    await expect(fetchPublicPiece(token)).rejects.toMatchObject({ kind: 'not-found', message: 'QR não encontrado' });
  });

  it('reports a recoverable network failure separately from an invalid QR', async () => {
    vi.stubGlobal('fetch', async () => { throw new TypeError('Failed to fetch'); });
    await expect(fetchPublicPiece(token)).rejects.toMatchObject({ kind: 'offline', message: expect.stringMatching(/conexão.*tente novamente/i) });
  });

  it('does not make a request for a malformed token', async () => {
    vi.stubGlobal('fetch', () => { throw new Error('Must not fetch malformed tokens'); });
    await expect(fetchPublicPiece('../private')).rejects.toMatchObject({ kind: 'not-found' });
  });

  it('distinguishes service failure from offline', async () => {
    vi.stubGlobal('fetch', async () => new Response(null, { status: 503 }));
    await expect(fetchPublicPiece(token)).rejects.toMatchObject({ kind: 'unavailable' });
  });

  it.each([
    ['missing selected piece', (p: ReturnType<typeof payload>) => { p.selected_piece_key = 'unknown'; }],
    ['invalid dimensions', (p: ReturnType<typeof payload>) => { p.module.pieces[0].cut_mm = [720, -1, 18]; }],
    ['ambiguous piece keys', (p: ReturnType<typeof payload>) => { p.module.pieces[1].logical_key = 'lateral-esquerda'; }],
    ['invalid timestamp', (p: ReturnType<typeof payload>) => { p.synced_at = 'yesterday'; }],
  ])('rejects invalid public responses: %s', async (_, change) => {
    const data = payload(); change(data);
    vi.stubGlobal('fetch', async () => Response.json(data));
    await expect(fetchPublicPiece(token)).rejects.toMatchObject({ kind: 'invalid-response' });
  });
});
