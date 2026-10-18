require 'json'
require 'uri'
require 'digest'
require 'securerandom'

module MarcenariaParametrica
  class ControladorEtiquetas
    def initialize
      @configuracao = ConfiguracaoEtiquetas.new
    end

    def abrir
      if @dialogo && @dialogo.visible?
        atualizar
        @dialogo.bring_to_front
        return
      end
      @modelo = Sketchup.active_model
      @conexao = ler_conexao
      @token = nil
      @sincronizacao = nil
      @dialogo = FabricaDialogos.criar('Etiquetas e QR', 'etiquetas', largura: 900, altura: 820, largura_minima: 560)
      @dialogo.add_action_callback('etiquetas_prontas') { |_contexto| atualizar }
      @dialogo.add_action_callback('atualizar_lote') { |_contexto| atualizar }
      @dialogo.add_action_callback('sincronizar_etiquetas') { |_contexto, dados| sincronizar(dados) }
      @dialogo.add_action_callback('salvar_configuracao_etiquetas') { |_contexto, dados| salvar_configuracao(dados) }
      @dialogo.add_action_callback('solicitar_previa') { |_contexto, dados| preparar_saida(dados) }
      @dialogo.set_on_closed do
        # Credencial apenas na memória desta sessão; nunca nas preferências ou HTML.
        @token = nil
        @sincronizacao = nil
        @dialogo = nil
        @modelo = nil
      end
      @dialogo.show
    rescue StandardError
      UI.messagebox('Não foi possível abrir as etiquetas do projeto.')
    end

    private

    def enviar(funcao, dados)
      FabricaDialogos.enviar(@dialogo, funcao, dados)
    end

    def verificar_modelo
      raise ArgumentError, 'Abra as etiquetas novamente no projeto ativo.' unless @modelo == Sketchup.active_model
    end

    def ler_dados(dados)
      valor = dados.is_a?(String) ? JSON.parse(dados) : dados
      raise ArgumentError, 'Dados de etiquetas inválidos.' unless valor.is_a?(Hash)

      valor
    rescue JSON::ParserError
      # O erro do parser pode conter o payload, inclusive a credencial.
      raise ArgumentError, 'Dados de etiquetas inválidos.'
    end

    def validar_conexao(dados)
      api = URI.parse(dados['sync_url'].to_s)
      viewer = URI.parse(dados['viewer_base_url'].to_s)
      unless [api, viewer].all? { |uri| uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo && !uri.query && !uri.fragment } &&
             api.path == '/v1/revisions' && ['', '/'].include?(viewer.path)
        raise ArgumentError, 'Configure as URLs HTTPS da API e do visualizador.'
      end
      { 'sync_url' => api.to_s, 'viewer_base_url' => viewer.to_s.sub(%r{/$}, '') }
    rescue URI::InvalidURIError
      raise ArgumentError, 'As URLs de sincronização estão inválidas.'
    end

    def ler_conexao
      texto = Sketchup.read_default('NexMob', 'conexao_qr', nil)
      texto ? validar_conexao(JSON.parse(texto)) : {}
    rescue JSON::ParserError, ArgumentError, TypeError
      {}
    end

    def catalogo_atual
      verificar_modelo
      CatalogoPecas.listar(@modelo)
    end

    def itens_publicos(catalogo)
      catalogo.map do |item|
        CompositorEtiquetas::CAMPOS.to_h { |chave| [chave, item[chave.to_sym]] }
      end
    end

    def assinatura(catalogo)
      manifesto = ManifestoQr.gerar(@modelo, catalogo, revision_id: 'conferencia')
      manifesto.delete('synced_at')
      Digest::SHA256.hexdigest(JSON.generate([manifesto, itens_publicos(catalogo)]))
    end

    def configuracao_publica
      dados = @configuracao.ler.merge('viewer_base_url' => @conexao['viewer_base_url'])
      if @sincronizacao
        dados.merge!('revision_id' => @sincronizacao[:revision_id], 'gerado_em' => @sincronizacao[:gerado_em])
      end
      dados
    end

    def atualizar
      catalogo = catalogo_atual
      sincronizado = @sincronizacao && @sincronizacao[:assinatura] == assinatura(catalogo)
      @sincronizacao = nil unless sincronizado
      enviar('receberDadosEtiquetas', {
        itens: itens_publicos(catalogo), configuracao: configuracao_publica,
        sincronizado: !!sincronizado,
        conexao: @conexao.merge('credencial_configurada' => !@token.to_s.empty?)
      })
    rescue StandardError
      @sincronizacao = nil
      enviar('erroEtiquetas', 'Não foi possível listar as peças. Confira o projeto ativo e os dados dos módulos.')
    end

    def salvar_configuracao(dados)
      verificar_modelo
      @configuracao.salvar(ler_dados(dados))
    rescue StandardError
      enviar('erroEtiquetas', 'Configuração inválida. Use QR mínimo de 20 mm, texto mínimo de 6 pt e medidas legíveis.')
    end

    def sincronizar(dados)
      verificar_modelo
      @sincronizacao = nil
      entrada = ler_dados(dados)
      conexao = validar_conexao(entrada)
      token = entrada['token']
      token = @token if token == '' || token.nil?
      unless token.is_a?(String) && token.match?(/\A[^\s\x00-\x1f\x7f]+\z/)
        raise ArgumentError, 'Configure uma credencial válida.'
      end
      @configuracao.salvar(entrada.fetch('configuracao'))
      # Somente as duas URLs validadas são persistidas; nunca gravar entrada/token.
      unless Sketchup.write_default('NexMob', 'conexao_qr', JSON.generate(conexao))
        raise ArgumentError, 'Não foi possível salvar as URLs.'
      end
      @conexao = conexao
      @token = token
      etapa = 'validacao'
      catalogo = catalogo_atual
      raise ArgumentError, 'Não há peças válidas.' if catalogo.empty?

      manifesto = ManifestoQr.gerar(@modelo, catalogo, revision_id: SecureRandom.uuid)
      marca = assinatura(catalogo)
      enviar('estadoSincronizacao', { status: 'sincronizando' })
      resultado = ClienteSincronizacao.publicar(url: @conexao['sync_url'], token: @token, manifesto: manifesto)
      if resultado.sucesso?
        @sincronizacao = { assinatura: marca, revision_id: manifesto['revision_id'], gerado_em: manifesto['synced_at'] }
      elsif resultado.status == :credencial_recusada
        @token = nil
      end
      # Nunca encaminhar corpo, exceção, mensagem de rede ou o payload à interface.
      enviar('estadoSincronizacao', { status: resultado.status.to_s, credencial_configurada: !@token.to_s.empty? })
      atualizar if resultado.sucesso?
    rescue KeyError, ArgumentError, TypeError
      enviar('estadoSincronizacao', { status: etapa || 'configuracao', credencial_configurada: !@token.to_s.empty? })
    rescue StandardError
      enviar('estadoSincronizacao', { status: 'servidor' })
    end

    def preparar_saida(dados)
      entrada = ler_dados(dados)
      config = ConfiguracaoEtiquetas.validar(entrada.fetch('configuracao', entrada))
      modo = entrada.fetch('modo', 'termica')
      raise ArgumentError, 'Modo de saída inválido.' unless %w[termica a4].include?(modo)
      ConfiguracaoEtiquetas.validar(config.merge('largura_mm' => 99, 'altura_mm' => 55.8)) if modo == 'a4'
      catalogo = catalogo_atual
      unless @sincronizacao && !catalogo.empty? && @sincronizacao[:assinatura] == assinatura(catalogo)
        @sincronizacao = nil
        enviar('erroEtiquetas', 'O projeto precisa ser sincronizado. Sincronize novamente após alterar os móveis ou dados do projeto.')
        return
      end
      enviar('prepararSaidaEtiquetas', {
        itens: itens_publicos(catalogo), configuracao: configuracao_publica.merge(config),
        modo: modo, imprimir: entrada['imprimir'] == true
      })
    rescue StandardError
      enviar('erroEtiquetas', 'Não foi possível preparar a saída. Confira as medidas da etiqueta e sincronize o projeto.')
    end
  end
end
