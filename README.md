# Nex Mob

Plugin paramétrico de marcenaria para SketchUp 2026 no Windows. Versão 0.4.7.

## Instalação

Instale `nex_mob-0.4.7.rbz` pelo Gerenciador de Extensões e reinicie o SketchUp. A barra **Nex Mob** contém quatro comandos: **Inserir módulo**, **Editar módulo e vãos**, **Portas e frentes** e **Modo construtivo**. Ela também pode ser exibida por **Extensões > Nex Mob > Mostrar barra de ferramentas**.

O arquivo de entrada e a pasta internos continuam como `marcenaria_parametrica`, para atualizar a instalação anterior sem duplicar a extensão. Os dicionários antigos também são preservados para reconhecer os móveis já criados. O nome apresentado no SketchUp, nos diálogos e na barra é Nex Mob.

## Catálogo e edição

Escolha **Balcão inferior** e clique no modelo. A edição abre após a inserção e ativa a seleção de vãos. Para um móvel existente, selecione seu grupo principal e use **Editar módulo e vãos**.

Clique diretamente na abertura frontal do vão. O preenchimento e o contorno mostram o destaque; o vão selecionado fica em vermelho e os demais em azul esverdeado. A visualização apresenta o número e as medidas livres de cada abertura. **Enquadrar em vista frontal** facilita a seleção e retoma a ferramenta se ela tiver sido encerrada com Esc.

Adicione prateleiras ou divisórias pelo modal de edição ou pelos botões flutuantes do vão. Os botões no 3D inserem uma peça no centro. No painel, informe a **quantidade** e a medida livre do **primeiro vão**. Com várias peças, os demais vãos são distribuídos igualmente. A posição da peça inclui a espessura das chapas que limitam o vão: digitar 350 mm produz um espaço livre de 350 mm até a primeira peça. Cada vão resultante precisa respeitar a folga mínima configurada no modo construtivo (80 mm no modo inicial). Todo o lote é criado em uma operação e pode ser desfeito com um único Ctrl+Z. As divisões são gravadas como proporções e acompanham as alterações das dimensões do módulo.

## Editor 3D

O painel tem abas **Construir**, **Medidas** e **Visualização**. Modo construtivo continua em um diálogo separado; materiais ficam para uma etapa própria.

- Clique em uma face visível da prateleira ou divisória para selecioná-la. A borda fica vermelha e aparecem as ações **Mover**, **Duplicar** e **Excluir**, além das cotas livres dos dois lados.
- Arraste a alça quadrada no centro da peça, ou use **Mover**, mova o cursor e clique no destino. A prévia não modifica a geometria; soltar o arraste ou confirmar o destino aplica uma única operação.
- Os vãos mostram alças apenas nas bordas apoiadas em prateleiras ou divisórias móveis. Arrastar uma dessas alças move a peça correspondente.
- No painel, **Altura livre do vão inferior** ou **Largura livre do vão esquerdo** mede a distância interna até a primeira face da peça. A cota mostrada no 3D corresponde ao valor digitado. O arraste e a caixa Medidas do SketchUp continuam trabalhando com coordenadas locais do módulo em milímetros.
- O movimento pelo cursor depende da precisão da projeção na tela. Use a posição digitada para uma medida exata. As cotas e posições são locais ao módulo, antes de eventuais escalas externas do SketchUp.
- Esc durante o movimento cancela somente a prévia. Ctrl+Z desfaz a operação concluída. Após mover, duplicar ou inserir, a ferramenta continua disponível.
- **Duplicar** procura um vão adjacente com a mesma largura (prateleira) ou altura (divisória), preferindo acima/à direita e colocando a cópia no centro.
- Ao excluir uma divisão, o Nex Mob também remove as subdivisões criadas dentro dos vãos dela. Tudo acontece na mesma operação e pode ser desfeito com Ctrl+Z.
- Clique em qualquer peça de uma gaveta para selecionar a caixa completa. O painel permite editar sua posição vertical, altura e profundidade; **Mover** usa a alça central e a cota no 3D. **Duplicar** cria outra caixa no espaço disponível; ao duplicar uma gaveta única, o vão é dividido em duas caixas iguais. As folgas e as cinco peças da caixa continuam vinculadas ao modo construtivo.

