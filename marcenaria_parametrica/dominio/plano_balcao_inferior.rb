require 'json'

module MarcenariaParametrica
  module PlanoBalcaoInferior
    DICIONARIO_MODULO = 'marcenaria_parametrica_modulo'.freeze
    DICIONARIO_PECA = 'marcenaria_parametrica_peca'.freeze
    TIPO = 'balcao_inferior'.freeze
    PADRAO = {
      'largura_mm' => 800.0,
      'altura_mm' => 720.0,
      'profundidade_mm' => 560.0,
      'espessura_mm' => 18.0,
      'espessura_fundo_mm' => 6.0,
      'largura_sarrafo_mm' => 80.0,
      'folga_minima_mm' => 80.0,
      'espessura_gaveta_mm' => 15.0,
      'espessura_fundo_gaveta_mm' => 6.0,
      'folga_lateral_gaveta_mm' => 13.0,
      'folga_frontal_gaveta_mm' => 2.0,
      'folga_traseira_gaveta_mm' => 12.0,
      'folga_base_gaveta_mm' => 3.0,
      'folga_sarrafo_gaveta_mm' => 3.0,
      'folga_vertical_gaveta_mm' => 3.0,
      'espessura_porta_mm' => 18.0,
      'folga_porta_mm' => 2.0,
      'recuo_porta_mm' => 0.0,
      'largura_referencia_porta_mm' => 450.0,
      'espessura_frente_gaveta_mm' => 18.0,
      'folga_frente_gaveta_mm' => 2.0,
      'recuo_frente_gaveta_mm' => 0.0
    }.freeze

    def self.normalizar(parametros)
      raise ArgumentError, 'Parâmetros inválidos.' unless parametros.is_a?(Hash)

      valores = {}
      PADRAO.each_key do |chave|
        valor = parametros.key?(chave) ? parametros[chave] : PADRAO[chave]
        begin
          numero = Float(valor)
        rescue ArgumentError, TypeError
          raise ArgumentError, "#{chave} deve ser um número."
        end
        raise ArgumentError, "#{chave} deve ser finito." unless numero.finite?

        valores[chave] = numero
      end

      largura = valores['largura_mm']
      altura = valores['altura_mm']
      profundidade = valores['profundidade_mm']
      espessura = valores['espessura_mm']
      fundo = valores['espessura_fundo_mm']
      sarrafo = valores['largura_sarrafo_mm']
      folga_minima = valores['folga_minima_mm']
      espessura_gaveta = valores['espessura_gaveta_mm']
      fundo_gaveta = valores['espessura_fundo_gaveta_mm']
      folga_lateral_gaveta = valores['folga_lateral_gaveta_mm']
      folga_frontal_gaveta = valores['folga_frontal_gaveta_mm']
      folga_traseira_gaveta = valores['folga_traseira_gaveta_mm']
      folga_base_gaveta = valores['folga_base_gaveta_mm']
      folga_sarrafo_gaveta = valores['folga_sarrafo_gaveta_mm']
      folga_vertical_gaveta = valores['folga_vertical_gaveta_mm']
      espessura_porta = valores['espessura_porta_mm']
      folga_porta = valores['folga_porta_mm']
      recuo_porta = valores['recuo_porta_mm']
      largura_referencia_porta = valores['largura_referencia_porta_mm']
      espessura_frente_gaveta = valores['espessura_frente_gaveta_mm']
      folga_frente_gaveta = valores['folga_frente_gaveta_mm']
      recuo_frente_gaveta = valores['recuo_frente_gaveta_mm']

      raise ArgumentError, 'Largura fora do intervalo de 300 a 2400 mm.' unless (300.0..2400.0).cover?(largura)
      raise ArgumentError, 'Altura fora do intervalo de 300 a 1200 mm.' unless (300.0..1200.0).cover?(altura)
      raise ArgumentError, 'Profundidade fora do intervalo de 250 a 800 mm.' unless (250.0..800.0).cover?(profundidade)
      raise ArgumentError, 'Espessura da chapa fora do intervalo de 12 a 30 mm.' unless (12.0..30.0).cover?(espessura)
      raise ArgumentError, 'Espessura do fundo fora do intervalo de 3 a 12 mm.' unless (3.0..12.0).cover?(fundo)
      raise ArgumentError, 'Largura dos sarrafos fora do intervalo de 50 a 150 mm.' unless (50.0..150.0).cover?(sarrafo)
      raise ArgumentError, 'A folga mínima dos vãos deve ficar entre 40 e 200 mm.' unless (40.0..200.0).cover?(folga_minima)
      raise ArgumentError, 'Espessura das gavetas fora do intervalo de 12 a 25 mm.' unless (12.0..25.0).cover?(espessura_gaveta)
      raise ArgumentError, 'Espessura do fundo das gavetas fora do intervalo de 3 a 12 mm.' unless (3.0..12.0).cover?(fundo_gaveta)
      raise ArgumentError, 'Folga lateral das gavetas fora do intervalo de 5 a 25 mm.' unless (5.0..25.0).cover?(folga_lateral_gaveta)
      raise ArgumentError, 'Folga frontal das gavetas fora do intervalo de 0 a 30 mm.' unless (0.0..30.0).cover?(folga_frontal_gaveta)
      raise ArgumentError, 'Folga traseira das gavetas fora do intervalo de 0 a 40 mm.' unless (0.0..40.0).cover?(folga_traseira_gaveta)
      raise ArgumentError, 'Folga da base das gavetas fora do intervalo de 0 a 30 mm.' unless (0.0..30.0).cover?(folga_base_gaveta)
      raise ArgumentError, 'Folga do sarrafo das gavetas fora do intervalo de 0 a 30 mm.' unless (0.0..30.0).cover?(folga_sarrafo_gaveta)
      raise ArgumentError, 'Folga vertical das gavetas fora do intervalo de 1 a 20 mm.' unless (1.0..20.0).cover?(folga_vertical_gaveta)
      raise ArgumentError, 'Espessura das portas fora do intervalo de 12 a 30 mm.' unless (12.0..30.0).cover?(espessura_porta)
      raise ArgumentError, 'Folga das portas fora do intervalo de 0 a 10 mm.' unless (0.0..10.0).cover?(folga_porta)
      raise ArgumentError, 'Recuo das portas fora do intervalo de 0 a 30 mm.' unless (0.0..30.0).cover?(recuo_porta)
      raise ArgumentError, 'Largura de referência das portas fora do intervalo de 250 a 800 mm.' unless (250.0..800.0).cover?(largura_referencia_porta)
      raise ArgumentError, 'Espessura das frentes de gaveta fora do intervalo de 12 a 30 mm.' unless (12.0..30.0).cover?(espessura_frente_gaveta)
      raise ArgumentError, 'Folga das frentes de gaveta fora do intervalo de 0 a 10 mm.' unless (0.0..10.0).cover?(folga_frente_gaveta)
      raise ArgumentError, 'Recuo das frentes de gaveta fora do intervalo de 0 a 30 mm.' unless (0.0..30.0).cover?(recuo_frente_gaveta)
      raise ArgumentError, 'Dimensões internas insuficientes.' if largura - 2 * espessura < 150 ||
                                                             altura - 2 * espessura < 150 ||
                                                             profundidade - fundo < 200
      raise ArgumentError, 'Os sarrafos superiores precisam de um intervalo livre.' if
        profundidade - fundo - 2 * sarrafo < 40

      valores
    end

    def self.planejar(parametros, divisoes = [])
      calcular(parametros, divisoes)[0]
    end

    def self.vaos(parametros, divisoes = [])
      calcular(parametros, divisoes)[1]
    end

    def self.adicionar_divisao(parametros, divisoes, identificador_vao, tipo, posicao_mm)
      raise ArgumentError, 'Tipo de divisão inválido.' unless %w[prateleira divisoria].include?(tipo)

      vao = vaos(parametros, divisoes).find { |item| item[:id] == identificador_vao }
      raise ArgumentError, 'O vão selecionado não existe mais.' unless vao

      begin
        posicao = Float(posicao_mm)
      rescue ArgumentError, TypeError
        raise ArgumentError, 'A posição deve ser um número em milímetros.'
      end
      raise ArgumentError, 'A posição deve ser finita.' unless posicao.finite?

      espessura = normalizar(parametros)['espessura_mm']
      esquerda, direita, inferior, superior = vao[:limites_mm]
      extensao = tipo == 'prateleira' ? superior - inferior : direita - esquerda
      proporcao = posicao / (extensao - espessura)
      novas_divisoes = divisoes.map(&:dup) + [
        { 'vao_id' => identificador_vao, 'tipo' => tipo, 'proporcao' => proporcao }
      ]
      calcular(parametros, novas_divisoes)
      novas_divisoes
    end

    def self.ler_divisoes(grupo)
      texto = grupo.get_attribute(DICIONARIO_MODULO, 'divisoes_json')
      return JSON.parse(texto) if texto

      versao = grupo.get_attribute(DICIONARIO_MODULO, 'versao_esquema')
      return [{ 'vao_id' => 'vao', 'tipo' => 'prateleira', 'proporcao' => 0.5 }] if versao == 1

      []
    rescue JSON::ParserError
      raise ArgumentError, 'Os dados dos vãos estão inválidos.'
    end

    def self.calcular(parametros, divisoes)
      valores = normalizar(parametros)
      raise ArgumentError, 'Lista de divisões inválida.' unless divisoes.is_a?(Array)
      raise ArgumentError, 'Limite de 32 divisões por módulo.' if divisoes.length > 32

      largura = valores['largura_mm']
      altura = valores['altura_mm']
      profundidade = valores['profundidade_mm']
      espessura = valores['espessura_mm']
      fundo = valores['espessura_fundo_mm']
      sarrafo = valores['largura_sarrafo_mm']
      folga_minima = valores['folga_minima_mm']
      vao = largura - 2 * espessura
      corpo = profundidade - fundo

      plano = [
        { codigo: 'LATERAL_ESQUERDA', nome: 'Lateral esquerda', posicao_mm: [0.0, 0.0, 0.0],
          dimensoes_mm: [espessura, corpo, altura], corte_mm: [corpo, altura, espessura], fita_borda: 'frente' },
        { codigo: 'LATERAL_DIREITA', nome: 'Lateral direita', posicao_mm: [largura - espessura, 0.0, 0.0],
          dimensoes_mm: [espessura, corpo, altura], corte_mm: [corpo, altura, espessura], fita_borda: 'frente' },
        { codigo: 'BASE', nome: 'Base', posicao_mm: [espessura, 0.0, 0.0],
          dimensoes_mm: [vao, corpo, espessura], corte_mm: [vao, corpo, espessura], fita_borda: 'frente' },
        { codigo: 'SARRAFO_FRONTAL', nome: 'Sarrafo superior frontal', posicao_mm: [espessura, 0.0, altura - espessura],
          dimensoes_mm: [vao, sarrafo, espessura], corte_mm: [vao, sarrafo, espessura], fita_borda: 'frente' },
        { codigo: 'SARRAFO_TRASEIRO', nome: 'Sarrafo superior traseiro', posicao_mm: [espessura, corpo - sarrafo, altura - espessura],
          dimensoes_mm: [vao, sarrafo, espessura], corte_mm: [vao, sarrafo, espessura], fita_borda: 'nenhuma' },
        { codigo: 'FUNDO', nome: 'Fundo', posicao_mm: [0.0, corpo, 0.0],
          dimensoes_mm: [largura, fundo, altura], corte_mm: [largura, altura, fundo], fita_borda: 'nenhuma' }
      ]

      vaos_livres = { 'vao' => [espessura, largura - espessura, espessura, altura - espessura] }
      divisoes.each_with_index do |divisao, indice|
        unless divisao.is_a?(Hash) && divisao['vao_id'].is_a?(String) &&
               %w[prateleira divisoria].include?(divisao['tipo'])
          raise ArgumentError, 'Divisão interna inválida.'
        end
        limites = vaos_livres.delete(divisao['vao_id'])
        raise ArgumentError, 'A divisão aponta para um vão inexistente.' unless limites

        begin
          proporcao = Float(divisao['proporcao'])
        rescue ArgumentError, TypeError
          raise ArgumentError, 'Proporção da divisão inválida.'
        end
        raise ArgumentError, 'Proporção da divisão inválida.' unless proporcao.finite? && proporcao > 0 && proporcao < 1

        esquerda, direita, inferior, superior = limites
        if divisao['tipo'] == 'prateleira'
          extensao = superior - inferior - espessura
          deslocamento = extensao * proporcao
          validar_vaos_resultantes(deslocamento, extensao - deslocamento, folga_minima)
          posicao = inferior + deslocamento
          plano << { codigo: "PRATELEIRA_#{indice + 1}", nome: "Prateleira #{indice + 1}",
                     posicao_mm: [esquerda, 0.0, posicao], dimensoes_mm: [direita - esquerda, corpo, espessura],
                     corte_mm: [direita - esquerda, corpo, espessura], fita_borda: 'frente', vao_id: divisao['vao_id'] }
          vaos_livres["#{divisao['vao_id']}_I"] = [esquerda, direita, inferior, posicao]
          vaos_livres["#{divisao['vao_id']}_S"] = [esquerda, direita, posicao + espessura, superior]
        else
          extensao = direita - esquerda - espessura
          deslocamento = extensao * proporcao
          validar_vaos_resultantes(deslocamento, extensao - deslocamento, folga_minima)
          posicao = esquerda + deslocamento
          plano << { codigo: "DIVISORIA_#{indice + 1}", nome: "Divisória #{indice + 1}",
                     posicao_mm: [posicao, 0.0, inferior], dimensoes_mm: [espessura, corpo, superior - inferior],
                     corte_mm: [corpo, superior - inferior, espessura], fita_borda: 'frente', vao_id: divisao['vao_id'] }
          vaos_livres["#{divisao['vao_id']}_E"] = [esquerda, posicao, inferior, superior]
          vaos_livres["#{divisao['vao_id']}_D"] = [posicao + espessura, direita, inferior, superior]
        end
      end

      [plano, vaos_livres.map { |identificador, limites| { id: identificador, limites_mm: limites } }]
    end

    def self.validar_vaos_resultantes(primeiro, segundo, folga_minima = 80.0)
      raise ArgumentError, "Cada lado da divisão precisa ter ao menos #{folga_minima.round} mm livres." if
        primeiro < folga_minima || segundo < folga_minima
    end

  end
end
