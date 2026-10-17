module MarcenariaParametrica
  module FabricaDialogos
    def self.criar(titulo, arquivo, largura: 440, altura: 640, largura_minima: 360, altura_minima: 430)
      dialogo = UI::HtmlDialog.new(
        dialog_title: "Nex Mob · #{titulo}", preferences_key: "nex_mob.#{arquivo}",
        scrollable: true, resizable: true, width: largura, height: altura,
        min_width: largura_minima, min_height: altura_minima, style: UI::HtmlDialog::STYLE_UTILITY
      )
      dialogo.set_file(File.join(__dir__, "#{arquivo}.html"))
      dialogo
    end
  end
end
