require 'json'

module MarcenariaParametrica
  class ControladorEdicao
    def initialize(abrir_modo, abrir_frentes = nil)
      @abrir_modo = abrir_modo
      @abrir_frentes = abrir_frentes
    end

    def abrir(grupo = Sketchup.active_model.selection.first)
      raise ArgumentError, 'Selecione o grupo principal de um módulo Nex Mob.' unless ModuloParametrico.editavel?(grupo)

      encerrar_ferramenta
      @grupo = grupo
      @modelo = grupo.model
      @observador = ObservadorEdicao.new(method(:atualizar))
      @modelo.add_observer(@observador)
      if @dialogo && @dialogo.visible?
        atualizar
        ativar_selecao
        @dialogo.bring_to_front
        return
      end

      @dialogo = FabricaDialogos.criar('Editar módulo', 'edicao', altura: 690)
      @dialogo.add_action_callback('pronto') { |_contexto| atualizar; ativar_selecao }
      @dialogo.add_action_callback('salvar_edicao') { |_contexto, dados| salvar_medidas(dados) }
      @dialogo.add_action_callback('adicionar_elemento') { |_contexto, dados| adicionar_elemento(dados) }
      @dialogo.add_action_callback('selecionar_vao') { |_contexto| ativar_selecao }
      @dialogo.add_action_callback('vista_frontal') { |_contexto| vista_frontal }
      @dialogo.add_action_callback('abrir_modo_construtivo') { |_contexto| @abrir_modo.call }
      @dialogo.add_action_callback('abrir_frentes') { |_contexto| @abrir_frentes.call(@grupo) if @abrir_frentes }
      @dialogo.add_action_callback('acao_peca') { |_contexto, dados| acao_painel(dados) }
      @dialogo.add_action_callback('acao_gaveta') { |_contexto, dados| editar_gaveta(dados) }
      @dialogo.add_action_callback('concluir_edicao') { |_contexto| @dialogo.close }
      @dialogo.set_on_closed { encerrar_ferramenta; @dialogo = nil; @grupo = nil }
      @dialogo.show
    rescue StandardError => erro
      UI.messagebox(erro.message)
    end

    def atualizar
      @vao = nil
      @peca = nil
      @gaveta = nil
      return unless @dialogo

      enviar('limparVao')
      unless ModuloParametrico.editavel?(@grupo)
        enviar('exibirErro', 'O módulo não está disponível. Selecione um módulo e abra a edição novamente.')
        return
      end
      parametros = ModuloParametrico.parametros(@grupo)
      enviar('receberModulo', parametros)
      divisoes = PlanoBalcaoInferior.ler_divisoes(@grupo)
      enviar('receberResumo', { vaos: ModuloParametrico.vaos(@grupo).length,
                                prateleiras: divisoes.count { |item| item['tipo'] == 'prateleira' },
                                divisorias: divisoes.count { |item| item['tipo'] == 'divisoria' },
                                gavetas: PlanoGavetas.validas(parametros, divisoes, PlanoGavetas.ler(@grupo)).length })
      @ferramenta.atualizar_vaos(ModuloParametrico.vaos(@grupo)) if @ferramenta
      @modelo.active_view.invalidate
    end

    private

    def ativar_selecao
      verificar_modulo
      @ferramenta ||= FerramentaEdicao3d.new(@modelo, @grupo, method(:selecionar), method(:executar_acao))
      @modelo.select_tool(@ferramenta) unless @modelo.tools.active_tool.equal?(@ferramenta)
      @modelo.active_view.invalidate
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def encerrar_ferramenta
      @modelo.remove_observer(@observador) if @modelo && @observador
      @modelo.select_tool(nil) if @modelo && @ferramenta && @modelo.tools.active_tool.equal?(@ferramenta)
      @ferramenta = nil
      @observador = nil
    end

    def verificar_modulo
      raise ArgumentError, 'O módulo selecionado não está disponível.' unless ModuloParametrico.editavel?(@grupo)
    end

    def selecionar(vao)
      verificar_modulo
      if vao[:tipo] == 'gaveta'
        @vao = nil
        @peca = nil
        @gaveta = vao[:id]
        enviar('receberGaveta', vao)
        return
      end
      if vao[:tipo]
        @vao = nil
        @gaveta = nil
        @peca = vao[:id]
        enviar('receberPeca', vao.merge(folga_minima_mm: ModuloParametrico.parametros(@grupo)['folga_minima_mm']))
        return
      end
      @peca = nil
      @gaveta = nil
      @vao = vao[:id]
      esquerda, direita, inferior, superior = vao[:limites_mm]
      parametros = ModuloParametrico.parametros(@grupo)
      enviar('receberVao', { id: @vao, largura_mm: direita - esquerda, altura_mm: superior - inferior,
                             espessura_mm: parametros['espessura_mm'], folga_minima_mm: parametros['folga_minima_mm'],
                             folga_vertical_gaveta_mm: parametros['folga_vertical_gaveta_mm'],
                             folga_base_gaveta_mm: parametros['folga_base_gaveta_mm'],
                             folga_sarrafo_gaveta_mm: parametros['folga_sarrafo_gaveta_mm'] })
    end

    def acao_painel(dados)
      raise ArgumentError, 'Selecione uma peça no móvel.' unless @peca && dados.is_a?(Hash)
      if dados['acao'] == 'iniciar_movimento'
        ativar_selecao
        @ferramenta.executar_acao(:mover)
      else
        executar_acao(dados['acao'].to_sym, dados.merge('id' => @peca))
      end
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def executar_acao(acao, dados)
      return editar_gaveta(dados) if acao == :gaveta
      if acao == :erro
        enviar('exibirErro', dados)
        return
      elsif acao == :limpar
        @vao = @peca = @gaveta = nil
        enviar('limparVao')
        return
      end
      verificar_modulo
      parametros = ModuloParametrico.parametros(@grupo)
      divisoes = PlanoBalcaoInferior.ler_divisoes(@grupo)
      if [:prateleira, :divisoria].include?(acao)
        vao = ModuloParametrico.vaos(@grupo).find { |item| item[:id] == dados['id'] }
        raise ArgumentError, 'Selecione novamente o vão.' unless vao
        esquerda, direita, inferior, superior = vao[:limites_mm]
        extensao = acao == :prateleira ? superior - inferior : direita - esquerda
        novas = PlanoBalcaoInferior.adicionar_divisao(parametros, divisoes, vao[:id], acao.to_s,
                                                     (extensao - parametros['espessura_mm']) / 2)
        selecionada = vao[:id]
      else
        case acao
        when :mover
          novas = if dados.key?('vao_livre_mm')
                    EdicaoDivisoes.mover_por_vao(parametros, divisoes, dados['id'], dados['vao_livre_mm'])
                  else
                    EdicaoDivisoes.mover(parametros, divisoes, dados['id'], dados['posicao_mm'])
                  end
          selecionada = dados['id']
        when :duplicar
          novas = EdicaoDivisoes.duplicar(parametros, divisoes, dados['id'])
          selecionada = novas.last['vao_id']
        when :excluir
          novas = EdicaoDivisoes.excluir(parametros, divisoes, dados['id'])
        else
          raise ArgumentError, 'Ação de edição desconhecida.'
        end
      end
      ConstrutorBalcaoInferior.new(@modelo).atualizar(@grupo, parametros, novas)
      atualizar
      ativar_selecao
      @ferramenta.selecionar_peca(selecionada) if selecionada
      enviar('confirmarAcao', acao == :excluir ? 'Peça excluída. Clique no próximo vão.' : 'Peça atualizada. Continue editando no 3D.')
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def salvar_medidas(dados)
      verificar_modulo
      raise ArgumentError, 'Medidas inválidas.' unless dados.is_a?(Hash)

      medidas = dados.select { |chave, _valor| %w[largura_mm altura_mm profundidade_mm].include?(chave) }
      ConstrutorBalcaoInferior.new(@modelo).atualizar(@grupo, ModuloParametrico.parametros(@grupo).merge(medidas))
      atualizar
      ativar_selecao
      enviar('confirmarEdicao')
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def adicionar_elemento(dados)
      verificar_modulo
      raise ArgumentError, 'Clique no vão desejado no 3D.' unless @vao
      raise ArgumentError, 'Dados inválidos.' unless dados.is_a?(Hash)

      parametros = ModuloParametrico.parametros(@grupo)
      divisoes = ConstrutorBalcaoInferior.ler_divisoes(@grupo)
      if dados['tipo'] == 'gaveta'
        gavetas = PlanoGavetas.adicionar(parametros, divisoes, PlanoGavetas.ler(@grupo), @vao, dados.fetch('quantidade', 1))
        ConstrutorBalcaoInferior.new(@modelo).atualizar(@grupo, parametros, divisoes, gavetas: gavetas)
      else
        divisoes = EdicaoDivisoes.adicionar_multiplas(
          parametros, divisoes, @vao, dados['tipo'], dados['posicao_mm'], dados.fetch('quantidade', 1)
        )
        ConstrutorBalcaoInferior.new(@modelo).atualizar(@grupo, parametros, divisoes)
      end
      atualizar
      ativar_selecao
      @ferramenta.selecionar_peca(divisoes.last['vao_id']) unless dados['tipo'] == 'gaveta'
      enviar('confirmarElemento', dados.fetch('quantidade', 1), dados['tipo'])
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def editar_gaveta(dados)
      verificar_modulo
      raise ArgumentError, 'Selecione uma gaveta no móvel.' unless @gaveta
      raise ArgumentError, 'Dados da gaveta inválidos.' unless dados.is_a?(Hash)

      identificador = dados.fetch('id', @gaveta).to_s
      raise ArgumentError, 'Selecione novamente a gaveta.' unless identificador == @gaveta

      if dados['acao'] == 'mover' && !dados.key?('posicao_mm')
        ativar_selecao
        @ferramenta.executar_acao(:mover)
        return
      end

      parametros = ModuloParametrico.parametros(@grupo)
      divisoes = ConstrutorBalcaoInferior.ler_divisoes(@grupo)
      gavetas = PlanoGavetas.ler(@grupo)
      case dados['acao']
      when 'mover'
        gavetas = PlanoGavetas.mover(parametros, divisoes, gavetas, identificador, dados['posicao_mm'])
        mensagem = 'Gaveta movida. Continue editando no 3D.'
      when 'redimensionar'
        gavetas = PlanoGavetas.redimensionar(parametros, divisoes, gavetas, identificador,
                                              dados['posicao_mm'], dados['altura_mm'], dados['profundidade_mm'])
        mensagem = 'Ajustes da gaveta aplicados.'
      when 'duplicar'
        gavetas = PlanoGavetas.duplicar(parametros, divisoes, gavetas, identificador)
        mensagem = 'Gaveta duplicada no espaço livre disponível.'
      when 'excluir'
        gavetas = PlanoGavetas.excluir(parametros, divisoes, gavetas, identificador)
        mensagem = 'Gaveta excluída. Clique em outra caixa para continuar.'
      else
        raise ArgumentError, 'Ação da gaveta desconhecida.'
      end
      ConstrutorBalcaoInferior.new(@modelo).atualizar(@grupo, parametros, divisoes, gavetas: gavetas)
      atualizar
      ativar_selecao
      @ferramenta.selecionar_gaveta(identificador) unless dados['acao'] == 'excluir'
      enviar('confirmarAcao', mensagem)
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def vista_frontal
      verificar_modulo
      EnquadramentoModulo.frontal(@modelo, @grupo)
      ativar_selecao
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def enviar(funcao, *argumentos)
      @dialogo.execute_script("window.#{funcao}(#{argumentos.map { |valor| JSON.generate(valor) }.join(',')})") if @dialogo
    end
  end
end
