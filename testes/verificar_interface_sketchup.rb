require_relative '../marcenaria_parametrica/principal'
require 'json'

module MarcenariaParametrica
  module VerificacaoInterface
    def self.executar(caminho_relatorio)
      @caminho_relatorio = caminho_relatorio
      @resultado = { sucesso: false, processo: Process.pid }
      armazenamento = Object.new
      dados = {}
      armazenamento.define_singleton_method(:read_default) { |secao, chave, padrao| dados.fetch([secao, chave], padrao) }
      armazenamento.define_singleton_method(:write_default) { |secao, chave, valor| dados[[secao, chave]] = valor; true }
      @configuracao = ConfiguracaoConstrutiva.new(armazenamento)
      @modo = ControladorModoConstrutivo.new(@configuracao, proc {})
      @modo.abrir
      dialogo = @modo.instance_variable_get(:@dialogo)
      dialogo.add_action_callback('resultado_interface') { |_contexto, resposta| conferir_modo(resposta) }
      UI.start_timer(1, false) do
        dialogo.execute_script(<<~JS)
          (() => {
            const original = window.exibirMensagemModo;
            window.exibirMensagemModo = (texto) => {
              original(texto);
              if (!texto.startsWith('Modo salvo')) return;
              const botao = document.getElementById('aplicar-projeto').getBoundingClientRect();
              window.sketchup.resultado_interface({
                nome: document.getElementById('nome-modo').value,
                opcoes: document.getElementById('modo-salvo').options.length,
                botaoVisivel: botao.top >= 0 && botao.bottom <= window.innerHeight,
                semRolagemHorizontal: document.documentElement.scrollWidth <= window.innerWidth
              });
            };
            window.exibirErro = (erro) => window.sketchup.resultado_interface({erro});
            document.getElementById('novo-modo').click();
            document.getElementById('nome-modo').value = 'Oficina reforçada';
            document.querySelector('[data-medida="espessura_mm"]').value = '25';
            document.querySelector('[data-familia="superiores"]').click();
            document.querySelector('[data-medida="espessura_fundo_mm"]').value = '9';
            document.querySelector('[data-familia="armarios"]').click();
            document.querySelector('[data-medida="espessura_mm"]').value = '20';
            document.querySelector('[data-familia="inferiores"]').click();
            document.getElementById('formulario-modo').requestSubmit();
          })();
        JS
      end
    rescue StandardError => erro
      falhar(erro)
    end

    def self.conferir_modo(resposta)
      raise resposta['erro'] if resposta['erro']
      raise 'O novo modo não foi salvo.' unless resposta['nome'] == 'Oficina reforçada' && resposta['opcoes'] == 2
      raise 'Botão de aplicação fora da área visível.' unless resposta['botaoVisivel']
      raise 'Modal excede a largura disponível.' unless resposta['semRolagemHorizontal']
      raise 'Inferiores perdeu a edição ao trocar de aba.' unless @configuracao.ler('inferiores')['espessura_mm'] == 25
      raise 'Superiores perdeu a edição ao trocar de aba.' unless @configuracao.ler('superiores')['espessura_fundo_mm'] == 9
      raise 'Armários perdeu a edição ao trocar de aba.' unless @configuracao.ler('armarios')['espessura_mm'] == 20

      @resultado[:modo_salvo_pela_interface] = resposta
      @modo.instance_variable_get(:@dialogo).close
      iniciar_edicao
    rescue StandardError => erro
      falhar(erro)
    end

    def self.iniciar_edicao
      modelo = Sketchup.active_model
      @grupo = ConstrutorBalcaoInferior.new(modelo).construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(0, 0, 0))
      EnquadramentoModulo.frontal(modelo, @grupo)
      @edicao = ControladorEdicao.new(proc { @modo.abrir })
      @edicao.abrir(@grupo)
      dialogo = @edicao.instance_variable_get(:@dialogo)
      dialogo.add_action_callback('resultado_edicao') { |_contexto, resposta| conferir_edicao(resposta) }
      UI.start_timer(1, false) do
        begin
          ferramenta = modelo.tools.active_tool
          raise 'Abrir edição não ativou a seleção.' unless ferramenta.is_a?(FerramentaSelecaoVao)

          tela = modelo.active_view.screen_coords(Geom::Point3d.new(400.mm, 0, 360.mm))
          ferramenta.onLButtonDown(0, tela.x, tela.y, modelo.active_view)
          dialogo.execute_script(<<~JS)
            (() => {
              const original = window.confirmarElemento;
              window.confirmarElemento = () => {
                original();
                window.sketchup.resultado_edicao({ mensagem: document.getElementById('mensagem-edicao').textContent });
              };
              window.exibirErro = (erro) => window.sketchup.resultado_edicao({erro});
              document.getElementById('posicao-prateleira').value = '333';
              document.querySelector('[data-elemento="prateleira"]').click();
            })();
          JS
        rescue StandardError => erro
          falhar(erro)
        end
      end
    end

    def self.conferir_edicao(resposta)
      raise resposta['erro'] if resposta['erro']
      raise 'Prateleira não inserida.' unless ModuloParametrico.vaos(@grupo).length == 2

      ferramenta = Sketchup.active_model.tools.active_tool
      raise 'Seleção encerrada após inserir peça.' unless ferramenta.is_a?(FerramentaSelecaoVao)

      tela = Sketchup.active_model.active_view.screen_coords(Geom::Point3d.new(400.mm, 0, 180.mm))
      ferramenta.onLButtonDown(0, tela.x, tela.y, Sketchup.active_model.active_view)
      raise 'Não foi possível selecionar o novo vão imediatamente.' unless @edicao.instance_variable_get(:@vao) == 'vao_I'

      @resultado[:edicao_continua_pela_interface] = true
      @resultado[:sucesso] = true
      File.write(@caminho_relatorio, JSON.pretty_generate(@resultado))
    rescue StandardError => erro
      falhar(erro)
    end

    def self.falhar(erro)
      @resultado[:erro] = erro.message
      @resultado[:rastreamento] = erro.backtrace
      File.write(@caminho_relatorio, JSON.pretty_generate(@resultado))
    end
  end
end
