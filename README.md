# Nex Mob

Plugin paramétrico de marcenaria para SketchUp 2026 no Windows. Versão 0.5.0.

## Instalação

Instale `nex_mob-0.5.0.rbz` pelo Gerenciador de Extensões e reinicie o SketchUp. A barra **Nex Mob** contém seis comandos: **Inserir módulo**, **Editar módulo e vãos**, **Portas e frentes**, **Modo construtivo**, **Dados do projeto** e **Etiquetas e QR**. Ela também pode ser exibida por **Extensões > Nex Mob > Mostrar barra de ferramentas**.

O arquivo de entrada e a pasta internos continuam como `marcenaria_parametrica`, para atualizar a instalação anterior sem duplicar a extensão. Os dicionários antigos também são preservados para reconhecer os móveis já criados. O nome apresentado no SketchUp, nos diálogos e na barra é Nex Mob.

## Catálogo e edição

Escolha **Balcão inferior** e clique no modelo. A edição abre após a inserção e ativa a seleção de vãos. Para um móvel existente, selecione seu grupo principal e use **Editar módulo e vãos**.

Clique diretamente na abertura frontal do vão. O preenchimento e o contorno mostram o destaque; o vão selecionado fica em vermelho e os demais em azul esverdeado. A visualização apresenta o número e as medidas livres de cada abertura. **Enquadrar em vista frontal** facilita a seleção e retoma a ferramenta se ela tiver sido encerrada com Esc.

Adicione prateleiras ou divisórias pelo modal de edição ou pelos botões flutuantes do vão. Os botões no 3D inserem uma peça no centro. No painel, informe a **quantidade** e a medida livre do **primeiro vão**. Com várias peças, os demais vãos são distribuídos igualmente. A posição da peça inclui a espessura das chapas que limitam o vão: digitar 350 mm produz um espaço livre de 350 mm até a primeira peça. Cada vão resultante precisa respeitar a folga mínima configurada no modo construtivo (80 mm no modo inicial). Todo o lote é criado em uma operação e pode ser desfeito com um único Ctrl+Z. As divisões são gravadas como proporções e acompanham as alterações das dimensões do módulo.

## Editor 3D

O painel tem abas **Construir**, **Medidas** e **Visualização**. Modo construtivo continua em um diálogo separado; ambiente e materiais são informados no editor do módulo.

- Clique em uma face visível da prateleira ou divisória para selecioná-la. A borda fica vermelha e aparecem as ações **Mover**, **Duplicar** e **Excluir**, além das cotas livres dos dois lados.
- Arraste a alça quadrada no centro da peça, ou use **Mover**, mova o cursor e clique no destino. A prévia não modifica a geometria; soltar o arraste ou confirmar o destino aplica uma única operação.
- Os vãos mostram alças apenas nas bordas apoiadas em prateleiras ou divisórias móveis. Arrastar uma dessas alças move a peça correspondente.
- No painel, **Altura livre do vão inferior** ou **Largura livre do vão esquerdo** mede a distância interna até a primeira face da peça. A cota mostrada no 3D corresponde ao valor digitado. O arraste e a caixa Medidas do SketchUp continuam trabalhando com coordenadas locais do módulo em milímetros.
- O movimento pelo cursor depende da precisão da projeção na tela. Use a posição digitada para uma medida exata. As cotas e posições são locais ao módulo, antes de eventuais escalas externas do SketchUp.
- Esc durante o movimento cancela somente a prévia. Ctrl+Z desfaz a operação concluída. Após mover, duplicar ou inserir, a ferramenta continua disponível.
- **Duplicar** procura um vão adjacente com a mesma largura (prateleira) ou altura (divisória), preferindo acima/à direita e colocando a cópia no centro.
- Ao excluir uma divisão, o Nex Mob também remove as subdivisões criadas dentro dos vãos dela. Tudo acontece na mesma operação e pode ser desfeito com Ctrl+Z.
- Clique em qualquer peça de uma gaveta para selecionar a caixa completa. O painel permite editar sua posição vertical, altura e profundidade; **Mover** usa a alça central e a cota no 3D. **Duplicar** cria outra caixa no espaço disponível; ao duplicar uma gaveta única, o vão é dividido em duas caixas iguais. As folgas e as cinco peças da caixa continuam vinculadas ao modo construtivo.

