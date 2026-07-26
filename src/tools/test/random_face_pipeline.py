"""Generate deterministic random front faces from the pixel-faithful reference."""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image

try:
    from .reference_face_pipeline import (
        ANNOTATIONS_PATH,
        PROJECT_ROOT,
        SOURCE_DIR,
        build_reference_layers,
        load_annotations,
        load_source_frame,
    )
except ImportError:
    from reference_face_pipeline import (  # type: ignore
        ANNOTATIONS_PATH,
        PROJECT_ROOT,
        SOURCE_DIR,
        build_reference_layers,
        load_annotations,
        load_source_frame,
    )


DEFAULT_OUTPUT = PROJECT_ROOT / "assets" / "test" / "face_random_v2"
EYE_GEOMETRY_FIELDS = ("sclera", "iris", "lash")


def _inside_project(path: Path | str, label: str) -> Path:
    resolved = Path(path).expanduser().resolve()
    if resolved.drive.upper() != "E:":
        raise ValueError(f"{label} must be on E: drive: {resolved}")
    try:
        resolved.relative_to(PROJECT_ROOT.resolve())
    except ValueError as error:
        raise ValueError(f"{label} must stay under {PROJECT_ROOT}") from error
    return resolved


def _points(layer: Image.Image, predicate=None) -> set[tuple[int, int]]:
    points = set()
    for y in range(layer.height):
        for x in range(layer.width):
            if layer.getpixel((x, y))[3] > 0 and (predicate is None or predicate(x, y)):
                points.add((x, y))
    return points


def _center(points: set[tuple[int, int]]) -> tuple[float, float]:
    xs = [x for x, _ in points]
    ys = [y for _, y in points]
    return ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)


def _transform_eye(
    source: Image.Image,
    points: set[tuple[int, int]],
    center: tuple[float, float],
    scale_x: float,
    scale_y: float,
    tilt: int,
    shift_x: int,
) -> Image.Image:
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    cx, cy = center
    source_pixels = source.load()
    result_pixels = result.load()
    for x, y in sorted(points):
        nx = round(cx + (x - cx) * scale_x + shift_x)
        ny = round(cy + (y - cy) * scale_y + tilt * (x - cx) / 5)
        if 0 <= nx < result.width and 0 <= ny < result.height:
            result_pixels[nx, ny] = source_pixels[x, y]
    return result


