(() => {
  const detalhes = document.getElementById('detalhes-peca');
  const detalhesGaveta = document.getElementById('detalhes-gaveta');
  const campo = document.getElementById('posicao-peca');
  const vazio = document.getElementById('estado-sem-selecao');

  window.limparPeca = function limparPeca() {
    detalhes.hidden = true;
    if (detalhesGaveta) detalhesGaveta.hidden = true;
    vazio.hidden = false;
  };
  window.ocultarPeca = function ocultarPeca() {
    detalhes.hidden = true;
    if (detalhesGaveta) detalhesGaveta.hidden = true;
    vazio.hidden = true;
    window.mostrarAba('construir');
  };
  window.receberPeca = function receberPeca(peca) {
    document.getElementById('detalhes-vao').hidden = true;
    detalhes.hidden = false;
    if (detalhesGaveta) detalhesGaveta.hidden = true;
    vazio.hidden = true;
    window.mostrarAba('construir');
    document.getElementById('nome-peca').textContent = peca.nome;
    document.getElementById('rotulo-medida-peca').textContent = peca.tipo === 'prateleira' ?
      'Altura livre do vão inferior' : 'Largura livre do vão esquerdo';
    document.getElementById('referencia-posicao').textContent = peca.tipo === 'prateleira' ?
      'Da face superior da base do vão até a face inferior da prateleira' :
      'Da lateral interna esquerda do vão até a face esquerda da divisória';
    campo.min = peca.minimo_vao_mm;
    campo.max = peca.maximo_vao_mm;
    campo.value = Number(peca.vao_livre_mm.toFixed(1));
    document.querySelector('[data-acao-peca="excluir"]').disabled = false;
    document.getElementById('dependencias-peca').textContent =
      'Arraste a alça no 3D ou digite uma posição. Duplicar coloca uma cópia no vão adjacente disponível.';
    window.confirmarAcao('Peça selecionada. Arraste a alça ou use as ações.');
  };
  window.receberGaveta = function receberGaveta(gaveta) {
    document.getElementById('detalhes-vao').hidden = true;
    detalhes.hidden = true;
    detalhesGaveta.hidden = false;
    detalhesGaveta.dataset.gavetaId = gaveta.id;
    vazio.hidden = true;
    window.mostrarAba('construir');
    document.getElementById('nome-gaveta').textContent = gaveta.nome;
    const posicao = document.getElementById('posicao-gaveta');
    const altura = document.getElementById('altura-gaveta');
    const profundidade = document.getElementById('profundidade-gaveta');
    posicao.min = gaveta.minimo_posicao_mm;
    posicao.max = gaveta.maximo_posicao_mm;
    posicao.value = Number(gaveta.posicao_mm.toFixed(1));
    altura.min = gaveta.minimo_altura_mm;
    altura.max = gaveta.maximo_altura_mm;
    altura.value = Number(gaveta.altura_mm.toFixed(1));
    profundidade.min = gaveta.minimo_profundidade_mm;
    profundidade.max = gaveta.maximo_profundidade_mm;
    profundidade.value = Number(gaveta.profundidade_mm.toFixed(1));
    window.confirmarAcao('Gaveta selecionada. Arraste a alça ou ajuste as medidas da caixa.');
  };
  window.confirmarAcao = function confirmarAcao(texto) {
    const mensagem = document.getElementById('mensagem-edicao');
    mensagem.textContent = texto;
    mensagem.className = 'mensagem-edicao sucesso';
  };
  window.receberResumo = function receberResumo(resumo) {
    const contagem = document.getElementById('contagem-pecas');
    contagem.replaceChildren();
    [`${resumo.vaos} ${resumo.vaos === 1 ? 'vão' : 'vãos'}`,
      `${resumo.prateleiras} ${resumo.prateleiras === 1 ? 'prateleira' : 'prateleiras'}`,
      `${resumo.divisorias} ${resumo.divisorias === 1 ? 'divisória' : 'divisórias'}`,
      `${resumo.gavetas || 0} ${(resumo.gavetas || 0) === 1 ? 'gaveta' : 'gavetas'}`].forEach((texto) => {
      const etiqueta = document.createElement('span');
      etiqueta.textContent = texto;
      contagem.appendChild(etiqueta);
    });
  };
  window.atualizarResumoMedidas = function atualizarResumoMedidas(parametros) {
    document.getElementById('dimensoes-resumo').textContent =
      `${parametros.largura_mm} × ${parametros.altura_mm} × ${parametros.profundidade_mm} mm`;
  };

  function executarAcao(dados) {
    if (!window.sketchup) return window.exibirErro('Abra a edição dentro do SketchUp.');
    window.sketchup.acao_peca(dados);
  }
  function executarAcaoGaveta(dados) {
    if (!window.sketchup) return window.exibirErro('Abra a edição dentro do SketchUp.');
    window.sketchup.acao_gaveta(dados);
  }
  document.getElementById('formulario-posicao').addEventListener('submit', (evento) => {
    evento.preventDefault();
    if (campo.reportValidity()) executarAcao({ acao: 'mover', vao_livre_mm: Number(campo.value) });
  });
  document.querySelectorAll('[data-acao-peca]').forEach((botao) => {
    botao.addEventListener('click', () => executarAcao({ acao: botao.dataset.acaoPeca }));
  });
  const formularioGaveta = document.getElementById('formulario-gaveta');
  if (formularioGaveta) {
    formularioGaveta.addEventListener('submit', (evento) => {
      evento.preventDefault();
      const posicao = document.getElementById('posicao-gaveta');
      const altura = document.getElementById('altura-gaveta');
      const profundidade = document.getElementById('profundidade-gaveta');
      if (!posicao.reportValidity() || !altura.reportValidity() || !profundidade.reportValidity()) return;
      executarAcaoGaveta({ acao: 'redimensionar', id: janelaIdGaveta(), posicao_mm: Number(posicao.value),
        altura_mm: Number(altura.value), profundidade_mm: Number(profundidade.value) });
    });
  }
  function janelaIdGaveta() {
    return detalhesGaveta.dataset.gavetaId;
  }
  document.querySelectorAll('[data-acao-gaveta]').forEach((botao) => {
    botao.addEventListener('click', () => executarAcaoGaveta({ acao: botao.dataset.acaoGaveta, id: janelaIdGaveta() }));
  });
  document.getElementById('botao-concluir').addEventListener('click', () => {
    if (window.sketchup) window.sketchup.concluir_edicao();
  });
})();
