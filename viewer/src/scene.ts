import * as THREE from 'three';
import type { PublicPieceResponse } from './api';

/** Schematic tones distinguish material names; they do not represent a texture catalogue. */
function materialColor(name: string): number {
  const tones = [0xcbd5e1, 0xd9dde1, 0xb7c5ce, 0xc4cdd4, 0xbec9d6];
  const hash = [...name].reduce((value, char) => (value * 31 + char.charCodeAt(0)) >>> 0, 0);
  return tones[hash % tones.length];
}

/** Contract axes are XYZ in mm, Z-up. Transform translation is the box centre. */
export function buildModuleScene(payload: PublicPieceResponse, scene: THREE.Scene): Map<string, THREE.Mesh> {
  const meshes = new Map<string, THREE.Mesh>();
  for (const piece of payload.module.pieces) {
    const selected = piece.logical_key === payload.selected_piece_key;
    const geometry = new THREE.BoxGeometry(...piece.cut_mm);
    const material = new THREE.MeshStandardMaterial({
      name: piece.material,
      color: selected ? 0xe6a23c : materialColor(piece.material),
      roughness: 0.8,
      metalness: 0,
      opacity: 1,
      transparent: false,
      polygonOffset: selected,
      polygonOffsetFactor: selected ? -1 : 0,
      polygonOffsetUnits: selected ? -1 : 0,
    });
    const mesh = new THREE.Mesh(geometry, material);
    mesh.name = piece.logical_key;
    // Avoid z-fighting on coincident faces without moving contract geometry.
    mesh.renderOrder = selected ? 1 : 0;
    mesh.position.set(piece.transform_mm[0], piece.transform_mm[1], piece.transform_mm[2]);
    mesh.rotation.z = THREE.MathUtils.degToRad(piece.transform_mm[3]);
    mesh.visible = piece.visible;
    mesh.userData = { material: piece.material, selected };
    const edges = new THREE.LineSegments(new THREE.EdgesGeometry(geometry), new THREE.LineBasicMaterial({ color: selected ? 0x895408 : 0x617487 }));
    mesh.add(edges);
    scene.add(mesh);
    meshes.set(piece.logical_key, mesh);
  }
  return meshes;
}
