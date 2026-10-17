module MarcenariaParametrica
  module EnquadramentoModulo
    def self.frontal(modelo, grupo)
      transformacao = modelo.edit_transform * grupo.transformation
      alvo = grupo.definition.bounds.center.transform(transformacao)
      direcao = Geom::Vector3d.new(0, -1, 0).transform(transformacao).normalize
      superior = Geom::Vector3d.new(0, 0, 1).transform(transformacao).normalize
      distancia = [grupo.bounds.diagonal * 2, 1000.mm].max
      modelo.active_view.camera = Sketchup::Camera.new(alvo.offset(direcao, distancia), alvo, superior, false)
      modelo.active_view.zoom(grupo)
      modelo.active_view.zoom(0.72)
      modelo.active_view.invalidate
    end
  end
end
