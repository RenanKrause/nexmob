import { describe, expect, it } from 'vitest';
import * as THREE from 'three';
import fixture from '../../contracts/fixtures/revision-v1.json';
import { buildModuleScene } from './scene';
import type { PublicPieceResponse } from './api';

const payload = (): PublicPieceResponse => ({ module: structuredClone(fixture.modules[0]) as PublicPieceResponse['module'], selected_piece_key: 'lateral-esquerda', synced_at: fixture.synced_at });

describe('buildModuleScene', () => {
  it('builds exactly one box per module piece in millimeters', () => {
    const scene = new THREE.Scene();
    const meshes = buildModuleScene(payload(), scene);
    expect(meshes.size).toBe(2);
    expect(scene.children.filter(child => child instanceof THREE.Mesh)).toHaveLength(2);
    const box = meshes.get('lateral-esquerda')!.geometry as THREE.BoxGeometry;
    expect(box.parameters.width).toBe(720);
    expect(box.parameters.height).toBe(560);
    expect(box.parameters.depth).toBe(18);
  });

  it('preserves XYZ placement and rotates around Z in degrees', () => {
    const data = payload();
    data.module.pieces[0].transform_mm = [120, -40, 720, 90];
    const mesh = buildModuleScene(data, new THREE.Scene()).get('lateral-esquerda')!;
    expect(mesh.position.toArray()).toEqual([120, -40, 720]);
    expect(mesh.rotation.z).toBeCloseTo(Math.PI / 2);
    expect(mesh.rotation.x).toBe(0);
    expect(mesh.rotation.y).toBe(0);
    mesh.updateMatrixWorld(true);
    const center = new THREE.Box3().setFromObject(mesh).getCenter(new THREE.Vector3());
    expect(center.toArray()).toEqual([120, -40, 720]);
  });

  it('applies effective material and highlights only the QR piece, keeping the others opaque', () => {
    const meshes = buildModuleScene(payload(), new THREE.Scene());
    const selected = meshes.get('lateral-esquerda')!;
    const other = meshes.get('base')!;
    expect(selected.userData.selected).toBe(true);
    expect(other.userData.selected).toBe(false);
    expect(other.userData.material).toBe('MDF branco');
    const selectedMaterial = selected.material as THREE.MeshStandardMaterial;
    const normalMaterial = other.material as THREE.MeshStandardMaterial;
    expect(selectedMaterial.color.getHexString()).toBe('e6a23c');
    expect(normalMaterial.color.equals(selectedMaterial.color)).toBe(false);
    expect(normalMaterial.opacity).toBe(1);
    expect(normalMaterial.transparent).toBe(false);
  });

  it('keeps hidden pieces hidden and does not introduce other modules', () => {
    const data = payload(); data.module.pieces[1].visible = false;
    const meshes = buildModuleScene(data, new THREE.Scene());
    expect([...meshes.keys()]).toEqual(['lateral-esquerda', 'base']);
    expect(meshes.get('base')!.visible).toBe(false);
  });

  it('keeps the selected surface readable when the fixture contains coplanar pieces', () => {
    const meshes = buildModuleScene(payload(), new THREE.Scene());
    const selected = meshes.get('lateral-esquerda')!;
    const other = meshes.get('base')!;
    expect(selected.renderOrder).toBeGreaterThan(other.renderOrder);
    const material = selected.material as THREE.MeshStandardMaterial;
    expect(material.polygonOffset).toBe(true);
    expect(material.polygonOffsetFactor).toBeLessThan(0);
  });
});
