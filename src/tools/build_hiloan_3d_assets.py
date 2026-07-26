#!/usr/bin/env python3
"""Build the Hiloan 3D creator meshes from the vendored MakeHuman CC0 sources."""

from __future__ import annotations

import json
import math
import struct
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/source"
VENDOR_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/vendor/makehuman/clothes"
OUTPUT_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/meshes"
ART_MASTER_DATA = (
    PROJECT_ROOT / "assets/creator/hiloan_3d/user_edits/art_master_meshes.json"
)
SCALE = 0.1


Vec2 = tuple[float, float]
Vec3 = tuple[float, float, float]
FaceCorner = tuple[int, int | None]


@dataclass
class ObjMesh:
    vertices: list[Vec3] = field(default_factory=list)
    uvs: list[Vec2] = field(default_factory=list)
    groups: dict[str, list[list[FaceCorner]]] = field(default_factory=dict)


def add(a: Vec3, b: Vec3) -> Vec3:
    return a[0] + b[0], a[1] + b[1], a[2] + b[2]


def sub(a: Vec3, b: Vec3) -> Vec3:
    return a[0] - b[0], a[1] - b[1], a[2] - b[2]


def mul(a: Vec3, amount: float) -> Vec3:
    return a[0] * amount, a[1] * amount, a[2] * amount


def cross(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def normalized(a: Vec3) -> Vec3:
    length = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])
    return (0.0, 1.0, 0.0) if length < 1e-10 else mul(a, 1.0 / length)


def parse_obj(path: Path) -> ObjMesh:
    result = ObjMesh()
    group = "default"
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if line.startswith("v "):
            _, x, y, z = line.split()[:4]
            result.vertices.append((float(x), float(y), float(z)))
        elif line.startswith("vt "):
            _, u, v = line.split()[:3]
            result.uvs.append((float(u), 1.0 - float(v)))
        elif line.startswith("g "):
            group = line[2:].strip()
        elif line.startswith("f "):
            corners: list[FaceCorner] = []
            for item in line.split()[1:]:
                parts = item.split("/")
                vertex = int(parts[0]) - 1
                uv = int(parts[1]) - 1 if len(parts) > 1 and parts[1] else None
                corners.append((vertex, uv))
            result.groups.setdefault(group, []).append(corners)
    return result


def parse_target(path: Path) -> dict[int, Vec3]:
    target: dict[int, Vec3] = {}
    for raw in path.read_text().splitlines():
        parts = raw.split()
        if len(parts) != 4:
            continue
        target[int(parts[0])] = (float(parts[1]), float(parts[2]), float(parts[3]))
    return target


def combine_targets(weighted: Iterable[tuple[dict[int, Vec3], float]]) -> dict[int, Vec3]:
    result: dict[int, Vec3] = {}
    for target, weight in weighted:
        for index, delta in target.items():
            result[index] = add(result.get(index, (0.0, 0.0, 0.0)), mul(delta, weight))
    return result


def apply_target(vertices: list[Vec3], target: dict[int, Vec3]) -> list[Vec3]:
    result = list(vertices)
    for index, delta in target.items():
        if index < len(result):
            result[index] = add(result[index], delta)
    return result


def triangulate(faces: Iterable[list[FaceCorner]]) -> list[tuple[FaceCorner, FaceCorner, FaceCorner]]:
    triangles: list[tuple[FaceCorner, FaceCorner, FaceCorner]] = []
    for face in faces:
        for index in range(1, len(face) - 1):
            triangles.append((face[0], face[index], face[index + 1]))
    return triangles


def parse_mhclo(path: Path) -> tuple[list[tuple], set[int]]:
    fit_rows: list[tuple] = []
    deleted: set[int] = set()
    section = ""
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("verts "):
            section = "verts"
            continue
        if line == "delete_verts":
            section = "delete"
            continue
        if line.startswith("delete_faces"):
            section = "other"
            continue
        if section == "verts":
            parts = line.split()
            if len(parts) == 1:
                fit_rows.append((int(parts[0]),))
            elif len(parts) == 9:
                fit_rows.append(
                    (
                        int(parts[0]),
                        int(parts[1]),
                        int(parts[2]),
                        float(parts[3]),
                        float(parts[4]),
                        float(parts[5]),
                        float(parts[6]),
                        float(parts[7]),
                        float(parts[8]),
                    )
                )
        elif section == "delete":
            tokens = line.split()
            cursor = 0
            while cursor < len(tokens):
                start = int(tokens[cursor])
                if cursor + 2 < len(tokens) and tokens[cursor + 1] == "-":
                    end = int(tokens[cursor + 2])
                    deleted.update(range(start, end + 1))
                    cursor += 3
                else:
                    deleted.add(start)
                    cursor += 1
    return fit_rows, deleted


def fit_proxy(
    body: list[Vec3],
    mhclo_path: Path,
    offset_scale: float = 1.0,
) -> tuple[list[Vec3], set[int]]:
    rows, deleted = parse_mhclo(mhclo_path)
    scale_refs: dict[str, tuple[int, int, float]] = {}
    for raw in mhclo_path.read_text().splitlines():
        parts = raw.split()
        if len(parts) == 4 and parts[0] in {"x_scale", "y_scale", "z_scale"}:
            scale_refs[parts[0][0]] = (int(parts[1]), int(parts[2]), float(parts[3]))
    axis_scale = {}
    for axis, component in (("x", 0), ("y", 1), ("z", 2)):
        first, second, divisor = scale_refs[axis]
        axis_scale[axis] = abs(body[first][component] - body[second][component]) / divisor

    fitted: list[Vec3] = []
    for row in rows:
        if len(row) == 1:
            fitted.append(body[row[0]])
            continue
        a, b, c, wa, wb, wc, dx, dy, dz = row
        anchor = add(add(mul(body[a], wa), mul(body[b], wb)), mul(body[c], wc))
        offset = (
            dx * axis_scale["x"] * offset_scale,
            dy * axis_scale["y"] * offset_scale,
            dz * axis_scale["z"] * offset_scale,
        )
        fitted.append(add(anchor, offset))
    return fitted, deleted


