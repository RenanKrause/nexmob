require 'json'
require_relative '../marcenaria_parametrica/construtores/construtor_balcao_inferior'

module MarcenariaParametrica
  module VerificacaoMontagem
    def self.executar(modelo)
      construtor = ConstrutorBalcaoInferior.new(modelo)
      grupo = construtor.construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(0, 0, 0))
      divisoes = [
        { 'vao_id' => 'vao', 'tipo' => 'prateleira', 'proporcao' => 0.5 },
        { 'vao_id' => 'vao_S', 'tipo' => 'divisoria', 'proporcao' => 0.5 }
      ]
      construtor.atualizar(grupo, ConstrutorBalcaoInferior::PADRAO, divisoes)
      alturas_esperadas = {
        'LATERAL_ESQUERDA' => [0, 720], 'LATERAL_DIREITA' => [0, 720],
        'BASE' => [0, 18], 'FUNDO' => [0, 720],
        'SARRAFO_FRONTAL' => [702, 720], 'SARRAFO_TRASEIRO' => [702, 720],
        'PRATELEIRA_1' => [351, 369], 'DIVISORIA_2' => [369, 702]
      }
      resultados = grupo.entities.grep(Sketchup::Group).map do |chapa|
        codigo = chapa.get_attribute(ConstrutorBalcaoInferior::DICIONARIO_PECA, 'codigo')
        limites = chapa.definition.bounds
        alturas = 8.times.map do |indice|
          limites.corner(indice).transform(chapa.transformation).z.to_mm
        end.minmax
        esperadas = alturas_esperadas.fetch(codigo)
        raise "Alturas incorretas em #{codigo}: #{alturas.inspect}" unless
          alturas.zip(esperadas).all? { |atual, esperada| (atual - esperada).abs < 0.001 }
        raise "Chapa não sólida: #{codigo}" unless chapa.manifold?

        { codigo: codigo, alturas_mm: alturas, solida: true }
      end
      raise 'Quantidade de chapas incorreta.' unless resultados.length == 8

      { sucesso: true, pecas: resultados }
    ensure
      grupo.erase! if grupo && grupo.valid?
    end
  end
end
