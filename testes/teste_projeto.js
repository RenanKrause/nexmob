const teste = require('node:test');
const afirmar = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

function tela() {
  const elementos = new Map();
  function criar() {
    return { value: '', textContent: '', hidden: false, disabled: false, children: [], eventos: {},
      addEventListener(nome, acao) { this.eventos[nome] = acao; },
      replaceChildren(...filhos) { this.children = filhos; }, appendChild(filho) { this.children.push(filho); },
      reportValidity() { return true; } };
  }
  const documento = { getElementById(id) { if (!elementos.has(id)) elementos.set(id, criar()); return elementos.get(id); },
    createElement: criar };
  const chamadas = [];
  const janela = { sketchup: new Proxy({}, { get(_alvo, nome) { return dados => chamadas.push({ nome, dados }); } }) };
  const contexto = { module: { exports: {} }, document: undefined };
  const arquivo = path.join(__dirname, '../marcenaria_parametrica/interface/projeto.js');
  if (fs.existsSync(arquivo)) vm.runInNewContext(fs.readFileSync(arquivo, 'utf8'), contexto);
  return { documento, janela, chamadas, campo: id => documento.getElementById(id), api: contexto.module.exports,
    enviar(id) { documento.getElementById(id).eventos.submit({ preventDefault() {} }); } };
}

teste('formulário envia cliente, cria e renomeia ambientes preservando o identificador', () => {
  const t = tela();
  afirmar.equal(typeof t.api.conectarProjeto, 'function', 'Conector do projeto ainda não implementado');
  t.api.conectarProjeto(t.documento, t.janela);
  t.janela.receberProjeto({ cliente: '<Ana>', ambientes: [{ id: 'cozinha-1', nome: '<Cozinha>' }] });
  afirmar.equal(t.campo('cliente').value, '<Ana>');
  afirmar.equal(t.campo('ambiente-projeto').children[0].textContent, '<Cozinha>');
  t.campo('cliente').value = '  Ana  ';
  t.enviar('formulario-cliente');
  t.campo('novo-ambiente').value = '  Sala  ';
  t.enviar('formulario-criar-ambiente');
  t.campo('ambiente-projeto').value = 'cozinha-1';
  t.campo('nome-ambiente').value = 'Cozinha gourmet';
  t.enviar('formulario-renomear-ambiente');
  afirmar.equal(t.chamadas[1].nome, 'salvar_cliente');
  afirmar.equal(t.chamadas[1].dados.nome, 'Ana');
  afirmar.equal(t.chamadas[2].nome, 'criar_ambiente');
  afirmar.equal(t.chamadas[2].dados.nome, 'Sala');
  afirmar.equal(t.chamadas[3].nome, 'renomear_ambiente');
  afirmar.equal(t.chamadas[3].dados.id, 'cozinha-1');
  afirmar.equal(t.chamadas[3].dados.nome, 'Cozinha gourmet');
  t.campo('botao-excluir-ambiente').eventos.click();
  afirmar.equal(t.chamadas[4].nome, 'excluir_ambiente');
  afirmar.equal(t.chamadas[4].dados.id, 'cozinha-1');
  t.janela.erroProjeto('O ambiente está em uso por um módulo.');
  afirmar.match(t.campo('mensagem-projeto').textContent, /em uso/);
});

teste('nome vazio impede criar ambiente e lista vazia impede renomear ou excluir', () => {
  const t = tela();
  afirmar.equal(typeof t.api.conectarProjeto, 'function');
  t.api.conectarProjeto(t.documento, t.janela);
  t.janela.receberProjeto({ cliente: '', ambientes: [] });
  t.campo('novo-ambiente').value = '  ';
  t.enviar('formulario-criar-ambiente');
  t.enviar('formulario-renomear-ambiente');
  t.campo('botao-excluir-ambiente').eventos.click();
  afirmar.equal(t.chamadas.length, 1);
  afirmar.equal(t.campo('botao-excluir-ambiente').disabled, true);
});

teste('editor associa ambiente ao módulo e permite material padrão ou substituição por peça', () => {
  const t = tela();
  afirmar.equal(typeof t.api.conectarModulo, 'function', 'Conector dos metadados ainda não implementado');
  t.api.conectarModulo(t.documento, t.janela);
  t.janela.receberMetadadosModulo({ ambiente_id: 'sala', material_padrao: 'MDP',
    ambientes: [{ id: 'sala', nome: 'Sala' }], pecas: [
      { chave_logica: 'lat-1', nome: 'Lateral', material_padrao: 'MDP', material_sobrescrito: 'Freijó' },
      { chave_logica: 'lat-2', nome: 'Outra lateral', material_padrao: 'MDP', material_sobrescrito: '' }
    ] });
  afirmar.equal(t.campo('ambiente-modulo').value, 'sala');
  afirmar.equal(t.campo('modo-material-peca').value, 'sobrescrito');
  t.campo('ambiente-modulo').value = '';
  t.campo('material-padrao-modulo').value = 'MDF Branco';
  t.enviar('formulario-metadados-modulo');
  afirmar.equal(t.chamadas[0].nome, 'salvar_metadados_modulo');
  afirmar.equal(t.chamadas[0].dados.ambiente_id, '');
  afirmar.equal(t.chamadas[0].dados.material_padrao, 'MDF Branco');
  t.campo('modo-material-peca').value = 'padrao';
  t.campo('modo-material-peca').eventos.change();
  afirmar.equal(t.campo('material-sobrescrito-peca').disabled, true);
  t.enviar('formulario-material-peca');
  afirmar.equal(t.chamadas[1].dados.chave_logica, 'lat-1');
  afirmar.equal(t.chamadas[1].dados.material_sobrescrito, '');
  t.campo('peca-material').value = 'lat-2';
  t.campo('peca-material').eventos.change();
  t.campo('modo-material-peca').value = 'sobrescrito';
  t.campo('modo-material-peca').eventos.change();
  t.campo('material-sobrescrito-peca').value = 'MDF Freijó Puro';
  t.enviar('formulario-material-peca');
  afirmar.equal(t.chamadas[2].dados.chave_logica, 'lat-2');
  afirmar.equal(t.chamadas[2].dados.material_sobrescrito, 'MDF Freijó Puro');
  t.campo('material-sobrescrito-peca').value = ' ';
  t.enviar('formulario-material-peca');
  afirmar.equal(t.chamadas.length, 3);
});