Nesta versão, prateleiras são divisões estruturais horizontais. Gavetas são caixas internas: cada uma possui lateral esquerda, lateral direita, contra frente, posterior e fundo. Portas e frentes externas são definidas no modal próprio; ferragens e prateleiras independentes da divisão frontal ainda não fazem parte do editor.

## Portas e frentes

**Portas e frentes** é um modal separado do Modo construtivo. Abra-o pela barra do Nex Mob após selecionar o grupo principal do módulo, ou pelo botão disponível no Editor 3D. O modal detecta as caixas existentes no vão, indica seus nomes e sugere **Frentes de gaveta** quando houver gavetas. Sem gavetas, ele sugere automaticamente de 1 a 4 portas de acordo com a largura de referência configurada no modo construtivo; 764 mm sugerem duas portas no padrão inicial.

Espessura, folga e recuo partem das regras do Modo construtivo e podem receber ajuste pontual no modal. Aplicar substitui somente a composição do vão escolhido. Portas e frentes de gaveta são grupos independentes com metadados de fabricação e são reconstruídas quando as medidas do módulo, vãos ou gavetas mudam.

## Modos construtivos

O terceiro botão abre uma área de trabalho separada, com as categorias **Inferiores**, **Superiores** e **Armários** na lateral. Cada modo salvo tem um nome e reúne as configurações das três famílias; trocar a categoria apenas troca o perfil em edição dentro do mesmo modo. **Novo modo** copia todas as regras abertas; informe outro nome e ajuste-as. Selecionar um modo apenas o carrega para edição; **Ativar selecionado** define o padrão para os próximos móveis.

- **Salvar e ativar** grava as regras e define o modo para os próximos móveis.
- **Salvar e aplicar a todos os móveis** também recalcula os módulos Nex Mob compatíveis do projeto, inclusive os que estão dentro de grupos e componentes.
- Ao aplicar aos móveis existentes, as regras de espessura, folga e recuo de portas e frentes também são sincronizadas com o modo salvo.
- Móveis bloqueados, ou dentro de ancestrais bloqueados, são preservados. Cópias compartilhadas são isoladas quando necessário.
- A aplicação ao projeto ocupa um único passo de Desfazer. Se alguma medida ou divisão ficar inválida, a alteração de geometria inteira é cancelada; o modo permanece salvo.

As regras disponíveis nesta fase são organizadas nas abas **Estrutura**, **Fundo** e, nos Inferiores, **Sarrafos**, **Caixa da gaveta**, **Portas** e **Frentes de gaveta**. Elas incluem espessura das chapas da estrutura, espessura do fundo, folga mínima de cada vão livre (40 a 200 mm) e profundidade dos dois sarrafos superiores. A caixa da gaveta define espessuras, folgas laterais, frontal e traseira, além das distâncias independentes para a base, o sarrafo e entre gavetas. Portas e frentes definem espessura, folga, recuo e a largura que calcula a quantidade sugerida de portas. O padrão inicial de folga mínima do vão é 80 mm. A prévia técnica destaca a peça afetada e responde ao valor digitado, sem alterar o modelo até que o modo seja salvo. A escolha de materiais terá um modal próprio em uma etapa posterior.

A construção 3D disponível continua sendo o balcão inferior. Selecione um vão no editor e use **Gavetas** para adicionar de 1 a 10 caixas empilhadas. Cada caixa cria cinco grupos independentes: lateral esquerda, lateral direita, contra frente, posterior e fundo. O fundo fica entre as quatro paredes da caixa. A altura é distribuída igualmente dentro do vão e a caixa acompanha alterações de dimensão do módulo. Se a alteração de uma divisão eliminar o vão de origem, as gavetas desse vão são removidas na mesma reconstrução. Os padrões de Superiores e Armários já podem ser salvos, mas sua geração 3D ainda está em preparação.

## Geometria e compatibilidade

O balcão padrão possui seis chapas independentes: duas laterais, base inferior, dois sarrafos superiores de 80 mm e fundo sobreposto. Não há tampo fechado nem prateleira inicial. As faces são orientadas para Z positivo antes da extrusão. A edição mantém a transformação do módulo e suas divisões registradas, recriando as chapas a partir dos parâmetros.

Módulos da versão 0.1 preservam a prateleira original ao serem editados; seu tampo fechado é substituído pelos sarrafos. Para reparar um módulo criado com a extrusão invertida de versões anteriores, selecione seu grupo principal, abra a edição e clique em **Aplicar medidas**.

