require_relative '../dominio/plano_balcao_inferior'
require_relative '../dominio/plano_gavetas'
require_relative '../dominio/plano_frentes'
require_relative '../dominio/modulo_parametrico'
require_relative 'fabrica_chapas'

module MarcenariaParametrica
  class ConstrutorBalcaoInferior
    DICIONARIO_MODULO = PlanoBalcaoInferior::DICIONARIO_MODULO
    DICIONARIO_PECA = PlanoBalcaoInferior::DICIONARIO_PECA
    TIPO = PlanoBalcaoInferior::TIPO
    PADRAO = PlanoBalcaoInferior::PADRAO

    def self.normalizar(*argumentos)
      PlanoBalcaoInferior.normalizar(*argumentos)
    end

    def self.planejar(*argumentos)
      PlanoBalcaoInferior.planejar(*argumentos)
    end

    def self.vaos(*argumentos)
      PlanoBalcaoInferior.vaos(*argumentos)
    end

    def self.adicionar_divisao(*argumentos)
      PlanoBalcaoInferior.adicionar_divisao(*argumentos)
    end

    def self.ler_divisoes(*argumentos)
      PlanoBalcaoInferior.ler_divisoes(*argumentos)
    end

    def initialize(modelo)
      @modelo = modelo
    end

    def construir(parametros, ponto)
      valores = self.class.normalizar(parametros)
      divisoes = []
      plano = self.class.planejar(valores, divisoes)
      @modelo.start_operation('Inserir balcão inferior', true)
      operacao_iniciada = true
      grupo = @modelo.active_entities.add_group
      grupo.name = 'Balcão inferior'
      preencher(grupo, plano, valores, divisoes, [], [])
      grupo.transformation = Geom::Transformation.new(ponto)
      @modelo.commit_operation
      operacao_iniciada = false
      grupo
    rescue StandardError
      @modelo.abort_operation if operacao_iniciada
      raise
    end

    def atualizar(grupo, parametros, divisoes = nil, gavetas: nil, frentes: nil, gerenciar_operacao: true)
      unless grupo.is_a?(Sketchup::Group) && grupo.valid? && !grupo.locked? &&
             grupo.get_attribute(DICIONARIO_MODULO, 'tipo') == TIPO
        raise ArgumentError, 'Selecione um balcão inferior válido.'
      end

      valores = self.class.normalizar(parametros)
      divisoes = self.class.ler_divisoes(grupo) if divisoes.nil?
      gavetas ||= PlanoGavetas.ler(grupo)
      gavetas = PlanoGavetas.validas(valores, divisoes, gavetas)
      frentes ||= PlanoFrentes.ler(grupo)
      frentes = PlanoFrentes.validas(valores, divisoes, gavetas, frentes)
      plano = self.class.planejar(valores, divisoes)
      @modelo.start_operation('Editar balcão inferior', true) if gerenciar_operacao
      operacao_iniciada = gerenciar_operacao
      grupo.make_unique
      grupo.entities.clear!
      preencher(grupo, plano, valores, divisoes, gavetas, frentes)
      @modelo.commit_operation if gerenciar_operacao
      operacao_iniciada = false
      grupo
    rescue StandardError
      @modelo.abort_operation if operacao_iniciada
      raise
    end

    private

    def preencher(grupo, plano, valores, divisoes, gavetas, frentes)
      pecas = plano + PlanoGavetas.planejar(valores, divisoes, gavetas) + PlanoFrentes.planejar(valores, divisoes, gavetas, frentes)
      pecas.each { |peca| FabricaChapas.criar(grupo.entities, peca) }
      grupo.set_attribute(DICIONARIO_MODULO, 'tipo', TIPO)
      ModuloParametrico.inicializar(grupo)
      grupo.set_attribute(DICIONARIO_MODULO, 'versao_esquema', 2)
      grupo.set_attribute(DICIONARIO_MODULO, 'divisoes_json', JSON.generate(divisoes))
      grupo.set_attribute(DICIONARIO_MODULO, PlanoGavetas::DICIONARIO_GAVETAS, JSON.generate(gavetas))
      grupo.set_attribute(DICIONARIO_MODULO, PlanoFrentes::DICIONARIO_FRENTES, JSON.generate(frentes))
      valores.each { |chave, valor| grupo.set_attribute(DICIONARIO_MODULO, chave, valor) }
    end

  end
end
