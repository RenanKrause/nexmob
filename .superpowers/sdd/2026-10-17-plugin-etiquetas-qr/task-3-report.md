# Task 3 — catálogo, manifesto RevisionV1 e sincronização

Base da tarefa: `61f8f58465bac985daf2f8b45be5c0c73e03f2c0`.
Commit: `feat: serialize and sync project QR revisions` (SHA informado no handoff).
Escopo exclusivo Task 3; sem subagentes, push, deploy, alterações de credenciais ou configuração remota.

## Entrega

- `CatalogoPecas.listar(modelo)` percorre grupos e instâncias de componentes recursivamente. Só inclui peças de módulos que satisfazem `reconhecido?` e `editavel?`. Descarta ancestrais bloqueados/ocultos, tags invisíveis, entidades inválidas, peças sem medidas positivas e transformações incompatíveis com a cena. A varredura de peças para quando encontra outro módulo; a varredura de módulos o processa separadamente, sem duplicá-lo. Caminho de definições evita ciclos sem deduplicar ocorrências legítimas de componentes.
- `DadosProjeto.ler` fornece UUID do projeto e nomes atuais dos ambientes; `modulo_uuid` existente é preservado. O catálogo migra somente chave lógica/token ausentes ou inválidos, persistindo a nova identidade. Um token válido com 32 dígitos hexadecimais, inclusive maiúsculos, é mantido literalmente. Material vem de `IdentidadePeca.material_efetivo` e não é sobrescrito durante a migração.
- `ManifestoQr.gerar(modelo, catalogo, revision_id:)` monta exclusivamente os campos RevisionV1, valida strings, dimensões, números finitos, booleanos, chaves e tokens duplicados. Cliente e referências do SketchUp nunca entram na lista explícita de campos públicos. UUID do projeto vem de `projeto_uuid`; ambiente é novamente resolvido pelo ID no momento da geração.
- `ClienteSincronizacao.publicar(url:, token:, manifesto:)` usa POST JSON, TLS e `Authorization: Bearer` somente no header, sem redirecionamentos ou repetição automática. Timeouts: conexão 10s, leitura 30s e escrita 30s. URL com HTTP, usuário/senha, query ou fragmento é recusada. Token não pode conter espaços, controles ou quebras de linha. Corpo de resposta e detalhes de exceções nunca entram no resultado, console, arquivo ou HTML.
- `principal.rb` carrega os domínios das Tasks 1/2 e os três serviços.

## Interface do catálogo para Tasks 4/5

Cada item é um Hash com chaves símbolo:

- `:modulo` e `:peca`: referências locais SketchUp, nunca serializadas;
- `:modulo_id`, `:modulo_nome`, `:ambiente_id`, `:ambiente`, `:cliente`;
- `:codigo`, `:nome`, `:chave_logica`, `:qr_token`, `:material`, `:visible`;
- `:corte_mm`: `[comprimento, largura, espessura]` persistidos para fabricação/etiqueta;
- `:dimensoes_mm`: caixa local `[X, Y, Z]`, com escala mundial aplicada; vira `cut_mm` no contrato;
- `:transform_mm`: centro geométrico mundial XYZ em mm, seguido da rotação Z em graus;
- `:fita_borda`: valor legado; `:edge_banding`: Hash com chaves string `top/right/bottom/left`, todos booleanos.

`ClienteSincronizacao::Resultado` expõe `status`, `http_status`, `mensagem` e `sucesso?`.
Status: `:sucesso` para qualquer 2xx; `:credencial_recusada` para 401; `:validacao` para demais 4xx e JSON não serializável; `:servidor` para outras respostas; `:rede` para timeout/conexão/TLS/protocolo; `:configuracao` para URL/credencial inválidas. O chamador fornece a URL completa do endpoint `/v1/revisions` e um novo revision_id por sincronização.

## Decisões e limites

