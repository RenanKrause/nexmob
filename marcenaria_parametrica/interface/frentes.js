const seletorVao = document.getElementById('seletor-vao');
const quantidadePortas = document.getElementById('quantidade-portas');
const espessuraFrente = document.getElementById('espessura-frente');
const folgaFrente = document.getElementById('folga-frente');
const recuoFrente = document.getElementById('recuo-frente');
const botaoAplicar = document.getElementById('botao-aplicar');
const resumo = document.getElementById('resumo-frentes');
const mensagem = document.getElementById('mensagem-frentes');
let vaos = [];
let composicoes = [];
let padroes = {};
let tipoAtual = 'portas';

function mostrarMensagem(texto, classe = '') {
  mensagem.textContent = texto;
  mensagem.className = `mensagem-edicao ${classe}`.trim();
}

function vaoAtual() {
  return vaos.find((vao) => vao.id === seletorVao.value);
}

function composicaoAtual() {
  return composicoes.find((composicao) => composicao.vao_id === seletorVao.value);
}

function chaveTipoAtual() {
  return tipoAtual === 'gavetas' ? 'frentes_gavetas' : 'portas';
}

function sugestaoPortas(vao) {
  return vao.portas_sugeridas || Math.min(4, Math.max(1, Math.ceil(vao.largura_mm / 450)));
}

function aplicarPadroes(vao) {
  const padrao = padroes[chaveTipoAtual()] || { espessura_mm: 18, folga_mm: 2, recuo_mm: 0 };
  quantidadePortas.value = sugestaoPortas(vao);
  espessuraFrente.value = padrao.espessura_mm;
  folgaFrente.value = padrao.folga_mm;
  recuoFrente.value = padrao.recuo_mm;
}

function atualizarFormulario(carregarComposicao = false) {
  const vao = vaoAtual();
  const composicao = composicaoAtual();
  if (!vao) {
    resumo.textContent = 'Nenhum vão disponível para compor.';
    botaoAplicar.disabled = true;
    return;
  }
  if (composicao && carregarComposicao) {
    tipoAtual = composicao.tipo === 'frentes_gavetas' ? 'gavetas' : 'portas';
    quantidadePortas.value = composicao.quantidade || 1;
    espessuraFrente.value = composicao.espessura_mm;
    folgaFrente.value = composicao.folga_mm;
    recuoFrente.value = composicao.recuo_mm;
  } else if (!composicao && carregarComposicao) {
    tipoAtual = vao.gavetas > 0 ? 'gavetas' : 'portas';
    aplicarPadroes(vao);
  }
  const temGavetas = vao.gavetas > 0;
  const gavetasAtivas = tipoAtual === 'gavetas';
  const nomesGavetas = (vao.gavetas_identificadas || []).join(', ');
  quantidadePortas.disabled = gavetasAtivas;
  botaoAplicar.disabled = gavetasAtivas && !temGavetas;
  resumo.textContent = gavetasAtivas ?
    (temGavetas ? `${vao.gavetas} caixa(s) padrão detectada(s): ${nomesGavetas || 'gavetas do vão'}. Serão criadas ${vao.gavetas} frente(s) vinculada(s).` : 'Adicione gavetas neste vão antes de criar frentes.') :
    `${Math.round(vao.largura_mm)} × ${Math.round(vao.altura_mm)} mm livres. Sugestão automática: ${sugestaoPortas(vao)} porta(s).`;
  document.querySelectorAll('[data-tipo]').forEach((botao) => {
    const ativo = botao.dataset.tipo === tipoAtual;
    botao.classList.toggle('ativo', ativo);
    botao.setAttribute?.('aria-pressed', String(ativo));
  });
}

function preencherVaos() {
  const opcoes = vaos.map((vao, indice) => {
    const opcao = document.createElement('option');
    opcao.value = vao.id;
    opcao.textContent = `Vão ${indice + 1} · ${Math.round(vao.largura_mm)} × ${Math.round(vao.altura_mm)} mm`;
    return opcao;
  });
  seletorVao.replaceChildren(...opcoes);
  if (opcoes.length) seletorVao.value = opcoes[0].value;
}

window.receberFrentes = function receberFrentes(dados) {
  vaos = dados.vaos || [];
  composicoes = dados.composicoes || [];
  padroes = dados.padroes || {};
  preencherVaos();
  atualizarFormulario(true);
};

window.exibirMensagemFrentes = function exibirMensagemFrentes(texto) {
  mostrarMensagem(texto, 'sucesso');
};

window.exibirErroFrentes = function exibirErroFrentes(texto) {
  mostrarMensagem(texto, 'erro');
};

seletorVao.addEventListener('change', () => atualizarFormulario(true));
document.querySelectorAll('[data-tipo]').forEach((botao) => {
  botao.addEventListener('click', () => {
    tipoAtual = botao.dataset.tipo;
    const vao = vaoAtual();
    if (vao) aplicarPadroes(vao);
    atualizarFormulario();
  });
});

botaoAplicar.addEventListener('click', () => {
  if (![espessuraFrente, folgaFrente, recuoFrente].every((campo) => campo.reportValidity())) return;
  if (!window.sketchup) return window.exibirErroFrentes('Abra este modal dentro do SketchUp.');
  const dados = {
    vao_id: seletorVao.value,
    tipo: chaveTipoAtual(),
    espessura_mm: Number(espessuraFrente.value), folga_mm: Number(folgaFrente.value), recuo_mm: Number(recuoFrente.value)
  };
  if (dados.tipo === 'portas') dados.quantidade = Number(quantidadePortas.value);
  mostrarMensagem('Aplicando composição…');
  window.sketchup.salvar_frentes(dados);
});

if (window.sketchup?.pronto) window.sketchup.pronto();
