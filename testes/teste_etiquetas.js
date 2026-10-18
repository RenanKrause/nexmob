const teste = require('node:test');
const afirmar = require('node:assert/strict');
const path = require('node:path');
const arquivo = path.join(__dirname, '../marcenaria_parametrica/interface/etiquetas.js');
const E = require(arquivo);
const item = { cliente: 'Ana <Cliente>', ambiente: 'Cozinha', modulo_nome: 'Balcão 1', nome: 'Lateral', codigo: 'LAT-1',
  corte_mm: [720, 560, 18], material: 'MDF Freijó Puro', fita_borda: 'frente', qr_token: '0123456789abcdef0123456789abcdef' };
const config = { viewer_base_url: 'https://nexmob.pages.dev', revision_id: 'rev-1', gerado_em: '2026-10-17T20:00:00Z' };

teste('configuração bloqueia medidas ilegíveis, QR menor que 20 mm e texto menor que 6 pt', () => {
  afirmar.equal(E.validarConfiguracao({}).largura_mm, 99);
  for (const dado of [{ qr_mm: 19 }, { texto_pt: 5 }, { largura_mm: 30 }, { altura_mm: 20 },
    { altura_mm: 48 }, { altura_mm: Infinity }, { largura_mm: 'nan' }, { offset_x_mm: 7 }, { offset_y_mm: -10 }]) {
    afirmar.throws(() => E.validarConfiguracao(dado));
  }
});

teste('composição contém dados reais escapados, quatro lados, desenho e QR SVG local', () => {
  const html = E.renderizarEtiqueta(item, config);
  for (const texto of ['Ana &lt;Cliente&gt;', 'Cozinha', 'Balcão 1', 'LAT-1', 'Lateral', '720 × 560 × 18 mm',
    'MDF Freijó Puro', 'Superior', 'Inferior', 'Esquerda', 'Direita', 'Escaneie para ver o móvel', 'rev-1']) afirmar.ok(html.includes(texto), texto);
  afirmar.match(html, /class="qr"[^>]*>[\s\S]*?<svg/);
  afirmar.match(html, /class="desenho"/);
  afirmar.equal((html.match(/data-lado="top" class="com-fita"/g) || []).length, 1);
  afirmar.doesNotMatch(html, /<(?:img|script)[^>]+(?:src|href)=|https?:\/\/[^< ]*\.(?:png|svg)/);
});

teste('fitas frente, todos, nenhuma e cada lado preservam a orientação da fabricação', () => {
  const vazio = { top: false, right: false, bottom: false, left: false };
  afirmar.deepEqual(E.fitas('frente'), { ...vazio, top: true });
  afirmar.deepEqual(E.fitas('todos'), { top: true, right: true, bottom: true, left: true });
  afirmar.deepEqual(E.fitas('nenhuma'), vazio);
  for (const [lado, chave] of [['superior', 'top'], ['direita', 'right'], ['inferior', 'bottom'], ['esquerda', 'left']]) {
    afirmar.deepEqual(E.fitas(lado), { ...vazio, [chave]: true });
  }
  afirmar.deepEqual(E.fitas({ top: false, right: true, bottom: true, left: false }), { ...vazio, right: true, bottom: true });
  afirmar.throws(() => E.fitas('lateral_desconhecida'));
});

teste('URL pública contém somente token hexadecimal de 32 posições e rejeita base insegura', () => {
  afirmar.equal(E.urlPublica(item, config), 'https://nexmob.pages.dev/p/0123456789abcdef0123456789abcdef');
  for (const viewer_base_url of ['javascript:alert(1)', 'http://host', 'https://user:secret@host', 'https://host?cliente=Ana', 'https://host/#private']) {
    afirmar.throws(() => E.urlPublica(item, { viewer_base_url }));
  }
  afirmar.throws(() => E.urlPublica({ ...item, qr_token: 'Ana' }, config));
});

teste('A4 quebra após dez etiquetas e mantém células 99 × 55,8 mesmo com tamanho térmico diferente', () => {
  const saida = E.montarDocumento(Array.from({ length: 11 }, () => item), { ...config, largura_mm: 110, altura_mm: 65, offset_x_mm: 1.2, offset_y_mm: -2 }, 'a4');
  afirmar.deepEqual(saida.paginas.map(p => p.length), [10, 1]);
  afirmar.match(saida.css, /size: 210mm 297mm/);
  afirmar.match(saida.css, /grid-template-columns: repeat\(2, 99mm\)/);
  afirmar.match(saida.css, /grid-template-rows: repeat\(5, 55\.8mm\)/);
  afirmar.match(saida.css, /translate\(1\.2mm, -2mm\)/);
  afirmar.match(saida.css, /--largura:99mm/);
  afirmar.equal((saida.html.match(/class="folha a4"/g) || []).length, 2);
});

teste('impressão térmica usa uma etiqueta por página no tamanho ativo', () => {
  const saida = E.montarDocumento([item, item], { ...config, largura_mm: 110, altura_mm: 65 }, 'termica');
  afirmar.deepEqual(saida.paginas.map(p => p.length), [1, 1]);
  afirmar.match(saida.css, /size: 110mm 65mm/);
  afirmar.equal((saida.html.match(/class="folha termica"/g) || []).length, 2);
});

