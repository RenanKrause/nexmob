require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module MarcenariaParametrica
  module ClienteSincronizacao
    Resultado = Struct.new(:status, :http_status, :mensagem, keyword_init: true) do
      def sucesso?
        status == :sucesso
      end
    end

    class << self
      def publicar(url:, token:, manifesto:)
        uri = url.is_a?(String) ? URI.parse(url) : nil
        unless uri.is_a?(URI::HTTPS) && uri.host && !uri.host.empty? &&
               uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
               token.is_a?(String) && token.match?(/\A[^\s\x00-\x1f\x7f]+\z/)
          return resultado(:configuracao, nil, 'Configure uma URL HTTPS e uma credencial de sincronização válidas.')
        end
        corpo = JSON.generate(manifesto)
        pedido = Net::HTTP::Post.new(uri.request_uri)
        pedido['Authorization'] = "Bearer #{token}"
        pedido['Content-Type'] = 'application/json'
        pedido['Accept'] = 'application/json'
        pedido.body = corpo
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 30
        http.write_timeout = 30
        # Revisões são imutáveis. Uma nova tentativa deve ser decisão do chamador.
        http.max_retries = 0
        resposta = http.request(pedido)
        codigo = resposta.code.to_i
        case codigo
        when 200..299
          resultado(:sucesso, codigo, 'Revisão sincronizada com sucesso.')
        when 401
          resultado(:credencial_recusada, codigo, 'A credencial de sincronização foi recusada.')
        when 400..499
          resultado(:validacao, codigo, 'A revisão foi recusada. Verifique os dados e a permissão do projeto.')
        else
          resultado(:servidor, codigo, 'O serviço de sincronização está indisponível. Tente novamente.')
        end
      rescue URI::InvalidURIError, ArgumentError
        resultado(:configuracao, nil, 'A configuração de sincronização está inválida.')
      rescue JSON::JSONError, TypeError
        resultado(:validacao, nil, 'Os dados da revisão não podem ser serializados.')
      rescue Timeout::Error, SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
        # Nunca retornar corpo do servidor, URL, exceção ou credencial.
        resultado(:rede, nil, 'Não foi possível confirmar a sincronização. Verifique a conexão e tente novamente.')
      end

      private

      def resultado(status, codigo, mensagem)
        Resultado.new(status: status, http_status: codigo, mensagem: mensagem)
      end
    end
  end
end
