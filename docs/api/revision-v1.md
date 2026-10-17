# Contrato `RevisionV1`

O contrato em [`contracts/revision-v1.schema.json`](../../contracts/revision-v1.schema.json) é a interface versionada entre o Nex Mob, a API Cloudflare e o visualizador. O payload descreve uma revisão completa e imutável; o servidor só deve torná-la atual depois de validar e persistir o manifesto inteiro.

## Estrutura

Uma revisão contém `schema_version` (`"1"`), `project_id`, `revision_id`, `synced_at` em RFC 3339 e `modules`. Cada módulo identifica seu móvel, nome, ambiente e peças. Cada peça contém uma `logical_key` estável, token QR aleatório, nome, dimensões de corte, transformação, material efetivo, lados com fita e visibilidade.

`cut_mm` é uma tupla de três medidas positivas em milímetros. `transform_mm` é `[x, y, z, rotation_z_deg]`: posição em milímetros e rotação em graus ao redor de Z. `edge_banding` sempre possui os booleanos `top`, `right`, `bottom` e `left`. `qr_token` contém exatamente 32 caracteres hexadecimais (16 bytes, 128 bits); ele não codifica dados do projeto. O fixture válido em [`contracts/fixtures/revision-v1.json`](../../contracts/fixtures/revision-v1.json) é um exemplo mínimo.

## HTTP

- O plugin envia o manifesto completo por `POST /v1/revisions`, autenticando a instalação com `Authorization: Bearer <credencial>`.
- O QR público aponta para `/p/{qr_token}` no domínio do Pages. A página resolve o token por meio da API pública e exibe a revisão atual, destacando a peça correspondente.

### Sincronização e imutabilidade

`POST /v1/revisions` retorna `201 { "status": "published" }` depois de gravar o JSON em R2 e concluir um único batch transacional no D1 (projeto, revisão, tokens e ponteiro atual). Uma falha de armazenamento retorna `503`, preservando o ponteiro anterior. O JSON usa chaves `revisions/{project_id}/{revision_id}.json`, com cada identificador codificado por `encodeURIComponent` para evitar colisões entre segmentos. A criação condicional em R2 impede sobrescrita.

O ID da revisão é único dentro de cada projeto. Reutilizar um ID já publicado retorna `409`; envie um novo ID em cada sincronização. Se R2 persistir o objeto mas o batch D1 falhar, ele permanece órfão e privado: uma tentativa idêntica pode completá-lo, mas um conteúdo diferente com o mesmo ID retorna `409`. O serviço não remove automaticamente objetos órfãos. Entre revisões distintas concorrentes, o último batch concluído define a revisão atual.

Credencial ausente, incorreta ou revogada retorna `401`. Um projeto pertence à instalação que o criou; outra instalação recebe `403`. Um token QR é globalmente único (sem distinguir maiúsculas/minúsculas), permanece reservado mesmo após a peça ser removida e não pode ser transferido a outro projeto ou chave lógica (`409`). Ownership, revogação e conflitos de token são novamente protegidos dentro do batch, inclusive se mudarem durante a gravação R2.

O payload completo é validado em runtime pelo contrato Draft 2020-12, sem coerção ou remoção de campos desconhecidos. Dados inválidos retornam `400`. O serviço também rejeita tokens repetidos na mesma revisão, IDs de módulo repetidos e chaves lógicas repetidas dentro de um módulo para evitar seleção ambígua. A mesma chave lógica pode aparecer em módulos diferentes; a seleção usa o token QR.

O índice de tokens é consultado e gravado em lote via `json_each` com parâmetros vinculados, mantendo a quantidade de consultas D1 independente do número de peças. Isso evita esgotar o limite de consultas por requisição em projetos completos.

### Resolução pública

`GET /v1/public/pieces/{qr_token}` não exige credencial e retorna somente:

```json
{
  "module": {
    "module_id": "module-a1",
    "name": "Balcão inferior",
    "environment": "Cozinha",
    "pieces": []
  },
  "selected_piece_key": "lateral-esquerda",
  "synced_at": "2026-10-17T16:00:00Z"
}
```

`module` contém todas as peças daquele móvel conforme o contrato (o array vazio acima é apenas abreviação). Outros módulos, IDs de instalação/projeto/revisão, índices D1 e chaves R2 não fazem parte da resposta. A consulta parte de `projects.current_revision_id`; um QR antigo mostra a cena atual, e uma peça removida da revisão atual retorna `404 { "error": "not_found" }`, assim como tokens desconhecidos ou malformados. Um manifesto atual ausente ou inválido retorna `503 { "error": "storage_unavailable" }` sem revelar dados internos. Todas as respostas usam `Cache-Control: no-store`.

`GET /health` retorna `200 { "status": "ok" }` e indica que o handler está ativo; não verifica a disponibilidade de D1/R2.

### CORS e origem Pages

Configure `PAGES_ORIGIN` com a origem HTTPS exata do Pages, sem barra final. Somente essa origem recebe `Access-Control-Allow-Origin`; não há wildcard nem credenciais de navegador. O plugin pode enviar POST sem `Origin`, usando sua credencial Bearer. POST com outra origem retorna `403`. Preflights aceitam apenas a rota/método correspondente e, no POST, os headers `Authorization` e `Content-Type`; origens, métodos ou headers não permitidos retornam `403`. A leitura pública permanece acessível por HTTP sem autenticação; CORS controla apenas acesso via navegador.

Não incluir dados pessoais, caminhos locais ou credenciais no token ou na URL pública. Tokens são persistentes por peça lógica; alterações de medida não devem exigir um QR novo.

## Validação local

Com Node.js e npm disponíveis, valide o fixture válido e o inválido na raiz do repositório:

```sh
npx --yes ajv-cli@5 validate --spec=draft2020 -s contracts/revision-v1.schema.json -d contracts/fixtures/revision-v1.json
npx --yes ajv-cli@5 validate --spec=draft2020 -s contracts/revision-v1.schema.json -d contracts/fixtures/revision-v1-invalid.json
```

O primeiro comando deve passar; o segundo deve falhar, pois omite `schema_version` e contém token e dimensão fora do contrato.

O Worker usa um validador gerado pelo Ajv a partir desse mesmo schema, sem compilação dinâmica dentro do runtime Workers. Depois de editar o contrato, execute `npm run generate:validator` em `cloudflare/worker` e inclua o arquivo gerado no commit. `npm run check:validator` confirma que o código gerado corresponde ao schema; `npm test` e `npm run typecheck` verificam integração e tipos.
