-- Pre-deploy initial schema: no remote database has applied this migration.
-- Already-migrated local databases need a deliberate rebuild or data migration;
-- reapplying 0001 does not upgrade an older schema.
-- Installation credentials are high-entropy secrets provisioned out of band.
-- Store only their lowercase SHA-256 digest; public QRs live in piece_tokens.
CREATE TABLE installations (
  id TEXT PRIMARY KEY NOT NULL,
  token_hash TEXT NOT NULL UNIQUE
    CHECK (length(token_hash) = 64 AND token_hash NOT GLOB '*[^0-9a-f]*'),
  revoked_at TEXT
);

CREATE TABLE projects (
  id TEXT PRIMARY KEY NOT NULL,
  installation_id TEXT NOT NULL REFERENCES installations(id),
  current_revision_id TEXT,
  FOREIGN KEY (id, current_revision_id) REFERENCES revisions(project_id, id)
);
CREATE INDEX projects_installation_id ON projects(installation_id);

-- Scope revision identifiers to their project. Insert a project with a NULL
-- pointer, insert its revision, then advance the pointer in the same D1 batch.
CREATE TABLE revisions (
  id TEXT NOT NULL,
  project_id TEXT NOT NULL REFERENCES projects(id),
  synced_at TEXT NOT NULL,
  r2_key TEXT NOT NULL UNIQUE,
  PRIMARY KEY (project_id, id)
);

CREATE TABLE piece_tokens (
  token TEXT PRIMARY KEY COLLATE NOCASE NOT NULL
    CHECK (length(token) = 32 AND token NOT GLOB '*[^0-9a-fA-F]*'),
  project_id TEXT NOT NULL REFERENCES projects(id),
  -- Permanent QR identity includes the furniture module, not only the key.
  module_id TEXT NOT NULL CHECK (length(module_id) > 0),
  logical_key TEXT NOT NULL,
  -- Each stable piece keeps exactly one issued token across all revisions.
  UNIQUE (project_id, module_id, logical_key)
);
CREATE INDEX piece_tokens_project_id ON piece_tokens(project_id);
