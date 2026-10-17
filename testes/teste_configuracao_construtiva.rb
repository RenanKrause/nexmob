require 'minitest/autorun'
require_relative '../marcenaria_parametrica/configuracao/configuracao_construtiva'

class TesteConfiguracaoConstrutiva < Minitest::Test
  def configuracao
    armazenamento = Object.new
    dados = {}
    armazenamento.define_singleton_method(:read_default) { |secao, chave, padrao| dados.fetch([secao, chave], padrao) }
    armazenamento.define_singleton_method(:write_default) { |secao, chave, valor| dados[[secao, chave]] = valor; true }
    MarcenariaParametrica::ConfiguracaoConstrutiva.new(armazenamento)
  end

  def test_salvar_inferiores_nao_altera_superiores
    registro = configuracao
    registro.salvar('inferiores', { 'espessura_mm' => 25, 'espessura_fundo_mm' => 9, 'largura_sarrafo_mm' => 100 })
    assert_equal 25, registro.ler('inferiores')['espessura_mm']
    assert_equal 18, registro.ler('superiores')['espessura_mm']
    refute registro.ler('armarios').key?('largura_sarrafo_mm')
  end

  def test_rejeita_valores_invalidos_sem_sobrescrever_padrao
    registro = configuracao
    assert_raises(ArgumentError) { registro.salvar('inferiores', { 'espessura_mm' => 0 }) }
    assert_equal 18, registro.ler('inferiores')['espessura_mm']
    assert_raises(ArgumentError) { registro.salvar('inexistente', {}) }
  end

  def test_modos_nomeados_preservam_as_tres_familias_ao_alternar
    registro = configuracao
    registro.salvar_modo('Reforçado', {
      'inferiores' => { 'espessura_mm' => 25 },
      'superiores' => { 'espessura_fundo_mm' => 9 },
      'armarios' => { 'espessura_mm' => 20 }
    })
    assert_equal 25, registro.ler('inferiores')['espessura_mm']
    assert_equal 9, registro.ler('superiores')['espessura_fundo_mm']
    assert_equal 20, registro.ler('armarios')['espessura_mm']
    registro.ativar('Padrão')
    assert_equal 18, registro.ler('inferiores')['espessura_mm']
    registro.ativar('Reforçado')
    assert_equal 25, registro.ler('inferiores')['espessura_mm']
    assert_equal 2, registro.carregar['modos'].size
  end

  def test_inferiores_guardam_regras_de_gavetas_portas_e_frentes
    valores = configuracao.ler('inferiores')

    assert_equal 3, valores['folga_base_gaveta_mm']
    assert_equal 3, valores['folga_sarrafo_gaveta_mm']
    assert_equal 18, valores['espessura_porta_mm']
    assert_equal 450, valores['largura_referencia_porta_mm']
    assert_equal 2, valores['folga_frente_gaveta_mm']
  end
end
