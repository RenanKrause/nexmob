require 'minitest/autorun'
require_relative '../marcenaria_parametrica/dominio/edicao_divisoes'

class TesteEdicaoDivisoes < Minitest::Test
  def setup
    @parametros = MarcenariaParametrica::PlanoBalcaoInferior::PADRAO
    @plano = MarcenariaParametrica::PlanoBalcaoInferior
    @edicao = MarcenariaParametrica::EdicaoDivisoes
    @divisoes = @plano.adicionar_divisao(@parametros, [], 'vao', 'prateleira', 333)
  end

  def test_posicao_absoluta_e_limites_da_peca
    peca = @edicao.pecas(@parametros, @divisoes).first
    assert_in_delta 351, peca[:posicao_mm]
    assert_equal [18.0, 782.0, 351.0, 369.0], peca[:limites_mm]
    assert_in_delta 98, peca[:minimo_mm]
    assert_in_delta 604, peca[:maximo_mm]
  end

  def test_movimento_recalcula_descendentes_sem_mudar_o_original
    originais = @plano.adicionar_divisao(@parametros, @divisoes, 'vao_S', 'divisoria', 373)
    alteradas = @edicao.mover(@parametros, originais, 'vao', 450)
    pecas = @edicao.pecas(@parametros, alteradas)
    assert_in_delta 450, pecas[0][:posicao_mm]
    assert_in_delta 468, pecas[1][:limites_mm][2]
    assert_in_delta 0.5, originais[0]['proporcao']
  end

  def test_movimento_invalido_por_descendente_nao_altera_arvore
    originais = @plano.adicionar_divisao(@parametros, @divisoes, 'vao_S', 'prateleira', 157)
    assert_raises(ArgumentError) { @edicao.mover(@parametros, originais, 'vao', 590) }
    assert_equal 2, originais.length
    assert_in_delta 0.5, originais[0]['proporcao']
    assert_raises(ArgumentError) { @edicao.mover(@parametros, originais, 'vao', Float::NAN) }
  end

  def test_duplicar_preserva_peca_e_acrescenta_no_vao_adjacente
    novas = @edicao.duplicar(@parametros, @divisoes, 'vao')
    assert_equal 2, novas.length
    assert_equal @divisoes.first, novas.first
    assert_equal 'vao_S', novas.last['vao_id']
    assert_equal 3, @plano.vaos(@parametros, novas).length
  end

  def test_excluir_divisao_remove_tambem_os_descendentes
    novas = @plano.adicionar_divisao(@parametros, @divisoes, 'vao_S', 'divisoria', 373)
    assert_empty @edicao.excluir(@parametros, novas, 'vao')
    assert_equal @divisoes, @edicao.excluir(@parametros, novas, 'vao_S')
    assert_empty @edicao.excluir(@parametros, @divisoes, 'vao')
  end

  def test_divisoria_mede_a_partir_da_lateral_externa
    divisoes = @plano.adicionar_divisao(@parametros, [], 'vao', 'divisoria', 373)
    novas = @edicao.mover(@parametros, divisoes, 'vao', 300)
    assert_in_delta 300, @edicao.pecas(@parametros, novas).first[:posicao_mm]
  end

  def test_alcas_aparecem_apenas_nas_bordas_com_divisoes_editaveis
    vaos = @plano.vaos(@parametros, @divisoes)
    pecas = @edicao.pecas(@parametros, @divisoes)
    inferior = @edicao.bordas(vaos.find { |vao| vao[:id] == 'vao_I' }, pecas)
    superior = @edicao.bordas(vaos.find { |vao| vao[:id] == 'vao_S' }, pecas)
    assert_equal [:superior], inferior.map { |borda| borda[:lado] }
    assert_equal [:inferior], superior.map { |borda| borda[:lado] }
    assert_equal 'vao', superior.first[:peca][:id]
  end

  def test_medida_digitada_corresponde_ao_vao_livre_inferior
    divisoes = @edicao.mover_por_vao(@parametros, @divisoes, 'vao', 350)
    peca = @edicao.pecas(@parametros, divisoes).first
    assert_in_delta 350, peca[:vao_livre_mm], 0.001
    assert_in_delta 368, peca[:posicao_mm], 0.001
    inferior = @plano.vaos(@parametros, divisoes).find { |vao| vao[:id] == 'vao_I' }
    assert_in_delta 350, inferior[:limites_mm][3] - inferior[:limites_mm][2], 0.001
  end

  def test_medida_digitada_corresponde_ao_vao_livre_esquerdo_em_arvore_aninhada
    divisoes = @plano.adicionar_divisao(@parametros, @divisoes, 'vao_I', 'divisoria', 373)
    alteradas = @edicao.mover_por_vao(@parametros, divisoes, 'vao_I', 350)
    peca = @edicao.pecas(@parametros, alteradas).last
    assert_in_delta 350, peca[:vao_livre_mm], 0.001
    assert_in_delta 368, peca[:posicao_mm], 0.001
    esquerda = @plano.vaos(@parametros, alteradas).find { |vao| vao[:id] == 'vao_I_E' }
    assert_in_delta 350, esquerda[:limites_mm][1] - esquerda[:limites_mm][0], 0.001
    assert_in_delta 373, @edicao.pecas(@parametros, divisoes).last[:vao_livre_mm], 0.001
  end

  def test_tres_prateleiras_mantem_primeiro_vao_exato_e_distribui_restantes
    divisoes = @edicao.adicionar_multiplas(@parametros, [], 'vao', 'prateleira', 250, 3)
    assert_equal 3, divisoes.length
    assert_equal %w[vao vao_S vao_S_S], divisoes.map { |item| item['vao_id'] }
    alturas = @plano.vaos(@parametros, divisoes).map { |vao| vao[:limites_mm][3] - vao[:limites_mm][2] }
    assert_in_delta 250, alturas.first, 0.001
    alturas.drop(1).each { |altura| assert_in_delta (684 - 250 - 3 * 18) / 3.0, altura, 0.001 }
  end

  def test_duas_divisorias_tem_primeiro_vao_exato_e_uma_operacao_de_plano
    divisoes = @edicao.adicionar_multiplas(@parametros, [], 'vao', 'divisoria', 350, 2)
    larguras = @plano.vaos(@parametros, divisoes).map { |vao| vao[:limites_mm][1] - vao[:limites_mm][0] }
    assert_equal 2, divisoes.length
    assert_in_delta 350, larguras.first, 0.001
    larguras.drop(1).each { |largura| assert_in_delta 189, largura, 0.001 }
  end

  def test_lote_invalido_nao_modifica_divisoes_originais
    assert_raises(ArgumentError) { @edicao.adicionar_multiplas(@parametros, @divisoes, 'vao_S', 'prateleira', 250, 3) }
    assert_equal 1, @divisoes.length
    assert_raises(ArgumentError) { @edicao.adicionar_multiplas(@parametros, [], 'vao', 'divisoria', 350, 8) }
  end
end
