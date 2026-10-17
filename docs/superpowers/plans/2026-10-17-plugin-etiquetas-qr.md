# Plugin de etiquetas inteligentes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estender o plugin Nex Mob para armazenar dados de projeto/ambientes/materiais, sincronizar todas as peças com o serviço QR e gerar etiquetas do projeto inteiro para impressora térmica ou folha A4 A4350.

**Architecture:** Serviços Ruby isolam persistência de atributos, identidade estável de peças, montagem do manifesto e composição HTML de etiquetas. Controladores HtmlDialog expõem diálogos pequenos para projeto, material e lote de etiquetas; o HTML de impressão reutiliza o layout A aprovado e chama a impressão nativa para térmica ou PDF/A4.

**Tech Stack:** Ruby da API SketchUp 2026, `UI::HtmlDialog`, JavaScript/CSS nativo, Minitest, `node --test` e HTTP padrão Ruby (`Net::HTTP`).

**Spec:** `docs/superpowers/specs/2026-10-17-etiquetas-qr-design.md`

## Global Constraints

- Preservar os dicionários atuais `marcenaria_parametrica_modulo` e `marcenaria_parametrica_peca`; os novos atributos complementam, não substituem, `codigo`, corte, espessura e `fita_borda`.
- Gerar etiquetas para todos os grupos que satisfaçam `ModuloParametrico.reconhecido?`, uma vez por peça visível.
- Cliente é do projeto; ambiente é criado/renomeado pelo usuário e associado a cada módulo; a peça herda ambos.
- Material padrão pode ser substituído por peça e precisa sobreviver à reconstrução do módulo.
- Fita é somente leitura nesta entrega e vem do modo construtivo; a etiqueta mostra lados e desenho destacados.
- QR tem 20 mm ou mais; texto principal tem 6 pt ou mais; impedir lote ilegível.
- O tamanho padrão é 99 × 55,8 mm. A4 usa papel adesivo A4350: 2 colunas × 5 linhas, 10 etiquetas, escala 100%, com calibração X/Y persistida.
- O QR mostra sempre a última revisão sincronizada; não expor segredos Cloudflare, dados do cliente na URL ou credenciais no HTML de impressão.

## Review Focus

- Reconstruir um módulo após trocar material mantém a substituição somente na peça lógica correspondente — coberto na Task 2.
- Renomear ambiente não perde módulos associados; remover ambiente em uso é recusado — coberto na Task 1.
- Projeto com módulo bloqueado, grupo não Nex Mob ou peça sem medidas não produz etiqueta inválida nem interrompe o lote inteiro — coberto na Task 3.
- Dimensão/tamanho de papel que não comporta QR de 20 mm e texto de 6 pt é bloqueado antes de impressão — coberto na Task 4.
- O lote A4 troca corretamente de página depois da décima etiqueta e aplica deslocamento de calibração sem deformar as células — coberto na Task 4.

---

## Estrutura de arquivos

```text
marcenaria_parametrica/
  dominio/dados_projeto.rb             Cliente, ambientes e associação a módulos
  dominio/identidade_peca.rb           Chave lógica, token QR e material efetivo
  servicos/catalogo_pecas.rb           Varredura de módulos/peças reconhecidas
  servicos/manifesto_qr.rb             Serialização RevisionV1 para a API
  servicos/cliente_sincronizacao.rb    POST autenticado, estado e erros de rede
  servicos/compositor_etiquetas.rb     Dados e HTML/CSS de etiqueta, térmica e A4
  configuracao/configuracao_etiquetas.rb Tamanho ativo e calibração A4
  interface/controlador_projeto.rb     Diálogo cliente/ambientes
  interface/controlador_etiquetas.rb   Prévia, sync, impressão e PDF
  interface/projeto.html/.js/.css      Tela de dados do projeto
  interface/etiquetas.html/.js/.css    Tela de lote e documento de impressão
  interface/vendor/qrcode.min.js       Gerador QR local, com licença incluída
  interface/comandos_plugin.rb         Novos comandos Nex Mob
  interface/controlador_interface.rb   Criação e roteamento dos controladores
  principal.rb                          Requires dos novos componentes
testes/
  teste_dados_projeto.rb
  teste_identidade_peca.rb
  teste_catalogo_pecas.rb
  teste_manifesto_qr.rb
  teste_configuracao_etiquetas.rb
  teste_compositor_etiquetas.rb
  teste_projeto.js
  teste_etiquetas.js
  verificar_etiquetas_sketchup.rb
```

### Task 1: Persistir dados do projeto e ambientes nomeados

**Files:**
- Create: `marcenaria_parametrica/dominio/dados_projeto.rb`
- Create: `testes/teste_dados_projeto.rb`
- Modify: `marcenaria_parametrica/construtores/construtor_balcao_inferior.rb`
- Modify: `marcenaria_parametrica/dominio/modulo_parametrico.rb`

