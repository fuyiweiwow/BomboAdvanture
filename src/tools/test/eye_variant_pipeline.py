"""Apply shared reference-pixel eye shapes to the male and female front bases."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from types import SimpleNamespace

from PIL import Image

try:
    from .random_face_pipeline import build_eye_variant_layers, build_frame_eye_variant_layers
    from .reference_face_pipeline import (
        ANNOTATIONS_PATH,
        PROJECT_ROOT,
        SOURCE_DIR as REFERENCE_SOURCE_DIR,
        build_reference_layers,
        load_annotations,
        load_source_frame,
    )
except ImportError:  # Support running this file by absolute path.
    from random_face_pipeline import (  # type: ignore
        build_eye_variant_layers,
        build_frame_eye_variant_layers,
    )
    from reference_face_pipeline import (  # type: ignore
        ANNOTATIONS_PATH,
        PROJECT_ROOT,
        SOURCE_DIR as REFERENCE_SOURCE_DIR,
        build_reference_layers,
        load_annotations,
        load_source_frame,
    )


DEFAULT_BASES_DIR = PROJECT_ROOT / "assets" / "test" / "face_bases_v1"
DEFAULT_OUTPUT = PROJECT_ROOT / "assets" / "test" / "face_eye_variants_v1"
DEFAULT_FULL_OUTPUT = PROJECT_ROOT / "assets" / "test" / "face_eye_variants_full_v1"
DEFAULT_EXAGGERATED_OUTPUT = PROJECT_ROOT / "assets" / "test" / "face_eye_exaggerated_v1"
ROLES = ("male", "female")
FACE_IDS = {"male": "face10101", "female": "Face10701"}
DIRECTION_INDEX = {"R": "0", "U": "1", "L": "2", "D": "3"}
FRAME_PATTERN = re.compile(r"_(stand|walk)_([DLRU])_(\d+)\.png$", re.IGNORECASE)
VARIANTS = {
    "set_a_reference_open": {
        "eye_scale_x": 1.0,
        "eye_scale_y": 1.0,
        "eye_tilt": 0,
        "eye_shift_x": 0,
    },
    "set_b_round_open": {
        "eye_scale_x": 1.1,
        "eye_scale_y": 1.15,
        "eye_tilt": 0,
        "eye_shift_x": 0,
    },
}
EXAGGERATED_VARIANTS = {
    "set_c_exaggerated": {
        "eye_scale_x": 1.25,
        "eye_scale_y": 1.30,
        "eye_tilt": 0,
        "eye_shift_x": 0,
        "brow_curve": -3,
        "brow_lift": -2,
        "brow_weight": 1,
        "eye_max_y": 29,
    },
}


def _inside_project(path: Path | str, label: str) -> Path:
    resolved = Path(path).expanduser().resolve()
    if resolved.drive.upper() != "E:":
        raise ValueError(f"{label} must be on E: drive: {resolved}")
    try:
        resolved.relative_to(PROJECT_ROOT.resolve())
    except ValueError as error:
        raise ValueError(f"{label} must stay under {PROJECT_ROOT}") from error
    return resolved


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _load_base_component(bases_dir: Path, role: str, component: str) -> Image.Image:
    filename = f"{FACE_IDS[role]}_stand_D_0.png"
    path = bases_dir / role / component / filename
    if not path.is_file():
        raise FileNotFoundError(f"missing {role} {component} base: {path}")
    return Image.open(path).convert("RGBA")


def _parse_frame_name(filename: str) -> tuple[str, str, int]:
    match = FRAME_PATTERN.search(filename)
    if match is None:
        raise ValueError(f"unsupported base frame name: {filename}")
    state, direction, frame = match.groups()
    return state.lower(), direction.upper(), int(frame)


def _frame_sort_key(path: Path) -> tuple[int, int, int, str]:
    state, direction, frame = _parse_frame_name(path.name)
    return (
        0 if state == "stand" else 1,
        ("D", "L", "R", "U").index(direction),
        frame,
        path.name,
    )


def _load_frame_component(bases_dir: Path, role: str, component: str, filename: str) -> Image.Image:
    path = bases_dir / role / component / filename
    if not path.is_file():
        raise FileNotFoundError(f"missing {role} {component} frame: {path}")
    return Image.open(path).convert("RGBA")


def _load_reference_frame(role: str, filename: str) -> Image.Image:
    state, direction, frame = _parse_frame_name(filename)
    source_name = f"{FACE_IDS[role]}_{state}_{DIRECTION_INDEX[direction]}_{frame}.png"
    path = REFERENCE_SOURCE_DIR / source_name
    if not path.is_file():
        raise FileNotFoundError(f"missing reference frame: {path}")
    return Image.open(path).convert("RGBA")


def _write_catalog_preview(images: list[tuple[str, Image.Image]], path: Path) -> Image.Image:
    tile_width, tile_height = 144, 136
    columns = 7
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGBA", (tile_width * columns, tile_height * rows), (24, 24, 30, 255))
    for index, (_filename, image) in enumerate(images):
        sheet.alpha_composite(image, ((index % columns) * tile_width, (index // columns) * tile_height))
    _save_png(sheet, path)
    return sheet


def _compose(base: Image.Image, layers: list[Image.Image]) -> Image.Image:
    result = base.copy()
    for layer in layers:
        result.alpha_composite(layer)
    return result


def _build_brow_variant(source: Image.Image, factors: dict[str, float | int]) -> Image.Image:
    """Apply optional expressive brow factors while preserving the source palette."""
    if "brow_curve" not in factors:
        return source.copy()

    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    result_pixels = result.load()
    points = [
        (x, y)
        for y in range(source.height)
        for x in range(source.width)
        if source_pixels[x, y][3] > 0
    ]
    for side_points in (
        [point for point in points if point[0] < source.width / 2],
        [point for point in points if point[0] >= source.width / 2],
    ):
        if not side_points:
            continue
        center_x = (min(x for x, _ in side_points) + max(x for x, _ in side_points)) / 2
        for x, y in side_points:
            dx = x - center_x
            ny = y + int(factors.get("brow_lift", 0)) + round(int(factors["brow_curve"]) * (dx * dx) / 16)
            if 0 <= ny < result.height:
                result_pixels[x, ny] = source_pixels[x, y]
                if int(factors.get("brow_weight", 0)):
                    thick_y = min(result.height - 1, ny + 1)
                    result_pixels[x, thick_y] = source_pixels[x, y]
    return result


def _clip_eye_layers(eye_layers: dict[str, Image.Image], factors: dict[str, float | int]) -> None:
    max_y = factors.get("eye_max_y")
    if max_y is None:
        return
    limit = int(max_y)
    for layer in eye_layers.values():
        pixels = layer.load()
        for y in range(max(0, limit + 1), layer.height):
            for x in range(layer.width):
                pixels[x, y] = (0, 0, 0, 0)


def _component_palette(reference, field: str) -> list[tuple[int, int, int, int]]:
    pixels = reference.layers["eye"].load()
    colors = {
        pixels[x, y]
        for x, y in reference.raw_masks[field]
        if pixels[x, y][3] > 0
    }
    return sorted(colors, key=lambda color: sum(color[:3])) or [(255, 255, 255, 255)]


def _recolor_frame_eye(reference, canonical_reference) -> Image.Image:
    """Keep a frame's eye geometry while replacing its palette with the front palette."""
    source = reference.layers["eye"]
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    result_pixels = result.load()
    for field in ("sclera", "iris", "pupil", "highlight", "lash"):
        palette = _component_palette(canonical_reference, field)
        for x, y in reference.raw_masks[field]:
            source_pixel = source_pixels[x, y]
            if source_pixel[3] == 0:
                continue
            source_luminance = sum(source_pixel[:3])
            target = min(palette, key=lambda color: abs(sum(color[:3]) - source_luminance))
            result_pixels[x, y] = target
    return result