- Ruling: `cut_mm` do contrato usa XYZ da caixa geométrica, não a ordem do corte de fabricação — exigência explícita de `docs/api/revision-v1.md`; custo se o consumidor esperar corte tradicional: deve usar `:corte_mm` do catálogo para etiqueta.
- Ruling: borda legada `frente` corresponde a `top` no desenho de fabricação; `todos` ativa as quatro e `nenhuma` desativa as quatro — o projeto não tinha orientação top/right/bottom/left anterior. Esta convenção é pública para o compositor; custo se a referência de desenho exigir outra orientação: ajustar esse mapeamento e testes antes de imprimir.
- Ruling: inclinação fora de Z e cisalhamento são omitidos, pois RevisionV1 não os representa — exportá-los produziria uma cena falsa. Escala e rotação Z são suportadas. Custo: essas chapas não terão etiqueta/cena neste formato; o catálogo não fornece uma lista de avisos nesta tarefa.
- Ruling: cópias que repetem UUID de módulo, QR ou chave lógica são recusadas no manifesto, sem regenerar identidades — a API reserva o token permanentemente por projeto/módulo/chave. Custo: módulos copiados com atributos herdados ou duas ocorrências da mesma definição precisam de uma política futura de individualização antes de sincronizar. A recusa evita transferir uma etiqueta já emitida para outra peça.
- Ruling: Ruby indisponível não bloqueia a escrita autorizada; os testes são entregues, tentados e a limitação é explícita. Não se afirma RED/GREEN Ruby nem validação no SketchUp. Custo: sintaxe e comportamento Ruby/SketchUp ainda precisam de execução real.

## Testes e evidência

Foram escritos antes dos serviços: suporte SketchUp, `teste_catalogo_pecas.rb`, `teste_manifesto_qr.rb` e `teste_cliente_sincronizacao.rb`. São 17 casos Minitest após as extensões, cobrindo travessia, ambientes, filtros, unidade/centro/escala/rotação, migração, identidade, fitas, esquema exato, privacidade, conflitos, HTTP, erros e sigilo. O transporte HTTP é substituído somente na fronteira de rede; o cliente real monta o pedido e interpreta o resultado.

1. RED tentado nos três arquivos antes da implementação: exit 1, PowerShell informa `The term 'ruby' is not recognized`. Não foi uma falha funcional dos testes.
2. Repetidos os três comandos após implementar e estender testes; mesma ausência de Ruby.
3. Regressões `teste_dados_projeto.rb`, `teste_identidade_peca.rb` e `teste_montagem_balcao_inferior.rb` também tentadas: mesma ausência. Não houve execução de Minitest, parser Ruby, SketchUp ou HTTP real.
4. Criados `testes/fixtures/manifesto-qr-v1.json` e `teste_manifesto_qr_contract.js`. O fixture foi elaborado manualmente com os valores esperados dos testes Ruby; **não foi produzido executando o exportador Ruby**. O teste Ruby possui exportação opt-in pela variável `NEX_MOB_MANIFEST_FIXTURE` para verificar a saída real quando houver runtime.
5. Primeira abordagem do teste Node tentou importar diretamente o validador ESM gerado da API e falhou porque ele contém uma dependência `require` tratada pelo bundler do Worker. O teste foi ajustado para compilar o schema com o próprio Ajv Draft 2020-12 instalado em `cloudflare/worker` (nenhum arquivo da API alterado). A tentativa seguinte falhou porque o fixture ainda não existia; após criá-lo, passou. O teste Node exige `npm ci` em `cloudflare/worker` num checkout limpo.
6. `node --test testes/*.js`: **7 aprovados, 0 falhas**, exit 0. Os dois novos testes comprovam que o fixture é aceito por Ajv e que campo público `cliente`, medida zero, token inválido e fita string são rejeitados.
7. `npm run check:validator` em `cloudflare/worker`: exit 0, `Draft 2020-12 validator matches the contract.` Isso confirma que o validador da API permanece correspondente ao schema usado no teste.
8. Checagem Node dos 32 `require_relative` dos arquivos novos/principal: todos os destinos existentes, exit 0.
9. `git diff --check`: sem erros. Checagem staged repetida antes do commit.

Próxima verificação necessária: executar os três novos arquivos Minitest individualmente com Ruby/Minitest e as regressões anteriores; exportar um fixture Ruby real e validá-lo contra o schema; verificar geometria, visibilidade, preservação de atributos e TLS dentro do SketchUp 2026. Nenhuma aprovação Ruby ou teste de integração remota é alegada.
