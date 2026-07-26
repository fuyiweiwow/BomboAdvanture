#!/usr/bin/env python3
"""Small deterministic software renderer used to visually verify creator GLBs."""

from __future__ import annotations

import argparse
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MESH_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/meshes"


def disc_geometry(
    center: tuple[float, float, float],
    radius: float,
    vertical_scale: float,
    segments: int = 32,
) -> tuple[np.ndarray, np.ndarray]:
    positions = [center]
    for index in range(segments):
        angle = index * math.tau / segments
        positions.append(
            (
                center[0] + math.cos(angle) * radius,
                center[1] + math.sin(angle) * radius * vertical_scale,
                center[2],
            )
        )
    triangles = [(0, index + 1, (index + 1) % segments + 1) for index in range(segments)]
    return np.asarray(positions, dtype=np.float32), np.asarray(triangles, dtype=np.int32)


def read_glb(path: Path, active_morphs: set[str]) -> list[tuple[np.ndarray, np.ndarray]]:
    payload = path.read_bytes()
    _, _, _ = struct.unpack_from("<4sII", payload)
    json_length, _ = struct.unpack_from("<I4s", payload, 12)
    document = json.loads(payload[20 : 20 + json_length])
    binary_header = 20 + json_length
    binary_length, _ = struct.unpack_from("<I4s", payload, binary_header)
    binary = payload[binary_header + 8 : binary_header + 8 + binary_length]

    def accessor(index: int) -> np.ndarray:
        spec = document["accessors"][index]
        view = document["bufferViews"][spec["bufferView"]]
        count = spec["count"]
        components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[spec["type"]]
        dtype = {5125: np.uint32, 5126: np.float32}[spec["componentType"]]
        offset = view.get("byteOffset", 0) + spec.get("byteOffset", 0)
        return np.frombuffer(binary, dtype=dtype, count=count * components, offset=offset).reshape(count, components)

    meshes: list[tuple[np.ndarray, np.ndarray]] = []
    for mesh in document["meshes"]:
        morph_names = mesh.get("extras", {}).get("targetNames", [])
        for primitive in mesh["primitives"]:
            positions = accessor(primitive["attributes"]["POSITION"]).copy()
            for morph_name, target_spec in zip(morph_names, primitive.get("targets", [])):
                if morph_name in active_morphs:
                    positions += accessor(target_spec["POSITION"])
            triangles = accessor(primitive["indices"]).reshape(-1, 3).astype(np.int32)
            meshes.append((positions, triangles))
    return meshes


def transform(points: np.ndarray, yaw: float) -> np.ndarray:
    cosine = math.cos(yaw)
    sine = math.sin(yaw)
    matrix = np.array(
        [[cosine, 0.0, sine], [0.0, 1.0, 0.0], [-sine, 0.0, cosine]],
        dtype=np.float32,
    )
    return points @ matrix.T


def project(
    points: np.ndarray,
    camera: np.ndarray,
    target: np.ndarray,
    width: int,
    height: int,
    fov: float,
) -> tuple[np.ndarray, np.ndarray]:
    forward = target - camera
    forward /= np.linalg.norm(forward)
    right = np.cross(forward, np.array([0.0, 1.0, 0.0], dtype=np.float32))
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    relative = points - camera
    x = relative @ right
    y = relative @ up
    depth = relative @ forward
    tangent = math.tan(math.radians(fov) * 0.5)
    ndc_x = x / np.maximum(depth * tangent * (width / height), 1e-6)
    ndc_y = y / np.maximum(depth * tangent, 1e-6)
    screen = np.column_stack(
        ((ndc_x + 1.0) * 0.5 * (width - 1), (1.0 - ndc_y) * 0.5 * (height - 1))
    )
    return screen, depth


