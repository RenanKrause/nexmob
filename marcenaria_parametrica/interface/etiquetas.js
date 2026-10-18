(function (raiz, fabrica) {
  'use strict';
  if (typeof module === 'object' && module.exports) module.exports = fabrica(require('./vendor/qrcode.js'));
  else raiz.Etiquetas = fabrica(raiz.qrcode);
})(typeof window === 'undefined' ? globalThis : window, function (qrcode) {
  'use strict';
  const PADRAO = Object.freeze({ largura_mm: 99, altura_mm: 55.8, qr_mm: 22, texto_pt: 7, offset_x_mm: 0, offset_y_mm: 0 });
  const LADOS = Object.freeze({ top: 'Superior', right: 'Direita', bottom: 'Inferior', left: 'Esquerda' });
  const escapar = valor => String(valor == null ? '' : valor).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function validarConfiguracao(entrada = {}) {
    const config = {};
    for (const [chave, padrao] of Object.entries(PADRAO)) {
      const valor = entrada[chave] === undefined ? padrao : entrada[chave];
      if (valor === null || typeof valor === 'boolean' || String(valor).trim() === '' || !Number.isFinite(Number(valor))) {
        throw new Error('Informe medidas numéricas e finitas para a etiqueta.');
      }
      config[chave] = Number(valor);
    }
    if (config.qr_mm < 20 || config.texto_pt < 6) throw new Error('Use QR de pelo menos 20 mm e texto de pelo menos 6 pt.');
    if (config.largura_mm < config.qr_mm + 42 || config.altura_mm < Math.max(config.qr_mm + 27, config.texto_pt * 0.352778 * 1.2 * 12 + 10)) {
      throw new Error('O conteúdo não cabe de forma legível. Aumente o tamanho da etiqueta.');
    }
    if (Math.abs(config.offset_x_mm) > 6 || Math.abs(config.offset_y_mm) > 9) throw new Error('A calibração ultrapassa a folha A4: X ±6 mm, Y ±9 mm.');
    return config;
  }

  function fitas(valor) {
    const resultado = { top: false, right: false, bottom: false, left: false };
    if (valor && typeof valor === 'object' && !Array.isArray(valor)) {
      if (Object.keys(valor).length !== 4 || !Object.keys(resultado).every(k => typeof valor[k] === 'boolean')) throw new Error('As fitas da peça estão inválidas.');
      return { top: valor.top, right: valor.right, bottom: valor.bottom, left: valor.left };
    }
    const modo = String(valor == null ? 'nenhuma' : valor).trim().toLowerCase();
    if (modo === 'todos') return { top: true, right: true, bottom: true, left: true };
    if (modo === 'nenhuma') return resultado;
    const chave = { frente: 'top', superior: 'top', direita: 'right', inferior: 'bottom', esquerda: 'left', top: 'top', right: 'right', bottom: 'bottom', left: 'left' }[modo];
    if (!chave) throw new Error('A indicação de fita da peça é desconhecida.');
    resultado[chave] = true;
    return resultado;
  }

  function urlPublica(item, configuracao) {
    if (typeof item.qr_token !== 'string' || !/^[0-9a-fA-F]{32}$/.test(item.qr_token)) throw new Error('A identidade QR da peça está inválida.');
    let base;
    try { base = new URL(configuracao.viewer_base_url); } catch (_) { throw new Error('Informe a URL HTTPS pública do visualizador.'); }
    if (base.protocol !== 'https:' || !base.hostname || base.username || base.password || base.search || base.hash || (base.pathname !== '/' && base.pathname !== '')) {
      throw new Error('Use a URL HTTPS pública do visualizador, sem credenciais ou dados de cliente.');
    }
    return base.origin + '/p/' + item.qr_token;
  }

  function qrSvg(url) {
    const qr = qrcode(0, 'M');
    qr.addData(url, 'Byte');
    qr.make();
    // Quatro módulos brancos de margem são parte do QR, inclusive na impressão.
    return qr.createSvgTag({ cellSize: 1, margin: 4, scalable: true, alt: 'QR público da peça' });
  }

  function linhasDados(item, bordas) {
    const medidas = item.corte_mm;
    if (!Array.isArray(medidas) || medidas.length !== 3 || !medidas.every(n => typeof n === 'number' && Number.isFinite(n) && n > 0)) {
      throw new Error('As dimensões de corte da peça estão inválidas.');
    }
    const numero = n => Number(n.toFixed(2)).toString().replace('.', ',');
    return [
      ['Cliente', item.cliente], ['Ambiente', item.ambiente], ['Móvel', item.modulo_nome],
      ['Peça', [item.codigo, item.nome].filter(Boolean).join(' · ')],
      ['Dimensão', medidas.map(numero).join(' × ') + ' mm'], ['Material', item.material],
      ['Fita', Object.keys(LADOS).filter(lado => bordas[lado]).map(lado => LADOS[lado]).join(', ') || 'Nenhuma']
    ];
  }

  function renderizarEtiqueta(item, entrada) {
    const config = validarConfiguracao(entrada);
    const url = urlPublica(item, entrada);
    // O catálogo já traz edge_banding; a forma antiga também é compreendida por lado.
    const bordas = fitas(item.edge_banding === undefined ? item.fita_borda : item.edge_banding);
    const linhas = linhasDados(item, bordas);
    const larguraDados = config.largura_mm - config.qr_mm - 10;
    const caracteresPorLinha = Math.max(1, Math.floor(larguraDados / (config.texto_pt * 0.352778 * 0.56)));
    const linhasDisponiveis = Math.floor((config.altura_mm - 12) / (config.texto_pt * 0.352778 * 1.2));
    const linhasUsadas = linhas.reduce((n, [rotulo, valor]) => n + Math.max(1, Math.ceil((rotulo.length + 2 + String(valor || '').length) / caracteresPorLinha)), 0);
    if (linhasUsadas > linhasDisponiveis) throw new Error('O conteúdo não cabe de forma legível. Aumente a etiqueta ou revise os textos.');
    const dados = linhas.map(([rotulo, valor]) => `<div><dt>${rotulo}</dt><dd>${escapar(valor)}</dd></div>`).join('');
    const arestas = Object.keys(LADOS).map(lado => `<span class="borda ${bordas[lado] ? 'fitada' : ''}" data-orientacao="${lado}">${LADOS[lado]}</span>`).join('');
    const coordenadas = { top: 'x1="12" y1="12" x2="88" y2="12"', right: 'x1="88" y1="12" x2="88" y2="48"', bottom: 'x1="12" y1="48" x2="88" y2="48"', left: 'x1="12" y1="12" x2="12" y2="48"' };
    const desenho = Object.keys(LADOS).map(lado => `<line data-lado="${lado}" class="${bordas[lado] ? 'com-fita' : 'sem-fita'}" ${coordenadas[lado]}/>`).join('');
    const rastreio = [entrada.revision_id, entrada.gerado_em].filter(Boolean).join(' · ');
    if (rastreio.length > Math.floor((config.largura_mm - 7) / (6 * 0.352778 * 0.56))) {
      throw new Error('A rastreabilidade não cabe de forma legível. Aumente a etiqueta ou revise a identificação da revisão.');
    }
    return `<article class="etiqueta" data-medir aria-label="Etiqueta ${escapar(item.codigo || item.nome)}">${arestas}` +
      `<dl class="dados" data-medir>${dados}</dl><div class="qr">${qrSvg(url)}<p>Escaneie para ver o móvel</p></div>` +
      `<div class="desenho"><svg viewBox="0 0 100 60" role="img" aria-label="Desenho das bordas com fita">${desenho}<text x="50" y="7">↑ Superior</text><text x="50" y="58">Inferior</text></svg></div>` +
      `<footer data-medir>${escapar(rastreio)}</footer></article>`;
  }

  const ESTILO_ETIQUETA = `
*{box-sizing:border-box}html,body{margin:0;padding:0;background:white;color:#111;font-family:Arial,sans-serif}
.folha{position:relative;break-after:page;page-break-after:always}.folha:last-child{break-after:auto;page-break-after:auto}
.etiqueta{position:relative;width:var(--largura);height:var(--altura);font-size:var(--texto);line-height:1.2;background:white;break-inside:avoid;page-break-inside:avoid}
.dados{position:absolute;left:4mm;right:calc(var(--qr) + 6mm);top:4mm;bottom:8mm;margin:0;overflow-wrap:anywhere}
.dados>div{margin-bottom:.6mm}.dados dt,.dados dd{display:inline;margin:0}.dados dt{font-weight:bold}.dados dt:after{content:': '}
.qr{position:absolute;top:3mm;right:3mm;width:var(--qr)}.qr svg{display:block;width:var(--qr);height:var(--qr)}
.qr p{margin:.5mm 0 0;font-size:6pt;text-align:center;line-height:1.05}
.desenho{position:absolute;right:3mm;bottom:6mm;width:var(--qr);height:13mm}.desenho svg{width:100%;height:100%}
.desenho line{stroke:#111;stroke-width:1}.desenho .com-fita{stroke:#c21d23;stroke-width:3}.desenho text{font-size:7px;text-anchor:middle;fill:#111}
.borda{position:absolute;font-size:6pt;line-height:1;white-space:nowrap}.borda.fitada{color:#a40000;font-weight:bold;text-decoration:underline}
[data-orientacao=top]{left:4mm;top:1mm}[data-orientacao=bottom]{left:4mm;bottom:1mm}
[data-orientacao=left]{left:.4mm;top:50%;writing-mode:vertical-rl;transform:rotate(180deg)}[data-orientacao=right]{right:.4mm;top:50%;writing-mode:vertical-rl}
.etiqueta footer{position:absolute;bottom:3mm;left:4mm;right:3mm;height:2.5mm;font-size:6pt;line-height:1.1;overflow-wrap:anywhere}
.calibracao{display:flex;align-items:center;justify-content:center;border:.2mm solid #111;font-size:10pt;text-align:center}
@media screen{body{background:#e7e8e9}.folha{margin:8mm auto;background:white;box-shadow:0 1mm 3mm #0002}.etiqueta{outline:1px dashed #bbb}}
@media print{html,body{background:white}.folha{margin:0;box-shadow:none}.etiqueta{outline:0}body{-webkit-print-color-adjust:exact;print-color-adjust:exact}}`;

  function montarDocumento(itens, entrada, modo = 'termica', calibracao = false) {
    const config = validarConfiguracao(entrada);
    if (!['termica', 'a4'].includes(modo)) throw new Error('Modo de impressão inválido.');
    if (!Array.isArray(itens) || (!itens.length && !calibracao)) throw new Error('Não há peças para imprimir.');
    const tamanho = modo === 'a4' ? { ...config, largura_mm: 99, altura_mm: 55.8 } : config;
    validarConfiguracao(tamanho);
    const porPagina = modo === 'a4' ? 10 : 1;
    const paginas = [];
    const lote = calibracao ? Array.from({ length: 10 }, (_, i) => i + 1) : itens;
    for (let i = 0; i < lote.length; i += porPagina) paginas.push(lote.slice(i, i + porPagina));
    const html = paginas.map(pagina => `<section class="folha ${modo}"><div class="grade">${pagina.map(peca => calibracao ?
      `<article class="etiqueta calibracao">A4350 · ${peca}<br>99 × 55,8 mm<br>Imprimir em escala 100%</article>` :
      renderizarEtiqueta(peca, { ...entrada, ...tamanho })).join('')}</div></section>`).join('');
    const variaveis = `:root{--largura:${tamanho.largura_mm}mm;--altura:${tamanho.altura_mm}mm;--qr:${config.qr_mm}mm;--texto:${config.texto_pt}pt}`;
    const papel = modo === 'a4' ? `@page{size: 210mm 297mm;margin:0}
.folha.a4{width:210mm;height:297mm;padding:9mm 6mm}
.a4 .grade{display:grid;grid-template-columns: repeat(2, 99mm);grid-template-rows: repeat(5, 55.8mm);gap:0;transform:translate(${config.offset_x_mm}mm, ${config.offset_y_mm}mm)}` :
      `@page{size: ${config.largura_mm}mm ${config.altura_mm}mm;margin:0}.folha.termica{width:${config.largura_mm}mm;height:${config.altura_mm}mm}`;
    return { html, css: ESTILO_ETIQUETA + variaveis + papel, paginas };
  }

  function verificarLegibilidade(documento) {
    for (const bloco of documento.querySelectorAll('[data-medir]')) {
      if (bloco.scrollHeight > bloco.clientHeight || bloco.scrollWidth > bloco.clientWidth) {
        throw new Error('O conteúdo não cabe de forma legível. Aumente a etiqueta ou revise os textos.');
      }
    }
  }

  function imprimirPreparado(documento, janela) {
    verificarLegibilidade(documento);
    janela.focus();
    janela.print();
  }

  function prepararFrame(frame, dados, imprimir, mensagem) {
    frame.onload = function () {
      const executar = () => {
        try {
          verificarLegibilidade(frame.contentDocument);
          if (imprimir) imprimirPreparado(frame.contentDocument, frame.contentWindow);
        } catch (erro) { mensagem(erro.message); }
      };
      const fontes = frame.contentDocument.fonts;
      if (fontes && fontes.ready) fontes.ready.then(executar); else executar();
    };
    frame.srcdoc = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Etiquetas Nex Mob</title><style>${dados.css}</style></head><body>${dados.html}</body></html>`;
  }

  function conectarInterface(documento, janela, renderizar) {
    const campo = id => documento.getElementById(id);
    const mensagem = texto => { campo('mensagem-etiquetas').textContent = texto; };
    const botoes = ['botao-previa', 'botao-imprimir', 'botao-pdf'];
    let itens = [], entrada = {}, pronto = false, credencialDisponivel = false;
    const habilitar = valor => { pronto = valor; botoes.forEach(id => { campo(id).disabled = !valor; }); };
    const valores = () => validarConfiguracao(Object.fromEntries(Object.keys(PADRAO).map(chave => [chave, campo(chave).value])));
    const desenhar = renderizar || ((dados, _modo, imprimir) => prepararFrame(campo('previa-etiquetas'), dados, imprimir, mensagem));
    function acao(modo, imprimir, calibracao = false) {
      try {
        if (!pronto && !calibracao) throw new Error('Sincronize o projeto antes de gerar etiquetas.');
        const configuracao = valores();
        const dados = montarDocumento(itens, { ...entrada, ...configuracao }, modo, calibracao);
        if (calibracao) {
          desenhar(dados, modo, imprimir);
          mensagem('Imprima a calibração A4350 em escala 100%, sem ajustar à página.');
        } else {
          if (!janela.sketchup) throw new Error('Abra as etiquetas no SketchUp.');
          janela.sketchup.solicitar_previa(JSON.stringify({ configuracao, modo, imprimir }));
          mensagem('Conferindo o projeto sincronizado…');
        }
      } catch (erro) { mensagem(erro.message); }
    }
    janela.receberDadosEtiquetas = dados => {
      try {
        entrada = dados.configuracao || {};
        const config = validarConfiguracao(entrada);
        itens = dados.itens || [];
        const conexao = dados.conexao || {};
        if (conexao.sync_url !== undefined) campo('sync_url').value = conexao.sync_url;
        if (conexao.viewer_base_url !== undefined) campo('viewer_base_url').value = conexao.viewer_base_url;
        credencialDisponivel = conexao.credencial_configurada === true;
        campo('estado-credencial').textContent = credencialDisponivel ? 'Credencial disponível nesta sessão.' : 'Informe a credencial para esta sessão.';
        Object.keys(PADRAO).forEach(chave => { campo(chave).value = config[chave]; });
        campo('contagem-etiquetas').textContent = `${itens.length} peça${itens.length === 1 ? '' : 's'} no projeto`;
        habilitar(itens.length > 0 && dados.sincronizado === true);
        mensagem(dados.mensagem || (pronto ? 'Projeto sincronizado. Etiquetas prontas para prévia.' : 'Sincronize o projeto antes de gerar etiquetas.'));
      } catch (erro) { habilitar(false); mensagem(erro.message); }
    };
    const limparPrevia = () => { campo('previa-etiquetas').onload = null; campo('previa-etiquetas').srcdoc = ''; };
    janela.erroEtiquetas = texto => { habilitar(false); limparPrevia(); mensagem(String(texto)); };
    const estados = {
      sincronizando: 'Sincronizando a revisão do projeto…', sucesso: 'Revisão sincronizada com sucesso.',
      rede: 'Falha de rede. Confira a conexão e sincronize novamente.',
      credencial_recusada: 'Credencial recusada (401). Informe uma credencial válida.',
      validacao: 'Revisão recusada. Verifique os dados e a permissão do projeto.',
      configuracao: 'Configure URLs HTTPS e uma credencial válidas.',
      servidor: 'Serviço indisponível. Tente sincronizar novamente.'
    };
    janela.estadoSincronizacao = dados => {
      habilitar(false);
      limparPrevia();
      campo('botao-sincronizar').disabled = dados.status === 'sincronizando';
      if (typeof dados.credencial_configurada === 'boolean') {
        credencialDisponivel = dados.credencial_configurada;
        campo('estado-credencial').textContent = credencialDisponivel ? 'Credencial disponível nesta sessão.' : 'Informe a credencial para esta sessão.';
      }
      if (dados.status === 'credencial_recusada') {
        credencialDisponivel = false;
        campo('estado-credencial').textContent = 'Informe uma nova credencial.';
      }
      mensagem(estados[dados.status] || estados.servidor);
    };
    janela.prepararSaidaEtiquetas = dados => {
      try {
        const documentoSaida = montarDocumento(dados.itens, dados.configuracao, dados.modo);
        itens = dados.itens;
        entrada = dados.configuracao;
        desenhar(documentoSaida, dados.modo, dados.imprimir === true);
        habilitar(true);
        mensagem(dados.imprimir ? 'Use escala 100%, sem ajustar à página. Para PDF, escolha Salvar como PDF no diálogo.' : 'Prévia pronta. Confira todos os dados antes de imprimir.');
      } catch (erro) { janela.erroEtiquetas(erro.message); }
    };
    campo('formulario-sincronizacao').addEventListener('submit', evento => {
      evento.preventDefault();
      try {
        const sync_url = campo('sync_url').value.trim();
        const viewer_base_url = campo('viewer_base_url').value.trim();
        let url;
        try { url = new URL(sync_url); } catch (_) { throw new Error(estados.configuracao); }
        if (url.protocol !== 'https:' || !url.hostname || url.username || url.password || url.search || url.hash || url.pathname !== '/v1/revisions') throw new Error(estados.configuracao);
        urlPublica({ qr_token: '0'.repeat(32) }, { viewer_base_url });
        const token = campo('credencial').value;
        if (!token && !credencialDisponivel) throw new Error('Informe a credencial de sincronização.');
        if (token && !/^[^\s\x00-\x1f\x7f]+$/.test(token)) throw new Error('A credencial não pode conter espaços ou caracteres de controle.');
        if (!janela.sketchup) throw new Error('Abra as etiquetas no SketchUp.');
        const configuracao = valores();
        campo('credencial').value = '';
        janela.estadoSincronizacao({ status: 'sincronizando' });
        try {
          janela.sketchup.sincronizar_etiquetas(JSON.stringify({ sync_url, viewer_base_url, token, configuracao }));
        } catch (_) {
          janela.estadoSincronizacao({ status: 'configuracao' });
        }
      } catch (erro) { mensagem(erro.message); }
    });
    campo('botao-atualizar-lote').addEventListener('click', () => {
      habilitar(false);
      limparPrevia();
      if (janela.sketchup) janela.sketchup.atualizar_lote();
    });
    campo('formulario-etiquetas').addEventListener('submit', evento => {
      evento.preventDefault();
      try {
        const config = valores();
        habilitar(false);
        limparPrevia();
        if (janela.sketchup) {
          janela.sketchup.salvar_configuracao_etiquetas(JSON.stringify(config));
          janela.sketchup.solicitar_previa(JSON.stringify(config));
        } else mensagem('Abra as etiquetas no SketchUp para salvar a configuração.');
      } catch (erro) { mensagem(erro.message); }
    });
    campo('botao-previa').addEventListener('click', () => acao(campo('modo_saida').value, false));
    campo('botao-imprimir').addEventListener('click', () => acao(campo('modo_saida').value, true));
    campo('botao-pdf').addEventListener('click', () => acao('a4', true));
    campo('botao-calibracao').addEventListener('click', () => acao('a4', true, true));
    ['sync_url', 'viewer_base_url', 'credencial'].forEach(id => campo(id).addEventListener('input', () => {
      habilitar(false);
      limparPrevia();
      mensagem('Configuração alterada. Sincronize novamente para gerar etiquetas.');
    }));
    habilitar(false);
    Object.keys(PADRAO).forEach(chave => { campo(chave).value = PADRAO[chave]; });
    if (janela.sketchup && janela.sketchup.etiquetas_prontas) janela.sketchup.etiquetas_prontas();
    return { acao };
  }

  function iniciarDocumento(documento, janela) {
    const estado = documento.getElementById('estado-impressao');
    try {
      const payload = JSON.parse(documento.getElementById('dados-impressao').textContent);
      const dados = montarDocumento(payload.itens, payload.configuracao, payload.modo);
      const estilo = documento.createElement('style');
      estilo.textContent = dados.css;
      documento.head.appendChild(estilo);
      documento.getElementById('documento-etiquetas').innerHTML = dados.html;
      const concluir = () => {
        try {
          verificarLegibilidade(documento);
          estado.hidden = true;
          const botao = documento.createElement('button');
          botao.textContent = payload.modo === 'a4' ? 'Imprimir / Salvar PDF · escala 100%' : 'Imprimir etiquetas · escala 100%';
          botao.className = 'acao-impressao';
          estilo.textContent += '@media print{.acao-impressao{display:none}}';
          botao.addEventListener('click', () => {
            try { imprimirPreparado(documento, janela); } catch (erro) { estado.hidden = false; estado.textContent = erro.message; }
          });
          documento.body.insertBefore(botao, documento.body.firstChild);
        } catch (erro) { estado.textContent = erro.message; }
      };
      if (documento.fonts && documento.fonts.ready) documento.fonts.ready.then(concluir); else concluir();
    } catch (erro) { estado.textContent = erro.message; }
  }

  return { validarConfiguracao, fitas, urlPublica, qrSvg, renderizarEtiqueta, montarDocumento,
    verificarLegibilidade, imprimirPreparado, conectarInterface, iniciarDocumento };
});

if (typeof document !== 'undefined' && document.getElementById('formulario-etiquetas')) {
  window.Etiquetas.conectarInterface(document, window);
}
