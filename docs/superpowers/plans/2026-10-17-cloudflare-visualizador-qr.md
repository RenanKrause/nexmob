# Visualizador público com QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar uma API Cloudflare e um visualizador móvel que exibam a revisão atual de um móvel Nex Mob e destaquem a peça identificada pelo QR.

**Architecture:** Um Cloudflare Worker autentica a sincronização vinda do plugin, mantém os índices em D1 e guarda os manifestos de revisão no R2. Um aplicativo estático Vite/Three.js, publicado no Cloudflare Pages a partir de `viewer/`, recebe um token de QR na rota e consulta o endpoint público do Worker para montar as chapas paramétricas no navegador.

**Tech Stack:** TypeScript, Cloudflare Workers, D1, R2, Wrangler, Vite, Three.js, Vitest e Cloudflare Workers Vitest pool.

**Spec:** `docs/superpowers/specs/2026-10-17-etiquetas-qr-design.md`

## Global Constraints

- O repositório remoto é `https://github.com/RenanKrause/nexmob.git`; ele está vazio na data deste plano e será a origem do plugin e do aplicativo web.
- O Cloudflare Pages já está conectado ao repositório; configure o root directory como `viewer`, o build command como `npm run build` e o output como `dist`.
- O endereço público inicial usa `*.pages.dev`; não há login nem expiração/desativação de QR.
- Tokens de QR são aleatórios, têm 128 bits e nunca contêm dados de cliente, caminhos locais ou credenciais.
- A conta Cloudflare é administrada centralmente pelo proprietário do Nex Mob. Credenciais administrativas não entram no plugin nem no navegador.
- A cena da primeira versão é JSON de chapas retangulares; não introduzir exportação GLB, AR ou edição pelo celular.

## Review Focus

- Token inexistente, malformado ou removido retorna página/JSON 404 sem revelar dados de outros projetos — coberto na Task 3.
- Credencial ausente, inválida ou revogada nunca grava revisão nem altera o ponteiro público — coberto na Task 3.
- Uma revisão que falha antes do fim não substitui a revisão pública anterior — coberto na Task 3.
- Material, posição e orientação enviados no manifesto produzem no navegador uma chapa com dimensão e destaque corretos — coberto na Task 4.
- A rota profunda aberta diretamente em `/p/<token>` no Pages carrega o visualizador em vez de 404 — coberto na Task 5.

---

## Estrutura de arquivos