def rasterize_triangle(
    image: np.ndarray,
    z_buffer: np.ndarray,
    triangle: np.ndarray,
    depths: np.ndarray,
    color: np.ndarray,
) -> None:
    min_x = max(0, int(math.floor(float(np.min(triangle[:, 0])))))
    max_x = min(image.shape[1] - 1, int(math.ceil(float(np.max(triangle[:, 0])))))
    min_y = max(0, int(math.floor(float(np.min(triangle[:, 1])))))
    max_y = min(image.shape[0] - 1, int(math.ceil(float(np.max(triangle[:, 1])))))
    if min_x > max_x or min_y > max_y or np.any(depths <= 0.0):
        return

    a, b, c = triangle
    denominator = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(float(denominator)) < 1e-7:
        return
    grid_x, grid_y = np.meshgrid(
        np.arange(min_x, max_x + 1, dtype=np.float32) + 0.5,
        np.arange(min_y, max_y + 1, dtype=np.float32) + 0.5,
    )
    wa = ((b[1] - c[1]) * (grid_x - c[0]) + (c[0] - b[0]) * (grid_y - c[1])) / denominator
    wb = ((c[1] - a[1]) * (grid_x - c[0]) + (a[0] - c[0]) * (grid_y - c[1])) / denominator
    wc = 1.0 - wa - wb
    inside = (wa >= -1e-5) & (wb >= -1e-5) & (wc >= -1e-5)
    if not np.any(inside):
        return
    depth = wa * depths[0] + wb * depths[1] + wc * depths[2]
    region = z_buffer[min_y : max_y + 1, min_x : max_x + 1]
    visible = inside & (depth < region)
    if not np.any(visible):
        return
    region[visible] = depth[visible]
    image[min_y : max_y + 1, min_x : max_x + 1][visible] = color


