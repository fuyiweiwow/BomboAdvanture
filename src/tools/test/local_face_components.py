"""Build deterministic, componentized face layers from manual annotations.

This is deliberately local and reproducible. It does not call an image API or
make a creative model responsible for pixel placement. The annotation file
defines the geometry; the seeded variant rules define colors and small style
changes.

Usage:
    E:\\env\\venv\\Scripts\\python.exe local_face_components.py
    E:\\env\\venv\\Scripts\\python.exe local_face_components.py --seed 20260726
"""

from __future__ import annotations

import argparse
import json
import random
from collections import defaultdict
from pathlib import Path
from typing import Iterable

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ANNOTATIONS = PROJECT_ROOT / "assets" / "test" / "male_face_v2" / "annotations.json"
DEFAULT_SOURCE_DIR = PROJECT_ROOT / "assets" / "img" / "face"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "assets" / "test" / "male_face_v3_local"

ORIENTATION_TO_ATLAS_DIR = {"R": 0, "U": 1, "L": 2, "D": 3}
EYE_FIELDS = ("sclera", "iris", "pupil", "highlight", "lash")
REMOVE_FIELDS = EYE_FIELDS + ("brow", "ear")
LAYER_NAMES = ("eye_eyeball", "eye_iris", "eye_pupil", "eye_highlight", "brow", "ear")


VARIANT_PLANS = (
    {
        "id": "variant_01",
        "label": "soft_blue_open",
        "eye_mode": "open",
        "iris": ((56, 126, 184, 255), (30, 78, 128, 255), (18, 42, 76, 255)),
        "brow": ((72, 42, 31, 255), (112, 67, 44, 255)),
        "ear": ((242, 167, 130, 255), (214, 125, 101, 255), (151, 75, 68, 255)),
    },
    {
        "id": "variant_02",
        "label": "amber_half_lid",
        "eye_mode": "half_lid",
        "iris": ((194, 142, 58, 255), (119, 76, 28, 255), (65, 39, 18, 255)),
        "brow": ((43, 30, 27, 255), (96, 55, 37, 255)),
        "ear": ((229, 145, 116, 255), (188, 93, 78, 255), (117, 56, 53, 255)),
    },
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--annotations", type=Path, default=DEFAULT_ANNOTATIONS)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--face-id", default="face10101")
    parser.add_argument("--seed", type=int, default=20260726)
    return parser.parse_args()


def as_points(values: Iterable[Iterable[int]]) -> set[tuple[int, int]]:
    return {(int(point[0]), int(point[1])) for point in values}


