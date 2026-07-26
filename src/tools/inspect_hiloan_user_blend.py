#!/usr/bin/env python3
"""Compare an opened Hiloan user Blender file with a generated baseline."""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy


BASELINE_PATH = Path("/tmp/hiloan_raw_baseline.blend")
REPORT_PATH = Path("/tmp/hiloan_user_blend_diff.txt")
COMPARE_PREFIXES = (
    "RAW_BaseBody",
    "RAW_EyeWhites",
    "RAW_UpperEyelashes",
    "RAW_LowerEyelashes",
    "RAW_ShortHair",
    "RAW_CloseCrop",
    "RAW_SideSwept",
    "RAW_Eyebrow",
    "RAW_Underwear",
    "RAW_TravelSuit",
    "RAW_FieldSuit",
    "RAW_FormalSuit",
    "RAW_TravelShoes",
    "RAW_LowShoes",
    "RAW_TravelBoots",
)


def transform_delta(current: bpy.types.Object, baseline: bpy.types.Object) -> tuple[float, float, float]:
    translation = (current.location - baseline.location).length
    rotation = math.sqrt(
        sum(
            (current.rotation_euler[index] - baseline.rotation_euler[index]) ** 2
            for index in range(3)
        )
    )
    scale = (current.scale - baseline.scale).length
    return translation, rotation, scale


def main() -> None:
    if not BASELINE_PATH.exists():
        raise FileNotFoundError(BASELINE_PATH)

    source_names: list[str]
    baseline_objects: list[bpy.types.Object]
    with bpy.data.libraries.load(str(BASELINE_PATH), link=False) as (source, target):
        source_names = [
            name
            for name in source.objects
            if any(name.startswith(prefix) for prefix in COMPARE_PREFIXES)
        ]
        target.objects = list(source_names)
    baseline_objects = target.objects

    lines = ["HILOAN_USER_BLEND_DIFF", ""]
    for source_name, baseline in zip(source_names, baseline_objects):
        current = bpy.data.objects.get(source_name)
        if current is None:
            lines.append(f"{source_name}: MISSING")
            continue
        translation, rotation, scale = transform_delta(current, baseline)
        if current.type != "MESH" or baseline.type != "MESH":
            lines.append(
                f"{source_name}: transform=({translation:.8f},{rotation:.8f},{scale:.8f})"
            )
            continue
        if len(current.data.vertices) != len(baseline.data.vertices):
            lines.append(
                f"{source_name}: TOPOLOGY_CHANGED "
                f"vertices={len(current.data.vertices)}/{len(baseline.data.vertices)} "
                f"faces={len(current.data.polygons)}/{len(baseline.data.polygons)}"
            )
            continue

        deltas = [
            (current.data.vertices[index].co - baseline.data.vertices[index].co).length
            for index in range(len(current.data.vertices))
        ]
        changed = [delta for delta in deltas if delta > 0.00001]
        lines.append(
            f"{source_name}: changed={len(changed)}/{len(deltas)} "
            f"mean_delta={sum(deltas) / max(1, len(deltas)):.8f} "
            f"max_delta={max(deltas, default=0.0):.8f} "
            f"transform=({translation:.8f},{rotation:.8f},{scale:.8f}) "
            f"hidden={current.hide_get()} render_hidden={current.hide_render}"
        )

    REPORT_PATH.write_text("\n".join(lines) + "\n")
    print(REPORT_PATH.read_text())


if __name__ == "__main__":
    sys.exit(main())
