module MarcenariaParametrica
  class ControladorCatalogo
    def initialize(configuracao, ao_inserir, abrir_modo)
      @configuracao = configuracao
      @ao_inserir = ao_inserir
      @abrir_modo = abrir_modo
    end

    def abrir
      return @dialogo.bring_to_front if @dialogo && @dialogo.visible?

      @dialogo = FabricaDialogos.criar('Catálogo', 'catalogo')
      @dialogo.add_action_callback('iniciar_insercao') { |_contexto, tipo| inserir(tipo) }
      @dialogo.add_action_callback('abrir_modo_construtivo') { |_contexto| @abrir_modo.call }
      @dialogo.set_on_closed { @dialogo = nil }
      @dialogo.show
    end

    private

    def inserir(tipo)
      raise ArgumentError, 'Este módulo ainda está em preparação.' unless tipo == ConstrutorBalcaoInferior::TIPO

      parametros = ConstrutorBalcaoInferior::PADRAO.merge(@configuracao.ler('inferiores'))
      Sketchup.active_model.select_tool(FerramentaInsercao.new(Sketchup.active_model, parametros, @ao_inserir))
      @dialogo.close
    rescue StandardError => erro
      UI.messagebox(erro.message)
    end
  end
end