Os dados de fabricação das chapas ficam em `marcenaria_parametrica_peca`, com medidas em milímetros. Os parâmetros, a árvore de divisões, as caixas de gaveta e as composições de frentes ficam em `marcenaria_parametrica_modulo`. Furação, ferragens e exportação CNC ainda não foram implementadas.

## Contrato da API Cloudflare

A sincronização do visualizador usa o contrato versionado `RevisionV1`, descrito em [`docs/api/revision-v1.md`](docs/api/revision-v1.md) e validado por `contracts/revision-v1.schema.json`. O POST autenticado é `/v1/revisions`; cada QR abre `/p/{qr_token}` com token aleatório de **32 caracteres hexadecimais (16 bytes, 128 bits)** e consulta a revisão pública atual. Fixtures válidos e inválidos ficam em `contracts/fixtures/`.

## Projeto, ambientes e etiquetas

Em **Dados do projeto**, salve o nome do cliente e crie os ambientes, por exemplo Cozinha e Lavanderia. Os nomes de ambiente devem ser únicos; um ambiente associado a um móvel não pode ser excluído. Selecione cada módulo e abra **Editar módulo e vãos** para escolher seu ambiente e material padrão. Para uma chapa específica, escolha a peça, selecione **Substituir nesta peça**, informe o material e aplique. **Usar material padrão** remove a substituição. O material individual e o QR acompanham a mesma peça quando suas medidas são reconstruídas.

Abra **Etiquetas e QR**, informe a URL HTTPS completa de sincronização (`https://WORKER/v1/revisions`), a origem HTTPS do visualizador (`https://PAGES`, sem caminho) e a credencial privada fornecida pelo administrador. Esses endereços são exemplos; use os recursos publicados da sua instalação. A credencial fica somente na memória do diálogo e precisa ser informada novamente após fechá-lo. Apenas URLs e preferências de impressão são salvas no computador. Nunca coloque a credencial na URL pública, no modelo ou em capturas de tela.

Use **Atualizar contagem** para reler as peças e **Sincronizar projeto** para publicar a revisão. A listagem considera peças válidas de módulos visíveis e desbloqueados, inclusive aninhados; confira a contagem antes de imprimir. Falhas de rede permitem tentar novamente; credencial recusada exige informar uma válida. Prévia e impressão são liberadas após sincronização bem-sucedida. Alterar móveis, materiais, ambiente ou cliente exige nova sincronização; a conferência Ruby também rejeita uma saída baseada em dados antigos.

O QR público contém somente o token aleatório da peça e pode ser aberto por qualquer pessoa que possua o link. A API pública mostra móvel, ambiente, peças, materiais, dimensões e horário da última sincronização; o nome do cliente fica na etiqueta local e não é enviado no manifesto público. A mesma etiqueta consulta a última revisão publicada: alterações feitas apenas no SketchUp não aparecem no celular. Uma peça removida da última revisão passa a retornar não encontrada; seu token permanece reservado e não é reutilizado para outra identidade. Uma cópia de móvel com identidade duplicada bloqueia a publicação e precisa ser corrigida antes do envio.

### Térmica, PDF A4 e calibração

Para térmica, informe largura e altura reais da etiqueta e selecione a saída térmica; **Imprimir** usa uma etiqueta por página. No diálogo do sistema, selecione a impressora e o tamanho personalizado correspondente, escala **100% / tamanho real**, margens zero quando suportadas e desative cabeçalhos e rodapés. O QR deve ter pelo menos **20 mm** e o texto pelo menos **6 pt**; aumente a etiqueta quando o conteúdo não couber. O tamanho padrão é 99 × 55,8 mm; não há redução automática de texto ou QR para caber em uma etiqueta menor.

**Gerar PDF** sempre usa A4 e abre a impressão do sistema: escolha **Microsoft Print to PDF** (ou Salvar como PDF), papel **A4 retrato**, escala **100%**, sem ajustar à página, cabeçalhos ou rodapés. A folha A4350 contém **2 colunas × 5 linhas**, células fixas de **99 × 55,8 mm**, margens de 6 mm nas laterais e 9 mm no topo/rodapé. O tamanho configurado para a térmica não altera essa grade. O plugin não exporta um PDF silenciosamente; o arquivo e seu destino são escolhidos no diálogo de impressão.