def render(
    body_type: str,
    outfit: bool,
    shoes: bool,
    hair: bool,
    outfit_style: str,
    shoe_style: str,
    hair_style: str,
    eyebrow_style: str,
    accessory_style: str,
    face_shape: str,
    eyes_style: str,
    nose_style: str,
    mouth_style: str,
    yaw: float,
    face_closeup: bool,
    output: Path,
) -> None:
    width, height = 520, 680
    image = np.zeros((height, width, 3), dtype=np.uint8)
    image[:] = np.array([31, 37, 42], dtype=np.uint8)
    z_buffer = np.full((height, width), np.inf, dtype=np.float32)
    mask = "plain"
    if outfit and shoes:
        mask = f"{outfit_style}_shoes"
    elif outfit:
        mask = outfit_style
    elif shoes:
        mask = "shoes"

    morphs = {
        f"face_{face_shape}",
        f"eyes_{eyes_style}",
        f"nose_{nose_style}",
        f"mouth_{mouth_style}",
    }
    drawables: list[tuple[np.ndarray, np.ndarray, np.ndarray]] = []
    body_meshes = read_glb(MESH_ROOT / body_type / f"body_{mask}.glb", morphs)
    for index, (positions, triangles) in enumerate(body_meshes):
        color = np.array(
            ([111, 70, 53], [137, 82, 76], [238, 233, 225], [32, 27, 28])[min(index, 3)],
            dtype=np.float32,
        )
        drawables.append((positions, triangles, color))
    if not outfit:
        for positions, triangles in read_glb(MESH_ROOT / body_type / "underwear.glb", set()):
            drawables.append((positions, triangles, np.array([48, 58, 64], dtype=np.float32)))
    if outfit:
        for positions, triangles in read_glb(MESH_ROOT / body_type / f"{outfit_style}.glb", set()):
            drawables.append((positions, triangles, np.array([52, 58, 64], dtype=np.float32)))
    if shoes:
        shoe_file = f"{shoe_style}_tucked.glb" if outfit else f"{shoe_style}.glb"
        for positions, triangles in read_glb(MESH_ROOT / body_type / shoe_file, set()):
            drawables.append((positions, triangles, np.array([36, 33, 34], dtype=np.float32)))
    if hair:
        for positions, triangles in read_glb(MESH_ROOT / body_type / f"{hair_style}.glb", set()):
            drawables.append((positions, triangles, np.array([170, 168, 164], dtype=np.float32)))
    if eyebrow_style != "none":
        for positions, triangles in read_glb(MESH_ROOT / body_type / f"{eyebrow_style}.glb", set()):
            drawables.append((positions, triangles, np.array([55, 41, 35], dtype=np.float32)))
    if accessory_style != "none":
        for positions, triangles in read_glb(MESH_ROOT / body_type / f"{accessory_style}.glb", set()):
            color = [45, 62, 70] if accessory_style == "scarf" else [166, 121, 54]
            drawables.append((positions, triangles, np.array(color, dtype=np.float32)))
    eye_specs = {
        "soft": (0.0058, 0.92, 0.8207),
        "narrow": (0.0054, 0.78, 0.8202),
        "tired": (0.0056, 0.84, 0.8198),
    }
    iris_radius, iris_scale, iris_y = eye_specs[eyes_style]
    for eye_x in (-0.0293, 0.0293):
        drawables.append(
            (
                *disc_geometry((eye_x, iris_y, 0.1457), iris_radius * 1.08, iris_scale),
                np.array([40, 32, 39], dtype=np.float32),
            )
        )
        drawables.append(
            (
                *disc_geometry((eye_x, iris_y, 0.1464), iris_radius, iris_scale),
                np.array([91, 57, 36], dtype=np.float32),
            )
        )
        drawables.append(
            (
                *disc_geometry((eye_x, iris_y, 0.1471), iris_radius * 0.40, iris_scale),
                np.array([20, 18, 22], dtype=np.float32),
            )
        )
        drawables.append(
            (
                *disc_geometry(
                    (eye_x - 0.0015, iris_y + 0.0017, 0.1478),
                    iris_radius * 0.17,
                    iris_scale,
                ),
                np.array([245, 242, 234], dtype=np.float32),
            )
        )

    if face_closeup:
        camera = np.array([0.0, 0.79, 0.78], dtype=np.float32)
        target = np.array([0.0, 0.79, 0.0], dtype=np.float32)
        fov = 28.0
    else:
        camera = np.array([0.0, 0.0, 4.05], dtype=np.float32)
        target = np.array([0.0, 0.0, 0.0], dtype=np.float32)
        fov = 28.0
    light = np.array([-0.35, 0.45, 0.82], dtype=np.float32)
    light /= np.linalg.norm(light)

    for positions, triangles, base_color in drawables:
        world = transform(positions, yaw)
        screen, depths = project(world, camera, target, width, height, fov)
        for ia, ib, ic in triangles:
            p0, p1, p2 = world[ia], world[ib], world[ic]
            normal = np.cross(p1 - p0, p2 - p0)
            length = np.linalg.norm(normal)
            if length < 1e-8:
                continue
            normal /= length
            brightness = 0.46 + 0.68 * max(0.0, float(normal @ light))
            color = np.clip(base_color * brightness, 0, 255).astype(np.uint8)
            rasterize_triangle(
                image,
                z_buffer,
                screen[[ia, ib, ic]],
                depths[[ia, ib, ic]],
                color,
            )

    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--body", choices=["lean", "standard"], default="standard")
    parser.add_argument("--outfit", action="store_true")
    parser.add_argument("--shoes", action="store_true")
    parser.add_argument("--hair", action="store_true")
    parser.add_argument("--outfit-style", default="travel_suit")
    parser.add_argument("--shoe-style", default="travel_shoes")
    parser.add_argument("--hair-style", default="short_hair")
    parser.add_argument("--eyebrow-style", default="none")
    parser.add_argument("--accessory-style", default="none")
    parser.add_argument("--face-shape", choices=["oval", "angular", "soft"], default="oval")
    parser.add_argument("--eyes-style", choices=["soft", "narrow", "tired"], default="soft")
    parser.add_argument("--nose-style", choices=["straight", "soft", "broad"], default="straight")
    parser.add_argument("--mouth-style", choices=["neutral", "gentle", "firm"], default="neutral")
    parser.add_argument("--yaw", type=float, default=0.0)
    parser.add_argument("--face", action="store_true")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    render(
        args.body,
        args.outfit,
        args.shoes,
        args.hair,
        args.outfit_style,
        args.shoe_style,
        args.hair_style,
        args.eyebrow_style,
        args.accessory_style,
        args.face_shape,
        args.eyes_style,
        args.nose_style,
        args.mouth_style,
        args.yaw,
        args.face,
        args.output,
    )


if __name__ == "__main__":
    main()
