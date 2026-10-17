require_relative '../marcenaria_parametrica/principal'
require_relative 'verificar_no_sketchup'

module MarcenariaParametrica
  module VerificacaoFluxos
    def self.exigir(condicao, mensagem)
      raise mensagem unless condicao
    end

    def self.executar(modelo, imagem)
      resultado = VerificacaoMontagem.executar(modelo)
      construtor = ConstrutorBalcaoInferior.new(modelo)
      primeiro = construtor.construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(0, 0, 0))
      segundo = construtor.construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(1100.mm, 0, 0))
      terceiro = construtor.construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(2200.mm, 0, 0))
      envoltorio = modelo.entities.add_group(terceiro)
      copia = envoltorio.copy
      envoltorio.locked = true
      copia.transformation = Geom::Transformation.new([0, 800.mm, 0])
      categorias = ConfiguracaoConstrutiva::PADROES.transform_values(&:dup)
      categorias['inferiores']['espessura_mm'] = 25.0
      aplicado = AplicadorModoConstrutivo.new(modelo).aplicar(categorias)
      exigir(aplicado == { atualizados: 3, bloqueados: 1 }, "Contagem incorreta: #{aplicado}")
      exigir(ModuloParametrico.parametros(primeiro)['espessura_mm'] == 25.0, 'Primeiro móvel não atualizado.')
      exigir(ModuloParametrico.parametros(segundo)['espessura_mm'] == 25.0, 'Segundo móvel não atualizado.')
      exigir(ModuloParametrico.parametros(terceiro)['espessura_mm'] == 18.0, 'Móvel sob ancestral bloqueado foi alterado.')
      interno_copia = copia.entities.grep(Sketchup::Group).first
      exigir(ModuloParametrico.parametros(interno_copia)['espessura_mm'] == 25.0, 'Cópia livre não atualizada.')
      Sketchup.undo
      exigir(ModuloParametrico.parametros(primeiro)['espessura_mm'] == 18.0, 'Desfazer não restaurou a espessura.')
      exigir(ModuloParametrico.parametros(segundo)['espessura_mm'] == 18.0, 'Desfazer parcial da aplicação global.')
      resultado[:aplicacao_global] = aplicado
      resultado[:desfazer_unico] = true

      divisao_estreita = ConstrutorBalcaoInferior.adicionar_divisao(ConstrutorBalcaoInferior::PADRAO, [], 'vao', 'divisoria', 80)
      construtor.atualizar(segundo, ConstrutorBalcaoInferior::PADRAO, divisao_estreita)
      rejeitado = false
      begin
        AplicadorModoConstrutivo.new(modelo).aplicar(categorias)
      rescue ArgumentError
        rejeitado = true
      end
      exigir(rejeitado, 'A aplicação deveria rejeitar o vão menor que 80 mm.')
      exigir(ModuloParametrico.parametros(primeiro)['espessura_mm'] == 18.0, 'Falha deixou o projeto parcialmente atualizado.')
      resultado[:reversao_em_erro] = true

      divisoes = ConstrutorBalcaoInferior.adicionar_divisao(ConstrutorBalcaoInferior::PADRAO, [], 'vao', 'prateleira', 333)
      construtor.atualizar(primeiro, ConstrutorBalcaoInferior::PADRAO, divisoes)
      EnquadramentoModulo.frontal(modelo, primeiro)
      recebidos = []
      ferramenta = FerramentaSelecaoVao.new(modelo, primeiro, ModuloParametrico.vaos(primeiro), proc { |vao| recebidos << vao[:id] })
      ferramenta.define_singleton_method(:draw) do |vista|
        super(vista)
        @desenhou = true
      rescue StandardError => erro
        @erro_desenho = erro.message
      end
      modelo.select_tool(ferramenta)
      [180, 500].each do |altura|
        tela = modelo.active_view.screen_coords(Geom::Point3d.new(400.mm, 0, altura.mm))
        ferramenta.onMouseMove(0, tela.x, tela.y, modelo.active_view)
        ferramenta.onLButtonDown(0, tela.x, tela.y, modelo.active_view)
      end
      exigir(recebidos == %w[vao_I vao_S], "Seleção sequencial falhou: #{recebidos}")
      exigir(modelo.tools.active_tool.equal?(ferramenta), 'A ferramenta terminou após o clique.')
      modelo.active_view.refresh
      exigir(ferramenta.instance_variable_get(:@desenhou), "Destaque não desenhado: #{ferramenta.instance_variable_get(:@erro_desenho)}")
      modelo.active_view.write_image(filename: imagem, width: 1200, height: 900, antialias: true)
      resultado[:selecao_continua] = recebidos
      resultado[:destaque_desenhado] = true
      [resultado, primeiro]
    end
  end
end
