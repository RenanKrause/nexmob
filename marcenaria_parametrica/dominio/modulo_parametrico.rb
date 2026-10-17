module MarcenariaParametrica
  module ModuloParametrico
    def self.reconhecido?(grupo)
      grupo.is_a?(Sketchup::Group) && grupo.valid? &&
        grupo.get_attribute(ConstrutorBalcaoInferior::DICIONARIO_MODULO, 'tipo') == ConstrutorBalcaoInferior::TIPO
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
