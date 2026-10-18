const teste = require('node:test');
const afirmar = require('node:assert/strict');
const sistema = require('node:fs');
const caminho = require('node:path');
const { createRequire } = require('node:module');

// Fixture manual equivalente às expectativas Minitest; não prova execução do exportador Ruby.
const arquivo = caminho.join(__dirname, 'fixtures/manifesto-qr-v1.json');
// Usa o mesmo Ajv Draft 2020-12 da API; requer npm ci em cloudflare/worker.
const requireWorker = createRequire(caminho.join(__dirname, '../cloudflare/worker/package.json'));
const Ajv2020 = requireWorker('ajv/dist/2020.js');
const schema = JSON.parse(sistema.readFileSync(caminho.join(__dirname, '../contracts/revision-v1.schema.json'), 'utf8'));
const validate = new Ajv2020({ strict: true, strictTuples: false }).compile(schema);

teste('fixture do catálogo QR respeita RevisionV1 e usa caixa XYZ/centro em mm', () => {
  const manifesto = JSON.parse(sistema.readFileSync(arquivo, 'utf8'));
  afirmar.equal(validate(manifesto), true, JSON.stringify(validate.errors));
  const peca = manifesto.modules[0].pieces[0];
  afirmar.deepEqual(peca.cut_mm, [18, 560, 720]);
  afirmar.deepEqual(peca.transform_mm, [9, 280, 360, 0]);
  afirmar.equal(peca.material, 'MDF Freijó Puro');
  afirmar.equal(sistema.readFileSync(arquivo, 'utf8').includes('CLIENTE PRIVADO 123'), false);
});

teste('contrato recusa cliente público, medida zero e QR inválido no fixture QR', () => {
  for (const alterar of [
    (m) => { m.cliente = 'CLIENTE PRIVADO 123'; },
    (m) => { m.modules[0].pieces[0].cut_mm[0] = 0; },
    (m) => { m.modules[0].pieces[0].qr_token = 'cliente-123'; },
    (m) => { m.modules[0].pieces[0].edge_banding.top = 'true'; }
  ]) {
    const manifesto = JSON.parse(sistema.readFileSync(arquivo, 'utf8'));
    alterar(manifesto);
    afirmar.equal(validate(manifesto), false);
  }
});
