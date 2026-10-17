require_relative 'representacao_vaos'

module MarcenariaParametrica
  module RepresentacaoEdicao
    COR = '#b8433f'.freeze

    def self.frontal?(visualizacao, transformacao)
      visualizacao.camera.eye.transform(transformacao.inverse).y < 0
    end

    def self.centro(visualizacao, limites, transformacao)
      esquerda, direita, inferior, superior = limites
      ponto(visualizacao, (esquerda + direita) / 2, (inferior + superior) / 2, transformacao)
    end

    def self.ponto(visualizacao, x, z, transformacao)
      visualizacao.screen_coords(Geom::Point3d.new(x.mm, (-3).mm, z.mm).transform(transformacao))
    end

    def self.controles(visualizacao, selecao, transformacao)
      return [] unless selecao && frontal?(visualizacao, transformacao)

      centro = centro(visualizacao, selecao[:limites_mm], transformacao)
      acoes = if selecao[:tipo] == 'gaveta'
                [[:mover, 'Mover', 66], [:duplicar, 'Duplicar', 78], [:excluir, 'Excluir', 66]]
              elsif selecao[:tipo]
                [[:mover, 'Mover', 66], [:duplicar, 'Duplicar', 78], [:excluir, 'Excluir', 66]]
              else
                [[:prateleira, '+ Prateleira', 104], [:divisoria, '+ Divisória', 104]]
              end
      largura = acoes.sum { |acao| acao[2] + 4 } - 4
      x = [[centro.x - largura / 2, 8].max, [visualizacao.vpwidth - largura - 8, 8].max].min
      y = [[centro.y - 52, 8].max, [visualizacao.vpheight - 38, 8].max].min
      acoes.map do |acao, texto, tamanho|
        controle = { acao: acao, texto: texto, retangulo: [x, y, x + tamanho, y + 29] }
        x += tamanho + 4
        controle
      end
    end

    def self.dentro?(retangulo, x, y)
      esquerda, superior, direita, inferior = retangulo
      x >= esquerda && x <= direita && y >= superior && y <= inferior
    end

    def self.alcas_vao(visualizacao, selecao, pecas, transformacao)
      return [] unless selecao && !selecao[:tipo] && frontal?(visualizacao, transformacao)
      EdicaoDivisoes.bordas(selecao, pecas).map do |borda|
        x, z = borda[:posicao_mm]
        centro = ponto(visualizacao, x, z, transformacao)
        borda.merge(retangulo: [centro.x - 6, centro.y - 6, centro.x + 6, centro.y + 6])
      end
    end

    def self.desenhar(visualizacao, selecao, transformacao, previa = nil, valida = true)
      return unless selecao && frontal?(visualizacao, transformacao)

      contorno(visualizacao, selecao, transformacao, COR, selecao[:tipo] ? 100 : 45)
      alvo = previa || selecao
      if previa
        contorno(visualizacao, previa, transformacao, valida ? '#276f73' : '#c22727', 100)
      end
      if alvo[:tipo]
        alca = centro(visualizacao, alvo[:limites_mm], transformacao)
        retangulo(visualizacao, [alca.x - 6, alca.y - 6, alca.x + 6, alca.y + 6], '#ffffff', COR)
        cotas(visualizacao, alvo, transformacao)
      else
        esquerda, direita, inferior, superior = alvo[:limites_mm]
        centro = centro(visualizacao, alvo[:limites_mm], transformacao)
        legenda(visualizacao, centro.x, centro.y + 18, "#{(direita - esquerda).round} × #{(superior - inferior).round} mm", COR)
      end
      return if previa

      controles(visualizacao, selecao, transformacao).each do |controle|
        cor = controle[:acao] == :excluir ? COR : '#276f73'
        retangulo(visualizacao, controle[:retangulo], '#ffffff', cor)
        x, y = controle[:retangulo]
        visualizacao.draw_text(Geom::Point3d.new(x + 8, y + 5, 0), controle[:texto], size: 10, bold: true, color: cor)
      end
    end

    def self.contorno(visualizacao, selecao, transformacao, cor, opacidade)
      pontos = RepresentacaoVaos.cantos(selecao, transformacao)
      preenchimento = Sketchup::Color.new(cor)
      preenchimento.alpha = opacidade
      visualizacao.drawing_color = preenchimento
      visualizacao.draw(GL_QUADS, pontos)
      visualizacao.drawing_color = cor
      visualizacao.line_width = 3
      visualizacao.line_stipple = ''
      visualizacao.draw(GL_LINE_LOOP, pontos)
    end

    def self.cotas(visualizacao, peca, transformacao)
      esquerda, direita, inferior, superior = peca[:limites_pai_mm]
      limites = peca[:limites_mm]
      if %w[prateleira gaveta].include?(peca[:tipo])
        segmentos = [[esquerda - 28, inferior, esquerda - 28, limites[2], limites[2] - inferior],
                     [esquerda - 28, limites[3], esquerda - 28, superior, superior - limites[3]]]
      else
        segmentos = [[esquerda, inferior - 28, limites[0], inferior - 28, limites[0] - esquerda],
                     [limites[1], inferior - 28, direita, inferior - 28, direita - limites[1]]]
      end
      segmentos.each do |x1, z1, x2, z2, medida|
        primeiro = ponto(visualizacao, x1, z1, transformacao)
        segundo = ponto(visualizacao, x2, z2, transformacao)
        visualizacao.drawing_color = '#276f73'
        visualizacao.line_width = 1
        visualizacao.draw2d(GL_LINES, [primeiro, segundo])
        [primeiro, segundo].each do |extremo|
          deslocamento = %w[prateleira gaveta].include?(peca[:tipo]) ? [5, 0] : [0, 5]
          visualizacao.draw2d(GL_LINES, [Geom::Point3d.new(extremo.x - deslocamento[0], extremo.y - deslocamento[1], 0),
                                       Geom::Point3d.new(extremo.x + deslocamento[0], extremo.y + deslocamento[1], 0)])
        end
        legenda(visualizacao, (primeiro.x + segundo.x) / 2, (primeiro.y + segundo.y) / 2, "#{medida.round} mm", '#276f73')
      end
    end

    def self.legenda(visualizacao, x, y, texto, cor)
      largura = texto.length * 7 + 16
      retangulo(visualizacao, [x - largura / 2, y - 11, x + largura / 2, y + 12], '#ffffff', cor)
      visualizacao.draw_text(Geom::Point3d.new(x, y - 7, 0), texto, size: 10, bold: true, color: cor, align: TextAlignCenter)
    end

    def self.retangulo(visualizacao, limites, fundo, borda)
      esquerda, superior, direita, inferior = limites
      pontos = [[esquerda, superior, 0], [direita, superior, 0], [direita, inferior, 0], [esquerda, inferior, 0]]
      visualizacao.drawing_color = fundo
      visualizacao.draw2d(GL_QUADS, pontos)
      visualizacao.drawing_color = borda
      visualizacao.line_width = 1
      visualizacao.draw2d(GL_LINE_LOOP, pontos)
    end
  end
end
