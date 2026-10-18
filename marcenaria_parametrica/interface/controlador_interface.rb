module MarcenariaParametrica
  class ControladorInterface
    def initialize
      configuracao = ConfiguracaoConstrutiva.new
      @frentes = ControladorFrentes.new
      @projeto = ControladorProjeto.new
      @etiquetas = ControladorEtiquetas.new
      @edicao = ControladorEdicao.new(method(:abrir_modo_construtivo), @frentes.method(:abrir))
      @modo_construtivo = ControladorModoConstrutivo.new(configuracao, @edicao.method(:atualizar))
      @catalogo = ControladorCatalogo.new(configuracao, @edicao.method(:abrir), method(:abrir_modo_construtivo))
    end

    def abrir_catalogo
      @catalogo.abrir
    end

    def abrir_projeto
      @projeto.abrir
    end

    def abrir_etiquetas
      @etiquetas.abrir
    end

    def abrir_edicao
      @edicao.abrir
    end

    def abrir_modo_construtivo
      @modo_construtivo.abrir
    end

    def abrir_frentes
      @frentes.abrir
    end
  end
end
