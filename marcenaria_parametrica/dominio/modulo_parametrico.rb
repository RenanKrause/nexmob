require 'securerandom'
require_relative 'plano_balcao_inferior'

module MarcenariaParametrica
  module ModuloParametrico
    def self.reconhecido?(grupo)
      grupo.is_a?(Sketchup::Group) && grupo.valid? &&
        grupo.get_attribute(PlanoBalcaoInferior::DICIONARIO_MODULO, 'tipo') == PlanoBalcaoInferior::TIPO
    end

    def self.inicializar(grupo)
      raise ArgumentError, 'Selecione um módulo reconhecido.' unless reconhecido?(grupo)

      dicionario = PlanoBalcaoInferior::DICIONARIO_MODULO
      uuid = grupo.get_attribute(dicionario, 'modulo_uuid')
      if uuid.nil? || (uuid.is_a?(String) && uuid.strip.empty?)
        grupo.set_attribute(dicionario, 'modulo_uuid', SecureRandom.uuid)
      end
      grupo.set_attribute(dicionario, 'ambiente_id', '') if grupo.get_attribute(dicionario, 'ambiente_id').nil?
      grupo
    end

    def self.nome_exibicao(grupo)
      nome = grupo.name.to_s.strip
      return nome unless nome.empty?

      tipo = grupo.get_attribute(PlanoBalcaoInferior::DICIONARIO_MODULO, 'tipo')
      tipo == PlanoBalcaoInferior::TIPO ? 'Balcão inferior' : tipo.to_s.tr('_', ' ').capitalize
    end

    def self.editavel?(grupo)
      reconhecido?(grupo) && !grupo.locked? && grupo.model == Sketchup.active_model
    end

    def self.parametros(grupo)
      ConstrutorBalcaoInferior::PADRAO.to_h do |chave, padrao|
        [chave, grupo.get_attribute(ConstrutorBalcaoInferior::DICIONARIO_MODULO, chave, padrao)]
      end
    end

    def self.vaos(grupo)
      ConstrutorBalcaoInferior.vaos(parametros(grupo), ConstrutorBalcaoInferior.ler_divisoes(grupo))
    end
  end
end
