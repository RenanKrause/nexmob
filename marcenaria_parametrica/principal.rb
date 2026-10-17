require 'sketchup.rb'
require_relative 'construtores/construtor_balcao_inferior'
require_relative 'configuracao/configuracao_construtiva'
require_relative 'dominio/modulo_parametrico'
require_relative 'dominio/plano_gavetas'
require_relative 'dominio/plano_frentes'
require_relative 'servicos/aplicador_modo_construtivo'
require_relative 'visualizacao/enquadramento_modulo'
require_relative 'ferramentas/ferramenta_insercao'
require_relative 'ferramentas/ferramenta_selecao_vao'
require_relative 'ferramentas/ferramenta_edicao_3d'
require_relative 'interface/fabrica_dialogos'
require_relative 'interface/observador_edicao'
require_relative 'interface/controlador_catalogo'
require_relative 'interface/controlador_edicao'
require_relative 'interface/controlador_frentes'
require_relative 'interface/controlador_modo_construtivo'
require_relative 'interface/controlador_interface'
require_relative 'interface/comandos_plugin'

module MarcenariaParametrica
  unless file_loaded?(__FILE__)
    CONTROLADOR = ControladorInterface.new
    COMANDOS = ComandosPlugin.new(CONTROLADOR)
    file_loaded(__FILE__)
  end
end
