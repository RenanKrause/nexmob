require_relative 'suporte_catalogo_qr'
require_relative '../marcenaria_parametrica/servicos/catalogo_pecas'

class TesteCatalogoPecas < Minitest::Test
  include SuporteCatalogoQr
  def setup; preparar_modelo; end

  def test_varre_grupos_componentes_e_ambientes_sem_duplicar_peca
    ancestral = Sketchup::Group.new(@modelo)
    @modelo.entities << ancestral
    um = modulo_em(ancestral.entities)
    peca_em(um)
    dois = modulo_em([], @sala)
    outra = peca_em(dois, 'BASE')
    outra.set_attribute(PECA, 'qr_token', 'a' * 32)
    @modelo.entities << Sketchup::ComponentInstance.new(@modelo, [dois])
    estranho = Sketchup::Group.new(@modelo)
    @modelo.entities << estranho
    peca_em(estranho)

    itens = MarcenariaParametrica::CatalogoPecas.listar(@modelo)
    assert_equal 2, itens.length
    assert_equal ['Cozinha', 'Sala'], itens.map { |i| i[:ambiente] }
    assert_equal %w[LATERAL_ESQUERDA BASE], itens.map { |i| i[:codigo] }
    assert_equal [560.0, 720.0, 18.0], itens.first[:corte_mm]
    assert_equal 'MDF Freijó Puro', itens.first[:material]
    assert_equal 'CLIENTE PRIVADO 123', itens.first[:cliente]
    assert_equal({ 'top' => true, 'right' => false, 'bottom' => false, 'left' => false }, itens.first[:edge_banding])
  end

  def test_exclui_bloqueados_invisiveis_tags_e_medidas_invalidas_sem_parar_lote
    bom = modulo_em
    peca_em(bom)
    peca_em(bom, 'SEM_MEDIDA').set_attribute(PECA, 'comprimento_mm', nil)
    peca_em(bom, 'ZERO', [0, 2, 3])
    peca_em(bom, 'OCULTA').hidden = true
    peca_em(bom, 'TAG').layer = Struct.new(:visible?).new(false)
    peca_em(modulo_em).tap { |p| p.model.entities.last.locked = true }
    oculto = Sketchup::Group.new(@modelo)
    oculto.hidden = true
    @modelo.entities << oculto
    peca_em(modulo_em(oculto.entities))
    bloqueado = Sketchup::Group.new(@modelo)
    bloqueado.locked = true
    @modelo.entities << bloqueado
    peca_em(modulo_em(bloqueado.entities))
    assert_equal ['LATERAL_ESQUERDA'], MarcenariaParametrica::CatalogoPecas.listar(@modelo).map { |i| i[:codigo] }
  end

  def test_centro_mundial_e_eixos_locais_em_mm_com_ancestral_rotacionado_e_escala
    ancestral = Sketchup::Group.new(@modelo)
    ancestral.transformation = Geom::Transformation.caixa(x: 1000, y: 2000, z: 300, graus: 90)
    @modelo.entities << ancestral
    modulo = modulo_em(ancestral.entities)
    modulo.transformation = Geom::Transformation.caixa(x: 100)
    peca = peca_em(modulo, 'BASE', [100, 200, 20])
    peca.transformation = Geom::Transformation.caixa(x: 10, y: 20, escala: [2, 1, 1])
    item = MarcenariaParametrica::CatalogoPecas.listar(@modelo).first
    [200, 200, 20].zip(item[:dimensoes_mm]) { |esperado, real| assert_in_delta esperado, real, 0.00001 }
    [880, 2210, 310, 90].zip(item[:transform_mm]) { |esperado, real| assert_in_delta esperado, real, 0.00001 }
  end

  def test_preserva_identidades_e_migra_peca_legada_uma_unica_vez
    modulo = modulo_em
    peca = peca_em(modulo)
    peca.set_attribute(PECA, 'qr_token', 'ABCDEF0123456789ABCDEF0123456789')
    antes = MarcenariaParametrica::CatalogoPecas.listar(@modelo).first
    depois = MarcenariaParametrica::CatalogoPecas.listar(@modelo).first
    assert_equal antes[:modulo_id], depois[:modulo_id]
    assert_equal 'ABCDEF0123456789ABCDEF0123456789', depois[:qr_token]
    assert_equal 'chave-LATERAL_ESQUERDA', depois[:chave_logica]
    peca.set_attribute(PECA, 'chave_logica', nil)
    peca.set_attribute(PECA, 'qr_token', nil)
    migrado = MarcenariaParametrica::CatalogoPecas.listar(@modelo).first
    assert_match(/\A[0-9a-f]{32}\z/, migrado[:qr_token])
    assert_equal migrado[:qr_token], MarcenariaParametrica::CatalogoPecas.listar(@modelo).first[:qr_token]
    assert_equal 'MDF Freijó Puro', migrado[:material]
  end

  def test_fitas_todos_nenhuma_e_frente_sao_booleanos_dos_quatro_lados
    modulo = modulo_em
    peca = peca_em(modulo)
    { 'todos' => [true, true, true, true], 'nenhuma' => [false, false, false, false],
      'frente' => [true, false, false, false] }.each do |fita, esperado|
      peca.set_attribute(PECA, 'fita_borda', fita)
      item = MarcenariaParametrica::CatalogoPecas.listar(@modelo).first
      assert_equal esperado, item[:edge_banding].values_at('top', 'right', 'bottom', 'left')
    end
  end

  def test_modulo_aninhado_nao_entra_duas_vezes_e_centro_usa_bounds_local_deslocado
    pai = modulo_em
    filho = modulo_em(pai.entities, @sala)
    peca = peca_em(filho)
    peca.definition.bounds.center = Geom::Point3d.new(100 / 25.4, 200 / 25.4, 300 / 25.4)
    itens = MarcenariaParametrica::CatalogoPecas.listar(@modelo)
    assert_equal 1, itens.length
    assert_equal 'Sala', itens.first[:ambiente]
    [100, 200, 300, 0].zip(itens.first[:transform_mm]) { |esperado, real| assert_in_delta esperado, real, 0.00001 }
  end

  def test_nao_exporta_cisalhamento_ou_inclinacao_como_se_fosse_caixa_z
    modulo = modulo_em
    peca = peca_em(modulo)
    [
      [[1, 0.5, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]],
      [[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]]
    ].each do |matrix|
      peca.transformation = Geom::Transformation.new(matrix)
      assert_empty MarcenariaParametrica::CatalogoPecas.listar(@modelo)
    end
  end
end
