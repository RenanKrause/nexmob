require 'json'
require 'securerandom'
require_relative 'modulo_parametrico'

module MarcenariaParametrica
  module DadosProjeto
    DICIONARIO = 'nex_mob_projeto'.freeze

    class << self
      def ler(modelo)
        dicionario = modelo.attribute_dictionary(DICIONARIO, true)
        ambientes = ler_ambientes(dicionario['ambientes_json'])
        cliente = dicionario['cliente']
        raise ArgumentError, 'Os dados do cliente estão inválidos.' unless cliente.nil? || cliente.is_a?(String)

        projeto_uuid = dicionario['projeto_uuid']
        unless projeto_uuid.nil? || projeto_uuid.is_a?(String)
          raise ArgumentError, 'A identidade do projeto está inválida.'
        end

        if projeto_uuid.nil? || projeto_uuid.strip.empty?
          projeto_uuid = SecureRandom.uuid
          dicionario['projeto_uuid'] = projeto_uuid
        end
        dicionario['cliente'] = '' if cliente.nil?
        dicionario['ambientes_json'] = JSON.generate(ambientes) if dicionario['ambientes_json'].nil?
        modulos(modelo).each { |grupo| ModuloParametrico.inicializar(grupo) }

        { 'projeto_uuid' => projeto_uuid.dup, 'cliente' => (cliente || '').dup, 'ambientes' => ambientes }
      end

      def salvar_cliente(modelo, nome)
        raise ArgumentError, 'O nome do cliente deve ser um texto.' unless nome.nil? || nome.is_a?(String)

        ler(modelo)
        modelo.attribute_dictionary(DICIONARIO, true)['cliente'] = nome.to_s.strip
      end

      def criar_ambiente(modelo, nome)
        ambientes = ler(modelo)['ambientes']
        nome = validar_nome(nome, ambientes)
        ambiente = { 'id' => SecureRandom.uuid, 'nome' => nome }
        salvar_ambientes(modelo, ambientes + [ambiente])
        ambiente
      end

      def renomear_ambiente(modelo, id, nome)
        ambientes = ler(modelo)['ambientes']
        ambiente = buscar_ambiente(ambientes, id)
        ambiente['nome'] = validar_nome(nome, ambientes, id)
        salvar_ambientes(modelo, ambientes)
        ambiente
      end

      def excluir_ambiente(modelo, id)
        ambientes = ler(modelo)['ambientes']
        ambiente = buscar_ambiente(ambientes, id)
        if modulos(modelo).any? { |grupo| grupo.get_attribute(PlanoBalcaoInferior::DICIONARIO_MODULO, 'ambiente_id') == id }
          raise ArgumentError, 'O ambiente está em uso por um módulo.'
        end

        salvar_ambientes(modelo, ambientes.reject { |item| item['id'] == id })
        ambiente
      end

      def atribuir_ambiente(grupo, ambiente_id)
        raise ArgumentError, 'Selecione um módulo reconhecido.' unless ModuloParametrico.reconhecido?(grupo)

        # A referência vazia representa um módulo ainda sem ambiente escolhido.
        ambiente_id = '' if ambiente_id.nil?
        buscar_ambiente(ler(grupo.model)['ambientes'], ambiente_id) unless ambiente_id == ''
        ModuloParametrico.inicializar(grupo)
        grupo.set_attribute(PlanoBalcaoInferior::DICIONARIO_MODULO, 'ambiente_id', ambiente_id)
      end

      private

      def salvar_ambientes(modelo, ambientes)
        modelo.attribute_dictionary(DICIONARIO, true)['ambientes_json'] = JSON.generate(ambientes)
      end

      def buscar_ambiente(ambientes, id)
        ambientes.find { |ambiente| ambiente['id'] == id } ||
          raise(ArgumentError, 'O ambiente informado não existe neste projeto.')
      end

      def validar_nome(nome, ambientes, id = nil)
        unless nome.is_a?(String) && !nome.strip.empty?
          raise ArgumentError, 'Informe um nome para o ambiente.'
        end

        nome = nome.strip
        if ambientes.any? { |ambiente| ambiente['id'] != id && ambiente['nome'].strip.downcase == nome.downcase }
          raise ArgumentError, 'Já existe um ambiente com esse nome.'
        end

        nome
      end

      def ler_ambientes(texto)
        return [] if texto.nil?
        raise ArgumentError, 'Os dados dos ambientes estão inválidos.' unless texto.is_a?(String)

        ambientes = JSON.parse(texto)
        raise ArgumentError, 'Os dados dos ambientes estão inválidos.' unless ambientes.is_a?(Array)

        ids = {}
        nomes = {}
        ambientes.each do |ambiente|
          unless ambiente.is_a?(Hash) && ambiente['id'].is_a?(String) && !ambiente['id'].strip.empty? &&
                 ambiente['nome'].is_a?(String) && !ambiente['nome'].strip.empty?
            raise ArgumentError, 'Os dados dos ambientes estão inválidos.'
          end

          id = ambiente['id']
          nome = ambiente['nome'].strip.downcase
          raise ArgumentError, 'Os dados dos ambientes estão duplicados.' if ids[id] || nomes[nome]

          ids[id] = true
          nomes[nome] = true
        end
        ambientes
      rescue JSON::ParserError
        raise ArgumentError, 'Os dados dos ambientes estão inválidos.'
      end

      def modulos(modelo)
        encontrados = []
        visitados = {}
        percorrer = lambda do |entidades|
          return if visitados[entidades.object_id]

          visitados[entidades.object_id] = true
          entidades.each do |entidade|
            if entidade.is_a?(Sketchup::Group) && entidade.valid?
              encontrados << entidade if ModuloParametrico.reconhecido?(entidade)
              percorrer.call(entidade.entities)
            elsif defined?(Sketchup::ComponentInstance) && entidade.is_a?(Sketchup::ComponentInstance) && entidade.valid?
              percorrer.call(entidade.definition.entities)
            end
          end
        end
        percorrer.call(modelo.entities)
        encontrados
      end
    end
  end
end
