# Carregue pelo Console Ruby do SketchUp 2026, com um modelo novo e vazio.
# Não usa rede, credenciais ou impressora. O resultado final é assíncrono.
unless defined?(Sketchup::Model) && defined?(UI::HtmlDialog)
  raise LoadError, 'Verificador requer SketchUp 2026. Abra um modelo novo e carregue este arquivo pelo Console Ruby; Ruby comum não fornece a API SketchUp.'
end

require_relative '../marcenaria_parametrica/principal'
require 'json'

module MarcenariaParametrica
  module VerificacaoEtiquetas
    class << self
      attr_reader :resultado

      def executar
        raise 'Feche a prévia anterior antes de repetir a verificação.' if @dialogo && @dialogo.visible?

        modelo = Sketchup.active_model
        unless modelo.path.empty? && modelo.entities.empty? && modelo.active_path.nil? &&
               modelo.attribute_dictionary(DadosProjeto::DICIONARIO, false).nil?
          raise 'Abra um modelo novo e vazio, sem salvar, antes de executar. O verificador cria dois móveis descartáveis.'
        end

        @resultado = { sucesso: false, etapa: 'geometria', rede: 'não utilizada', impressao: 'não executada' }
        DadosProjeto.salvar_cliente(modelo, 'Cliente QA')
        cozinha = DadosProjeto.criar_ambiente(modelo, 'Cozinha')
        lavanderia = DadosProjeto.criar_ambiente(modelo, 'Lavanderia')
        construtor = ConstrutorBalcaoInferior.new(modelo)
        primeiro = construtor.construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(0, 0, 0))
        segundo = construtor.construir(ConstrutorBalcaoInferior::PADRAO, Geom::Point3d.new(1100.mm, 0, 0))
        primeiro.name = 'Balcão QA 1'
        segundo.name = 'Balcão QA 2'
        DadosProjeto.atribuir_ambiente(primeiro, cozinha['id'])
        DadosProjeto.atribuir_ambiente(segundo, lavanderia['id'])

        catalogo = CatalogoPecas.listar(modelo)
        exigir(catalogo.size == 12, "Esperadas 12 chapas nos dois balcões; recebidas #{catalogo.size}.")
        alvo = catalogo.find { |item| item[:modulo].equal?(primeiro) }
        exigir(alvo, 'Primeiro móvel ausente do catálogo.')
        identidades = catalogo.to_h { |item| [[item[:modulo_id], item[:chave_logica]], item[:qr_token]] }
        alvo[:peca].set_attribute(IdentidadePeca::DICIONARIO, 'material_sobrescrito', 'MDF QA Freijó')

        # A largura diferente força uma reconstrução real, destruindo as chapas antigas.
        parametros = ModuloParametrico.parametros(primeiro).merge('largura_mm' => 900.0)
        construtor.atualizar(primeiro, parametros)
        catalogo = CatalogoPecas.listar(modelo)
        tokens = catalogo.map { |item| item[:qr_token] }
        exigir(catalogo.size == 12, 'A reconstrução alterou a quantidade de chapas.')
        exigir(tokens.all? { |token| token.is_a?(String) && token.match?(/\A[0-9a-f]{32}\z/) }, 'QR deve conter exatamente 32 hexadecimais.')
        exigir(tokens.uniq.size == tokens.size, 'Há tokens QR duplicados no lote.')
        exigir(catalogo.all? { |item| identidades[[item[:modulo_id], item[:chave_logica]]] == item[:qr_token] },
               'A reconstrução mudou uma identidade QR existente.')
        reconstruida = catalogo.find { |item| item[:modulo_id] == alvo[:modulo_id] && item[:chave_logica] == alvo[:chave_logica] }
        exigir(reconstruida && reconstruida[:material] == 'MDF QA Freijó', 'Material individual perdido na reconstrução.')
        exigir(catalogo.map { |item| item[:ambiente] }.uniq.sort == %w[Cozinha Lavanderia], 'Ambientes incorretos no lote.')
        exigir(catalogo.all? { |item| item[:cliente] == 'Cliente QA' }, 'Cliente ausente nas etiquetas.')

        manifesto = ManifestoQr.gerar(modelo, catalogo, revision_id: 'verificacao-local')
        pecas_publicas = manifesto['modules'].flat_map { |modulo| modulo['pieces'] }
        exigir(manifesto['modules'].size == 2 && pecas_publicas.size == 12, 'Manifesto incompleto.')
        exigir(manifesto['modules'].map { |modulo| modulo['environment'] }.sort == %w[Cozinha Lavanderia], 'Ambientes ausentes no manifesto.')
        exigir(pecas_publicas.map { |peca| peca['qr_token'] }.sort == tokens.sort, 'Manifesto e etiquetas discordam nos tokens.')
        exigir(pecas_publicas.any? { |peca| peca['qr_token'] == reconstruida[:qr_token] && peca['material'] == 'MDF QA Freijó' },
               'Material individual ausente do manifesto.')
        exigir(!JSON.generate(manifesto).include?('Cliente QA'), 'Cliente vazou para o manifesto público.')

        config = ConfiguracaoEtiquetas::PADRAO.merge('viewer_base_url' => 'https://viewer.example.invalid',
                                                   'revision_id' => manifesto['revision_id'], 'gerado_em' => manifesto['synced_at'])
        rejeitado = false
        begin
          CompositorEtiquetas.lote_a4(catalogo, config.merge('qr_mm' => 19))
        rescue ArgumentError
          rejeitado = true
        end
        exigir(rejeitado, 'Compositor aceitou QR menor que 20 mm.')
        @resultado.merge!(etapa: 'html_dialog', pecas: catalogo.size, tokens_distintos: tokens.uniq.size,
                          material_preservado: true, identidades_preservadas: true, manifesto: true)
        abrir_previa(CompositorEtiquetas.lote_a4(catalogo, config))
        puts 'QA etiquetas: geometria e manifesto conferidos; aguardando HtmlDialog (até 30 s).'
        @resultado
      rescue StandardError => erro
        falhar(erro)
      end

      private

      def exigir(condicao, mensagem)
        raise mensagem unless condicao
      end

      def abrir_previa(html)
        @dialogo = UI::HtmlDialog.new(dialog_title: 'QA etiquetas · sem rede', width: 1100, height: 850, resizable: true)
        @dialogo.add_action_callback('resultado_qa_etiquetas') do |_contexto, dados|
          begin
            exigir(@resultado[:etapa] == 'html_dialog', 'Resposta recebida após encerramento do teste.')
            exigir(dados.is_a?(Hash), 'Resposta HtmlDialog inválida.')
            exigir(!dados['erro'], dados['erro'])
            exigir(dados['paginas'] == 2 && dados['celulas_primeira'] == 10 && dados['celulas_segunda'] == 2,
                   'A4 deve conter dez células na primeira folha e duas na segunda.')
            exigir(dados['qr_count'] == 12 && dados['qr_min_mm'].to_f >= 20, 'QR renderizado menor que 20 mm ou ausente.')
            exigir((dados['largura_mm'].to_f - 99).abs < 0.1 && (dados['altura_mm'].to_f - 55.8).abs < 0.1,
                   'Célula A4350 diferente de 99 × 55,8 mm.')
            @resultado.merge!(sucesso: true, etapa: 'concluido', a4: dados)
            UI.stop_timer(@temporizador) if @temporizador
            puts "PASS QA etiquetas: #{JSON.generate(@resultado)}"
            puts 'A prévia usa URL fictícia. Impressão física, leitura por câmera e Pages continuam pendentes.'
          rescue StandardError => erro
            falhar(erro)
          end
        end
        @dialogo.set_on_closed do
          falhar(RuntimeError.new('HtmlDialog fechado antes da resposta. Repita em um modelo novo.')) if @resultado[:etapa] == 'html_dialog'
          @dialogo = nil
        end
        verificacao = <<~HTML
          <script>
          (() => {
            const conferir = () => requestAnimationFrame(() => {
              try {
                const estado = document.getElementById('estado-impressao');
                if (!estado.hidden) throw new Error(estado.textContent);
                Etiquetas.verificarLegibilidade(document);
                const folhas = [...document.querySelectorAll('.folha.a4')];
                const celula = folhas[0].querySelector('.etiqueta').getBoundingClientRect();
                const qrs = [...document.querySelectorAll('.qr > svg')];
                const mm = px => px * 25.4 / 96;
                window.sketchup.resultado_qa_etiquetas({ paginas: folhas.length,
                  celulas_primeira: folhas[0].querySelectorAll('.etiqueta').length,
                  celulas_segunda: folhas[1].querySelectorAll('.etiqueta').length,
                  qr_count: qrs.length, qr_min_mm: Math.min(...qrs.map(qr => mm(Math.min(qr.getBoundingClientRect().width, qr.getBoundingClientRect().height)))),
                  largura_mm: mm(celula.width), altura_mm: mm(celula.height) });
              } catch (erro) { window.sketchup.resultado_qa_etiquetas({ erro: erro.message }); }
            });
            if (document.fonts && document.fonts.ready) document.fonts.ready.then(conferir); else conferir();
          })();
          </script>
        HTML
        @dialogo.set_html(html.sub('</body>', verificacao + '</body>'))
        @temporizador = UI.start_timer(30, false) do
          falhar(RuntimeError.new('HtmlDialog não respondeu em 30 s. Confira a instalação e o Console Ruby.')) if @resultado[:etapa] == 'html_dialog'
        end
        @dialogo.show
      end

      def falhar(erro)
        UI.stop_timer(@temporizador) if @temporizador
        @resultado ||= {}
        @resultado.merge!(sucesso: false, etapa: 'falhou', erro: erro.message)
        warn "FAIL QA etiquetas: #{erro.class}: #{erro.message}"
        warn Array(erro.backtrace).first(8).join("\n")
        @resultado
      end
    end
  end
end

MarcenariaParametrica::VerificacaoEtiquetas.executar
