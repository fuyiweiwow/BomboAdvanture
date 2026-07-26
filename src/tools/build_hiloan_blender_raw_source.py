#!/usr/bin/env python3
"""Pack the untouched quad-based MakeHuman sources into a Blender work file."""

from __future__ import annotations

import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_ROOT = Path(__file__).resolve().parent
SOURCE_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/source"
BLENDER_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/blender"
OUTPUT_PATH = BLENDER_ROOT / "hiloan_character_creator_raw_source.blend"
PREVIEW_PATH = BLENDER_ROOT / "hiloan_character_creator_raw_source_preview.png"

sys.path.insert(0, str(TOOLS_ROOT))
import build_hiloan_3d_assets as assets  # noqa: E402


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def child_collection(parent: bpy.types.Collection, name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    parent.children.link(collection)
    return collection


def hex_color(value: str) -> tuple[float, float, float, float]:
    value = value.removeprefix("#")
    return tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def material(name: str, color: str, roughness: float) -> bpy.types.Material:
    value = bpy.data.materials.new(name)
    value.diffuse_color = hex_color(color)
    value.use_nodes = True
    principled = value.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = hex_color(color)
    principled.inputs["Roughness"].default_value = roughness
    return value


def blender_position(source: assets.Vec3) -> tuple[float, float, float]:
    x, y, z = source
    return x * assets.SCALE, -z * assets.SCALE, y * assets.SCALE


def make_quad_object(
    name: str,
    source_mesh: assets.ObjMesh,
    faces: list[list[assets.FaceCorner]],
    collection: bpy.types.Collection,
    mesh_material: bpy.types.Material,
    source_vertices: list[assets.Vec3] | None = None,
) -> tuple[bpy.types.Object, dict[int, int]]:
    source_vertices = source_vertices or source_mesh.vertices
    used_indices = sorted({corner[0] for face in faces for corner in face})
    source_to_local = {source_index: index for index, source_index in enumerate(used_indices)}
    vertices = [blender_position(source_vertices[index]) for index in used_indices]
    polygons = [
        [source_to_local[corner[0]] for corner in face]
        for face in faces
    ]

    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, source_face in zip(mesh.polygons, faces):
        for loop_index, source_corner in zip(polygon.loop_indices, source_face):
            uv_index = source_corner[1]
            uv_layer.data[loop_index].uv = (
                source_mesh.uvs[uv_index]
                if uv_index is not None
                else (0.0, 0.0)
            )

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.data.materials.append(mesh_material)
    obj["source_edit_mesh"] = True
    obj["source_topology"] = "untouched_quads"
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj, source_to_local


def hide_collection(collection: bpy.types.Collection) -> None:
    for obj in collection.objects:
        obj.hide_set(True)
        obj.hide_render = True
    for child in collection.children:
        hide_collection(child)


def add_proxy(
    root: bpy.types.Collection,
    category: str,
    asset_name: str,
    mesh_material: bpy.types.Material,
    body_vertices: list[assets.Vec3],
) -> bpy.types.Object:
    category_collection = bpy.data.collections.get(category) or child_collection(root, category)
    option_collection = child_collection(category_collection, asset_name.upper())
    source_mesh = assets.parse_obj(SOURCE_ROOT / f"{asset_name}.obj")
    fitted_vertices, _ = assets.fit_proxy(
        body_vertices,
        SOURCE_ROOT / f"{asset_name}.mhclo",
    )
    faces = [face for group_faces in source_mesh.groups.values() for face in group_faces]
    obj, _ = make_quad_object(
        f"RAW_{asset_name.title().replace('_', '')}",
        source_mesh,
        faces,
        option_collection,
        mesh_material,
        fitted_vertices,
    )
    obj["source_obj"] = f"assets/creator/hiloan_3d/source/{asset_name}.obj"
    hide_collection(option_collection)
    return obj


def aim_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_studio(root: bpy.types.Collection) -> None:
    studio = child_collection(root, "STUDIO_REFERENCE_NOT_FOR_EXPORT")
    bpy.ops.object.light_add(type="AREA", location=(-2.0, -2.4, 3.0))
    key = bpy.context.object
    key.name = "RAW_REF_Key"
    key.data.energy = 300.0
    key.data.shape = "DISK"
    key.data.size = 2.2
    aim_at(key, (0.0, 0.0, 0.1))
    for owner in list(key.users_collection):
        owner.objects.unlink(key)
    studio.objects.link(key)

    bpy.ops.object.light_add(type="AREA", location=(2.0, 0.8, 2.2))
    rim = bpy.context.object
    rim.name = "RAW_REF_Rim"
    rim.data.energy = 130.0
    rim.data.size = 1.7
    aim_at(rim, (0.0, 0.0, 0.3))
    for owner in list(rim.users_collection):
        owner.objects.unlink(rim)
    studio.objects.link(rim)

    bpy.ops.object.camera_add(location=(0.0, -4.0, 0.1))
    camera = bpy.context.object
    camera.name = "RAW_REF_Camera"
    camera.data.lens = 58.0
    aim_at(camera, (0.0, 0.0, 0.08))
    for owner in list(camera.users_collection):
        owner.objects.unlink(camera)
    studio.objects.link(camera)
    bpy.context.scene.camera = camera


def add_guide() -> None:
    guide = bpy.data.texts.new("README_RAW_SOURCE")
    guide.write(
        """HILOAN RAW QUAD SOURCE

This file contains the untouched MakeHuman source topology fitted to the
current standard masculine body.

1. Every imported source asset uses its original quad faces.
2. Standard body target deltas and original MakeHuman fitting rules are applied
   to vertex positions; topology is not changed.
3. RAW_BaseBody includes the integrated face and lips.
4. Use the LIPS_EDIT_REGION vertex group to select the mouth edit area.
5. Optional hair, brows, underwear, outfits, and shoes are hidden by default.
6. These assets are fitted to STANDARD; LEAN will be derived after refinement.
7. Do not triangulate, remesh, rename objects, or apply transforms.
8. Save your adjusted file as hiloan_user_reference.blend.

Use proportional editing, Sculpt Grab/Smooth, or loop selection. The adjusted
shape will be transferred back to the fitted game assets separately.
"""
    )


def main() -> None:
    BLENDER_ROOT.mkdir(parents=True, exist_ok=True)
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.world.color = (0.018, 0.022, 0.028)

    root = bpy.data.collections.new("HILOAN_RAW_QUAD_SOURCE")
    scene.collection.children.link(root)
    body_collection = child_collection(root, "RAW_BODY")
    helpers_collection = child_collection(root, "RAW_FACE_HELPERS")

    skin = material("RAW_MAT_Skin", "#b97d5f", 0.78)
    eyes = material("RAW_MAT_EyeWhite", "#e8e3da", 0.42)
    lashes = material("RAW_MAT_Lashes", "#241815", 0.90)
    hair = material("RAW_MAT_Hair", "#292321", 0.80)
    cloth = material("RAW_MAT_Cloth", "#343d42", 0.84)
    outfit = material("RAW_MAT_Outfit", "#30404a", 0.88)
    shoes = material("RAW_MAT_Shoes", "#332820", 0.86)

    base_mesh = assets.parse_obj(SOURCE_ROOT / "base.obj")
    face_harmony = assets.combine_targets(
        [
            (assets.target("chin-width-decr.target"), 0.12),
            (assets.target("chin-height-decr.target"), 0.075),
            (assets.target("head-scale-vert-decr.target"), 0.055),
            (assets.target("forehead-scale-vert-decr.target"), 0.10),
            (assets.target("nose-scale-horiz-decr.target"), 0.07),
            (assets.target("nose-scale-vert-decr.target"), 0.055),
            (assets.target("nose-volume-decr.target"), 0.04),
            (assets.target("mouth-scale-horiz-incr.target"), 0.055),
            (assets.target("l-eye-scale-incr.target"), 0.045),
            (assets.target("r-eye-scale-incr.target"), 0.045),
        ]
    )
    standard_target = assets.combine_targets(
        [
            (assets.target("caucasian-male-young.target"), 1.0),
            (face_harmony, 1.0),
            (assets.muscle_profile(1.0), 1.0),
        ]
    )
    body_vertices = assets.apply_target(base_mesh.vertices, standard_target)
    body_faces = base_mesh.groups["body"]
    body, source_to_local = make_quad_object(
        "RAW_BaseBody",
        base_mesh,
        body_faces,
        body_collection,
        skin,
        body_vertices,
    )
    lip_vertices = set().union(
        assets.target("mouth-upperlip-volume-incr.target").keys(),
        assets.target("mouth-lowerlip-volume-incr.target").keys(),
    )
    lip_local = [source_to_local[index] for index in lip_vertices if index in source_to_local]
    lip_group = body.vertex_groups.new(name="LIPS_EDIT_REGION")
    lip_group.add(lip_local, 1.0, "REPLACE")

    eye_faces = [
        *base_mesh.groups.get("helper-l-eye", []),
        *base_mesh.groups.get("helper-r-eye", []),
    ]
    make_quad_object(
        "RAW_EyeWhites",
        base_mesh,
        eye_faces,
        helpers_collection,
        eyes,
        body_vertices,
    )
    for suffix, label in (("eyelashes-2", "UpperEyelashes"), ("eyelashes-1", "LowerEyelashes")):
        lash_faces = [
            face
            for group_name, group_faces in base_mesh.groups.items()
            if group_name.endswith(suffix)
            for face in group_faces
        ]
        make_quad_object(
            f"RAW_{label}",
            base_mesh,
            lash_faces,
            helpers_collection,
            lashes,
            body_vertices,
        )

    for asset_name in ("short_hair", "close_crop", "side_swept"):
        add_proxy(root, "RAW_HAIR", asset_name, hair, body_vertices)
    for asset_name in ("eyebrow_natural", "eyebrow_arched", "eyebrow_full"):
        add_proxy(root, "RAW_EYEBROWS", asset_name, hair, body_vertices)
    underwear = add_proxy(root, "RAW_UNDERWEAR", "underwear", cloth, body_vertices)
    underwear.hide_set(False)
    underwear.hide_render = False
    for asset_name in ("travel_suit", "field_suit", "formal_suit"):
        add_proxy(root, "RAW_OUTFITS", asset_name, outfit, body_vertices)
    for asset_name in ("travel_shoes", "low_shoes", "travel_boots"):
        add_proxy(root, "RAW_SHOES", asset_name, shoes, body_vertices)

    add_studio(root)
    add_guide()
    scene["project"] = "Hiloan Raw Quad Source"
    scene["runtime_export_ready"] = False
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_PATH))
    bpy.ops.render.render(write_still=True)

    non_quads = [
        (obj.name, len(polygon.vertices))
        for obj in bpy.data.objects
        if obj.type == "MESH" and obj.get("source_edit_mesh", False)
        for polygon in obj.data.polygons
        if len(polygon.vertices) != 4
    ]
    print(f"BLENDER_RAW_SOURCE={OUTPUT_PATH}")
    print(f"BLENDER_RAW_PREVIEW={PREVIEW_PATH}")
    print(f"RAW_NON_QUAD_FACES={len(non_quads)}")


if __name__ == "__main__":
    sys.exit(main())
