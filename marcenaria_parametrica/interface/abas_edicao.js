(() => {
  const abas = Array.from(document.querySelectorAll('[data-aba]'));
  window.mostrarAba = function mostrarAba(nome) {
    abas.forEach((aba) => {
      const ativa = aba.dataset.aba === nome;
      aba.setAttribute('aria-selected', String(ativa));
      aba.tabIndex = ativa ? 0 : -1;
      document.getElementById(`painel-${aba.dataset.aba}`).hidden = !ativa;
    });
  };
  abas.forEach((aba, indice) => {
    aba.addEventListener('click', () => window.mostrarAba(aba.dataset.aba));
    aba.addEventListener('keydown', (evento) => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(evento.key)) return;
      evento.preventDefault();
      let destino = (indice + (evento.key === 'ArrowLeft' ? -1 : 1) + abas.length) % abas.length;
      if (evento.key === 'Home') destino = 0;
      if (evento.key === 'End') destino = abas.length - 1;
      window.mostrarAba(abas[destino].dataset.aba);
      abas[destino].focus();
    });
  });
})();
