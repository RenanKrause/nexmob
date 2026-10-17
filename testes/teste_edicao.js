const teste = require('node:test');
const afirmar = require('node:assert/strict');
const sistema = require('node:fs');
const caminho = require('node:path');
const maquina = require('node:vm');

teste('edição recebe medidas e envia números ao controlador', () => {
  const campos = new Map(['largura_mm', 'altura_mm', 'profundidade_mm'].map((chave) => [chave, { value: '' }]));
  const eventos = {};
  const formulario = {
    elements: { namedItem(chave) { return campos.get(chave); } },
    addEventListener(nome, acao) { eventos[nome] = acao; },
    reportValidity() { return true; }
  };
  const mensagem = { textContent: '', className: '' };
  const detalhes = { hidden: true };
  const medidas = { textContent: '' };
  const posicoes = Object.fromEntries(['prateleira', 'divisoria'].map((tipo) => [tipo, {
    value: '', max: 0, disabled: false, reportValidity() { return true; }
  }]));
  const quantidades = Object.fromEntries(['prateleira', 'divisoria', 'gaveta'].map((tipo) => [tipo, {
    value: 1, max: 10, eventos: {}, reportValidity() { return true; },
    addEventListener(nome, acao) { this.eventos[nome] = acao; }
  }]));
  const botoes = ['prateleira', 'divisoria', 'gaveta'].map((tipo) => ({
    dataset: { elemento: tipo }, disabled: false, eventos: {},
    addEventListener(nome, acao) { this.eventos[nome] = acao; }
  }));
  const botaoSelecao = { eventos: {}, addEventListener(nome, acao) { this.eventos[nome] = acao; } };
  const botaoFrentes = { eventos: {}, addEventListener(nome, acao) { this.eventos[nome] = acao; } };
  const chamadas = [];
  const janela = { atualizarResumoMedidas() {}, limparPeca() {}, ocultarPeca() {}, sketchup: {
    pronto() { chamadas.push('pronto'); },
    salvar_edicao(parametros) { chamadas.push(parametros); },
    vista_frontal() { chamadas.push('vista_frontal'); },
    abrir_modo_construtivo() { chamadas.push('modo'); },
    abrir_frentes() { chamadas.push('frentes'); },
    adicionar_elemento(dados) { chamadas.push(dados); }
  } };
  const documento = {
    getElementById(identificador) {
      if (identificador === 'formulario-edicao') return formulario;
      if (identificador === 'mensagem-edicao') return mensagem;
      if (identificador === 'detalhes-vao') return detalhes;
      if (identificador === 'medidas-vao') return medidas;
      if (identificador === 'botao-vista-frontal') return botaoSelecao;
      if (identificador === 'botao-modo-construtivo') return { addEventListener() {} };
      if (identificador === 'botao-frentes') return botaoFrentes;
      if (identificador.startsWith('quantidade-')) return quantidades[identificador.replace('quantidade-', '')];
      return posicoes[identificador.replace('posicao-', '')];
    },
    querySelectorAll() { return botoes; },
    querySelector(seletor) { return botoes.find((botao) => seletor.includes(botao.dataset.elemento)); }
  };
  class DadosFormulario {
    forEach(acao) { campos.forEach((campo, chave) => acao(campo.value, chave)); }
  }
  const arquivo = caminho.join(__dirname, '../marcenaria_parametrica/interface/edicao.js');
  maquina.runInNewContext(sistema.readFileSync(arquivo, 'utf8'), {
    document: documento, window: janela, FormData: DadosFormulario, Number
  });

  afirmar.equal(chamadas[0], 'pronto');
  janela.receberModulo({ largura_mm: 800, altura_mm: 720 });
  afirmar.equal(campos.get('largura_mm').value, 800);
  campos.get('largura_mm').value = '900';
  eventos.submit({ preventDefault() {} });
  afirmar.equal(chamadas[1].largura_mm, 900);
  janela.confirmarEdicao();
  afirmar.equal(mensagem.textContent, 'Medidas aplicadas ao módulo.');
  botaoSelecao.eventos.click();
  afirmar.equal(chamadas[2], 'vista_frontal');
  botaoFrentes.eventos.click();
  afirmar.equal(chamadas[3], 'frentes');
  janela.receberVao({ largura_mm: 764, altura_mm: 684, espessura_mm: 18 });
  afirmar.equal(detalhes.hidden, false);
  afirmar.equal(posicoes.prateleira.value, 333);
  botoes[0].eventos.click();
  afirmar.equal(chamadas[4].tipo, 'prateleira');
  afirmar.equal(chamadas[4].posicao_mm, 333);
  afirmar.equal(chamadas[4].quantidade, 1);
  quantidades.prateleira.value = 3;
  quantidades.prateleira.eventos.input();
  afirmar.equal(posicoes.prateleira.value, 157.5);
  posicoes.prateleira.value = 350;
  botoes[0].eventos.click();
  afirmar.equal(chamadas[5].quantidade, 3);
  afirmar.equal(chamadas[5].posicao_mm, 350);
  quantidades.gaveta.value = 3;
  quantidades.gaveta.eventos.input();
  botoes[2].eventos.click();
  afirmar.equal(chamadas[6].tipo, 'gaveta');
  afirmar.equal(chamadas[6].quantidade, 3);
  afirmar.equal(chamadas[6].posicao_mm, undefined);
  janela.limparVao();
  afirmar.equal(detalhes.hidden, true);
});

