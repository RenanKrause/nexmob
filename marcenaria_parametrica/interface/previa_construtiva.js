(() => {
  const espacoSvg = 'http://www.w3.org/2000/svg';

  function limitarNumero(valor, minimo, maximo, padrao) {
    const numero = Number(valor);
    return Number.isFinite(numero) ? Math.min(Math.max(numero, minimo), maximo) : padrao;
  }

  function criarElemento(nome, atributos = {}) {
    const elemento = document.createElementNS(espacoSvg, nome);
    Object.entries(atributos).forEach(([chave, valor]) => elemento.setAttribute(chave, valor));
    return elemento;
  }

  function adicionarRetangulo(desenho, x, y, largura, altura, classe) {
    desenho.append(criarElemento('rect', { x, y, width: largura, height: altura, class: classe }));
  }

  function adicionarLinha(desenho, x1, y1, x2, y2, classe) {
    desenho.append(criarElemento('line', { x1, y1, x2, y2, class: classe }));
  }

  function adicionarTexto(desenho, texto, x, y, classe) {
    const rotulo = criarElemento('text', { x, y, class: classe });
    rotulo.textContent = texto;
    desenho.append(rotulo);
  }

  function nomeDestaque(chave) {
    return { estrutura: 'a estrutura', fundo: 'o fundo', sarrafos: 'os sarrafos', vao: 'o vão livre', gaveta: 'a caixa da gaveta', porta: 'as portas', frente: 'as frentes de gaveta' }[chave] || 'a montagem';
  }

  window.atualizarPreviaConstrutiva = function atualizarPreviaConstrutiva(categoria, valores, destaque) {
    const desenho = document.getElementById('desenho-previa');
    const descricao = document.getElementById('descricao-previa');
    if (!desenho || !descricao) return;

    const espessura = limitarNumero(valores.espessura_mm, 12, 30, 18);
    const fundo = limitarNumero(valores.espessura_fundo_mm, 3, 12, 6);
    const sarrafo = limitarNumero(valores.largura_sarrafo_mm, 50, 150, 80);
    const escalaChapa = 10 + (espessura - 12) * 0.55;
    const escalaFundo = 4 + (fundo - 3) * 0.8;
    const escalaSarrafo = 22 + (sarrafo - 50) * 0.4;
    const espessuraGaveta = limitarNumero(valores.espessura_gaveta_mm, 12, 25, 15);
    const fundoGaveta = limitarNumero(valores.espessura_fundo_gaveta_mm, 3, 12, 6);
    const escalaGaveta = 7 + (espessuraGaveta - 12) * 0.8;
    const escalaFundoGaveta = 4 + (fundoGaveta - 3) * 0.8;
    const temSarrafos = categoria === 'inferiores';
    desenho.replaceChildren();

    adicionarRetangulo(desenho, 52, 38, 256, 172, 'previa-fundo' + (destaque === 'fundo' ? ' destacado' : ''));
    adicionarRetangulo(desenho, 42, 30, escalaChapa, 190, 'previa-peca' + (destaque === 'estrutura' ? ' destacado' : ''));
    adicionarRetangulo(desenho, 308 - escalaChapa, 30, escalaChapa, 190, 'previa-peca' + (destaque === 'estrutura' ? ' destacado' : ''));
    adicionarRetangulo(desenho, 42, 210 - escalaChapa, 266, escalaChapa, 'previa-peca' + (destaque === 'estrutura' ? ' destacado' : ''));
    adicionarRetangulo(desenho, 52, 38, escalaFundo, 162, 'previa-espessura-fundo' + (destaque === 'fundo' ? ' destacado' : ''));

    if (temSarrafos) {
      adicionarRetangulo(desenho, 42 + escalaChapa, 30, 266 - (escalaChapa * 2), 8, 'previa-sarrafo' + (destaque === 'sarrafos' ? ' destacado' : ''));
      adicionarRetangulo(desenho, 42 + escalaChapa, 44 + escalaSarrafo, 266 - (escalaChapa * 2), 8, 'previa-sarrafo' + (destaque === 'sarrafos' ? ' destacado' : ''));
    } else {
      adicionarRetangulo(desenho, 42 + escalaChapa, 30, 266 - (escalaChapa * 2), escalaChapa, 'previa-peca' + (destaque === 'estrutura' ? ' destacado' : ''));
    }

    if (categoria === 'inferiores') {
      const classeGaveta = 'previa-gaveta' + (destaque === 'gaveta' ? ' destacado' : '');
      adicionarRetangulo(desenho, 94, 126, escalaGaveta, 58, classeGaveta);
      adicionarRetangulo(desenho, 238 - escalaGaveta, 126, escalaGaveta, 58, classeGaveta);
      adicionarRetangulo(desenho, 94 + escalaGaveta, 126, 144 - 2 * escalaGaveta, escalaGaveta, classeGaveta);
      adicionarRetangulo(desenho, 94 + escalaGaveta, 184 - escalaFundoGaveta, 144 - 2 * escalaGaveta, escalaFundoGaveta, classeGaveta);
      adicionarTexto(desenho, 'gaveta', 142, 160, 'previa-rotulo' + (destaque === 'gaveta' ? ' destacado' : ''));
      if (destaque === 'porta') {
        adicionarRetangulo(desenho, 87, 112, 73, 78, 'previa-porta destacado');
        adicionarRetangulo(desenho, 165, 112, 73, 78, 'previa-porta destacado');
        adicionarTexto(desenho, 'portas', 138, 104, 'previa-rotulo destacado');
      }
      if (destaque === 'frente') {
        adicionarRetangulo(desenho, 87, 112, 151, 36, 'previa-frente destacado');
        adicionarRetangulo(desenho, 87, 152, 151, 36, 'previa-frente destacado');
        adicionarTexto(desenho, 'frentes', 133, 104, 'previa-rotulo destacado');
      }
    }

    adicionarLinha(desenho, 24, 100, 24, 180, 'previa-cota' + (destaque === 'vao' ? ' destacado' : ''));
    adicionarLinha(desenho, 19, 100, 29, 100, 'previa-cota' + (destaque === 'vao' ? ' destacado' : ''));
    adicionarLinha(desenho, 19, 180, 29, 180, 'previa-cota' + (destaque === 'vao' ? ' destacado' : ''));
    adicionarTexto(desenho, `${Math.round(limitarNumero(valores.folga_minima_mm, 40, 200, 80))} mm`, 8, 94, 'previa-rotulo' + (destaque === 'vao' ? ' destacado' : ''));
    adicionarTexto(desenho, window.familiasConstrutivas[categoria].titulo, 42, 246, 'previa-titulo');
    descricao.textContent = `Prévia de ${window.familiasConstrutivas[categoria].titulo}. O destaque mostra ${nomeDestaque(destaque)}.`;
  };
})();
