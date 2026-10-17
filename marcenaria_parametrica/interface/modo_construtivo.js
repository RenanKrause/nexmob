const formularioModo = document.getElementById('formulario-modo');
const nomeModo = document.getElementById('nome-modo');
const mensagemModo = document.getElementById('mensagem-modo');
const listaModos = document.getElementById('lista-modos');
const abasSecoes = document.getElementById('abas-secoes');
const camposConstrutivos = document.getElementById('campos-construtivos');
const botaoAtivar = document.getElementById('ativar-modo');
let modosSalvos = {};
let rascunhoModo = {};
let modoSelecionado = '';
let modoAtivo = '';
let familiaAtual = 'inferiores';
let secaoAtual = 'estrutura';
let ocupado = false;

function copiar(valor) {
  return JSON.parse(JSON.stringify(valor));
}

function secoesDaFamilia() {
  return window.secoesConstrutivas[familiaAtual];
}

function secaoSelecionada() {
  return secoesDaFamilia().find((secao) => secao.id === secaoAtual) || secoesDaFamilia()[0];
}

function guardarCampos() {
  if (!rascunhoModo[familiaAtual]) return;
  camposConstrutivos.querySelectorAll('[data-medida]').forEach((campo) => {
    rascunhoModo[familiaAtual][campo.dataset.medida] = campo.value;
  });
}

function atualizarMensagem(texto, classe = '') {
  mensagemModo.textContent = texto;
  mensagemModo.className = `mensagem-edicao ${classe}`.trim();
}

function atualizarPrevia(chave) {
  const definicao = window.camposConstrutivos[chave] || window.camposConstrutivos[secaoSelecionada().campos[0]];
  window.atualizarPreviaConstrutiva(familiaAtual, rascunhoModo[familiaAtual] || {}, definicao.destaque);
}

function atualizarBotoes() {
  botaoAtivar.disabled = ocupado || !modoSelecionado || modoSelecionado === modoAtivo;
  document.querySelectorAll('.acoes-cabecalho button, #novo-modo').forEach((botao) => {
    if (botao !== botaoAtivar) botao.disabled = ocupado;
  });
}

function renderizarListaModos() {
  listaModos.replaceChildren();
  Object.keys(modosSalvos).forEach((nome) => {
    const botao = document.createElement('button');
    botao.type = 'button';
    botao.className = 'item-modo';
    botao.classList.toggle('selecionado', nome === modoSelecionado);
    botao.setAttribute('aria-pressed', String(nome === modoSelecionado));
    const titulo = document.createElement('strong');
    titulo.textContent = nome;
    const estado = document.createElement('small');
    estado.textContent = nome === modoAtivo ? 'Ativo para novos móveis' : 'Clique para editar';
    botao.append(titulo, estado);
    botao.addEventListener('click', () => carregarModo(nome));
    listaModos.append(botao);
  });
}

function renderizarFamilias() {
  document.querySelectorAll('[data-familia]').forEach((botao) => {
    const ativa = botao.dataset.familia === familiaAtual;
    botao.classList.toggle('ativa', ativa);
    botao.setAttribute('aria-pressed', String(ativa));
    botao.tabIndex = ativa ? 0 : -1;
  });
}

function renderizarAbas() {
  abasSecoes.replaceChildren();
  secoesDaFamilia().forEach((secao) => {
    const botao = document.createElement('button');
    const ativa = secao.id === secaoAtual;
    botao.id = `aba-secao-${secao.id}`;
    botao.type = 'button';
    botao.role = 'tab';
    botao.className = 'aba-secao';
    botao.classList.toggle('ativa', ativa);
    botao.setAttribute('aria-selected', String(ativa));
    botao.tabIndex = ativa ? 0 : -1;
    botao.textContent = secao.titulo;
    botao.addEventListener('click', () => trocarSecao(secao.id));
    botao.addEventListener('keydown', navegarAbas);
    abasSecoes.append(botao);
  });
}

function renderizarCampos() {
  const secao = secaoSelecionada();
  document.getElementById('titulo-secao').textContent = secao.titulo;
  document.getElementById('descricao-secao').textContent = secao.descricao;
  camposConstrutivos.replaceChildren();
  secao.campos.forEach((chave) => {
    const definicao = window.camposConstrutivos[chave];
    const linha = document.createElement('div');
    linha.className = 'linha-regra';
    const texto = document.createElement('div');
    const rotulo = document.createElement('label');
    const identificador = `campo-${chave}`;
    rotulo.htmlFor = identificador;
    rotulo.textContent = definicao.titulo;
    const descricao = document.createElement('p');
    descricao.textContent = definicao.descricao;
    texto.append(rotulo, descricao);
    const medida = document.createElement('span');
    medida.className = 'campo-medida';
    const campo = document.createElement('input');
    campo.id = identificador;
    campo.type = 'number';
    campo.min = definicao.minimo;
    campo.max = definicao.maximo;
    campo.step = '0.1';
    campo.required = true;
    campo.value = rascunhoModo[familiaAtual][chave];
    campo.dataset.medida = chave;
    campo.addEventListener('focus', () => atualizarPrevia(chave));
    campo.addEventListener('input', () => { guardarCampos(); atualizarPrevia(chave); });
    campo.addEventListener('blur', () => atualizarPrevia());
    const unidade = document.createElement('span');
    unidade.textContent = 'mm';
    medida.append(campo, unidade);
    linha.append(texto, medida);
    camposConstrutivos.append(linha);
  });
}