teste('lote vazio, medidas ausentes e texto que não cabe impedem a geração em vez de omitir dados', () => {
  afirmar.throws(() => E.montarDocumento([], config, 'termica'));
  afirmar.throws(() => E.renderizarEtiqueta({ ...item, corte_mm: [0, 560, 18] }, config));
  afirmar.throws(() => E.renderizarEtiqueta({ ...item, cliente: 'Cliente extenso '.repeat(200) }, config), /cabe|legível/);
  afirmar.throws(() => E.renderizarEtiqueta(item, { ...config, revision_id: 'revisao'.repeat(200) }), /cabe|legível/);
  afirmar.throws(() => E.montarDocumento([item], config, 'desconhecido'));
  const html = E.renderizarEtiqueta({ ...item, ambiente: '', material: '' }, config);
  afirmar.doesNotMatch(html, /MDF padrão|Sem ambiente|Cliente não informado/);
});

function interfaceFalsa() {
  const nomes = ['largura_mm', 'altura_mm', 'qr_mm', 'texto_pt', 'offset_x_mm', 'offset_y_mm', 'modo_saida',
    'botao-previa', 'botao-imprimir', 'botao-pdf', 'botao-calibracao', 'formulario-etiquetas', 'mensagem-etiquetas', 'contagem-etiquetas', 'previa-etiquetas'];
  const elementos = Object.fromEntries(nomes.map(nome => [nome, { value: '', textContent: '', disabled: false, hidden: false,
    eventos: {}, addEventListener(evento, acao) { this.eventos[evento] = acao; } }]));
  elementos.modo_saida.value = 'termica';
  const chamadas = [];
  const documento = { getElementById(id) { return elementos[id]; } };
  const janela = { sketchup: { etiquetas_prontas() { chamadas.push(['pronto']); },
    salvar_configuracao_etiquetas(valor) { chamadas.push(['salvar', valor]); }, solicitar_previa(valor) { chamadas.push(['previa', valor]); } } };
  const impressoes = [];
  const api = E.conectarInterface(documento, janela, (dados, modo, imprimir) => impressoes.push({ dados, modo, imprimir }));
  return { elementos, chamadas, janela, impressoes, api };
}

teste('interface recebe lote, mostra contagem, valida prévia e pede salvar medidas antes da nova prévia', () => {
  const t = interfaceFalsa();
  afirmar.deepEqual(t.chamadas[0], ['pronto']);
  t.janela.receberDadosEtiquetas({ itens: [item], configuracao: config, sincronizado: true });
  afirmar.match(t.elementos['contagem-etiquetas'].textContent, /1/);
  t.elementos['botao-previa'].eventos.click();
  afirmar.equal(t.impressoes[0].imprimir, false);
  t.elementos.largura_mm.value = '110';
  t.elementos['formulario-etiquetas'].eventos.submit({ preventDefault() {} });
  afirmar.equal(t.chamadas[1][0], 'salvar');
  afirmar.equal(JSON.parse(t.chamadas[1][1]).largura_mm, 110);
  afirmar.equal(t.chamadas[2][0], 'previa');
});

teste('interface encaminha impressão direta e Gerar PDF A4 e bloqueia conteúdo alterado/ilegível', () => {
  const t = interfaceFalsa();
  afirmar.equal(t.elementos['botao-imprimir'].disabled, true);
  t.janela.receberDadosEtiquetas({ itens: [item], configuracao: config, sincronizado: true });
  t.elementos['botao-imprimir'].eventos.click();
  t.elementos['botao-pdf'].eventos.click();
  afirmar.deepEqual(t.impressoes.map(p => [p.modo, p.imprimir]), [['termica', true], ['a4', true]]);
  t.elementos.qr_mm.value = '19';
  t.elementos['botao-imprimir'].eventos.click();
  afirmar.equal(t.impressoes.length, 2);
  afirmar.match(t.elementos['mensagem-etiquetas'].textContent, /20/);
});

teste('documento preparado mede overflow antes de chamar impressão do sistema', () => {
  let impresso = 0;
  const raiz = { querySelectorAll() { return [{ scrollHeight: 10, clientHeight: 9, scrollWidth: 4, clientWidth: 4 }]; } };
  afirmar.throws(() => E.verificarLegibilidade(raiz), /cabe|legível/);
  raiz.querySelectorAll = () => [{ scrollHeight: 9, clientHeight: 9, scrollWidth: 4, clientWidth: 4 }];
  E.imprimirPreparado(raiz, { focus() {}, print() { impresso++; } });
  afirmar.equal(impresso, 1);
});

teste('interface exige confirmação explícita de sincronização antes de liberar etiquetas', () => {
  for (const sincronizado of [false, undefined]) {
    const t = interfaceFalsa();
    t.janela.receberDadosEtiquetas({ itens: [item], configuracao: config, sincronizado });
    afirmar.equal(t.elementos['botao-imprimir'].disabled, true);
    t.elementos['botao-pdf'].eventos.click();
    afirmar.equal(t.impressoes.length, 0);
  }
});
