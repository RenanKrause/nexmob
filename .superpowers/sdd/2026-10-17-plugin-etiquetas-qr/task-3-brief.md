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
