require 'minitest/autorun'
require_relative '../marcenaria_parametrica/dominio/plano_frentes'

class TestePlanoFrentes < Minitest::Test
  def setup
    @parametros = MarcenariaParametrica::PlanoBalcaoInferior::PADRAO
    @plano = MarcenariaParametrica::PlanoFrentes
  end

  def test_planeja_duas_portas_com_folgas_iguais
    frentes = @plano.definir(@parametros, [], [], [], {
      'vao_id' => 'vao', 'tipo' => 'portas', 'quantidade' => 2,
      'espessura_mm' => 18, 'folga_mm' => 2, 'recuo_mm' => 0
    })
    pecas = @plano.planejar(@parametros, [], [], frentes)

    assert_equal 2, pecas.length
    assert_equal [20.0, -18.0, 20.0], pecas.first[:posicao_mm]
    assert_equal [379.0, 18.0, 680.0], pecas.first[:dimensoes_mm]
  end

  def test_vincula_frente_de_gaveta_a_caixa_do_vao
    gavetas = MarcenariaParametrica::PlanoGavetas.adicionar(@parametros, [], [], 'vao', 1)
    frentes = @plano.definir(@parametros, [], gavetas, [], {
      'vao_id' => 'vao', 'tipo' => 'frentes_gavetas',
      'espessura_mm' => 18, 'folga_mm' => 2, 'recuo_mm' => 0
    })
    peca = @plano.planejar(@parametros, [], gavetas, frentes).first

    assert_equal 'gaveta_1_1', peca[:gaveta_destino]
    assert_equal [760.0, 18.0, 674.0], peca[:dimensoes_mm]
  end

  def test_sugere_duas_portas_para_um_vao_de_764_mm
    assert_equal 2, @plano.quantidade_portas_sugerida(@parametros, 764)
  end

  def test_sincroniza_portas_com_as_regras_do_modo_construtivo
    frentes = @plano.definir(@parametros, [], [], [], {
      'vao_id' => 'vao', 'tipo' => 'portas', 'quantidade' => 2,
      'espessura_mm' => 15, 'folga_mm' => 1, 'recuo_mm' => 4
    })
    parametros = @parametros.merge('espessura_porta_mm' => 20, 'folga_porta_mm' => 3, 'recuo_porta_mm' => 2)
    sincronizadas = @plano.sincronizar_com_modo(parametros, [], [], frentes)

    assert_equal 20.0, sincronizadas.first['espessura_mm']
    assert_equal 3.0, sincronizadas.first['folga_mm']
    assert_equal 2.0, sincronizadas.first['recuo_mm']
    assert_equal 2, sincronizadas.first['quantidade']
  end
end
