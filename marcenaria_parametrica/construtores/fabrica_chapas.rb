require_relative '../dominio/plano_balcao_inferior'
require_relative '../dominio/identidade_peca'

module MarcenariaParametrica
  class FabricaChapas
    def self.criar(entidades, peca, anteriores = {})
      atributos = IdentidadePeca.atributos_para(peca, anteriores)
      chapa = entidades.add_group
      chapa.name = peca[:nome]
      largura, profundidade, altura = peca[:dimensoes_mm].map(&:mm)
      face = chapa.entities.add_face(
        [0, 0, 0], [largura, 0, 0], [largura, profundidade, 0], [0, profundidade, 0]
      )
      raise 'Não foi possível criar a face da chapa.' unless face

      # Faces no plano Z = 0 nascem voltadas para baixo no SketchUp.
      # O plano de montagem exige que todas as chapas cresçam no sentido positivo de Z.
      face.reverse! if face.normal.z < 0
      face.pushpull(altura)
      chapa.transformation = Geom::Transformation.new(peca[:posicao_mm].map(&:mm))
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'codigo', peca[:codigo])
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'nome', peca[:nome])
      atributos.each { |chave, valor| chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, chave, valor) }
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'material', IdentidadePeca.material_efetivo(chapa))
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'comprimento_mm', peca[:corte_mm][0])
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'largura_mm', peca[:corte_mm][1])
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'espessura_mm', peca[:corte_mm][2])
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'fita_borda', peca[:fita_borda])
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'vao_origem', peca[:vao_id]) if peca[:vao_id]
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'gaveta_origem', peca[:gaveta_id]) if peca[:gaveta_id]
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'gaveta_vao', peca[:vao_destino]) if peca[:vao_destino]
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'frente_origem', peca[:frente_id]) if peca[:frente_id]
      chapa.set_attribute(PlanoBalcaoInferior::DICIONARIO_PECA, 'frente_gaveta', peca[:gaveta_destino]) if peca[:gaveta_destino]
      chapa
    end
  end
end
