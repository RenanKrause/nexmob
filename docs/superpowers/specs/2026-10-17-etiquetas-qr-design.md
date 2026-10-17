# Etiquetas inteligentes com QR — design

## Objetivo

Permitir que o Nex Mob gere etiquetas de fabricação para **todas as peças de todos os móveis do projeto**. Cada etiqueta terá um QR exclusivo da peça. Ao ser lido por qualquer pessoa, sem login, o QR abre no celular a visualização atualizada do móvel completo e destaca a peça daquela etiqueta.

O resultado deve manter a leitura de produção da referência aprovada: informações técnicas no centro, QR no canto superior e desenho técnico da peça no canto inferior, com as bordas que recebem fita evidenciadas.

## Experiência esperada

1. O marceneiro registra uma vez os dados do projeto, incluindo o cliente, e cria uma lista livre de ambientes, dando nome a cada um deles.
2. Ao inserir ou editar um móvel, escolhe um ambiente da lista. O móvel e todas as suas peças passam a usar essa referência.
3. O modo construtivo continua sendo a fonte das bordas com fita. A etiqueta não exige que a mesma fita seja configurada novamente peça a peça.
4. A peça herda um material padrão, mas o usuário pode substituir o material daquela peça no editor. A substituição aparece na etiqueta e no visualizador.
5. No comando **Etiquetas e QR**, o plugin sincroniza o estado atual do projeto, mostra uma prévia no tamanho configurado e gera uma etiqueta por peça do projeto inteiro.
6. O usuário pode gerar o lote para uma impressora térmica de etiquetas adesivas ou exportá-lo em PDF para folha A4. A impressão térmica usa a caixa de impressão do sistema; o PDF é um arquivo de saída separado.
7. Ao escanear uma etiqueta, a página pública abre o móvel na versão mais recente disponível e dá destaque visual à peça correspondente.

## Dados e persistência no SketchUp

Os dados ficarão em dicionários de atributos, para permanecerem dentro do `.skp`:

- No modelo: `projeto_uuid`, `cliente` e `ambientes`. Cada ambiente é `{ id, nome }`; o ID é imutável e o nome pode ser renomeado.
- Em cada grupo principal de módulo: `modulo_uuid` e `ambiente_id`.
- Em cada chapa/grupo de peça: `material_padrao`, `material_sobrescrito` opcional, uma chave lógica de peça e `qr_token`.
- Nas preferências do plugin: um único tamanho ativo de etiqueta, identificado por largura e altura em milímetros. Não há biblioteca de formatos; mudar o tamanho substitui o formato ativo para as próximas gerações. O padrão inicial é 99 × 55,8 mm.

O Nex Mob já cria grupos de peça e persiste código, nome, corte, espessura e `fita_borda` no dicionário `marcenaria_parametrica_peca`. A implementação estenderá esses metadados, em vez de criar uma segunda fonte de verdade.

Como as peças são reconstruídas ao editar um módulo, a identidade pública não pode depender do `entityID` do SketchUp. Ela será derivada e preservada por `projeto_uuid + modulo_uuid + chave_logica_da_peca`. A chave usará o código de fabricação e, quando existir, a origem estável de vão, gaveta ou frente. Assim, uma lateral ou frente mantém seu QR após uma alteração de medida; uma peça removida deixa de existir na revisão atual.

O `qr_token` é um identificador aleatório de 128 bits, criado uma vez na primeira geração e persistido junto à peça. Ele é o único valor público no QR; não é derivado de nome, dimensões ou dados do cliente.

## Conteúdo e composição da etiqueta

Em qualquer tamanho configurado, o motor adapta tipografia e espaçamento, sem reduzir o QR abaixo de um tamanho legível. O formato A aprovado contém:

- Bordas: indicação textual superior, inferior, esquerda e direita; as bordas com fita recebem destaque vermelho.
- Dados: cliente, ambiente, móvel, nome/código da peça, dimensão de corte (comprimento × largura × espessura), material efetivo e uma indicação resumida das bordas a fitar.
- QR: no canto superior direito, com a chamada “Escaneie para ver o móvel”.
- Desenho: representação retangular da chapa no canto inferior direito, com as bordas de fita em vermelho e indicadores de orientação.
- Rastreabilidade: data/hora de geração e identificação de revisão, em tamanho secundário.

Quando o espaço não comportar todos os dados em tamanho legível, a prévia deve alertar e impedir a geração até que o usuário aumente a etiqueta ou reduza o conteúdo permitido; informações não devem simplesmente desaparecer.

### Saídas de impressão

- **Térmica:** uma etiqueta por página, no tamanho ativo, para a impressora de etiqueta adesiva configurada no Windows.
- **PDF A4:** predefinição A4350, com 10 etiquetas adesivas por folha — 2 colunas × 5 linhas, cada etiqueta com 99 × 55,8 mm. A saída preserva a escala de 100%, sem ajuste automático do leitor de PDF.
- **Calibração A4:** haverá uma impressão de teste e ajustes persistidos de deslocamento horizontal e vertical; isso compensa diferenças entre impressoras e lotes de papel sem alterar o tamanho ou o conteúdo da etiqueta.

