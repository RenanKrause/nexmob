/** Private synchronization contract; see contracts/revision-v1.schema.json. */
export interface RevisionV1 {
  schema_version: '1';
  project_id: string;
  revision_id: string;
  synced_at: string;
  modules: RevisionModule[];
}

export interface RevisionModule {
  module_id: string;
  name: string;
  environment: string;
  pieces: RevisionPiece[];
}

export interface RevisionPiece {
  logical_key: string;
  /** Public identifier: 32 hexadecimal characters (128 bits), never a credential. */
  qr_token: string;
  name: string;
  cut_mm: [number, number, number];
  transform_mm: [number, number, number, number];
  material: string;
  edge_banding: { top: boolean; right: boolean; bottom: boolean; left: boolean };
  visible: boolean;
}

export interface Installation {
  id: string;
  revoked_at: string | null;
}

export interface Env {
  DB: D1Database;
  REVISIONS: R2Bucket;
  PAGES_ORIGIN: string;
}
