"""Build pixel-faithful face references from the original face sprites."""

from __future__ import annotations

import argparse
import copy
import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
SOURCE_DIR = PROJECT_ROOT / "assets" / "img" / "face"
ANNOTATIONS_PATH = PROJECT_ROOT / "assets" / "test" / "male_face_v2" / "annotations.json"
DEFAULT_OUTPUT = PROJECT_ROOT / "assets" / "test" / "face_reference_v2"

DIRECTION_BY_INDEX = {"R": "0", "U": "1", "L": "2", "D": "3"}
INDEX_BY_DIRECTION = {value: key for key, value in DIRECTION_BY_INDEX.items()}
ROLE_CONFIG = {
    "male": {"face_id": "face10101", "preserve_blush": False},
}
FEATURE_FIELDS = ("sclera", "iris", "pupil", "highlight", "lash", "brow", "ear")
EYE_FIELDS = ("sclera", "iris", "pupil", "highlight", "lash")


@dataclass
class ReferenceLayerResult:
    layers: dict[str, Image.Image]
    reference_mismatch: int
    normalized_mismatch: int
    raw_masks: dict[str, set[tuple[int, int]]]
    normalized_ear: set[tuple[int, int]]


def _inside_project(path: Path | str, label: str) -> Path:
    resolved = Path(path).expanduser().resolve()
    if resolved.drive.upper() != "E:":
        raise ValueError(f"{label} must be on E: drive: {resolved}")
    try:
        resolved.relative_to(PROJECT_ROOT.resolve())
    except ValueError as error:
        raise ValueError(f"{label} must stay under {PROJECT_ROOT}") from error
    return resolved


def source_frame_name(face_id: str, state: str, direction: str, frame: int) -> str:
    try:
        direction_index = DIRECTION_BY_INDEX[direction]
    except KeyError as error:
        raise ValueError(f"unsupported direction: {direction}") from error
    if state not in ("stand", "walk"):
        raise ValueError(f"unsupported state: {state}")
    return f"{face_id}_{state}_{direction_index}_{int(frame)}.png"


def annotation_key(state: str, direction: str, frame: int) -> str:
    return f"{state}_{direction}_{int(frame)}"


def load_annotations(path: Path | str = ANNOTATIONS_PATH) -> dict:
    with Path(path).open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_source_frame(
    role: str,
    state: str,
    direction: str,
    frame: int,
    source_dir: Path | str = SOURCE_DIR,
) -> Image.Image:
    config = ROLE_CONFIG[role]
    path = Path(source_dir) / source_frame_name(config["face_id"], state, direction, frame)
    return Image.open(path).convert("RGBA")


def _points(value: object, width: int, height: int) -> set[tuple[int, int]]:
    if not isinstance(value, list):
        return set()
    result = set()
    for item in value:
        if isinstance(item, list) and len(item) == 2:
            x, y = int(item[0]), int(item[1])
            if 0 <= x < width and 0 <= y < height:
                result.add((x, y))
    return result


def _feature_masks(annotation: dict, width: int, height: int) -> dict[str, set[tuple[int, int]]]:
    feature_data = annotation.get("feat", {})
    return {
        name: _points(feature_data.get(name, []), width, height)
        for name in FEATURE_FIELDS
    }


def _mirror(points: set[tuple[int, int]], width: int) -> set[tuple[int, int]]:
    return {(width - 1 - x, y) for x, y in points}


def _make_layer(source: Image.Image, points: set[tuple[int, int]]) -> Image.Image:
    layer = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    layer_pixels = layer.load()
    for x, y in points:
        pixel = source_pixels[x, y]
        if pixel[3] > 0:
            layer_pixels[x, y] = pixel
    return layer


def _remove(source: Image.Image, points: set[tuple[int, int]]) -> Image.Image:
    result = source.copy()
    pixels = result.load()
    for x, y in points:
        pixels[x, y] = (0, 0, 0, 0)
    return result


def _skin_fallback(source: Image.Image, excluded: set[tuple[int, int]]) -> tuple[int, int, int, int]:
    candidates = []
    pixels = source.load()
    for y in range(6, min(source.height, 31)):
        for x in range(4, max(4, source.width - 4)):
            if (x, y) in excluded:
                continue
            pixel = pixels[x, y]
            if pixel[3] > 0:
                candidates.append(pixel)
    return Counter(candidates).most_common(1)[0][0] if candidates else (240, 144, 112, 255)


def _nearest_fill_color(
    source: Image.Image,
    point: tuple[int, int],
    excluded: set[tuple[int, int]],
    fallback: tuple[int, int, int, int],
) -> tuple[int, int, int, int]:
    px, py = point
    pixels = source.load()
    for radius in range(1, 10):
        candidates = []
        for y in range(max(0, py - radius), min(source.height, py + radius + 1)):
            for x in range(max(0, px - radius), min(source.width, px + radius + 1)):
                if max(abs(x - px), abs(y - py)) != radius or (x, y) in excluded:
                    continue
                pixel = pixels[x, y]
                if pixel[3] > 0:
                    candidates.append(pixel)
        if candidates:
            return Counter(candidates).most_common(1)[0][0]
    return fallback


def _fill_non_ear_features(
    base: Image.Image,
    source: Image.Image,
    masks: dict[str, set[tuple[int, int]]],
) -> Image.Image:
    result = base.copy()
    excluded = set().union(*(masks[name] for name in FEATURE_FIELDS))
    fill_points = set().union(*(masks[name] for name in FEATURE_FIELDS if name != "ear"))
    fallback = _skin_fallback(source, excluded)
    pixels = result.load()
    for point in fill_points:
        pixels[point] = _nearest_fill_color(source, point, excluded, fallback)
    return result