Como decisão de implementação, o QR não poderá medir menos que 20 mm e o texto principal não poderá ficar abaixo de 6 pt; a prévia bloqueará tamanhos que não atendam a ambos.

## Visualização pública e sincronização

O primeiro lançamento usa endereço gratuito `*.pages.dev`; domínio próprio é uma evolução opcional posterior. A página será pública, mas a URL do QR conterá somente um identificador longo e aleatório, nunca cliente, ambiente, endereço ou caminho do arquivo.

A infraestrutura Cloudflare será centralizada e administrada pelo proprietário do Nex Mob, e não por cada marcenaria. O serviço deve isolar os projetos de cada instalação/cliente e emitir uma credencial de sincronização revogável para cada instalação; chaves administrativas da Cloudflare permanecem exclusivamente no servidor do proprietário.

Arquitetura proposta:

```text
Nex Mob no SketchUp
    └─ sincroniza a revisão do projeto por HTTPS
Cloudflare Worker/API
    ├─ registro público e revisão atual
    ├─ metadados de móveis e peças
    └─ arquivos da cena no R2
Cloudflare Pages
    └─ visualizador 3D no navegador do celular
```

Para os móveis paramétricos atuais, o plugin enviará uma cena JSON compacta composta pelas caixas das peças, suas medidas, transformações, materiais e identificadores lógicos. A página gera a malha no navegador e destaca a peça do QR. Isso evita depender de exportação GLB no primeiro lançamento e combina com as geometrias de chapa existentes. Modelos que no futuro não puderem ser descritos assim poderão ganhar um exportador GLB compatível, sem alterar a URL nem os QRs existentes.

Todo envio cria uma revisão imutável com identificador e data/hora. A API só troca o ponteiro público para essa nova revisão após validar e gravar o manifesto completo; uma falha deixa a revisão pública anterior intacta. O QR sempre consulta esse ponteiro; por isso etiquetas já impressas mostram a versão mais recente. Em caso de cópias concorrentes do mesmo `.skp`, a última sincronização concluída vence e fica registrada no histórico administrativo. O visualizador deverá informar claramente a data/hora da última sincronização e a revisão exibida.

Os QRs públicos não expiram e não terão ação de desativação no produto. Enquanto o serviço estiver ativo, uma etiqueta já emitida continua resolvendo para a versão mais recente do projeto.

## Interfaces do plugin

1. **Dados do projeto**: cliente e gerenciamento da lista de ambientes (adicionar, renomear e remover somente ambientes que não estejam em uso).
2. **Móvel**: seletor de ambiente na criação/edição do módulo.
3. **Peça**: seletor de material efetivo, com opção de voltar ao material padrão. A UI também explica que as fitas vêm do modo construtivo.
4. **Etiquetas e QR**: tamanho ativo em milímetros, prévia do layout A, validação de legibilidade, estado da última sincronização e ações “Gerar PDF” e “Imprimir”. A geração sempre inclui o projeto inteiro.

Móveis incluídos na geração são somente grupos reconhecidos por `ModuloParametrico.reconhecido?`. Para o campo “Móvel”, a etiqueta usa o nome do grupo se o usuário o tiver definido; caso contrário, usa o nome amigável do tipo do módulo, como “Balcão inferior”.

## Restrições e não objetivos do primeiro lançamento

- Não haverá login no visualizador, AR, edição do móvel pelo celular, CNC ou controle de estoque.
- A página pública não expõe dados pessoais fora do texto necessário da etiqueta; o token público não é uma autorização administrativa.
- A sincronização de escrita exigirá credencial configurada pelo proprietário do serviço. A credencial não será embutida no QR nem exposta no navegador público.
- O material da peça é um valor de fabricação exibido pelo plugin. Um catálogo completo de padrões/texturas e a especificação detalhada da fita (marca, cor e espessura) não fazem parte deste primeiro recorte, salvo se já existirem no modo construtivo.
- Projetos antigos receberão os novos UUIDs e valores padrão de forma preguiçosa ao serem abertos/gerados, preservando os dados de fabricação atuais.

## Critérios de aceite

- É possível criar, nomear e atribuir ambientes sem perder a associação ao renomeá-los.
- Alterar material de uma peça afeta somente aquela peça e persiste após salvar/reabrir e reconstruir o módulo.
- A geração inclui cada peça de todos os módulos reconhecidos do projeto uma única vez, em PDF e pela impressão direta.
- A prévia e a saída respeitam o tamanho ativo em milímetros e recusam layout ilegível.
- A etiqueta identifica corretamente dados do projeto, móvel, peça, material, dimensões e bordas com fita.
- Cada peça possui QR público distinto; ele abre o móvel correto, evidencia a peça e mostra a última revisão sincronizada.
- Após alterar o projeto e sincronizar novamente, o mesmo QR exibe a versão mais recente.
