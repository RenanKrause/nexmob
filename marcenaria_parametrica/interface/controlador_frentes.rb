require 'json'

module MarcenariaParametrica
  class ControladorFrentes
    def abrir(grupo = Sketchup.active_model.selection.first)
      raise ArgumentError, 'Selecione o grupo principal de um módulo Nex Mob.' unless ModuloParametrico.editavel?(grupo)

      @grupo = grupo
      @modelo = grupo.model
      if @dialogo && @dialogo.visible?
        enviar_dados
        @dialogo.bring_to_front
        return
      end

      @dialogo = FabricaDialogos.criar('Frentes', 'frentes', largura: 540, altura: 650, largura_minima: 420, altura_minima: 520)
      @dialogo.add_action_callback('pronto') { |_contexto| enviar_dados }
      @dialogo.add_action_callback('salvar_frentes') { |_contexto, dados| salvar(dados) }
      @dialogo.set_on_closed { @dialogo = nil; @grupo = nil }
      @dialogo.show
    rescue StandardError => erro
      UI.messagebox(erro.message)
    end

    private

    def enviar_dados
      parametros = ModuloParametrico.parametros(@grupo)
      divisoes = PlanoBalcaoInferior.ler_divisoes(@grupo)
      gavetas = PlanoGavetas.validas(parametros, divisoes, PlanoGavetas.ler(@grupo))
      composicoes = PlanoFrentes.validas(parametros, divisoes, gavetas, PlanoFrentes.ler(@grupo))
      gavetas_por_vao = PlanoGavetas.representacoes(parametros, divisoes, gavetas).group_by { |gaveta| gaveta[:vao_id] }
      vaos = ModuloParametrico.vaos(@grupo).map do |vao|
        esquerda, direita, inferior, superior = vao[:limites_mm]
        gavetas_do_vao = gavetas_por_vao.fetch(vao[:id], [])
        { id: vao[:id], largura_mm: direita - esquerda, altura_mm: superior - inferior,
          gavetas: gavetas_do_vao.length, gavetas_identificadas: gavetas_do_vao.map { |gaveta| gaveta[:nome] },
          portas_sugeridas: PlanoFrentes.quantidade_portas_sugerida(parametros, direita - esquerda) }
      end
      enviar('receberFrentes', { vaos: vaos, composicoes: composicoes,
                                 padroes: { portas: PlanoFrentes.padroes_para(parametros, 'portas'),
                                             frentes_gavetas: PlanoFrentes.padroes_para(parametros, 'frentes_gavetas') } })
    rescue StandardError => erro
      enviar('exibirErroFrentes', erro.message)
    end

    def salvar(dados)
      raise ArgumentError, 'Dados das frentes inválidos.' unless dados.is_a?(Hash)
      raise ArgumentError, 'O módulo não está disponível.' unless ModuloParametrico.editavel?(@grupo)

      parametros = ModuloParametrico.parametros(@grupo)
      divisoes = PlanoBalcaoInferior.ler_divisoes(@grupo)
      gavetas = PlanoGavetas.validas(parametros, divisoes, PlanoGavetas.ler(@grupo))
      frentes = PlanoFrentes.definir(parametros, divisoes, gavetas, PlanoFrentes.ler(@grupo), dados)
      ConstrutorBalcaoInferior.new(@modelo).atualizar(@grupo, parametros, divisoes, gavetas: gavetas, frentes: frentes)
      enviar_dados
      enviar('exibirMensagemFrentes', 'Frentes atualizadas no módulo.')
    rescue StandardError => erro
      enviar('exibirErroFrentes', erro.message)
    end

    def enviar(funcao, valor)
      @dialogo.execute_script("window.#{funcao}(#{JSON.generate(valor)})") if @dialogo
    end
  end
end
