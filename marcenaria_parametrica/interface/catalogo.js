const titulos = {
  inferiores: ['Balcões inferiores', '1 disponível'],
  superiores: ['Módulos superiores', 'Em preparação'],
  armarios: ['Armários', 'Em preparação']
};

function alternarCategoria(categoria) {
  document.querySelectorAll('[data-categoria]').forEach((botao) => {
    const ativa = botao.dataset.categoria === categoria;
    botao.classList.toggle('ativa', ativa);
    botao.setAttribute('aria-pressed', String(ativa));
  });
  document.querySelectorAll('[data-lista]').forEach((lista) => {
    lista.classList.toggle('oculto', lista.dataset.lista !== categoria);
  });
  document.getElementById('titulo-categoria').textContent = titulos[categoria][0];
  document.getElementById('contagem-categoria').textContent = titulos[categoria][1];
}

document.querySelectorAll('[data-categoria]').forEach((botao) => {
  botao.addEventListener('click', () => alternarCategoria(botao.dataset.categoria));
});

document.querySelectorAll('[data-tipo]').forEach((botao) => {
  botao.addEventListener('click', () => {
    if (!window.sketchup) {
      document.getElementById('mensagem-catalogo').textContent = 'Abra o catálogo dentro do SketchUp.';
      return;
    }
    document.getElementById('mensagem-catalogo').textContent = 'Clique no modelo para posicionar.';
    window.sketchup.iniciar_insercao(botao.dataset.tipo);
  });
});

document.getElementById('botao-modo-construtivo').addEventListener('click', () => {
  if (window.sketchup) window.sketchup.abrir_modo_construtivo();
});
