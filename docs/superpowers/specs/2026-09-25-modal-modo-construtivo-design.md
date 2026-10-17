# Modal de modo construtivo do Nex Mob

## Objetivo

Substituir o modal compacto atual por uma tela de trabalho inspirada na referência fornecida. A tela deve permitir configurar um modo construtivo completo, navegar pelas regras de cada família de móvel e entender visualmente o efeito de cada regra antes de salvar.

Um modo construtivo continua sendo um único registro nomeado. Ele sempre contém três perfis: `inferiores`, `superiores` e `armarios`. A categoria escolhida na lateral apenas determina qual perfil do modo está em edição; ela não cria listas isoladas nem duplica presets.

## Organização da tela

O diálogo usa largura de trabalho maior e é dividido em duas colunas.

```text
+-------------------------+----------------------------------------------+
| Nex Mob                 | Nome do modo                    [Salvar]     |
| Modo construtivo        | Subtítulo da categoria selecionada           |
|                         +----------------------------------------------+
| Categorias              | Estrutura | Fundo | Sarrafos                  |
| [Inferiores]            +----------------------------------------------+
| [Superiores]            | Título da seção e explicação                 |
| [Armários]              |                                              |
|                         | regra + explicação        [controle]         |
| Modos construtivos      | regra + explicação        [controle]         |
| [Padrão]                | regra + explicação        [controle]         |
|  Cozinha 18 mm          |                                              |
|                         | Prévia técnica da montagem                   |
| [+ Novo modo]           |                                              |
+-------------------------+----------------------------------------------+
```

A lateral permanece fixa enquanto o conteúdo da direita rola. Os botões de categoria deixam evidente a família ativa. A lista apresenta todos os modos salvos, com o modo ativo identificado. O botão `Novo modo` copia o modo aberto, limpa apenas o nome e preserva as alterações ainda não salvas.

O cabeçalho contém o nome editável do modo, a família em edição e as ações `Salvar e ativar` e `Salvar e aplicar ao projeto`. Selecionar outro modo somente carrega seus valores; `Ativar selecionado` continua sendo a ação explícita que altera o padrão usado por novos móveis.

## Abas e regras iniciais

As abas mostram apenas regras que já existem no modelo e que terão efeito ao salvar. Dessa forma, a interface não promete portas, gavetas, ferragens, furação, bordas ou materiais antes de essas partes existirem no plugin.

### Estrutura

- Espessura das chapas da estrutura.
- Folga mínima dos vãos livres.

### Fundo

- Espessura da chapa do fundo.

### Sarrafos

- Disponível para Inferiores.
- Profundidade comum dos sarrafos frontal e traseiro.

Para Superiores e Armários, a aba Sarrafos informa que não se aplica àquela construção e exibe a prévia correspondente sem campos editáveis.

Materiais continuam fora deste modal, em uma futura janela de materiais. Portas, gavetas, ferragens, furação, bordas e tamponamentos serão adicionados quando suas regras puderem gerar geometria e dados de fabricação de fato.

## Prévia técnica reativa

Cada aba contém uma prévia SVG de montagem, localizada abaixo das regras em telas estreitas e ao lado delas em telas largas. A prévia é um desenho técnico simples do módulo, sem renderização decorativa.

- Ao focar, passar o cursor ou alterar um campo, a peça afetada recebe o destaque verde da marca.
- A espessura muda visualmente a largura de laterais, base e sarrafos no desenho.
- A regra de fundo destaca e redimensiona o painel traseiro.
- A regra dos sarrafos destaca os dois sarrafos e atualiza sua profundidade desenhada.
- A folga mínima mostra a cota de abertura livre entre divisões em uma pequena anotação no desenho.
- A prévia nunca substitui a geração do SketchUp; ela explica a regra antes do usuário aplicá-la ao módulo.

A prévia recebe uma descrição acessível que informa a regra em destaque e o valor atual. O mesmo estado visual é atualizado por teclado e por mouse.

## Dados e compatibilidade

O formato persistido de `ConfiguracaoConstrutiva` permanece compatível:

```json
{
  "ativo": "Padrão",
  "modos": {
    "Padrão": {
      "inferiores": { "...": "..." },
      "superiores": { "...": "..." },
      "armarios": { "...": "..." }
    }
  }
}
```

Não haverá migração de dados nesta entrega. O controlador Ruby mantém os mesmos callbacks de carregar, salvar, ativar e aplicar. A mudança fica concentrada em arquivos de interface: estrutura HTML, estilos, definição declarativa das abas e campos, controlador JavaScript e um módulo separado para construir e atualizar as prévias SVG.

## Limites e tratamento de erro

Os limites existentes continuam sendo validados em Ruby antes de gravar o modo. O HTML repete esses limites para orientar a entrada. Valores inválidos mantêm o rascunho aberto e mostram a mensagem retornada pelo controlador. A prévia usa o último valor válido quando a digitação estiver incompleta.

Salvar e aplicar mantém a operação única de Desfazer já existente. Módulos bloqueados permanecem protegidos e uma aplicação que produzir geometria inválida é cancelada pelo serviço atual.

## Critérios de aceite

- Um modo salvo reúne os três perfis no mesmo registro.
- A categoria lateral muda o perfil em edição sem perder valores das outras categorias.
- A lista lateral permite carregar, criar e identificar o modo ativo.
- Estrutura, Fundo e Sarrafos exibem somente regras realmente suportadas.
- Alterar ou focar uma regra atualiza a prévia técnica e destaca a peça correspondente.
- Navegação por teclado funciona para categorias, abas, campos e ações.
- A tela permanece utilizável no tamanho padrão de um `Sketchup::HtmlDialog` e adapta-se a larguras menores.
