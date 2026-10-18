require 'time'
require_relative '../dominio/dados_projeto'

module MarcenariaParametrica
  module ManifestoQr
    class << self
      def gerar(modelo, catalogo, revision_id:)
        projeto = DadosProjeto.ler(modelo)
        texto!(revision_id)
        texto!(projeto['projeto_uuid'])
        ambientes = projeto['ambientes'].to_h { |ambiente| [ambiente['id'], ambiente['nome']] }
        modulos, origens, chaves, tokens = {}, {}, {}, {}
        catalogo.each do |item|
          id = item[:modulo_id]
          texto!(id)
          texto!(item[:modulo_nome])
          if modulos.key?(id)
            if modulos[id]['name'] != item[:modulo_nome] ||
               (origens[id] && item[:modulo] && !origens[id].equal?(item[:modulo])) ||
               modulos[id]['environment'] != ambientes.fetch(item[:ambiente_id], '')
              raise ArgumentError, 'Há módulos com identidade duplicada. Verifique as cópias do móvel.'
            end
          else
            modulos[id] = { 'module_id' => id, 'name' => item[:modulo_nome],
                            'environment' => ambientes.fetch(item[:ambiente_id], ''), 'pieces' => [] }
            origens[id] = item[:modulo]
            chaves[id] = {}
          end
          peca = peca_publica(item)
          token = peca['qr_token'].downcase
          if tokens[token] || chaves[id][peca['logical_key']]
            raise ArgumentError, 'Há peças com identidade duplicada. Verifique as cópias do móvel.'
          end
          tokens[token] = true
          chaves[id][peca['logical_key']] = true
          modulos[id]['pieces'] << peca
        end
        { 'schema_version' => '1', 'project_id' => projeto['projeto_uuid'], 'revision_id' => revision_id,
          'synced_at' => Time.now.utc.iso8601, 'modules' => modulos.values }
      end

      private

      def peca_publica(item)
        %i[chave_logica nome material].each { |chave| texto!(item[chave]) }
        token = item[:qr_token]
        unless token.is_a?(String) && token.match?(/\A[0-9a-fA-F]{32}\z/)
          raise ArgumentError, 'A identidade QR da peça está inválida.'
        end
        tupla!(item[:dimensoes_mm], 3, true)
        tupla!(item[:transform_mm], 4)
        fita = item[:edge_banding]
        unless fita.is_a?(Hash) && fita.keys.sort == %w[bottom left right top] &&
               fita.values.all? { |valor| valor == true || valor == false }
          raise ArgumentError, 'As fitas da peça estão inválidas.'
        end
        unless item[:visible] == true || item[:visible] == false
          raise ArgumentError, 'A visibilidade da peça está inválida.'
        end
        # Lista explícita: dados de cliente e referências SketchUp nunca são serializados.
        { 'logical_key' => item[:chave_logica], 'qr_token' => token, 'name' => item[:nome],
          'cut_mm' => item[:dimensoes_mm].dup, 'transform_mm' => item[:transform_mm].dup,
          'material' => item[:material], 'edge_banding' => fita.dup, 'visible' => item[:visible] }
      end

      def texto!(valor)
        raise ArgumentError, 'Os dados da revisão estão incompletos.' unless valor.is_a?(String) && !valor.strip.empty?
      end

      def tupla!(valores, tamanho, positivo = false)
        valido = valores.is_a?(Array) && valores.length == tamanho && valores.all? { |valor|
          valor.is_a?(Numeric) && valor.real? && valor.finite? && (!positivo || valor > 0)
        }
        unless valido
          raise ArgumentError, 'As medidas ou a transformação da peça estão inválidas.'
        end
      end
    end
  end
end
