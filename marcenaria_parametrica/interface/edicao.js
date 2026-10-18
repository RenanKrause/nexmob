const formulario = document.getElementById('formulario-edicao');
const mensagem = document.getElementById('mensagem-edicao');
const detalhesVao = document.getElementById('detalhes-vao');
let vaoAtual = null;

function atualizarQuantidade(tipo) {
  if (!vaoAtual) return;
  const tamanho = tipo === 'prateleira' ? vaoAtual.altura_mm : vaoAtual.largura_mm;
  const espessura = vaoAtual.espessura_mm;
  const quantidade = document.getElementById(`quantidade-${tipo}`);
  const botao = document.querySelector(`[data-elemento="${tipo}"]`);
  if (tipo === 'gaveta') {
    const folga = vaoAtual.folga_vertical_gaveta_mm || 3;
    const base = vaoAtual.folga_base_gaveta_mm ?? folga;
    const sarrafo = vaoAtual.folga_sarrafo_gaveta_mm ?? folga;
    const limite = Math.min(10, Math.floor((vaoAtual.altura_mm - base - sarrafo + folga) / (80 + folga)));
    quantidade.max = Math.max(1, limite);
    const numero = Number(quantidade.value);
    botao.disabled = limite < 1 || !Number.isInteger(numero) || numero < 1 || numero > limite;
    return;
  }
  const campo = document.getElementById(`posicao-${tipo}`);
  const folga = vaoAtual.folga_minima_mm || 80;
  const limite = Math.min(10, Math.floor((tamanho - folga) / (folga + espessura)));
  quantidade.max = Math.max(1, limite);
  const numero = Number(quantidade.value);
  const disponivel = limite >= 1 && Number.isInteger(numero) && numero >= 1 && numero <= limite;
  const maximo = tamanho - numero * espessura - numero * folga;
  campo.max = maximo;
  campo.value = disponivel ? Number(((tamanho - numero * espessura) / (numero + 1)).toFixed(1)) : '';
  campo.disabled = !disponivel;
  botao.disabled = !disponivel;
}

window.receberModulo = function receberModulo(parametros) {
  window.atualizarResumoMedidas(parametros);
  Object.entries(parametros).forEach(([chave, valor]) => {
    const campo = formulario.elements.namedItem(chave);
    if (campo) campo.value = valor;
  });
  mensagem.textContent = '';
  mensagem.className = 'mensagem-edicao';
};

window.exibirErro = function exibirErro(texto) {
  mensagem.textContent = texto;
  mensagem.className = 'mensagem-edicao erro';
};

window.confirmarEdicao = function confirmarEdicao() {
  mensagem.textContent = 'Medidas aplicadas ao módulo.';
  mensagem.className = 'mensagem-edicao sucesso';
};

window.limparVao = function limparVao() {
  vaoAtual = null;
  detalhesVao.hidden = true;
  window.limparPeca();
};

window.receberVao = function receberVao(vao) {
  vaoAtual = vao;
  window.ocultarPeca();
  detalhesVao.hidden = false;
  document.getElementById('medidas-vao').textContent =
    `${Math.round(vao.largura_mm)} × ${Math.round(vao.altura_mm)} mm`;
  ['prateleira', 'divisoria', 'gaveta'].forEach((tipo) => {
    document.getElementById(`quantidade-${tipo}`).value = 1;
    atualizarQuantidade(tipo);
  });
  mensagem.textContent = 'Vão selecionado. Escolha a peça e a posição.';
  mensagem.className = 'mensagem-edicao';
};

window.confirmarElemento = function confirmarElemento(quantidade = 1, tipo = 'peca') {
  const nome = tipo === 'gaveta' ? (quantidade === 1 ? 'Gaveta' : 'Gavetas') : (quantidade === 1 ? 'Peça' : 'Peças');
  mensagem.textContent = quantidade === 1 ? `${nome} adicionada. Continue editando no 3D.` :
    `${quantidade} ${nome.toLowerCase()} adicionadas em uma operação. Continue editando no 3D.`;
  mensagem.className = 'mensagem-edicao sucesso';
};

formulario.addEventListener('submit', (evento) => {
  evento.preventDefault();
  if (!formulario.reportValidity()) return;
  if (!window.sketchup) {
    window.exibirErro('Abra a edição dentro do SketchUp.');
    return;
  }

  const parametros = {};
  new FormData(formulario).forEach((valor, chave) => {
    parametros[chave] = Number(valor);
  });
  mensagem.textContent = 'Aplicando medidas…';
  mensagem.className = 'mensagem-edicao';
  window.sketchup.salvar_edicao(parametros);
});

document.getElementById('botao-vista-frontal').addEventListener('click', () => {
  if (window.sketchup) window.sketchup.vista_frontal();
});

document.getElementById('botao-modo-construtivo').addEventListener('click', () => {
  if (window.sketchup) window.sketchup.abrir_modo_construtivo();
});

document.getElementById('botao-frentes').addEventListener('click', () => {
  if (window.sketchup) window.sketchup.abrir_frentes();
});

document.querySelectorAll('[data-elemento]').forEach((botao) => {
  const quantidade = document.getElementById(`quantidade-${botao.dataset.elemento}`);
  quantidade.addEventListener('input', () => atualizarQuantidade(botao.dataset.elemento));
  botao.addEventListener('click', () => {
    const tipo = botao.dataset.elemento;
    if (tipo === 'gaveta') {
      if (!quantidade.reportValidity()) return;
      if (!window.sketchup) return window.exibirErro('Abra a edição dentro do SketchUp.');
      mensagem.textContent = 'Adicionando gavetas…';
      mensagem.className = 'mensagem-edicao';
      return window.sketchup.adicionar_elemento({ tipo, quantidade: Number(quantidade.value) });
    }
    const campo = document.getElementById(`posicao-${tipo}`);
    if (!quantidade.reportValidity() || !campo.reportValidity()) return;
    if (!window.sketchup) {
      window.exibirErro('Abra a edição dentro do SketchUp.');
      return;
    }
    mensagem.textContent = 'Adicionando peças…';
    mensagem.className = 'mensagem-edicao';
    window.sketchup.adicionar_elemento({ tipo, posicao_mm: Number(campo.value), quantidade: Number(quantidade.value) });
  });
});

if (window.Projeto) window.Projeto.conectarModulo(document, window);
if (window.sketchup) window.sketchup.pronto();