**Interfaces:**
- Produces: `DadosProjeto.ler(modelo) -> Hash`, `DadosProjeto.salvar_cliente(modelo, nome)`, `DadosProjeto.criar_ambiente(modelo, nome) -> Hash`, `DadosProjeto.renomear_ambiente(modelo, id, nome)`, `DadosProjeto.atribuir_ambiente(grupo, ambiente_id)`.
- Consumed by: controlador de projeto, catálogo de peças e manifesto.

- [ ] **Step 1: Escrever testes Minitest de projeto/ambiente**

Cobrir criação de ambiente com UUID e nome, renomeação mantendo o mesmo ID, associação de dois módulos ao ambiente, recusa de nome vazio/duplicado e recusa de exclusão enquanto algum módulo reconhecido o usa.

- [ ] **Step 2: Executar teste para confirmar falha**

Run: `ruby testes/teste_dados_projeto.rb`

Expected: FAIL porque `DadosProjeto` não existe.

- [ ] **Step 3: Implementar `DadosProjeto` e inicialização do módulo**

Usar `model.attribute_dictionary('nex_mob_projeto', true)` para cliente/JSON de ambientes e `marcenaria_parametrica_modulo` para `modulo_uuid`/`ambiente_id`. Criar UUID aleatório uma única vez ao inserir módulo e expor `ModuloParametrico.nome_exibicao(grupo)` que usa o nome personalizado do grupo ou o nome amigável do tipo.

- [ ] **Step 4: Executar testes de domínio**

Run: `ruby testes/teste_dados_projeto.rb && ruby testes/teste_plano_balcao_inferior.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add marcenaria_parametrica/dominio marcenaria_parametrica/construtores testes
git commit -m "feat: store project client and named environments"
```

### Task 2: Preservar identidade, QR e material de cada peça em reconstruções

**Files:**
- Create: `marcenaria_parametrica/dominio/identidade_peca.rb`
- Create: `testes/teste_identidade_peca.rb`
- Modify: `marcenaria_parametrica/construtores/fabrica_chapas.rb`
- Modify: `marcenaria_parametrica/construtores/construtor_balcao_inferior.rb`

**Interfaces:**
- Produces: `IdentidadePeca.chave_logica(peca) -> String`, `IdentidadePeca.atributos_para(peca, anteriores) -> Hash`, `IdentidadePeca.material_efetivo(grupo) -> String`.
- Consumed by: catálogo, etiquetas e manifesto.

- [ ] **Step 1: Escrever testes de chaves e preservação**

Testar que a chave usa código e origem de vão/gaveta/frente quando disponíveis; que `qr_token` hexadecimal de 64 caracteres é criado somente na primeira geração; que uma substituição “MDF Freijó Puro” na lateral não passa para outra lateral e sobrevive a `atualizar`.

- [ ] **Step 2: Executar testes para confirmar falha**

Run: `ruby testes/teste_identidade_peca.rb`

Expected: FAIL porque `IdentidadePeca` não existe.

- [ ] **Step 3: Implementar captura e reaplicação de atributos**

Antes de `grupo.entities.clear!`, indexar os atributos das peças antigas por `chave_logica`; passar esse índice a `FabricaChapas.criar`. Gravar `chave_logica`, `qr_token`, `material_padrao` e `material_sobrescrito`; a fábrica deve escolher a substituição se houver e cair no material padrão atual em caso contrário.

- [ ] **Step 4: Executar testes de identidade e regressão de reconstrução**

