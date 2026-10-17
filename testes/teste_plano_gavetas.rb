require 'minitest/autorun'
require_relative '../marcenaria_parametrica/dominio/plano_gavetas'

class TestePlanoGavetas < Minitest::Test
  def setup
    @parametros = MarcenariaParametrica::PlanoBalcaoInferior::PADRAO
    @plano = MarcenariaParametrica::PlanoGavetas
  end

  def test_planeja_cinco_chapas_por_gaveta_com_fundo_entre_as_laterais
    gavetas = [{ 'vao_id' => 'vao', 'quantidade' => 3 }]
    pecas = @plano.planejar(@parametros, [], gavetas)

    assert_equal 15, pecas.length
    assert_equal [15.0, 540.0, 224.0], pecas.find { |peca| peca[:codigo] == 'GAVETA_1_1_LATERAL_ESQUERDA' }[:dimensoes_mm]
    assert_equal [708.0, 15.0, 224.0], pecas.find { |peca| peca[:codigo] == 'GAVETA_1_1_CONTRA_FRENTE' }[:dimensoes_mm]
    assert_equal [708.0, 510.0, 6.0], pecas.find { |peca| peca[:codigo] == 'GAVETA_1_1_FUNDO' }[:dimensoes_mm]
    assert_equal [46.0, 17.0, 21.0], pecas.find { |peca| peca[:codigo] == 'GAVETA_1_1_FUNDO' }[:posicao_mm]
  end

  def test_rejeita_mais_de_um_conjunto_de_gavetas_no_mesmo_vao
    gavetas = [{ 'vao_id' => 'vao', 'quantidade' => 1 }, { 'vao_id' => 'vao', 'quantidade' => 1 }]

    assert_raises(ArgumentError) { @plano.planejar(@parametros, [], gavetas) }
  end

  def test_descarta_gavetas_quando_o_vao_de_origem_deixa_de_existir
    divisao = [{ 'vao_id' => 'vao', 'tipo' => 'prateleira', 'proporcao' => 0.5 }]
    gavetas = [{ 'vao_id' => 'vao', 'quantidade' => 1 }]

    assert_equal [], @plano.validas(@parametros, divisao, gavetas)
  end

  def test_redimensiona_uma_gaveta_sem_alterar_as_demais
    gavetas = @plano.adicionar(@parametros, [], [], 'vao', 2)
    alteradas = @plano.redimensionar(@parametros, [], gavetas, 'gaveta_1_1', 20, 300, 500)
    primeira = @plano.representacoes(@parametros, [], alteradas).find { |gaveta| gaveta[:id] == 'gaveta_1_1' }
    segunda = @plano.representacoes(@parametros, [], alteradas).find { |gaveta| gaveta[:id] == 'gaveta_1_2' }

    assert_equal 20.0, primeira[:posicao_mm]
    assert_equal 300.0, primeira[:altura_mm]
    assert_equal 500.0, primeira[:profundidade_mm]
    assert_equal 337.5, segunda[:altura_mm]
  end

  def test_duplica_gaveta_unica_dividindo_o_vao_em_duas_caixas
    gavetas = @plano.adicionar(@parametros, [], [], 'vao', 1)
    duplicadas = @plano.duplicar(@parametros, [], gavetas, 'gaveta_1_1')
    representacoes = @plano.representacoes(@parametros, [], duplicadas)

    assert_equal 2, representacoes.length
    assert_equal [337.5, 337.5], representacoes.map { |gaveta| gaveta[:altura_mm] }
  end

  def test_respeita_folgas_independentes_na_base_sarrafo_e_entre_gavetas
    parametros = @parametros.merge('folga_base_gaveta_mm' => 10, 'folga_sarrafo_gaveta_mm' => 20,
                                   'folga_vertical_gaveta_mm' => 5)
    gavetas = @plano.adicionar(parametros, [], [], 'vao', 2)
    representacoes = @plano.representacoes(parametros, [], gavetas)

    assert_equal [10.0, 339.5], representacoes.map { |gaveta| gaveta[:posicao_mm] }
    assert_equal [324.5, 324.5], representacoes.map { |gaveta| gaveta[:altura_mm] }
  end
end
