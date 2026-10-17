# Modal de modo construtivo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganizar o modal de modo construtivo como uma área de trabalho com presets completos, categorias laterais, abas técnicas e prévia reativa.

**Architecture:** O formato Ruby de persistência continua sendo um modo nomeado com três perfis. A interface passa a manter estado de `modo`, `familia` e `secao`; uma definição declarativa informa quais campos pertencem a cada aba. Um módulo JavaScript independente desenha a prévia SVG e recebe somente os valores do rascunho e a regra em destaque.

**Tech Stack:** Ruby para `Sketchup::HtmlDialog`, HTML, CSS e JavaScript sem dependências.

**Spec:** `docs/superpowers/specs/2026-09-25-modal-modo-construtivo-design.md`

## Global Constraints

- Toda nomenclatura própria e comentários permanecem em português.
- Um modo salvo contém `inferiores`, `superiores` e `armarios` no mesmo registro.
- Materiais, portas, gavetas, ferragens, furação, bordas e tamponamentos não recebem controles nesta entrega.
- Não criar nem executar testes automatizados neste trabalho; executar somente verificações sintáticas e de empacotamento.
- Não sobrescrever ou apagar os pacotes RBZ existentes.

## Review Focus

- Selecionar uma categoria após editar outra preserva as alterações ainda não salvas de ambas.
- Criar um modo novo a partir de um preset mantém todos os três perfis e limpa apenas o nome.
- Selecionar um preset não o ativa sem a ação explícita `Ativar selecionado`.
- Campos ausentes em presets antigos assumem os valores padrão sem quebrar a prévia.
- A prévia atualiza quando o campo recebe foco, valor digitado ou alteração por teclado.

---

### Task 1: Criar a definição das seções técnicas

**Files:**
- Modify: `marcenaria_parametrica/interface/campos_construtivos.js`

**Interfaces:**
- Produces: `window.secoesConstrutivas[categoria]`, uma lista de objetos `{ id, titulo, descricao, campos, aviso }`.
- Produces: `window.camposConstrutivos[chave]`, com `{ titulo, descricao, minimo, maximo, aba, destaque }`.
- Consumes: chaves persistidas em `ConfiguracaoConstrutiva::PADROES`.

- [x] **Step 1: Definir a estrutura e o fundo para as três categorias**

```js
inferiores: [
  { id: 'estrutura', titulo: 'Estrutura', campos: ['espessura_mm', 'folga_minima_mm'] },
  { id: 'fundo', titulo: 'Fundo', campos: ['espessura_fundo_mm'] },
  { id: 'sarrafos', titulo: 'Sarrafos', campos: ['largura_sarrafo_mm'] }
]
```

Usar `estrutura` e `fundo` para Superiores e Armários. A aba `sarrafos` somente existe para Inferiores.

- [x] **Step 2: Acrescentar textos de ajuda e o alvo da prévia para cada campo**

```js
espessura_mm: {
  titulo: 'Espessura das chapas', descricao: 'Laterais, base e divisórias.',
  minimo: 12, maximo: 30, destaque: 'estrutura'
}
```

Associar `espessura_fundo_mm` a `fundo`, `largura_sarrafo_mm` a `sarrafos` e `folga_minima_mm` a `vao`.

- [x] **Step 3: Conferir sintaxe do arquivo**

Run: `node --check marcenaria_parametrica/interface/campos_construtivos.js`

Expected: saída vazia e código de saída `0`.

### Task 2: Isolar a prévia técnica do modo construtivo

**Files:**
- Create: `marcenaria_parametrica/interface/previa_construtiva.js`
- Modify: `marcenaria_parametrica/interface/modo_construtivo.html`

**Interfaces:**
- Consumes: `window.camposConstrutivos`, categoria, valores do rascunho e chave de destaque.
- Produces: `window.atualizarPreviaConstrutiva(categoria, valores, destaque)`.
- Consumes from Task 3: chamada após renderizar, focar ou editar qualquer campo.

- [x] **Step 1: Adicionar o contêiner acessível da prévia no painel principal**

```html
<aside class="previa-construtiva" aria-label="Prévia da montagem">
  <p id="descricao-previa" class="rotulo-oculto" aria-live="polite"></p>
  <svg id="desenho-previa" viewBox="0 0 360 260" role="img" aria-describedby="descricao-previa"></svg>
</aside>
```

- [x] **Step 2: Construir o SVG sem depender do DOM da lista de campos**

```js
window.atualizarPreviaConstrutiva = function atualizarPreviaConstrutiva(categoria, valores, destaque) {
  const espessura = limitarNumero(valores.espessura_mm, 12, 30, 18);
  const fundo = limitarNumero(valores.espessura_fundo_mm, 3, 12, 6);
  const sarrafo = limitarNumero(valores.largura_sarrafo_mm, 50, 150, 80);
  desenharMontagem(categoria, espessura, fundo, sarrafo, destaque);
};
```

Criar elementos SVG nomeados para laterais, base, fundo, sarrafos e cota do vão. Aplicar a classe `destacado` somente ao conjunto solicitado.

- [x] **Step 3: Descrever o estado técnico para leitores de tela**

```js
descricao.textContent = `${tituloCampo}. Prévia de ${tituloCategoria}: ${valorAtual} mm.`;
```

- [x] **Step 4: Conferir sintaxe do novo módulo**

Run: `node --check marcenaria_parametrica/interface/previa_construtiva.js`

Expected: saída vazia e código de saída `0`.

### Task 3: Reconstruir a navegação e a renderização do modal