Nesta versão, prateleiras são divisões estruturais horizontais. Gavetas são caixas internas: cada uma possui lateral esquerda, lateral direita, contra frente, posterior e fundo. Portas e frentes externas são definidas no modal próprio; ferragens e prateleiras independentes da divisão frontal ainda não fazem parte do editor.

## Portas e frentes

**Portas e frentes** é um modal separado do Modo construtivo. Abra-o pela barra do Nex Mob após selecionar o grupo principal do módulo, ou pelo botão disponível no Editor 3D. O modal detecta as caixas existentes no vão, indica seus nomes e sugere **Frentes de gaveta** quando houver gavetas. Sem gavetas, ele sugere automaticamente de 1 a 4 portas de acordo com a largura de referência configurada no modo construtivo; 764 mm sugerem duas portas no padrão inicial.

Espessura, folga e recuo partem das regras do Modo construtivo e podem receber ajuste pontual no modal. Aplicar substitui somente a composição do vão escolhido. Portas e frentes de gaveta são grupos independentes com metadados de fabricação e são reconstruídas quando as medidas do módulo, vãos ou gavetas mudam.

## Modos construtivos

O terceiro botão abre uma área de trabalho separada, com as categorias **Inferiores**, **Superiores** e **Armários** na lateral. Cada modo salvo tem um nome e reúne as configurações das três famílias; trocar a categoria apenas troca o perfil em edição dentro do mesmo modo. **Novo modo** copia todas as regras abertas; informe outro nome e ajuste-as. Selecionar um modo apenas o carrega para edição; **Ativar selecionado** define o padrão para os próximos móveis.

- **Salvar e ativar** grava as regras e define o modo para os próximos móveis.
- **Salvar e aplicar a todos os móveis** também recalcula os módulos Nex Mob compatíveis do projeto, inclusive os que estão dentro de grupos e componentes.
- Ao aplicar aos móveis existentes, as regras de espessura, folga e recuo de portas e frentes também são sincronizadas com o modo salvo.
- Móveis bloqueados, ou dentro de ancestrais bloqueados, são preservados. Cópias compartilhadas são isoladas quando necessário.
- A aplicação ao projeto ocupa um único passo de Desfazer. Se alguma medida ou divisão ficar inválida, a alteração de geometria inteira é cancelada; o modo permanece salvo.

As regras disponíveis nesta fase são organizadas nas abas **Estrutura**, **Fundo** e, nos Inferiores, **Sarrafos**, **Caixa da gaveta**, **Portas** e **Frentes de gaveta**. Elas incluem espessura das chapas da estrutura, espessura do fundo, folga mínima de cada vão livre (40 a 200 mm) e profundidade dos dois sarrafos superiores. A caixa da gaveta define espessuras, folgas laterais, frontal e traseira, além das distâncias independentes para a base, o sarrafo e entre gavetas. Portas e frentes definem espessura, folga, recuo e a largura que calcula a quantidade sugerida de portas. O padrão inicial de folga mínima do vão é 80 mm. A prévia técnica destaca a peça afetada e responde ao valor digitado, sem alterar o modelo até que o modo seja salvo. A escolha de materiais terá um modal próprio em uma etapa posterior.

A construção 3D disponível continua sendo o balcão inferior. Selecione um vão no editor e use **Gavetas** para adicionar de 1 a 10 caixas empilhadas. Cada caixa cria cinco grupos independentes: lateral esquerda, lateral direita, contra frente, posterior e fundo. O fundo fica entre as quatro paredes da caixa. A altura é distribuída igualmente dentro do vão e a caixa acompanha alterações de dimensão do módulo. Se a alteração de uma divisão eliminar o vão de origem, as gavetas desse vão são removidas na mesma reconstrução. Os padrões de Superiores e Armários já podem ser salvos, mas sua geração 3D ainda está em preparação.

## Geometria e compatibilidade

O balcão padrão possui seis chapas independentes: duas laterais, base inferior, dois sarrafos superiores de 80 mm e fundo sobreposto. Não há tampo fechado nem prateleira inicial. As faces são orientadas para Z positivo antes da extrusão. A edição mantém a transformação do módulo e suas divisões registradas, recriando as chapas a partir dos parâmetros.

