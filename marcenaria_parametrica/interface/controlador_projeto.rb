require 'json'

module MarcenariaParametrica
  class ControladorProjeto
    def abrir
      if @dialogo && @dialogo.visible?
        atualizar
        @dialogo.bring_to_front
        return
      end
      @modelo = Sketchup.active_model
      @dialogo = FabricaDialogos.criar('Dados do projeto', 'projeto', largura: 500, altura: 720)
      @dialogo.add_action_callback('projeto_pronto') { |_contexto| atualizar }
      %w[salvar_cliente criar_ambiente renomear_ambiente excluir_ambiente].each do |acao|
        @dialogo.add_action_callback(acao) { |_contexto, dados| executar(acao, dados) }
      end
      @dialogo.set_on_closed { @dialogo = nil; @modelo = nil }
      @dialogo.show
    rescue StandardError
      UI.messagebox('Não foi possível abrir os dados do projeto.')
    end

    private

    def atualizar(mensagem = nil)
      verificar_modelo
      dados = DadosProjeto.ler(@modelo)
      dados['mensagem'] = mensagem if mensagem
      FabricaDialogos.enviar(@dialogo, 'receberProjeto', dados)
    rescue StandardError => erro
      FabricaDialogos.enviar(@dialogo, 'erroProjeto', erro.message)
    end

    def verificar_modelo
      raise ArgumentError, 'Abra novamente os dados no projeto ativo.' unless @modelo == Sketchup.active_model
    end

    def executar(acao, dados)
      verificar_modelo
      raise ArgumentError, 'Dados de projeto inválidos.' unless dados.is_a?(Hash)

      @modelo.start_operation('Dados do projeto Nex Mob', true)
      operacao = true
      case acao
      when 'salvar_cliente' then DadosProjeto.salvar_cliente(@modelo, dados['nome'])
      when 'criar_ambiente' then DadosProjeto.criar_ambiente(@modelo, dados['nome'])
      when 'renomear_ambiente' then DadosProjeto.renomear_ambiente(@modelo, dados['id'], dados['nome'])
      when 'excluir_ambiente' then DadosProjeto.excluir_ambiente(@modelo, dados['id'])
      end
      @modelo.commit_operation
      operacao = false
      atualizar('Dados do projeto salvos.')
    rescue StandardError => erro
      @modelo.abort_operation if operacao
      FabricaDialogos.enviar(@dialogo, 'erroProjeto', erro.message)
    end
  end
end
