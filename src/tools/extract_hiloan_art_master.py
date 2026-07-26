#!/usr/bin/env python3
"""Extract approved Blender meshes for the Hiloan runtime asset builder."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_PATH = PROJECT_ROOT / "assets/creator/hiloan_3d/user_edits/art_master_meshes.json"

ASSETS = {
    "short_hair": ("RAW_ShortHair",),
    "close_crop": ("RAW_CloseCrop",),
    "side_swept": ("RAW_SideSwept",),
    "underwear": ("RAW_Underwear", "ART_UnderwearWaistband"),
    "travel_suit": (
        "FIT_CoastalTunic",
        "FIT_CoastalPants",
    ),
    "field_suit": (
        "FIT_FrostfieldUnderlayer",
        "FIT_FrostfieldUniform",
    ),
    "formal_suit": (
        "FIT_AcademyRobe",
    ),
    "travel_shoes": ("FIT_TravelShoes",),
    "low_shoes": ("FIT_LowShoes",),
    "travel_boots": ("FIT_TravelBoots",),
    "glasses_round": ("FIT_GlassesRound",),
    "glasses_angular": ("FIT_GlassesAngular",),
    "pendant": ("ART_BiomePendant", "ART_BiomePendantChain"),
    "scarf": ("ART_CoastalNeckWrap", "ART_CoastalScarfTail"),
    "belt_vial": ("ART_BiomeVial", "ART_BiomeVialHarness"),
}


def game_position(value) -> list[float]:
    return [round(value.x, 7), round(value.z, 7), round(-value.y, 7)]


def extract_object(obj: bpy.types.Object) -> dict:
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh(preserve_all_data_layers=True)
    owns_mesh = mesh is not None
    if mesh is None:
        mesh = obj.data
    uv_layer = mesh.uv_layers.active
    corner_map: dict[tuple[int, float, float], int] = {}
    positions: list[list[float]] = []
    uvs: list[list[float]] = []
    indices: list[int] = []

    for polygon in mesh.polygons:
        corners: list[int] = []
        for loop_index in polygon.loop_indices:
            loop = mesh.loops[loop_index]
            uv = (
                uv_layer.data[loop_index].uv
                if uv_layer is not None and loop_index < len(uv_layer.data)
                else (0.0, 0.0)
            )
            key = (loop.vertex_index, round(float(uv[0]), 7), round(float(uv[1]), 7))
            if key not in corner_map:
                corner_map[key] = len(positions)
                world_position = evaluated.matrix_world @ mesh.vertices[loop.vertex_index].co
                positions.append(game_position(world_position))
                uvs.append([round(float(uv[0]), 7), round(float(uv[1]), 7)])
            corners.append(corner_map[key])
        for index in range(1, len(corners) - 1):
            indices.extend((corners[0], corners[index], corners[index + 1]))

    result = {
        "name": (
            obj.name.removeprefix("RAW_")
            .removeprefix("ART_")
            .removeprefix("FIT_")
        ),
        "positions": positions,
        "uvs": uvs,
        "indices": indices,
    }
    if owns_mesh:
        evaluated.to_mesh_clear()
    return result


def main() -> None:
    assets: dict[str, list[dict]] = {}
    missing: list[str] = []
    for asset_name, object_names in ASSETS.items():
        entries: list[dict] = []
        for object_name in object_names:
            obj = bpy.data.objects.get(object_name)
            if obj is None:
                if object_name.startswith("RAW_"):
                    missing.append(object_name)
                continue
            if obj.type == "MESH" and obj.data.polygons:
                entries.append(extract_object(obj))
        if entries:
            assets[asset_name] = entries

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(
            {
                "source_blend": bpy.data.filepath,
                "coordinate_system": "Godot glTF meters",
                "assets": assets,
            },
            separators=(",", ":"),
        )
    )
    print(f"HILOAN_ART_MASTER_JSON={OUTPUT_PATH}")
    print(f"HILOAN_ART_MASTER_ASSETS={','.join(sorted(assets))}")
    if missing:
        print(f"HILOAN_ART_MASTER_MISSING={','.join(missing)}")


if __name__ == "__main__":
    sys.exit(main())
