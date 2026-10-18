require 'minitest/autorun'
require_relative '../marcenaria_parametrica/construtores/construtor_balcao_inferior'

class Numeric
  def mm
    self
  end unless method_defined?(:mm)
end

module Geom
  class Transformation
    attr_reader :origem

    def initialize(origem)
      @origem = origem.to_a
    end
  end
end

module Sketchup
  class Group
    attr_accessor :name, :transformation
    attr_reader :entities

    def initialize
      @transformation = Geom::Transformation.new([0, 0, 0])
      @entities = EntidadesDeTeste.new
      @atributos = {}
    end

    def transform!(transformacao)
      @transformation = Geom::Transformation.new(
        @transformation.origem.zip(transformacao.origem).map { |atual, deslocamento| atual + deslocamento }
      )
    end

    def set_attribute(dicionario, chave, valor)
      @atributos[[dicionario, chave]] = valor
    end

    def get_attribute(dicionario, chave)
      @atributos[[dicionario, chave]]
    end

    def valid?
      true
    end

    def locked?
      false
    end

    def make_unique
      self
    end
  end
end

class EntidadesDeTeste
  attr_reader :grupos, :faces

  def initialize
    @grupos = []
    @faces = []
  end

  def add_group
    Sketchup::Group.new.tap { |grupo| @grupos << grupo }
  end

  def add_face(*pontos)
    FaceDeTeste.new(pontos).tap { |face| @faces << face }
  end

  def clear!
    @grupos.clear
    @faces.clear
  end
end

class FaceDeTeste
  attr_reader :pontos, :altura, :normal, :pontos_extrudados

  def initialize(pontos)
    @pontos = pontos
    # A API orienta as faces criadas em Z = 0 para baixo, mesmo com vértices anti-horários.
    @normal = Struct.new(:z).new(-1)
  end

  def reverse!
    @normal.z *= -1
  end

  def pushpull(altura)
    @altura = altura
    @pontos_extrudados = @pontos.map { |x, y, z| [x, y, z + @normal.z * altura] }
  end
end

class ModeloDeTeste
  attr_reader :active_entities

  def initialize
    @active_entities = EntidadesDeTeste.new
  end

  def start_operation(_nome, _transparente)
  end

  def commit_operation
  end

  def abort_operation
  end
end

class TesteMontagemBalcaoInferior < Minitest::Test
  def test_insercao_cria_uuid_uma_vez_e_reconstrucao_preserva_identidade_e_ambiente
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior.new(ModeloDeTeste.new)
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO
    grupo = construtor.construir(parametros, [0, 0, 0])
    dicionario = 'marcenaria_parametrica_modulo'
    uuid = grupo.get_attribute(dicionario, 'modulo_uuid')

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, uuid)
    assert_equal '', grupo.get_attribute(dicionario, 'ambiente_id')
    grupo.set_attribute(dicionario, 'ambiente_id', 'ambiente-existente')
    construtor.atualizar(grupo, parametros.merge('largura_mm' => 900))

    assert_equal uuid, grupo.get_attribute(dicionario, 'modulo_uuid')
    assert_equal 'ambiente-existente', grupo.get_attribute(dicionario, 'ambiente_id')
    assert_equal 900, grupo.get_attribute(dicionario, 'largura_mm')
  end

  def test_reconstrucao_inicializa_modulo_antigo_sem_alterar_nome_e_atributos_extras
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior.new(ModeloDeTeste.new)
    grupo = Sketchup::Group.new
    dicionario = 'marcenaria_parametrica_modulo'
    grupo.name = 'Balcão personalizado'
    grupo.set_attribute(dicionario, 'tipo', 'balcao_inferior')
    grupo.set_attribute(dicionario, 'versao_esquema', 2)
    grupo.set_attribute(dicionario, 'material_padrao', 'MDF Freijó')

    construtor.atualizar(grupo, MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO)

    refute_empty grupo.get_attribute(dicionario, 'modulo_uuid')
    assert_equal '', grupo.get_attribute(dicionario, 'ambiente_id')
    assert_equal 'Balcão personalizado', grupo.name
    assert_equal 'MDF Freijó', grupo.get_attribute(dicionario, 'material_padrao')
  end

  def test_pecas_ocupam_as_coordenadas_planejadas
    modelo = ModeloDeTeste.new
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior.new(modelo)
    grupo = construtor.construir(MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO, [1200, 200, 0])
    pecas = grupo.entities.grupos.to_h do |chapa|
      [chapa.get_attribute('marcenaria_parametrica_peca', 'codigo'), chapa]
    end

    assert_equal [1200, 200, 0], grupo.transformation.origem
    assert_equal 6, pecas.length
    assert_equal [18.0, 0.0, 0.0], pecas['BASE'].transformation.origem
    assert_equal [18.0, 0.0, 702.0], pecas['SARRAFO_FRONTAL'].transformation.origem
    assert_equal [18.0, 474.0, 702.0], pecas['SARRAFO_TRASEIRO'].transformation.origem
    assert_equal [0.0, 554.0, 0.0], pecas['FUNDO'].transformation.origem
    assert_equal 18.0, pecas['BASE'].entities.faces.first.altura
  end

  def test_volumes_crescem_para_cima_e_ficam_dentro_dos_limites_do_movel
    modelo = ModeloDeTeste.new
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior.new(modelo)
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO
    grupo = construtor.construir(parametros, [1200, 200, 0])
    divisoes = [
      { 'vao_id' => 'vao', 'tipo' => 'prateleira', 'proporcao' => 0.5 },
      { 'vao_id' => 'vao_S', 'tipo' => 'divisoria', 'proporcao' => 0.5 }
    ]
    construtor.atualizar(grupo, parametros, divisoes)
    limites_esperados = {
      'LATERAL_ESQUERDA' => [0.0, 720.0], 'LATERAL_DIREITA' => [0.0, 720.0],
      'BASE' => [0.0, 18.0], 'FUNDO' => [0.0, 720.0],
      'SARRAFO_FRONTAL' => [702.0, 720.0], 'SARRAFO_TRASEIRO' => [702.0, 720.0],
      'PRATELEIRA_1' => [351.0, 369.0], 'DIVISORIA_2' => [369.0, 702.0]
    }

    grupo.entities.grupos.each do |chapa|
      codigo = chapa.get_attribute('marcenaria_parametrica_peca', 'codigo')
      face = chapa.entities.faces.first
      alturas = (face.pontos + face.pontos_extrudados).map do |ponto|
        ponto[2] + chapa.transformation.origem[2]
      end
      assert_equal limites_esperados.fetch(codigo), alturas.minmax, codigo
    end
  end

  def test_edicao_preserva_posicao_do_modulo_e_recria_divisoria_no_vao
    modelo = ModeloDeTeste.new
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior.new(modelo)
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO
    grupo = construtor.construir(parametros, [1200, 200, 0])
    divisoes = MarcenariaParametrica::ConstrutorBalcaoInferior.adicionar_divisao(
      parametros, [], 'vao', 'divisoria', 373.0
    )

    construtor.atualizar(grupo, parametros, divisoes)
    divisoria = grupo.entities.grupos.find do |chapa|
      chapa.get_attribute('marcenaria_parametrica_peca', 'codigo') == 'DIVISORIA_1'
    end

    assert_equal [1200, 200, 0], grupo.transformation.origem
    assert_equal [391.0, 0.0, 18.0], divisoria.transformation.origem
    assert_equal 7, grupo.entities.grupos.length
  end
end
