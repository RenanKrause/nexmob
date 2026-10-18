require 'sketchup.rb'
require 'extensions.rb'

module MarcenariaParametrica
  unless file_loaded?(__FILE__)
    EXTENSAO = SketchupExtension.new('Nex Mob', 'marcenaria_parametrica/principal')
    EXTENSAO.description = 'Módulos de marcenaria com chapas e dados de fabricação.'
    EXTENSAO.version = '0.5.0'
    EXTENSAO.creator = 'Nex Mob'
    Sketchup.register_extension(EXTENSAO, true)
    file_loaded(__FILE__)
  end
end

