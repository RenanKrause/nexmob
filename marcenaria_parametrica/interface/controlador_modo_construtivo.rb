require 'json'

module MarcenariaParametrica
  class ControladorModoConstrutivo
    def initialize(configuracao, ao_aplicar)
      @configuracao = configuracao
      @ao_aplicar = ao_aplicar
    end

    def abrir
      return @dialogo.bring_to_front if @dialogo && @dialogo.visible?

      @dialogo = FabricaDialogos.criar(
        'Modo construtivo', 'modo_construtivo', largura: 1180, altura: 760,
        largura_minima: 760, altura_minima: 560
      )
      @dialogo.add_action_callback('pronto') { |_contexto| enviar_dados }
      @dialogo.add_action_callback('salvar_modo') { |_contexto, dados| salvar(dados, false) }
      @dialogo.add_action_callback('aplicar_modo') { |_contexto, dados| salvar(dados, true) }
      @dialogo.add_action_callback('ativar_modo') { |_contexto, nome| ativar(nome) }
      @dialogo.set_on_closed { @dialogo = nil }
      @dialogo.show
    end

    private

    def enviar_dados
      enviar('receberModos', @configuracao.carregar)
    end

    def ativar(nome)
      @configuracao.ativar(nome)
      enviar_dados
      enviar('exibirMensagemModo', 'Modo ativo para novos móveis. Para atualizar os existentes, aplique ao projeto.')
    rescue StandardError => erro
      enviar('exibirErro', erro.message)
    end

    def salvar(dados, aplicar)
      raise ArgumentError, 'Configuração inválida.' unless dados.is_a?(Hash)

      registro = @configuracao.salvar_modo(dados['nome'], dados['categorias'])
      enviar_dados
      if aplicar
        resultado = AplicadorModoConstrutivo.new(Sketchup.active_model).aplicar(registro['modos'].fetch(registro['ativo']))
        @ao_aplicar.call
        enviar('exibirMensagemModo', "Modo salvo. #{resultado[:atualizados]} móveis atualizados; #{resultado[:bloqueados]} bloqueados preservados.")
      else
        enviar('exibirMensagemModo', 'Modo salvo e ativo para os próximos móveis.')
      end
    rescue StandardError => erro
      prefixo = registro && aplicar ? 'Modo salvo; o projeto não foi atualizado. ' : ''
      enviar('exibirErro', "#{prefixo}#{erro.message}")
    end

    def enviar(funcao, valor)
      @dialogo.execute_script("window.#{funcao}(#{JSON.generate(valor)})") if @dialogo
    end
  end
end
