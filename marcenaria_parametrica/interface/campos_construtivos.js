window.camposConstrutivos = {
  espessura_mm: {
    titulo: 'Espessura das chapas', descricao: 'Laterais, base e divisórias estruturais.',
    minimo: 12, maximo: 30, destaque: 'estrutura'
  },
  folga_minima_mm: {
    titulo: 'Folga mínima dos vãos', descricao: 'Medida livre mínima entre as divisões do móvel.',
    minimo: 40, maximo: 200, destaque: 'vao'
  },
  espessura_fundo_mm: {
    titulo: 'Espessura do fundo', descricao: 'Painel traseiro que fecha a estrutura.',
    minimo: 3, maximo: 12, destaque: 'fundo'
  },
  largura_sarrafo_mm: {
    titulo: 'Profundidade dos sarrafos', descricao: 'Medida dos sarrafos frontal e traseiro.',
    minimo: 50, maximo: 150, destaque: 'sarrafos'
  },
  espessura_gaveta_mm: {
    titulo: 'Espessura das peças', descricao: 'Laterais, contra frente e posterior da gaveta.',
    minimo: 12, maximo: 25, destaque: 'gaveta'
  },
  espessura_fundo_gaveta_mm: {
    titulo: 'Espessura do fundo', descricao: 'Fundo encaixado entre as peças da caixa.',
    minimo: 3, maximo: 12, destaque: 'gaveta'
  },
  folga_lateral_gaveta_mm: {
    titulo: 'Folga lateral', descricao: 'Folga de cada lado entre a caixa e o vão.',
    minimo: 5, maximo: 25, destaque: 'gaveta'
  },
  folga_frontal_gaveta_mm: {
    titulo: 'Folga frontal', descricao: 'Distância entre a frente da caixa e o móvel.',
    minimo: 0, maximo: 30, destaque: 'gaveta'
  },
  folga_traseira_gaveta_mm: {
    titulo: 'Folga traseira', descricao: 'Distância entre a caixa e o fundo do móvel.',
    minimo: 0, maximo: 40, destaque: 'gaveta'
  },
  folga_vertical_gaveta_mm: {
    titulo: 'Folga entre gavetas', descricao: 'Espaço vertical entre duas caixas empilhadas no mesmo vão.',
    minimo: 1, maximo: 20, destaque: 'gaveta'
  },
  folga_base_gaveta_mm: {
    titulo: 'Folga da base', descricao: 'Distância da caixa até a base ou prateleira abaixo.',
    minimo: 0, maximo: 30, destaque: 'gaveta'
  },
  folga_sarrafo_gaveta_mm: {
    titulo: 'Folga do sarrafo', descricao: 'Distância da caixa até o sarrafo superior ou prateleira acima.',
    minimo: 0, maximo: 30, destaque: 'gaveta'
  },
  espessura_porta_mm: {
    titulo: 'Espessura das portas', descricao: 'Espessura padrão das portas criadas no modal de frentes.',
    minimo: 12, maximo: 30, destaque: 'porta'
  },
  folga_porta_mm: {
    titulo: 'Folga das portas', descricao: 'Folga nas bordas externas e entre portas lado a lado.',
    minimo: 0, maximo: 10, destaque: 'porta'
  },
  recuo_porta_mm: {
    titulo: 'Recuo das portas', descricao: 'Avanço ou recuo da porta em relação à frente do módulo.',
    minimo: 0, maximo: 30, destaque: 'porta'
  },
  largura_referencia_porta_mm: {
    titulo: 'Largura de referência', descricao: 'Define a sugestão automática da quantidade de portas por vão.',
    minimo: 250, maximo: 800, destaque: 'porta'
  },
  espessura_frente_gaveta_mm: {
    titulo: 'Espessura das frentes', descricao: 'Espessura padrão das frentes externas de gaveta.',
    minimo: 12, maximo: 30, destaque: 'frente'
  },
  folga_frente_gaveta_mm: {
    titulo: 'Folga das frentes', descricao: 'Folga nas bordas da frente e entre frentes de gaveta.',
    minimo: 0, maximo: 10, destaque: 'frente'
  },
  recuo_frente_gaveta_mm: {
    titulo: 'Recuo das frentes', descricao: 'Avanço ou recuo da frente em relação à caixa da gaveta.',
    minimo: 0, maximo: 30, destaque: 'frente'
  }
};

window.familiasConstrutivas = {
  inferiores: {
    titulo: 'Balcões inferiores', subtitulo: 'Perfil de móveis inferiores.',
    descricao: 'Base entre as laterais, fundo e sarrafos superiores.'
  },
  superiores: {
    titulo: 'Módulos superiores', subtitulo: 'Perfil de móveis aéreos.',
    descricao: 'Estrutura fechada para módulos posicionados acima da bancada.'
  },
  armarios: {
    titulo: 'Armários e guarda-roupas', subtitulo: 'Perfil de móveis altos.',
    descricao: 'Estrutura vertical para armários e guarda-roupas.'
  }
};

window.secoesConstrutivas = {
  inferiores: [
    { id: 'estrutura', titulo: 'Estrutura do móvel', descricao: 'Espessuras que definem a caixa e os vãos.', campos: ['espessura_mm', 'folga_minima_mm'] },
    { id: 'fundo', titulo: 'Fundo', descricao: 'Configuração do painel traseiro.', campos: ['espessura_fundo_mm'] },
    { id: 'sarrafos', titulo: 'Sarrafos dos inferiores', descricao: 'Elementos superiores frontal e traseiro.', campos: ['largura_sarrafo_mm'] },
    { id: 'gavetas', titulo: 'Caixa da gaveta', descricao: 'Laterais, fundo e folgas da caixa interna.', campos: ['espessura_gaveta_mm', 'espessura_fundo_gaveta_mm', 'folga_lateral_gaveta_mm', 'folga_frontal_gaveta_mm', 'folga_traseira_gaveta_mm', 'folga_base_gaveta_mm', 'folga_sarrafo_gaveta_mm', 'folga_vertical_gaveta_mm'] },
    { id: 'portas', titulo: 'Portas', descricao: 'Padrões de avanço, folga e sugestão automática das portas.', campos: ['espessura_porta_mm', 'folga_porta_mm', 'recuo_porta_mm', 'largura_referencia_porta_mm'] },
    { id: 'frentes-gavetas', titulo: 'Frentes de gaveta', descricao: 'Padrões das frentes vinculadas automaticamente às caixas.', campos: ['espessura_frente_gaveta_mm', 'folga_frente_gaveta_mm', 'recuo_frente_gaveta_mm'] }
  ],
  superiores: [
    { id: 'estrutura', titulo: 'Estrutura do móvel', descricao: 'Espessuras que definem a caixa e os vãos.', campos: ['espessura_mm', 'folga_minima_mm'] },
    { id: 'fundo', titulo: 'Fundo', descricao: 'Configuração do painel traseiro.', campos: ['espessura_fundo_mm'] }
  ],
  armarios: [
    { id: 'estrutura', titulo: 'Estrutura do móvel', descricao: 'Espessuras que definem a caixa e os vãos.', campos: ['espessura_mm', 'folga_minima_mm'] },
    { id: 'fundo', titulo: 'Fundo', descricao: 'Configuração do painel traseiro.', campos: ['espessura_fundo_mm'] }
  ]
};