def smooth_normals(positions: list[Vec3], triangles: list[tuple[int, int, int]]) -> list[Vec3]:
    normals = [(0.0, 0.0, 0.0) for _ in positions]
    for ia, ib, ic in triangles:
        face_normal = cross(sub(positions[ib], positions[ia]), sub(positions[ic], positions[ia]))
        normals[ia] = add(normals[ia], face_normal)
        normals[ib] = add(normals[ib], face_normal)
        normals[ic] = add(normals[ic], face_normal)
    return [normalized(normal) for normal in normals]


def prepare_primitive(
    mesh: ObjMesh,
    vertices: list[Vec3],
    faces: Iterable[list[FaceCorner]],
    morphs: dict[str, dict[int, Vec3]] | None = None,
    deleted_vertices: set[int] | None = None,
) -> dict:
    deleted_vertices = deleted_vertices or set()
    triangles = [
        triangle
        for triangle in triangulate(faces)
        if not any(corner[0] in deleted_vertices for corner in triangle)
    ]
    corner_map: dict[FaceCorner, int] = {}
    positions: list[Vec3] = []
    uvs: list[Vec2] = []
    source_indices: list[int] = []
    indices: list[int] = []
    for triangle in triangles:
        for source_corner in triangle:
            if source_corner not in corner_map:
                source_index, uv_index = source_corner
                corner_map[source_corner] = len(positions)
                positions.append(mul(vertices[source_index], SCALE))
                source_indices.append(source_index)
                uvs.append(mesh.uvs[uv_index] if uv_index is not None else (0.0, 0.0))
            indices.append(corner_map[source_corner])
    tri_indices = [tuple(indices[i : i + 3]) for i in range(0, len(indices), 3)]
    normals = smooth_normals(positions, tri_indices)

    prepared_morphs: dict[str, list[Vec3]] = {}
    for name, target in (morphs or {}).items():
        prepared_morphs[name] = [mul(target.get(source_index, (0.0, 0.0, 0.0)), SCALE) for source_index in source_indices]
    return {
        "positions": positions,
        "normals": normals,
        "uvs": uvs,
        "indices": indices,
        "morphs": prepared_morphs,
    }


def geometry_primitive(
    positions: list[Vec3],
    triangles: list[tuple[int, int, int]],
    uvs: list[Vec2] | None = None,
) -> dict:
    return {
        "positions": positions,
        "normals": smooth_normals(positions, triangles),
        "uvs": uvs or [(0.0, 0.0) for _ in positions],
        "indices": [index for triangle in triangles for index in triangle],
        "morphs": {},
    }


def load_art_master_assets() -> dict[str, list[dict]]:
    if not ART_MASTER_DATA.exists():
        return {}
    payload = json.loads(ART_MASTER_DATA.read_text())
    return payload.get("assets", {})


def art_master_primitive(entry: dict, body_name: str, asset_name: str) -> dict:
    positions = [tuple(value) for value in entry["positions"]]
    if body_name == "lean":
        face_assets = {
            "short_hair",
            "close_crop",
            "side_swept",
            "glasses_round",
            "glasses_angular",
        }
        if asset_name in face_assets:
            positions = [(x * 0.985, y, z) for x, y, z in positions]
        elif asset_name in {"travel_suit", "field_suit", "formal_suit"}:
            adjusted: list[Vec3] = []
            for x, y, z in positions:
                horizontal = max(0.0, min(1.0, (abs(x) - 0.24) / 0.14))
                vertical = max(0.0, min(1.0, (y - 0.02) / 0.16))
                arm_weight = (
                    horizontal
                    * horizontal
                    * (3.0 - 2.0 * horizontal)
                    * vertical
                    * vertical
                    * (3.0 - 2.0 * vertical)
                )
                width_scale = 0.94 + 0.06 * arm_weight
                adjusted.append((x * width_scale, y, z))
            positions = adjusted
        else:
            positions = [(x * 0.94, y, z) for x, y, z in positions]
    triangles = [
        tuple(entry["indices"][index : index + 3])
        for index in range(0, len(entry["indices"]), 3)
    ]
    return geometry_primitive(
        positions,
        triangles,
        [tuple(value) for value in entry["uvs"]],
    )


def tube_primitive(path: list[Vec3], radius: float, sides: int = 10, closed: bool = False) -> dict:
    positions: list[Vec3] = []
    uvs: list[Vec2] = []
    path_count = len(path)
    for path_index, point in enumerate(path):
        before = path[(path_index - 1) % path_count] if closed or path_index > 0 else point
        after = path[(path_index + 1) % path_count] if closed or path_index < path_count - 1 else point
        tangent = normalized(sub(after, before))
        reference = (0.0, 0.0, 1.0) if abs(tangent[2]) < 0.86 else (1.0, 0.0, 0.0)
        side = normalized(cross(tangent, reference))
        up = normalized(cross(side, tangent))
        for side_index in range(sides):
            angle = math.tau * side_index / sides
            offset = add(mul(side, math.cos(angle) * radius), mul(up, math.sin(angle) * radius))
            positions.append(add(point, offset))
            uvs.append((side_index / sides, path_index / max(1, path_count - 1)))

    triangles: list[tuple[int, int, int]] = []
    segment_count = path_count if closed else path_count - 1
    for path_index in range(segment_count):
        next_path = (path_index + 1) % path_count
        for side_index in range(sides):
            next_side = (side_index + 1) % sides
            a = path_index * sides + side_index
            b = path_index * sides + next_side
            c = next_path * sides + side_index
            d = next_path * sides + next_side
            triangles.extend(((a, c, b), (b, c, d)))
    return geometry_primitive(positions, triangles, uvs)