Módulos da versão 0.1 preservam a prateleira original ao serem editados; seu tampo fechado é substituído pelos sarrafos. Para reparar um módulo criado com a extrusão invertida de versões anteriores, selecione seu grupo principal, abra a edição e clique em **Aplicar medidas**.

Os dados de fabricação das chapas ficam em `marcenaria_parametrica_peca`, com medidas em milímetros. Os parâmetros, a árvore de divisões, as caixas de gaveta e as composições de frentes ficam em `marcenaria_parametrica_modulo`. Furação, ferragens e exportação CNC ainda não foram implementadas.

## Contrato da API Cloudflare

A sincronização do visualizador usa o contrato versionado `RevisionV1`, descrito em [`docs/api/revision-v1.md`](docs/api/revision-v1.md) e validado por `contracts/revision-v1.schema.json`. O POST autenticado é `/v1/revisions`; cada QR abre `/p/{qr_token}` e consulta a revisão pública atual. Fixtures válidos e inválidos ficam em `contracts/fixtures/`.

## Organização do código

```text
marcenaria_parametrica.rb              Registro da extensão Nex Mob
marcenaria_parametrica/
  principal.rb                        Carregamento e inicialização
  configuracao/
    configuracao_construtiva.rb        Modos nomeados e persistência
  dominio/
    plano_balcao_inferior.rb           Cálculo de chapas e árvore de vãos
    plano_gavetas.rb                   Cálculo das caixas de gavetas
    plano_frentes.rb                   Cálculo de portas e frentes de gaveta
    modulo_parametrico.rb              Leitura de parâmetros dos móveis
    edicao_divisoes.rb                 Mover, duplicar, excluir e localizar bordas
  construtores/
    construtor_balcao_inferior.rb      Inserção, atualização e operações
    fabrica_chapas.rb                 Geometria e metadados das peças
  servicos/
    aplicador_modo_construtivo.rb      Aplicação ao projeto e proteção de cópias
  ferramentas/
    ferramenta_insercao.rb            Clique para inserir
    ferramenta_selecao_vao.rb          Seleção contínua básica
    ferramenta_edicao_3d.rb            Cliques, alças, arraste e medidas digitadas
  visualizacao/
    representacao_vaos.rb              Cores, contornos e legendas
    representacao_edicao.rb            Ações flutuantes, alças e cotas
    enquadramento_modulo.rb            Vista frontal
  interface/
    controlador_interface.rb          Coordenação dos quatro diálogos
    controlador_catalogo.rb           Catálogo e inserção
    controlador_edicao.rb             Edição de módulo e vãos
    controlador_frentes.rb            Portas e frentes por vão
    controlador_modo_construtivo.rb    Modos salvos e aplicação
    fabrica_dialogos.rb               Configuração comum dos diálogos
    observador_edicao.rb              Sincronização após Desfazer/Refazer
    comandos_plugin.rb                Menu, barra e comandos
    catalogo.html / catalogo.js
    edicao.html / edicao.js / edicao.css
    frentes.html / frentes.js / frentes.css
    abas_edicao.js / selecao_pecas.js   Navegação e propriedades da peça
    modo_construtivo.html / modo_construtivo.js / modo_construtivo.css
    campos_construtivos.js             Seções e descrições dos campos por família
    previa_construtiva.js              Desenho técnico reativo do modo construtivo
    estilos.css                       Aparência compartilhada
  icones/
    catalogo.svg / editar.svg / frentes.svg / construcao.svg
```

## Verificação

Os testes unitários Ruby usam Minitest e ficam em `testes/teste_*.rb`; execute cada arquivo separadamente. Os testes de JavaScript usam `node --test testes/*.js`.

Os scripts `verificar_no_sketchup.rb`, `verificar_fluxos_sketchup.rb` e `verificar_interface_sketchup.rb` verificam a API real em um modelo descartável do SketchUp. Eles cobrem geometria sólida, seleção contínua, aplicação em lote, cópias bloqueadas, Desfazer, cancelamento em erro e a comunicação dos novos diálogos. Não carregue os testes unitários com simulações da API dentro do SketchUp.

O script `verificar_editor_3d_sketchup.rb` testa o editor em um móvel transladado, girado e escalado: seleção, barra flutuante, arraste sem mutação durante a prévia, cancelamento, Desfazer, posição numérica, duplicação/exclusão, alças dos vãos e comunicação real do HtmlDialog.


