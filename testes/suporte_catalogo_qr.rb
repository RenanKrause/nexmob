require 'minitest/autorun'
require 'json'

# Double limitado à fronteira da API SketchUp, com unidades internas em polegadas.
module Geom
  Point3d = Struct.new(:x, :y, :z) do
    def transform(transformacao)
      transformacao.aplicar(self)
    end
  end
  Vector3d = Struct.new(:x, :y, :z) do
    def length
      Math.sqrt(x * x + y * y + z * z)
    end
    def dot(outro)
      x * outro.x + y * outro.y + z * outro.z
    end
  end
  class Transformation
    attr_reader :matrix
    def initialize(matrix = nil)
      @matrix = matrix || [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    end
    def self.caixa(x: 0, y: 0, z: 0, graus: 0, escala: [1, 1, 1])
      a = graus * Math::PI / 180
      c, s = Math.cos(a), Math.sin(a)
      new([[c * escala[0], -s * escala[1], 0, x / 25.4],
           [s * escala[0], c * escala[1], 0, y / 25.4],
           [0, 0, escala[2], z / 25.4], [0, 0, 0, 1]])
    end
    def *(outro)
      self.class.new(4.times.map { |i| 4.times.map { |j| (0..3).sum { |k| matrix[i][k] * outro.matrix[k][j] } } })
    end
    def aplicar(ponto)
      valores = [ponto.x, ponto.y, ponto.z, 1]
      Point3d.new(*3.times.map { |i| (0..3).sum { |j| matrix[i][j] * valores[j] } })
    end
    def xaxis; Vector3d.new(matrix[0][0], matrix[1][0], matrix[2][0]); end
    def yaxis; Vector3d.new(matrix[0][1], matrix[1][1], matrix[2][1]); end
    def zaxis; Vector3d.new(matrix[0][2], matrix[1][2], matrix[2][2]); end
  end
end

module Sketchup
  class << self
    attr_accessor :active_model
  end
  class Layer
    attr_accessor :visible, :folder
    def initialize(visible = true, folder = nil)
      @visible, @folder = visible, folder
    end
    def visible?; @visible; end
  end
  class LayerFolder < Layer; end
  class Group
    attr_accessor :name, :locked, :hidden, :transformation, :layer, :valid
    attr_reader :entities, :model, :definition
    def initialize(modelo, dimensoes = [18, 560, 720])
      @model, @name, @locked, @hidden, @valid = modelo, '', false, false, true
      @entities, @atributos = [], {}
      @transformation = Geom::Transformation.new
      @layer = Layer.new
      bounds = Struct.new(:width, :height, :depth, :center).new(
        *dimensoes.map { |v| v / 25.4 }, Geom::Point3d.new(*dimensoes.map { |v| v / 50.8 })
      )
      @definition = Struct.new(:entities, :bounds).new(@entities, bounds)
    end
    def valid?; @valid; end
    def locked?; @locked; end
    def hidden?; @hidden; end
    def get_attribute(dic, chave, padrao = nil); @atributos.fetch([dic, chave], padrao); end
    def set_attribute(dic, chave, valor); @atributos[[dic, chave]] = valor; end
  end
  class ComponentInstance < Group
    def initialize(modelo, entidades, definition: nil)
      super(modelo)
      if definition
        @definition = definition
        @entities = definition.entities
      else
        @entities.concat(entidades)
      end
    end
  end
end

class ModeloCatalogoQr
  attr_reader :entities
  def initialize
    @entities, @dicionarios = [], {}
  end
  def attribute_dictionary(nome, criar = false)
    @dicionarios[nome] ||= {} if criar
    @dicionarios[nome]
  end
end

module SuporteCatalogoQr
  MOD = 'marcenaria_parametrica_modulo'.freeze
  PECA = 'marcenaria_parametrica_peca'.freeze
  def preparar_modelo
    @modelo = ModeloCatalogoQr.new
    Sketchup.active_model = @modelo
    @dados = MarcenariaParametrica::DadosProjeto
    @dados.salvar_cliente(@modelo, 'CLIENTE PRIVADO 123')
    @cozinha = @dados.criar_ambiente(@modelo, 'Cozinha')
    @sala = @dados.criar_ambiente(@modelo, 'Sala')
  end
  def modulo_em(entidades = @modelo.entities, ambiente = @cozinha)
    grupo = Sketchup::Group.new(@modelo)
    grupo.name = 'Balcão da pia'
    grupo.set_attribute(MOD, 'tipo', 'balcao_inferior')
    entidades << grupo
    @dados.atribuir_ambiente(grupo, ambiente['id'])
    grupo
  end
  def peca_em(modulo, codigo = 'LATERAL_ESQUERDA', dimensoes = [18, 560, 720])
    grupo = Sketchup::Group.new(@modelo, dimensoes)
    atributos = { 'codigo' => codigo, 'nome' => 'Lateral esquerda', 'comprimento_mm' => 560,
                  'largura_mm' => 720, 'espessura_mm' => 18, 'material_padrao' => 'MDF Branco',
                  'material_sobrescrito' => 'MDF Freijó Puro', 'fita_borda' => 'frente',
                  'chave_logica' => "chave-#{codigo}", 'qr_token' => '0123456789abcdef0123456789abcdef' }
    atributos.each { |chave, valor| grupo.set_attribute(PECA, chave, valor) }
    modulo.entities << grupo
    grupo
  end
end
