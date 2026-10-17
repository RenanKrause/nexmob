require_relative '../marcenaria_parametrica/principal'
require_relative 'verificar_no_sketchup'
require 'json'

module MarcenariaParametrica
  module VerificacaoEditor3d
    def self.exigir(condicao, mensagem)
      raise mensagem unless condicao
    end

    def self.executar(relatorio)
      @relatorio = relatorio
      @resultado = { sucesso: false, processo: Process.pid }
      File.write(@relatorio, JSON.pretty_generate(@resultado.merge(etapa: 'Iniciando editor')))
      @modelo = Sketchup.active_model
      @resultado[:montagem] = VerificacaoMontagem.executar(@modelo)
      @parametros = PlanoBalcaoInferior::PADRAO
      @grupo = ConstrutorBalcaoInferior.new(@modelo).construir(@parametros, Geom::Point3d.new)
      @grupo.transformation = Geom::Transformation.translation([1000.mm, 300.mm, 150.mm]) *
                             Geom::Transformation.rotation(ORIGIN, Z_AXIS, 25.degrees) *
                             Geom::Transformation.scaling(1.2, 1.0, 1.1)
      @edicao = ControladorEdicao.new(proc {})
      @edicao.abrir(@grupo)
      registrar_resultado
      EnquadramentoModulo.frontal(@modelo, @grupo)
      UI.start_timer(2, false) { conferir_ferramenta }
    rescue StandardError => erro
      falhar(erro)
    end

    def self.tela(x, z)
      @modelo.active_view.screen_coords(Geom::Point3d.new(x.mm, 0, z.mm).transform(@grupo.transformation))
    end

    def self.clicar(x, z)
      ponto = tela(x, z)
      @ferramenta.onLButtonDown(0, ponto.x, ponto.y, @modelo.active_view)
      @ferramenta.onLButtonUp(0, ponto.x, ponto.y, @modelo.active_view)
    end

    def self.posicao
      EdicaoDivisoes.pecas(@parametros, PlanoBalcaoInferior.ler_divisoes(@grupo)).first[:posicao_mm]
    end

    def self.conferir_ferramenta
      @ferramenta = @modelo.tools.active_tool
      exigir(@ferramenta.is_a?(FerramentaEdicao3d), 'Editor 3D não ativado.')
      clicar(400, 350)
      exigir(@edicao.instance_variable_get(:@vao) == 'vao', 'Clique no módulo transformado perdeu o vão.')
      selecao = @ferramenta.instance_variable_get(:@selecao)
      controle = RepresentacaoEdicao.controles(@modelo.active_view, selecao, @grupo.transformation).first
      esquerda, superior, direita, inferior = controle[:retangulo]
      @ferramenta.onLButtonDown(0, (esquerda + direita) / 2, (superior + inferior) / 2, @modelo.active_view)
      exigir(PlanoBalcaoInferior.ler_divisoes(@grupo).length == 1, 'Botão flutuante não criou a prateleira.')
      exigir((posicao - 351).abs < 0.01, 'Prateleira em posição incorreta.')

      # Arrastar a alça preserva a diferença entre o centro e a primeira face.
      origem = tela(400, 360)
      destino = tela(400, 409)
      @ferramenta.onLButtonDown(0, origem.x, origem.y, @modelo.active_view)
      @ferramenta.onMouseMove(0, destino.x, destino.y, @modelo.active_view)
      exigir((posicao - 351).abs < 0.01, 'Prévia alterou a geometria antes da confirmação.')
      @ferramenta.draw(@modelo.active_view)
      @ferramenta.onLButtonUp(0, destino.x, destino.y, @modelo.active_view)
      # A projeção do cursor é quantizada em pixels; a entrada digitada é exata.
      exigir((posicao - 400).abs < 1.5, "Arrasto deslocou para #{posicao} em vez de aproximadamente 400 mm.")
      Sketchup.undo
      exigir((posicao - 351).abs < 0.01, 'Um Desfazer não reverteu todo o movimento.')
      @ferramenta.selecionar_peca('vao')
      @ferramenta.onUserText('420,5', @modelo.active_view)
      exigir((posicao - 420.5).abs < 0.01, 'Entrada numérica em milímetros falhou.')
      @ferramenta.executar_acao(:mover)
      cancelar = tela(400, 520)
      @ferramenta.onMouseMove(0, cancelar.x, cancelar.y, @modelo.active_view)
      @ferramenta.onCancel(0, @modelo.active_view)
      alvo = Geom::Point3d.new(400.mm, 250.mm, 360.mm).transform(@grupo.transformation)
      olho = Geom::Point3d.new(1100.mm, -1600.mm, 1200.mm).transform(@grupo.transformation)
      @modelo.active_view.camera = Sketchup::Camera.new(olho, alvo, Z_AXIS, false)
      @modelo.active_view.zoom(@grupo)
      face_superior = @modelo.active_view.screen_coords(Geom::Point3d.new(400.mm, 120.mm, 438.5.mm).transform(@grupo.transformation))
      peca_visivel = @ferramenta.send(:identificar_alvo, @modelo.active_view, face_superior.x, face_superior.y)
      exigir(peca_visivel && peca_visivel[:tipo] == 'prateleira', 'A face superior visível não selecionou a prateleira.')
      EnquadramentoModulo.frontal(@modelo, @grupo)
      exigir((posicao - 420.5).abs < 0.01 && @modelo.tools.active_tool.equal?(@ferramenta), 'Esc não cancelou apenas a prévia.')
      @ferramenta.onUserText('690', @modelo.active_view)
      exigir((posicao - 420.5).abs < 0.01, 'Movimento inválido alterou o módulo.')
      @ferramenta.executar_acao(:duplicar)
      exigir(PlanoBalcaoInferior.ler_divisoes(@grupo).length == 2, 'Duplicação falhou.')
      @ferramenta.executar_acao(:excluir)
      exigir(PlanoBalcaoInferior.ler_divisoes(@grupo).length == 1, 'Exclusão da cópia falhou.')
      clicar(400, 429.5)
      exigir(@edicao.instance_variable_get(:@peca) == 'vao', 'Clique na borda frontal não selecionou a peça.')
      @ferramenta.draw(@modelo.active_view)
      clicar(400, 180)
      vao = @ferramenta.instance_variable_get(:@selecao)
      alca = RepresentacaoEdicao.alcas_vao(@modelo.active_view, vao, @ferramenta.instance_variable_get(:@pecas), @grupo.transformation).first
      exigir(alca && alca[:lado] == :superior, 'O vão não exibiu a alça da prateleira superior.')
      esquerda, superior, direita, inferior = alca[:retangulo]
      @ferramenta.onLButtonDown(0, (esquerda + direita) / 2, (superior + inferior) / 2, @modelo.active_view)
      exigir(@ferramenta.instance_variable_get(:@arrastando), 'A alça do vão não iniciou o movimento da peça.')
      @ferramenta.onCancel(0, @modelo.active_view)
      exigir(@grupo.entities.grep(Sketchup::Group).all?(&:manifold?), 'Uma das chapas deixou de ser sólida.')
      clicar(400, 180)
      @edicao.send(:adicionar_elemento, { 'tipo' => 'prateleira', 'posicao_mm' => 120, 'quantidade' => 2 })
      exigir(PlanoBalcaoInferior.ler_divisoes(@grupo).length == 3, 'Inserção de duas prateleiras no mesmo vão falhou.')
      Sketchup.undo
      exigir(PlanoBalcaoInferior.ler_divisoes(@grupo).length == 1, 'Desfazer não removeu o lote inteiro.')
      clicar(400, 180)
      @edicao.send(:adicionar_elemento, { 'tipo' => 'divisoria', 'posicao_mm' => 350, 'quantidade' => 1 })
      exigir(PlanoBalcaoInferior.ler_divisoes(@grupo).length == 2, 'Divisória sob a prateleira não foi criada.')
      @ferramenta.selecionar_peca('vao')
      @resultado[:interacao] = { transformacao_preservada: true, barra_flutuante: true, arrasto: true,
                                previa_sem_mutacao: true, desfazer: true, entrada_mm: true, cancelar: true,
                                posicao_invalida_protegida: true, duplicar_excluir: true, desenho_api: true,
                                alca_do_vao: true, selecao_pela_face: true, lote_em_uma_operacao: true }
      File.write(@relatorio, JSON.pretty_generate(@resultado.merge(etapa: 'Aguardando interface')))
      conferir_interface
    rescue StandardError => erro
      falhar(erro)
    end

    def self.registrar_resultado
      dialogo = @edicao.instance_variable_get(:@dialogo)
      dialogo.add_action_callback('resultado_editor') do |_contexto, resposta|
        begin
          raise resposta['erro'] if resposta['erro']
          exigir(resposta['peca_visivel'] && resposta['sem_rolagem_horizontal'], 'Layout da seleção não está visível.')
          exigir(resposta['aba_medidas'] && resposta['aba_visualizacao'], 'Abas não alternaram.')
          peca = EdicaoDivisoes.pecas(@parametros, PlanoBalcaoInferior.ler_divisoes(@grupo)).first
          exigir((peca[:vao_livre_mm] - 350).abs < 0.01, 'Vão livre digitado não mede 350 mm.')
          exigir((posicao - 368).abs < 0.01, 'A posição da peça não incluiu a espessura da base.')
          @resultado[:interface] = resposta
          @resultado[:sucesso] = true
          File.write(@relatorio, JSON.pretty_generate(@resultado))
        rescue StandardError => erro
          falhar(erro)
        end
      end
    end

    def self.conferir_interface
      dialogo = @edicao.instance_variable_get(:@dialogo)
      UI.start_timer(1, false) do
        dialogo.execute_script(<<~JS)
          (() => {
            try {
              const resposta = {};
              document.querySelector('[data-aba="medidas"]').click();
              resposta.aba_medidas = !document.getElementById('painel-medidas').hidden;
              document.querySelector('[data-aba="visualizacao"]').click();
              resposta.aba_visualizacao = !document.getElementById('painel-visualizacao').hidden;
              document.querySelector('[data-aba="construir"]').click();
              setTimeout(() => {
                resposta.peca_visivel = !document.getElementById('detalhes-peca').hidden;
                resposta.sem_rolagem_horizontal = document.documentElement.scrollWidth <= innerWidth;
                resposta.posicao = document.getElementById('posicao-peca').value;
                window.sketchup.resultado_editor(resposta);
              }, 600);
              window.exibirErro = (erro) => window.sketchup.resultado_editor({erro});
              document.getElementById('posicao-peca').value = '350';
              document.getElementById('formulario-posicao').requestSubmit();
            } catch (erro) { window.sketchup.resultado_editor({erro: erro.message}); }
          })();
        JS
      end
    end

    def self.falhar(erro)
      @resultado[:erro] = erro.message
      @resultado[:rastreamento] = erro.backtrace
      File.write(@relatorio, JSON.pretty_generate(@resultado))
    end
  end
end