Antes de usar adesivos, use **Imprimir folha de calibração** em papel comum a 100% e sobreponha à folha A4350 contra a luz. Meça as células, confira primeira e última linha e ajuste os deslocamentos X/Y em milímetros. Valores positivos movem a grade para direita/baixo; se a impressão ficou 1 mm à direita, corrija X em −1 mm. Os limites são X ±6 mm e Y ±9 mm. Deslocamentos corrigem posição; se as células estiverem menores ou o erro aumentar entre linhas, corrija a escala/configuração do driver. Repita até alinhar, salve as preferências e faça uma leitura real do QR antes do lote definitivo. A calibração pode ser impressa sem sincronizar.

## Preparação local do visualizador e da API

O código está preparado para Worker + D1 + R2 e Pages. A validação local não cria recursos nem comprova um serviço publicado. Os comandos de provisionamento e deploy abaixo são instruções para o administrador executar posteriormente, quando escolher publicar.

Use Node.js 24 compatível com `viewer/package.json` (validado com 24.14.1) e npm. Instale as dependências com `npm ci` em `viewer` e em `cloudflare/worker`. Na raiz, a documentação do contrato contém os comandos para validar as fixtures. Depois execute, em cada diretório:

```sh
# Em viewer/
npm test
npm run build
npm run preview -- --host 127.0.0.1

# Em cloudflare/worker/
npm run check:validator
npm test
npm run typecheck
npx wrangler deploy --dry-run --outdir .wrangler/build
npm run db:migrate:local
```

O último comando aplica migrations somente ao D1 local em `.wrangler/state`; os testes usam armazenamento isolado. O `--dry-run` apenas empacota o Worker, sem enviá-lo à Cloudflare. `npm run dev` inicia o Worker local, sem `--remote`. O preview Vite serve o build; sem API na mesma origem ou `VITE_API_ORIGIN` configurada antes do build, a consulta de uma peça não terá dados. Para QA totalmente local, use uma resposta pública derivada da fixture num servidor/proxy local de mesma origem. Um preview Vite não comprova o comportamento do CDN Pages.

O arquivo existente `viewer/public/_redirects` contém `/p/* /index.html 200` e é copiado pelo Vite para `dist/_redirects`. Ele faz a abertura direta do QR carregar a página. O parser compartilhado em `viewer/src/route.ts`, usado pelo `main.ts`, aceita somente `/p/` seguido de 32 hexadecimais; tokens de 64 caracteres, segmentos extras e barra final são inválidos. A página pode carregar com HTTP 200 pelo fallback e ainda mostrar “QR inválido” ou “QR não encontrado”; o endpoint público devolve HTTP 404 nesses casos.

### Configuração que cabe ao administrador

Escolha a conta Cloudflare e os nomes de recursos; autentique o Wrangler apenas no ambiente administrativo. Use o dashboard ou, **posteriormente**, execute em `cloudflare/worker`:

```sh
npx wrangler d1 create nexmob-qr
npx wrangler r2 bucket create nexmob-qr-revisions
```

