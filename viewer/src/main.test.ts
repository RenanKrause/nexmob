// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import fixture from '../../contracts/fixtures/revision-v1.json';

// WebGL is the external boundary: keep its canvas, button and cleanup effects.
const renderer = vi.hoisted(() => ({ live: 0, mounts: 0, actions: 0 }));
vi.mock('./view', () => ({
  mountScene: (_payload: unknown, host: HTMLElement, buttons: HTMLButtonElement[]) => {
    renderer.live++; renderer.mounts++;
    const canvas = document.createElement('canvas'); host.replaceChildren(canvas);
    const action = () => { renderer.actions++; };
    buttons.forEach(button => { button.disabled = false; button.addEventListener('click', action); });
    return () => {
      renderer.live--; canvas.remove();
      buttons.forEach(button => { button.disabled = true; button.removeEventListener('click', action); });
    };
  },
}));

let addListener: ReturnType<typeof vi.spyOn>;
let requests: number;
const publicPayload = () => ({ module: structuredClone(fixture.modules[0]), selected_piece_key: 'lateral-esquerda', synced_at: fixture.synced_at });
const transition = (type: 'pagehide' | 'pageshow', persisted: boolean) => window.dispatchEvent(new PageTransitionEvent(type, { persisted }));
const button = () => document.getElementById('rotate-view') as HTMLButtonElement;

beforeEach(() => {
  vi.resetModules();
  renderer.live = 0; renderer.mounts = 0; renderer.actions = 0; requests = 0;
  window.history.replaceState(null, '', '/p/0123456789abcdef0123456789abcdef');
  document.body.innerHTML = '<div id="app"></div>';
  addListener = vi.spyOn(window, 'addEventListener');
  vi.stubGlobal('fetch', async () => { requests++; return Response.json(publicPayload()); });
});

afterEach(() => {
  transition('pagehide', false);
  for (const [type, listener, options] of addListener.mock.calls) {
    if (type === 'pagehide' || type === 'pageshow') window.removeEventListener(type, listener, options);
  }
  vi.restoreAllMocks(); vi.unstubAllGlobals();
});

describe('viewer page lifecycle', () => {
  it('restores canvas and controls from cached data after BFCache, without duplicate renderers or listeners', async () => {
    await import('./main');
    await vi.waitFor(() => expect(document.querySelector('canvas')).not.toBeNull());
    expect(button().disabled).toBe(false);
    transition('pagehide', true);
    expect(document.querySelector('canvas')).toBeNull();
    expect(button().disabled).toBe(true);
    expect(renderer.live).toBe(0);

    transition('pageshow', true);
    await vi.waitFor(() => expect(document.querySelector('canvas')).not.toBeNull());
    expect(button().disabled).toBe(false);
    expect(renderer.live).toBe(1);
    expect(requests).toBe(1);
    transition('pageshow', true);
    await Promise.resolve(); await Promise.resolve();
    expect(renderer.mounts).toBe(2);
    button().click(); expect(renderer.actions).toBe(1);

    transition('pagehide', true); transition('pagehide', true);
    expect(renderer.live).toBe(0);
    transition('pageshow', true); transition('pageshow', true);
    await vi.waitFor(() => expect(document.querySelector('canvas')).not.toBeNull());
    expect(renderer.live).toBe(1);
    button().click(); expect(renderer.actions).toBe(2);
    expect(requests).toBe(1);
  });

  it('does not mount or fetch again for non-persisted pageshow events', async () => {
    await import('./main');
    await vi.waitFor(() => expect(document.querySelector('canvas')).not.toBeNull());
    transition('pageshow', false);
    expect(renderer.mounts).toBe(1);
    transition('pagehide', false); transition('pageshow', false);
    await Promise.resolve(); await Promise.resolve();
    expect(document.querySelector('canvas')).toBeNull();
    expect(renderer.live).toBe(0);
    expect(requests).toBe(1);
  });

  it('does not restore a scene for an invalid QR with no loaded payload', async () => {
    window.history.replaceState(null, '', '/p/invalido');
    await import('./main');
    transition('pagehide', true); transition('pageshow', true);
    await Promise.resolve(); await Promise.resolve();
    expect(renderer.live).toBe(0);
    expect(requests).toBe(0);
    expect(document.querySelector('#status h1')?.textContent).toBe('QR inválido');
  });

  it('does not mount a response that arrives while hidden, and restores it without another fetch', async () => {
    let release!: (response: Response) => void;
    vi.stubGlobal('fetch', () => { requests++; return new Promise<Response>(resolve => { release = resolve; }); });
    await import('./main');
    transition('pagehide', true);
    release(Response.json(publicPayload()));
    await vi.waitFor(() => expect(document.getElementById('piece-name')?.textContent).toBe('Lateral esquerda'));
    expect(document.querySelector('canvas')).toBeNull();
    expect(renderer.live).toBe(0);
    transition('pageshow', true);
    await vi.waitFor(() => expect(document.querySelector('canvas')).not.toBeNull());
    expect(renderer.live).toBe(1);
    expect(requests).toBe(1);
  });
});
