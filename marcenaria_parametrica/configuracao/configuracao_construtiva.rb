require 'json'

module MarcenariaParametrica
  class ConfiguracaoConstrutiva
    PADROES = {
      'inferiores' => { 'espessura_mm' => 18.0, 'espessura_fundo_mm' => 6.0, 'largura_sarrafo_mm' => 80.0,
                        'folga_minima_mm' => 80.0, 'espessura_gaveta_mm' => 15.0,
                        'espessura_fundo_gaveta_mm' => 6.0, 'folga_lateral_gaveta_mm' => 13.0,
                        'folga_frontal_gaveta_mm' => 2.0, 'folga_traseira_gaveta_mm' => 12.0,
                        'folga_base_gaveta_mm' => 3.0, 'folga_sarrafo_gaveta_mm' => 3.0,
                        'folga_vertical_gaveta_mm' => 3.0,
                        'espessura_porta_mm' => 18.0, 'folga_porta_mm' => 2.0,
                        'recuo_porta_mm' => 0.0, 'largura_referencia_porta_mm' => 450.0,
                        'espessura_frente_gaveta_mm' => 18.0, 'folga_frente_gaveta_mm' => 2.0,
                        'recuo_frente_gaveta_mm' => 0.0 }.freeze,
      'superiores' => { 'espessura_mm' => 18.0, 'espessura_fundo_mm' => 6.0, 'folga_minima_mm' => 80.0 }.freeze,
      'armarios' => { 'espessura_mm' => 18.0, 'espessura_fundo_mm' => 6.0, 'folga_minima_mm' => 80.0 }.freeze
    }.freeze
    LIMITES = { 'espessura_mm' => 12.0..30.0, 'espessura_fundo_mm' => 3.0..12.0,
                'largura_sarrafo_mm' => 50.0..150.0, 'folga_minima_mm' => 40.0..200.0,
                'espessura_gaveta_mm' => 12.0..25.0, 'espessura_fundo_gaveta_mm' => 3.0..12.0,
                'folga_lateral_gaveta_mm' => 5.0..25.0, 'folga_frontal_gaveta_mm' => 0.0..30.0,
                'folga_traseira_gaveta_mm' => 0.0..40.0, 'folga_base_gaveta_mm' => 0.0..30.0,
                'folga_sarrafo_gaveta_mm' => 0.0..30.0, 'folga_vertical_gaveta_mm' => 1.0..20.0,
                'espessura_porta_mm' => 12.0..30.0, 'folga_porta_mm' => 0.0..10.0,
                'recuo_porta_mm' => 0.0..30.0, 'largura_referencia_porta_mm' => 250.0..800.0,
                'espessura_frente_gaveta_mm' => 12.0..30.0, 'folga_frente_gaveta_mm' => 0.0..10.0,
                'recuo_frente_gaveta_mm' => 0.0..30.0 }.freeze

    def initialize(armazenamento = Sketchup)
      @armazenamento = armazenamento
    end

    def ler(categoria)
      dados = carregar
      dados['modos'].fetch(dados['ativo']).fetch(categoria) { raise ArgumentError, 'Categoria construtiva inválida.' }.dup
    end

    def todos
      PADROES.keys.to_h { |categoria| [categoria, ler(categoria)] }
    end

    def salvar(categoria, parametros)
      valores = validar(categoria, parametros)
      dados = carregar
      categorias = dados['modos'].fetch(dados['ativo']).merge(categoria => valores)
      salvar_modo(dados['ativo'], categorias)
      valores
    end

    def carregar
      texto = @armazenamento.read_default('NexMob', 'modos_construtivos', nil)
      return padrao_inicial unless texto

      dados = JSON.parse(texto)
      raise ArgumentError unless dados.is_a?(Hash) && dados['modos'].is_a?(Hash) && dados['modos'].key?(dados['ativo'])

      dados['modos'].each_value do |categorias|
        PADROES.each_key do |categoria|
          categorias[categoria] = validar(categoria, categorias.fetch(categoria, {}))
        end
      end
      dados
    rescue JSON::ParserError, ArgumentError, KeyError, TypeError, NoMethodError
      padrao_inicial
    end

    def salvar_modo(nome, categorias)
      nome = nome.to_s.strip
      raise ArgumentError, 'Dê um nome ao modo construtivo, com até 60 caracteres.' if nome.empty? || nome.length > 60
      raise ArgumentError, 'Configurações inválidas.' unless categorias.is_a?(Hash)

      valores = PADROES.keys.to_h { |categoria| [categoria, validar(categoria, categorias.fetch(categoria, {}))] }
      dados = carregar
      raise ArgumentError, 'Limite de 50 modos salvos.' if dados['modos'].length >= 50 && !dados['modos'].key?(nome)

      dados['modos'][nome] = valores
      dados['ativo'] = nome
      gravar(dados)
    end

    def ativar(nome)
      dados = carregar
      raise ArgumentError, 'Modo construtivo não encontrado.' unless dados['modos'].key?(nome)

      dados['ativo'] = nome
      gravar(dados)
    end

    private

    def padrao_inicial
      { 'ativo' => 'Padrão', 'modos' => { 'Padrão' => PADROES.transform_values(&:dup) } }
    end

    def gravar(dados)
      raise 'Não foi possível salvar os modos construtivos.' unless
        @armazenamento.write_default('NexMob', 'modos_construtivos', JSON.generate(dados))

      dados
    end

    public

    def validar(categoria, parametros)
      padrao = PADROES.fetch(categoria) { raise ArgumentError, 'Categoria construtiva inválida.' }
      raise ArgumentError, 'Configuração inválida.' unless parametros.is_a?(Hash)

      padrao.to_h do |chave, valor_padrao|
        begin
          valor = Float(parametros.fetch(chave, valor_padrao))
        rescue ArgumentError, TypeError
          raise ArgumentError, 'Informe medidas numéricas para o modo construtivo.'
        end
        raise ArgumentError, "Medida fora do intervalo permitido: #{chave}." unless valor.finite? && LIMITES.fetch(chave).cover?(valor)

        [chave, valor]
      end
    end
  end
end