Run: `ruby testes/teste_identidade_peca.rb && ruby testes/teste_construtor_balcao_inferior.rb`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add marcenaria_parametrica/construtores marcenaria_parametrica/dominio testes
git commit -m "feat: preserve piece material overrides and QR identities"
```

### Task 3: Catalogar peças e sincronizar a revisão atual

**Files:**
- Create: `marcenaria_parametrica/servicos/catalogo_pecas.rb`
- Create: `marcenaria_parametrica/servicos/manifesto_qr.rb`
- Create: `marcenaria_parametrica/servicos/cliente_sincronizacao.rb`
- Create: `testes/teste_catalogo_pecas.rb`
- Create: `testes/teste_manifesto_qr.rb`
- Modify: `marcenaria_parametrica/principal.rb`

**Interfaces:**
- Consumes: `DadosProjeto`, `IdentidadePeca`, `ModuloParametrico.reconhecido?` e contrato `contracts/revision-v1.schema.json`.
- Produces: `CatalogoPecas.listar(modelo) -> Array<Hash>`, `ManifestoQr.gerar(modelo, catalogo, revision_id:) -> Hash`, `ClienteSincronizacao.publicar(url:, token:, manifesto:) -> Resultado`.

- [ ] **Step 1: Escrever testes de varredura e manifesto**

Cobrir projeto com múltiplos ambientes/módulos, exclusão de grupo não Nex Mob e módulo bloqueado, uma ocorrência por peça visível, dimensões/código/fita/material corretos, cena de caixa com transformação em milímetros e ausência de cliente no payload público.

- [ ] **Step 2: Executar testes para confirmar falha**

Run: `ruby testes/teste_catalogo_pecas.rb && ruby testes/teste_manifesto_qr.rb`

Expected: FAIL porque os serviços não existem.

- [ ] **Step 3: Implementar catálogo, manifesto e cliente HTTP**

Percorrer recursivamente entidades do modelo e considerar somente módulos reconhecidos e editáveis. `ManifestoQr` cria o `RevisionV1` definido no contrato e usa a identidade persistida. `ClienteSincronizacao` faz `POST` JSON com `Authorization: Bearer`, timeouts explícitos e retorna objetos de resultado para sucesso, credencial recusada, erro de validação e falha de rede; nunca registra o token em mensagens, arquivo ou HTML.

- [ ] **Step 4: Executar testes e verificar contrato**

Run: `ruby testes/teste_catalogo_pecas.rb && ruby testes/teste_manifesto_qr.rb`

Expected: PASS; serializar o fixture gerado e validá-lo contra `contracts/revision-v1.schema.json` pelo validador da API.

- [ ] **Step 5: Commit**

```bash
git add marcenaria_parametrica/servicos marcenaria_parametrica/principal.rb testes
git commit -m "feat: serialize and sync project QR revisions"
```

### Task 4: Compor etiqueta A, prévia térmica e folha A4 A4350

**Files:**
- Create: `marcenaria_parametrica/configuracao/configuracao_etiquetas.rb`
- Create: `marcenaria_parametrica/servicos/compositor_etiquetas.rb`
- Create: `testes/teste_configuracao_etiquetas.rb`
- Create: `testes/teste_compositor_etiquetas.rb`
- Create: `marcenaria_parametrica/interface/etiquetas.html`
- Create: `marcenaria_parametrica/interface/etiquetas.js`
- Create: `marcenaria_parametrica/interface/etiquetas.css`
- Create: `testes/teste_etiquetas.js`

**Interfaces:**
- Consumes: itens de `CatalogoPecas`, URL pública formada por `viewer_base_url + '/p/' + qr_token` e `ConfiguracaoEtiquetas`.
- Produces: `CompositorEtiquetas.gerar(item, configuracao) -> String`, `CompositorEtiquetas.lote_a4(itens, configuracao) -> String`, `ConfiguracaoEtiquetas.ler/salvar`.

- [ ] **Step 1: Escrever testes Ruby e JS de composição**

Testar etiqueta de 99 × 55,8 mm contendo cliente, ambiente, móvel, peça, dimensão, material, quatro lados de fita, QR e desenho; bordas `frente`, `todos` e `nenhuma`; bloqueio abaixo de QR 20 mm/texto 6 pt; A4 com 10 células 2×5, quebra após a décima primeira e offsets X/Y; e callbacks JS de prévia/impressão.

- [ ] **Step 2: Executar testes para confirmar falha**

Run: `ruby testes/teste_configuracao_etiquetas.rb && ruby testes/teste_compositor_etiquetas.rb && node --test testes/teste_etiquetas.js`

Expected: FAIL porque configurador, compositor e interface não existem.

- [ ] **Step 3: Implementar configuração e HTML de impressão**

Persistir uma largura/altura ativa e offsets A4 em `Sketchup.read_default/write_default`. Gerar QR como SVG em memória por biblioteca JavaScript local/vendida com o plugin, sem serviço externo; gerar CSS `@page` separado para térmica e A4. O layout A usa QR no canto superior direito, dados no centro e desenho de chapa/fitas no canto inferior. A ação de impressão chama `window.print()` no documento preparado; a ação “Gerar PDF” abre o mesmo documento em modo A4 para o usuário salvar como PDF no diálogo do sistema.

- [ ] **Step 4: Executar testes de composição e preview**

Run: `ruby testes/teste_configuracao_etiquetas.rb && ruby testes/teste_compositor_etiquetas.rb && node --test testes/teste_etiquetas.js`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add marcenaria_parametrica/configuracao marcenaria_parametrica/servicos marcenaria_parametrica/interface testes
git commit -m "feat: generate thermal and A4 QR label layouts"
```

### Task 5: Expor diálogos e comandos do Nex Mob

