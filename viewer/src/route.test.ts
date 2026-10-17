import { describe, expect, it } from 'vitest';
import { parsePieceRoute } from './route';

describe('parsePieceRoute', () => {
  it('accepts an exact public QR path with a 128-bit hexadecimal token', () => {
    expect(parsePieceRoute('/p/0123456789abcdef0123456789abcdef')).toBe('0123456789abcdef0123456789abcdef');
  });

  it('normalizes uppercase hexadecimal tokens for the public lookup', () => {
    expect(parsePieceRoute('/p/0123456789ABCDEF0123456789ABCDEF')).toBe('0123456789abcdef0123456789abcdef');
  });

  it.each([
    '/', '', '/p/', '/p/0123456789abcdef',
    '/p/0123456789abcdef0123456789abcde',
    '/p/0123456789abcdef0123456789abcdef0',
    '/p/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    '/p/0123456789abcdef0123456789abcdeg',
    '/p/0123456789abcdef0123456789abcdef/',
    '/p/0123456789abcdef0123456789abcdef/extra',
    '/other/0123456789abcdef0123456789abcdef',
    '/P/0123456789abcdef0123456789abcdef',
    '/p/%30123456789abcdef0123456789abcdef',
    '/p/0123456789abcdef0123456789abcdef\n',
  ])('rejects a path outside the exact public QR route: %j', path => {
    expect(parsePieceRoute(path)).toBeNull();
  });
});
