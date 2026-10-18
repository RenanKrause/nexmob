require 'minitest/autorun'
require 'json'
require_relative '../marcenaria_parametrica/servicos/cliente_sincronizacao'

class TesteClienteSincronizacao < Minitest::Test
  class Transporte
    attr_accessor :use_ssl, :open_timeout, :read_timeout, :write_timeout, :max_retries
    attr_reader :pedido
    def initialize(codigo = '201', erro = nil)
      @codigo, @erro = codigo, erro
    end
    def request(pedido)
      @pedido = pedido
      raise @erro if @erro
      Struct.new(:code, :body).new(@codigo, '{"token":"SEGREDO","error":"interno"}')
    end
  end
  def publicar(transporte, url: 'https://sync.example/v1/revisions', token: 'SEGREDO')
    Net::HTTP.stub(:new, transporte) do
      MarcenariaParametrica::ClienteSincronizacao.publicar(url: url, token: token, manifesto: { 'schema_version' => '1' })
    end
  end

  def test_post_json_autenticado_so_no_header_e_com_timeouts
    transporte = Transporte.new
    resultado = publicar(transporte)
    assert resultado.sucesso?
    assert_equal :sucesso, resultado.status
    assert_equal 201, resultado.http_status
    assert_instance_of Net::HTTP::Post, transporte.pedido
    assert_equal '/v1/revisions', transporte.pedido.path
    assert_equal 'Bearer SEGREDO', transporte.pedido['Authorization']
    assert_equal 'application/json', transporte.pedido['Content-Type']
    assert_equal({ 'schema_version' => '1' }, JSON.parse(transporte.pedido.body))
    assert transporte.use_ssl
    assert_operator transporte.open_timeout, :>, 0
    assert_operator transporte.read_timeout, :>, 0
    assert_operator transporte.write_timeout, :>, 0
    assert_equal 0, transporte.max_retries
    refute_includes resultado.inspect, 'SEGREDO'
  end

  def test_status_distingue_sucesso_credencial_validacao_e_servidor_sem_refletir_resposta
    { '200' => :sucesso, '204' => :sucesso, '401' => :credencial_recusada,
      '400' => :validacao, '403' => :validacao, '409' => :validacao, '503' => :servidor }.each do |codigo, status|
      resultado = publicar(Transporte.new(codigo))
      assert_equal status, resultado.status
      assert_equal codigo.to_i, resultado.http_status
      refute_includes resultado.inspect, 'SEGREDO'
      refute_includes resultado.mensagem, 'interno'
    end
  end

  def test_rede_e_timeout_nao_vazam_excecao_url_ou_credencial
    [Net::ReadTimeout.new('SEGREDO'), SocketError.new('SEGREDO'), IOError.new('SEGREDO')].each do |erro|
      resultado = publicar(Transporte.new('201', erro))
      assert_equal :rede, resultado.status
      refute resultado.sucesso?
      assert_nil resultado.http_status
      refute_includes resultado.inspect, 'SEGREDO'
    end
  end

  def test_recusa_url_insegura_com_credencial_query_fragmento_e_token_invalido_antes_de_enviar
    ['http://sync.example/v1/revisions', 'https://user:SEGREDO@sync.example/v1/revisions',
     'https://sync.example/v1/revisions?token=SEGREDO', 'https://sync.example/v1/revisions#SEGREDO'].each do |url|
      transporte = Transporte.new
      resultado = publicar(transporte, url: url)
      assert_equal :configuracao, resultado.status
      assert_nil transporte.pedido
      refute_includes resultado.inspect, 'SEGREDO'
    end
    assert_equal :configuracao, publicar(Transporte.new, token: "SEGREDO\nHeader: valor").status
  end

  def test_json_circular_ou_nao_finito_retorna_validacao_sem_envio
    circular = []
    circular << circular
    [circular, { 'numero' => Float::INFINITY }].each do |manifesto|
      transporte = Transporte.new
      Net::HTTP.stub(:new, transporte) do
        resultado = MarcenariaParametrica::ClienteSincronizacao.publicar(
          url: 'https://sync.example/v1/revisions', token: 'SEGREDO', manifesto: manifesto
        )
        assert_equal :validacao, resultado.status
        assert_nil transporte.pedido
        refute_includes resultado.inspect, 'SEGREDO'
      end
    end
  end
end
