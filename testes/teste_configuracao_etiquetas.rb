require 'minitest/autorun'
require_relative '../marcenaria_parametrica/configuracao/configuracao_etiquetas'

class TesteConfiguracaoEtiquetas < Minitest::Test
  def setup
    @dados = {}
    @armazenamento = armazenamento = Object.new
    dados = @dados
    armazenamento.define_singleton_method(:read_default) { |secao, chave, padrao| dados.fetch([secao, chave], padrao) }
    armazenamento.define_singleton_method(:write_default) { |secao, chave, valor| dados[[secao, chave]] = valor; true }
    @configuracao = MarcenariaParametrica::ConfiguracaoEtiquetas.new(armazenamento)
  end

  def test_tamanho_ativo_e_calibracao_sobrevivem_a_outra_instancia
    assert_equal 99, @configuracao.ler['largura_mm']
    assert_equal 55.8, @configuracao.ler['altura_mm']
    @configuracao.salvar('largura_mm' => 105, 'altura_mm' => 60, 'offset_x_mm' => -1.2, 'offset_y_mm' => 2.5)
    outra = MarcenariaParametrica::ConfiguracaoEtiquetas.new(@armazenamento)
    assert_equal 105, outra.ler['largura_mm']
    assert_equal(-1.2, outra.ler['offset_x_mm'])
    assert_equal 2.5, outra.ler['offset_y_mm']
    refute_empty @dados
  end

  def test_rejeita_lote_ilegivel_sem_alterar_preferencia
    [{ 'qr_mm' => 19.9 }, { 'texto_pt' => 5.9 }, { 'largura_mm' => 30 },
     { 'altura_mm' => 48 }, { 'altura_mm' => Float::INFINITY }, { 'largura_mm' => 'nan' },
     { 'offset_x_mm' => 7 }, { 'offset_y_mm' => -10 }].each do |entrada|
      assert_raises(ArgumentError) { @configuracao.salvar(entrada) }
    end
    assert_empty @dados
  end

  def test_salvar_parcial_preserva_o_tamanho_ativo
    @configuracao.salvar('largura_mm' => 110, 'altura_mm' => 65)
    @configuracao.salvar('offset_x_mm' => 1)
    assert_equal 110, @configuracao.ler['largura_mm']
    assert_equal 65, @configuracao.ler['altura_mm']
  end

  def test_preferencia_corrompida_retorna_padrao
    @dados[['NexMob', 'etiquetas']] = '{'
    assert_equal 99, @configuracao.ler['largura_mm']
  end
end
