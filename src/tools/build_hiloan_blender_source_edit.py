#!/usr/bin/env python3
"""Create a quad-oriented Blender source file from the fitted runtime draft."""

from __future__ import annotations

import math
import sys
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BLENDER_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/blender"
INPUT_PATH = BLENDER_ROOT / "hiloan_character_creator_fitting_v2.blend"
OUTPUT_PATH = BLENDER_ROOT / "hiloan_character_creator_source_edit.blend"
PREVIEW_PATH = BLENDER_ROOT / "hiloan_character_creator_source_edit_preview.png"


def aim_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def restore_quads(obj: bpy.types.Object) -> None:
    if obj.type != "MESH" or not obj.data.polygons:
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.tris_convert_to_quads(
        face_threshold=math.radians(40.0),
        shape_threshold=math.radians(40.0),
        uvs=True,
        vcols=True,
        seam=True,
        sharp=True,
        materials=True,
    )
    bpy.ops.object.mode_set(mode="OBJECT")
    obj["source_edit_mesh"] = True


def topology_summary() -> str:
    lines = ["HILOAN SOURCE EDIT TOPOLOGY", ""]
    for obj in sorted((item for item in bpy.data.objects if item.type == "MESH"), key=lambda item: item.name):
        counts = Counter(len(polygon.vertices) for polygon in obj.data.polygons)
        lines.append(
            f"{obj.name}: "
            + ", ".join(f"{size}-gon={count}" for size, count in sorted(counts.items()))
        )
    return "\n".join(lines)


def add_source_guide() -> None:
    guide = bpy.data.texts.get("README_SOURCE_EDIT") or bpy.data.texts.new("README_SOURCE_EDIT")
    guide.clear()
    guide.write(
        """HILOAN SOURCE EDIT FILE

This file is for manual shape and fitting work, not direct game export.

1. Meshes have been restored to quad-oriented topology where the source allows.
2. Edit STANDARD first. LEAN remains available as a hidden comparison body.
3. STANDARD_Lips keeps the Lip_Surface_Fit Shrinkwrap modifier.
4. Move loops with proportional editing or Sculpt Grab/Smooth. Avoid moving
   individual triangles.
5. Do not apply transforms, rename objects, remesh, triangulate, or delete
   Shape Keys.
6. HairCap is the fitted scalp underlayer. Adjust the outer hairstyle first.
7. Save your result as hiloan_user_reference.blend.

The runtime GLB assets will be rebuilt separately after the art changes are
approved.
"""
    )
    report = bpy.data.texts.get("SOURCE_TOPOLOGY_REPORT") or bpy.data.texts.new(
        "SOURCE_TOPOLOGY_REPORT"
    )
    report.clear()
    report.write(topology_summary())


def render_preview() -> None:
    scene = bpy.context.scene
    camera = bpy.data.objects.get("REF_Camera_Front")
    if camera is None:
        return
    scene.camera = camera
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    camera.data.lens = 68.0
    camera.location = (0.0, -1.15, 0.81)
    aim_at(camera, (0.0, 0.0, 0.80))
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    if not INPUT_PATH.exists():
        raise FileNotFoundError(f"Missing fitted Blender draft: {INPUT_PATH}")
    bpy.ops.wm.open_mainfile(filepath=str(INPUT_PATH))

    hidden_states = {obj.name: obj.hide_get() for obj in bpy.data.objects}
    render_states = {obj.name: obj.hide_render for obj in bpy.data.objects}
    for obj in list(bpy.data.objects):
        restore_quads(obj)
    for obj in bpy.data.objects:
        obj.hide_set(hidden_states.get(obj.name, False))
        obj.hide_render = render_states.get(obj.name, False)

    add_source_guide()
    scene = bpy.context.scene
    scene["draft_purpose"] = "Quad-oriented manual source editing"
    scene["runtime_export_ready"] = False
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_PATH))
    render_preview()

    quad_faces = sum(
        1
        for obj in bpy.data.objects
        if obj.type == "MESH"
        for polygon in obj.data.polygons
        if len(polygon.vertices) == 4
    )
    triangle_faces = sum(
        1
        for obj in bpy.data.objects
        if obj.type == "MESH"
        for polygon in obj.data.polygons
        if len(polygon.vertices) == 3
    )
    print(f"BLENDER_SOURCE_EDIT={OUTPUT_PATH}")
    print(f"BLENDER_SOURCE_PREVIEW={PREVIEW_PATH}")
    print(f"TOPOLOGY_QUADS={quad_faces}")
    print(f"TOPOLOGY_TRIANGLES={triangle_faces}")


if __name__ == "__main__":
    sys.exit(main())
