require_relative 'plano_balcao_inferior'

module MarcenariaParametrica
  # Opera sobre o plano em milímetros; nenhuma alteração no modelo ocorre aqui.
  module EdicaoDivisoes
    def self.pecas(parametros, divisoes)
      plano = PlanoBalcaoInferior.planejar(parametros, divisoes)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      espessura = valores['espessura_mm']
      folga = valores['folga_minima_mm']
      divisoes.each_with_index.map do |divisao, indice|
        chapa = plano[6 + indice]
        x, _y, z = chapa[:posicao_mm]
        largura, _profundidade, altura = chapa[:dimensoes_mm]
        pai = PlanoBalcaoInferior.vaos(parametros, divisoes.take(indice)).find { |vao| vao[:id] == divisao['vao_id'] }
        limites = pai[:limites_mm]
        horizontal = divisao['tipo'] == 'prateleira'
        inicio = horizontal ? limites[2] : limites[0]
        tamanho_pai = horizontal ? limites[3] - limites[2] : limites[1] - limites[0]
        {
          id: divisao['vao_id'], tipo: divisao['tipo'], nome: chapa[:nome],
          limites_mm: [x, x + largura, z, z + altura], limites_pai_mm: limites,
          posicao_mm: horizontal ? z : x,
          vao_livre_mm: (horizontal ? z : x) - inicio,
          minimo_vao_mm: folga,
          maximo_vao_mm: tamanho_pai - espessura - folga,
          minimo_mm: (horizontal ? limites[2] : limites[0]) + folga,
          maximo_mm: (horizontal ? limites[3] : limites[1]) - espessura - folga,
          dependentes: divisoes.count { |outra| outra['vao_id'].start_with?(divisao['vao_id'] + '_') }
        }
      end
    end

    def self.mover(parametros, divisoes, identificador, posicao_mm)
      peca = localizar(parametros, divisoes, identificador)
      posicao = Float(posicao_mm)
      raise ArgumentError, 'Digite uma posição finita em milímetros.' unless posicao.finite?

      esquerda, direita, inferior, superior = peca[:limites_pai_mm]
      espessura = PlanoBalcaoInferior.normalizar(parametros)['espessura_mm']
      inicio, fim = peca[:tipo] == 'prateleira' ? [inferior, superior] : [esquerda, direita]
      novas = divisoes.map(&:dup)
      novas.find { |divisao| divisao['vao_id'] == identificador }['proporcao'] = (posicao - inicio) / (fim - inicio - espessura)
      PlanoBalcaoInferior.calcular(parametros, novas)
      novas
    end

    def self.mover_por_vao(parametros, divisoes, identificador, medida_livre_mm)
      peca = localizar(parametros, divisoes, identificador)
      begin
        medida = Float(medida_livre_mm)
      rescue ArgumentError, TypeError
        raise ArgumentError, 'A medida do vão deve ser um número em milímetros.'
      end
      raise ArgumentError, 'Digite uma medida finita em milímetros.' unless medida.finite?

      inicio = peca[:limites_pai_mm][peca[:tipo] == 'prateleira' ? 2 : 0]
      mover(parametros, divisoes, identificador, inicio + medida)
    end

    def self.adicionar_multiplas(parametros, divisoes, identificador_vao, tipo, primeira_medida_mm, quantidade)
      raise ArgumentError, 'Tipo de divisão inválido.' unless %w[prateleira divisoria].include?(tipo)

      begin
        numero = Integer(quantidade)
        raise ArgumentError unless Float(quantidade) == numero
      rescue ArgumentError, TypeError
        raise ArgumentError, 'A quantidade deve ser um número inteiro.'
      end
      raise ArgumentError, 'Escolha de 1 a 10 peças por vez.' unless (1..10).cover?(numero)

      vao = PlanoBalcaoInferior.vaos(parametros, divisoes).find { |item| item[:id] == identificador_vao }
      raise ArgumentError, 'O vão selecionado não existe mais.' unless vao

      begin
        primeira = Float(primeira_medida_mm)
      rescue ArgumentError, TypeError
        raise ArgumentError, 'A primeira medida deve ser um número em milímetros.'
      end
      raise ArgumentError, 'A primeira medida deve ser finita.' unless primeira.finite?

      espessura = PlanoBalcaoInferior.normalizar(parametros)['espessura_mm']
      esquerda, direita, inferior, superior = vao[:limites_mm]
      extensao = tipo == 'prateleira' ? superior - inferior : direita - esquerda
      restante = (extensao - primeira - numero * espessura) / numero
      folga = PlanoBalcaoInferior.normalizar(parametros)['folga_minima_mm']
      if primeira < folga || restante < folga
        raise ArgumentError, "Cada vão resultante precisa de ao menos #{folga.round} mm livres. Reduza a quantidade ou a primeira medida."
      end

      novas = divisoes.map(&:dup)
      atual = identificador_vao
      numero.times do |indice|
        distancia = indice.zero? ? primeira : restante
        novas = PlanoBalcaoInferior.adicionar_divisao(parametros, novas, atual, tipo, distancia)
        atual += tipo == 'prateleira' ? '_S' : '_D'
      end
      novas
    end

    def self.duplicar(parametros, divisoes, identificador)
      peca = localizar(parametros, divisoes, identificador)
      horizontal = peca[:tipo] == 'prateleira'
      espessura = PlanoBalcaoInferior.normalizar(parametros)['espessura_mm']
      folga = PlanoBalcaoInferior.normalizar(parametros)['folga_minima_mm']
      limites = peca[:limites_mm]
      candidatos = PlanoBalcaoInferior.vaos(parametros, divisoes).select do |vao|
        esquerda, direita, inferior, superior = vao[:limites_mm]
        mesma_extensao = horizontal ? (esquerda - limites[0]).abs < 0.01 && (direita - limites[1]).abs < 0.01 :
                                     (inferior - limites[2]).abs < 0.01 && (superior - limites[3]).abs < 0.01
        tamanho = horizontal ? superior - inferior : direita - esquerda
        vao[:id].start_with?(identificador + '_') && mesma_extensao && tamanho >= 2 * folga + espessura
      end
      # Prefere acima/à direita; usa o outro lado quando não houver espaço.
      vao = candidatos.min_by do |candidato|
        inicio = candidato[:limites_mm][horizontal ? 2 : 0]
        [inicio >= peca[:posicao_mm] ? 0 : 1, (inicio - peca[:posicao_mm]).abs]
      end
      raise ArgumentError, 'Não há vão adjacente livre para uma cópia com a mesma extensão.' unless vao

      esquerda, direita, inferior, superior = vao[:limites_mm]
      tamanho = horizontal ? superior - inferior : direita - esquerda
      PlanoBalcaoInferior.adicionar_divisao(parametros, divisoes, vao[:id], peca[:tipo], (tamanho - espessura) / 2)
    end

    def self.excluir(parametros, divisoes, identificador)
      localizar(parametros, divisoes, identificador)
      novas = divisoes.reject do |divisao|
        divisao['vao_id'] == identificador || divisao['vao_id'].start_with?(identificador + '_')
      end.map(&:dup)
      PlanoBalcaoInferior.calcular(parametros, novas)
      novas
    end

    def self.localizar(parametros, divisoes, identificador)
      pecas(parametros, divisoes).find { |peca| peca[:id] == identificador } ||
        raise(ArgumentError, 'A peça selecionada não existe mais.')
    end

    def self.bordas(vao, pecas)
      esquerda, direita, inferior, superior = vao[:limites_mm]
      pecas.filter_map do |peca|
        lado = nil
        inicio_x, fim_x, inicio_z, fim_z = peca[:limites_mm]
        if peca[:tipo] == 'prateleira' && inicio_x <= esquerda + 0.01 && fim_x >= direita - 0.01
          lado = :inferior if (fim_z - inferior).abs < 0.01
          lado = :superior if (inicio_z - superior).abs < 0.01
          posicao = [(esquerda + direita) / 2, lado == :inferior ? inferior : superior]
        elsif peca[:tipo] == 'divisoria' && inicio_z <= inferior + 0.01 && fim_z >= superior - 0.01
          lado = :esquerda if (fim_x - esquerda).abs < 0.01
          lado = :direita if (inicio_x - direita).abs < 0.01
          posicao = [lado == :esquerda ? esquerda : direita, (inferior + superior) / 2]
        end
        { lado: lado, posicao_mm: posicao, peca: peca } if lado
      end
    end
  end
end
