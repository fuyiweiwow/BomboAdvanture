"""Apply shared reference-pixel eye shapes to the male and female front bases."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

try:
    from .random_face_pipeline import build_eye_variant_layers
    from .reference_face_pipeline import (
        ANNOTATIONS_PATH,
        PROJECT_ROOT,
        SOURCE_DIR as REFERENCE_SOURCE_DIR,
        build_reference_layers,
        load_annotations,
        load_source_frame,
    )
except ImportError:  # Support running this file by absolute path.
    from random_face_pipeline import build_eye_variant_layers  # type: ignore
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
ROLES = ("male", "female")
FACE_IDS = {"male": "face10101", "female": "Face10701"}
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


def _compose(base: Image.Image, layers: list[Image.Image]) -> Image.Image:
    result = base.copy()
    for layer in layers:
        result.alpha_composite(layer)
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
            brow = _load_base_component(bases_root, role, "brow")
            ear = _load_base_component(bases_root, role, "ear")
            eye_layers = build_eye_variant_layers(reference, factors)
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
        "is a slightly rounder open-eye form.\n",
        encoding="utf-8",
    )
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate shared eye variants for front bases")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--bases-dir", default=str(DEFAULT_BASES_DIR))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    manifest = generate_eye_variants(args.output_dir, args.bases_dir)
    print(json.dumps({"output_dir": args.output_dir, "variants": manifest["variants"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