def _mirror_right_half(source: Image.Image) -> Image.Image:
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    result_pixels = result.load()
    for y in range(source.height):
        for x in range(source.width // 2, source.width):
            pixel = source_pixels[x, y]
            if pixel[3] == 0:
                continue
            result_pixels[x, y] = pixel
            result_pixels[source.width - 1 - x, y] = pixel
    return result


def _transform_mirrored_geometry(
    source: Image.Image,
    points: set[tuple[int, int]],
    scale_x: float,
    scale_y: float,
    tilt: int,
    shift_x: int,
) -> Image.Image:
    right_points = {point for point in points if point[0] >= source.width / 2}
    if not right_points:
        return Image.new("RGBA", source.size, (0, 0, 0, 0))
    transformed_right = _transform_eye(
        source,
        right_points,
        _center(right_points),
        scale_x,
        scale_y,
        tilt,
        shift_x,
    )
    return _mirror_right_half(transformed_right)


def _transform_independent_details(
    source: Image.Image,
    points: set[tuple[int, int]],
    scale_x: float,
    scale_y: float,
    tilt: int,
    shift_x: int,
) -> Image.Image:
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    left_points = {point for point in points if point[0] < source.width / 2}
    right_points = {point for point in points if point[0] >= source.width / 2}
    for side_points, side_shift in ((left_points, -shift_x), (right_points, shift_x)):
        if not side_points:
            continue
        result.alpha_composite(
            _transform_eye(
                source,
                side_points,
                _center(side_points),
                scale_x,
                scale_y,
                tilt,
                side_shift,
            )
        )
    return result


def _transform_brow(source: Image.Image, curve: int, lift: int, weight: int) -> Image.Image:
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    result_pixels = result.load()
    points = _points(source)
    for x, y in points:
        center_x = 11 if x < source.width / 2 else 24
        dx = x - center_x
        ny = y + lift + round(curve * (dx * dx) / 16)
        if 0 <= ny < result.height:
            result_pixels[x, ny] = source_pixels[x, y]
            if weight:
                thick_y = min(result.height - 1, ny + 1)
                result_pixels[x, thick_y] = source_pixels[x, y]
    return result


def _random_factors(rng: random.Random) -> dict[str, float | int | str]:
    return {
        "eye_scale_x": rng.choice((0.9, 1.0, 1.1)),
        "eye_scale_y": rng.choice((0.85, 0.95, 1.0, 1.05, 1.15)),
        "eye_tilt": rng.choice((-1, 0, 1)),
        "eye_shift_x": rng.choice((-1, 0, 1)),
        "brow_curve": rng.choice((-1, 0, 1)),
        "brow_lift": rng.choice((-1, 0, 1)),
        "brow_weight": rng.choice((0, 1)),
        "ear": "reference",
    }


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def generate_random_faces(
    output_dir: Path | str = DEFAULT_OUTPUT,
    count: int = 6,
    seed: int = 20260727,
) -> dict:
    if count < 1 or count > 24:
        raise ValueError("count must be between 1 and 24")
    output_root = _inside_project(output_dir, "output-dir")
    annotations = load_annotations(ANNOTATIONS_PATH)
    source = load_source_frame("male", "stand", "D", 0, SOURCE_DIR)
    reference = build_reference_layers(source, annotations["stand_D_0"], normalize_front_ears=True)
    rng = random.Random(seed)
    tile_size = (source.width * 4, source.height * 4)
    columns = min(4, count)
    rows = math.ceil(count / columns)
    sheet = Image.new("RGBA", (tile_size[0] * columns, tile_size[1] * rows), (24, 24, 30, 255))
    samples = []
    factors_list = []
    geometry_points = set().union(*(reference.raw_masks[name] for name in EYE_GEOMETRY_FIELDS))

    for index in range(count):
        factors = _random_factors(rng)
        eye_geometry = _transform_mirrored_geometry(
            reference.layers["eye"],
            geometry_points,
            float(factors["eye_scale_x"]),
            float(factors["eye_scale_y"]),
            int(factors["eye_tilt"]),
            int(factors["eye_shift_x"]),
        )
        pupil = _transform_independent_details(
            reference.layers["eye"],
            reference.raw_masks["pupil"],
            float(factors["eye_scale_x"]),
            float(factors["eye_scale_y"]),
            int(factors["eye_tilt"]),
            int(factors["eye_shift_x"]),
        )
        highlight = _transform_independent_details(
            reference.layers["eye"],
            reference.raw_masks["highlight"],
            float(factors["eye_scale_x"]),
            float(factors["eye_scale_y"]),
            int(factors["eye_tilt"]),
            int(factors["eye_shift_x"]),
        )
        eye = eye_geometry.copy()
        eye.alpha_composite(pupil)
        eye.alpha_composite(highlight)
        brow = _transform_brow(
            reference.layers["brow"],
            int(factors["brow_curve"]),
            int(factors["brow_lift"]),
            int(factors["brow_weight"]),
        )
        composite = reference.layers["base_clean"].copy()
        composite.alpha_composite(eye)
        composite.alpha_composite(brow)
        composite.alpha_composite(reference.layers["ear_normalized"])

        sample_id = f"face_{index:02d}"
        sample_dir = output_root / sample_id
        _save_png(reference.layers["base_clean"], sample_dir / "base_clean.png")
        _save_png(eye_geometry, sample_dir / "eye_geometry.png")
        _save_png(pupil, sample_dir / "pupil.png")
        _save_png(highlight, sample_dir / "highlight.png")
        _save_png(eye, sample_dir / "eye.png")
        _save_png(brow, sample_dir / "brow.png")
        _save_png(reference.layers["ear_normalized"], sample_dir / "ear.png")
        _save_png(composite, sample_dir / "composite.png")
        _save_png(composite.resize(tile_size, Image.Resampling.NEAREST), sample_dir / "preview.png")
        (sample_dir / "factors.json").write_text(
            json.dumps(factors, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        sheet.alpha_composite(composite.resize(tile_size, Image.Resampling.NEAREST), ((index % columns) * tile_size[0], (index // columns) * tile_size[1]))
        samples.append({"id": sample_id, "factors": factors, "size": {"width": source.width, "height": source.height}})
        factors_list.append(factors)

    output_root.mkdir(parents=True, exist_ok=True)
    _save_png(sheet, output_root / "random_faces_preview.png")
    manifest = {
        "generator_version": "random_face_pipeline_v2",
        "seed": int(seed),
        "source_frame": "stand_D_0",
        "source": "assets/img/face/face10101_stand_3_0.png",
        "sample_count": count,
        "eye_layers": ["eye_geometry", "pupil", "highlight", "eye"],
        "factors": factors_list,
        "samples": samples,
    }
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (output_root / "README.md").write_text(
        "# Controlled random front faces v2\n\n"
        "These samples use the original face pixel structure as a seed. Eye geometry "
        "(sclera, iris, and lash) is transformed once and mirrored so both eyes keep the "
        "same overall size. Pupils and highlights remain separate layers and may differ "
        "between sides. All transforms are small nearest-neighbor pixel operations; the "
        "face base and human ears remain from face_reference_v2.\n",
        encoding="utf-8",
    )
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate controlled random front faces")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--count", type=int, default=6)
    parser.add_argument("--seed", type=int, default=20260727)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    manifest = generate_random_faces(args.output_dir, count=args.count, seed=args.seed)
    print(json.dumps({"output_dir": args.output_dir, "sample_count": manifest["sample_count"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
