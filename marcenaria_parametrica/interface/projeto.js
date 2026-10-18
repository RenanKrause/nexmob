(function (raiz, fabrica) {
  'use strict';
  if (typeof module === 'object' && module.exports) module.exports = fabrica();
  else raiz.Projeto = fabrica();
})(typeof window === 'undefined' ? globalThis : window, function () {
  'use strict';
  function preencherOpcoes(documento, seletor, itens) {
    seletor.replaceChildren();
    itens.forEach(item => {
      const opcao = documento.createElement('option');
      opcao.value = item.id;
      opcao.textContent = item.nome;
      seletor.appendChild(opcao);
    });
  }

  function conectarProjeto(documento, janela) {
    const campo = id => documento.getElementById(id);
    let ambientes = [];
    const mensagem = (texto, erro = false) => {
      campo('mensagem-projeto').textContent = texto;
      campo('mensagem-projeto').className = erro ? 'mensagem-edicao erro' : 'mensagem-edicao sucesso';
    };
    function enviar(acao, dados) {
      if (!janela.sketchup) return mensagem('Abra os dados do projeto no SketchUp.', true);
      janela.sketchup[acao](dados);
    }
    function selecionar() {
      const ambiente = ambientes.find(item => item.id === campo('ambiente-projeto').value);
      campo('nome-ambiente').value = ambiente ? ambiente.nome : '';
    }
    janela.receberProjeto = dados => {
      campo('cliente').value = dados.cliente;
      ambientes = dados.ambientes || [];
      const selecionado = campo('ambiente-projeto').value;
      preencherOpcoes(documento, campo('ambiente-projeto'), ambientes);
      campo('ambiente-projeto').value = ambientes.some(a => a.id === selecionado) ? selecionado : (ambientes[0]?.id || '');
      campo('botao-renomear-ambiente').disabled = !ambientes.length;
      campo('botao-excluir-ambiente').disabled = !ambientes.length;
      selecionar();
      campo('novo-ambiente').value = '';
      mensagem(dados.mensagem || 'Dados do projeto carregados.');
    };
    janela.erroProjeto = texto => mensagem(String(texto), true);
    campo('ambiente-projeto').addEventListener('change', selecionar);
    campo('formulario-cliente').addEventListener('submit', evento => {
      evento.preventDefault();
      enviar('salvar_cliente', { nome: campo('cliente').value.trim() });
    });
    campo('formulario-criar-ambiente').addEventListener('submit', evento => {
      evento.preventDefault();
      const nome = campo('novo-ambiente').value.trim();
      if (!nome) return mensagem('Informe um nome para o ambiente.', true);
      enviar('criar_ambiente', { nome });
    });
    campo('formulario-renomear-ambiente').addEventListener('submit', evento => {
      evento.preventDefault();
      const id = campo('ambiente-projeto').value;
      const nome = campo('nome-ambiente').value.trim();
      if (!id || !nome) return mensagem('Selecione um ambiente e informe o nome.', true);
      enviar('renomear_ambiente', { id, nome });
    });
    campo('botao-excluir-ambiente').addEventListener('click', () => {
      const id = campo('ambiente-projeto').value;
      if (id) enviar('excluir_ambiente', { id });
    });
    if (janela.sketchup) janela.sketchup.projeto_pronto();
  }

  function conectarModulo(documento, janela) {
    const campo = id => documento.getElementById(id);
    let pecas = [];
    const erro = texto => {
      if (janela.exibirErro) janela.exibirErro(texto);
      else campo('mensagem-edicao').textContent = texto;
    };
    const enviar = (acao, dados) => {
      if (!janela.sketchup) return erro('Abra a edição dentro do SketchUp.');
      janela.sketchup[acao](dados);
    };
    function modoMaterial() {
      campo('material-sobrescrito-peca').disabled = campo('modo-material-peca').value !== 'sobrescrito';
    }
    function selecionarPeca() {
      const peca = pecas.find(p => p.chave_logica === campo('peca-material').value);
      campo('modo-material-peca').value = peca?.material_sobrescrito ? 'sobrescrito' : 'padrao';
      campo('material-sobrescrito-peca').value = peca?.material_sobrescrito || '';
      campo('material-efetivo-peca').textContent = peca ? `Material atual: ${peca.material_sobrescrito || peca.material_padrao}` : 'Nenhuma peça disponível.';
      campo('botao-material-peca').disabled = !peca;
      modoMaterial();
    }
    janela.receberMetadadosModulo = dados => {
      preencherOpcoes(documento, campo('ambiente-modulo'), [{ id: '', nome: 'Sem ambiente' }, ...(dados.ambientes || [])]);
      campo('ambiente-modulo').value = dados.ambiente_id || '';
      campo('material-padrao-modulo').value = dados.material_padrao || 'MDP';
      const anterior = campo('peca-material').value;
      pecas = dados.pecas || [];
      preencherOpcoes(documento, campo('peca-material'), pecas.map(p => ({ id: p.chave_logica, nome: p.nome })));
      campo('peca-material').value = pecas.some(p => p.chave_logica === anterior) ? anterior : (pecas[0]?.chave_logica || '');
      selecionarPeca();
    };
    campo('peca-material').addEventListener('change', selecionarPeca);
    campo('modo-material-peca').addEventListener('change', modoMaterial);
    campo('formulario-metadados-modulo').addEventListener('submit', evento => {
      evento.preventDefault();
      const material = campo('material-padrao-modulo').value.trim();
      if (!material) return erro('Informe o material padrão do módulo.');
      enviar('salvar_metadados_modulo', { ambiente_id: campo('ambiente-modulo').value, material_padrao: material });
    });
    campo('formulario-material-peca').addEventListener('submit', evento => {
      evento.preventDefault();
      const chave = campo('peca-material').value;
      if (!pecas.some(p => p.chave_logica === chave)) return erro('Selecione uma peça.');
      const sobrescrito = campo('modo-material-peca').value === 'sobrescrito';
      const material = sobrescrito ? campo('material-sobrescrito-peca').value.trim() : '';
      if (sobrescrito && !material) return erro('Informe o material que substituirá o padrão.');
      enviar('salvar_material_peca', { chave_logica: chave, material_sobrescrito: material });
    });
  }
  return { conectarProjeto, conectarModulo };
});

if (typeof document !== 'undefined' && document.getElementById('formulario-cliente')) {
  window.Projeto.conectarProjeto(document, window);
}