def _iris_center(reference, left: bool) -> tuple[float, float] | None:
    split = reference.layers["eye"].width / 2
    points = [point for point in reference.raw_masks["iris"] if (point[0] < split) == left]
    if not points:
        return None
    return (
        (min(x for x, _ in points) + max(x for x, _ in points)) / 2,
        (min(y for _, y in points) + max(y for _, y in points)) / 2,
    )


def _shift_layer_side(
    source: Image.Image,
    target_size: tuple[int, int],
    left: bool,
    dx: int,
    dy: int,
) -> Image.Image:
    result = Image.new("RGBA", target_size, (0, 0, 0, 0))
    source_pixels = source.load()
    result_pixels = result.load()
    split = source.width / 2
    for y in range(source.height):
        for x in range(source.width):
            if (x < split) != left:
                continue
            pixel = source_pixels[x, y]
            nx, ny = x + dx, y + dy
            if pixel[3] > 0 and 0 <= nx < result.width and 0 <= ny < result.height:
                result_pixels[nx, ny] = pixel
    return result


def _build_anchored_eye_layers(canonical_reference, canonical_layers, target_reference) -> dict[str, Image.Image]:
    """Place the canonical front eye on a D-facing frame using its annotated iris centers."""
    target_size = target_reference.layers["eye"].size
    layers = {
        name: Image.new("RGBA", target_size, (0, 0, 0, 0))
        for name in ("eye_geometry", "pupil", "highlight")
    }
    for left in (True, False):
        canonical_center = _iris_center(canonical_reference, left)
        target_center = _iris_center(target_reference, left)
        if canonical_center is None or target_center is None:
            continue
        dx = round(target_center[0] - canonical_center[0])
        dy = round(target_center[1] - canonical_center[1])
        for name in layers:
            layers[name].alpha_composite(
                _shift_layer_side(canonical_layers[name], target_size, left, dx, dy)
            )
    eye = layers["eye_geometry"].copy()
    eye.alpha_composite(layers["pupil"])
    eye.alpha_composite(layers["highlight"])
    layers["eye"] = eye
    return layers