**Files:**
- Create: `marcenaria_parametrica/interface/controlador_projeto.rb`
- Create: `marcenaria_parametrica/interface/controlador_etiquetas.rb`
- Create: `marcenaria_parametrica/interface/projeto.html`
- Create: `marcenaria_parametrica/interface/projeto.js`
- Create: `marcenaria_parametrica/interface/projeto.css`
- Create: `testes/teste_projeto.js`
- Modify: `marcenaria_parametrica/interface/edicao.html`
- Modify: `marcenaria_parametrica/interface/edicao.js`
- Modify: `marcenaria_parametrica/interface/controlador_interface.rb`
- Modify: `marcenaria_parametrica/interface/comandos_plugin.rb`
- Modify: `marcenaria_parametrica/interface/fabrica_dialogos.rb`
- Modify: `marcenaria_parametrica/principal.rb`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: comandos “Dados do projeto” e “Etiquetas e QR” e seus fluxos HtmlDialog.

- [ ] **Step 1: Escrever testes JS de formulários e mensagens**

Cobrir criação/renomeação de ambiente, associação de ambiente a módulo, seleção de material padrão/sobrescrito, bloqueio de prévia inválida, exibição de contagem total de peças e mensagens distintas de sincronização, falha de rede e credencial recusada.

- [ ] **Step 2: Executar testes para confirmar falha**

Run: `node --test testes/teste_projeto.js testes/teste_etiquetas.js`

Expected: FAIL porque os controladores e callbacks não existem.

- [ ] **Step 3: Implementar controladores e registrar os comandos**

Seguir o padrão `FabricaDialogos`/`add_action_callback` existente. “Dados do projeto” gerencia cliente e ambientes; o editor do módulo recebe seletor de ambiente e material da peça. “Etiquetas e QR” lista a quantidade encontrada no projeto, exige URL/credencial configuradas, sincroniza antes de liberar a prévia e abre o documento correto para térmica ou A4. Adicionar os dois comandos à barra/menu com ícones novos.

- [ ] **Step 4: Executar testes de interface e regressão existente**

Run: `node --test testes/*.js`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add marcenaria_parametrica/interface marcenaria_parametrica/principal.rb testes
git commit -m "feat: add project data and QR labels dialogs"
```

### Task 6: Verificar o fluxo no SketchUp e empacotar a extensão

**Files:**
- Create: `testes/verificar_etiquetas_sketchup.rb`
- Modify: `README.md`
- Modify: `marcenaria_parametrica.rb`

**Interfaces:**
- Consumes: todo o fluxo das Tasks 1–5 e a API do plano Cloudflare.
- Produces: verificação manual/automatizada documentada e `.rbz` atualizado.

- [ ] **Step 1: Escrever verificador da API real do SketchUp**

Criar projeto descartável com dois móveis em ambientes distintos, substituir o material de uma peça, reconstruir o módulo, coletar o lote e afirmar tokens distintos, preservação de material, 10 células no primeiro A4 e QR mínimo de 20 mm.

- [ ] **Step 2: Executar dentro do SketchUp para confirmar falha inicial**

Run: carregar `testes/verificar_etiquetas_sketchup.rb` no console Ruby do SketchUp 2026.

Expected: FAIL antes dos diálogos/serviços finais estarem disponíveis.

- [ ] **Step 3: Corrigir integração e documentar operação**

Atualizar README com: cadastrar cliente/ambientes, associar móveis, configurar credencial e URL, sincronizar, imprimir térmica, gerar PDF A4 A4350 a 100% e executar a página de calibração. Incrementar versão exibida em `marcenaria_parametrica.rb` e gerar o `.rbz` sem incluir segredos, `node_modules`, `.wrangler` ou `.superpowers`.

- [ ] **Step 4: Executar a matriz final de verificação**

Run: `ruby testes/teste_*.rb` individualmente; `node --test testes/*.js`; carregar `testes/verificar_etiquetas_sketchup.rb` no SketchUp; imprimir uma folha de teste A4350 em escala 100%; abrir um QR no Pages.

Expected: todos os testes PASS, a grade física alinhada após calibração e o QR destacando a peça correta na última revisão.

- [ ] **Step 5: Commit**

```bash
git add README.md marcenaria_parametrica.rb testes
git commit -m "release: verify QR labels workflow"
```

## Self-review

- Cobertura da especificação: o plano implementa os metadados do projeto, ambientes, material individual, fita vinda do modo construtivo, layout A, QR permanente por peça, sincronização, impressão térmica, PDF A4 A4350 e calibração.
- Limites intencionais: a infraestrutura e o visualizador são entregues pelo plano `2026-10-17-cloudflare-visualizador-qr.md`; AR, CNC, catálogo avançado de fitas e domínio próprio permanecem fora do primeiro lançamento.
- Consistência: `DadosProjeto`, `IdentidadePeca`, `CatalogoPecas`, `ManifestoQr`, `ClienteSincronizacao` e `CompositorEtiquetas` têm responsáveis e assinaturas explicitadas antes de serem consumidos.
- Review Focus: cada um dos cinco riscos do cabeçalho é coberto pelas Tasks 2, 1, 3, 4 e 4, respectivamente.