**Files:**
- Modify: `marcenaria_parametrica/interface/modo_construtivo.html`
- Modify: `marcenaria_parametrica/interface/modo_construtivo.js`

**Interfaces:**
- Consumes: `window.secoesConstrutivas` da Task 1 e `window.atualizarPreviaConstrutiva` da Task 2.
- Consumes: callbacks Ruby existentes `pronto`, `salvar_modo`, `aplicar_modo` e `ativar_modo`.
- Produces: `window.receberModos`, `window.exibirMensagemModo` e `window.exibirErro`, mantidas para o controlador Ruby.

- [x] **Step 1: Reestruturar o HTML em lateral, área principal e rodapé fixo**

```html
<div class="area-modo">
  <aside class="lateral-modo">…categorias e lista de modos…</aside>
  <main class="principal-modo">…cabeçalho, abas, regras e prévia…</main>
</div>
```

Adicionar `previa_construtiva.js` antes de `modo_construtivo.js` e preservar todos os identificadores usados pelos callbacks atuais.

- [x] **Step 2: Manter um rascunho único e trocar somente a família exibida**

```js
let rascunhoModo = {};
let familiaAtual = 'inferiores';
let secaoAtual = 'estrutura';

function trocarFamilia(familia) {
  guardarCampos();
  familiaAtual = familia;
  secaoAtual = window.secoesConstrutivas[familia][0].id;
  renderizarModal();
}
```

Renderizar os campos da seção a partir de `rascunhoModo[familiaAtual]`, sem apagar os valores das outras categorias.

- [x] **Step 3: Ligar o estado da prévia a foco e edição**

```js
campo.addEventListener('focus', () => atualizarPrevia(chave));
campo.addEventListener('input', () => {
  guardarCampos();
  atualizarPrevia(chave);
});
campo.addEventListener('blur', () => atualizarPrevia());
```

Após mudar de categoria, aba ou modo, atualizar a prévia com o primeiro campo da seção ativa.

- [x] **Step 4: Preservar as ações atuais de modo**

Manter `Novo modo`, `Ativar selecionado`, `Salvar e ativar` e `Salvar e aplicar ao projeto`. A seleção de um modo não chama `ativar_modo`; o clique explícito no botão chama esse callback.

- [x] **Step 5: Implementar teclado para categorias e abas**

Usar setas esquerda/direita, `Home` e `End` nas abas; usar setas cima/baixo, `Home` e `End` nos botões de categoria. Atualizar `aria-selected`, `tabindex` e o foco após cada troca.

- [x] **Step 6: Conferir sintaxe do controlador de interface**

Run: `node --check marcenaria_parametrica/interface/modo_construtivo.js`

Expected: saída vazia e código de saída `0`.

### Task 4: Aplicar o sistema visual e dimensionar o diálogo

**Files:**
- Modify: `marcenaria_parametrica/interface/modo_construtivo.css`
- Modify: `marcenaria_parametrica/interface/controlador_modo_construtivo.rb`
- Modify: `README.md`
- Modify: `marcenaria_parametrica.rb`
- Modify: `marcenaria_parametrica/interface/catalogo.html`

**Interfaces:**
- Consumes: classes semânticas criadas na Task 3.
- Produces: diálogo de 1180 × 760 px, com mínimo de 760 × 560 px e layout empilhado abaixo de 760 px.

- [x] **Step 1: Declarar a grade de trabalho no CSS**

```css
.area-modo { display: grid; grid-template-columns: 272px minmax(0, 1fr); min-height: 0; }
.lateral-modo { border-right: 1px solid var(--linha); overflow-y: auto; }
.principal-modo { min-width: 0; overflow-y: auto; }
```

Usar fundo branco, divisores cinza claro, verde `var(--petroleo)` nas seleções e campos em linhas com descrição à esquerda e controle à direita. Evitar gradientes, cartões repetidos e sombras decorativas.

- [x] **Step 2: Estilizar a prévia como desenho de montagem**

```css
.previa-construtiva svg { width: 100%; max-height: 300px; }
.previa-peca { fill: #f8faf9; stroke: #526467; }
.previa-peca.destacado { fill: #dceee2; stroke: var(--petroleo); stroke-width: 3; }
```

Separar o estilo de estado selecionado, foco visível e modo desabilitado.

- [x] **Step 3: Ampliar o `HtmlDialog` sem alterar os outros modais**

```ruby
@dialogo = FabricaDialogos.criar('Modo construtivo', 'modo_construtivo', largura: 1180, altura: 760)
```

Estender `FabricaDialogos.criar` com argumentos opcionais `largura_minima:` e `altura_minima:` e passá-los somente pelo controlador do modo construtivo.

- [x] **Step 4: Atualizar versão e documentação**

Explicar no README que um preset contém os três perfis, que a lateral troca a categoria em edição e que a prévia técnica responde aos campos disponíveis. Incrementar versão para `0.4.3` no registro e no rodapé do catálogo.

- [x] **Step 5: Verificar sintaxe e pacote**

Run: `node --check marcenaria_parametrica/interface/campos_construtivos.js; node --check marcenaria_parametrica/interface/previa_construtiva.js; node --check marcenaria_parametrica/interface/modo_construtivo.js`

Expected: saída vazia e código de saída `0`.

Criar `nex_mob-0.4.3.rbz` sem remover os RBZ anteriores e conferir que inclui `modo_construtivo.html`, `modo_construtivo.css`, `modo_construtivo.js`, `previa_construtiva.js` e `campos_construtivos.js`.
