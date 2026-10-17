require 'minitest/autorun'
require_relative '../marcenaria_parametrica/ferramentas/ferramenta_selecao_vao'

class TesteFerramentaSelecaoVao < Minitest::Test
  def test_dois_cliques_selecionam_vaos_sem_encerrar_a_ferramenta
    modelo = Object.new
    encerramentos = []
    modelo.define_singleton_method(:select_tool) { |ferramenta| encerramentos << ferramenta }
    visualizacao = Object.new
    visualizacao.define_singleton_method(:invalidate) {}
    recebidos = []
    ferramenta = MarcenariaParametrica::FerramentaSelecaoVao.new(modelo, nil, [], proc { |vao| recebidos << vao[:id] })
    ferramenta.define_singleton_method(:identificar) { |_vista, x, _y| { id: "vao_#{x}" } }

    ferramenta.onLButtonDown(0, 1, 0, visualizacao)
    ferramenta.onLButtonDown(0, 2, 0, visualizacao)

    assert_equal %w[vao_1 vao_2], recebidos
    assert_empty encerramentos
  end

  def test_localiza_apenas_o_vão_em_que_o_ponto_cai
    vaos = [
      { id: 'vao_I', limites_mm: [18.0, 782.0, 18.0, 351.0] },
      { id: 'vao_S', limites_mm: [18.0, 782.0, 369.0, 702.0] }
    ]

    assert_equal 'vao_S', MarcenariaParametrica::FerramentaSelecaoVao.localizar_vao(vaos, 400, 500)[:id]
    assert_nil MarcenariaParametrica::FerramentaSelecaoVao.localizar_vao(vaos, 400, 360)
    assert_nil MarcenariaParametrica::FerramentaSelecaoVao.localizar_vao(vaos, 800, 500)
  end
end
