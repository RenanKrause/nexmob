require_relative '../visualizacao/representacao_vaos'

module MarcenariaParametrica
  class FerramentaSelecaoVao
    def self.localizar_vao(vaos, posicao_x_mm, posicao_z_mm)
      vaos.find do |vao|
        esquerda, direita, inferior, superior = vao[:limites_mm]
        posicao_x_mm > esquerda && posicao_x_mm < direita &&
          posicao_z_mm > inferior && posicao_z_mm < superior
      end
    end

    def initialize(modelo, grupo, vaos, ao_selecionar)
      @modelo = modelo
      @grupo = grupo
      @vaos = vaos
      @ao_selecionar = ao_selecionar
      @vao_destacado = nil
      @vao_selecionado = nil
    end

    def atualizar_vaos(vaos)
      @vaos = vaos
      @vao_destacado = nil
      @vao_selecionado = nil
    end

    def activate
      Sketchup.set_status_text('Nex Mob: clique nos vãos para editar. A seleção permanece ativa. Esc para sair.')
    end

    def resume(visualizacao)
      activate
      visualizacao.invalidate
    end

    def deactivate(visualizacao)
      Sketchup.set_status_text('')
      visualizacao.invalidate
    end

    def onMouseMove(_sinalizadores, coordenada_x, coordenada_y, visualizacao)
      @vao_destacado = identificar(visualizacao, coordenada_x, coordenada_y)
      visualizacao.tooltip = @vao_destacado ? "Selecionar #{@vao_destacado[:id]}" : ''
      visualizacao.invalidate
    end

    def onLButtonDown(_sinalizadores, coordenada_x, coordenada_y, visualizacao)
      vao = identificar(visualizacao, coordenada_x, coordenada_y)
      return unless vao

      @vao_selecionado = vao
      @ao_selecionar.call(vao)
      visualizacao.invalidate
    rescue StandardError => erro
      UI.messagebox("Não foi possível selecionar o vão: #{erro.message}")
    end

    def draw(visualizacao)
      return unless @grupo.valid? && @grupo.model == Sketchup.active_model
      transformacao = @modelo.edit_transform * @grupo.transformation
      RepresentacaoVaos.desenhar(visualizacao, @vaos, transformacao, @vao_destacado, @vao_selecionado)
    end

    def onCancel(motivo, visualizacao)
      @vao_destacado = nil
      @vao_selecionado = nil
      visualizacao.invalidate
      @modelo.select_tool(nil) if motivo == 0
    end

    def getExtents
      limites = Geom::BoundingBox.new
      return limites unless @grupo.valid?

      transformacao = @modelo.edit_transform * @grupo.transformation
      @vaos.each { |vao| RepresentacaoVaos.cantos(vao, transformacao).each { |ponto| limites.add(ponto) } }
      limites
    end

    private

    def identificar(visualizacao, coordenada_x, coordenada_y)
      return nil unless @grupo.valid? && !@grupo.locked? && @grupo.model == Sketchup.active_model

      transformacao = @modelo.edit_transform * @grupo.transformation
      inversa = transformacao.inverse
      origem, direcao = visualizacao.pickray(coordenada_x, coordenada_y)
      origem_local = origem.transform(inversa)
      direcao_local = direcao.transform(inversa)
      return nil unless origem_local.y < 0 && direcao_local.y > 0

      ponto_local = Geom.intersect_line_plane(
        [origem_local, direcao_local],
        [Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 1, 0)]
      )
      return nil unless ponto_local

      self.class.localizar_vao(@vaos, ponto_local.x.to_mm, ponto_local.z.to_mm)
    rescue ArgumentError
      nil
    end
  end
end
