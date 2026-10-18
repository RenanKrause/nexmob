module MarcenariaParametrica
  class ComandosPlugin
    def initialize(controlador)
      @comandos = [
        criar('Inserir módulo', 'catalogo', 'Abra o catálogo Nex Mob.', controlador.method(:abrir_catalogo)),
        criar('Editar módulo e vãos', 'editar', 'Clique nos vãos do móvel para editar.', controlador.method(:abrir_edicao)),
        criar('Portas e frentes', 'frentes', 'Adicione portas e frentes de gaveta.', controlador.method(:abrir_frentes)),
        criar('Modo construtivo', 'construcao', 'Configure e salve os modos construtivos.', controlador.method(:abrir_modo_construtivo)),
        criar('Dados do projeto', 'projeto', 'Cadastre cliente e ambientes do projeto.', controlador.method(:abrir_projeto)),
        criar('Etiquetas e QR', 'etiquetas', 'Sincronize o projeto e imprima etiquetas térmicas ou A4.', controlador.method(:abrir_etiquetas))
      ]
      @barra = UI::Toolbar.new('Nex Mob')
      menu = UI.menu('Plugins').add_submenu('Nex Mob')
      @comandos.each { |comando| @barra.add_item(comando); menu.add_item(comando) }
      menu.add_item('Mostrar barra de ferramentas') { @barra.show }
      @barra.get_last_state == TB_NEVER_SHOWN ? @barra.show : @barra.restore
    end

    private

    def criar(titulo, icone, descricao, acao)
      comando = UI::Command.new(titulo) { acao.call }
      comando.tooltip = "Nex Mob · #{titulo}"
      comando.status_bar_text = descricao
      comando.small_icon = File.join(__dir__, '..', 'icones', "#{icone}.svg")
      comando.large_icon = comando.small_icon
      comando
    end
  end
end
