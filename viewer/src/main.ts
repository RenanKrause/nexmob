import { fetchPublicPiece, PublicPieceError, type PublicPieceResponse } from './api';
import { parsePieceRoute } from './route';
import './style.css';

const app = document.querySelector<HTMLDivElement>('#app')!;
app.innerHTML = `
  <a class="skip-link" href="#piece-details">Ir para os dados da peça</a>
  <header class="masthead"><span class="brand">Nex Mob</span><span>Consulta de peça</span></header>
  <main id="content">
    <section id="status" class="status" role="status" aria-live="polite"></section>
    <div id="viewer" hidden>
      <header class="module-heading"><div><p id="environment"></p><h1 id="module-name"></h1></div><span class="unit-label">Medidas em mm</span></header>
      <div class="workbench">
        <section class="drawing" aria-label="Visualização do móvel">
          <div id="scene" aria-busy="true"><p class="scene-message">Preparando a visualização 3D…</p></div>
          <div class="scene-tools" role="group" aria-label="Controles da câmera">
            <button type="button" id="reset-view" aria-label="Enquadrar móvel">Enquadrar</button>
            <button type="button" id="rotate-view">Girar vista</button>
            <button type="button" id="zoom-in" aria-label="Aproximar o móvel">+</button>
            <button type="button" id="zoom-out" aria-label="Afastar o móvel">−</button>
          </div>
          <p class="drawing-help" id="scene-help">Arraste para girar. Use dois dedos para mover ou ajustar o zoom. Com teclado, use os controles acima.</p>
          <p class="selection-key"><span aria-hidden="true"></span>Peça desta etiqueta em amarelo</p>
        </section>
        <section id="piece-details" class="piece-details" tabindex="-1" aria-labelledby="piece-name">
          <p class="detail-caption">Peça da etiqueta</p><h2 id="piece-name"></h2>
          <p id="visibility-note" hidden>Esta peça está oculta na visualização sincronizada.</p>
          <dl><div class="dimension-row"><dt>Corte (X × Y × Z)</dt><dd id="dimensions"></dd></div>
            <div><dt>Material</dt><dd id="material"></dd></div>
            <div><dt>Ambiente</dt><dd id="detail-environment"></dd></div></dl>
          <div class="sync"><p>Última sincronização</p><time id="synced-at"></time><p class="sync-note">Confira a data antes de produzir.</p></div>
          <p class="material-note">As cores do desenho são esquemáticas. Confira o material nesta ficha.</p>
        </section>
      </div>
    </div>
  </main>`;

const status = document.querySelector<HTMLElement>('#status')!;
const viewer = document.querySelector<HTMLDivElement>('#viewer')!;
const sceneHost = document.querySelector<HTMLDivElement>('#scene')!;
const buttons = ['reset-view', 'rotate-view', 'zoom-in', 'zoom-out'].map(id => document.getElementById(id) as HTMLButtonElement);
let disposeScene: (() => void) | undefined;
let currentPayload: PublicPieceResponse | undefined;
let pageHidden = false;
let sceneGeneration = 0;
let sceneModule: Promise<typeof import('./view')> | undefined;

function clearScene(): void {
  sceneGeneration++;
  const dispose = disposeScene;
  disposeScene = undefined;
  dispose?.();
}

function showStatus(title: string, detail: string, retry = false): void {
  viewer.hidden = true;
  status.hidden = false;
  status.replaceChildren();
  const heading = document.createElement('h1'); heading.textContent = title;
  const description = document.createElement('p'); description.textContent = detail;
  status.append(heading, description);
  if (retry) {
    const button = document.createElement('button'); button.type = 'button'; button.textContent = 'Tentar novamente';
    button.addEventListener('click', () => { void load(); }); status.append(button);
  }
}

function write(id: string, value: string): void { document.getElementById(id)!.textContent = value; }

async function showPiece(payload: PublicPieceResponse): Promise<void> {
  const piece = payload.module.pieces.find(candidate => candidate.logical_key === payload.selected_piece_key)!;
  write('module-name', payload.module.name);
  write('environment', payload.module.environment || 'Ambiente não informado');
  write('detail-environment', payload.module.environment || 'Não informado');
  write('piece-name', piece.name);
  write('dimensions', `${piece.cut_mm.map(mm => new Intl.NumberFormat('pt-BR', { maximumSignificantDigits: 21 }).format(mm)).join(' × ')} mm`);
  write('material', piece.material);
  document.getElementById('visibility-note')!.hidden = piece.visible;
  const syncedAt = document.querySelector<HTMLTimeElement>('#synced-at')!;
  syncedAt.dateTime = payload.synced_at;
  syncedAt.textContent = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(payload.synced_at));
  syncedAt.title = `Horário local deste dispositivo. Registro: ${payload.synced_at}`;
  status.hidden = true; viewer.hidden = false;
  currentPayload = payload;
  await restoreScene();
}

async function restoreScene(): Promise<void> {
  if (!currentPayload || pageHidden || disposeScene) return;
  const payload = currentPayload;
  const generation = ++sceneGeneration;
  sceneHost.setAttribute('aria-busy', 'true');
  buttons.forEach(button => { button.disabled = true; });
  try {
    const { mountScene } = await (sceneModule ??= import('./view').catch(error => {
      sceneModule = undefined;
      throw error;
    }));
    // A pagehide or newer restore may have invalidated this pending import.
    if (pageHidden || generation !== sceneGeneration) return;
    disposeScene = mountScene(payload, sceneHost, buttons);
  } catch {
    if (pageHidden || generation !== sceneGeneration) return;
    sceneHost.replaceChildren();
    const message = document.createElement('p'); message.className = 'scene-message'; message.setAttribute('role', 'status');
    message.textContent = 'Não foi possível abrir o desenho 3D. Tente outro navegador com WebGL. Os dados da peça estão disponíveis abaixo.';
    sceneHost.append(message);
  } finally {
    if (generation === sceneGeneration) sceneHost.setAttribute('aria-busy', 'false');
  }
}

async function load(): Promise<void> {
  clearScene(); currentPayload = undefined;
  const token = parsePieceRoute(window.location.pathname);
  if (!token) {
    showStatus('QR inválido', 'Abra o endereço completo da etiqueta ou escaneie o QR novamente.');
    return;
  }
  showStatus('Carregando o móvel…', 'Buscando a última sincronização desta peça.');
  status.setAttribute('aria-busy', 'true');
  try { await showPiece(await fetchPublicPiece(token)); }
  catch (error) {
    if (error instanceof PublicPieceError) {
      const title = error.kind === 'not-found' ? 'QR não encontrado' : error.kind === 'offline' ? 'Sem conexão com o serviço' : 'Não foi possível carregar o móvel';
      showStatus(title, error.kind === 'not-found' ? 'Esta peça não está disponível. Confira a etiqueta ou peça uma nova sincronização do móvel.' : error.message, error.kind !== 'not-found' && error.kind !== 'configuration');
    } else showStatus('Não foi possível carregar o móvel', 'Tente novamente em instantes.', true);
  } finally { status.setAttribute('aria-busy', 'false'); }
}

window.addEventListener('pagehide', () => {
  pageHidden = true;
  clearScene();
});
window.addEventListener('pageshow', event => {
  if (!event.persisted) return;
  pageHidden = false;
  void restoreScene();
});
void load();