function renderizarModal(destaque) {
  const familia = window.familiasConstrutivas[familiaAtual];
  document.getElementById('subtitulo-familia').textContent = familia.subtitulo;
  document.querySelector('.conteudo-secao').setAttribute('aria-labelledby', `aba-secao-${secaoAtual}`);
  renderizarFamilias();
  renderizarListaModos();
  renderizarAbas();
  renderizarCampos();
  atualizarPrevia(destaque);
  atualizarBotoes();
}

function carregarModo(nome) {
  if (!modosSalvos[nome]) return;
  guardarCampos();
  modoSelecionado = nome;
  rascunhoModo = copiar(modosSalvos[nome]);
  nomeModo.value = nome;
  renderizarModal();
  atualizarMensagem('Modo carregado para edição. Ative-o quando quiser usá-lo nos próximos móveis.');
}

function trocarFamilia(familia) {
  if (familia === familiaAtual) return;
  guardarCampos();
  familiaAtual = familia;
  secaoAtual = secoesDaFamilia()[0].id;
  renderizarModal();
}

function trocarSecao(secao) {
  if (secao === secaoAtual) return;
  guardarCampos();
  secaoAtual = secao;
  renderizarModal();
}

function navegarAbas(evento) {
  const botoes = [...abasSecoes.querySelectorAll('[role="tab"]')];
  const indice = botoes.indexOf(evento.currentTarget);
  let destino = null;
  if (evento.key === 'ArrowRight') destino = (indice + 1) % botoes.length;
  if (evento.key === 'ArrowLeft') destino = (indice - 1 + botoes.length) % botoes.length;
  if (evento.key === 'Home') destino = 0;
  if (evento.key === 'End') destino = botoes.length - 1;
  if (destino !== null) {
    evento.preventDefault();
    trocarSecao(secoesDaFamilia()[destino].id);
    abasSecoes.querySelectorAll('[role="tab"]')[destino].focus();
  }
}

function navegarFamilias(evento) {
  const botoes = [...document.querySelectorAll('[data-familia]')];
  const indice = botoes.indexOf(evento.currentTarget);
  let destino = null;
  if (evento.key === 'ArrowDown') destino = (indice + 1) % botoes.length;
  if (evento.key === 'ArrowUp') destino = (indice - 1 + botoes.length) % botoes.length;
  if (evento.key === 'Home') destino = 0;
  if (evento.key === 'End') destino = botoes.length - 1;
  if (destino !== null) {
    evento.preventDefault();
    trocarFamilia(botoes[destino].dataset.familia);
    botoes[destino].focus();
  }
}

function definirOcupado(valor) {
  ocupado = valor;
  atualizarBotoes();
}

function enviarModo(aplicar) {
  if (!formularioModo.reportValidity()) return;
  guardarCampos();
  if (!window.sketchup) {
    window.exibirErro('Abra o modo construtivo dentro do SketchUp.');
    return;
  }
  definirOcupado(true);
  atualizarMensagem(aplicar ? 'Aplicando ao projeto…' : 'Salvando modo…');
  const dados = { nome: nomeModo.value.trim(), categorias: rascunhoModo };
  if (aplicar) window.sketchup.aplicar_modo(dados);
  else window.sketchup.salvar_modo(dados);
}

window.receberModos = function receberModos(dados) {
  modosSalvos = dados.modos || {};
  modoAtivo = dados.ativo || '';
  carregarModo(modoAtivo);
  atualizarBotoes();
};

window.exibirMensagemModo = function exibirMensagemModo(texto) {
  definirOcupado(false);
  atualizarMensagem(texto, 'sucesso');
};

window.exibirErro = function exibirErro(texto) {
  definirOcupado(false);
  atualizarMensagem(texto, 'erro');
};

document.querySelectorAll('[data-familia]').forEach((botao) => {
  botao.addEventListener('click', () => trocarFamilia(botao.dataset.familia));
  botao.addEventListener('keydown', navegarFamilias);
});

document.getElementById('novo-modo').addEventListener('click', () => {
  guardarCampos();
  modoSelecionado = '';
  nomeModo.value = '';
  renderizarModal();
  nomeModo.focus();
  atualizarMensagem('Dê um nome ao novo modo. As regras abertas foram copiadas para você ajustar.');
});

botaoAtivar.addEventListener('click', () => {
  if (window.sketchup && modoSelecionado) {
    definirOcupado(true);
    atualizarMensagem('Ativando modo…');
    window.sketchup.ativar_modo(modoSelecionado);
  }
});

formularioModo.addEventListener('submit', (evento) => { evento.preventDefault(); enviarModo(false); });
document.getElementById('aplicar-projeto').addEventListener('click', () => enviarModo(true));
if (window.sketchup) window.sketchup.pronto();
