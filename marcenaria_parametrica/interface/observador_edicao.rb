module MarcenariaParametrica
  class ObservadorEdicao < Sketchup::ModelObserver
    def initialize(ao_alterar)
      @ao_alterar = ao_alterar
    end

    def onTransactionUndo(_modelo)
      @ao_alterar.call
    end

    def onTransactionRedo(_modelo)
      @ao_alterar.call
    end
  end
end