def cylinder_z_primitive(center: Vec3, radius: float, depth: float, segments: int = 32) -> dict:
    positions: list[Vec3] = []
    uvs: list[Vec2] = []
    for z_offset in (-depth * 0.5, depth * 0.5):
        for index in range(segments):
            angle = math.tau * index / segments
            positions.append(
                (
                    center[0] + math.cos(angle) * radius,
                    center[1] + math.sin(angle) * radius,
                    center[2] + z_offset,
                )
            )
            uvs.append((index / segments, 0.0 if z_offset < 0.0 else 1.0))
    positions.extend(
        [
            (center[0], center[1], center[2] - depth * 0.5),
            (center[0], center[1], center[2] + depth * 0.5),
        ]
    )
    uvs.extend(((0.5, 0.5), (0.5, 0.5)))
    triangles: list[tuple[int, int, int]] = []
    front_center = segments * 2
    back_center = front_center + 1
    for index in range(segments):
        next_index = (index + 1) % segments
        triangles.extend(
            (
                (index, segments + index, next_index),
                (next_index, segments + index, segments + next_index),
                (front_center, next_index, index),
                (back_center, segments + index, segments + next_index),
            )
        )
    return geometry_primitive(positions, triangles, uvs)


def revolution_primitive(
    center: Vec3,
    profile: list[tuple[float, float]],
    segments: int = 24,
) -> dict:
    positions: list[Vec3] = []
    uvs: list[Vec2] = []
    for profile_index, (height, radius) in enumerate(profile):
        for segment in range(segments):
            angle = math.tau * segment / segments
            positions.append(
                (
                    center[0] + math.cos(angle) * radius,
                    center[1] + height,
                    center[2] + math.sin(angle) * radius,
                )
            )
            uvs.append((segment / segments, profile_index / max(1, len(profile) - 1)))
    triangles: list[tuple[int, int, int]] = []
    for profile_index in range(len(profile) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            a = profile_index * segments + segment
            b = profile_index * segments + next_segment
            c = (profile_index + 1) * segments + segment
            d = (profile_index + 1) * segments + next_segment
            triangles.extend(((a, c, b), (b, c, d)))
    return geometry_primitive(positions, triangles, uvs)


def scarf_tail_primitive(center_x: float, top_y: float, width: float, length: float, z: float) -> dict:
    columns = 8
    rows = 18
    positions: list[Vec3] = []
    uvs: list[Vec2] = []
    for row in range(rows):
        v = row / (rows - 1)
        taper = 1.0 - v * 0.22
        for column in range(columns):
            u = column / (columns - 1)
            x = center_x + (u - 0.5) * width * taper + math.sin(v * math.pi * 1.3) * 0.018
            y = top_y - v * length
            fold = math.sin(u * math.pi * 3.0 + v * 2.0) * 0.008
            positions.append((x, y, z + fold + v * 0.015))
            uvs.append((u, v))
    triangles: list[tuple[int, int, int]] = []
    for row in range(rows - 1):
        for column in range(columns - 1):
            a = row * columns + column
            b = a + 1
            c = a + columns
            d = c + 1
            triangles.extend(((a, c, b), (b, c, d)))
    return geometry_primitive(positions, triangles, uvs)


def build_accessories(body_dir: Path, width: float) -> None:
    pendant_chain = [
        (-0.071 * width, 0.606, 0.149),
        (-0.064 * width, 0.552, 0.176),
        (-0.042 * width, 0.486, 0.194),
        (0.0, 0.435, 0.207),
        (0.042 * width, 0.486, 0.194),
        (0.064 * width, 0.552, 0.176),
        (0.071 * width, 0.606, 0.149),
    ]
    write_glb(
        body_dir / "pendant.glb",
        [
            ("PendantChain", tube_primitive(pendant_chain, 0.0048, 9), 0),
            ("PendantMedallion", cylinder_z_primitive((0.0, 0.397, 0.212), 0.035, 0.010), 0),
            (
                "PendantRelief",
                tube_primitive(
                    [
                        (-0.022, 0.397, 0.219),
                        (0.0, 0.419, 0.221),
                        (0.022, 0.397, 0.219),
                        (0.0, 0.375, 0.221),
                        (-0.022, 0.397, 0.219),
                    ],
                    0.003,
                    8,
                ),
                0,
            ),
        ],
        [material("PendantMetal", "#a87834", 0.34, 0.65)],
    )

    scarf_ring = [
        (
            math.cos(math.tau * index / 28) * 0.105 * width,
            0.617 + math.sin(math.tau * index / 28) * 0.018,
            math.sin(math.tau * index / 28) * 0.082,
        )
        for index in range(28)
    ]
    write_glb(
        body_dir / "scarf.glb",
        [
            ("ScarfCollar", tube_primitive(scarf_ring, 0.024, 10, True), 0),
            ("ScarfTailLeft", scarf_tail_primitive(-0.047, 0.59, 0.105, 0.38, 0.177), 0),
            ("ScarfTailRight", scarf_tail_primitive(0.055, 0.585, 0.088, 0.29, 0.172), 0),
        ],
        [material("ScarfFabric", "#2b3e47", 0.92)],
    )

    vial_center = (0.22 * width, -0.15, 0.19)
    vial_profile = [
        (-0.06, 0.005),
        (-0.055, 0.020),
        (-0.044, 0.030),
        (0.025, 0.030),
        (0.040, 0.023),
        (0.052, 0.014),
        (0.065, 0.014),
    ]
    vial_strap = [
        (0.105 * width, 0.018, 0.178),
        (0.145 * width, -0.035, 0.188),
        (0.195 * width, -0.082, 0.194),
        (0.22 * width, -0.095, 0.19),
    ]
    write_glb(
        body_dir / "belt_vial.glb",
        [
            ("VialLeatherLoop", tube_primitive(vial_strap, 0.008, 9), 0),
            ("VialBottle", revolution_primitive(vial_center, vial_profile), 0),
            (
                "VialCap",
                revolution_primitive(
                    (vial_center[0], vial_center[1] + 0.065, vial_center[2]),
                    [(-0.009, 0.016), (0.009, 0.016)],
                ),
                0,
            ),
        ],
        [material("VialAssembly", "#879ea5", 0.42, 0.28)],
    )


class GlbBuilder:
    def __init__(self) -> None:
        self.data = bytearray()
        self.buffer_views: list[dict] = []
        self.accessors: list[dict] = []

    def _align(self) -> None:
        while len(self.data) % 4:
            self.data.append(0)

    def add_blob(self, blob: bytes, target: int | None = None) -> int:
        self._align()
        offset = len(self.data)
        self.data.extend(blob)
        view: dict = {"buffer": 0, "byteOffset": offset, "byteLength": len(blob)}
        if target is not None:
            view["target"] = target
        self.buffer_views.append(view)
        return len(self.buffer_views) - 1

    def add_vec(self, values: list[tuple], vector_type: str, include_bounds: bool = False) -> int:
        flattened = [component for value in values for component in value]
        view = self.add_blob(struct.pack("<" + "f" * len(flattened), *flattened), 34962)
        accessor: dict = {
            "bufferView": view,
            "componentType": 5126,
            "count": len(values),
            "type": vector_type,
        }
        if include_bounds and values:
            accessor["min"] = [min(value[i] for value in values) for i in range(len(values[0]))]
            accessor["max"] = [max(value[i] for value in values) for i in range(len(values[0]))]
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def add_indices(self, values: list[int]) -> int:
        view = self.add_blob(struct.pack("<" + "I" * len(values), *values), 34963)
        self.accessors.append(
            {
                "bufferView": view,
                "componentType": 5125,
                "count": len(values),
                "type": "SCALAR",
                "min": [min(values)],
                "max": [max(values)],
            }
        )
        return len(self.accessors) - 1

    def add_mesh(self, primitive: dict, material: int, name: str) -> dict:
        attributes = {
            "POSITION": self.add_vec(primitive["positions"], "VEC3", True),
            "NORMAL": self.add_vec(primitive["normals"], "VEC3"),
            "TEXCOORD_0": self.add_vec(primitive["uvs"], "VEC2"),
        }
        gltf_primitive: dict = {
            "attributes": attributes,
            "indices": self.add_indices(primitive["indices"]),
            "material": material,
            "mode": 4,
        }
        morph_names = list(primitive["morphs"])
        if morph_names:
            gltf_primitive["targets"] = [
                {"POSITION": self.add_vec(primitive["morphs"][morph_name], "VEC3")}
                for morph_name in morph_names
            ]
        mesh: dict = {"name": name, "primitives": [gltf_primitive]}
        if morph_names:
            mesh["weights"] = [0.0] * len(morph_names)
            mesh["extras"] = {"targetNames": morph_names}
        return mesh


def write_glb(
    path: Path,
    entries: list[tuple[str, dict, int]],
    materials: list[dict],
) -> None:
    builder = GlbBuilder()
    meshes = [builder.add_mesh(primitive, material, name) for name, primitive, material in entries]
    nodes = [{"name": name, "mesh": index} for index, (name, _, _) in enumerate(entries)]
    document = {
        "asset": {"version": "2.0", "generator": "BomboAdvanture Hiloan 3D builder"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "buffers": [{"byteLength": len(builder.data)}],
        "bufferViews": builder.buffer_views,
        "accessors": builder.accessors,
    }
    json_data = json.dumps(document, separators=(",", ":")).encode()
    while len(json_data) % 4:
        json_data += b" "
    while len(builder.data) % 4:
        builder.data.append(0)
    total_length = 12 + 8 + len(json_data) + 8 + len(builder.data)
    glb = bytearray(struct.pack("<4sII", b"glTF", 2, total_length))
    glb.extend(struct.pack("<I4s", len(json_data), b"JSON"))
    glb.extend(json_data)
    glb.extend(struct.pack("<I4s", len(builder.data), b"BIN\x00"))
    glb.extend(builder.data)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(glb)


def material(name: str, color: str, roughness: float = 0.8, metallic: float = 0.0) -> dict:
    value = color.removeprefix("#")
    rgb = [int(value[i : i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return {
        "name": name,
        "pbrMetallicRoughness": {
            "baseColorFactor": [*rgb, 1.0],
            "metallicFactor": metallic,
            "roughnessFactor": roughness,
        },
        "doubleSided": True,
    }


def target(name: str) -> dict[int, Vec3]:
    return parse_target(SOURCE_ROOT / name)


def muscle_profile(strength: float) -> dict[int, Vec3]:
    weights = [
        ("torso-muscle-pectoral-incr.target", 1.06),
        ("torso-muscle-dorsi-incr.target", 0.82),
        ("torso-vshape-incr.target", 0.32),
        ("stomach-tone-incr.target", 1.08),
        ("l-upperarm-shoulder-muscle-incr.target", 0.68),
        ("r-upperarm-shoulder-muscle-incr.target", 0.68),
        ("l-upperarm-muscle-incr.target", 0.62),
        ("r-upperarm-muscle-incr.target", 0.62),
        ("l-lowerarm-muscle-incr.target", 0.44),
        ("r-lowerarm-muscle-incr.target", 0.44),
        ("l-upperleg-muscle-incr.target", 0.58),
        ("r-upperleg-muscle-incr.target", 0.58),
        ("l-lowerleg-muscle-incr.target", 0.50),
        ("r-lowerleg-muscle-incr.target", 0.50),
    ]
    return combine_targets([(target(name), weight * strength) for name, weight in weights])


def offset_primitive(primitive: dict, amount: float) -> dict:
    primitive["positions"] = [
        add(position, mul(normal, amount))
        for position, normal in zip(primitive["positions"], primitive["normals"])
    ]
    return primitive


def conform_eyelashes(primitive: dict, body_primitive: dict) -> dict:
    eyelid_surface = [
        position
        for position in body_primitive["positions"]
        if abs(position[0]) < 0.065
        and 0.79 < position[1] < 0.845
        and position[2] > 0.125
    ]
    conformed: list[Vec3] = []
    for x, y, z in primitive["positions"]:
        nearest = min(
            eyelid_surface,
            key=lambda point: (point[0] - x) ** 2 + (point[1] - y) ** 2,
        )
        conformed.append((x, y, nearest[2] + 0.00025))
    primitive["positions"] = conformed
    triangles = [
        tuple(primitive["indices"][index : index + 3])
        for index in range(0, len(primitive["indices"]), 3)
    ]
    primitive["normals"] = smooth_normals(conformed, triangles)
    return primitive


def expand_face_region(
    all_faces: list[list[FaceCorner]],
    seed_faces: list[list[FaceCorner]],
    rings: int,
    predicate,
) -> list[list[FaceCorner]]:
    selected_ids = {id(face) for face in seed_faces}
    selected_vertices = {corner[0] for face in seed_faces for corner in face}
    for _ in range(rings):
        additions = [
            face
            for face in all_faces
            if id(face) not in selected_ids
            and any(corner[0] in selected_vertices for corner in face)
            and predicate(face)
        ]
        if not additions:
            break
        selected_ids.update(id(face) for face in additions)
        selected_vertices.update(corner[0] for face in additions for corner in face)
    return [face for face in all_faces if id(face) in selected_ids]


def widen_hair(name: str, vertices: list[Vec3]) -> list[Vec3]:
    width_scale = {
        "short_hair": 1.115,
        "close_crop": 1.060,
        "side_swept": 1.030,
    }.get(name, 1.0)
    if width_scale == 1.0:
        return vertices
    center_x = (min(vertex[0] for vertex in vertices) + max(vertex[0] for vertex in vertices)) * 0.5
    return [
        (center_x + (x - center_x) * width_scale, y, z)
        for x, y, z in vertices
    ]


def smoothstep(low: float, high: float, value: float) -> float:
    if high <= low:
        return 0.0
    normalized_value = max(0.0, min(1.0, (value - low) / (high - low)))
    return normalized_value * normalized_value * (3.0 - 2.0 * normalized_value)


def expand_cross_section(
    first: float,
    second: float,
    center_first: float,
    center_second: float,
    amount: float,
) -> tuple[float, float]:
    delta_first = first - center_first
    delta_second = second - center_second
    distance = math.hypot(delta_first, delta_second)
    if distance < 1e-8:
        return first, second
    return (
        first + delta_first / distance * amount,
        second + delta_second / distance * amount,
    )


def shape_outfit(name: str, vertices: list[Vec3]) -> list[Vec3]:
    torso_ease, sleeve_ease, trouser_ease = {
        "travel_suit": (0.10, 0.12, 0.15),
        "field_suit": (0.09, 0.13, 0.16),
        "formal_suit": (0.075, 0.09, 0.11),
    }[name]
    shaped: list[Vec3] = []
    for x, y, z in vertices:
        result_x, result_y, result_z = x, y, z
        absolute_x = abs(x)

        torso_weight = (
            smoothstep(3.65, 4.45, y)
            * (1.0 - smoothstep(6.85, 7.28, y))
            * (1.0 - smoothstep(1.85, 2.55, absolute_x))
        )
        if torso_weight > 0.0:
            result_x, result_z = expand_cross_section(
                result_x,
                result_z,
                0.0,
                0.28,
                torso_ease * torso_weight,
            )

        sleeve_weight = (
            smoothstep(1.75, 2.35, absolute_x)
            * (1.0 - smoothstep(5.00, 5.55, absolute_x))
            * smoothstep(3.65, 4.30, y)
        )
        if sleeve_weight > 0.0:
            arm_axis_y = 6.55 - max(0.0, absolute_x - 1.80) * 0.43
            result_y, result_z = expand_cross_section(
                result_y,
                result_z,
                arm_axis_y,
                0.24,
                sleeve_ease * sleeve_weight,
            )

        trouser_weight = (
            (1.0 - smoothstep(3.65, 4.20, y))
            * smoothstep(-7.35, -6.55, y)
            * (1.0 - smoothstep(2.15, 2.75, absolute_x))
        )
        if trouser_weight > 0.0 and absolute_x > 0.20:
            leg_center_x = math.copysign(0.88, x)
            result_x, result_z = expand_cross_section(
                result_x,
                result_z,
                leg_center_x,
                0.18,
                trouser_ease * trouser_weight,
            )

        shaped.append((result_x, result_y, result_z))
    return shaped


def boundary_loops(mesh: ObjMesh) -> list[list[int]]:
    edge_counts: dict[tuple[int, int], int] = {}
    for faces in mesh.groups.values():
        for face in faces:
            vertex_indices = [corner[0] for corner in face]
            for first, second in zip(vertex_indices, vertex_indices[1:] + vertex_indices[:1]):
                edge = tuple(sorted((first, second)))
                edge_counts[edge] = edge_counts.get(edge, 0) + 1

    adjacency: dict[int, set[int]] = {}
    for (first, second), count in edge_counts.items():
        if count != 1:
            continue
        adjacency.setdefault(first, set()).add(second)
        adjacency.setdefault(second, set()).add(first)

    loops: list[list[int]] = []
    remaining = set(adjacency)
    while remaining:
        start = next(iter(remaining))
        loop = [start]
        previous: int | None = None
        current = start
        while True:
            candidates = [index for index in adjacency[current] if index != previous]
            if not candidates:
                break
            next_index = candidates[0]
            if next_index == start:
                break
            if next_index in loop:
                break
            loop.append(next_index)
            previous, current = current, next_index
        remaining.difference_update(loop)
        loops.append(loop)
    return loops


def underwear_waistband(mesh: ObjMesh, fitted_vertices: list[Vec3]) -> dict:
    waist_loop = max(
        boundary_loops(mesh),
        key=lambda loop: sum(fitted_vertices[index][1] for index in loop) / len(loop),
    )
    path = [mul(fitted_vertices[index], SCALE) for index in waist_loop]
    center_x = sum(point[0] for point in path) / len(path)
    center_z = sum(point[2] for point in path) / len(path)
    positions: list[Vec3] = []
    uvs: list[Vec2] = []
    for path_index, (x, y, z) in enumerate(path):
        radial = normalized((x - center_x, 0.0, z - center_z))
        inner_bottom = add((x, y - 0.003, z), mul(radial, -0.0008))
        outer_bottom = add((x, y - 0.003, z), mul(radial, 0.0040))
        inner_top = add((x, y + 0.019, z), mul(radial, -0.0008))
        outer_top = add((x, y + 0.019, z), mul(radial, 0.0040))
        positions.extend((inner_bottom, outer_bottom, inner_top, outer_top))
        u = path_index / len(path)
        uvs.extend(((u, 0.0), (u, 0.0), (u, 1.0), (u, 1.0)))

    triangles: list[tuple[int, int, int]] = []
    for path_index in range(len(path)):
        next_path = (path_index + 1) % len(path)
        a = path_index * 4
        b = next_path * 4
        triangles.extend(
            (
                (a + 1, b + 1, a + 3),
                (a + 3, b + 1, b + 3),
                (a, a + 2, b),
                (a + 2, b + 2, b),
                (a + 2, a + 3, b + 2),
                (a + 3, b + 3, b + 2),
                (a, b, a + 1),
                (a + 1, b, b + 1),
            )
        )
    return geometry_primitive(positions, triangles, uvs)


def shape_underwear(vertices: list[Vec3]) -> list[Vec3]:
    shaped: list[Vec3] = []
    for x, y, z in vertices:
        horizontal = math.exp(-((x / 0.060) ** 2))
        vertical = math.exp(-(((y - 0.065) / 0.072) ** 2))
        front = max(0.0, min(1.0, (z - 0.035) / 0.105))
        shaped.append((x, y, z + 0.009 * horizontal * vertical * front))
    return shaped


def build() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    art_master_assets = load_art_master_assets()
    base_mesh = parse_obj(SOURCE_ROOT / "base.obj")
    male = target("caucasian-male-young.target")
    lean = target("bodyshapes-elvs-man-lean-column.target")

    # Creator presets are deliberately restrained. Their purpose is to keep a
    # harmonious shared face while changing silhouette and expression subtly.
    face_harmony = combine_targets(
        [
            (target("chin-width-decr.target"), 0.12),
            (target("chin-height-decr.target"), 0.075),
            (target("head-scale-vert-decr.target"), 0.055),
            (target("forehead-scale-vert-decr.target"), 0.10),
            (target("nose-scale-horiz-decr.target"), 0.07),
            (target("nose-scale-vert-decr.target"), 0.055),
            (target("nose-volume-decr.target"), 0.04),
            (target("mouth-scale-horiz-incr.target"), 0.055),
            (target("l-eye-scale-incr.target"), 0.045),
            (target("r-eye-scale-incr.target"), 0.045),
        ]
    )
    morphs = {
        "face_oval": combine_targets(
            [
                (target("head-oval.target"), 0.12),
                (target("chin-width-decr.target"), 0.055),
                (target("chin-height-decr.target"), 0.025),
            ]
        ),
        "face_angular": combine_targets(
            [
                (target("head-rectangular.target"), 0.10),
                (target("chin-width-incr.target"), 0.055),
                (target("chin-height-decr.target"), 0.025),
            ]
        ),
        "face_soft": combine_targets(
            [
                (target("head-round.target"), 0.12),
                (target("chin-width-decr.target"), 0.035),
                (target("chin-height-decr.target"), 0.035),
            ]
        ),
        "ears_pointed": combine_targets(
            [
                (target("l-ear-shape-pointed.target"), 0.45),
                (target("r-ear-shape-pointed.target"), 0.45),
            ]
        ),
        "eyes_soft": combine_targets(
            [
                (target(f"{side}-eye-height{part}-incr.target"), 0.12)
                for side in ("l", "r")
                for part in (1, 2, 3)
            ]
            + [
                (target("l-eye-corner2-up.target"), 0.06),
                (target("r-eye-corner2-up.target"), 0.06),
            ]
        ),
        "eyes_narrow": combine_targets(
            [
                (target(f"{side}-eye-height{part}-decr.target"), 0.16)
                for side in ("l", "r")
                for part in (1, 2, 3)
            ]
            + [
                (target("l-eye-corner2-up.target"), 0.08),
                (target("r-eye-corner2-up.target"), 0.08),
            ]
        ),
        "eyes_tired": combine_targets(
            [
                *[
                    (target(f"{side}-eye-corner{corner}-down.target"), 0.16)
                    for side in ("l", "r")
                    for corner in (1, 2)
                ],
                (target("l-eye-bag-incr.target"), 0.08),
                (target("r-eye-bag-incr.target"), 0.08),
            ]
        ),
        "nose_straight": combine_targets(
            [
                (target("nose-hump-decr.target"), 0.18),
                (target("nose-curve-concave.target"), 0.07),
                (target("nose-scale-horiz-decr.target"), 0.05),
            ]
        ),
        "nose_soft": combine_targets(
            [
                (target("nose-point-width-incr.target"), 0.14),
                (target("nose-scale-depth-decr.target"), 0.10),
                (target("nose-point-up.target"), 0.06),
            ]
        ),
        "nose_broad": combine_targets(
            [
                (target("nose-scale-horiz-incr.target"), 0.13),
                (target("nose-nostrils-width-incr.target"), 0.10),
                (target("nose-width2-incr.target"), 0.10),
            ]
        ),
        "mouth_gentle": combine_targets(
            [
                (target("mouth-angles-up.target"), 0.15),
                (target("mouth-scale-horiz-incr.target"), 0.055),
            ]
        ),
        "mouth_firm": combine_targets(
            [
                (target("mouth-angles-down.target"), 0.10),
                (target("mouth-scale-horiz-decr.target"), 0.08),
                (target("mouth-scale-vert-decr.target"), 0.05),
            ]
        ),
    }

    suit_mesh = parse_obj(SOURCE_ROOT / "travel_suit.obj")
    shoes_mesh = parse_obj(SOURCE_ROOT / "travel_shoes.obj")
    hair_mesh = parse_obj(SOURCE_ROOT / "short_hair.obj")
    proxy_specs = [
        ("travel_suit", suit_mesh, SOURCE_ROOT / "travel_suit.mhclo", "#243b48"),
        (
            "field_suit",
            parse_obj(SOURCE_ROOT / "field_suit.obj"),
            SOURCE_ROOT / "field_suit.mhclo",
            "#34453e",
        ),
        (
            "formal_suit",
            parse_obj(SOURCE_ROOT / "formal_suit.obj"),
            SOURCE_ROOT / "formal_suit.mhclo",
            "#343942",
        ),
        (
            "underwear",
            parse_obj(SOURCE_ROOT / "underwear.obj"),
            SOURCE_ROOT / "underwear.mhclo",
            "#303a40",
        ),
        ("travel_shoes", shoes_mesh, SOURCE_ROOT / "travel_shoes.mhclo", "#37291f"),
        (
            "low_shoes",
            parse_obj(SOURCE_ROOT / "low_shoes.obj"),
            SOURCE_ROOT / "low_shoes.mhclo",
            "#342a24",
        ),
        (
            "travel_boots",
            parse_obj(SOURCE_ROOT / "travel_boots.obj"),
            SOURCE_ROOT / "travel_boots.mhclo",
            "#2f2927",
        ),
        ("short_hair", hair_mesh, SOURCE_ROOT / "short_hair.mhclo", "#2a211e"),
        (
            "close_crop",
            parse_obj(SOURCE_ROOT / "close_crop.obj"),
            SOURCE_ROOT / "close_crop.mhclo",
            "#2a211e",
        ),
        (
            "side_swept",
            parse_obj(SOURCE_ROOT / "side_swept.obj"),
            SOURCE_ROOT / "side_swept.mhclo",
            "#2a211e",
        ),
        (
            "eyebrow_natural",
            parse_obj(SOURCE_ROOT / "eyebrow_natural.obj"),
            SOURCE_ROOT / "eyebrow_natural.mhclo",
            "#2a211e",
        ),
        (
            "eyebrow_arched",
            parse_obj(SOURCE_ROOT / "eyebrow_arched.obj"),
            SOURCE_ROOT / "eyebrow_arched.mhclo",
            "#2a211e",
        ),
        (
            "eyebrow_full",
            parse_obj(SOURCE_ROOT / "eyebrow_full.obj"),
            SOURCE_ROOT / "eyebrow_full.mhclo",
            "#2a211e",
        ),
    ]
    outfit_names = {"travel_suit", "field_suit", "formal_suit"}
    shoe_names = {"travel_shoes", "low_shoes", "travel_boots"}

    mask_sets: dict[str, set[int]] = {"plain": set()}
    shoe_mask: set[int] = set()
    outfit_masks: dict[str, set[int]] = {}
    external_mask_paths = {
        "travel_suit": [
            VENDOR_ROOT
            / "rehmanpolanski_viking_tunic/rehmanpolanski_viking_tunic.mhclo",
            VENDOR_ROOT
            / "rehmanpolanski_viking_pants/rehmanpolanski_viking_pants.mhclo",
        ],
        "field_suit": [
            VENDOR_ROOT
            / "thegreatengineer_galactic_warrior_uniform/thegreatengineer_galactic_warrior_uniform.mhclo",
            VENDOR_ROOT
            / "matcreator_mc-skinsuit_2022/matcreator_mc-skinsuit_2022.mhclo",
        ],
        "formal_suit": [
            VENDOR_ROOT / "donitz_monk_robe/donitz_monk_robe.mhclo",
        ],
        "shoes": [
            VENDOR_ROOT / "culturalibre_male_boots/culturalibre_male_boots.mhclo",
            VENDOR_ROOT / "toigo_ankle_boots_male/toigo_ankle_boots_male.mhclo",
            VENDOR_ROOT
            / "rehmanpolanski_viking_boots/rehmanpolanski_viking_boots.mhclo",
        ],
    }
    if art_master_assets:
        for style, paths in external_mask_paths.items():
            deleted = set().union(*(parse_mhclo(path)[1] for path in paths))
            if style == "shoes":
                shoe_mask |= deleted
            else:
                outfit_masks[style] = deleted
    else:
        for proxy_name, _, mhclo, _ in proxy_specs:
            _, deleted = parse_mhclo(mhclo)
            if proxy_name in outfit_names:
                outfit_masks[proxy_name] = deleted
            elif proxy_name in shoe_names:
                shoe_mask |= deleted
    mask_sets["shoes"] = shoe_mask
    for outfit_name, outfit_mask in outfit_masks.items():
        mask_sets[outfit_name] = outfit_mask
        mask_sets[outfit_name + "_shoes"] = outfit_mask | shoe_mask

    skin_materials = [
        material("Skin", "#c58c68", 0.86),
        material("EyeWhite", "#eee9df", 0.55),
        material("Lashes", "#241c1b", 0.9),
    ]
    eye_groups = [
        *base_mesh.groups.get("helper-l-eye", []),
        *base_mesh.groups.get("helper-r-eye", []),
    ]
    lash_groups = [
        face
        for group_name, faces in base_mesh.groups.items()
        if group_name.endswith(("eyelashes-1", "eyelashes-2"))
        for face in faces
    ]
    lip_vertex_names = [
        "mouth-upperlip-volume-incr.target",
        "mouth-lowerlip-volume-incr.target",
    ]
    lip_vertices = set().union(*(target(name).keys() for name in lip_vertex_names))
    lip_core_faces = [
        face
        for face in base_mesh.groups["body"]
        if all(corner[0] in lip_vertices for corner in face)
        and all(base_mesh.vertices[corner[0]][2] > 1.52 for corner in face)
        and sum(base_mesh.vertices[corner[0]][1] for corner in face) / len(face) > 6.535
    ]
    lip_faces = expand_face_region(
        base_mesh.groups["body"],
        lip_core_faces,
        1,
        lambda face: (
            all(base_mesh.vertices[corner[0]][2] > 1.47 for corner in face)
            and sum(base_mesh.vertices[corner[0]][1] for corner in face) / len(face) > 6.48
        ),
    )
    lip_faces = expand_face_region(
        base_mesh.groups["body"],
        lip_faces,
        1,
        lambda face: (
            0.15
            < abs(sum(base_mesh.vertices[corner[0]][0] for corner in face) / len(face))
            < 0.27
            and 6.52
            < sum(base_mesh.vertices[corner[0]][1] for corner in face) / len(face)
            < 6.72
            and all(base_mesh.vertices[corner[0]][2] > 1.42 for corner in face)
        ),
    )
    skin_faces = base_mesh.groups["body"]
    face_fit_faces = [
        face
        for face in base_mesh.groups["body"]
        if min(base_mesh.vertices[corner[0]][1] for corner in face) > 5.75
        and min(base_mesh.vertices[corner[0]][2] for corner in face) > 0.28
        and max(abs(base_mesh.vertices[corner[0]][0]) for corner in face) < 1.08
    ]
    scalp_faces = [
        face
        for face in base_mesh.groups["body"]
        if min(base_mesh.vertices[corner[0]][1] for corner in face) > 7.75
        and max(base_mesh.vertices[corner[0]][2] for corner in face) < 1.35
        and max(abs(base_mesh.vertices[corner[0]][0]) for corner in face) < 0.88
    ]
    for body_name, body_delta in (
        (
            "standard",
            combine_targets([(male, 1.0), (face_harmony, 1.0), (muscle_profile(1.0), 1.0)]),
        ),
        (
            "lean",
            combine_targets(
                [(male, 1.0), (lean, 0.8), (face_harmony, 1.0), (muscle_profile(0.58), 1.0)]
            ),
        ),
    ):
        body_vertices = apply_target(base_mesh.vertices, body_delta)
        body_dir = OUTPUT_ROOT / body_name
        build_accessories(body_dir, 0.91 if body_name == "lean" else 1.0)
        write_glb(
            body_dir / "face_fit_surface.glb",
            [
                (
                    "FaceFitSurface",
                    prepare_primitive(base_mesh, body_vertices, face_fit_faces, morphs),
                    0,
                )
            ],
            [skin_materials[0]],
        )
        for mask_name, deleted in mask_sets.items():
            body_primitive = prepare_primitive(
                base_mesh,
                body_vertices,
                skin_faces,
                morphs,
                deleted,
            )
            eyelash_primitive = prepare_primitive(
                base_mesh,
                body_vertices,
                lash_groups,
                morphs,
            )
            entries = [
                ("Body", body_primitive, 0),
                ("EyeWhites", prepare_primitive(base_mesh, body_vertices, eye_groups, morphs), 1),
                ("Eyelashes", eyelash_primitive, 2),
            ]
            write_glb(body_dir / f"body_{mask_name}.glb", entries, skin_materials)

        for proxy_name, proxy_mesh, mhclo, color in proxy_specs:
            fitted, _ = fit_proxy(body_vertices, mhclo)
            art_entries = art_master_assets.get(proxy_name, [])
            if art_entries:
                entries = [
                    (
                        entry["name"],
                        art_master_primitive(entry, body_name, proxy_name),
                        0,
                    )
                    for entry in art_entries
                ]
                if (
                    proxy_name == "field_suit"
                    and not any(entry[0] == "FrostfieldUnderlayer" for entry in entries)
                ):
                    underlayer_root = VENDOR_ROOT / "matcreator_mc-skinsuit_2022"
                    underlayer_mesh = parse_obj(underlayer_root / "MC-SkinSuit_2022.obj")
                    underlayer_vertices, _ = fit_proxy(
                        body_vertices,
                        underlayer_root / "matcreator_mc-skinsuit_2022.mhclo",
                        0.1,
                    )
                    underlayer_faces = [
                        face
                        for group_faces in underlayer_mesh.groups.values()
                        for face in group_faces
                    ]
                    entries.insert(
                        0,
                        (
                            "FrostfieldUnderlayer",
                            prepare_primitive(
                                underlayer_mesh,
                                underlayer_vertices,
                                underlayer_faces,
                            ),
                            0,
                        ),
                    )
                materials = [material(proxy_name, color)]
                if proxy_name in {"short_hair", "close_crop", "side_swept"}:
                    hair_cap = offset_primitive(
                        prepare_primitive(base_mesh, body_vertices, scalp_faces),
                        0.00035,
                    )
                    entries.append(("HairCap", hair_cap, 1))
                    materials.append(material("hair_cap", color, 0.86))
                write_glb(body_dir / f"{proxy_name}.glb", entries, materials)
                if proxy_name in shoe_names:
                    write_glb(
                        body_dir / f"{proxy_name}_tucked.glb",
                        entries,
                        materials,
                    )
                continue
            if proxy_name == "underwear":
                fitted = shape_underwear(fitted)
            elif proxy_name in {"short_hair", "close_crop", "side_swept"}:
                fitted = widen_hair(proxy_name, fitted)
            elif proxy_name in outfit_names:
                fitted = shape_outfit(proxy_name, fitted)
            faces = [face for group_faces in proxy_mesh.groups.values() for face in group_faces]
            primitive = prepare_primitive(proxy_mesh, fitted, faces)
            entries = [(proxy_name.title().replace("_", ""), primitive, 0)]
            materials = [material(proxy_name, color)]
            if proxy_name == "underwear":
                entries.append(("UnderwearWaistband", underwear_waistband(proxy_mesh, fitted), 0))
            if proxy_name in {"short_hair", "close_crop", "side_swept"}:
                hair_cap = offset_primitive(
                    prepare_primitive(base_mesh, body_vertices, scalp_faces),
                    0.00035,
                )
                entries.append(("HairCap", hair_cap, 1))
                materials.append(material("hair_cap", color, 0.86))
            write_glb(
                body_dir / f"{proxy_name}.glb",
                entries,
                materials,
            )
            if proxy_name in shoe_names:
                tucked_faces = [
                    face
                    for face in faces
                    if all(fitted[corner[0]][1] <= -6.9 for corner in face)
                ]
                tucked = prepare_primitive(proxy_mesh, fitted, tucked_faces)
                write_glb(
                    body_dir / f"{proxy_name}_tucked.glb",
                    [("TravelShoes", tucked, 0)],
                    [material(proxy_name, color)],
                )

        for accessory_name in (
            "pendant",
            "scarf",
            "belt_vial",
            "glasses_round",
            "glasses_angular",
        ):
            art_entries = art_master_assets.get(accessory_name, [])
            if not art_entries:
                continue
            entries = [
                (
                    entry["name"],
                    art_master_primitive(entry, body_name, accessory_name),
                    0,
                )
                for entry in art_entries
            ]
            write_glb(
                body_dir / f"{accessory_name}.glb",
                entries,
                [material(accessory_name, "#a87834", 0.42, 0.52)],
            )

    print(f"Built Hiloan 3D assets in {OUTPUT_ROOT}")


if __name__ == "__main__":
    build()
