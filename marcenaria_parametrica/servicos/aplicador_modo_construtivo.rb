module MarcenariaParametrica
  class AplicadorModoConstrutivo
    def initialize(modelo)
      @modelo = modelo
    end

    def aplicar(categorias)
      raise ArgumentError, 'Saia da edição interna de grupos antes de aplicar o modo ao projeto.' if @modelo.active_path

      @padrao = categorias.fetch('inferiores')
      @atualizados = 0
      @bloqueados = 0
      @modelo.start_operation('Nex Mob: aplicar modo construtivo ao projeto', true)
      iniciada = true
      percorrer(@modelo.entities)
      @modelo.commit_operation
      iniciada = false
      { atualizados: @atualizados, bloqueados: @bloqueados }
    rescue StandardError
      @modelo.abort_operation if iniciada
      raise
    end

    private

    def instancias(entidades)
      entidades.select { |entidade| entidade.is_a?(Sketchup::Group) || entidade.is_a?(Sketchup::ComponentInstance) }
    end

    def quantidade_modulos(entidades)
      instancias(entidades).sum do |instancia|
        ModuloParametrico.reconhecido?(instancia) ? 1 : quantidade_modulos(instancia.definition.entities)
      end
    end

    def percorrer(entidades)
      instancias(entidades).each do |instancia|
        if instancia.locked?
          @bloqueados += ModuloParametrico.reconhecido?(instancia) ? 1 : quantidade_modulos(instancia.definition.entities)
          next
        end
        if ModuloParametrico.reconhecido?(instancia)
          parametros = ModuloParametrico.parametros(instancia).merge(@padrao)
          divisoes = PlanoBalcaoInferior.ler_divisoes(instancia)
          gavetas = PlanoGavetas.validas(parametros, divisoes, PlanoGavetas.ler(instancia))
          frentes = PlanoFrentes.sincronizar_com_modo(parametros, divisoes, gavetas, PlanoFrentes.ler(instancia))
          ConstrutorBalcaoInferior.new(@modelo).atualizar(instancia, parametros, divisoes,
                                                            gavetas: gavetas, frentes: frentes,
                                                            gerenciar_operacao: false)
          @atualizados += 1
        elsif quantidade_modulos(instancia.definition.entities) > 0
          # Isola os ancestrais para preservar cópias bloqueadas da mesma definição.
          instancia.make_unique if instancia.definition.instances.length > 1
          percorrer(instancia.definition.entities)
        end
      end
    end
  end
end
