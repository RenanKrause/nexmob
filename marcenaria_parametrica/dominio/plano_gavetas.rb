require_relative 'plano_balcao_inferior'

module MarcenariaParametrica
  module PlanoGavetas
    DICIONARIO_GAVETAS = 'gavetas_json'.freeze
    ALTURA_MINIMA_MM = 80.0

    def self.ler(grupo)
      texto = grupo.get_attribute(PlanoBalcaoInferior::DICIONARIO_MODULO, DICIONARIO_GAVETAS)
      return [] unless texto

      JSON.parse(texto)
    rescue JSON::ParserError
      raise ArgumentError, 'Os dados das gavetas estão inválidos.'
    end

    def self.planejar(parametros, divisoes, gavetas)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      registros = normalizar(valores, vaos, gavetas)
      validar_registros(valores, vaos, registros)
      registros.flat_map { |gaveta| planejar_caixa(calcular_caixa(valores, vaos.fetch(gaveta['vao_id']), gaveta)) }
    end

    def self.adicionar(parametros, divisoes, gavetas, identificador_vao, quantidade)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      identificador = identificador_vao.to_s
      limites = vaos[identificador]
      raise ArgumentError, 'O vão da gaveta não existe mais.' unless limites

      registros = normalizar(valores, vaos, gavetas)
      raise ArgumentError, 'Já existem gavetas neste vão.' if registros.any? { |gaveta| gaveta['vao_id'] == identificador }

      novos = registros + criar_registros_padrao(valores, limites, identificador, inteiro(quantidade), proximo_conjunto(registros))
      validar_registros(valores, vaos, novos)
      novos
    end

    def self.validas(parametros, divisoes, gavetas)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      normalizar(valores, indice_vaos(valores, divisoes), gavetas, descartar_inexistentes: true)
    end

    def self.representacoes(parametros, divisoes, gavetas)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      registros = normalizar(valores, vaos, gavetas)
      validar_registros(valores, vaos, registros)
      registros.map do |gaveta|
        caixa = calcular_caixa(valores, vaos.fetch(gaveta['vao_id']), gaveta)
        {
          id: gaveta['id'], tipo: 'gaveta', nome: caixa[:nome], vao_id: gaveta['vao_id'],
          limites_mm: [caixa[:x], caixa[:x] + caixa[:largura], caixa[:z], caixa[:z] + caixa[:altura]],
          limites_pai_mm: caixa[:limites_vao], posicao_mm: caixa[:posicao_no_vao],
          altura_mm: caixa[:altura], profundidade_mm: caixa[:profundidade],
          minimo_posicao_mm: valores['folga_base_gaveta_mm'],
          maximo_posicao_mm: caixa[:altura_vao] - valores['folga_sarrafo_gaveta_mm'] - caixa[:altura],
          minimo_altura_mm: ALTURA_MINIMA_MM,
          maximo_altura_mm: caixa[:altura_vao] - caixa[:posicao_no_vao] - valores['folga_sarrafo_gaveta_mm'],
          minimo_profundidade_mm: 2 * valores['espessura_gaveta_mm'] + 1,
          maximo_profundidade_mm: caixa[:profundidade_disponivel]
        }
      end
    end

    def self.mover(parametros, divisoes, gavetas, identificador, posicao_mm)
      valores, vaos, registros = preparar_edicao(parametros, divisoes, gavetas)
      registro = localizar(registros, identificador)
      limites = vaos.fetch(registro['vao_id'])
      registro['proporcao_posicao'] = medida(posicao_mm, 'A posição da gaveta') / (limites[3] - limites[2])
      validar_registros(valores, vaos, registros)
      registros
    end

    def self.redimensionar(parametros, divisoes, gavetas, identificador, posicao_mm, altura_mm, profundidade_mm)
      valores, vaos, registros = preparar_edicao(parametros, divisoes, gavetas)
      registro = localizar(registros, identificador)
      limites = vaos.fetch(registro['vao_id'])
      altura_vao = limites[3] - limites[2]
      profundidade_disponivel = valores['profundidade_mm'] - valores['espessura_fundo_mm'] -
                                valores['folga_frontal_gaveta_mm'] - valores['folga_traseira_gaveta_mm']
      registro['proporcao_posicao'] = medida(posicao_mm, 'A posição da gaveta') / altura_vao
      registro['proporcao_altura'] = medida(altura_mm, 'A altura da gaveta') / altura_vao
      registro['proporcao_profundidade'] = medida(profundidade_mm, 'A profundidade da gaveta') / profundidade_disponivel
      validar_registros(valores, vaos, registros)
      registros
    end

    def self.duplicar(parametros, divisoes, gavetas, identificador)
      valores, vaos, registros = preparar_edicao(parametros, divisoes, gavetas)
      origem = localizar(registros, identificador)
      caixa_origem = calcular_caixa(valores, vaos.fetch(origem['vao_id']), origem)
      limites = vaos.fetch(origem['vao_id'])
      nova = origem.dup
      nova['id'] = proximo_identificador(registros, origem['id'])
      mesmas = registros.select { |gaveta| gaveta['vao_id'] == origem['vao_id'] }
      if mesma_gaveta_ocupa_o_vao?(valores, caixa_origem, mesmas.length)
        altura_vao = limites[3] - limites[2]
        altura = (altura_vao - valores['folga_base_gaveta_mm'] - valores['folga_sarrafo_gaveta_mm'] -
                  valores['folga_vertical_gaveta_mm']) / 2
        origem['proporcao_posicao'] = valores['folga_base_gaveta_mm'] / altura_vao
        origem['proporcao_altura'] = altura / altura_vao
        nova['proporcao_posicao'] = (valores['folga_base_gaveta_mm'] + altura +
                                     valores['folga_vertical_gaveta_mm']) / altura_vao
        nova['proporcao_altura'] = altura / altura_vao
      else
        nova['proporcao_posicao'] = proxima_posicao_livre(valores, vaos, registros, origem['vao_id'], caixa_origem[:altura]) /
                                      (limites[3] - limites[2])
      end
      registros << nova
      validar_registros(valores, vaos, registros)
      registros
    end

    def self.excluir(parametros, divisoes, gavetas, identificador)
      valores, vaos, registros = preparar_edicao(parametros, divisoes, gavetas)
      localizar(registros, identificador)
      restantes = registros.reject { |gaveta| gaveta['id'] == identificador.to_s }
      validar_registros(valores, vaos, restantes)
      restantes
    end

    def self.preparar_edicao(parametros, divisoes, gavetas)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      registros = normalizar(valores, vaos, gavetas)
      validar_registros(valores, vaos, registros)
      [valores, vaos, registros]
    end

    def self.indice_vaos(valores, divisoes)
      PlanoBalcaoInferior.vaos(valores, divisoes).to_h { |vao| [vao[:id], vao[:limites_mm]] }
    end

    def self.normalizar(valores, vaos, gavetas, descartar_inexistentes: false)
      raise ArgumentError, 'Lista de gavetas inválida.' unless gavetas.is_a?(Array)

      registros = gavetas.each_with_index.flat_map do |gaveta, indice|
        normalizar_registro(valores, vaos, gaveta, indice + 1, descartar_inexistentes)
      end
      ids = registros.map { |gaveta| gaveta['id'] }
      raise ArgumentError, 'Há duas gavetas com o mesmo identificador.' unless ids.uniq.length == ids.length

      registros
    end

    def self.normalizar_registro(valores, vaos, gaveta, indice, descartar_inexistentes)
      raise ArgumentError, 'Dados da gaveta inválidos.' unless gaveta.is_a?(Hash)

      identificador_vao = gaveta['vao_id'].to_s
      limites = vaos[identificador_vao]
      return [] if limites.nil? && descartar_inexistentes
      raise ArgumentError, 'O vão da gaveta não existe mais.' unless limites

      if gaveta.key?('quantidade')
        criar_registros_padrao(valores, limites, identificador_vao, inteiro(gaveta['quantidade']), indice)
      else
        identificador = gaveta['id'].to_s
        raise ArgumentError, 'O identificador da gaveta é inválido.' unless identificador.match?(/\Agaveta_\d+_\d+\z/)

        {
          'id' => identificador, 'vao_id' => identificador_vao,
          'proporcao_posicao' => proporcao(gaveta['proporcao_posicao']),
          'proporcao_altura' => proporcao(gaveta['proporcao_altura']),
          'proporcao_profundidade' => proporcao(gaveta['proporcao_profundidade'])
        }
      end
    end

    def self.criar_registros_padrao(valores, limites, identificador_vao, quantidade, conjunto)
      raise ArgumentError, 'Escolha de 1 a 10 gavetas por vão.' unless (1..10).cover?(quantidade)

      altura_vao = limites[3] - limites[2]
      folga_entre = valores['folga_vertical_gaveta_mm']
      altura = (altura_vao - valores['folga_base_gaveta_mm'] - valores['folga_sarrafo_gaveta_mm'] -
                (quantidade - 1) * folga_entre) / quantidade
      quantidade.times.map do |indice|
        posicao = valores['folga_base_gaveta_mm'] + indice * (altura + folga_entre)
        {
          'id' => "gaveta_#{conjunto}_#{indice + 1}", 'vao_id' => identificador_vao,
          'proporcao_posicao' => posicao / altura_vao,
          'proporcao_altura' => altura / altura_vao,
          'proporcao_profundidade' => 1.0
        }
      end
    end

    def self.calcular_caixa(valores, limites, gaveta)
      esquerda, direita, inferior, superior = limites
      espessura = valores['espessura_gaveta_mm']
      folga_lateral = valores['folga_lateral_gaveta_mm']
      altura_vao = superior - inferior
      profundidade_disponivel = valores['profundidade_mm'] - valores['espessura_fundo_mm'] -
                                valores['folga_frontal_gaveta_mm'] - valores['folga_traseira_gaveta_mm']
      largura = direita - esquerda - 2 * folga_lateral
      posicao = gaveta['proporcao_posicao'] * altura_vao
      altura = gaveta['proporcao_altura'] * altura_vao
      profundidade = gaveta['proporcao_profundidade'] * profundidade_disponivel
      {
        id: gaveta['id'], nome: "Gaveta #{gaveta['id'].delete_prefix('gaveta_').tr('_', '.')}", vao_id: gaveta['vao_id'],
        x: esquerda + folga_lateral, y: valores['folga_frontal_gaveta_mm'], z: inferior + posicao,
        largura: largura, profundidade: profundidade, altura: altura, posicao_no_vao: posicao,
        altura_vao: altura_vao, profundidade_disponivel: profundidade_disponivel, limites_vao: limites,
        espessura: espessura, fundo: valores['espessura_fundo_gaveta_mm']
      }
    end

    def self.validar_registros(valores, vaos, registros)
      caixas = registros.map { |gaveta| calcular_caixa(valores, vaos.fetch(gaveta['vao_id']), gaveta) }
      caixas.each do |caixa|
        raise ArgumentError, 'O vão não tem largura suficiente para as laterais da gaveta.' if caixa[:largura] <= 2 * caixa[:espessura]
        raise ArgumentError, 'A profundidade do móvel não comporta a gaveta com os ajustes escolhidos.' if caixa[:profundidade] <= 2 * caixa[:espessura]
        raise ArgumentError, 'A altura mínima de uma gaveta é 80 mm.' if caixa[:altura] < ALTURA_MINIMA_MM
        raise ArgumentError, 'A gaveta precisa manter a folga da base do vão.' if caixa[:posicao_no_vao] < valores['folga_base_gaveta_mm']
        raise ArgumentError, 'A gaveta precisa manter a folga do sarrafo do vão.' if
          caixa[:posicao_no_vao] + caixa[:altura] > caixa[:altura_vao] - valores['folga_sarrafo_gaveta_mm']
      end

      caixas.group_by { |caixa| caixa[:vao_id] }.each_value do |caixas_vao|
        caixas_vao.sort_by { |caixa| caixa[:posicao_no_vao] }.each_cons(2) do |inferior, superior|
          minimo = inferior[:posicao_no_vao] + inferior[:altura] + valores['folga_vertical_gaveta_mm']
          raise ArgumentError, 'As gavetas precisam manter folga entre si.' if superior[:posicao_no_vao] < minimo
        end
      end
    end

    def self.planejar_caixa(caixa)
      largura_interna = caixa[:largura] - 2 * caixa[:espessura]
      profundidade_interna = caixa[:profundidade] - 2 * caixa[:espessura]
      codigo = caixa[:id].upcase
      comum = { gaveta_id: caixa[:id], vao_destino: caixa[:vao_id], fita_borda: 'nenhuma' }
      [
        comum.merge(codigo: "#{codigo}_LATERAL_ESQUERDA", nome: "#{caixa[:nome]} lateral esquerda",
                    posicao_mm: [caixa[:x], caixa[:y], caixa[:z]], dimensoes_mm: [caixa[:espessura], caixa[:profundidade], caixa[:altura]],
                    corte_mm: [caixa[:profundidade], caixa[:altura], caixa[:espessura]], fita_borda: 'frente'),
        comum.merge(codigo: "#{codigo}_LATERAL_DIREITA", nome: "#{caixa[:nome]} lateral direita",
                    posicao_mm: [caixa[:x] + caixa[:largura] - caixa[:espessura], caixa[:y], caixa[:z]], dimensoes_mm: [caixa[:espessura], caixa[:profundidade], caixa[:altura]],
                    corte_mm: [caixa[:profundidade], caixa[:altura], caixa[:espessura]], fita_borda: 'frente'),
        comum.merge(codigo: "#{codigo}_CONTRA_FRENTE", nome: "#{caixa[:nome]} contra frente",
                    posicao_mm: [caixa[:x] + caixa[:espessura], caixa[:y], caixa[:z]], dimensoes_mm: [largura_interna, caixa[:espessura], caixa[:altura]],
                    corte_mm: [largura_interna, caixa[:altura], caixa[:espessura]], fita_borda: 'superior'),
        comum.merge(codigo: "#{codigo}_POSTERIOR", nome: "#{caixa[:nome]} posterior",
                    posicao_mm: [caixa[:x] + caixa[:espessura], caixa[:y] + caixa[:profundidade] - caixa[:espessura], caixa[:z]], dimensoes_mm: [largura_interna, caixa[:espessura], caixa[:altura]],
                    corte_mm: [largura_interna, caixa[:altura], caixa[:espessura]], fita_borda: 'nenhuma'),
        comum.merge(codigo: "#{codigo}_FUNDO", nome: "#{caixa[:nome]} fundo",
                    posicao_mm: [caixa[:x] + caixa[:espessura], caixa[:y] + caixa[:espessura], caixa[:z]], dimensoes_mm: [largura_interna, profundidade_interna, caixa[:fundo]],
                    corte_mm: [largura_interna, profundidade_interna, caixa[:fundo]], fita_borda: 'nenhuma')
      ]
    end

    def self.proxima_posicao_livre(valores, vaos, registros, identificador_vao, altura)
      limites = vaos.fetch(identificador_vao)
      altura_vao = limites[3] - limites[2]
      folga = valores['folga_vertical_gaveta_mm']
      caixas = registros.select { |gaveta| gaveta['vao_id'] == identificador_vao }.map do |gaveta|
        calcular_caixa(valores, limites, gaveta)
      end
      candidatas = [valores['folga_base_gaveta_mm']] + caixas.map { |caixa| caixa[:posicao_no_vao] + caixa[:altura] + folga }
      posicao = candidatas.sort.find do |candidata|
        candidata + altura <= altura_vao - valores['folga_sarrafo_gaveta_mm'] && caixas.none? do |caixa|
          candidata < caixa[:posicao_no_vao] + caixa[:altura] + folga && candidata + altura + folga > caixa[:posicao_no_vao]
        end
      end
      raise ArgumentError, 'Não há espaço livre neste vão para duplicar a gaveta.' unless posicao

      posicao
    end

    def self.mesma_gaveta_ocupa_o_vao?(valores, caixa, quantidade)
      return false unless quantidade == 1

      (caixa[:posicao_no_vao] - valores['folga_base_gaveta_mm']).abs < 0.01 &&
        (caixa[:posicao_no_vao] + caixa[:altura] - (caixa[:altura_vao] - valores['folga_sarrafo_gaveta_mm'])).abs < 0.01
    end

    def self.proximo_conjunto(registros)
      numeros = registros.filter_map { |gaveta| gaveta['id'][/\Agaveta_(\d+)_/, 1]&.to_i }
      (numeros.max || 0) + 1
    end

    def self.proximo_identificador(registros, identificador)
      conjunto = identificador.to_s[/\Agaveta_(\d+)_/, 1]
      raise ArgumentError, 'O identificador da gaveta é inválido.' unless conjunto

      indices = registros.filter_map do |gaveta|
        gaveta['id'][/\Agaveta_#{Regexp.escape(conjunto)}_(\d+)\z/, 1]&.to_i
      end
      "gaveta_#{conjunto}_#{(indices.max || 0) + 1}"
    end

    def self.localizar(registros, identificador)
      registros.find { |gaveta| gaveta['id'] == identificador.to_s } ||
        raise(ArgumentError, 'A gaveta selecionada não existe mais.')
    end

    def self.proporcao(valor)
      numero = medida(valor, 'A proporção da gaveta')
      raise ArgumentError, 'A proporção da gaveta é inválida.' unless numero >= 0 && numero <= 1

      numero
    end

    def self.medida(valor, nome)
      numero = Float(valor)
      raise ArgumentError, "#{nome} deve ser finita." unless numero.finite?

      numero
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{nome} deve ser um número em milímetros."
    end

    def self.inteiro(valor)
      numero = Integer(valor)
      raise ArgumentError unless Float(valor) == numero

      numero
    rescue ArgumentError, TypeError
      raise ArgumentError, 'A quantidade de gavetas deve ser um número inteiro.'
    end
  end
end
