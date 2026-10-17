require_relative 'plano_balcao_inferior'
require_relative 'plano_gavetas'

module MarcenariaParametrica
  module PlanoFrentes
    DICIONARIO_FRENTES = 'frentes_json'.freeze
    TIPOS = %w[portas frentes_gavetas].freeze

    def self.ler(grupo)
      texto = grupo.get_attribute(PlanoBalcaoInferior::DICIONARIO_MODULO, DICIONARIO_FRENTES)
      return [] unless texto

      JSON.parse(texto)
    rescue JSON::ParserError
      raise ArgumentError, 'Os dados das frentes estão inválidos.'
    end

    def self.definir(parametros, divisoes, gavetas, frentes, dados)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      registro = normalizar_registro(valores, vaos, divisoes, gavetas, dados, 1)
      atuais = normalizar(valores, vaos, divisoes, gavetas, frentes)
      novas = atuais.reject { |frente| frente['vao_id'] == registro['vao_id'] } + [registro]
      validar_registros(valores, vaos, divisoes, gavetas, novas)
      novas
    end

    def self.validas(parametros, divisoes, gavetas, frentes)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      normalizar(valores, vaos, divisoes, gavetas, frentes, descartar_inexistentes: true)
    end

    def self.sincronizar_com_modo(parametros, divisoes, gavetas, frentes)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      validas = normalizar(valores, vaos, divisoes, gavetas, frentes, descartar_inexistentes: true)
      normalizar(valores, vaos, divisoes, gavetas, validas.map do |frente|
        frente.merge(padroes_para(valores, frente['tipo']))
      end)
    end

    def self.planejar(parametros, divisoes, gavetas, frentes)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      vaos = indice_vaos(valores, divisoes)
      registros = normalizar(valores, vaos, divisoes, gavetas, frentes)
      validar_registros(valores, vaos, divisoes, gavetas, registros)
      registros.flat_map do |frente|
        frente['tipo'] == 'portas' ? planejar_portas(vaos.fetch(frente['vao_id']), frente) :
          planejar_frentes_gavetas(valores, divisoes, gavetas, frente)
      end
    end

    def self.indice_vaos(valores, divisoes)
      PlanoBalcaoInferior.vaos(valores, divisoes).to_h { |vao| [vao[:id], vao[:limites_mm]] }
    end

    def self.quantidade_portas_sugerida(parametros, largura_mm)
      valores = PlanoBalcaoInferior.normalizar(parametros)
      [[(Float(largura_mm) / valores['largura_referencia_porta_mm']).ceil, 1].max, 4].min
    rescue ArgumentError, TypeError
      raise ArgumentError, 'A largura do vão deve ser uma medida válida.'
    end

    def self.normalizar(valores, vaos, divisoes, gavetas, frentes, descartar_inexistentes: false)
      raise ArgumentError, 'Lista de frentes inválida.' unless frentes.is_a?(Array)

      registros = frentes.each_with_index.filter_map do |frente, indice|
        normalizar_registro(valores, vaos, divisoes, gavetas, frente, indice + 1, descartar_inexistentes)
      end
      vaos_destino = registros.map { |frente| frente['vao_id'] }
      raise ArgumentError, 'Cada vão pode ter apenas uma composição de frentes.' unless vaos_destino.uniq.length == vaos_destino.length

      registros
    end

    def self.normalizar_registro(valores, vaos, divisoes, gavetas, frente, _indice, descartar_inexistentes = false)
      raise ArgumentError, 'Dados da frente inválidos.' unless frente.is_a?(Hash)

      vao_id = frente['vao_id'].to_s
      return nil if !vaos.key?(vao_id) && descartar_inexistentes
      raise ArgumentError, 'O vão da frente não existe mais.' unless vaos.key?(vao_id)

      tipo = frente['tipo'].to_s
      raise ArgumentError, 'Tipo de frente inválido.' unless TIPOS.include?(tipo)
      if tipo == 'frentes_gavetas' && gavetas_do_vao(valores, divisoes, gavetas, vao_id).empty?
        return nil if descartar_inexistentes
        raise ArgumentError, 'Adicione ao menos uma gaveta antes de criar frentes de gaveta.'
      end

      padroes = padroes_para(valores, tipo)
      quantidade = tipo == 'portas' ? inteiro(frente.fetch('quantidade', quantidade_portas_sugerida(valores, vaos.fetch(vao_id)[1] - vaos.fetch(vao_id)[0]))) : nil
      raise ArgumentError, 'Escolha de 1 a 4 portas por vão.' if quantidade && !(1..4).cover?(quantidade)
      {
        'id' => frente.fetch('id', "frente_#{vao_id.gsub(/[^a-zA-Z0-9]+/, '_')}").to_s,
        'vao_id' => vao_id, 'tipo' => tipo, 'quantidade' => quantidade,
        'espessura_mm' => medida(frente.fetch('espessura_mm', padroes['espessura_mm']), 'A espessura da frente', 12.0..30.0),
        'folga_mm' => medida(frente.fetch('folga_mm', padroes['folga_mm']), 'A folga da frente', 0.0..10.0),
        'recuo_mm' => medida(frente.fetch('recuo_mm', padroes['recuo_mm']), 'O recuo da frente', 0.0..30.0)
      }.compact
    end

    def self.padroes_para(valores, tipo)
      if tipo == 'portas'
        { 'espessura_mm' => valores['espessura_porta_mm'], 'folga_mm' => valores['folga_porta_mm'],
          'recuo_mm' => valores['recuo_porta_mm'] }
      else
        { 'espessura_mm' => valores['espessura_frente_gaveta_mm'], 'folga_mm' => valores['folga_frente_gaveta_mm'],
          'recuo_mm' => valores['recuo_frente_gaveta_mm'] }
      end
    end

    def self.validar_registros(valores, vaos, divisoes, gavetas, registros)
      registros.each do |frente|
        pecas = frente['tipo'] == 'portas' ? planejar_portas(vaos.fetch(frente['vao_id']), frente) :
          planejar_frentes_gavetas(valores, divisoes, gavetas, frente)
        raise ArgumentError, 'As folgas deixam as frentes sem área útil.' if pecas.any? do |peca|
          peca[:dimensoes_mm][0] <= 0 || peca[:dimensoes_mm][2] <= 0
        end
      end
    end

    def self.planejar_portas(limites, frente)
      esquerda, direita, inferior, superior = limites
      quantidade = frente['quantidade']
      largura = (direita - esquerda - (quantidade + 1) * frente['folga_mm']) / quantidade
      altura = superior - inferior - 2 * frente['folga_mm']
      quantidade.times.map do |indice|
        codigo = "PORTA_#{frente['id'].upcase}_#{indice + 1}"
        {
          codigo: codigo, nome: "Porta #{indice + 1}", frente_id: frente['id'], vao_destino: frente['vao_id'],
          posicao_mm: [esquerda + frente['folga_mm'] + indice * (largura + frente['folga_mm']), -frente['espessura_mm'] + frente['recuo_mm'], inferior + frente['folga_mm']],
          dimensoes_mm: [largura, frente['espessura_mm'], altura], corte_mm: [largura, altura, frente['espessura_mm']], fita_borda: 'todos'
        }
      end
    end

    def self.planejar_frentes_gavetas(valores, divisoes, gavetas, frente)
      gavetas_do_vao(valores, divisoes, gavetas, frente['vao_id']).sort_by { |gaveta| gaveta[:posicao_mm] }.map do |gaveta|
        esquerda, direita, inferior, superior = gaveta[:limites_pai_mm]
        largura = direita - esquerda - 2 * frente['folga_mm']
        altura = gaveta[:altura_mm] - 2 * frente['folga_mm']
        {
          codigo: "FRENTE_#{gaveta[:id].upcase}", nome: "Frente #{gaveta[:nome]}", frente_id: frente['id'],
          gaveta_destino: gaveta[:id], vao_destino: frente['vao_id'],
          posicao_mm: [esquerda + frente['folga_mm'], -frente['espessura_mm'] + frente['recuo_mm'],
                        inferior + gaveta[:posicao_mm] + frente['folga_mm']],
          dimensoes_mm: [largura, frente['espessura_mm'], altura], corte_mm: [largura, altura, frente['espessura_mm']], fita_borda: 'todos'
        }
      end
    end

    def self.gavetas_do_vao(valores, divisoes, gavetas, vao_id)
      PlanoGavetas.representacoes(valores, divisoes, gavetas).select { |gaveta| gaveta[:vao_id] == vao_id }
    end

    def self.medida(valor, nome, intervalo)
      numero = Float(valor)
      raise ArgumentError, "#{nome} deve ser finita." unless numero.finite?
      raise ArgumentError, "#{nome} está fora do intervalo permitido." unless intervalo.cover?(numero)

      numero
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{nome} deve ser uma medida válida em milímetros."
    end

    def self.inteiro(valor)
      numero = Integer(valor)
      raise ArgumentError unless Float(valor) == numero

      numero
    rescue ArgumentError, TypeError
      raise ArgumentError, 'A quantidade de portas deve ser um número inteiro.'
    end
  end
end
