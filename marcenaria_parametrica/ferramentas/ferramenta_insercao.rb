module MarcenariaParametrica
  class FerramentaInsercao
    def initialize(modelo, parametros, ao_inserir = nil)
      @modelo = modelo
      @parametros = parametros
      @ponto_inferencia = Sketchup::InputPoint.new
      @ao_inserir = ao_inserir
    end

    def activate
      Sketchup.set_status_text('Clique no ponto de inserção do balcão inferior. Esc para cancelar.')
    end

    def deactivate(visualizacao)
      Sketchup.set_status_text('')
      visualizacao.invalidate
    end

    def onMouseMove(_sinalizadores, coordenada_x, coordenada_y, visualizacao)
      @ponto_inferencia.pick(visualizacao, coordenada_x, coordenada_y)
      visualizacao.tooltip = @ponto_inferencia.tooltip if @ponto_inferencia.valid?
      visualizacao.invalidate
    end

    def draw(visualizacao)
      @ponto_inferencia.draw(visualizacao) if @ponto_inferencia.display?
    end

    def onCancel(motivo, visualizacao)
      @ponto_inferencia.clear
      visualizacao.invalidate
      @modelo.select_tool(nil) if motivo == 0
    end

    def onLButtonDown(_sinalizadores, coordenada_x, coordenada_y, visualizacao)
      @ponto_inferencia.pick(visualizacao, coordenada_x, coordenada_y)
      return unless @ponto_inferencia.valid?

      grupo = ConstrutorBalcaoInferior.new(@modelo).construir(@parametros, @ponto_inferencia.position)
      @modelo.selection.clear
      @modelo.selection.add(grupo)
      @modelo.select_tool(nil)
      @ao_inserir.call(grupo) if @ao_inserir
    rescue StandardError => erro
      UI.messagebox("Não foi possível inserir o módulo: #{erro.message}")
    end
  end
end
