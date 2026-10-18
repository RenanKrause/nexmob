require 'json'
require 'uri'
require 'time'
require_relative '../configuracao/configuracao_etiquetas'

module MarcenariaParametrica
  module CompositorEtiquetas
    CAMPOS = %w[cliente ambiente modulo_nome nome codigo corte_mm material fita_borda edge_banding qr_token].freeze
    INTERFACE = File.expand_path('../interface', __dir__)

    class << self
      def gerar(item, configuracao)
        lote_termico([item], configuracao)
      end

      def lote_termico(itens, configuracao)
        documento(itens, configuracao, 'termica')
      end

      def lote_a4(itens, configuracao)
        documento(itens, configuracao, 'a4')
      end

      private

      def documento(itens, configuracao, modo)
        raise ArgumentError, 'Não há peças para imprimir.' unless itens.is_a?(Array) && !itens.empty?
        raise ArgumentError, 'Configuração inválida.' unless configuracao.is_a?(Hash)

        entrada = configuracao.transform_keys(&:to_s)
        preferencias = ConfiguracaoEtiquetas.validar(entrada)
        ConfiguracaoEtiquetas.validar(preferencias.merge('largura_mm' => 99, 'altura_mm' => 55.8)) if modo == 'a4'
        base = validar_url(entrada['viewer_base_url'])
        dados = itens.map { |item| dados_item(item) }
        config_publica = preferencias.merge('viewer_base_url' => base)
        %w[revision_id gerado_em].each { |chave| config_publica[chave] = entrada[chave].to_s if entrada.key?(chave) }
        config_publica['gerado_em'] ||= Time.now.utc.iso8601
        payload = JSON.generate('itens' => dados, 'configuracao' => config_publica, 'modo' => modo)
                      .gsub('<', '\\u003c').gsub('>', '\\u003e').gsub('&', '\\u0026')
        # Whitelist explícita: credenciais, entidades e caminhos do modelo nunca entram no documento.
        vendor = File.read(File.join(INTERFACE, 'vendor/qrcode.js'), encoding: 'UTF-8')
        motor = File.read(File.join(INTERFACE, 'etiquetas.js'), encoding: 'UTF-8')
        <<~HTML
          <!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Etiquetas Nex Mob</title></head><body>
          <p id="estado-impressao" role="status">Preparando etiquetas…</p><main id="documento-etiquetas"></main>
          <script type="application/json" id="dados-impressao">#{payload}</script>
          <script>#{vendor}</script><script>#{motor}</script>
          <script>Etiquetas.iniciarDocumento(document, window);</script>
          </body></html>
        HTML
      end

      def validar_url(valor)
        uri = URI.parse(valor.to_s)
        unless uri.is_a?(URI::HTTPS) && uri.host && !uri.userinfo && !uri.query && !uri.fragment &&
               (uri.path.empty? || uri.path == '/')
          raise ArgumentError, 'Informe a URL HTTPS pública do visualizador, sem credenciais ou dados de cliente.'
        end
        uri.to_s.sub(%r{/$}, '')
      rescue URI::InvalidURIError
        raise ArgumentError, 'A URL pública do visualizador é inválida.'
      end

      def dados_item(item)
        raise ArgumentError, 'Peça inválida.' unless item.is_a?(Hash)

        entrada = item.transform_keys(&:to_s)
        dados = CAMPOS.to_h { |chave| [chave, entrada[chave]] }.reject { |_chave, valor| valor.nil? }
        unless dados['qr_token'].is_a?(String) && dados['qr_token'].match?(/\A[0-9a-fA-F]{32}\z/)
          raise ArgumentError, 'A identidade QR da peça está inválida.'
        end
        corte = dados['corte_mm']
        unless corte.is_a?(Array) && corte.size == 3 && corte.all? { |n| n.is_a?(Numeric) && n.real? && n.finite? && n > 0 }
          raise ArgumentError, 'As dimensões de corte da peça estão inválidas.'
        end
        dados
      end
    end
  end
end
