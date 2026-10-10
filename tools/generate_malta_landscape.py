#!/usr/bin/env python3
"""Bake decorative masks/textures; never write terrain geometry or geography.

Requires numpy, scipy and Pillow. All output is original procedural artwork.
Land/water coverage is derived read-only from the supplied GLB. Agricultural
parcels are plausible visual patterns, NOT a surveyed 1940 cadastral map.
"""
import hashlib
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, gaussian_filter, map_coordinates
from scipy.spatial import cKDTree

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/malta/landscape"
BOUNDS = (-21000.0, -18500.0, 18000.0, 17500.0)
SIZE = 2048
SEED = 1942


def glb_surfaces():
    raw = (ROOT / "assets/malta/terrain.glb").read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    gltf = json.loads(raw[20:20 + length])
    offset = 20 + length
    binary = raw[offset + 8:]
    dtypes = {5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}

    def accessor(index):
        a = gltf["accessors"][index]
        v = gltf["bufferViews"][a["bufferView"]]
        channels = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
        dtype = np.dtype(dtypes[a["componentType"]])
        start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = v.get("byteStride", channels * dtype.itemsize)
        return np.ndarray((a["count"], channels), dtype, binary, start,
                          strides=(stride, dtype.itemsize)).copy()

    for node in gltf["nodes"]:
        if "mesh" not in node:
            continue
        # These assets already store world positions. Refuse silent remapping.
        assert not any(k in node for k in ("matrix", "translation", "rotation", "scale"))
        for p in gltf["meshes"][node["mesh"]]["primitives"]:
            vertices = accessor(p["attributes"]["POSITION"])
            faces = accessor(p["indices"]).reshape(-1, 3)
            yield vertices, faces


def periodic_noise(rng, resolution, octaves=(2, 7, 22, 60)):
    result = np.zeros((resolution, resolution), dtype=np.float32)
    for i, scale in enumerate(octaves):
        layer = gaussian_filter(rng.random((resolution, resolution)), scale, mode="wrap")
        layer = (layer - layer.mean()) / max(layer.std(), 0.0001)
        result += layer.astype(np.float32) / (2 ** (i * 0.7))
    return np.clip(result / 5 + 0.5, 0, 1)


def save(name, values):
    Image.fromarray(np.uint8(np.clip(values, 0, 1) * 255)).save(OUT / name, optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    dx = (BOUNDS[2] - BOUNDS[0]) / SIZE
    dz = (BOUNDS[3] - BOUNDS[1]) / SIZE
    coverage = Image.new("L", (SIZE, SIZE))
    draw = ImageDraw.Draw(coverage)
    for vertices, faces in glb_surfaces():
        tri = vertices[faces]
        normals = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        top = normals[:, 1] > 0.001
        uv = (vertices[:, [0, 2]] - np.array(BOUNDS[:2])) / np.array([dx, dz])
        for face in faces[top]:
            draw.polygon([tuple(p) for p in uv[face]], fill=255)
    land = np.array(coverage) > 127
    # World metre distance, not screen-space/depth effects; land stays untouched.
    water_distance = distance_transform_edt(~land, sampling=(dz, dx))
    coast = np.stack([land, np.clip(water_distance / 240, 0, 1), np.zeros_like(land)], axis=-1)
    Image.fromarray(np.uint8(coast * 255)).resize((1024, 1024), Image.Resampling.LANCZOS).save(OUT / "coast_distance.png", optimize=True)

    xx, zz = np.meshgrid(BOUNDS[0] + (np.arange(SIZE) + .5) * dx,
                         BOUNDS[1] + (np.arange(SIZE) + .5) * dz)
    warp_x = periodic_noise(rng, SIZE, (12, 35, 90)) * 100 - 50
    warp_z = periodic_noise(rng, SIZE, (12, 35, 90)) * 100 - 50
    # Random parcels and warped anisotropic distance avoid a repeating square grid.
    seeds = rng.uniform(BOUNDS[:2], BOUNDS[2:], (26000, 2))
    distance, indices = cKDTree(seeds * [0.85, 1.1]).query(
        np.stack([(xx + warp_x) * .85, (zz + warp_z) * 1.1], -1).reshape(-1, 2), k=2)
    index = indices[:, 0].reshape(SIZE, SIZE)
    classes = rng.choice(4, len(seeds), p=[.31, .32, .23, .14])
    strength = rng.uniform(.62, .97, len(seeds))
    masks = np.stack([(classes[index] == c) * strength[index] for c in range(3)], -1)
    boundary = np.clip(1 - (distance[:, 1] - distance[:, 0]) / 16, 0, 1).reshape(SIZE, SIZE)
    boundary *= (classes[index] < 2) * .85
    geography = json.loads((ROOT / "assets/malta/world_data.json").read_text())
    protected = np.zeros_like(xx)
    for field in geography["airfields"]:
        x, _, z = field["position"]
        a = np.deg2rad(field["heading"])
        lx = (xx - x) * np.cos(a) + (zz - z) * np.sin(a)
        lz = -(xx - x) * np.sin(a) + (zz - z) * np.cos(a)
        # Colour-only blending around unchanged operational strips/aprons.
        outside = np.maximum(np.abs(lx) - 165, np.abs(lz) - field["length"] * .55)
        protected = np.maximum(protected, np.clip(1 - outside / 120, 0, 1))
    valletta = geography["landmarks"][0]["position"]
    protected = np.maximum(protected, np.clip(1 - np.hypot(xx - valletta[0], zz - valletta[2]) / 260, 0, 1))
    masks *= (1 - protected)[..., None] * land[..., None]
    boundary *= (1 - protected) * land
    save("landcover.png", np.concatenate([masks, boundary[..., None]], -1))

    # One packed texture: limestone grain, earth, sparse scrub, furrow modulation.
    rock = periodic_noise(rng, 512)
    earth = periodic_noise(rng, 512, (1, 3, 12, 40))
    scrub = np.clip(periodic_noise(rng, 512, (2, 5, 15)) * 1.7 - .25, 0, 1)
    y, x = np.mgrid[0:512, 0:512]
    furrows = (.5 + .5 * np.sin(x * (2 * np.pi * 16 / 512))) * .6 + earth * .4
    save("surface_detail.png", np.stack([rock, earth, scrub, furrows], -1))
    strata = .5 + .18 * np.sin(y * (2 * np.pi * 8 / 512)) + .25 * (rock - .5)
    save("cliff_detail.png", np.stack([strata] * 3, -1))

    # A capped, spatially dispersed list, not thousands of runtime vegetation nodes.
    candidates = np.argwhere(land & (masks[..., 2] > .5) & (protected < .01))
    rng.shuffle(candidates)
    points = []
    for row, col in candidates:
        point = [float(xx[row, col]), float(zz[row, col])]
        if all(np.linalg.norm(np.array(point) - p) > 900 for p in points):
            points.append(point)
        if len(points) == 96:
            break
    layout = {"seed": SEED, "scrub_centres": points,
              "note": "Procedural decorative scrub only, terrain-aligned at runtime; no collision."}
    (OUT / "decoration.json").write_text(json.dumps(layout, indent=2) + "\n")
    print(json.dumps({"mask_size": SIZE, "detail_size": 512, "scrub_clusters": len(points),
                      "terrain_sha256": hashlib.sha256((ROOT / 'assets/malta/terrain.glb').read_bytes()).hexdigest()}))


if __name__ == "__main__":
    main()
