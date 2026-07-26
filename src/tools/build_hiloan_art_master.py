#!/usr/bin/env python3
"""Build the editable Hiloan art master on top of the user's hair work."""

from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_ROOT = Path(__file__).resolve().parent
BLENDER_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/blender"
VENDOR_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/vendor/makehuman/clothes"
INPUT_PATH = BLENDER_ROOT / "hiloan_user_reference.blend"
BACKUP_PATH = BLENDER_ROOT / "hiloan_user_reference_hair_backup.blend"
OUTPUT_PATH = BLENDER_ROOT / "hiloan_character_creator_art_master.blend"
PREVIEW_ROOT = BLENDER_ROOT / "art_master_previews"

sys.path.insert(0, str(TOOLS_ROOT))
import build_hiloan_3d_assets as assets  # noqa: E402


def hex_color(value: str) -> tuple[float, float, float, float]:
    value = value.removeprefix("#")
    return tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (1.0,)


def material(
    name: str,
    color: str,
    roughness: float,
    metallic: float = 0.0,
    cloth: bool = False,
) -> bpy.types.Material:
    value = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    value.diffuse_color = hex_color(color)
    value.use_nodes = True
    nodes = value.node_tree.nodes
    links = value.node_tree.links
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = hex_color(color)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if cloth and nodes.get(name + "_Noise") is None:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.name = name + "_Noise"
        noise.inputs["Scale"].default_value = 185.0
        noise.inputs["Detail"].default_value = 2.2
        noise.inputs["Roughness"].default_value = 0.72
        bump = nodes.new("ShaderNodeBump")
        bump.name = name + "_Bump"
        bump.inputs["Strength"].default_value = 0.16
        bump.inputs["Distance"].default_value = 0.025
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], principled.inputs["Normal"])
    return value


def image_material(
    name: str,
    texture_path: Path,
    fallback: str,
    roughness: float = 0.82,
) -> bpy.types.Material:
    value = material(name, fallback, roughness)
    nodes = value.node_tree.nodes
    links = value.node_tree.links
    principled = nodes.get("Principled BSDF")
    texture_node = nodes.get(name + "_Texture")
    if texture_node is None:
        texture_node = nodes.new("ShaderNodeTexImage")
        texture_node.name = name + "_Texture"
        texture_node.image = bpy.data.images.load(str(texture_path), check_existing=True)
        links.new(texture_node.outputs["Color"], principled.inputs["Base Color"])
    return value


def collection(parent: bpy.types.Collection, name: str) -> bpy.types.Collection:
    result = bpy.data.collections.get(name)
    if result is None:
        result = bpy.data.collections.new(name)
        parent.children.link(result)
    return result


