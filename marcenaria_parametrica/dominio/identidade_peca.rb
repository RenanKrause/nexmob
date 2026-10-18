require 'json'
require 'securerandom'
require_relative 'plano_balcao_inferior'

module MarcenariaParametrica
  module IdentidadePeca
    DICIONARIO = PlanoBalcaoInferior::DICIONARIO_PECA
    ORIGENS = {
      vao_id: 'vao_origem', gaveta_id: 'gaveta_origem', vao_destino: 'gaveta_vao',
      frente_id: 'frente_origem', gaveta_destino: 'frente_gaveta'
    }.freeze

    def self.chave_logica(peca)
      codigo = peca[:codigo].to_s
      raise ArgumentError, 'A peça precisa de um código estável.' if codigo.strip.empty?

      # O número de fabricação das divisões muda quando outra divisão é removida.
      # Cada vão admite uma divisão; tipo + origem mantém a peça sem confundir lados.
      codigo = codigo.sub(/\A(PRATELEIRA|DIVISORIA)_\d+\z/, '\1') if texto(peca[:vao_id])
      # Não depende de dimensões, posição, nome de exibição ou dados do cliente.
      JSON.generate([codigo, ORIGENS.keys.map { |origem| peca[origem].to_s }])
    end

    def self.atributos_para(peca, anteriores)
      chave = chave_logica(peca)
      anterior = anteriores[chave] || {}
      token = anterior['qr_token']
      token = SecureRandom.hex(16) unless token.is_a?(String) && token.match?(/\A[0-9a-f]{32}\z/)
      {
        'chave_logica' => chave,
        'qr_token' => token,
        'material_padrao' => texto(peca[:material_padrao]) || texto(peca[:material]) || 'MDP',
        'material_sobrescrito' => texto(anterior['material_sobrescrito']) || ''
      }
    end

    def self.material_efetivo(grupo)
      texto(grupo.get_attribute(DICIONARIO, 'material_sobrescrito')) ||
        texto(grupo.get_attribute(DICIONARIO, 'material_padrao')) ||
        texto(grupo.get_attribute(DICIONARIO, 'material')) || 'MDP'
    end

    def self.capturar(entidades)
      entidades.grep(Sketchup::Group).each_with_object({}) do |grupo, anteriores|
        codigo = grupo.get_attribute(DICIONARIO, 'codigo')
        next if codigo.to_s.strip.empty?

        peca = { codigo: codigo }
        ORIGENS.each { |origem, atributo| peca[origem] = grupo.get_attribute(DICIONARIO, atributo) }
        # Recalcula a chave semântica para migrar chaves antigas com número global,
        # conservando o QR e o material da própria peça anterior à reconstrução.
        chave = chave_logica(peca)
        padrao_anterior = grupo.get_attribute(DICIONARIO, 'material_padrao')
        substituicao_anterior = grupo.get_attribute(DICIONARIO, 'material_sobrescrito')
        padrao = texto(padrao_anterior) || 'MDP'
        sobrescrito = texto(substituicao_anterior)
        material = texto(grupo.get_attribute(DICIONARIO, 'material'))
        # Preserva também personalizações de peças anteriores ao esquema de identidade.
        if padrao_anterior.nil? && substituicao_anterior.nil? && material && material != padrao
          sobrescrito = material
        end
        anteriores[chave] = {
          'qr_token' => grupo.get_attribute(DICIONARIO, 'qr_token'),
          'material_padrao' => padrao, 'material_sobrescrito' => sobrescrito || ''
        }
      end
    end

    def self.texto(valor)
      valor if valor.is_a?(String) && !valor.strip.empty?
    end
    private_class_method :texto
  end
end