def load_annotations(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def locate_source(source_dir: Path, face_id: str, state: str, direction: str, frame: int) -> Path:
    atlas_dir = ORIENTATION_TO_ATLAS_DIR[direction]
    expected = f"{face_id}_{state}_{atlas_dir}_{frame}.png".lower()
    for path in source_dir.glob("*.png"):
        if path.name.lower() == expected:
            return path
    raise FileNotFoundError(f"Source frame not found: {expected} in {source_dir}")


def feature_sets(annotation: dict) -> dict[str, set[tuple[int, int]]]:
    features = annotation.get("feat", {})
    return {name: as_points(features.get(name, [])) for name in REMOVE_FIELDS}


def nearest_repair_color(
    image: Image.Image,
    x: int,
    y: int,
    removed: set[tuple[int, int]],
) -> tuple[int, int, int, int]:
    """Copy a nearby original pixel instead of leaving a transparent hole."""
    px = image.load()
    max_radius = max(image.width, image.height)
    for radius in range(1, max_radius + 1):
        candidates: list[tuple[int, int, int, int]] = []
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                if abs(dx) + abs(dy) != radius:
                    continue
                nx, ny = x + dx, y + dy
                if not (0 <= nx < image.width and 0 <= ny < image.height):
                    continue
                color = px[nx, ny]
                if color[3] >= 128 and (nx, ny) not in removed:
                    candidates.append(color)
        if candidates:
            # Keep exact source palette colors; do not introduce anti-aliasing.
            return candidates[0]
    return (0, 0, 0, 0)


def build_clean_base(
    original: Image.Image,
    features: dict[str, set[tuple[int, int]]],
) -> tuple[Image.Image, dict[str, int]]:
    removed = set().union(*(features[name] for name in REMOVE_FIELDS))
    ears = features["ear"]
    result = Image.new("RGBA", original.size, (0, 0, 0, 0))
    source_px = original.load()
    result_px = result.load()
    repaired = 0
    ear_transparent = 0

    for y in range(original.height):
        for x in range(original.width):
            point = (x, y)
            color = source_px[x, y]
            if point not in removed:
                result_px[x, y] = color
            elif point in ears:
                # Clear ears so the base face has a cheek silhouette and ears can
                # be replaced independently.
                result_px[x, y] = (0, 0, 0, 0)
                ear_transparent += 1
            elif color[3] >= 128:
                result_px[x, y] = nearest_repair_color(original, x, y, removed)
                repaired += 1

    return result, {"removed": len(removed), "repaired": repaired, "ear_transparent": ear_transparent}


def put_points(
    image: Image.Image,
    points: set[tuple[int, int]],
    color: tuple[int, int, int, int],
) -> None:
    px = image.load()
    for x, y in points:
        if 0 <= x < image.width and 0 <= y < image.height:
            px[x, y] = color


def split_brow_pixels(points: set[tuple[int, int]]) -> list[set[tuple[int, int]]]:
    """Split the left/right brow clusters without assuming a fixed face width."""
    if not points:
        return []
    remaining = set(points)
    groups: list[set[tuple[int, int]]] = []
    while remaining:
        seed = remaining.pop()
        group = {seed}
        frontier = [seed]
        while frontier:
            x, y = frontier.pop()
            neighbors = {
                (nx, ny)
                for nx in range(x - 1, x + 2)
                for ny in range(y - 1, y + 2)
                if (nx, ny) in remaining
            }
            remaining -= neighbors
            group |= neighbors
            frontier.extend(neighbors)
        groups.append(group)
    return sorted(groups, key=lambda group: min(x for x, _ in group))


def selected_brow_points(points: set[tuple[int, int]], mode: str) -> set[tuple[int, int]]:
    if mode == "thick" or not points:
        return points
    selected: set[tuple[int, int]] = set()
    for group in split_brow_pixels(points):
        min_x = min(x for x, _ in group)
        max_x = max(x for x, _ in group)
        min_y = min(y for _, y in group)
        span = max(1, max_x - min_x)
        for x, y in group:
            target_y = min_y + round((x - min_x) / span)
            if y <= target_y:
                selected.add((x, y))
    return selected


def build_variant_layers(
    original: Image.Image,
    features: dict[str, set[tuple[int, int]]],
    plan: dict,
    rng: random.Random,
) -> dict[str, Image.Image]:
    layers = {name: Image.new("RGBA", original.size, (0, 0, 0, 0)) for name in LAYER_NAMES}

    if plan["eye_mode"] == "open":
        put_points(layers["eye_eyeball"], features["sclera"], (255, 250, 238, 255))
        put_points(layers["eye_iris"], features["iris"], plan["iris"][0])
        put_points(layers["eye_pupil"], features["lash"], (45, 27, 24, 255))
        put_points(layers["eye_pupil"], features["pupil"], plan["iris"][2])
        put_points(layers["eye_highlight"], features["highlight"], (255, 255, 255, 255))
    else:
        # A half-lid variant uses the annotated lash envelope as a compact line.
        put_points(layers["eye_pupil"], features["lash"], (48, 29, 26, 255))
        pupil = sorted(features["pupil"], key=lambda p: (p[1], p[0]))
        put_points(layers["eye_pupil"], set(pupil[: max(1, len(pupil) // 2)]), plan["iris"][2])

    brow_color = plan["brow"][0]
    brow_highlight = plan["brow"][1]
    brow_mode = "thick" if plan["eye_mode"] == "open" else "thin"
    brow_points = selected_brow_points(features["brow"], brow_mode)
    put_points(layers["brow"], brow_points, brow_color)
    brow_px = layers["brow"].load()
    for index, point in enumerate(sorted(brow_points, key=lambda p: (p[1], p[0]))):
        if index % 5 == rng.randrange(5):
            brow_px[point[0], point[1]] = brow_highlight

    ear_pixels = features["ear"]
    if ear_pixels:
        ear_palette = plan["ear"]
        min_x = min(x for x, _ in ear_pixels)
        max_x = max(x for x, _ in ear_pixels)
        min_y = min(y for _, y in ear_pixels)
        max_y = max(y for _, y in ear_pixels)
        ear_px = layers["ear"].load()
        for x, y in ear_pixels:
            depth = abs(x - min_x) + abs(max_x - x) + abs(y - min_y) + abs(max_y - y)
            shade = 0 if depth > (max_x - min_x + max_y - min_y) * 1.3 else 1
            if (x + y + rng.randrange(3)) % 7 == 0:
                shade = 2
            ear_px[x, y] = ear_palette[shade]

    return layers


def alpha_composite(base: Image.Image, layers: Iterable[Image.Image]) -> Image.Image:
    result = base.copy()
    for layer in layers:
        result = Image.alpha_composite(result, layer)
    return result


def ordered_names(names: list[str]) -> list[str]:
    return sorted(names, key=lambda name: int(Path(name).stem.split("_")[-1]))


def write_component_json(folder: Path, component: str, frame_names: dict[str, list[str]]) -> None:
    data = {"NAME": component, "INTERVAL": 100}
    for direction in ("R", "U", "L", "D"):
        stand_names = ordered_names(frame_names.get(f"stand_{direction}", []))
        walk_names = ordered_names(frame_names.get(f"walk_{direction}", []))
        data[f"STAND_{direction}"] = {"IMG": stand_names, "CX": [0] * len(stand_names), "CY": [0] * len(stand_names)}
        data[direction] = {"IMG": walk_names, "CX": [0] * len(walk_names), "CY": [0] * len(walk_names)}
    with (folder / f"{component}.json").open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)


def make_preview(variant_dir: Path, variant_id: str, face_id: str) -> None:
    preview_dir = variant_dir / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    names = [
        f"{face_id}_stand_D_0.png",
        f"{face_id}_walk_D_0.png",
        f"{face_id}_stand_L_0.png",
        f"{face_id}_stand_R_0.png",
        f"{face_id}_stand_U_0.png",
    ]
    scale = 8
    tile_w, tile_h = 40 * scale, 40 * scale
    sheet = Image.new("RGBA", (tile_w * 3, tile_h * 2), (44, 44, 50, 255))
    for index, name in enumerate(names):
        path = variant_dir / "composite" / name
        if not path.exists():
            continue
        image = Image.open(path).convert("RGBA")
        image = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
        x = (index % 3) * tile_w + (tile_w - image.width) // 2
        y = (index // 3) * tile_h + (tile_h - image.height) // 2
        sheet.alpha_composite(image, (x, y))
    sheet.save(preview_dir / f"{variant_id}_preview.png")


def generate(args: argparse.Namespace) -> None:
    annotations = load_annotations(args.annotations)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "pipeline": "local_face_components_v1",
        "face_id": args.face_id,
        "annotations": str(args.annotations),
        "source_dir": str(args.source_dir),
        "seed": args.seed,
        "coordinate_contract": "Every PNG uses the original face frame pixel origin; CX/CY are 0.",
        "composition_order": ["base", "eye_eyeball", "eye_iris", "eye_pupil", "eye_highlight", "brow", "ear"],
        "variants": [],
    }

    for variant_index, plan in enumerate(VARIANT_PLANS):
        variant_seed = args.seed + variant_index * 1009
        variant_rng = random.Random(variant_seed)
        variant_dir = args.output_dir / plan["id"]
        component_dirs = {name: variant_dir / name for name in ("base", *LAYER_NAMES, "composite")}
        for folder in component_dirs.values():
            folder.mkdir(parents=True, exist_ok=True)
        frame_names: dict[str, dict[str, list[str]]] = {name: defaultdict(list) for name in (*LAYER_NAMES, "base")}
        stats = {"frames": 0, "repaired": 0, "ear_transparent": 0, "feature_pixels": 0}

        for key, annotation in annotations.items():
            state, direction, frame_text = key.split("_")
            frame = int(frame_text)
            source_path = locate_source(args.source_dir, args.face_id, state, direction, frame)
            original = Image.open(source_path).convert("RGBA")
            features = feature_sets(annotation)
            clean_base, repair_stats = build_clean_base(original, features)
            layers = build_variant_layers(original, features, plan, variant_rng)
            composite = alpha_composite(clean_base, (layers[name] for name in LAYER_NAMES))

            frame_name = f"{args.face_id}_{state}_{direction}_{frame}.png"
            clean_base.save(component_dirs["base"] / frame_name)
            composite.save(component_dirs["composite"] / frame_name)
            for layer_name, layer in layers.items():
                layer.save(component_dirs[layer_name] / frame_name)
                frame_names[layer_name][f"{state}_{direction}"].append(frame_name)
            frame_names["base"][f"{state}_{direction}"].append(frame_name)
            stats["frames"] += 1
            stats["repaired"] += repair_stats["repaired"]
            stats["ear_transparent"] += repair_stats["ear_transparent"]
            stats["feature_pixels"] += repair_stats["removed"]

        for component, names in frame_names.items():
            write_component_json(component_dirs[component], component, names)
        make_preview(variant_dir, plan["id"], args.face_id)
        manifest["variants"].append({
            "id": plan["id"],
            "label": plan["label"],
            "seed": variant_seed,
            "eye_mode": plan["eye_mode"],
            "stats": stats,
        })

    with (args.output_dir / "manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    generate(parse_args())