def move_to_collection(obj: bpy.types.Object, target: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    target.objects.link(obj)


def blender_position(source: assets.Vec3) -> tuple[float, float, float]:
    x, y, z = source
    return x * assets.SCALE, -z * assets.SCALE, y * assets.SCALE


def add_fitted_asset(
    name: str,
    folder: Path,
    obj_file: str,
    mhclo_file: str,
    body_vertices: list[assets.Vec3],
    target: bpy.types.Collection,
    value: bpy.types.Material,
    offset_scale: float = 1.0,
) -> bpy.types.Object:
    source_mesh = assets.parse_obj(folder / obj_file)
    fitted_vertices, _ = assets.fit_proxy(
        body_vertices,
        folder / mhclo_file,
        offset_scale,
    )
    faces = [face for group_faces in source_mesh.groups.values() for face in group_faces]
    used_indices = sorted({corner[0] for face in faces for corner in face})
    source_to_local = {source_index: index for index, source_index in enumerate(used_indices)}
    vertices = [blender_position(fitted_vertices[index]) for index in used_indices]
    polygons = [[source_to_local[corner[0]] for corner in face] for face in faces]
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, source_face in zip(mesh.polygons, faces):
        for loop_index, source_corner in zip(polygon.loop_indices, source_face):
            uv_index = source_corner[1]
            uv_layer.data[loop_index].uv = (
                source_mesh.uvs[uv_index] if uv_index is not None else (0.0, 0.0)
            )
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    apply_material(obj, value)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj["source_edit_mesh"] = True
    obj["source_license"] = "CC0"
    obj["source_folder"] = str(folder.relative_to(PROJECT_ROOT))
    return obj


def apply_material(obj: bpy.types.Object, value: bpy.types.Material) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(value)


def add_beveled_box(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    rotation: tuple[float, float, float],
    target: bpy.types.Collection,
    value: bpy.types.Material,
    bevel: float = 0.008,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Soft tailored edges", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    apply_material(obj, value)
    move_to_collection(obj, target)
    return obj


def add_curve(
    name: str,
    points: list[tuple[float, float, float]],
    radius: float,
    target: bpy.types.Collection,
    value: bpy.types.Material,
    cyclic: bool = False,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name + "_Curve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    target.objects.link(obj)
    curve.materials.append(value)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    return obj


def add_elliptical_band(
    name: str,
    center: tuple[float, float, float],
    radius_x: float,
    radius_y: float,
    height: float,
    thickness: float,
    target: bpy.types.Collection,
    value: bpy.types.Material,
    segments: int = 64,
) -> bpy.types.Object:
    positions: list[tuple[float, float, float]] = []
    for z_offset in (-height * 0.5, height * 0.5):
        for radius_offset in (-thickness * 0.5, thickness * 0.5):
            for index in range(segments):
                angle = math.tau * index / segments
                positions.append(
                    (
                        center[0] + math.cos(angle) * (radius_x + radius_offset),
                        center[1] + math.sin(angle) * (radius_y + radius_offset),
                        center[2] + z_offset,
                    )
                )
    faces: list[tuple[int, int, int, int]] = []
    for index in range(segments):
        next_index = (index + 1) % segments
        inner_bottom = index
        outer_bottom = segments + index
        inner_top = segments * 2 + index
        outer_top = segments * 3 + index
        next_inner_bottom = next_index
        next_outer_bottom = segments + next_index
        next_inner_top = segments * 2 + next_index
        next_outer_top = segments * 3 + next_index
        faces.extend(
            (
                (outer_bottom, next_outer_bottom, next_outer_top, outer_top),
                (inner_top, next_inner_top, next_inner_bottom, inner_bottom),
                (inner_top, outer_top, next_outer_top, next_inner_top),
                (inner_bottom, next_inner_bottom, next_outer_bottom, outer_bottom),
            )
        )
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(positions, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    apply_material(obj, value)
    bevel_modifier = obj.modifiers.new("Woven edge softness", "BEVEL")
    bevel_modifier.width = 0.0015
    bevel_modifier.segments = 2
    return obj


def boundary_loops(obj: bpy.types.Object) -> list[list[int]]:
    edge_counts: dict[tuple[int, int], int] = {}
    for polygon in obj.data.polygons:
        indices = list(polygon.vertices)
        for first, second in zip(indices, indices[1:] + indices[:1]):
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
        previous = None
        current = start
        while True:
            choices = [index for index in adjacency[current] if index != previous]
            if not choices:
                break
            next_index = choices[0]
            if next_index == start or next_index in loop:
                break
            loop.append(next_index)
            previous, current = current, next_index
        remaining.difference_update(loop)
        loops.append(loop)
    return loops


def add_fitted_waistband(
    name: str,
    underwear: bpy.types.Object,
    target: bpy.types.Collection,
    value: bpy.types.Material,
) -> bpy.types.Object:
    waist_loop = max(
        boundary_loops(underwear),
        key=lambda loop: sum(
            (underwear.matrix_world @ underwear.data.vertices[index].co).z for index in loop
        )
        / len(loop),
    )
    path = [
        underwear.matrix_world @ underwear.data.vertices[index].co for index in waist_loop
    ]
    center_x = sum(point.x for point in path) / len(path)
    center_y = sum(point.y for point in path) / len(path)
    positions: list[tuple[float, float, float]] = []
    for point in path:
        radial = Vector((point.x - center_x, point.y - center_y, 0.0)).normalized()
        positions.extend(
            (
                tuple(point - radial * 0.001 + Vector((0.0, 0.0, -0.003))),
                tuple(point + radial * 0.007 + Vector((0.0, 0.0, -0.003))),
                tuple(point - radial * 0.001 + Vector((0.0, 0.0, 0.021))),
                tuple(point + radial * 0.007 + Vector((0.0, 0.0, 0.021))),
            )
        )
    faces: list[tuple[int, int, int, int]] = []
    for index in range(len(path)):
        next_index = (index + 1) % len(path)
        a = index * 4
        b = next_index * 4
        faces.extend(
            (
                (a + 1, b + 1, b + 3, a + 3),
                (a, a + 2, b + 2, b),
                (a + 2, a + 3, b + 3, b + 2),
                (a, b, b + 1, a + 1),
            )
        )
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(positions, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    apply_material(obj, value)
    modifier = obj.modifiers.new("Elastic edge softness", "BEVEL")
    modifier.width = 0.0018
    modifier.segments = 2
    return obj


def add_surface(
    name: str,
    rows: int,
    columns: int,
    point,
    target: bpy.types.Collection,
    value: bpy.types.Material,
    thickness: float = 0.008,
    bevel: float = 0.003,
) -> bpy.types.Object:
    positions = [
        point(row / (rows - 1), column / (columns - 1))
        for row in range(rows)
        for column in range(columns)
    ]
    faces = []
    for row in range(rows - 1):
        for column in range(columns - 1):
            a = row * columns + column
            b = a + 1
            c = a + columns
            d = c + 1
            faces.append((a, c, d, b))
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(positions, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    target.objects.link(obj)
    apply_material(obj, value)
    solidify = obj.modifiers.new("Wearable thickness", "SOLIDIFY")
    solidify.thickness = thickness
    solidify.offset = 0.0
    edge = obj.modifiers.new("Tailored edge", "BEVEL")
    edge.width = bevel
    edge.segments = 3
    return obj


def add_ribbon(
    name: str,
    path: list[tuple[float, float, float]],
    width: float,
    target: bpy.types.Collection,
    value: bpy.types.Material,
) -> bpy.types.Object:
    def point(row: float, column: float) -> tuple[float, float, float]:
        scaled = row * (len(path) - 1)
        first = min(int(scaled), len(path) - 2)
        mix_value = scaled - first
        center = Vector(path[first]).lerp(Vector(path[first + 1]), mix_value)
        tangent = Vector(path[first + 1]) - Vector(path[first])
        side = Vector((tangent.z, 0.0, -tangent.x)).normalized()
        fold = math.sin(row * math.pi * 3.0) * 0.004
        result = center + side * ((column - 0.5) * width)
        result.y += fold
        return tuple(result)

    return add_surface(name, 18, 5, point, target, value, 0.006, 0.003)


def add_shoulder_shell(
    name: str,
    center_x: float,
    target: bpy.types.Collection,
    value: bpy.types.Material,
) -> bpy.types.Object:
    def point(row: float, column: float) -> tuple[float, float, float]:
        u = column * 2.0 - 1.0
        v = row * 2.0 - 1.0
        x = center_x + u * 0.145
        y = -0.035 + v * 0.125
        z = 0.602 + (1.0 - u * u) * 0.052 - v * v * 0.020
        return x, y, z

    return add_surface(name, 9, 11, point, target, value, 0.014, 0.006)


def add_knee_guard(
    name: str,
    center_x: float,
    target: bpy.types.Collection,
    value: bpy.types.Material,
) -> bpy.types.Object:
    def point(row: float, column: float) -> tuple[float, float, float]:
        u = column * 2.0 - 1.0
        v = row * 2.0 - 1.0
        x = center_x + u * 0.068
        z = -0.39 + v * 0.086
        y = -0.139 - (1.0 - u * u) * (1.0 - v * v) * 0.024
        return x, y, z

    return add_surface(name, 9, 7, point, target, value, 0.011, 0.005)


def add_academy_mantle(
    name: str,
    target: bpy.types.Collection,
    value: bpy.types.Material,
) -> bpy.types.Object:
    def point(row: float, column: float) -> tuple[float, float, float]:
        x = 0.015 + column * 0.35
        z = 0.675 - row * (0.17 + column * 0.13)
        shoulder_curve = math.sin(column * math.pi) * 0.060
        y = -0.045 - shoulder_curve - row * 0.035
        return x, y, z

    return add_surface(name, 8, 12, point, target, value, 0.010, 0.007)


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    target: bpy.types.Collection,
    value: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_material(obj, value)
    move_to_collection(obj, target)
    return obj


def offset_garment(obj: bpy.types.Object, amount: float) -> None:
    obj.data.update()
    for vertex in obj.data.vertices:
        height = (obj.matrix_world @ vertex.co).z
        cuff_weight = 0.35 if height < -0.66 or height > 0.68 else 1.0
        vertex.co += vertex.normal * amount * cuff_weight
        world = obj.matrix_world @ vertex.co
        if -0.73 < world.z < 0.13 and abs(world.x) > 0.025:
            center_x = -0.105 if world.x < 0.0 else 0.105
            vertex.co.x = center_x + (vertex.co.x - center_x) * 1.075
            vertex.co.y = -0.02 + (vertex.co.y + 0.02) * 1.09
    obj.data.update()
    obj["art_master_fit"] = "garment eased away from body"


def enlarge_shoes(obj: bpy.types.Object, width_scale: float, depth_scale: float) -> None:
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        foot_center_x = -0.125 if world.x < 0.0 else 0.125
        local_center = obj.matrix_world.inverted() @ Vector((foot_center_x, -0.082, -0.715))
        vertex.co.x = local_center.x + (vertex.co.x - local_center.x) * width_scale
        vertex.co.y = local_center.y + (vertex.co.y - local_center.y) * depth_scale
        if world.z > -0.78:
            vertex.co.z += 0.006 * ((world.z + 0.78) / 0.18)
    obj.data.update()
    obj["art_master_fit"] = "foot enclosure widened and vamp raised"


def add_underwear(master: bpy.types.Collection, cloth: bpy.types.Material) -> None:
    underwear_collection = collection(master, "ART_UNDERWEAR")
    underwear = bpy.data.objects["RAW_Underwear"]
    apply_material(underwear, cloth)
    underwear["art_master_note"] = "Boxer brief base; keep continuous and unbroken"
    band = add_fitted_waistband(
        "ART_UnderwearWaistband",
        underwear,
        underwear_collection,
        cloth,
    )
    band["art_master_note"] = "Separate elastic waistband with cloth material"


def add_coastal_outfit(
    target: bpy.types.Collection,
    cloth: bpy.types.Material,
    rope: bpy.types.Material,
    metal: bpy.types.Material,
) -> None:
    add_ribbon(
        "ART_CoastalSash",
        [
            (-0.15, -0.176, 0.625),
            (-0.08, -0.194, 0.50),
            (0.0, -0.204, 0.37),
            (0.08, -0.194, 0.24),
            (0.15, -0.174, 0.11),
        ],
        0.105,
        target,
        cloth,
    )
    add_curve(
        "ART_CoastalRopeBelt",
        [
            (-0.205, -0.112, 0.125),
            (-0.11, -0.164, 0.105),
            (0.0, -0.181, 0.095),
            (0.11, -0.164, 0.105),
            (0.205, -0.112, 0.125),
            (0.19, 0.048, 0.125),
            (0.0, 0.085, 0.112),
            (-0.19, 0.048, 0.125),
        ],
        0.008,
        target,
        rope,
        True,
    )
    clasp_points = [(-0.09, -0.202, 0.39), (0.0, -0.205, 0.33), (0.09, -0.195, 0.27)]
    for index, point in enumerate(clasp_points):
        add_uv_sphere(
            "ART_CoastalClasps" if index == 0 else f"ART_CoastalClasps_{index}",
            point,
            (0.016, 0.007, 0.022),
            target,
            metal,
        )


def add_field_outfit(
    target: bpy.types.Collection,
    cloth: bpy.types.Material,
    leather: bpy.types.Material,
    metal: bpy.types.Material,
) -> None:
    add_shoulder_shell(
        "ART_FieldShoulderGuard",
        -0.205,
        target,
        cloth,
    )
    add_curve(
        "ART_FieldHarness",
        [
            (-0.15, -0.175, 0.62),
            (-0.08, -0.195, 0.47),
            (0.02, -0.198, 0.30),
            (0.12, -0.178, 0.13),
        ],
        0.013,
        target,
        leather,
    )
    for index, x in enumerate((-0.115, 0.115)):
        add_knee_guard(
            "ART_FieldKneeGuards" if index == 0 else "ART_FieldKneeGuards_R",
            x,
            target,
            cloth,
        )
    add_uv_sphere(
        "ART_FieldHarness_Rivet",
        (0.02, -0.215, 0.30),
        (0.015, 0.006, 0.015),
        target,
        metal,
    )


def add_academy_outfit(
    target: bpy.types.Collection,
    cloth: bpy.types.Material,
    conduit: bpy.types.Material,
    metal: bpy.types.Material,
) -> None:
    add_academy_mantle(
        "ART_AcademyMantle",
        target,
        cloth,
    )
    add_curve(
        "ART_AcademyConduit",
        [
            (0.18, -0.18, 0.57),
            (0.12, -0.205, 0.48),
            (0.035, -0.214, 0.39),
            (-0.07, -0.205, 0.31),
            (-0.13, -0.178, 0.20),
        ],
        0.007,
        target,
        conduit,
    )
    for index, z in enumerate((0.48, 0.39, 0.30)):
        add_uv_sphere(
            "ART_AcademyClasps" if index == 0 else f"ART_AcademyClasps_{index}",
            (-0.018, -0.221, z),
            (0.018, 0.006, 0.018),
            target,
            metal,
        )


def add_extras(
    master: bpy.types.Collection,
    cloth: bpy.types.Material,
    leather: bpy.types.Material,
    metal: bpy.types.Material,
    glass: bpy.types.Material,
) -> None:
    extras = collection(master, "ART_EXTRAS")
    pendant = collection(extras, "BIOME_PENDANT")
    add_curve(
        "ART_BiomePendantChain",
        [
            (-0.078, -0.142, 0.61),
            (-0.055, -0.176, 0.52),
            (0.0, -0.197, 0.45),
            (0.055, -0.176, 0.52),
            (0.078, -0.142, 0.61),
        ],
        0.004,
        pendant,
        metal,
    )
    medallion = add_uv_sphere(
        "ART_BiomePendant",
        (0.0, -0.205, 0.425),
        (0.040, 0.010, 0.052),
        pendant,
        metal,
    )
    medallion["lore"] = "Personal Biome resonance seal"

    scarf = collection(extras, "COASTAL_NECK_WRAP")
    add_elliptical_band(
        "ART_CoastalNeckWrap",
        (0.0, -0.005, 0.675),
        0.115,
        0.092,
        0.075,
        0.018,
        scarf,
        cloth,
    )
    add_ribbon(
        "ART_CoastalScarfTail",
        [
            (0.045, -0.152, 0.645),
            (0.075, -0.171, 0.56),
            (0.095, -0.178, 0.45),
            (0.105, -0.17, 0.34),
        ],
        0.095,
        scarf,
        cloth,
    )

    vial = collection(extras, "BIOME_VIAL")
    add_curve(
        "ART_BiomeVialHarness",
        [
            (0.14, -0.12, 0.12),
            (0.19, -0.15, 0.06),
            (0.22, -0.15, -0.03),
        ],
        0.010,
        vial,
        leather,
    )
    bottle = add_uv_sphere(
        "ART_BiomeVial",
        (0.22, -0.158, -0.09),
        (0.038, 0.026, 0.080),
        vial,
        glass,
    )
    bottle["lore"] = "Biome field sample vessel"


def set_visibility(names: set[str]) -> None:
    for obj in bpy.data.objects:
        if obj.type in {"MESH", "CURVE"} and (
            obj.name.startswith("RAW_")
            or obj.name.startswith("ART_")
            or obj.name.startswith("FIT_")
        ):
            visible = obj.name in names
            obj.hide_set(not visible)
            obj.hide_render = not visible


def aim_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_preview(name: str, visible: set[str], yaw: float = 0.0) -> None:
    set_visibility(visible)
    body = bpy.data.objects.get("RAW_BaseBody")
    body.rotation_euler.z = yaw
    for obj_name in visible:
        obj = bpy.data.objects.get(obj_name)
        if obj is not None and obj != body:
            obj.rotation_euler.z = yaw
    scene = bpy.context.scene
    camera = bpy.data.objects.get("RAW_REF_Camera")
    if camera is None:
        return
    camera.location = (0.0, -3.7, 0.10)
    camera.data.lens = 58.0
    aim_at(camera, (0.0, 0.0, 0.06))
    scene.camera = camera
    scene.render.resolution_x = 900
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    scene.render.use_border = False
    scene.render.use_crop_to_border = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_ROOT / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def add_guide() -> None:
    guide = bpy.data.texts.get("README_ART_MASTER") or bpy.data.texts.new("README_ART_MASTER")
    guide.clear()
    guide.write(
        """HILOAN CHARACTER CREATOR ART MASTER

The user's saved hair meshes are the source of truth.

ART_UNDERWEAR contains the modeled boxer waistband.
ART_OUTFITS contains region-specific garment structure.
ART_SHOES contains the widened shoe bases.
ART_EXTRAS contains visible pendant, neck wrap, and Biome vial options.

Edit this file for future fitting work. Keep RAW_/ART_ object names stable so
the runtime extractor can find them. Export is performed by
extract_hiloan_art_master.py; this Blender file is never loaded directly by
Godot.
"""
    )


def main() -> None:
    if not INPUT_PATH.exists():
        raise FileNotFoundError(INPUT_PATH)
    if not BACKUP_PATH.exists():
        shutil.copy2(INPUT_PATH, BACKUP_PATH)
    bpy.ops.wm.open_mainfile(filepath=str(INPUT_PATH))

    old_master = bpy.data.collections.get("HILOAN_ART_MASTER")
    if old_master is not None:
        for obj in list(old_master.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old_master)

    scene_root = bpy.context.scene.collection
    master = bpy.data.collections.new("HILOAN_ART_MASTER")
    scene_root.children.link(master)
    outfit_root = collection(master, "ART_OUTFITS")
    shoe_root = collection(master, "ART_SHOES")
    glasses_root = collection(master, "ART_GLASSES")

    underwear_mat = material("ART_MAT_UnderwearKnit", "#303840", 0.86, cloth=True)
    coastal_mat = material("ART_MAT_CoastalCloth", "#38545c", 0.88, cloth=True)
    field_mat = material("ART_MAT_FieldQuilt", "#39483d", 0.92, cloth=True)
    academy_mat = material("ART_MAT_AcademyCloth", "#253f58", 0.84, cloth=True)
    rope_mat = material("ART_MAT_Rope", "#887052", 0.94, cloth=True)
    leather_mat = material("ART_MAT_Leather", "#4a3427", 0.64)
    metal_mat = material("ART_MAT_Brass", "#a67b35", 0.32, 0.72)
    conduit_mat = material("ART_MAT_BiomeConduit", "#4b8ca0", 0.27, 0.38)
    glass_mat = material("ART_MAT_BiomeGlass", "#4a9db4", 0.18, 0.12)

    add_underwear(master, underwear_mat)

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
    base_mesh = assets.parse_obj(assets.SOURCE_ROOT / "base.obj")
    body_vertices = assets.apply_target(
        base_mesh.vertices,
        assets.combine_targets(
            [
                (assets.target("caucasian-male-young.target"), 1.0),
                (face_harmony, 1.0),
                (assets.muscle_profile(1.0), 1.0),
            ]
        ),
    )

    coastal = collection(outfit_root, "COASTAL_TRAVELER")
    field = collection(outfit_root, "FROSTFIELD_WORKER")
    academy = collection(outfit_root, "DATT_ACADEMY")
    viking_tunic = VENDOR_ROOT / "rehmanpolanski_viking_tunic"
    viking_pants = VENDOR_ROOT / "rehmanpolanski_viking_pants"
    viking_boots = VENDOR_ROOT / "rehmanpolanski_viking_boots"
    galactic = VENDOR_ROOT / "thegreatengineer_galactic_warrior_uniform"
    skinsuit = VENDOR_ROOT / "matcreator_mc-skinsuit_2022"
    monk = VENDOR_ROOT / "donitz_monk_robe"
    male_boots = VENDOR_ROOT / "culturalibre_male_boots"
    ankle_boots = VENDOR_ROOT / "toigo_ankle_boots_male"
    rectangular_glasses = VENDOR_ROOT / "frankyaye_glasses_library_male"
    round_glasses = VENDOR_ROOT / "toigo_round_glasses_leopard"

    coastal_tunic_mat = image_material(
        "ART_MAT_CoastalTunic",
        viking_tunic / "TUNIC_Viking.png",
        "#38545c",
    )
    coastal_pants_mat = image_material(
        "ART_MAT_CoastalPants",
        viking_pants / "PantsViking.png",
        "#3b4548",
    )
    frost_mat = image_material(
        "ART_MAT_FrostUniform",
        galactic / "Glactic_Warrior_02.png",
        "#3a4846",
    )
    academy_robe_mat = image_material(
        "ART_MAT_AcademyRobe",
        monk / "robe_brown__diffuse.png",
        "#253f58",
    )
    viking_boot_mat = image_material(
        "ART_MAT_VikingBoot",
        viking_boots / "BootsViking.png",
        "#4a3427",
    )
    male_boot_mat = image_material(
        "ART_MAT_MaleBoot",
        male_boots / "boot.png",
        "#392d27",
    )
    ankle_boot_mat = image_material(
        "ART_MAT_AnkleBoot",
        ankle_boots / "BootsAnkleM.png",
        "#302a27",
    )
    rectangular_glasses_mat = image_material(
        "ART_MAT_RectangularGlasses",
        rectangular_glasses / "Glasses2.png",
        "#222326",
        0.38,
    )
    round_glasses_mat = image_material(
        "ART_MAT_RoundGlasses",
        round_glasses / "Glasses-leopard.png",
        "#9a783b",
        0.38,
    )

    add_fitted_asset(
        "FIT_CoastalTunic",
        viking_tunic,
        "tunicviking.obj",
        "rehmanpolanski_viking_tunic.mhclo",
        body_vertices,
        coastal,
        coastal_tunic_mat,
    )
    add_fitted_asset(
        "FIT_CoastalPants",
        viking_pants,
        "pantsviking.obj",
        "rehmanpolanski_viking_pants.mhclo",
        body_vertices,
        coastal,
        coastal_pants_mat,
    )
    add_fitted_asset(
        "FIT_FrostfieldUnderlayer",
        skinsuit,
        "MC-SkinSuit_2022.obj",
        "matcreator_mc-skinsuit_2022.mhclo",
        body_vertices,
        field,
        field_mat,
        0.1,
    )
    add_fitted_asset(
        "FIT_FrostfieldUniform",
        galactic,
        "Glactic_Warrior_02.obj",
        "thegreatengineer_galactic_warrior_uniform.mhclo",
        body_vertices,
        field,
        frost_mat,
    )
    add_fitted_asset(
        "FIT_AcademyRobe",
        monk,
        "Monks_Robe.obj",
        "donitz_monk_robe.mhclo",
        body_vertices,
        academy,
        academy_robe_mat,
    )
    add_fitted_asset(
        "FIT_TravelShoes",
        male_boots,
        "male_boots.obj",
        "culturalibre_male_boots.mhclo",
        body_vertices,
        shoe_root,
        male_boot_mat,
    )
    add_fitted_asset(
        "FIT_LowShoes",
        ankle_boots,
        "boots_ankle_male.obj",
        "toigo_ankle_boots_male.mhclo",
        body_vertices,
        shoe_root,
        ankle_boot_mat,
    )
    add_fitted_asset(
        "FIT_TravelBoots",
        viking_boots,
        "bootsviking.obj",
        "rehmanpolanski_viking_boots.mhclo",
        body_vertices,
        shoe_root,
        viking_boot_mat,
    )
    add_fitted_asset(
        "FIT_GlassesAngular",
        rectangular_glasses,
        "glasses_library_male.obj",
        "frankyaye_glasses_library_male.mhclo",
        body_vertices,
        glasses_root,
        rectangular_glasses_mat,
    )
    add_fitted_asset(
        "FIT_GlassesRound",
        round_glasses,
        "roundglasses_leopard.obj",
        "toigo_round_glasses_leopard.mhclo",
        body_vertices,
        glasses_root,
        round_glasses_mat,
    )

    for name in (
        "RAW_TravelSuit",
        "RAW_FieldSuit",
        "RAW_FormalSuit",
        "RAW_TravelShoes",
        "RAW_LowShoes",
        "RAW_TravelBoots",
    ):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.hide_set(True)
            obj.hide_render = True
            obj["legacy_not_exported"] = True
    add_guide()
    bpy.context.scene["project"] = "Hiloan Character Creator Art Master"
    bpy.context.scene["source_of_truth"] = "User hair + art-master garment fitting"

    PREVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    body = {"RAW_BaseBody", "RAW_EyeWhites", "RAW_UpperEyelashes", "RAW_LowerEyelashes"}
    render_preview(
        "01_body_underwear_hair",
        body | {"RAW_Underwear", "ART_UnderwearWaistband", "RAW_ShortHair", "RAW_EyebrowNatural"},
    )
    render_preview(
        "02_coastal_traveler",
        body
        | {
            "RAW_ShortHair",
            "FIT_CoastalTunic",
            "FIT_CoastalPants",
            "FIT_TravelShoes",
        },
    )
    render_preview(
        "03_frostfield_worker",
        body
        | {
            "RAW_CloseCrop",
            "FIT_FrostfieldUnderlayer",
            "FIT_FrostfieldUniform",
            "FIT_TravelBoots",
        },
    )
    render_preview(
        "04_academy_scholar",
        body
        | {
            "RAW_SideSwept",
            "FIT_AcademyRobe",
            "FIT_LowShoes",
        },
    )
    render_preview(
        "05_glasses_round",
        body | {"RAW_ShortHair", "RAW_Underwear", "ART_UnderwearWaistband", "FIT_GlassesRound"},
    )
    render_preview(
        "06_glasses_angular",
        body | {"RAW_ShortHair", "RAW_Underwear", "ART_UnderwearWaistband", "FIT_GlassesAngular"},
    )

    set_visibility(body | {"RAW_Underwear", "ART_UnderwearWaistband", "RAW_ShortHair"})
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_PATH))
    print(f"HILOAN_ART_MASTER={OUTPUT_PATH}")
    print(f"HILOAN_ART_MASTER_BACKUP={BACKUP_PATH}")
    print(f"HILOAN_ART_MASTER_PREVIEWS={PREVIEW_ROOT}")


if __name__ == "__main__":
    sys.exit(main())
