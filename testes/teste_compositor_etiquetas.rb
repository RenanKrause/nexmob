require 'minitest/autorun'
require 'json'
require_relative '../marcenaria_parametrica/servicos/compositor_etiquetas'

class TesteCompositorEtiquetas < Minitest::Test
  def item
    { cliente: 'Ana <Cliente>', ambiente: 'Cozinha', modulo_nome: 'Balcão 1', nome: 'Lateral', codigo: 'LAT-1',
      corte_mm: [720, 560, 18], material: 'MDF Freijó Puro', fita_borda: 'frente',
      qr_token: '0123456789abcdef0123456789abcdef' }
  end

  def configuracao
    { 'viewer_base_url' => 'https://nexmob.pages.dev', 'revision_id' => 'rev-1', 'gerado_em' => '2026-10-17T20:00:00Z' }
  end

  def payload(html)
    JSON.parse(html[/<script type="application\/json" id="dados-impressao">(.*?)<\/script>/m, 1])
  end

  def test_documento_autossuficiente_conserva_dados_reais_e_token_sem_entidades_sketchup
    html = MarcenariaParametrica::CompositorEtiquetas.gerar(item.merge(peca: Object.new), configuracao)
    dados = payload(html)
    assert_equal 'Ana <Cliente>', dados['itens'][0]['cliente']
    assert_equal [720, 560, 18], dados['itens'][0]['corte_mm']
    assert_equal item[:qr_token], dados['itens'][0]['qr_token']
    refute dados['itens'][0].key?('peca')
    assert_equal 'termica', dados['modo']
    assert_includes html, 'qrcode'
    refute_match(/<script[^>]+src=/, html)
  end

  def test_lote_a4_mantem_tamanho_a4350_e_calibracao_sem_reduzir_celulas
    dados = payload(MarcenariaParametrica::CompositorEtiquetas.lote_a4(Array.new(11) { item }, configuracao.merge(
      'largura_mm' => 110, 'altura_mm' => 65, 'offset_x_mm' => 1, 'offset_y_mm' => -2)))
    assert_equal 'a4', dados['modo']
    assert_equal 11, dados['itens'].size
    assert_equal 1, dados['configuracao']['offset_x_mm']
    assert_equal 110, dados['configuracao']['largura_mm']
  end

  def test_rejeita_ilegibilidade_e_identidade_invalida_antes_de_entregar_html
    assert_raises(ArgumentError) { MarcenariaParametrica::CompositorEtiquetas.gerar(item, configuracao.merge('qr_mm' => 19)) }
    assert_raises(ArgumentError) { MarcenariaParametrica::CompositorEtiquetas.gerar(item.merge(qr_token: 'cliente'), configuracao) }
    assert_raises(ArgumentError) { MarcenariaParametrica::CompositorEtiquetas.gerar(item.merge(corte_mm: [0, 560, 18]), configuracao) }
    assert_raises(ArgumentError) { MarcenariaParametrica::CompositorEtiquetas.gerar(item, configuracao.merge('viewer_base_url' => 'javascript:alert(1)')) }
  end

  def test_escapa_fechamento_script_em_dados_privados
    html = MarcenariaParametrica::CompositorEtiquetas.gerar(item.merge(cliente: '</script><script>alert(1)</script>'), configuracao)
    refute_includes html, '</script><script>alert(1)'
    assert_equal '</script><script>alert(1)</script>', payload(html)['itens'][0]['cliente']
  end

  def test_documento_usa_data_real_da_geracao_e_nao_inclui_segredos_da_configuracao
    inicio = Time.now.utc - 1
    dados = payload(MarcenariaParametrica::CompositorEtiquetas.gerar(item, {
      'viewer_base_url' => 'https://nexmob.pages.dev', 'token' => 'SEGREDO INSTALACAO'
    }))
    instante = Time.iso8601(dados['configuracao']['gerado_em'])
    assert instante >= inicio && instante <= Time.now.utc
    refute dados['configuracao'].key?('token')
    refute dados['configuracao'].key?('revision_id')
  end
end
