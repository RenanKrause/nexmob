export interface PublicPiece {
  logical_key: string;
  qr_token: string;
  name: string;
  cut_mm: [number, number, number];
  transform_mm: [number, number, number, number];
  material: string;
  edge_banding: { top: boolean; right: boolean; bottom: boolean; left: boolean };
  visible: boolean;
}

export interface PublicPieceResponse {
  module: { module_id: string; name: string; environment: string; pieces: PublicPiece[] };
  selected_piece_key: string;
  synced_at: string;
}

export type PublicPieceErrorKind = 'not-found' | 'offline' | 'unavailable' | 'invalid-response' | 'configuration';

export class PublicPieceError extends Error {
  constructor(public readonly kind: PublicPieceErrorKind, message: string) {
    super(message);
    this.name = 'PublicPieceError';
  }
}

const tokenPattern = /^[a-f0-9]{32}$/i;
const record = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);
const text = (value: unknown): value is string => typeof value === 'string' && value.length > 0;
const tuple = (value: unknown, size: number, positive = false): value is number[] => Array.isArray(value) && value.length === size && value.every(n => typeof n === 'number' && Number.isFinite(n) && (!positive || n > 0));

function isPiece(value: unknown): value is PublicPiece {
  return record(value) && text(value.logical_key) && text(value.name) && text(value.material)
    && typeof value.qr_token === 'string' && tokenPattern.test(value.qr_token)
    && tuple(value.cut_mm, 3, true) && tuple(value.transform_mm, 4)
    && typeof value.visible === 'boolean' && record(value.edge_banding)
    && ['top', 'right', 'bottom', 'left'].every(side => typeof (value.edge_banding as Record<string, unknown>)[side] === 'boolean');
}

function parseResponse(value: unknown): PublicPieceResponse {
  const invalid = () => new PublicPieceError('invalid-response', 'Os dados do móvel estão incompletos. Tente novamente.');
  if (!record(value) || !record(value.module) || !text(value.selected_piece_key)
    || typeof value.synced_at !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/.test(value.synced_at)
    || !Number.isFinite(Date.parse(value.synced_at))) throw invalid();
  const module = value.module;
  if (!text(module.module_id) || !text(module.name) || typeof module.environment !== 'string'
    || !Array.isArray(module.pieces) || !module.pieces.every(isPiece)) throw invalid();
  const keys = module.pieces.map(piece => piece.logical_key);
  if (new Set(keys).size !== keys.length || !keys.includes(value.selected_piece_key)) throw invalid();
  return {
    module: { module_id: module.module_id, name: module.name, environment: module.environment, pieces: module.pieces },
    selected_piece_key: value.selected_piece_key,
    synced_at: value.synced_at,
  };
}

function apiOrigin(): string {
  const configured = (import.meta.env.VITE_API_ORIGIN ?? '').trim();
  if (!configured) return '';
  try {
    const origin = new URL(configured);
    if ((origin.protocol !== 'https:' && !(origin.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(origin.hostname)))
      || origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash) throw new Error();
    return origin.origin;
  } catch {
    throw new PublicPieceError('configuration', 'O endereço do serviço precisa ser configurado pelo responsável.');
  }
}

export async function fetchPublicPiece(token: string): Promise<PublicPieceResponse> {
  if (!tokenPattern.test(token)) throw new PublicPieceError('not-found', 'QR não encontrado');
  const url = `${apiOrigin()}/v1/public/pieces/${token.toLowerCase()}`;
  let response: Response;
  try {
    response = await fetch(url, { credentials: 'omit', cache: 'no-store', signal: AbortSignal.timeout(15000) });
  } catch {
    throw new PublicPieceError('offline', 'Não foi possível conectar. Verifique sua conexão e tente novamente.');
  }
  if (response.status === 404) throw new PublicPieceError('not-found', 'QR não encontrado');
  if (!response.ok) throw new PublicPieceError('unavailable', 'O serviço está indisponível. Tente novamente em instantes.');
  try {
    return parseResponse(await response.json());
  } catch (error) {
    if (error instanceof PublicPieceError) throw error;
    throw new PublicPieceError('invalid-response', 'Não foi possível ler os dados do móvel. Tente novamente.');
  }
}