teste('medida da peça é enviada como vão livre, sem descontar a chapa da base', () => {
  const eventos = {};
  const chamadas = [];
  const elementos = new Map([
    ['detalhes-peca', { hidden: true }],
    ['posicao-peca', { value: '', min: 0, max: 0, reportValidity() { return true; } }],
    ['estado-sem-selecao', { hidden: false }],
    ['detalhes-vao', { hidden: true }],
    ['nome-peca', { textContent: '' }],
    ['rotulo-medida-peca', { textContent: '' }],
    ['referencia-posicao', { textContent: '' }],
    ['dependencias-peca', { textContent: '' }],
    ['mensagem-edicao', { textContent: '', className: '' }],
    ['formulario-posicao', { addEventListener(nome, acao) { eventos[nome] = acao; } }],
    ['botao-concluir', { addEventListener() {} }]
  ]);
  const documento = {
    getElementById(identificador) { return elementos.get(identificador); },
    querySelector() { return { disabled: false }; },
    querySelectorAll() { return []; }
  };
  const janela = { mostrarAba() {}, sketchup: { acao_peca(dados) { chamadas.push(dados); } } };
  const arquivo = caminho.join(__dirname, '../marcenaria_parametrica/interface/selecao_pecas.js');
  maquina.runInNewContext(sistema.readFileSync(arquivo, 'utf8'), { document: documento, window: janela, Number });
  janela.receberPeca({ tipo: 'prateleira', nome: 'Prateleira 1', minimo_vao_mm: 80,
    maximo_vao_mm: 586, vao_livre_mm: 332, dependentes: 1 });
  afirmar.equal(elementos.get('posicao-peca').value, 332);
  afirmar.equal(elementos.get('rotulo-medida-peca').textContent, 'Altura livre do vão inferior');
  elementos.get('posicao-peca').value = '350';
  eventos.submit({ preventDefault() {} });
  afirmar.equal(chamadas[0].vao_livre_mm, 350);
  afirmar.equal(chamadas[0].posicao_mm, undefined);
});

teste('gaveta selecionada envia posição, altura e profundidade da caixa ao controlador', () => {
  const eventos = {};
  const chamadas = [];
  const botoes = ['mover', 'duplicar', 'excluir'].map((acao) => ({
    dataset: { acaoGaveta: acao }, disabled: false,
    addEventListener(nome, manipulador) { this[nome] = manipulador; }
  }));
  const elementos = new Map([
    ['detalhes-peca', { hidden: true }],
    ['detalhes-gaveta', { hidden: true, dataset: {} }],
    ['estado-sem-selecao', { hidden: false }],
    ['detalhes-vao', { hidden: true }],
    ['nome-gaveta', { textContent: '' }],
    ['posicao-gaveta', { value: '', min: 0, max: 0, reportValidity() { return true; } }],
    ['altura-gaveta', { value: '', min: 0, max: 0, reportValidity() { return true; } }],
    ['profundidade-gaveta', { value: '', min: 0, max: 0, reportValidity() { return true; } }],
    ['mensagem-edicao', { textContent: '', className: '' }],
    ['formulario-gaveta', { addEventListener(nome, manipulador) { eventos[nome] = manipulador; } }],
    ['formulario-posicao', { addEventListener() {} }],
    ['botao-concluir', { addEventListener() {} }]
  ]);
  const documento = {
    getElementById(identificador) { return elementos.get(identificador); },
    querySelector() { return { disabled: false }; },
    querySelectorAll(seletor) { return seletor === '[data-acao-gaveta]' ? botoes : []; }
  };
  const janela = { mostrarAba() {}, sketchup: { acao_gaveta(dados) { chamadas.push(dados); } } };
  const arquivo = caminho.join(__dirname, '../marcenaria_parametrica/interface/selecao_pecas.js');
  maquina.runInNewContext(sistema.readFileSync(arquivo, 'utf8'), { document: documento, window: janela, Number });

  janela.receberGaveta({ id: 'gaveta_1_2', nome: 'Gaveta 1.2', posicao_mm: 250,
    altura_mm: 180, profundidade_mm: 450, maximo_posicao_mm: 420,
    maximo_altura_mm: 300, maximo_profundidade_mm: 540 });
  afirmar.equal(elementos.get('detalhes-gaveta').hidden, false);
  afirmar.equal(elementos.get('posicao-gaveta').value, 250);
  afirmar.equal(elementos.get('altura-gaveta').value, 180);
  afirmar.equal(elementos.get('profundidade-gaveta').value, 450);

  elementos.get('posicao-gaveta').value = '260';
  elementos.get('altura-gaveta').value = '175';
  elementos.get('profundidade-gaveta').value = '430';
  eventos.submit({ preventDefault() {} });
  afirmar.equal(chamadas[0].acao, 'redimensionar');
  afirmar.equal(chamadas[0].id, 'gaveta_1_2');
  afirmar.equal(chamadas[0].posicao_mm, 260);
  afirmar.equal(chamadas[0].altura_mm, 175);
  afirmar.equal(chamadas[0].profundidade_mm, 430);
  botoes[1].click();
  afirmar.equal(chamadas[1].acao, 'duplicar');
  afirmar.equal(chamadas[1].id, 'gaveta_1_2');
});
