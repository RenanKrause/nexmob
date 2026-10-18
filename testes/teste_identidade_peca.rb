require 'minitest/autorun'
require_relative '../marcenaria_parametrica/dominio/identidade_peca'

class TesteIdentidadePeca < Minitest::Test
  DICIONARIO = 'marcenaria_parametrica_peca'.freeze

  def setup
    @identidade = MarcenariaParametrica::IdentidadePeca
  end

  def grupo_com(atributos)
    grupo = Object.new
    grupo.define_singleton_method(:get_attribute) do |dicionario, chave|
      dicionario == DICIONARIO ? atributos[chave] : nil
    end
    grupo
  end

  def test_chave_preserva_lado_e_nao_depende_de_dimensoes_posicao_ou_nome
    esquerda = { codigo: 'LATERAL_ESQUERDA', nome: 'Lateral', corte_mm: [554, 720, 18] }
    direita = esquerda.merge(codigo: 'LATERAL_DIREITA')

    refute_equal @identidade.chave_logica(esquerda), @identidade.chave_logica(direita)
    assert_equal @identidade.chave_logica(esquerda),
                 @identidade.chave_logica(esquerda.merge(nome: 'Renomeada', corte_mm: [600, 800, 18], posicao_mm: [1, 2, 3]))
  end

  def test_chave_distingue_origens_de_vao_gaveta_e_frente_e_preserva_separadores
    [:vao_id, :vao_destino, :gaveta_id, :gaveta_destino, :frente_id].each do |origem|
      refute_equal @identidade.chave_logica({ codigo: 'PECA' }.merge(origem => 'a')),
                   @identidade.chave_logica({ codigo: 'PECA' }.merge(origem => 'b')), origem.to_s
    end
    refute_equal @identidade.chave_logica(codigo: 'A|B', vao_id: 'C'),
                 @identidade.chave_logica(codigo: 'A', vao_id: 'B|C')
  end

  def test_chaves_de_todas_as_pecas_do_layout_sao_unicas
    parametros = MarcenariaParametrica::PlanoBalcaoInferior::PADRAO
    pecas = MarcenariaParametrica::PlanoBalcaoInferior.planejar(parametros)

    assert_equal 6, pecas.map { |peca| @identidade.chave_logica(peca) }.uniq.length
  end

  def test_divisao_usa_tipo_e_vao_sem_depender_do_numero_de_fabricacao
    %w[PRATELEIRA DIVISORIA].each do |tipo|
      assert_equal @identidade.chave_logica(codigo: "#{tipo}_3", vao_id: 'vao_D'),
                   @identidade.chave_logica(codigo: "#{tipo}_2", vao_id: 'vao_D')
    end
    refute_equal @identidade.chave_logica(codigo: 'PRATELEIRA_2', vao_id: 'vao_D'),
                 @identidade.chave_logica(codigo: 'DIVISORIA_2', vao_id: 'vao_D')
    refute_equal @identidade.chave_logica(codigo: 'PRATELEIRA_2', vao_id: 'vao_E'),
                 @identidade.chave_logica(codigo: 'PRATELEIRA_2', vao_id: 'vao_D')
    refute_equal @identidade.chave_logica(codigo: 'PRATELEIRA_1'),
                 @identidade.chave_logica(codigo: 'PRATELEIRA_2')
  end

  def test_nao_cria_chave_ambigua_para_peca_sem_codigo
    assert_raises(ArgumentError) { @identidade.chave_logica(nome: 'Lateral') }
  end

  def test_cria_token_hexadecimal_de_128_bits_distinto_para_cada_peca
    tokens = 32.times.map { @identidade.atributos_para({ codigo: 'BASE' }, {})['qr_token'] }

    tokens.each { |token| assert_match(/\A[0-9a-f]{32}\z/, token) }
    assert_equal 32, tokens.uniq.length
  end

  def test_reutiliza_token_valido_sem_gerar_outro
    peca = { codigo: 'BASE' }
    chave = @identidade.chave_logica(peca)
    anteriores = { chave => { 'qr_token' => '0123456789abcdef0123456789abcdef' } }
    SecureRandom.stub(:hex, ->(*) { flunk 'Token existente não deve ser regenerado.' }) do
      assert_equal '0123456789abcdef0123456789abcdef', @identidade.atributos_para(peca, anteriores)['qr_token']
    end
  end

  def test_token_invalido_e_substituido_por_token_hexadecimal
    peca = { codigo: 'BASE' }
    chave = @identidade.chave_logica(peca)
    [nil, '', 'cliente-123', 'a' * 31, 'a' * 33, 'g' * 32].each do |token|
      atributos = @identidade.atributos_para(peca, chave => { 'qr_token' => token })
      assert_match(/\A[0-9a-f]{32}\z/, atributos['qr_token'])
    end
  end

  def test_substituicao_sobrevive_a_novo_padrao_sem_passar_para_outra_lateral
    esquerda = { codigo: 'LATERAL_ESQUERDA', material_padrao: 'MDF Branco' }
    direita = esquerda.merge(codigo: 'LATERAL_DIREITA')
    anteriores = { @identidade.chave_logica(esquerda) => {
      'qr_token' => '1' * 32, 'material_padrao' => 'MDP', 'material_sobrescrito' => 'MDF Freijó Puro'
    } }

    atributos = @identidade.atributos_para(esquerda, anteriores)
    assert_equal 'MDF Branco', atributos['material_padrao']
    assert_equal 'MDF Freijó Puro', atributos['material_sobrescrito']
    assert_equal 'MDF Freijó Puro', @identidade.material_efetivo(grupo_com(atributos))
    assert_equal 'MDF Branco', @identidade.material_efetivo(grupo_com(@identidade.atributos_para(direita, anteriores)))
  end

  def test_sem_substituicao_usa_material_padrao_atual
    peca = { codigo: 'BASE', material_padrao: 'MDF Branco' }
    anteriores = { @identidade.chave_logica(peca) => { 'material_padrao' => 'MDP', 'material_sobrescrito' => '' } }
    atributos = @identidade.atributos_para(peca, anteriores)

    assert_equal 'MDF Branco', @identidade.material_efetivo(grupo_com(atributos))
    assert_equal '', atributos['material_sobrescrito']
    assert_equal 'MDP', @identidade.material_efetivo(grupo_com({}))
    assert_equal 'MDF Legado', @identidade.material_efetivo(grupo_com('material' => 'MDF Legado'))
  end

  def test_material_da_peca_e_aceito_como_padrao_e_vazios_usam_mdp
    assert_equal 'MDF Branco', @identidade.atributos_para({ codigo: 'BASE', material: 'MDF Branco' }, {})['material_padrao']
    assert_equal 'MDP', @identidade.atributos_para({ codigo: 'BASE', material_padrao: ' ' }, {})['material_padrao']
  end
end
