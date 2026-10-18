require_relative '../dominio/dados_projeto'
require_relative '../dominio/identidade_peca'

module MarcenariaParametrica
  module CatalogoPecas
    DICIONARIO_MODULO = PlanoBalcaoInferior::DICIONARIO_MODULO
    DICIONARIO_PECA = PlanoBalcaoInferior::DICIONARIO_PECA
    MM_POR_POLEGADA = 25.4

    class << self
      def listar(modelo)
        projeto = DadosProjeto.ler(modelo)
        ambientes = projeto['ambientes'].to_h { |ambiente| [ambiente['id'], ambiente['nome']] }
        itens = []
        percorrer_modulos(modelo.entities, Geom::Transformation.new, [], itens, projeto, ambientes)
        itens
      end

      private

      # O caminho de definições evita ciclos sem apagar ocorrências de componentes.
      def percorrer_modulos(entidades, acumulada, caminho, itens, projeto, ambientes)
        return if caminho.include?(entidades.object_id)

        entidades.each do |entidade|
          next unless recipiente?(entidade) && disponivel?(entidade)

          transformacao = acumulada * entidade.transformation
          filhos = entidades_de(entidade)
          if ModuloParametrico.reconhecido?(entidade) && ModuloParametrico.editavel?(entidade)
            percorrer_pecas(filhos, transformacao, [], entidade, itens, projeto, ambientes)
          end
          percorrer_modulos(filhos, transformacao, caminho + [entidades.object_id], itens, projeto, ambientes)
        end
      end

      def percorrer_pecas(entidades, acumulada, caminho, modulo, itens, projeto, ambientes)
        return if caminho.include?(entidades.object_id)

        entidades.each do |entidade|
          next unless recipiente?(entidade) && disponivel?(entidade)
          next if ModuloParametrico.reconhecido?(entidade)

          transformacao = acumulada * entidade.transformation
          codigo = entidade.get_attribute(DICIONARIO_PECA, 'codigo')
          if codigo.is_a?(String) && !codigo.strip.empty?
            item = item_para(entidade, modulo, transformacao, projeto, ambientes)
            itens << item if item
          else
            percorrer_pecas(entidades_de(entidade), transformacao, caminho + [entidades.object_id],
                           modulo, itens, projeto, ambientes)
          end
        end
      end

      def recipiente?(entidade)
        entidade.is_a?(Sketchup::Group) ||
          (defined?(Sketchup::ComponentInstance) && entidade.is_a?(Sketchup::ComponentInstance))
      end

      def disponivel?(entidade)
        entidade.valid? && !entidade.locked? && !entidade.hidden? && entidade.layer.visible?
      end

      def entidades_de(entidade)
        entidade.is_a?(Sketchup::Group) ? entidade.entities : entidade.definition.entities
      end

      def item_para(peca, modulo, transformacao, projeto, ambientes)
        corte = %w[comprimento_mm largura_mm espessura_mm].map do |chave|
          peca.get_attribute(DICIONARIO_PECA, chave)
        end
        return unless corte.all? { |valor| positivo?(valor) }

        bounds = peca.definition.bounds
        eixos = [transformacao.xaxis, transformacao.yaxis, transformacao.zaxis]
        return unless caixa_representavel?(eixos)

        dimensoes = [bounds.width, bounds.height, bounds.depth].zip(eixos).map do |medida, eixo|
          medida.to_f * eixo.length * MM_POR_POLEGADA
        end
        return unless dimensoes.all? { |valor| positivo?(valor) }

        centro = bounds.center.transform(transformacao)
        posicao = [centro.x, centro.y, centro.z].map { |valor| valor.to_f * MM_POR_POLEGADA }
        rotacao = Math.atan2(eixos[0].y, eixos[0].x) * 180.0 / Math::PI
        return unless (posicao + [rotacao]).all? { |valor| numero?(valor) }

        identidade = identidade_para(peca)
        ambiente_id = modulo.get_attribute(DICIONARIO_MODULO, 'ambiente_id', '')
        nome = peca.get_attribute(DICIONARIO_PECA, 'nome')
        nome = peca.name if !nome.is_a?(String) || nome.strip.empty?
        codigo = peca.get_attribute(DICIONARIO_PECA, 'codigo')
        nome = codigo if !nome.is_a?(String) || nome.strip.empty?
        fita = peca.get_attribute(DICIONARIO_PECA, 'fita_borda', 'nenhuma')
        {
          modulo: modulo, peca: peca, modulo_id: modulo.get_attribute(DICIONARIO_MODULO, 'modulo_uuid'),
          modulo_nome: ModuloParametrico.nome_exibicao(modulo), ambiente_id: ambiente_id,
          ambiente: ambientes.fetch(ambiente_id, ''), cliente: projeto['cliente'],
          codigo: codigo, nome: nome, chave_logica: identidade['chave_logica'], qr_token: identidade['qr_token'],
          corte_mm: corte.map(&:to_f), dimensoes_mm: dimensoes, transform_mm: posicao + [rotacao],
          material: IdentidadePeca.material_efetivo(peca), fita_borda: fita,
          edge_banding: fitas(fita), visible: true
        }
      rescue ArgumentError, TypeError
        # Uma chapa legada inválida não impede etiquetas das outras peças.
        nil
      end

      def identidade_para(grupo)
        chave = grupo.get_attribute(DICIONARIO_PECA, 'chave_logica')
        token = grupo.get_attribute(DICIONARIO_PECA, 'qr_token')
        unless chave.is_a?(String) && !chave.strip.empty?
          dados = { codigo: grupo.get_attribute(DICIONARIO_PECA, 'codigo') }
          IdentidadePeca::ORIGENS.each { |origem, atributo| dados[origem] = grupo.get_attribute(DICIONARIO_PECA, atributo) }
          chave = IdentidadePeca.chave_logica(dados)
          grupo.set_attribute(DICIONARIO_PECA, 'chave_logica', chave)
        end
        unless token.is_a?(String) && token.match?(/\A[0-9a-fA-F]{32}\z/)
          token = SecureRandom.hex(16)
          grupo.set_attribute(DICIONARIO_PECA, 'qr_token', token)
        end
        { 'chave_logica' => chave, 'qr_token' => token }
      end

      def caixa_representavel?(eixos)
        return false unless eixos.all? { |eixo| positivo?(eixo.length) }

        x, y, z = eixos
        # RevisionV1 comporta escala e rotação Z, mas não inclinação ou cisalhamento.
        tolerancia = 1.0e-6
        x.z.abs <= tolerancia * x.length && y.z.abs <= tolerancia * y.length &&
          z.x.abs <= tolerancia * z.length && z.y.abs <= tolerancia * z.length &&
          x.dot(y).abs <= tolerancia * x.length * y.length
      end

      def numero?(valor)
        valor.is_a?(Numeric) && valor.real? && valor.finite?
      end

      def positivo?(valor)
        numero?(valor) && valor > 0
      end

      # No desenho de fabricação, a borda frontal é a borda superior (top).
      def fitas(valor)
        { 'top' => %w[frente todos].include?(valor), 'right' => valor == 'todos',
          'bottom' => valor == 'todos', 'left' => valor == 'todos' }
      end
    end
  end
end