O bucket R2 deve permanecer privado, sem acesso público `r2.dev` ou domínio público: o Worker lê os objetos pelo binding. Não é necessário distribuir chaves S3. Consulte a [criação de buckets R2](https://developers.cloudflare.com/r2/buckets/create-buckets/).

Copie `cloudflare/worker/wrangler.jsonc` para `cloudflare/worker/wrangler.local.jsonc` (ignorado pelo Git), no mesmo diretório para preservar os caminhos relativos. O arquivo versionado contém apenas placeholders. Edite a cópia administrativa e passe `--config wrangler.local.jsonc` em todos os comandos destinados à produção:

| Campo | Valor escolhido pelo administrador |
| --- | --- |
| `name` | Nome do Worker |
| `d1_databases[0].binding` | `DB`, conforme `env.DB` |
| `d1_databases[0].database_name` / `database_id` | Nome e ID retornados ao criar o D1; substituir o UUID de zeros |
| `d1_databases[0].migrations_dir` | `migrations` |
| `r2_buckets[0].binding` / `bucket_name` | `REVISIONS` e nome do bucket privado criado |
| `vars.PAGES_ORIGIN` | Origem HTTPS exata do Pages escolhido, sem barra final, caminho ou wildcard |

Não grave IDs reais de conta/banco, URLs privadas ou credenciais no Git. A origem de exemplo `https://pages.example.invalid` não é um serviço. O Worker só libera CORS para `PAGES_ORIGIN`; previews de branches com outro hostname precisarão de um Worker/recursos de teste separados e da origem exata correspondente. A configuração atual permite uma origem por Worker. O navegador local em HTTP não é uma origem Pages válida para esta configuração; use o proxy local para QA.

### Migrations D1 e banco já existente

Confira o banco e o arquivo de configuração antes de executar. Em `cloudflare/worker`, estes comandos são alternativas explícitas para banco local ou remoto:

```sh
# Local: não altera a Cloudflare
npx wrangler d1 migrations apply DB --local

# Produção: o administrador executará posteriormente, com a configuração real
npx wrangler d1 migrations list DB --remote --config wrangler.local.jsonc
npx wrangler d1 migrations apply DB --remote --config wrangler.local.jsonc
```

O D1 registra migrations aplicadas; `apply` executa apenas as pendentes ([migrations D1](https://developers.cloudflare.com/d1/reference/migrations/), [comandos Wrangler D1](https://developers.cloudflare.com/workers/wrangler/commands/d1/)). **Não altere `0001_initial.sql` depois que ela for aplicada remotamente**: editar esse arquivo não atualiza um banco já migrado. Mudanças posteriores exigem uma nova migration incremental, backup e plano de transformação dos dados.

A correção de identidade do QR incluiu `piece_tokens.module_id` na `0001_initial.sql` antes de qualquer deploy remoto desta implementação. Se um D1 local já aplicou a versão antiga, repetir `apply` não adiciona a coluna. Para um banco local descartável, pare o Wrangler, confira o caminho absoluto e mova somente `cloudflare/worker/.wrangler/state/v3/d1` para um backup fora de `state` (preserve R2 e os demais arquivos). Rode `npm run db:migrate:local` para reconstruir o D1 e recadastre instalações/reenvie as fixtures. Alternativamente, use um diretório de persistência novo com `--persist-to` tanto na migração local quanto no `wrangler dev`. Nenhum reset local é automático.

Se dados locais precisarem ser preservados, planeje um backfill confiável de `module_id` a partir das revisões antes de trocar o banco. Se a versão antiga tiver sido aplicada remotamente fora deste fluxo, não a reaplique nem invente um módulo padrão: será necessária uma nova migration e um backfill que preserve `(project_id, module_id, logical_key)` de cada reserva permanente de token.

### Credencial privada por instalação

O administrador gera um segredo aleatório de alta entropia por instalação (pelo menos 32 bytes, usando um gerador criptográfico ou gerenciador de segredos), codifica-o em hexadecimal ou base64url para ser aceito pelo Bearer, entrega-o de forma privada ao plugin e guarda apenas seu **SHA-256 em hexadecimal minúsculo** na tabela `installations`. Calcule o hash do texto codificado exato que será enviado, sem espaços ou quebra de linha. O segredo não vai no QR, no Pages, em `VITE_*`, no repositório ou em comandos/logs compartilhados. Este Worker não lê um `INSTALLATION_SECRET` global: `wrangler secret put` não cadastra instalações; a autenticação consulta D1.

Para calcular o digest no PowerShell 7, o administrador pode fornecer o segredo por prompt, sem colocá-lo no histórico (a variável fica temporariamente em memória):

```powershell
$installationSecret = Read-Host 'Segredo da instalação' -MaskInput
$installationHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($installationSecret))).ToLowerInvariant()
Remove-Variable installationSecret
$installationHash
```

Cadastre no D1 já migrado, via console administrativo ou arquivo SQL privado, substituindo os placeholders por ID único e digest de 64 hexadecimais:

```sql
INSERT INTO installations (id, token_hash, revoked_at)
VALUES ('INSTALLATION_ID', 'SHA256_HEX_64', NULL);
```

Para arquivo SQL, um nome como `.env.installation.sql` já é ignorado; mantenha somente ID/digest nele. O administrador escolhe **um** destino: `npx wrangler d1 execute DB --local --file .env.installation.sql` para desenvolvimento, ou `npx wrangler d1 execute DB --remote --config wrangler.local.jsonc --file .env.installation.sql` para produção. O digest de 64 caracteres não é o token público de 32. Cada POST envia o segredo original em `Authorization: Bearer …` por HTTPS. Revogue uma instalação preenchendo `revoked_at`; isso bloqueia novos envios, sem expirar os QRs existentes. O cadastro é administrativo; no plugin, o diálogo **Etiquetas e QR** recebe a credencial existente para a sessão.

### Publicação posterior de Worker e Pages

Após criar os recursos, aplicar a migration e configurar a instalação, o administrador poderá publicar o Worker em `cloudflare/worker`:

```sh
npx wrangler deploy --config wrangler.local.jsonc
```

Registre a origem pública HTTPS do Worker no ambiente administrativo. `GET /health` indica que o handler está ativo, mas não testa D1/R2. Para Pages, configure o projeto conectado ao repositório com **root directory `viewer`**, build command **`npm run build`** e output directory **`dist`**, relativo a esse root. Defina Node compatível via `NODE_VERSION` e configure **`VITE_API_ORIGIN` com a origem HTTPS do Worker**, sem caminho, credenciais ou barra final. Essa variável é pública e incorporada no build; alterar seu valor exige novo build. A configuração do Pages é descrita na [documentação oficial de build](https://developers.cloudflare.com/pages/configuration/build-configuration/).

No Worker, `PAGES_ORIGIN` aponta para Pages; em Pages, `VITE_API_ORIGIN` aponta para Worker. Deixar `VITE_API_ORIGIN` vazia usa a origem da página e só funciona com uma API/proxy nessa mesma origem; Pages estático sozinho não fornece `/v1/public/pieces/*`. `DB` e `REVISIONS` são bindings exclusivos do Worker; Pages não recebe banco, bucket ou segredo de instalação. Configurar Pages/branches de produção e disparar o build é uma ação posterior do administrador; nenhum push ou deploy faz parte da preparação local.

Depois de publicar, valide no ambiente escolhido: enviar uma revisão fixture por POST autenticado e obter `201`; abrir diretamente `<ORIGEM_PAGES>/p/0123456789abcdef0123456789abcdef`; confirmar móvel “Balcão inferior”, peça “Lateral esquerda” e destaque amarelo, material, dimensões e sincronização; verificar que a requisição pública ao Worker recebe o CORS da origem Pages. Teste também 404 para token desconhecido/removido, rejeição de token malformado e atualização da mesma etiqueta após publicar uma nova revisão. Use ambiente/instalação de teste para não misturar a fixture com dados reais. Esse aceite remoto continua pendente até o administrador efetuar a publicação.

## Organização do código

```text
marcenaria_parametrica.rb              Registro da extensão Nex Mob
marcenaria_parametrica/
  principal.rb                        Carregamento e inicialização
  configuracao/
    configuracao_construtiva.rb        Modos nomeados e persistência
  dominio/
    plano_balcao_inferior.rb           Cálculo de chapas e árvore de vãos
    plano_gavetas.rb                   Cálculo das caixas de gavetas
    plano_frentes.rb                   Cálculo de portas e frentes de gaveta
    modulo_parametrico.rb              Leitura de parâmetros dos móveis
    edicao_divisoes.rb                 Mover, duplicar, excluir e localizar bordas
  construtores/
    construtor_balcao_inferior.rb      Inserção, atualização e operações
    fabrica_chapas.rb                 Geometria e metadados das peças
  servicos/
    aplicador_modo_construtivo.rb      Aplicação ao projeto e proteção de cópias
  ferramentas/
    ferramenta_insercao.rb            Clique para inserir
    ferramenta_selecao_vao.rb          Seleção contínua básica
    ferramenta_edicao_3d.rb            Cliques, alças, arraste e medidas digitadas
  visualizacao/
    representacao_vaos.rb              Cores, contornos e legendas
    representacao_edicao.rb            Ações flutuantes, alças e cotas
    enquadramento_modulo.rb            Vista frontal
  interface/
    controlador_interface.rb          Coordenação dos quatro diálogos
    controlador_catalogo.rb           Catálogo e inserção
    controlador_edicao.rb             Edição de módulo e vãos
    controlador_frentes.rb            Portas e frentes por vão
    controlador_modo_construtivo.rb    Modos salvos e aplicação
    fabrica_dialogos.rb               Configuração comum dos diálogos
    observador_edicao.rb              Sincronização após Desfazer/Refazer
    comandos_plugin.rb                Menu, barra e comandos
    catalogo.html / catalogo.js
    edicao.html / edicao.js / edicao.css
    frentes.html / frentes.js / frentes.css
    abas_edicao.js / selecao_pecas.js   Navegação e propriedades da peça
    modo_construtivo.html / modo_construtivo.js / modo_construtivo.css
    campos_construtivos.js             Seções e descrições dos campos por família
    previa_construtiva.js              Desenho técnico reativo do modo construtivo
    estilos.css                       Aparência compartilhada
  icones/
    catalogo.svg / editar.svg / frentes.svg / construcao.svg
```

## Verificação

Os testes unitários Ruby usam Minitest e ficam em `testes/teste_*.rb`; execute cada arquivo separadamente. Os testes de JavaScript usam `node --test testes/*.js`.

No PowerShell, execute os testes Ruby separadamente, interrompendo no primeiro erro:

```powershell
Get-ChildItem testes/teste_*.rb | ForEach-Object { ruby $_.FullName; if ($LASTEXITCODE -ne 0) { throw "Falhou: $($_.Name)" } }
node --test testes/*.js
```

Os scripts `verificar_no_sketchup.rb`, `verificar_fluxos_sketchup.rb` e `verificar_interface_sketchup.rb` verificam a API real em um modelo descartável do SketchUp. Eles cobrem geometria sólida, seleção contínua, aplicação em lote, cópias bloqueadas, Desfazer, cancelamento em erro e a comunicação dos novos diálogos. Não carregue os testes unitários com simulações da API dentro do SketchUp.

O script `verificar_editor_3d_sketchup.rb` testa o editor em um móvel transladado, girado e escalado: seleção, barra flutuante, arraste sem mutação durante a prévia, cancelamento, Desfazer, posição numérica, duplicação/exclusão, alças dos vãos e comunicação real do HtmlDialog.

Para verificar etiquetas, abra um **modelo novo e vazio, sem salvar**, no SketchUp 2026. No Console Ruby, carregue o script do checkout (substitua o caminho):

```ruby
load 'C:/caminho/Plugin Skechupt/testes/verificar_etiquetas_sketchup.rb'
```

O script recusa modelos já preenchidos, cria dois móveis em ambientes distintos, substitui um material e reconstrói um módulo. Confere 12 tokens hexadecimais de 32 caracteres distintos, preservação das identidades e material, catálogo e manifesto público. Abre uma prévia local e aguarda até 30 segundos pela resposta do HtmlDialog: são verificadas dez células na primeira A4, duas na segunda, células de 99 × 55,8 mm, QR de pelo menos 20 mm e ausência de overflow. Aguarde **PASS QA etiquetas**; a mensagem inicial de espera não significa aprovação. **FAIL QA etiquetas** informa a etapa/erro no console; consulte também `MarcenariaParametrica::VerificacaoEtiquetas.resultado`. Descarte o modelo e abra outro novo antes de repetir. Não carregue Minitest/simulações junto desse teste.

A prévia do verificador usa domínio fictício `.invalid`, não envia dados, não imprime e não testa Pages. O aceite ainda exige, no equipamento de destino: rodar os testes Ruby e esse verificador, calibrar e imprimir uma folha A4350 a 100%, testar a térmica e escanear uma etiqueta sincronizada no Pages publicado. Confira o destaque da peça correta e a data de sincronização; altere o material, sincronize de novo e abra a mesma etiqueta para confirmar a atualização. Sem Ruby/SketchUp, impressora e implantação disponíveis, esses passos permanecem pendentes; passar nos testes Node não os substitui.

## Pacote local da extensão

O `.rbz` é um ZIP contendo somente `marcenaria_parametrica.rb` e a pasta `marcenaria_parametrica/` na raiz. Gere `nex_mob-0.5.0.rbz` localmente com um compactador ZIP, preservando esses caminhos e incluindo os arquivos JavaScript/vendor, HTML, CSS, ícones e licença do QR. Os arquivos `*.rbz` são ignorados pelo Git; distribua somente depois dos aceites acima. Não inclua README, testes, viewer, Worker, credenciais, `.env*`, `node_modules`, `.wrangler`, `.superpowers`, `.git` ou o worktree. Inspecione os nomes das entradas do ZIP antes de instalar.