def _compose(base: Image.Image, layers: list[Image.Image]) -> Image.Image:
    result = base.copy()
    for layer in layers:
        result.alpha_composite(layer)
    return result


def _mismatch(left: Image.Image, right: Image.Image) -> int:
    return sum(a != b for a, b in zip(left.get_flattened_data(), right.get_flattened_data()))


def build_reference_layers(
    source: Image.Image,
    annotation: dict,
    normalize_front_ears: bool = False,
) -> ReferenceLayerResult:
    source = source.convert("RGBA")
    masks = _feature_masks(annotation, source.width, source.height)
    raw_removed = set().union(*masks.values())
    raw_base = _remove(source, raw_removed)

    normalized_ear = set(masks["ear"])
    if normalize_front_ears:
        normalized_ear |= _mirror(normalized_ear, source.width)
    normalized_masks = copy.deepcopy(masks)
    normalized_masks["ear"] = normalized_ear
    normalized_removed = set().union(*normalized_masks.values())
    clean_base = _fill_non_ear_features(_remove(source, normalized_removed), source, normalized_masks)

    eye = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for field in EYE_FIELDS:
        eye.alpha_composite(_make_layer(source, masks[field]))
    brow = _make_layer(source, masks["brow"])
    ear = _make_layer(source, masks["ear"])
    ear_normalized = _make_layer(source, normalized_ear)

    reference = _compose(raw_base, [eye, brow, ear])
    composite = _compose(clean_base, [eye, brow, ear_normalized])
    return ReferenceLayerResult(
        layers={
            "base": raw_base,
            "base_clean": clean_base,
            "eye": eye,
            "brow": brow,
            "ear": ear,
            "ear_normalized": ear_normalized,
            "reference": reference,
            "composite": composite,
        },
        reference_mismatch=_mismatch(reference, source),
        normalized_mismatch=_mismatch(composite, source),
        raw_masks=masks,
        normalized_ear=normalized_ear,
    )


def _source_records(role: str, source_dir: Path) -> list[tuple[str, str, str, int, Path]]:
    face_id = ROLE_CONFIG[role]["face_id"]
    pattern = re.compile(re.escape(face_id) + r"_(stand|walk)_([0-3])_(\d+)\.png$", re.IGNORECASE)
    records = []
    for path in source_dir.glob(f"{face_id}_*.png"):
        match = pattern.fullmatch(path.name)
        if not match:
            continue
        state, direction_index, frame_text = match.groups()
        direction = INDEX_BY_DIRECTION[direction_index]
        records.append((state, direction, annotation_key(state, direction, int(frame_text)), int(frame_text), path))
    return sorted(records, key=lambda item: (0 if item[0] == "stand" else 1, item[1], item[3]))


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def generate_reference_catalog(
    output_dir: Path | str = DEFAULT_OUTPUT,
    role: str = "male",
    source_dir: Path | str = SOURCE_DIR,
    annotations_path: Path | str = ANNOTATIONS_PATH,
) -> dict:
    if role not in ROLE_CONFIG:
        raise ValueError(f"unsupported role: {role}")
    output_root = _inside_project(output_dir, "output-dir")
    source_root = _inside_project(source_dir, "source-dir")
    annotations = load_annotations(annotations_path)
    records = _source_records(role, source_root)
    if len(records) != 28:
        raise ValueError(f"expected 28 source frames for {role}, got {len(records)}")

    frames = {}
    for state, direction, key, frame, source_path in records:
        source = Image.open(source_path).convert("RGBA")
        annotation = annotations.get(key, {})
        result = build_reference_layers(
            source,
            annotation,
            normalize_front_ears=(direction == "D" and state == "stand" and frame == 0),
        )
        frame_dir = output_root / role / key
        for name, image in result.layers.items():
            _save_png(image, frame_dir / f"{name}.png")
        _save_png(
            result.layers["composite"].resize(
                (source.width * 4, source.height * 4), Image.Resampling.NEAREST
            ),
            frame_dir / "preview.png",
        )
        frames[key] = {
            "source": source_path.relative_to(PROJECT_ROOT).as_posix(),
            "size": {"width": source.width, "height": source.height},
            "reference_mismatch_pixels": result.reference_mismatch,
            "normalized_mismatch_pixels": result.normalized_mismatch,
            "raw_ear_pixels": len(result.raw_masks["ear"]),
            "normalized_ear_pixels": len(result.normalized_ear),
            "brow_pixels": len(result.raw_masks["brow"]),
            "eye_pixels": sum(len(result.raw_masks[name]) for name in EYE_FIELDS),
            "annotation_present": bool(annotation),
        }

    manifest = {
        "generator_version": "reference_face_pipeline_v1",
        "role": role,
        "source_face_id": ROLE_CONFIG[role]["face_id"],
        "annotation_file": Path(annotations_path).resolve().relative_to(PROJECT_ROOT).as_posix(),
        "front_frame": "stand_D_0",
        "frame_count": len(frames),
        "reference_mismatch_pixels": max(frame["reference_mismatch_pixels"] for frame in frames.values()),
        "frames": frames,
    }
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (output_root / "README.md").write_text(
        "# Reference face pipeline v1\n\n"
        "This catalog replays the original male face pixels. The front reference is "
        "face10101_stand_3_0.png (stand_D_0). The clean base removes feature pixels, "
        "fills only eye/brow sockets, and keeps normalized front ears as a separate layer.\n",
        encoding="utf-8",
    )
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build pixel-faithful face reference layers")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--role", choices=tuple(ROLE_CONFIG), default="male")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    manifest = generate_reference_catalog(args.output_dir, role=args.role)
    print(json.dumps({"output_dir": args.output_dir, "frame_count": manifest["frame_count"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
