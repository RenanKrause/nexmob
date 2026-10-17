module MarcenariaParametrica
  module RepresentacaoVaos
    def self.desenhar(visualizacao, vaos, transformacao, destacado, selecionado, rotulos: true)
      origem_local = visualizacao.camera.eye.transform(transformacao.inverse)
      return unless origem_local.y < 0

      vaos.each_with_index do |vao, indice|
        ativo = selecionado && selecionado[:id] == vao[:id]
        sob_cursor = destacado && destacado[:id] == vao[:id]
        pontos = cantos(vao, transformacao)
        visualizacao.drawing_color = Sketchup::Color.new(ativo ? 230 : 39, ativo ? 159 : 111, ativo ? 48 : 115, ativo ? 85 : (sob_cursor ? 65 : 18))
        visualizacao.draw(GL_QUADS, pontos)
        visualizacao.drawing_color = ativo ? Sketchup::Color.new(181, 104, 13) : Sketchup::Color.new(39, 111, 115)
        visualizacao.line_width = ativo || sob_cursor ? 4 : 1
        visualizacao.line_stipple = ''
        visualizacao.draw(GL_LINE_LOOP, pontos)
        next unless rotulos
        proximo = visualizacao.screen_coords(pontos[0])
        distante = visualizacao.screen_coords(pontos[2])
        next if (proximo.x - distante.x).abs < 65 || (proximo.y - distante.y).abs < 45

        esquerda, direita, inferior, superior = vao[:limites_mm]
        centro = Geom::Point3d.new(((esquerda + direita) / 2).mm, (-2).mm, ((inferior + superior) / 2).mm).transform(transformacao)
        legenda = "Vão #{indice + 1}\n#{(direita - esquerda).round} × #{(superior - inferior).round} mm"
        visualizacao.draw_text(visualizacao.screen_coords(centro), legenda, color: 'black', size: 11, bold: true, align: TextAlignCenter)
      end
    end

    def self.cantos(vao, transformacao)
      esquerda, direita, inferior, superior = vao[:limites_mm]
      [[esquerda, inferior], [direita, inferior], [direita, superior], [esquerda, superior]].map do |x, z|
        Geom::Point3d.new(x.mm, (-2).mm, z.mm).transform(transformacao)
      end
    end
  end
end
