require 'minitest/autorun'
require 'json'
require_relative '../marcenaria_parametrica/dominio/dados_projeto'

module Sketchup
  class Group
    attr_accessor :name, :locked
    attr_reader :model, :entities

    def initialize(modelo)
      @model = modelo
      @name = ''
      @locked = false
      @entities = []
      @atributos = {}
    end

    def valid?
      true
    end

    def locked?
      @locked
    end

    def get_attribute(dicionario, chave, padrao = nil)
      @atributos.fetch([dicionario, chave], padrao)
    end

    def set_attribute(dicionario, chave, valor)
      @atributos[[dicionario, chave]] = valor
    end
  end

  class ComponentInstance
    attr_reader :definition

    def initialize(entidades)
      @definition = Struct.new(:entities).new(entidades)
    end

    def valid?
      true
    end
  end
end

class ModeloDadosProjetoDeTeste
  attr_reader :entities, :dicionarios

  def initialize(dicionarios = {})
    @dicionarios = dicionarios
    @entities = []
  end

  def attribute_dictionary(nome, criar = false)
    @dicionarios[nome] ||= {} if criar
    @dicionarios[nome]
  end
end

class TesteDadosProjeto < Minitest::Test
  DICIONARIO_PROJETO = 'nex_mob_projeto'.freeze
  DICIONARIO_MODULO = 'marcenaria_parametrica_modulo'.freeze
  UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

  def setup
    @modelo = ModeloDadosProjetoDeTeste.new
    @dados = MarcenariaParametrica::DadosProjeto
    @modulo = MarcenariaParametrica::ModuloParametrico
  end

  def adicionar_modulo(entidades = @modelo.entities)
    grupo = Sketchup::Group.new(@modelo)
    grupo.set_attribute(DICIONARIO_MODULO, 'tipo', 'balcao_inferior')
    entidades << grupo
    grupo
  end

  def test_projeto_recebe_uuid_estavel_e_valores_iniciais
    projeto = @dados.ler(@modelo)

    assert_match UUID, projeto['projeto_uuid']
    assert_equal '', projeto['cliente']
    assert_empty projeto['ambientes']
    assert_equal projeto, @dados.ler(@modelo)
    assert_equal projeto['projeto_uuid'], @modelo.attribute_dictionary(DICIONARIO_PROJETO)['projeto_uuid']
  end

  def test_cliente_e_ambientes_sobrevivem_a_releitura_do_armazenamento_do_skp
    @dados.salvar_cliente(@modelo, '  José & Filhos "Móveis"  ')
    ambiente = @dados.criar_ambiente(@modelo, ' Cozinha ')
    reaberto = ModeloDadosProjetoDeTeste.new(JSON.parse(JSON.generate(@modelo.dicionarios)))

    assert_match UUID, ambiente['id']
    assert_equal 'Cozinha', ambiente['nome']
    assert_equal 'José & Filhos "Móveis"', @dados.ler(reaberto)['cliente']
    assert_equal [ambiente], @dados.ler(reaberto)['ambientes']
    assert_equal [ambiente], JSON.parse(reaberto.attribute_dictionary(DICIONARIO_PROJETO)['ambientes_json'])
  end

  def test_renomear_preserva_id_e_associacao_de_dois_modulos
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    grupos = [adicionar_modulo, adicionar_modulo]
    grupos.each { |grupo| @dados.atribuir_ambiente(grupo, ambiente['id']) }

    @dados.renomear_ambiente(@modelo, ambiente['id'], 'Copa')

    assert_equal [{ 'id' => ambiente['id'], 'nome' => 'Copa' }], @dados.ler(@modelo)['ambientes']
    grupos.each { |grupo| assert_equal ambiente['id'], grupo.get_attribute(DICIONARIO_MODULO, 'ambiente_id') }
    identificadores = grupos.map { |grupo| grupo.get_attribute(DICIONARIO_MODULO, 'modulo_uuid') }
    identificadores.each { |id| assert_match UUID, id }
    assert_equal 2, identificadores.uniq.length
  end

  def test_rejeita_nome_vazio_ou_duplicado_sem_mudar_o_projeto
    @dados.criar_ambiente(@modelo, 'Cozinha')
    antes = @dados.ler(@modelo)

    [nil, '', " \t\n", ' cozinha ', 'COZINHA'].each do |nome|
      assert_raises(ArgumentError) { @dados.criar_ambiente(@modelo, nome) }
    end

    assert_equal antes, @dados.ler(@modelo)
  end

  def test_renomear_rejeita_nome_vazio_duplicado_e_ambiente_desconhecido
    cozinha = @dados.criar_ambiente(@modelo, 'Cozinha')
    sala = @dados.criar_ambiente(@modelo, 'Sala')
    antes = @dados.ler(@modelo)

    assert_raises(ArgumentError) { @dados.renomear_ambiente(@modelo, sala['id'], ' cozinha ') }
    assert_raises(ArgumentError) { @dados.renomear_ambiente(@modelo, cozinha['id'], ' ') }
    assert_raises(ArgumentError) { @dados.renomear_ambiente(@modelo, 'inexistente', 'Quarto') }
    assert_equal antes, @dados.ler(@modelo)
    @dados.renomear_ambiente(@modelo, cozinha['id'], 'COZINHA')
    assert_equal 'COZINHA', @dados.ler(@modelo)['ambientes'].first['nome']
  end

  def test_exclui_ambiente_sem_uso_e_rejeita_id_desconhecido
    cozinha = @dados.criar_ambiente(@modelo, 'Cozinha')
    sala = @dados.criar_ambiente(@modelo, 'Sala')

    @dados.excluir_ambiente(@modelo, cozinha['id'])

    assert_equal [sala], @dados.ler(@modelo)['ambientes']
    assert_raises(ArgumentError) { @dados.excluir_ambiente(@modelo, 'inexistente') }
  end

  def test_exclusao_recusa_uso_por_modulo_bloqueado_dentro_de_componente
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    entidades = []
    grupo = adicionar_modulo(entidades)
    grupo.locked = true
    @modelo.entities << Sketchup::ComponentInstance.new(entidades)
    @dados.atribuir_ambiente(grupo, ambiente['id'])

    assert_raises(ArgumentError) { @dados.excluir_ambiente(@modelo, ambiente['id']) }
    assert_equal [ambiente], @dados.ler(@modelo)['ambientes']
  end

  def test_exclusao_recusa_uso_por_modulo_aninhado_em_grupo
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    ancestral = Sketchup::Group.new(@modelo)
    @modelo.entities << ancestral
    grupo = adicionar_modulo(ancestral.entities)
    @dados.atribuir_ambiente(grupo, ambiente['id'])

    assert_raises(ArgumentError) { @dados.excluir_ambiente(@modelo, ambiente['id']) }
  end

  def test_grupo_nao_reconhecido_nao_impede_exclusao_nem_recebe_identidade
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    grupo = Sketchup::Group.new(@modelo)
    grupo.set_attribute(DICIONARIO_MODULO, 'ambiente_id', ambiente['id'])
    @modelo.entities << grupo

    @dados.excluir_ambiente(@modelo, ambiente['id'])

    assert_empty @dados.ler(@modelo)['ambientes']
    assert_nil grupo.get_attribute(DICIONARIO_MODULO, 'modulo_uuid')
    assert_raises(ArgumentError) { @dados.atribuir_ambiente(grupo, nil) }
  end

  def test_atribuicao_recusa_id_de_outro_projeto_e_permite_limpar_associacao
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    grupo = adicionar_modulo
    @dados.atribuir_ambiente(grupo, ambiente['id'])

    assert_raises(ArgumentError) { @dados.atribuir_ambiente(grupo, 'inexistente') }
    assert_equal ambiente['id'], grupo.get_attribute(DICIONARIO_MODULO, 'ambiente_id')
    @dados.atribuir_ambiente(grupo, nil)
    assert_equal '', grupo.get_attribute(DICIONARIO_MODULO, 'ambiente_id')
    @dados.excluir_ambiente(@modelo, ambiente['id'])
    assert_empty @dados.ler(@modelo)['ambientes']
  end

  def test_leitura_inicializa_modulos_antigos_sem_substituir_atributos_legitimos
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    antigo = adicionar_modulo
    existente = adicionar_modulo
    existente.set_attribute(DICIONARIO_MODULO, 'modulo_uuid', 'uuid-legado')
    existente.set_attribute(DICIONARIO_MODULO, 'ambiente_id', ambiente['id'])
    existente.set_attribute(DICIONARIO_MODULO, 'largura_mm', 1234.0)
    existente.set_attribute(DICIONARIO_MODULO, 'divisoes_json', '[{"tipo":"prateleira"}]')

    @dados.ler(@modelo)
    primeiro_uuid = antigo.get_attribute(DICIONARIO_MODULO, 'modulo_uuid')
    @dados.ler(@modelo)

    assert_match UUID, primeiro_uuid
    assert_equal primeiro_uuid, antigo.get_attribute(DICIONARIO_MODULO, 'modulo_uuid')
    assert_equal '', antigo.get_attribute(DICIONARIO_MODULO, 'ambiente_id')
    assert_equal 'uuid-legado', existente.get_attribute(DICIONARIO_MODULO, 'modulo_uuid')
    assert_equal ambiente['id'], existente.get_attribute(DICIONARIO_MODULO, 'ambiente_id')
    assert_equal 1234.0, existente.get_attribute(DICIONARIO_MODULO, 'largura_mm')
    assert_equal '[{"tipo":"prateleira"}]', existente.get_attribute(DICIONARIO_MODULO, 'divisoes_json')
  end

  def test_nomes_de_exibicao_preferem_nome_personalizado_e_tipo_amigavel
    grupo = adicionar_modulo

    assert_equal 'Balcão inferior', @modulo.nome_exibicao(grupo)
    grupo.name = '   '
    assert_equal 'Balcão inferior', @modulo.nome_exibicao(grupo)
    grupo.name = '  Balcão da pia  '
    assert_equal 'Balcão da pia', @modulo.nome_exibicao(grupo)
    assert_equal '  Balcão da pia  ', grupo.name
  end

  def test_json_invalido_nao_e_silenciosamente_apagado
    @dados.ler(@modelo)
    dicionario = @modelo.attribute_dictionary(DICIONARIO_PROJETO)
    ['{invalido', '{}', 'null', 42, '[null]', '[{"id":"x","nome":""}]',
     '[{"id":"x","nome":"Sala"},{"id":"x","nome":"Copa"}]',
     '[{"id":"x","nome":"Sala"},{"id":"y","nome":" sala "}]'].each do |texto|
      dicionario['ambientes_json'] = texto

      assert_raises(ArgumentError) { @dados.ler(@modelo) }
      assert_raises(ArgumentError) { @dados.salvar_cliente(@modelo, 'Novo cliente') }
      assert_equal texto, dicionario['ambientes_json']
      assert_equal '', dicionario['cliente']
    end
  end

  def test_resultado_da_leitura_nao_altera_persistencia_por_referencia
    ambiente = @dados.criar_ambiente(@modelo, 'Cozinha')
    leitura = @dados.ler(@modelo)
    leitura['cliente'].replace('Sem salvar')
    leitura['projeto_uuid'].replace('Sem salvar')
    leitura['ambientes'].first['nome'].replace('Sem salvar')

    assert_equal '', @dados.ler(@modelo)['cliente']
    assert_match UUID, @dados.ler(@modelo)['projeto_uuid']
    assert_equal [ambiente], @dados.ler(@modelo)['ambientes']
  end
end
