"""Extract exact face-base and feature layers from the original face sprites.

This pipeline is intentionally non-generative: every non-transparent output
pixel is copied from the source sprite. Unmarked pixels stay in the base layer
instead of being repaired or filled.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

from PIL import Image


ROOT = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
SOURCE_DIR = ROOT / "assets" / "img" / "face"
ANNOTATIONS_PATH = ROOT / "assets" / "test" / "male_face_v2" / "annotations.json"
DEFAULT_OUTPUT = ROOT / "assets" / "test" / "face_bases_v1"

FACE_VARIANTS = {
    "male": {"id": "face10101", "preserve_blush": False},
    "female": {"id": "Face10701", "preserve_blush": True},
}

DIRECTION_BY_INDEX = {"0": "R", "1": "U", "2": "L", "3": "D"}
FEATURE_FOLDERS = (
    "eye_sclera",
    "eye_iris",
    "eye_pupil",
    "eye_highlight",
    "lash",
    "brow",
    "ear",
    "blush",
)
REQUIRED_FEATURES = {
    "eye_sclera": "sclera",
    "eye_iris": "iris",
    "eye_pupil": "pupil",
    "eye_highlight": "highlight",
    "lash": "lash",
    "brow": "brow",
    "ear": "ear",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=SOURCE_DIR)
    parser.add_argument("--annotations", type=Path, default=ANNOTATIONS_PATH)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--face",
        action="append",
        choices=("male", "female"),
        help="Extract only one role; repeat to select both.",
    )
    return parser.parse_args()


def load_annotations(path: Path) -> dict[str, dict]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def frame_key(path: Path, face_id: str) -> tuple[str, str, int] | None:
    match = re.fullmatch(
        re.escape(face_id) + r"_(stand|walk)_([0-3])_(\d+)\.png",
        path.name,
        flags=re.IGNORECASE,
    )
    if not match:
        return None
    state, direction_index, frame_text = match.groups()
    return state, DIRECTION_BY_INDEX[direction_index], int(frame_text)


def list_source_frames(source_dir: Path, face_id: str) -> list[tuple[Path, str]]:
    records: list[tuple[Path, str]] = []
    for path in source_dir.glob(f"{face_id}_*.png"):
        parsed = frame_key(path, face_id)
        if parsed is None:
            continue
        state, direction, frame = parsed
        records.append((path, f"{state}_{direction}_{frame}"))
    return sorted(records, key=lambda item: (item[1].split("_")[0], item[1].split("_")[1], int(item[1].split("_")[-1])))


def points(value: object) -> set[tuple[int, int]]:
    if not isinstance(value, list):
        return set()
    result: set[tuple[int, int]] = set()
    for item in value:
        if isinstance(item, list) and len(item) == 2:
            result.add((int(item[0]), int(item[1])))
    return result


def annotated_masks(annotation: dict) -> dict[str, set[tuple[int, int]]]:
    feature_data = annotation.get("feat", {})
    masks = {
        folder: points(feature_data.get(annotation_name, []))
        for folder, annotation_name in REQUIRED_FEATURES.items()
    }
    masks["blush"] = set()
    return masks


def is_pink_blush(pixel: tuple[int, int, int, int], x: int, y: int, width: int) -> bool:
    r, g, b, alpha = pixel
    if alpha < 128 or y < 20 or y > 31:
        return False
    in_left_cheek = 6 <= x <= min(14, width - 1)
    in_right_cheek = max(0, width - 15) <= x <= width - 7
    return (in_left_cheek or in_right_cheek) and r >= 180 and r - g >= 35 and b - g >= 5


def detect_blush(
    image: Image.Image,
    feature_points: set[tuple[int, int]],
    preserve_blush: bool,
) -> set[tuple[int, int]]:
    if not preserve_blush:
        return set()
    px = image.load()
    return {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if (x, y) not in feature_points and is_pink_blush(px[x, y], x, y, image.width)
    }


def make_layer(image: Image.Image, selected: set[tuple[int, int]]) -> Image.Image:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source_px = image.load()
    layer_px = layer.load()
    for x, y in selected:
        if 0 <= x < image.width and 0 <= y < image.height:
            pixel = source_px[x, y]
            if pixel[3] >= 1:
                layer_px[x, y] = pixel
    return layer


def make_base(image: Image.Image, removed: set[tuple[int, int]]) -> Image.Image:
    base = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source_px = image.load()
    base_px = base.load()
    for y in range(image.height):
        for x in range(image.width):
            if (x, y) in removed:
                continue
            pixel = source_px[x, y]
            if pixel[3] >= 1:
                base_px[x, y] = pixel
    return base


def make_mask(image: Image.Image, masks: dict[str, set[tuple[int, int]]]) -> Image.Image:
    colors = {
        "eye_sclera": (245, 245, 245, 255),
        "eye_iris": (55, 155, 220, 255),
        "eye_pupil": (30, 30, 45, 255),
        "eye_highlight": (255, 255, 255, 255),
        "lash": (105, 70, 120, 255),
        "brow": (230, 185, 65, 255),
        "ear": (80, 190, 130, 255),
        "blush": (245, 90, 125, 255),
    }
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result_px = result.load()
    for name in FEATURE_FOLDERS:
        for x, y in masks[name]:
            if 0 <= x < image.width and 0 <= y < image.height:
                result_px[x, y] = colors[name]
    return result


def write_component_metadata(folder: Path, component: str, names_by_key: dict[str, list[str]]) -> None:
    data = {"NAME": component, "INTERVAL": 100}
    for direction in ("R", "U", "L", "D"):
        for prefix, key in (("STAND", f"stand_{direction}"), (direction, f"walk_{direction}")):
            names = sorted(names_by_key.get(key, []), key=lambda name: int(Path(name).stem.split("_")[-1]))
            data[prefix] = {"IMG": names, "CX": [0] * len(names), "CY": [0] * len(names)}
    with (folder / f"{component}.json").open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)


def make_preview(face_dir: Path, face_id: str, records: list[tuple[Path, str]]) -> None:
    selected = [record for record in records if record[1].startswith("stand_")]
    selected.sort(key=lambda item: (item[1].split("_")[1], item[1]))
    scale = 8
    tile = (36 * scale, 34 * scale)
    sheet = Image.new("RGBA", (tile[0] * max(1, len(selected)), tile[1] * 4), (40, 40, 48, 255))
    for column, (_, key) in enumerate(selected):
        stem = f"{face_id}_{key.replace('_', '_')}.png"
        for row, folder in enumerate(("original", "base", "composite", "mask")):
            path = face_dir / folder / stem
            if not path.exists():
                continue
            image = Image.open(path).convert("RGBA").resize(tile, Image.Resampling.NEAREST)
            sheet.alpha_composite(image, (column * tile[0], row * tile[1]))
    preview_dir = face_dir / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    sheet.save(preview_dir / f"{face_id}_stand_extraction.png")


def extract_face(role: str, face_id: str, preserve_blush: bool, source_dir: Path, annotations: dict, output_dir: Path) -> dict:
    face_dir = output_dir / role
    folders = ("original", "base", "base_no_blush", "composite", "mask", *FEATURE_FOLDERS)
    for folder in folders:
        (face_dir / folder).mkdir(parents=True, exist_ok=True)

    names_by_component: dict[str, dict[str, list[str]]] = {
        component: defaultdict(list) for component in ("base", "base_no_blush", *FEATURE_FOLDERS, "composite")
    }
    frame_stats = []
    records = list_source_frames(source_dir, face_id)
    if not records:
        raise FileNotFoundError(f"No frames found for {face_id} in {source_dir}")

    for source_path, key in records:
        annotation = annotations.get(key, {})
        image = Image.open(source_path).convert("RGBA")
        masks = annotated_masks(annotation)
        all_feature_points = set().union(*(masks[name] for name in REQUIRED_FEATURES))
        masks["blush"] = detect_blush(image, all_feature_points, preserve_blush)
        removed_points = set().union(*(masks[name] for name in REQUIRED_FEATURES))
        base = make_base(image, removed_points)
        base_no_blush = make_base(image, removed_points | masks["blush"])
        layers = {name: make_layer(image, masks[name]) for name in FEATURE_FOLDERS}
        composite = base.copy()
        for name in FEATURE_FOLDERS:
            if name == "blush":
                continue
            composite = Image.alpha_composite(composite, layers[name])
        mask = make_mask(image, masks)

        output_name = f"{face_id}_{key}.png"
        image.save(face_dir / "original" / output_name)
        base.save(face_dir / "base" / output_name)
        base_no_blush.save(face_dir / "base_no_blush" / output_name)
        composite.save(face_dir / "composite" / output_name)
        mask.save(face_dir / "mask" / output_name)
        for name, layer in layers.items():
            layer.save(face_dir / name / output_name)

        for component in names_by_component:
            names_by_component[component][key].append(output_name)

        original_pixels = list(image.getdata())
        composite_pixels = list(composite.getdata())
        mismatch = sum(1 for left, right in zip(original_pixels, composite_pixels) if left != right)
        frame_stats.append(
            {
                "frame": key,
                "source": str(source_path),
                "size": [image.width, image.height],
                "source_opaque_pixels": sum(1 for pixel in original_pixels if pixel[3] >= 1),
                "base_opaque_pixels": sum(1 for pixel in base.getdata() if pixel[3] >= 1),
                "removed_feature_pixels": len(removed_points),
                "blush_pixels": len(masks["blush"]),
                "reconstruction_mismatch_pixels": mismatch,
                "annotation_present": bool(annotation),
            }
        )

    for component, names in names_by_component.items():
        write_component_metadata(face_dir / component, component, names)
    make_preview(face_dir, face_id, records)
    return {
        "role": role,
        "face_id": face_id,
        "preserve_blush_in_base": preserve_blush,
        "frame_count": len(records),
        "frames": frame_stats,
    }


def main() -> None:
    args = parse_args()
    selected_roles = args.face or ["male", "female"]
    annotations = load_annotations(args.annotations)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "pipeline": "face_base_extraction_v1",
        "ai_used": False,
        "fill_or_repair_used": False,
        "source_pixel_policy": "copy source RGBA pixels only; unmarked pixels remain in base",
        "annotation_file": str(args.annotations),
        "source_dir": str(args.source_dir),
        "selected_faces": {},
    }
    for role in selected_roles:
        config = FACE_VARIANTS[role]
        result = extract_face(
            role,
            config["id"],
            config["preserve_blush"],
            args.source_dir,
            annotations,
            args.output_dir,
        )
        manifest["selected_faces"][role] = result
    with (args.output_dir / "manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
