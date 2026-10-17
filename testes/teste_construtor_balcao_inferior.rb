require 'minitest/autorun'
require_relative '../marcenaria_parametrica/construtores/construtor_balcao_inferior'

class TesteConstrutorBalcaoInferior < Minitest::Test
  def test_plano_desconta_espessuras_e_usa_dois_sarrafos_superiores
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO
    plano = MarcenariaParametrica::ConstrutorBalcaoInferior.planejar(parametros)

    assert_equal 6, plano.length
    assert_equal [764.0, 554.0, 18.0], plano.find { |peca| peca[:codigo] == 'BASE' }[:corte_mm]
    assert_equal [800.0, 720.0, 6.0], plano.find { |peca| peca[:codigo] == 'FUNDO' }[:corte_mm]
    assert_equal [18.0, 554.0, 720.0], plano.find { |peca| peca[:codigo] == 'LATERAL_ESQUERDA' }[:dimensoes_mm]
    assert_equal [764.0, 80.0, 18.0], plano.find { |peca| peca[:codigo] == 'SARRAFO_FRONTAL' }[:corte_mm]
    assert_equal [18.0, 474.0, 702.0], plano.find { |peca| peca[:codigo] == 'SARRAFO_TRASEIRO' }[:posicao_mm]
    refute plano.any? { |peca| peca[:codigo] == 'TAMPO' || peca[:codigo] == 'PRATELEIRA' }
  end

  def test_vão_inicial_ocupa_area_interna_da_caixa
    vaos = MarcenariaParametrica::ConstrutorBalcaoInferior.vaos(
      MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO
    )

    assert_equal [{ id: 'vao', limites_mm: [18.0, 782.0, 18.0, 702.0] }], vaos
  end

  def test_prateleira_divide_vão_e_divisoria_subdivide_apenas_o_vão_escolhido
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior
    parametros = construtor::PADRAO
    divisoes = construtor.adicionar_divisao(parametros, [], 'vao', 'prateleira', 333.0)
    divisoes = construtor.adicionar_divisao(parametros, divisoes, 'vao_S', 'divisoria', 373.0)
    plano = construtor.planejar(parametros, divisoes)

    assert_equal 8, plano.length
    assert_equal [18.0, 0.0, 351.0], plano.find { |peca| peca[:codigo] == 'PRATELEIRA_1' }[:posicao_mm]
    assert_equal [391.0, 0.0, 369.0], plano.find { |peca| peca[:codigo] == 'DIVISORIA_2' }[:posicao_mm]
    assert_equal %w[vao_I vao_S_E vao_S_D], construtor.vaos(parametros, divisoes).map { |vao| vao[:id] }
  end

  def test_rejeita_divisao_que_deixa_vão_muito_estreito
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior

    assert_raises(ArgumentError) do
      construtor.adicionar_divisao(construtor::PADRAO, [], 'vao', 'divisoria', 10.0)
    end
  end

  def test_migracao_preserva_prateleira_do_modulo_antigo
    grupo = Object.new
    grupo.define_singleton_method(:get_attribute) do |_dicionario, chave|
      chave == 'versao_esquema' ? 1 : nil
    end
    construtor = MarcenariaParametrica::ConstrutorBalcaoInferior

    divisoes = construtor.ler_divisoes(grupo)
    assert_equal 1, divisoes.length
    assert_equal 'PRATELEIRA_1', construtor.planejar(construtor::PADRAO, divisoes).last[:codigo]
  end

  def test_rejeita_sarrafos_que_se_sobrepoem
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO.merge(
      'profundidade_mm' => 250, 'largura_sarrafo_mm' => 150
    )

    assert_raises(ArgumentError) do
      MarcenariaParametrica::ConstrutorBalcaoInferior.planejar(parametros)
    end
  end

  def test_rejeita_dimensoes_sem_espaco_interno
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO.merge('largura_mm' => 30)

    assert_raises(ArgumentError) do
      MarcenariaParametrica::ConstrutorBalcaoInferior.planejar(parametros)
    end
  end

  def test_rejeita_valor_nao_numerico
    parametros = MarcenariaParametrica::ConstrutorBalcaoInferior::PADRAO.merge('altura_mm' => 'invalido')

    assert_raises(ArgumentError) do
      MarcenariaParametrica::ConstrutorBalcaoInferior.planejar(parametros)
    end
  end
end
