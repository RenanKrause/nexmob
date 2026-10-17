import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import type { PublicPieceResponse } from './api';
import { buildModuleScene } from './scene';

export function mountScene(payload: PublicPieceResponse, host: HTMLElement, buttons: HTMLButtonElement[]): () => void {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#edf1f5');
  const meshes = buildModuleScene(payload, scene);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x67788c, 2.4));
  const light = new THREE.DirectionalLight(0xffffff, 3); light.position.set(1, -2, 4); scene.add(light);
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.domElement.setAttribute('role', 'img');
  renderer.domElement.setAttribute('aria-label', `Desenho 3D de ${payload.module.name}. A peça ${payload.module.pieces.find(p => p.logical_key === payload.selected_piece_key)!.name} está destacada em amarelo.`);
  renderer.domElement.setAttribute('aria-describedby', 'scene-help');
  host.replaceChildren(renderer.domElement);
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100000);
  camera.up.set(0, 0, 1);
  const controls = new OrbitControls(camera, renderer.domElement);
  // Render only when the user moves the view; no autonomous motion or damping.
  controls.enableDamping = false;
  controls.screenSpacePanning = true;
  const bounds = new THREE.Box3();
  for (const mesh of meshes.values()) if (mesh.visible) bounds.expandByObject(mesh);
  if (bounds.isEmpty()) {
    for (const mesh of meshes.values()) bounds.expandByObject(mesh);
  }
  const center = bounds.getCenter(new THREE.Vector3());
  const radius = Math.max(bounds.getSize(new THREE.Vector3()).length() / 2, 1);
  controls.minDistance = Math.max(radius * 0.04, 0.1);
  controls.maxDistance = radius * 20;
  camera.near = Math.max(radius / 10000, 0.01);
  camera.far = radius * 100;
  const render = () => renderer.render(scene, camera);

  const fit = () => {
    const verticalFov = THREE.MathUtils.degToRad(camera.fov);
    const horizontalFov = 2 * Math.atan(Math.tan(verticalFov / 2) * camera.aspect);
    const distance = radius / Math.sin(Math.min(verticalFov, horizontalFov) / 2) * 1.15;
    controls.target.copy(center);
    camera.position.copy(center).add(new THREE.Vector3(1, -1.5, 1).normalize().multiplyScalar(distance));
    camera.lookAt(center); camera.updateProjectionMatrix(); controls.update(); render();
  };
  const resize = () => {
    const width = Math.max(host.clientWidth, 1); const height = Math.max(host.clientHeight, 1);
    renderer.setSize(width, height, false); camera.aspect = width / height;
    fit();
  };
  const zoom = (factor: number) => {
    const offset = camera.position.clone().sub(controls.target);
    offset.setLength(THREE.MathUtils.clamp(offset.length() * factor, controls.minDistance, controls.maxDistance));
    camera.position.copy(controls.target).add(offset); controls.update(); render();
  };
  const rotate = () => {
    const offset = camera.position.clone().sub(controls.target).applyAxisAngle(new THREE.Vector3(0, 0, 1), Math.PI / 6);
    camera.position.copy(controls.target).add(offset); controls.update(); render();
  };
  const callbacks = [fit, rotate, () => zoom(0.8), () => zoom(1.25)];
  buttons.forEach((button, index) => { button.disabled = false; button.addEventListener('click', callbacks[index]); });
  controls.addEventListener('change', render);
  const observer = new ResizeObserver(resize); observer.observe(host); resize();
  return () => {
    observer.disconnect(); controls.dispose();
    buttons.forEach((button, index) => { button.removeEventListener('click', callbacks[index]); button.disabled = true; });
    scene.traverse(object => {
      if (object instanceof THREE.Mesh || object instanceof THREE.LineSegments) {
        object.geometry.dispose();
        const materials = Array.isArray(object.material) ? object.material : [object.material];
        materials.forEach(material => material.dispose());
      }
    });
    renderer.dispose(); renderer.domElement.remove();
  };
}
