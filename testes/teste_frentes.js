const teste = require('node:test');
const afirmar = require('node:assert/strict');
const sistema = require('node:fs');
const caminho = require('node:path');
const maquina = require('node:vm');

teste('modal de frentes envia portas e frentes de gaveta para o vão selecionado', () => {
  const chamadas = [];
  const botoes = ['portas', 'gavetas'].map((tipo) => ({
    dataset: { tipo }, classList: { toggle() {} }, addEventListener(nome, acao) { this[nome] = acao; }
  }));
  const elementos = new Map([
    ['seletor-vao', { value: 'vao', options: [], replaceChildren(...filhos) { this.options = filhos; }, addEventListener(nome, acao) { this[nome] = acao; } }],
    ['quantidade-portas', { value: 1, disabled: false }],
    ['espessura-frente', { value: 18, reportValidity() { return true; } }],
    ['folga-frente', { value: 2, reportValidity() { return true; } }],
    ['recuo-frente', { value: 0, reportValidity() { return true; } }],
    ['botao-aplicar', { disabled: false, addEventListener(nome, acao) { this[nome] = acao; } }],
    ['resumo-frentes', { textContent: '' }],
    ['mensagem-frentes', { textContent: '', className: '' }]
  ]);
  const documento = {
    getElementById(identificador) { return elementos.get(identificador); },
    querySelectorAll(seletor) { return seletor === '[data-tipo]' ? botoes : []; },
    createElement() { return { value: '', textContent: '' }; }
  };
  const janela = { sketchup: { salvar_frentes(dados) { chamadas.push(dados); } } };
  const arquivo = caminho.join(__dirname, '../marcenaria_parametrica/interface/frentes.js');
  maquina.runInNewContext(sistema.readFileSync(arquivo, 'utf8'), { document: documento, window: janela, Number, String });

  janela.receberFrentes({ vaos: [{ id: 'vao', largura_mm: 764, altura_mm: 684, gavetas: 3 }], composicoes: [] });
  afirmar.equal(elementos.get('quantidade-portas').value, 2);
  elementos.get('botao-aplicar').click();
  afirmar.equal(chamadas[0].tipo, 'frentes_gavetas');
  botoes[0].click();
  elementos.get('quantidade-portas').value = '2';
  elementos.get('botao-aplicar').click();
  afirmar.equal(chamadas[1].vao_id, 'vao');
  afirmar.equal(chamadas[1].tipo, 'portas');
  afirmar.equal(chamadas[1].quantidade, 2);
  afirmar.equal(chamadas[1].espessura_mm, 18);

  botoes[1].click();
  elementos.get('botao-aplicar').click();
  afirmar.equal(chamadas[2].tipo, 'frentes_gavetas');
  afirmar.equal(chamadas[2].quantidade, undefined);
});
