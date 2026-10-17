# Contrato `RevisionV1`

O contrato em [`contracts/revision-v1.schema.json`](../../contracts/revision-v1.schema.json) é a interface versionada entre o Nex Mob, a API Cloudflare e o visualizador. O payload descreve uma revisão completa e imutável; o servidor só deve torná-la atual depois de validar e persistir o manifesto inteiro.

## Estrutura

Uma revisão contém `schema_version` (`"1"`), `project_id`, `revision_id`, `synced_at` em RFC 3339 e `modules`. Cada módulo identifica seu móvel, nome, ambiente e peças. Cada peça contém uma `logical_key` estável, token QR aleatório, nome, dimensões de corte, transformação, material efetivo, lados com fita e visibilidade.

`cut_mm` é uma tupla de três medidas positivas em milímetros. `transform_mm` é `[x, y, z, rotation_z_deg]`: posição em milímetros e rotação em graus ao redor de Z. `edge_banding` sempre possui os booleanos `top`, `right`, `bottom` e `left`. `qr_token` contém exatamente 64 caracteres hexadecimais (32 bytes); ele não codifica dados do projeto. O fixture válido em [`contracts/fixtures/revision-v1.json`](../../contracts/fixtures/revision-v1.json) é um exemplo mínimo.

## HTTP

- O plugin envia o manifesto completo por `POST /v1/revisions`, autenticando a instalação com `Authorization: Bearer <credencial>`.
- O QR público aponta para `/p/{qr_token}` no domínio do Pages. A página resolve o token por meio da API pública e exibe a revisão atual, destacando a peça correspondente.

Não incluir dados pessoais, caminhos locais ou credenciais no token ou na URL pública. Tokens são persistentes por peça lógica; alterações de medida não devem exigir um QR novo.

## Validação local

Com Node.js e npm disponíveis, valide o fixture válido e o inválido na raiz do repositório:

```sh
npx --yes ajv-cli@5 validate --spec=draft2020 -s contracts/revision-v1.schema.json -d contracts/fixtures/revision-v1.json
npx --yes ajv-cli@5 validate --spec=draft2020 -s contracts/revision-v1.schema.json -d contracts/fixtures/revision-v1-invalid.json
```

O primeiro comando deve passar; o segundo deve falhar, pois omite `schema_version` e contém token e dimensão fora do contrato.
