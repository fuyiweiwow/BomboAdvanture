#!/usr/bin/env python3
"""Assemble the generated Hiloan creator assets into an editable Blender file."""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
MESH_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/meshes"
TEXTURE_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/textures"
OUTPUT_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/blender"
BLEND_PATH = OUTPUT_ROOT / "hiloan_character_creator_fitting_v2.blend"
PREVIEW_PATH = OUTPUT_ROOT / "hiloan_character_creator_fitting_v2_preview.png"
FACE_PREVIEW_PATH = OUTPUT_ROOT / "hiloan_character_creator_fitting_v2_face.png"
FACE_SIDE_PREVIEW_PATH = OUTPUT_ROOT / "hiloan_character_creator_fitting_v2_face_side.png"

OPTION_ASSETS = {
    "HAIR": ("short_hair", "close_crop", "side_swept"),
    "EYEBROWS": ("eyebrow_natural", "eyebrow_arched", "eyebrow_full"),
    "OUTFITS": ("travel_suit", "field_suit", "formal_suit"),
    "SHOES": ("travel_shoes", "low_shoes", "travel_boots"),
    "EXTRAS": ("pendant", "scarf", "belt_vial"),
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def child_collection(parent: bpy.types.Collection, name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    parent.children.link(collection)
    return collection


def move_to_collection(objects: list[bpy.types.Object], collection: bpy.types.Collection) -> None:
    for obj in objects:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        collection.objects.link(obj)


def import_glb(
    path: Path,
    collection: bpy.types.Collection,
    prefix: str,
    role: str,
    body_type: str,
) -> list[bpy.types.Object]:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [obj for obj in bpy.data.objects if obj not in before]
    move_to_collection(objects, collection)
    for obj in objects:
        obj.name = f"{prefix}_{obj.name}"
        obj["asset_role"] = role
        obj["body_type"] = body_type
        obj["source_glb"] = str(path.relative_to(PROJECT_ROOT))
    return objects


def mesh_objects(objects: list[bpy.types.Object]) -> list[bpy.types.Object]:
    return [obj for obj in objects if obj.type == "MESH"]


def hex_color(value: str) -> tuple[float, float, float, float]:
    value = value.removeprefix("#")
    return tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def simple_material(name: str, color: str, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = hex_color(color)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = hex_color(color)
    principled.inputs["Roughness"].default_value = roughness
    return material


def mapped_tint_material(
    name: str,
    color: str,
    detail_file: str,
    roughness: float,
    normal_file: str = "",
    roughness_file: str = "",
    normal_strength: float = 0.2,
    use_alpha: bool = False,
    alpha_gain: float = 1.0,
) -> bpy.types.Material:
    material = simple_material(name, color, roughness)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")

    detail = nodes.new("ShaderNodeTexImage")
    detail.name = f"{name} Detail"
    detail.image = bpy.data.images.load(str(TEXTURE_ROOT / detail_file), check_existing=True)
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.name = f"{name} Tint"
    multiply.blend_type = "MULTIPLY"
    multiply.inputs[0].default_value = 1.0
    multiply.inputs[1].default_value = hex_color(color)
    links.new(detail.outputs["Color"], multiply.inputs[2])
    links.new(multiply.outputs["Color"], principled.inputs["Base Color"])

    if normal_file:
        normal_image = nodes.new("ShaderNodeTexImage")
        normal_image.name = f"{name} Normal"
        normal_image.image = bpy.data.images.load(str(TEXTURE_ROOT / normal_file), check_existing=True)
        normal_image.image.colorspace_settings.name = "Non-Color"
        normal = nodes.new("ShaderNodeNormalMap")
        normal.name = f"{name} Normal Map"
        normal.inputs["Strength"].default_value = normal_strength
        links.new(normal_image.outputs["Color"], normal.inputs["Color"])
        links.new(normal.outputs["Normal"], principled.inputs["Normal"])

    if roughness_file:
        roughness_image = nodes.new("ShaderNodeTexImage")
        roughness_image.name = f"{name} Roughness"
        roughness_image.image = bpy.data.images.load(
            str(TEXTURE_ROOT / roughness_file),
            check_existing=True,
        )
        roughness_image.image.colorspace_settings.name = "Non-Color"
        links.new(roughness_image.outputs["Color"], principled.inputs["Roughness"])

    if use_alpha:
        alpha = nodes.new("ShaderNodeMath")
        alpha.name = f"{name} Alpha Density"
        alpha.operation = "MULTIPLY"
        alpha.inputs[1].default_value = alpha_gain
        alpha.use_clamp = True
        links.new(detail.outputs["Alpha"], alpha.inputs[0])
        links.new(alpha.outputs["Value"], principled.inputs["Alpha"])
        if hasattr(material, "surface_render_method"):
            material.surface_render_method = "DITHERED"
        elif hasattr(material, "blend_method"):
            material.blend_method = "HASHED"
    return material


def skin_material() -> bpy.types.Material:
    material = mapped_tint_material(
        "MAT_Skin_Warm",
        "#b97d5f",
        "skin_detail.png",
        0.78,
        "skin_normal.png",
        "skin_roughness.png",
        0.18,
    )
    principled = material.node_tree.nodes.get("Principled BSDF")
    specular = principled.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.28
    return material


def lip_material() -> bpy.types.Material:
    material = mapped_tint_material(
        "MAT_Lips_Natural",
        "#965d58",
        "lip_detail.png",
        0.44,
        "lip_normal.png",
        "lip_roughness.png",
        0.24,
    )
    principled = material.node_tree.nodes.get("Principled BSDF")
    specular = principled.inputs.get("Specular IOR Level")
    if specular is not None:
        specular.default_value = 0.42
    coat = principled.inputs.get("Coat Weight")
    if coat is not None:
        coat.default_value = 0.08
    return material


def eyebrow_material(style: str) -> bpy.types.Material:
    return mapped_tint_material(
        f"MAT_{style}",
        "#241815",
        f"{style}_detail.png",
        0.88,
        use_alpha=True,
        alpha_gain=1.8,
    )


def eyelash_material() -> bpy.types.Material:
    return mapped_tint_material(
        "MAT_Eyelashes",
        "#241815",
        "eyelash_detail.png",
        0.92,
        use_alpha=True,
        alpha_gain=1.8,
    )


def hair_material(style: str) -> bpy.types.Material:
    texture_name = {
        "short_hair": "hair_short_detail.png",
        "close_crop": "hair_crop_detail.png",
        "side_swept": "hair_swept_detail.png",
    }[style]
    return mapped_tint_material(
        f"MAT_{style}",
        "#292321",
        texture_name,
        0.78,
        use_alpha=True,
        alpha_gain=1.25,
    )


def hair_cap_material() -> bpy.types.Material:
    return simple_material("MAT_Hair_Cap", "#403a38", 0.84)


def cloth_material() -> bpy.types.Material:
    material = simple_material("MAT_Underwear_Charcoal_Knit", "#343d42", 0.84)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    sheen = principled.inputs.get("Sheen Weight")
    if sheen is not None:
        sheen.default_value = 0.12

    detail = nodes.get("Underwear Detail") or nodes.new("ShaderNodeTexImage")
    detail.name = "Underwear Detail"
    detail.label = "Subtle knit detail"
    detail.image = bpy.data.images.load(str(TEXTURE_ROOT / "underwear_detail.png"), check_existing=True)
    multiply = nodes.get("Underwear Tint") or nodes.new("ShaderNodeMixRGB")
    multiply.name = "Underwear Tint"
    multiply.blend_type = "MULTIPLY"
    multiply.inputs[0].default_value = 1.0
    multiply.inputs[1].default_value = hex_color("#343d42")
    links.new(detail.outputs["Color"], multiply.inputs[2])
    links.new(multiply.outputs["Color"], principled.inputs["Base Color"])

    normal_image = nodes.get("Underwear Normal") or nodes.new("ShaderNodeTexImage")
    normal_image.name = "Underwear Normal"
    normal_image.image = bpy.data.images.load(str(TEXTURE_ROOT / "underwear_normal.png"), check_existing=True)
    normal_image.image.colorspace_settings.name = "Non-Color"
    normal = nodes.get("Underwear Normal Map") or nodes.new("ShaderNodeNormalMap")
    normal.name = "Underwear Normal Map"
    normal.inputs["Strength"].default_value = 0.28
    links.new(normal_image.outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], principled.inputs["Normal"])
    return material


def assign_material(objects: list[bpy.types.Object], material: bpy.types.Material) -> None:
    for obj in mesh_objects(objects):
        obj.data.materials.clear()
        obj.data.materials.append(material)


def assign_body_materials(objects: list[bpy.types.Object]) -> None:
    materials = {
        "body": bpy.data.materials["MAT_Skin_Warm"],
        "lips": bpy.data.materials["MAT_Lips_Natural"],
        "eyewhites": bpy.data.materials["MAT_Eye_White"],
        "eyelashes": bpy.data.materials["MAT_Eyelashes"],
    }
    for obj in mesh_objects(objects):
        lowered = obj.name.lower()
        for token, material in materials.items():
            if token in lowered:
                assign_material([obj], material)
                break


def set_default_shape_keys(objects: list[bpy.types.Object]) -> None:
    defaults = {"face_oval", "eyes_soft", "nose_straight", "mouth_neutral"}
    for obj in mesh_objects(objects):
        if obj.data.shape_keys is None:
            continue
        for key in obj.data.shape_keys.key_blocks:
            key.value = 1.0 if key.name in defaults else 0.0


def add_eye_parts(collection: bpy.types.Collection, body_type: str) -> None:
    iris_material = simple_material("MAT_Eye_Hazel", "#6b4931", 0.42)
    pupil_material = simple_material("MAT_Eye_Pupil", "#171519", 0.36)
    catchlight_material = simple_material("MAT_Eye_Catchlight", "#f6f2e9", 0.24)
    for side, x in (("L", -0.0293), ("R", 0.0293)):
        for name, radius, y, material in (
            ("Iris", 0.0058, -0.1464, iris_material),
            ("Pupil", 0.0023, -0.1471, pupil_material),
            ("Catchlight", 0.0010, -0.1478, catchlight_material),
        ):
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=24,
                ring_count=12,
                location=(x, y, 0.8207),
                scale=(radius, 0.0014, radius * 0.92),
            )
            obj = bpy.context.object
            obj.name = f"{body_type.upper()}_{name}_{side}"
            obj.data.materials.append(material)
            obj["asset_role"] = "eye_component"
            move_to_collection([obj], collection)


def hide_collection(collection: bpy.types.Collection) -> None:
    for obj in collection.objects:
        obj.hide_set(True)
        obj.hide_render = True
    for child in collection.children:
        hide_collection(child)


def build_body_variant(root: bpy.types.Collection, body_type: str, visible: bool) -> None:
    body_root = child_collection(root, body_type.upper())
    base_collection = child_collection(body_root, "BASE_BODY")
    fitting_collection = child_collection(body_root, "FITTING_GUIDES")
    underwear_collection = child_collection(body_root, "UNDERWEAR_BOXER")
    eyes_collection = child_collection(body_root, "EYES")

    body_objects = import_glb(
        MESH_ROOT / body_type / "body_plain.glb",
        base_collection,
        body_type.upper(),
        "base_body",
        body_type,
    )
    assign_body_materials(body_objects)
    set_default_shape_keys(body_objects)
    fitting_objects = import_glb(
        MESH_ROOT / body_type / "face_fit_surface.glb",
        fitting_collection,
        body_type.upper(),
        "face_fit_surface",
        body_type,
    )
    assign_material(fitting_objects, bpy.data.materials["MAT_Skin_Warm"])
    set_default_shape_keys(fitting_objects)
    fitting_mesh = next(iter(mesh_objects(fitting_objects)), None)
    if fitting_mesh is not None:
        fitting_mesh.display_type = "WIRE"
        fitting_mesh.hide_render = True
        fitting_mesh.hide_set(True)

    lips_mesh = next(
        (obj for obj in mesh_objects(body_objects) if "lips" in obj.name.lower()),
        None,
    )
    if lips_mesh is not None and fitting_mesh is not None:
        modifier = lips_mesh.modifiers.new(name="Lip_Surface_Fit", type="SHRINKWRAP")
        modifier.target = fitting_mesh
        modifier.wrap_method = "NEAREST_SURFACEPOINT"
        modifier.wrap_mode = "OUTSIDE"
        modifier.offset = 0.00025

    underwear_objects = import_glb(
        MESH_ROOT / body_type / "underwear.glb",
        underwear_collection,
        body_type.upper(),
        "underwear_boxer",
        body_type,
    )
    assign_material(underwear_objects, bpy.data.materials["MAT_Underwear_Charcoal_Knit"])
    add_eye_parts(eyes_collection, body_type)

    for category, assets in OPTION_ASSETS.items():
        category_collection = child_collection(body_root, category)
        for asset in assets:
            option_collection = child_collection(category_collection, asset.upper())
            objects = import_glb(
                MESH_ROOT / body_type / f"{asset}.glb",
                option_collection,
                body_type.upper(),
                category.lower(),
                body_type,
            )
            if category == "EYEBROWS":
                assign_material(objects, eyebrow_material(asset))
            elif category == "HAIR":
                for obj in mesh_objects(objects):
                    assign_material(
                        [obj],
                        hair_cap_material()
                        if "haircap" in obj.name.lower()
                        else hair_material(asset),
                    )
            if asset in ("eyebrow_natural", "short_hair") and visible:
                continue
            hide_collection(option_collection)

    if not visible:
        hide_collection(body_root)


def aim_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def build_studio(root: bpy.types.Collection) -> None:
    studio = child_collection(root, "STUDIO_REFERENCE_NOT_FOR_EXPORT")
    bpy.ops.mesh.primitive_plane_add(size=4.0, location=(0.0, 0.0, -0.845))
    floor = bpy.context.object
    floor.name = "REF_Floor"
    floor.data.materials.append(simple_material("MAT_Studio_Floor", "#30373b", 0.92))
    move_to_collection([floor], studio)

    bpy.ops.object.light_add(type="AREA", location=(-2.0, -2.4, 3.0))
    key = bpy.context.object
    key.name = "REF_Key_Light"
    key.data.energy = 260.0
    key.data.shape = "DISK"
    key.data.size = 2.1
    aim_at(key, (0.0, 0.0, 0.15))
    move_to_collection([key], studio)

    bpy.ops.object.light_add(type="AREA", location=(2.0, 0.8, 2.2))
    rim = bpy.context.object
    rim.name = "REF_Rim_Light"
    rim.data.energy = 120.0
    rim.data.color = (0.70, 0.84, 0.92)
    rim.data.size = 1.6
    aim_at(rim, (0.0, 0.0, 0.25))
    move_to_collection([rim], studio)

    bpy.ops.object.camera_add(location=(0.0, -4.0, 0.15))
    camera = bpy.context.object
    camera.name = "REF_Camera_Front"
    camera.data.lens = 58.0
    aim_at(camera, (0.0, 0.0, 0.08))
    bpy.context.scene.camera = camera
    move_to_collection([camera], studio)


def add_editing_guide() -> None:
    guide = bpy.data.texts.new("README_EDITING_GUIDE")
    guide.write(
        """HILOAN CHARACTER CREATOR DRAFT

1. STANDARD is visible by default; LEAN objects are hidden.
2. Expand a child collection and click the closed eye beside its mesh object
   to show HAIR, EYEBROWS, OUTFITS, SHOES, or EXTRAS.
3. BASE_BODY contains editable face Shape Keys.
4. STANDARD_Lips has a Lip_Surface_Fit Shrinkwrap modifier. Its hidden target
   is STANDARD_FaceFitSurface in FITTING_GUIDES.
5. Keep the shared origin, object scale, and front direction unchanged.
6. Keep body, underwear, hair, garments, shoes, and accessories separate.
7. STUDIO_REFERENCE_NOT_FOR_EXPORT contains only preview lights/camera/floor.
8. Before returning the file, leave one polished standard character visible
   and preserve all source collections.

No armature has been added yet. This draft is for proportions, fitting,
topology, materials, and modular-part art direction.
"""
    )


def render_validation_previews(scene: bpy.types.Scene) -> None:
    camera = scene.camera
    original_location = camera.location.copy()
    original_rotation = camera.rotation_euler.copy()
    original_lens = camera.data.lens
    original_size = (scene.render.resolution_x, scene.render.resolution_y)

    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    camera.data.lens = 68.0
    for path, location in (
        (FACE_PREVIEW_PATH, (0.0, -1.15, 0.81)),
        (FACE_SIDE_PREVIEW_PATH, (0.72, -0.52, 0.82)),
    ):
        camera.location = location
        aim_at(camera, (0.0, 0.0, 0.80))
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    camera.location = original_location
    camera.rotation_euler = original_rotation
    camera.data.lens = original_lens
    scene.render.resolution_x, scene.render.resolution_y = original_size


def clean_empty_collections() -> None:
    for collection in list(bpy.data.collections):
        if collection.name == "HILOAN_CHARACTER_CREATOR":
            continue
        if not collection.objects and not collection.children and collection.users == 0:
            bpy.data.collections.remove(collection)


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
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

    root = bpy.data.collections.new("HILOAN_CHARACTER_CREATOR")
    scene.collection.children.link(root)
    skin_material()
    lip_material()
    simple_material("MAT_Eye_White", "#e8e3da", 0.42)
    eyelash_material()
    cloth_material()
    build_body_variant(root, "standard", True)
    build_body_variant(root, "lean", False)
    build_studio(root)
    add_editing_guide()
    clean_empty_collections()

    scene["project"] = "Hiloan Character Creator"
    scene["draft_purpose"] = "Modular asset refinement and fitting reference"
    scene["godot_forward_axis"] = "+Z"
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)
    render_validation_previews(scene)
    print(f"BLENDER_DRAFT={BLEND_PATH}")
    print(f"BLENDER_PREVIEW={PREVIEW_PATH}")


if __name__ == "__main__":
    sys.exit(main())
