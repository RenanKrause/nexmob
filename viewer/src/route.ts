/** Parse location.pathname only; public QR identifiers are 16 bytes (32 hex chars). */
export function parsePieceRoute(pathname: string): string | null {
  const match = /^\/p\/([a-fA-F0-9]{32})$/.exec(pathname);
  // JavaScript's $ can also match before a final newline: require the entire path.
  return match && match[0] === pathname ? match[1].toLowerCase() : null;
}