def _build_anchored_brow(canonical_brow: Image.Image, canonical_reference, target_reference) -> Image.Image:
    result = Image.new("RGBA", target_reference.layers["eye"].size, (0, 0, 0, 0))
    canonical_pixels = canonical_brow.load()
    result_pixels = result.load()
    for left in (True, False):
        canonical_center = _iris_center(canonical_reference, left)
        target_center = _iris_center(target_reference, left)
        if canonical_center is None or target_center is None:
            continue
        dx = round(target_center[0] - canonical_center[0])
        dy = round(target_center[1] - canonical_center[1])
        split = canonical_brow.width / 2
        for y in range(canonical_brow.height):
            for x in range(canonical_brow.width):
                if (x < split) != left:
                    continue
                pixel = canonical_pixels[x, y]
                nx, ny = x + dx, y + dy
                if pixel[3] > 0 and 0 <= nx < result.width and 0 <= ny < result.height:
                    result_pixels[nx, ny] = pixel
    return result


def generate_eye_variants(
    output_dir: Path | str = DEFAULT_OUTPUT,
    bases_dir: Path | str = DEFAULT_BASES_DIR,
) -> dict:
    output_root = _inside_project(output_dir, "output-dir")
    bases_root = _inside_project(bases_dir, "bases-dir")
    annotations = load_annotations(ANNOTATIONS_PATH)
    reference_source = load_source_frame("male", "stand", "D", 0, REFERENCE_SOURCE_DIR)
    reference = build_reference_layers(
        reference_source,
        annotations["stand_D_0"],
        normalize_front_ears=True,
    )

    previews: dict[tuple[str, str], Image.Image] = {}
    for variant_name, factors in VARIANTS.items():
        variant_dir = output_root / variant_name
        for role in ROLES:
            base = _load_base_component(bases_root, role, "base")
            brow = _build_brow_variant(_load_base_component(bases_root, role, "brow"), factors)
            ear = _load_base_component(bases_root, role, "ear")
            eye_layers = build_eye_variant_layers(reference, factors)
            _clip_eye_layers(eye_layers, factors)
            composite = _compose(base, [eye_layers["eye"], brow, ear])

            role_dir = variant_dir / role
            _save_png(base, role_dir / "base.png")
            for layer_name in ("eye_geometry", "pupil", "highlight", "eye"):
                _save_png(eye_layers[layer_name], role_dir / f"{layer_name}.png")
            _save_png(brow, role_dir / "brow.png")
            _save_png(ear, role_dir / "ear.png")
            _save_png(composite, role_dir / "composite.png")
            preview = composite.resize((composite.width * 4, composite.height * 4), Image.Resampling.NEAREST)
            _save_png(preview, role_dir / "preview.png")
            (role_dir / "factors.json").write_text(
                json.dumps(factors, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            previews[(variant_name, role)] = preview

    tile_width, tile_height = 144, 136
    sheet = Image.new("RGBA", (tile_width * len(VARIANTS), tile_height * len(ROLES)), (24, 24, 30, 255))
    for column, variant_name in enumerate(VARIANTS):
        for row, role in enumerate(ROLES):
            sheet.alpha_composite(previews[(variant_name, role)], (column * tile_width, row * tile_height))
    _save_png(sheet, output_root / "eye_variants_preview.png")

    manifest = {
        "generator_version": "eye_variant_pipeline_v1",
        "source_reference": "assets/img/face/face10101_stand_3_0.png",
        "base_source": "assets/test/face_bases_v1",
        "source_frame": "stand_D_0",
        "roles": list(ROLES),
        "variants": list(VARIANTS),
        "variant_factors": VARIANTS,
        "eye_layers": ["eye_geometry", "pupil", "highlight", "eye"],
        "size": {"width": 36, "height": 34},
    }
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (output_root / "README.md").write_text(
        "# Shared eye variant comparison\n\n"
        "Two controlled shapes use the same original reference-pixel eye. The eye is "
        "applied to the male and female front bases without changing their base pixels, "
        "brows, ears, or the female blush. Set A keeps the reference proportion; Set B "
        "is a slightly rounder open-eye form. Highlights stay on the left side of each "
        "iris rather than being horizontally mirrored.\n",
        encoding="utf-8",
    )
    return manifest


def generate_full_eye_variants(
    output_dir: Path | str = DEFAULT_FULL_OUTPUT,
    bases_dir: Path | str = DEFAULT_BASES_DIR,
    variants: dict[str, dict[str, float | int]] | None = None,
) -> dict:
    """Generate a selected eye-variant catalog for every extracted male/female frame."""
    output_root = _inside_project(output_dir, "output-dir")
    bases_root = _inside_project(bases_dir, "bases-dir")
    variant_catalog = VARIANTS if variants is None else variants
    annotations = load_annotations(ANNOTATIONS_PATH)
    canonical_reference = build_reference_layers(
        _load_reference_frame("male", "face10101_stand_D_0.png"),
        annotations["stand_D_0"],
        normalize_front_ears=False,
    )
    preview_catalogs: dict[tuple[str, str], Image.Image] = {}
    frame_count: dict[str, dict[str, int]] = {}

    for variant_name, factors in variant_catalog.items():
        frame_count[variant_name] = {}
        canonical_eye_layers = build_eye_variant_layers(canonical_reference, factors)
        _clip_eye_layers(canonical_eye_layers, factors)
        for role in ROLES:
            base_dir = bases_root / role / "base"
            frame_paths = sorted(base_dir.glob("*.png"), key=_frame_sort_key)
            if len(frame_paths) != 28:
                raise ValueError(f"expected 28 base frames for {role}, got {len(frame_paths)}")
            role_dir = output_root / variant_name / role
            catalog_images: list[tuple[str, Image.Image]] = []
            front_filename = f"{FACE_IDS[role]}_stand_D_0.png"
            canonical_brow = _build_brow_variant(
                _load_frame_component(bases_root, role, "brow", front_filename),
                factors,
            )

            for base_path in frame_paths:
                filename = base_path.name
                state, direction, frame = _parse_frame_name(filename)
                annotation_key = f"{state}_{direction}_{frame}"
                reference_source = _load_reference_frame("male", filename)
                reference = build_reference_layers(
                    reference_source,
                    annotations.get(annotation_key, {}),
                    normalize_front_ears=False,
                )
                if direction == "D":
                    eye_layers = _build_anchored_eye_layers(
                        canonical_reference,
                        canonical_eye_layers,
                        reference,
                    )
                else:
                    recolored_reference = SimpleNamespace(
                        layers={**reference.layers, "eye": _recolor_frame_eye(reference, canonical_reference)},
                        raw_masks=reference.raw_masks,
                    )
                    eye_layers = build_frame_eye_variant_layers(recolored_reference, factors)
                    _clip_eye_layers(eye_layers, factors)

                base = Image.open(base_path).convert("RGBA")
                if direction == "D":
                    brow = _build_anchored_brow(canonical_brow, canonical_reference, reference)
                else:
                    brow = _build_brow_variant(_load_frame_component(bases_root, role, "brow", filename), factors)
                ear = _load_frame_component(bases_root, role, "ear", filename)
                composite = _compose(base, [eye_layers["eye"], brow, ear])
                frame_dir = role_dir
                _save_png(base, frame_dir / "base" / filename)
                for layer_name in ("eye_geometry", "pupil", "highlight", "eye"):
                    _save_png(eye_layers[layer_name], frame_dir / layer_name / filename)
                _save_png(brow, frame_dir / "brow" / filename)
                _save_png(ear, frame_dir / "ear" / filename)
                _save_png(composite, frame_dir / "composite" / filename)
                preview = composite.resize((composite.width * 4, composite.height * 4), Image.Resampling.NEAREST)
                _save_png(preview, frame_dir / "preview" / "frames" / filename)
                catalog_images.append((filename, preview))

            preview_catalogs[(variant_name, role)] = _write_catalog_preview(
                catalog_images,
                role_dir / "preview" / "catalog.png",
            )
            frame_count[variant_name][role] = len(frame_paths)
            (role_dir / "factors.json").write_text(
                json.dumps(factors, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )

    catalog_width, catalog_height = 1008, 544
    sheet = Image.new("RGBA", (catalog_width * len(variant_catalog), catalog_height * len(ROLES)), (24, 24, 30, 255))
    for column, variant_name in enumerate(variant_catalog):
        for row, role in enumerate(ROLES):
            sheet.alpha_composite(
                preview_catalogs[(variant_name, role)],
                (column * catalog_width, row * catalog_height),
            )
    _save_png(sheet, output_root / "full_face_variants_preview.png")

    manifest = {
        "generator_version": "eye_variant_pipeline_v2",
        "source_reference": "assets/img/face/face10101_*.png",
        "base_source": "assets/test/face_bases_v1",
        "frame_count": frame_count,
        "roles": list(ROLES),
        "variants": list(variant_catalog),
        "variant_factors": variant_catalog,
        "eye_layers": ["eye_geometry", "pupil", "highlight", "eye"],
        "gpu_required": False,
        "size": {"width": 36, "height": 34},
        "frame_eye_strategy": "D frames use canonical front eye anchored by annotated iris centers; side frames preserve geometry and use the canonical front palette",
        "brow_strategy": "D frames use canonical front brows translated by the same iris-center offsets",
    }
    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (output_root / "README.md").write_text(
        "# Full face eye variant comparison\n\n"
        "Each set contains 28 frames for both male and female bases: standing and walking "
        "frames in all four directions. The front standing frame uses stable mirrored eye "
        "geometry. D-facing motion frames reuse the canonical front eye palette and geometry "
        "and move each eye by its annotated iris center. Side-facing frames preserve their "
        "visible geometry but use the canonical front palette. Brows on D-facing frames use "
        "the same iris-center translation. Back-facing frames keep transparent eye layers. "
        "Generation is deterministic CPU-only Pillow processing; no GPU or model runtime is "
        "required.\n",
        encoding="utf-8",
    )
    return manifest


def generate_exaggerated_eye_variants(
    output_dir: Path | str = DEFAULT_EXAGGERATED_OUTPUT,
    bases_dir: Path | str = DEFAULT_BASES_DIR,
) -> dict:
    """Generate one expressive eye-and-brow style for both face roles."""
    output_root = _inside_project(output_dir, "output-dir")
    manifest = generate_full_eye_variants(output_root, bases_dir, EXAGGERATED_VARIANTS)
    manifest["generator_version"] = "eye_variant_pipeline_v3_exaggerated"
    manifest["style"] = {
        "eye": "larger round open eye with reference-pixel geometry",
        "brow": "raised, thick, strongly arched brow",
        "highlight": "left side of each iris, never horizontally mirrored",
    }
    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (output_root / "README.md").write_text(
        "# Exaggerated face eye-and-brow variant\n\n"
        "This directory contains one expressive style for both male and female bases. "
        "Eyes are enlarged from the reference-pixel structure; brows are raised, thicker, "
        "and more strongly arched. D-facing motion frames reuse the front eye and brow "
        "anchors; side-facing frames preserve geometry but use the front eye palette. Each "
        "visible iris keeps its highlight on its own left side; highlights are never "
        "horizontally mirrored. The generation is deterministic CPU-only Pillow processing "
        "and includes 28 frames per role.\n",
        encoding="utf-8",
    )
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate shared eye variants for front bases")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--bases-dir", default=str(DEFAULT_BASES_DIR))
    parser.add_argument("--full", action="store_true", help="generate all 28 frames for both roles")
    parser.add_argument("--exaggerated", action="store_true", help="generate one expressive eye-and-brow style")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.exaggerated:
        manifest = generate_exaggerated_eye_variants(args.output_dir, args.bases_dir)
    elif args.full:
        manifest = generate_full_eye_variants(args.output_dir, args.bases_dir)
    else:
        manifest = generate_eye_variants(args.output_dir, args.bases_dir)
    print(json.dumps({"output_dir": args.output_dir, "variants": manifest["variants"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
