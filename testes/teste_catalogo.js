const teste = require('node:test');
const afirmar = require('node:assert/strict');
const sistema = require('node:fs');
const caminho = require('node:path');
const maquina = require('node:vm');

function criarElemento(dados = {}) {
  const eventos = {};
  const classes = new Set();
  return {
    dataset: dados,
    eventos,
    classes,
    classList: { toggle(nome, ativo) { if (ativo) classes.add(nome); else classes.delete(nome); } },
    setAttribute(nome, valor) { this[nome] = valor; },
    addEventListener(nome, acao) { eventos[nome] = acao; },
    textContent: ''
  };
}

teste('catálogo troca categoria e envia o tipo escolhido ao SketchUp', () => {
  const categorias = ['inferiores', 'superiores', 'armarios'].map((nome) => criarElemento({ categoria: nome }));
  const listas = ['inferiores', 'superiores', 'armarios'].map((nome) => criarElemento({ lista: nome }));
  const modulo = criarElemento({ tipo: 'balcao_inferior' });
  const elementos = {
    'titulo-categoria': criarElemento(),
    'contagem-categoria': criarElemento(),
    'mensagem-catalogo': criarElemento(),
    'botao-modo-construtivo': criarElemento()
  };
  const chamadas = [];
  const documento = {
    querySelectorAll(seletor) {
      return { '[data-categoria]': categorias, '[data-lista]': listas, '[data-tipo]': [modulo] }[seletor];
    },
    getElementById(identificador) { return elementos[identificador]; }
  };
  const janela = { sketchup: { iniciar_insercao(tipo) { chamadas.push(tipo); } } };
  const arquivo = caminho.join(__dirname, '../marcenaria_parametrica/interface/catalogo.js');
  maquina.runInNewContext(sistema.readFileSync(arquivo, 'utf8'), { document: documento, window: janela });

  categorias[1].eventos.click();
  afirmar.equal(elementos['titulo-categoria'].textContent, 'Módulos superiores');
  afirmar.equal(listas[1].classes.has('oculto'), false);
  afirmar.equal(listas[0].classes.has('oculto'), true);
  modulo.eventos.click();
  afirmar.deepEqual(chamadas, ['balcao_inferior']);
});
