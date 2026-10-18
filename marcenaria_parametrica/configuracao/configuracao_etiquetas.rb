require 'json'

module MarcenariaParametrica
  class ConfiguracaoEtiquetas
    PADRAO = { 'largura_mm' => 99.0, 'altura_mm' => 55.8, 'qr_mm' => 22.0, 'texto_pt' => 7.0,
               'offset_x_mm' => 0.0, 'offset_y_mm' => 0.0 }.freeze

    def initialize(armazenamento = Sketchup)
      @armazenamento = armazenamento
    end

    def ler
      texto = @armazenamento.read_default('NexMob', 'etiquetas', nil)
      texto ? self.class.validar(JSON.parse(texto)) : PADRAO.dup
    rescue JSON::ParserError, ArgumentError, TypeError
      PADRAO.dup
    end

    def salvar(parametros)
      raise ArgumentError, 'Configuração de etiquetas inválida.' unless parametros.is_a?(Hash)

      valores = self.class.validar(ler.merge(parametros.transform_keys(&:to_s)))
      unless @armazenamento.write_default('NexMob', 'etiquetas', JSON.generate(valores))
        raise 'Não foi possível salvar a configuração de etiquetas.'
      end
      valores
    end

    def self.validar(parametros)
      raise ArgumentError, 'Configuração de etiquetas inválida.' unless parametros.is_a?(Hash)

      entrada = parametros.transform_keys(&:to_s)
      valores = PADRAO.to_h do |chave, padrao|
        begin
          numero = Float(entrada.fetch(chave, padrao))
        rescue ArgumentError, TypeError
          raise ArgumentError, 'Informe medidas numéricas para a etiqueta.'
        end
        raise ArgumentError, 'Informe medidas finitas para a etiqueta.' unless numero.finite?

        [chave, numero]
      end
      if valores['qr_mm'] < 20 || valores['texto_pt'] < 6
        raise ArgumentError, 'Use QR de pelo menos 20 mm e texto de pelo menos 6 pt.'
      end
      largura, altura, qr, texto = valores.values_at('largura_mm', 'altura_mm', 'qr_mm', 'texto_pt')
      if largura < qr + 42 || altura < [qr + 27, texto * 0.352778 * 1.2 * 12 + 10].max
        raise ArgumentError, 'O conteúdo não cabe de forma legível. Aumente o tamanho da etiqueta.'
      end
      # A4350: margem horizontal 6 mm e vertical 9 mm; offsets não podem cortar a grade.
      if valores['offset_x_mm'].abs > 6 || valores['offset_y_mm'].abs > 9
        raise ArgumentError, 'A calibração ultrapassa os limites da folha A4 (X ±6 mm, Y ±9 mm).'
      end
      valores
    end
  end
end
