require_relative 'suporte_catalogo_qr'
require_relative '../marcenaria_parametrica/servicos/catalogo_pecas'
require_relative '../marcenaria_parametrica/servicos/manifesto_qr'

class TesteManifestoQr < Minitest::Test
  include SuporteCatalogoQr
  def setup
    preparar_modelo
    peca_em(modulo_em)
  end
  def gerar(catalogo = MarcenariaParametrica::CatalogoPecas.listar(@modelo))
    MarcenariaParametrica::ManifestoQr.gerar(@modelo, catalogo, revision_id: 'rev-1')
  end

  def test_revision_v1_exato_sem_cliente_ou_referencias_locais
    manifesto = gerar
    assert_equal %w[modules project_id revision_id schema_version synced_at], manifesto.keys.sort
    assert_equal @dados.ler(@modelo)['projeto_uuid'], manifesto['project_id']
    assert_equal '1', manifesto['schema_version']
    assert_equal 'rev-1', manifesto['revision_id']
    assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/, manifesto['synced_at'])
    modulo = manifesto['modules'].first
    assert_equal %w[environment module_id name pieces], modulo.keys.sort
    assert_equal 'Cozinha', modulo['environment']
    peca = modulo['pieces'].first
    assert_equal %w[cut_mm edge_banding logical_key material name qr_token transform_mm visible], peca.keys.sort
    [18, 560, 720].zip(peca['cut_mm']) { |esperado, real| assert_in_delta esperado, real, 0.00001 }
    [9, 280, 360, 0].zip(peca['transform_mm']) { |esperado, real| assert_in_delta esperado, real, 0.00001 }
    assert_equal '0123456789abcdef0123456789abcdef', peca['qr_token']
    assert_equal true, peca['visible']
    refute_includes JSON.generate(manifesto), 'CLIENTE PRIVADO 123'
  end

  def test_agrega_pecas_por_modulo_e_resolve_nome_atual_do_ambiente
    segundo = @modelo.entities.first
    peca_em(segundo, 'BASE').set_attribute(PECA, 'qr_token', 'b' * 32)
    @dados.renomear_ambiente(@modelo, @cozinha['id'], 'Copa')
    assert_equal 2, gerar['modules'].first['pieces'].length
    assert_equal 'Copa', gerar['modules'].first['environment']
  end

  def test_rejeita_token_repetido_chave_repetida_ou_id_de_modulo_ambiguo
    catalogo = MarcenariaParametrica::CatalogoPecas.listar(@modelo)
    assert_raises(ArgumentError) { gerar(catalogo + [catalogo.first.dup]) }
    outra = catalogo.first.merge(modulo_id: 'outro', chave_logica: 'outra')
    assert_raises(ArgumentError) { gerar(catalogo + [outra]) }
    outra = catalogo.first.merge(modulo_nome: 'Nome em conflito', chave_logica: 'outra', qr_token: 'a' * 32)
    assert_raises(ArgumentError) { gerar(catalogo + [outra]) }
  end

  def test_rejeita_dados_fora_do_contrato_sem_coercao
    catalogo = MarcenariaParametrica::CatalogoPecas.listar(@modelo)
    [{ dimensoes_mm: [1, 0, 3] }, { dimensoes_mm: [1, '2', 3] },
     { transform_mm: [0, 0, Float::INFINITY, 0] }, { qr_token: 'invalido' },
     { material: '' }, { edge_banding: { 'top' => true } }].each do |invalido|
      assert_raises(ArgumentError) { gerar([catalogo.first.merge(invalido)]) }
    end
    assert_raises(ArgumentError) { MarcenariaParametrica::ManifestoQr.gerar(@modelo, [], revision_id: '') }
    assert_empty gerar([])['modules']
  end

  # Execute com NEX_MOB_MANIFEST_FIXTURE=<arquivo> para exportar a saída Ruby real.
  def test_exporta_fixture_real_quando_solicitado
    caminho = ENV['NEX_MOB_MANIFEST_FIXTURE']
    File.write(caminho, JSON.pretty_generate(gerar)) if caminho && !caminho.empty?
    assert_kind_of Hash, gerar
  end
end
