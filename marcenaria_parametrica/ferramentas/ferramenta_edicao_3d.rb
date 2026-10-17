require_relative 'ferramenta_selecao_vao'
require_relative '../dominio/edicao_divisoes'
require_relative '../visualizacao/representacao_edicao'

module MarcenariaParametrica
  class FerramentaEdicao3d < FerramentaSelecaoVao
    def initialize(modelo, grupo, ao_selecionar, ao_executar)
      super(modelo, grupo, [], ao_selecionar)
      @ao_executar = ao_executar
      atualizar_vaos(ModuloParametrico.vaos(grupo))
    end

    def atualizar_vaos(vaos)
      super
      @parametros = ModuloParametrico.parametros(@grupo)
      @divisoes = PlanoBalcaoInferior.ler_divisoes(@grupo)
      @pecas = EdicaoDivisoes.pecas(@parametros, @divisoes)
      @gavetas = PlanoGavetas.representacoes(@parametros, @divisoes, PlanoGavetas.ler(@grupo))
      @selecao = nil
      cancelar_movimento
    end

    def activate
      Sketchup.set_status_text('Nex Mob: clique no vão, na peça ou na gaveta. Arraste a alça para mover. Esc cancela.')
      Sketchup.set_status_text('Posição (mm)', SB_VCB_LABEL)
    end

    def enableVCB?
      true
    end

    def selecionar_peca(identificador)
      peca = @pecas.find { |item| item[:id] == identificador }
      selecionar(peca) if peca
    end

    def selecionar_gaveta(identificador)
      gaveta = @gavetas.find { |item| item[:id] == identificador }
      selecionar(gaveta) if gaveta
    end

    def onMouseMove(_sinalizadores, x, y, visualizacao)
      return unless disponivel?
      if @movimento
        atualizar_movimento(x, y, visualizacao)
      else
        @sob_cursor = identificar_alvo(visualizacao, x, y)
        @vao_destacado = @sob_cursor && !@sob_cursor[:tipo] ? @sob_cursor : nil
        visualizacao.tooltip = @sob_cursor ? (@sob_cursor[:nome] || 'Selecionar vão') : ''
      end
      visualizacao.invalidate
    end

    def onLButtonDown(_sinalizadores, x, y, visualizacao)
      return unless disponivel?
      if @movimento
        atualizar_movimento(x, y, visualizacao)
        concluir_movimento
        return
      end
      controle = RepresentacaoEdicao.controles(visualizacao, @selecao, transformacao).find do |item|
        RepresentacaoEdicao.dentro?(item[:retangulo], x, y)
      end
      if controle
        executar_acao(controle[:acao])
      elsif (alca = RepresentacaoEdicao.alcas_vao(visualizacao, @selecao, @pecas, transformacao).find do |borda|
        RepresentacaoEdicao.dentro?(borda[:retangulo], x, y)
      end)
        selecionar(alca[:peca])
        iniciar_movimento
        @arrastando = true
        @origem_arrasto = coordenada(visualizacao, x, y)
      elsif sobre_alca?(visualizacao, x, y)
        iniciar_movimento
        @arrastando = true
        @origem_arrasto = coordenada(visualizacao, x, y)
      else
        alvo = identificar_alvo(visualizacao, x, y)
        selecionar(alvo) if alvo
      end
      visualizacao.invalidate
    rescue StandardError => erro
      @ao_executar.call(:erro, erro.message)
    end

    def onLButtonUp(_sinalizadores, x, y, visualizacao)
      return unless @movimento && @arrastando
      atualizar_movimento(x, y, visualizacao)
      concluir_movimento
    end

    def onUserText(texto, visualizacao)
      return unless @selecao && @selecao[:tipo]
      # A barra aceita milímetros; unidades explícitas usam o analisador do SketchUp.
      texto = texto.strip
      posicao = texto.match?(/\A[+-]?\d+(?:[.,]\d+)?\z/) ? Float(texto.tr(',', '.')) : texto.to_l.to_mm
      if @selecao[:tipo] == 'gaveta'
        @ao_executar.call(:gaveta, { 'acao' => 'mover', 'id' => @selecao[:id], 'posicao_mm' => posicao })
      else
        @ao_executar.call(:mover, { 'id' => @selecao[:id], 'posicao_mm' => posicao })
      end
      cancelar_movimento
      visualizacao.invalidate
    rescue StandardError => erro
      @ao_executar.call(:erro, erro.message)
    end

    def executar_acao(acao)
      return unless @selecao && disponivel?
      if acao.to_sym == :mover
        iniciar_movimento
      elsif @selecao[:tipo] == 'gaveta'
        @ao_executar.call(:gaveta, { 'acao' => acao.to_s, 'id' => @selecao[:id] })
      else
        @ao_executar.call(acao.to_sym, { 'id' => @selecao[:id] })
      end
      @modelo.active_view.invalidate
    end

    def getMenu(menu, *_argumentos)
      return unless @selecao
      acoes = if @selecao[:tipo] == 'gaveta'
                { 'Mover gaveta' => :mover, 'Duplicar gaveta no vão' => :duplicar, 'Excluir gaveta' => :excluir }
              elsif @selecao[:tipo]
                { 'Mover peça' => :mover, 'Duplicar no vão adjacente' => :duplicar, 'Excluir peça' => :excluir }
              else
                              { 'Adicionar prateleira' => :prateleira, 'Adicionar divisória' => :divisoria }
              end
      acoes.each { |titulo, acao| menu.add_item(titulo) { executar_acao(acao) } }
    end

    def draw(visualizacao)
      return unless disponivel?
      RepresentacaoVaos.desenhar(visualizacao, @vaos, transformacao, @vao_destacado, nil, rotulos: false)
      if @sob_cursor && @sob_cursor[:tipo] && @sob_cursor != @selecao && !@movimento &&
         RepresentacaoEdicao.frontal?(visualizacao, transformacao)
        RepresentacaoEdicao.contorno(visualizacao, @sob_cursor, transformacao, '#276f73', 65)
      end
      RepresentacaoEdicao.desenhar(visualizacao, @selecao, transformacao, @previa, @previa_valida)
      RepresentacaoEdicao.alcas_vao(visualizacao, @selecao, @pecas, transformacao).each do |borda|
        RepresentacaoEdicao.retangulo(visualizacao, borda[:retangulo], '#ffffff', RepresentacaoEdicao::COR)
      end
    end

    def onCancel(motivo, visualizacao)
      if @movimento
        cancelar_movimento
        activate
      else
        @selecao = nil
        @ao_executar.call(:limpar, nil)
        super
      end
      visualizacao.invalidate
    end

    def deactivate(visualizacao)
      cancelar_movimento
      super
    end

    private

    def disponivel?
      ModuloParametrico.editavel?(@grupo) && @grupo.model == Sketchup.active_model
    end

    def transformacao
      @modelo.edit_transform * @grupo.transformation
    end

    def selecionar(alvo)
      cancelar_movimento
      @selecao = alvo
      @vao_selecionado = alvo[:tipo] ? nil : alvo
      @ao_selecionar.call(alvo)
      Sketchup.set_status_text(alvo[:posicao_mm].round(1).to_s, SB_VCB_VALUE) if alvo[:tipo]
    end

    def ponto_local(visualizacao, x, y)
      return unless RepresentacaoEdicao.frontal?(visualizacao, transformacao)
      origem, direcao = visualizacao.pickray(x, y)
      inversa = transformacao.inverse
      origem = origem.transform(inversa)
      direcao = direcao.transform(inversa)
      return unless direcao.y > 0
      Geom.intersect_line_plane([origem, direcao], [Geom::Point3d.new, Geom::Vector3d.new(0, 1, 0)])
    end

    def identificar_alvo(visualizacao, x, y)
      ponto = ponto_local(visualizacao, x, y)
      return unless ponto
      encontro = @modelo.raytest(visualizacao.pickray(x, y), true)
      if encontro
        caminho = encontro[1]
        return unless caminho.include?(@grupo)
        chapa = caminho.find do |entidade|
          entidade.get_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'gaveta_origem') ||
          entidade.get_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'vao_origem')
        end
        if chapa
          identificador_gaveta = chapa.get_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'gaveta_origem')
          return @gavetas.find { |gaveta| gaveta[:id] == identificador_gaveta } if identificador_gaveta
          identificador = chapa.get_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'vao_origem')
          return @pecas.find { |peca| peca[:id] == identificador }
        end
      end
      # A faixa frontal da chapa tem prioridade sobre os vãos adjacentes.
      peca = self.class.localizar_vao(@pecas, ponto.x.to_mm, ponto.z.to_mm)
      peca || self.class.localizar_vao(@gavetas, ponto.x.to_mm, ponto.z.to_mm) ||
        self.class.localizar_vao(@vaos, ponto.x.to_mm, ponto.z.to_mm)
    end

    def sobre_alca?(visualizacao, x, y)
      return false unless @selecao && @selecao[:tipo]
      return false unless RepresentacaoEdicao.frontal?(visualizacao, transformacao)
      centro = RepresentacaoEdicao.centro(visualizacao, @selecao[:limites_mm], transformacao)
      (centro.x - x).abs <= 10 && (centro.y - y).abs <= 10
    end

    def iniciar_movimento
      return unless @selecao[:tipo]
      @movimento = true
      @posicao_inicial = @selecao[:posicao_mm]
      @posicao_proposta = @posicao_inicial
      @previa_valida = true
      Sketchup.set_status_text('Mova o cursor e clique para posicionar, ou digite a posição em mm. Esc cancela a prévia.')
    end

    def coordenada(visualizacao, x, y)
      ponto = ponto_local(visualizacao, x, y)
      return unless ponto
      %w[prateleira gaveta].include?(@selecao[:tipo]) ? ponto.z.to_mm : ponto.x.to_mm
    end

    def atualizar_movimento(x, y, visualizacao)
      valor = coordenada(visualizacao, x, y)
      return unless valor
      @posicao_proposta = (@origem_arrasto ? @posicao_inicial + valor - @origem_arrasto : valor).round(1)
      @previa = @selecao.dup
      @previa[:limites_mm] = @selecao[:limites_mm].dup
      indices = %w[prateleira gaveta].include?(@selecao[:tipo]) ? [2, 3] : [0, 1]
      indices.each { |indice| @previa[:limites_mm][indice] += @posicao_proposta - @posicao_inicial }
      @previa[:posicao_mm] = @posicao_proposta
      begin
        if @selecao[:tipo] == 'gaveta'
          PlanoGavetas.mover(@parametros, @divisoes, PlanoGavetas.ler(@grupo), @selecao[:id], @posicao_proposta)
        else
          EdicaoDivisoes.mover(@parametros, @divisoes, @selecao[:id], @posicao_proposta)
        end
        @previa_valida = true
        visualizacao.tooltip = "Posição #{@posicao_proposta} mm"
      rescue ArgumentError => erro
        @previa_valida = false
        visualizacao.tooltip = erro.message
      end
      Sketchup.set_status_text(@posicao_proposta.to_s, SB_VCB_VALUE)
    end

    def concluir_movimento
      if @previa_valida && (@posicao_proposta - @posicao_inicial).abs > 0.01
        if @selecao[:tipo] == 'gaveta'
          @ao_executar.call(:gaveta, { 'acao' => 'mover', 'id' => @selecao[:id], 'posicao_mm' => @posicao_proposta })
        else
          @ao_executar.call(:mover, { 'id' => @selecao[:id], 'posicao_mm' => @posicao_proposta })
        end
      elsif !@previa_valida
        if @selecao[:tipo] == 'gaveta'
          @ao_executar.call(:erro, 'Posição inválida: preserve as folgas da gaveta e não cruze outra caixa.')
        else
          folga = PlanoBalcaoInferior.normalizar(@parametros)['folga_minima_mm']
          @ao_executar.call(:erro, "Posição inválida: preserve pelo menos #{folga.round} mm livres em cada vão, inclusive nas divisões internas.")
        end
      end
      cancelar_movimento
      activate
      @modelo.active_view.invalidate
    end

    def cancelar_movimento
      @movimento = false
      @arrastando = false
      @origem_arrasto = nil
      @previa = nil
      @sob_cursor = nil
    end
  end
end
