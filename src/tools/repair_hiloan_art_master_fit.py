#!/usr/bin/env python3
"""Repair garment clearance in the user's current Hiloan Blender art master."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_ROOT = PROJECT_ROOT / "src/tools"
BLENDER_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/blender"
MASTER_PATH = BLENDER_ROOT / "hiloan_character_creator_art_master.blend"
REFERENCE_PATH = BLENDER_ROOT / "hiloan_user_reference.blend"
BACKUP_PATH = BLENDER_ROOT / "hiloan_character_creator_art_master_before_fit_repair.blend"
CHECK_ROOT = BLENDER_ROOT / "fit_repair_previews"

GARMENT_NAMES = (
    "FIT_CoastalTunic",
    "FIT_CoastalPants",
    "FIT_FrostfieldUniform",
    "FIT_AcademyRobe",
)


def ensure_frostfield_underlayer() -> tuple[bpy.types.Object, bool]:
    existing = bpy.data.objects.get("FIT_FrostfieldUnderlayer")
    fit_version = int(bpy.context.scene.get("frostfield_underlayer_fit_version", 0))
    if existing is not None and fit_version >= 5:
        return existing, False
    if existing is not None:
        old_mesh = existing.data
        bpy.data.objects.remove(existing, do_unlink=True)
        if old_mesh.users == 0:
            bpy.data.meshes.remove(old_mesh)

    sys.path.insert(0, str(TOOLS_ROOT))
    import build_hiloan_3d_assets as assets
    import build_hiloan_art_master as art_master

    body = bpy.data.objects["RAW_BaseBody"]
    body_vertices = [
        (
            vertex.co.x / assets.SCALE,
            vertex.co.z / assets.SCALE,
            -vertex.co.y / assets.SCALE,
        )
        for vertex in body.data.vertices
    ]
    folder = (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/matcreator_mc-skinsuit_2022"
    )
    target = bpy.data.collections.get("FROSTFIELD_WORKER")
    if target is None:
        raise RuntimeError("FROSTFIELD_WORKER collection is missing")
    uniform = bpy.data.objects["FIT_FrostfieldUniform"]
    value = art_master.material(
        "ART_MAT_FrostfieldUnderlayer",
        "#283136",
        0.94,
        cloth=True,
    )
    underlayer = art_master.add_fitted_asset(
        "FIT_FrostfieldUnderlayer",
        folder,
        "MC-SkinSuit_2022.obj",
        "matcreator_mc-skinsuit_2022.mhclo",
        body_vertices,
        target,
        value,
        0.1,
    )
    underlayer.hide_set(uniform.hide_get())
    underlayer.hide_render = uniform.hide_render
    underlayer["fit_repair"] = (
        "Continuous cloth layer fitted between underwear and Frostfield armor"
    )
    return underlayer, True


def wrap_underwear_front(
    garment: bpy.types.Object,
    underwear: bpy.types.Object,
    clearance: float = 0.005,
) -> tuple[int, float]:
    underwear_points = [
        underwear.matrix_world @ vertex.co for vertex in underwear.data.vertices
    ]
    inverse = garment.matrix_world.inverted()
    moved = 0
    max_move = 0.0
    for vertex in garment.data.vertices:
        world = garment.matrix_world @ vertex.co
        if not (
            -0.095 <= world.z <= 0.215
            and abs(world.x) <= 0.205
            and world.y <= -0.060
        ):
            continue
        candidates = [
            point
            for point in underwear_points
            if abs(point.x - world.x) <= 0.032
            and abs(point.z - world.z) <= 0.032
        ]
        if not candidates:
            candidates = sorted(
                underwear_points,
                key=lambda point: (
                    (point.x - world.x) ** 2 + (point.z - world.z) ** 2
                ),
            )[:8]
        target = world.copy()
        desired_y = min(point.y for point in candidates) - clearance
        target.y = max(world.y - 0.030, min(world.y, desired_y))
        amount = (target - world).length
        if amount <= 0.000001:
            continue
        vertex.co = inverse @ target
        moved += 1
        max_move = max(max_move, amount)
    garment.data.update()
    garment["fit_repair"] = (
        "Continuous inner suit with bounded front-crotch underwear clearance"
    )
    return moved, max_move


def inflate_mesh(obj: bpy.types.Object, amount: float) -> tuple[int, float]:
    obj.data.update()
    moved = 0
    for vertex in obj.data.vertices:
        if vertex.normal.length_squared <= 0.0:
            continue
        vertex.co += vertex.normal.normalized() * amount
        moved += 1
    obj.data.update()
    return moved, amount


def harmonize_preview_materials() -> None:
    sys.path.insert(0, str(TOOLS_ROOT))
    import build_hiloan_art_master as art_master

    specs = {
        "FIT_FrostfieldUnderlayer": (
            "ART_MAT_FrostfieldUnderlayer",
            "#252d31",
            0.94,
            0.0,
            True,
        ),
        "FIT_FrostfieldUniform": (
            "ART_MAT_FrostfieldArmor",
            "#586168",
            0.68,
            0.12,
            False,
        ),
        "FIT_TravelShoes": (
            "ART_MAT_TravelBootLeather",
            "#3b3029",
            0.72,
            0.0,
            False,
        ),
        "FIT_LowShoes": (
            "ART_MAT_LowShoeLeather",
            "#322b28",
            0.70,
            0.0,
            False,
        ),
        "FIT_TravelBoots": (
            "ART_MAT_FrostBootLeather",
            "#41342b",
            0.76,
            0.0,
            False,
        ),
    }
    for object_name, spec in specs.items():
        obj = bpy.data.objects.get(object_name)
        if obj is None:
            continue
        name, color, roughness, metallic, cloth = spec
        art_master.apply_material(
            obj,
            art_master.material(
                name,
                color,
                roughness,
                metallic,
                cloth,
            ),
        )


def world_bvh(obj: bpy.types.Object) -> BVHTree:
    vertices = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    polygons = [list(polygon.vertices) for polygon in obj.data.polygons]
    return BVHTree.FromPolygons(vertices, polygons, all_triangles=False)


def restore_underwear() -> tuple[int, float]:
    current = bpy.data.objects["RAW_Underwear"]
    with bpy.data.libraries.load(str(REFERENCE_PATH), link=False) as (_, target):
        target.objects = ["RAW_Underwear"]
    reference = target.objects[0]
    if reference is None or len(reference.data.vertices) != len(current.data.vertices):
        raise RuntimeError("Reference underwear topology does not match the art master")

    deltas = [
        (current.data.vertices[index].co - reference.data.vertices[index].co).length
        for index in range(len(current.data.vertices))
    ]
    changed = sum(delta > 0.000001 for delta in deltas)
    max_delta = max(deltas, default=0.0)
    materials = list(current.data.materials)
    old_mesh = current.data
    restored_mesh = reference.data.copy()
    restored_mesh.name = "RAW_Underwear_Mesh"
    restored_mesh.materials.clear()
    for value in materials:
        restored_mesh.materials.append(value)
    current.data = restored_mesh
    bpy.data.objects.remove(reference, do_unlink=True)
    if old_mesh.users == 0:
        bpy.data.meshes.remove(old_mesh)
    current["fit_repair"] = "Restored from the untouched fitted boxer-brief reference"
    return changed, max_delta


def push_outside_surface(
    garment: bpy.types.Object,
    surface: bpy.types.Object,
    distance_limit: float,
    clearance: float,
    z_range: tuple[float, float] | None = None,
) -> tuple[int, float]:
    bvh = world_bvh(surface)
    inverse = garment.matrix_world.inverted()
    moved = 0
    max_move = 0.0
    for vertex in garment.data.vertices:
        world = garment.matrix_world @ vertex.co
        if z_range is not None and not z_range[0] <= world.z <= z_range[1]:
            continue
        nearest = bvh.find_nearest(world)
        if nearest is None:
            continue
        location, normal, _, distance = nearest
        if distance > distance_limit:
            continue
        signed_distance = (world - location).dot(normal)
        if signed_distance >= clearance:
            continue
        amount = min(clearance - signed_distance, 0.014)
        vertex.co = inverse @ (world + normal * amount)
        moved += 1
        max_move = max(max_move, amount)
    garment.data.update()
    return moved, max_move


def repair_garments() -> list[str]:
    body = bpy.data.objects["RAW_BaseBody"]
    underwear = bpy.data.objects["RAW_Underwear"]
    report: list[str] = []
    for name in GARMENT_NAMES:
        garment = bpy.data.objects.get(name)
        if garment is None:
            report.append(f"{name}: missing")
            continue
        body_count, body_move = push_outside_surface(
            garment,
            body,
            distance_limit=0.018,
            clearance=0.005,
        )
        underwear_count, underwear_move = push_outside_surface(
            garment,
            underwear,
            distance_limit=0.026,
            clearance=0.006,
            z_range=(-0.095, 0.225),
        )
        garment["fit_repair"] = (
            "Close penetrations pushed outside body and restored underwear; "
            "draped regions preserved"
        )
        report.append(
            f"{name}: body={body_count}/{body_move:.5f} "
            f"underwear={underwear_count}/{underwear_move:.5f}"
        )
    return report


def smoothstep(first: float, second: float, value: float) -> float:
    normalized = max(0.0, min(1.0, (value - first) / (second - first)))
    return normalized * normalized * (3.0 - 2.0 * normalized)


def narrow_travel_shoe_shafts() -> tuple[int, float]:
    shoes = bpy.data.objects["FIT_TravelShoes"]
    inverse = shoes.matrix_world.inverted()
    changed = 0
    max_move = 0.0
    for vertex in shoes.data.vertices:
        world = shoes.matrix_world @ vertex.co
        weight = smoothstep(-0.70, -0.56, world.z)
        if weight <= 0.0:
            continue
        center_x = -0.125 if world.x < 0.0 else 0.125
        target = Vector(
            (
                center_x + (world.x - center_x) * (1.0 - 0.11 * weight),
                (world.y - 0.002) * (1.0 - 0.18 * weight) + 0.002,
                world.z,
            )
        )
        amount = (target - world).length
        vertex.co = inverse @ target
        changed += 1
        max_move = max(max_move, amount)
    shoes.data.update()
    shoes["fit_repair"] = "Shaft narrowed gradually; foot enclosure left unchanged"
    return changed, max_move


def render_checks() -> None:
    sys.path.insert(0, str(TOOLS_ROOT))
    import build_hiloan_art_master as art_master

    art_master.PREVIEW_ROOT = CHECK_ROOT
    CHECK_ROOT.mkdir(parents=True, exist_ok=True)
    body = {
        "RAW_BaseBody",
        "RAW_EyeWhites",
        "RAW_UpperEyelashes",
        "RAW_LowerEyelashes",
    }
    art_master.render_preview(
        "01_underwear_front",
        body | {"RAW_Underwear", "ART_UnderwearWaistband"},
    )
    art_master.render_preview(
        "02_underwear_side",
        body | {"RAW_Underwear", "ART_UnderwearWaistband"},
        0.72,
    )
    art_master.render_preview(
        "03_travel_shoes_front",
        body | {"FIT_TravelShoes"},
    )
    art_master.render_preview(
        "04_travel_shoes_side",
        body | {"FIT_TravelShoes"},
        0.72,
    )
    art_master.render_preview(
        "05_coastal_layers",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_CoastalTunic",
            "FIT_CoastalPants",
            "FIT_TravelShoes",
        },
    )
    art_master.render_preview(
        "06_frostfield_layers",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_FrostfieldUnderlayer",
            "FIT_FrostfieldUniform",
            "FIT_TravelBoots",
        },
    )
    art_master.render_preview(
        "07_academy_layers",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_AcademyRobe",
            "FIT_LowShoes",
        },
    )
    art_master.render_preview(
        "08_coastal_layers_side",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_CoastalTunic",
            "FIT_CoastalPants",
            "FIT_TravelShoes",
        },
        0.72,
    )
    art_master.render_preview(
        "09_frostfield_layers_side",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_FrostfieldUnderlayer",
            "FIT_FrostfieldUniform",
            "FIT_TravelBoots",
        },
        0.72,
    )
    art_master.render_preview(
        "10_academy_layers_side",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_AcademyRobe",
            "FIT_LowShoes",
        },
        0.72,
    )
    art_master.render_preview(
        "11_frostfield_underlayer_only",
        body
        | {
            "RAW_Underwear",
            "ART_UnderwearWaistband",
            "FIT_FrostfieldUnderlayer",
        },
    )


def main() -> None:
    if Path(bpy.data.filepath).resolve() != MASTER_PATH.resolve():
        raise RuntimeError(f"Open the current art master before repair: {MASTER_PATH}")
    if not BACKUP_PATH.exists():
        shutil.copy2(MASTER_PATH, BACKUP_PATH)

    already_repaired = bpy.context.scene.get("last_fit_repair") == "2026-07-27"
    waistband = bpy.data.objects["ART_UnderwearWaistband"]
    waistband_transform = waistband.matrix_world.copy()
    if already_repaired:
        underwear_changed, underwear_max = 0, 0.0
        garment_report = ["Existing garment repair retained"]
        shoe_changed, shoe_max = 0, 0.0
    else:
        underwear_changed, underwear_max = restore_underwear()
        garment_report = repair_garments()
        shoe_changed, shoe_max = narrow_travel_shoe_shafts()
    underlayer, underlayer_added = ensure_frostfield_underlayer()
    if underlayer_added:
        underlayer_inflate_count, underlayer_inflate_move = inflate_mesh(
            underlayer,
            0.005,
        )
        underlayer_underwear_count, underlayer_underwear_move = wrap_underwear_front(
            underlayer,
            bpy.data.objects["RAW_Underwear"],
        )
    else:
        underlayer_inflate_count, underlayer_inflate_move = 0, 0.0
        underlayer_underwear_count, underlayer_underwear_move = 0, 0.0
    if int(bpy.context.scene.get("frostfield_outer_fit_version", 0)) < 1:
        uniform_inflate_count, uniform_inflate_move = inflate_mesh(
            bpy.data.objects["FIT_FrostfieldUniform"],
            0.006,
        )
        bpy.context.scene["frostfield_outer_fit_version"] = 1
    else:
        uniform_inflate_count, uniform_inflate_move = 0, 0.0
    harmonize_preview_materials()
    if not waistband.matrix_world == waistband_transform:
        raise RuntimeError("Waistband transform changed unexpectedly")

    bpy.context.scene["last_fit_repair"] = "2026-07-27"
    bpy.context.scene["frostfield_underlayer_fit_version"] = 5
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTER_PATH))
    render_checks()
    print(
        f"HILOAN_UNDERWEAR_RESTORED={underwear_changed} "
        f"max={underwear_max:.5f}"
    )
    for line in garment_report:
        print(f"HILOAN_GARMENT_REPAIR={line}")
    print(f"HILOAN_TRAVEL_SHOE_SHAFT={shoe_changed} max={shoe_max:.5f}")
    print(
        f"HILOAN_FROSTFIELD_UNDERLAYER=added:{underlayer_added} "
        f"inflate:{underlayer_inflate_count}/{underlayer_inflate_move:.5f} "
        f"underwear:{underlayer_underwear_count}/{underlayer_underwear_move:.5f}"
    )
    print(
        f"HILOAN_FROSTFIELD_OUTER=inflate:"
        f"{uniform_inflate_count}/{uniform_inflate_move:.5f}"
    )
    print(f"HILOAN_FIT_REPAIR_BACKUP={BACKUP_PATH}")
    print(f"HILOAN_FIT_REPAIR_PREVIEWS={CHECK_ROOT}")


if __name__ == "__main__":
    sys.exit(main())