```text
contracts/
  revision-v1.schema.json             Contrato versionado para plugin, API e viewer
  fixtures/revision-v1.json           Cena mínima reproduzível para testes locais
  fixtures/revision-v1-invalid.json   Casos inválidos para validação do contrato
cloudflare/worker/
  package.json                        Scripts Wrangler/teste e dependências do serviço
  wrangler.jsonc                      Bindings D1/R2 e variáveis não secretas
  migrations/0001_initial.sql         Tabelas de instalações, projetos, revisões e tokens
  src/types.ts                        Tipos do contrato e bindings Worker
  src/auth.ts                         Hash e validação da credencial por instalação
  src/revisions.ts                    Validação, persistência atômica e leitura pública
  src/index.ts                        Rotas HTTP, CORS e respostas de erro
  test/worker.test.ts                 Testes de integração do Worker
viewer/
  package.json                        Vite, Three.js e scripts de teste/build
  vite.config.ts                      Base de deploy e configuração Vitest
  public/_redirects                   Fallback SPA para rotas `/p/*`
  src/api.ts                          Busca e validação da cena pública
  src/scene.ts                        Criação/seleção de meshes de chapa
  src/main.ts                         Estado da rota, câmera, carregamento e mensagens
  src/style.css                       Interface móvel e estados de erro/carregamento
  src/*.test.ts                       Testes unitários de API e geometria
README.md                             Instruções locais, deploy e configuração Pages
```

### Task 1: Importar a base no repositório e fixar o contrato de sincronização

**Files:**
- Create: `.gitignore`
- Create: `contracts/revision-v1.schema.json`
- Create: `contracts/fixtures/revision-v1.json`
- Create: `contracts/fixtures/revision-v1-invalid.json`
- Create: `docs/api/revision-v1.md`
- Modify: `README.md`

**Interfaces:**
- Produces: `RevisionV1` com `{ schema_version, project_id, revision_id, synced_at, modules[] }`; cada módulo tem `module_id`, `name`, `environment` e `pieces[]`; cada peça tem `logical_key`, `qr_token`, `name`, `cut_mm`, `transform_mm`, `material`, `edge_banding` e `visible`.
- Consumed by: Worker (Tasks 2–3), viewer (Task 4) e exportador Ruby no plano do plugin.

- [ ] **Step 1: Criar o teste/fixture inválido do contrato**

Adicionar ao fixture casos separados sem `schema_version`, com token fora do padrão de 32 caracteres hexadecimais (16 bytes, 128 bits) e com `cut_mm` de comprimento diferente de 3.

- [ ] **Step 2: Executar o validador de schema e confirmar falha**

Run: `npx --yes ajv-cli@5 validate -s contracts/revision-v1.schema.json -d contracts/fixtures/revision-v1-invalid.json`

Expected: FAIL apontando o primeiro campo inválido.

- [ ] **Step 3: Escrever `revision-v1.schema.json` e fixture válida**

Definir JSON Schema Draft 2020-12 com medidas em milímetros estritamente positivas, transformações `[x, y, z, rotation_z_deg]`, tokens de 32 caracteres hexadecimais (16 bytes, 128 bits) e os quatro lados `top`, `right`, `bottom`, `left` em `edge_banding`. Documentar a URL pública como `/p/{qr_token}` e o POST autenticado como `/v1/revisions`.

- [ ] **Step 4: Executar validação de fixture válida e inválida**

Run: `npx --yes ajv-cli@5 validate -s contracts/revision-v1.schema.json -d contracts/fixtures/revision-v1.json`

Expected: PASS; o fixture inválido continua falhando.

- [ ] **Step 5: Inicializar o Git e publicar a base no remoto vazio**

Ignorar `.superpowers/`, `.wrangler/`, `node_modules/`, arquivos de ambiente e pacotes `.rbz` gerados. Inicializar o repositório, associar o remoto informado, fazer o primeiro commit e confirmar que a origem contém a base atual do plugin e o contrato.

### Task 2: Estruturar Worker, D1 e R2 para dados privados de sincronização

**Files:**
- Create: `cloudflare/worker/package.json`
- Create: `cloudflare/worker/wrangler.jsonc`
- Create: `cloudflare/worker/migrations/0001_initial.sql`
- Create: `cloudflare/worker/src/types.ts`
- Create: `cloudflare/worker/src/auth.ts`
- Test: `cloudflare/worker/test/auth.test.ts`

**Interfaces:**
- Consumes: `RevisionV1` da Task 1.
- Produces: `Env` com bindings `DB: D1Database` e `REVISIONS: R2Bucket`; `authenticateInstallation(request, env): Promise<Installation | null>`.

- [ ] **Step 1: Escrever testes de autenticação**

Em `auth.test.ts`, registrar uma instalação com somente o hash SHA-256 do segredo e afirmar: token correto retorna a instalação; ausente, diferente e instalação revogada retornam `null`.

- [ ] **Step 2: Executar o teste para confirmar falha**

Run: `npm test -- --run test/auth.test.ts` em `cloudflare/worker`

Expected: FAIL porque `authenticateInstallation` ainda não existe.

- [ ] **Step 3: Criar schema e `authenticateInstallation(request, env)`**

Criar tabelas `installations(id, token_hash, revoked_at)`, `projects(id, installation_id, current_revision_id)`, `revisions(id, project_id, synced_at, r2_key)` e `piece_tokens(token, project_id, logical_key)`. Exigir `Authorization: Bearer <segredo>` no POST e comparar somente hashes; configurar D1 e R2 como bindings no `wrangler.jsonc`.

- [ ] **Step 4: Executar testes do Worker**

Run: `npm test -- --run test/auth.test.ts` em `cloudflare/worker`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add cloudflare/worker
git commit -m "feat: add Cloudflare storage bindings and installation auth"
```

### Task 3: Implementar sincronização atômica e leitura pública por QR

**Files:**
- Create: `cloudflare/worker/src/revisions.ts`
- Create: `cloudflare/worker/src/index.ts`
- Test: `cloudflare/worker/test/worker.test.ts`

**Interfaces:**
- Consumes: `authenticateInstallation`, `RevisionV1`, bindings D1/R2.
- Produces: `POST /v1/revisions`, `GET /v1/public/pieces/:qrToken` e `GET /health`.

- [ ] **Step 1: Escrever testes de integração do Worker**

Cobrir POST autenticado que cria uma revisão e seus tokens, GET público que devolve módulo+cena+`selected_piece_key`, 404 para token desconhecido, 401 para segredo errado e falha de R2 que preserva `current_revision_id` anterior.

- [ ] **Step 2: Executar os testes para confirmar falha**

Run: `npm test -- --run test/worker.test.ts` em `cloudflare/worker`

Expected: FAIL porque as rotas não existem.

- [ ] **Step 3: Implementar `publishRevision` e as rotas**

`publishRevision(env, installation, revision)` valida o contrato, grava `revisions/{projectId}/{revisionId}.json` no R2, cria/atualiza os tokens em D1 e somente então, em transação/batch D1, atualiza `projects.current_revision_id`. A leitura pública resolve o token no D1, busca a revisão indicada e devolve apenas a cena daquele módulo, a peça selecionada e `synced_at`. Enviar CORS somente para o domínio Pages configurado e `Cache-Control: no-store` na resolução pública, pois o QR deve refletir a revisão atual.

- [ ] **Step 4: Executar todos os testes do serviço**

Run: `npm test` em `cloudflare/worker`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add cloudflare/worker contracts docs/api
git commit -m "feat: publish current project revisions by QR token"
```

### Task 4: Criar visualizador móvel de chapas com Three.js

**Files:**
- Create: `viewer/package.json`
- Create: `viewer/vite.config.ts`
- Create: `viewer/index.html`
- Create: `viewer/src/api.ts`
- Create: `viewer/src/scene.ts`
- Create: `viewer/src/main.ts`
- Create: `viewer/src/style.css`
- Test: `viewer/src/api.test.ts`
- Test: `viewer/src/scene.test.ts`

**Interfaces:**
- Consumes: resposta de `GET /v1/public/pieces/:qrToken`.
- Produces: `fetchPublicPiece(token: string): Promise<PublicPieceResponse>` e `buildModuleScene(payload, scene): Map<string, THREE.Mesh>`.

- [ ] **Step 1: Escrever testes de cliente e geometria**

Testar que `fetchPublicPiece` converte 404 em erro “QR não encontrado”, que falha de rede tem mensagem recuperável e que `buildModuleScene` cria uma mesh por peça com dimensões em milímetros, aplica material e destaca somente `selected_piece_key`.

- [ ] **Step 2: Executar os testes para confirmar falha**

Run: `npm test -- --run` em `viewer`

Expected: FAIL porque os módulos ainda não existem.

- [ ] **Step 3: Implementar API, cena e tela responsiva**

Usar `BoxGeometry` para cada chapa JSON, OrbitControls para girar/zoom e um painel contendo móvel, ambiente, nome/dimensão/material da peça destacada e data/hora de sincronização. Ler o token de `/p/<token>`; apresentar estados distintos para carregando, QR inválido, offline e sucesso. A peça selecionada recebe cor de destaque e opacidade normal nas demais; não renderizar dados de cliente.

- [ ] **Step 4: Executar testes e build de produção**

Run: `npm test && npm run build` em `viewer`

Expected: PASS e `viewer/dist/` criado.

- [ ] **Step 5: Commit**

```bash
git add viewer
git commit -m "feat: add mobile QR furniture viewer"
```

### Task 5: Configurar deploy e verificar o fluxo público

Escopo desta execução: preparar e validar localmente. `_redirects` já foi adicionado na Task 4 e deve ser preservado e verificado. Recursos, migrations remotas, push e deploy serão executados posteriormente pelo administrador; nenhum URL de produção é criado nesta task.

**Files:**
- Create: `viewer/public/_redirects`
- Modify: `README.md`
- Modify: `cloudflare/worker/wrangler.jsonc`
- Test: `viewer/src/route.test.ts`

**Interfaces:**
- Consumes: build `viewer/dist` e Worker publicado.
- Produces: configuração documentada para Pages e um URL de produção testável.

- [ ] **Step 1: Escrever teste de rota profunda**

Testar que o parser de rota aceita apenas `/p/<token-hex-32>` (128 bits) e rejeita `/`, tokens curtos, tokens de 64 caracteres e segmentos adicionais. Extrair a regra para `viewer/src/route.ts`, consumida por `main.ts`.

- [ ] **Step 2: Executar teste para confirmar falha**

Run: `npm test -- --run src/route.test.ts` em `viewer`

Expected: FAIL porque o parser de rota não existe.

- [ ] **Step 3: Adicionar fallback e documentação de deploy**

Criar `_redirects` para servir `index.html` em `/p/*`; documentar os bindings `DB`/`REVISIONS`, a migração D1, os secrets, o root `viewer` no Pages e os comandos `wrangler deploy`/`npm run build`. Não salvar IDs de conta, tokens ou URLs privadas no Git.

- [ ] **Step 4: Executar verificação de release**

Run: `npm test && npm run build` em `viewer`; `npm test` em `cloudflare/worker`

Expected: PASS em ambos; abrir um QR fixture no ambiente de preview e confirmar que a peça correta fica destacada.

- [ ] **Step 5: Commit**

```bash
git add viewer README.md cloudflare/worker
git commit -m "docs: configure Pages deployment for QR viewer"
```

## Self-review

- Cobertura da especificação: esta parte entrega o serviço centralizado, URL pública permanente, token não identificável, revisão atual atômica, R2/D1 e a visualização móvel com destaque de peça.
- Limites intencionais: metadados e impressão dentro do SketchUp ficam no plano `2026-10-17-plugin-etiquetas-qr.md`; domínio próprio, AR, GLB e login não entram neste plano.
- Consistência: `RevisionV1` é o único payload compartilhado e todos os tokens públicos são `qr_token` de 32 caracteres hexadecimais (16 bytes, 128 bits). O hash SHA-256 de uma credencial privada tem 64 caracteres e não é um QR.
- Review Focus: os cinco cenários no cabeçalho estão cobertos respectivamente nas Tasks 3, 3, 3, 4 e 5.
