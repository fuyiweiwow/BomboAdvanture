"""Generate one normal-resolution face sample for each approved race."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

try:
    from .face_factor_model import DEFAULT_FACTORS
    from .face_factor_raster import rasterize_variant
except ImportError:
    PROJECT_ROOT_FOR_IMPORT = Path(__file__).resolve().parents[3]
    if str(PROJECT_ROOT_FOR_IMPORT) not in sys.path:
        sys.path.insert(0, str(PROJECT_ROOT_FOR_IMPORT))
    from src.tools.test.face_factor_model import DEFAULT_FACTORS
    from src.tools.test.face_factor_raster import rasterize_variant


PROJECT_ROOT = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
DEFAULT_SOURCE = PROJECT_ROOT / "assets" / "test" / "face_bases_v1" / "male" / "base" / "face10101_stand_D_0.png"
DEFAULT_OUTPUT = PROJECT_ROOT / "assets" / "test" / "face_race_samples_v1"
RACES = ("human", "elf", "orc")
LAYERS = ("base", "socket_cover", "eye", "brow", "ear", "composite")

ORC_PALETTE = {
    "skin": (137, 148, 96, 255),
    "shadow": (91, 103, 72, 255),
    "highlight": (173, 180, 119, 255),
}


def _inside_project(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    project = PROJECT_ROOT.resolve()
    if resolved.drive.upper() != "E:":
        raise ValueError(f"{label} must be on E: drive: {resolved}")
    try:
        resolved.relative_to(project)
    except ValueError as error:
        raise ValueError(f"{label} must stay under {project}") from error
    return resolved


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _factors_for_race(race: str) -> dict[str, dict]:
    factors = copy.deepcopy(DEFAULT_FACTORS)
    factors["brow"].update(style="normal", thickness=2, curve=0)
    factors["eye"].update(size="normal", scale_x=1.0, scale_y=1.0, iris="blue", pupil_offset=[0, 0])
    if race == "human":
        factors["ear"].update(type="human", length=0, tip_raise=0, outer_spread=0)
    elif race == "elf":
        factors["ear"].update(type="elf", length=4, tip_raise=3, outer_spread=1)
    elif race == "orc":
        factors["ear"].update(type="orc", placement="top", length=3, tip_raise=3, outer_spread=0)
    else:
        raise ValueError(f"unknown race: {race}")
    return factors


def _recolor_orc_base(base: Image.Image) -> Image.Image:
    result = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for y in range(base.height):
        for x in range(base.width):
            r, g, b, alpha = base.getpixel((x, y))
            if alpha == 0:
                continue
            luminance = (r * 299 + g * 587 + b * 114) // 1000
            if luminance < 125:
                color = ORC_PALETTE["shadow"]
            elif luminance > 205:
                color = ORC_PALETTE["highlight"]
            else:
                color = ORC_PALETTE["skin"]
            result.putpixel((x, y), color)
    return result


def _clear_orc_side_ears(base: Image.Image) -> None:
    for y in range(18, min(base.height, 27)):
        for x in list(range(0, min(4, base.width))) + list(range(max(0, base.width - 4), base.width)):
            base.putpixel((x, y), (0, 0, 0, 0))


def _draw_orc_top_ears(size: tuple[int, int]) -> Image.Image:
    width, height = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for points in (
        [(8, 14), (11, 3), (15, 14), (14, 18), (9, 18)],
        [(21, 14), (25, 3), (29, 14), (28, 18), (22, 18)],
    ):
        draw.polygon(points, fill=ORC_PALETTE["shadow"])
        inner = [(x, max(0, y + 1)) for x, y in points]
        draw.polygon(inner, fill=ORC_PALETTE["skin"])
        if width and height:
            draw.line([points[1], points[0]], fill=ORC_PALETTE["shadow"], width=1)
    return layer


def _render_race(race: str, source: Image.Image, seed: int) -> tuple[Image.Image, dict[str, Image.Image], dict[str, dict], list[str]]:
    base = source.convert("RGBA")
    if race == "orc":
        base = _recolor_orc_base(base)
        _clear_orc_side_ears(base)

    factors = _factors_for_race(race)
    raster_factors = copy.deepcopy(factors)
    if race == "orc":
        # Reuse old eye/brow/socket rasterization, then replace only the ear layer.
        raster_factors["ear"].update(type="human", length=0, tip_raise=0, outer_spread=0)
    result = rasterize_variant(base, "D", raster_factors, seed)
    layers = result.layers
    if race == "orc":
        layers["ear"] = _draw_orc_top_ears(base.size)

    composite = base.copy()
    for layer_name in ("socket_cover", "eye", "brow", "ear"):
        composite.alpha_composite(layers[layer_name])
    return composite, layers, factors, result.warnings


def generate_race_samples(output_dir: Path | str = DEFAULT_OUTPUT, seed: int = 20260726) -> dict:
    output_root = _inside_project(Path(output_dir), "output-dir")
    source_path = _inside_project(DEFAULT_SOURCE, "source")
    source = Image.open(source_path).convert("RGBA")
    samples: dict[str, dict] = {}

    for race in RACES:
        race_dir = output_root / race
        composite, layers, factors, warnings = _render_race(race, source, seed)
        for layer_name in LAYERS:
            (race_dir / layer_name).mkdir(parents=True, exist_ok=True)
        _save_png(source, race_dir / "base.png")
        for layer_name in ("socket_cover", "eye", "brow", "ear"):
            _save_png(layers[layer_name], race_dir / f"{layer_name}.png")
        _save_png(composite, race_dir / "composite.png")
        _save_png(composite.resize((composite.width * 4, composite.height * 4), Image.Resampling.NEAREST), race_dir / "preview.png")
        samples[race] = {
            "source": source_path.relative_to(PROJECT_ROOT).as_posix(),
            "size": {"width": composite.width, "height": composite.height},
            "factors": factors,
            "warnings": warnings,
        }

    manifest = {
        "generator_version": "race_face_samples_v1",
        "seed": int(seed),
        "source": source_path.relative_to(PROJECT_ROOT).as_posix(),
        "races": list(RACES),
        "sample_count": len(samples),
        "samples": samples,
    }
    output_root.mkdir(parents=True, exist_ok=True)
    _write_json(output_root / "manifest.json", manifest)
    (output_root / "README.md").write_text(
        "# Legacy-resolution race face samples\n\n"
        "One 36x34 normal-resolution face per race. Human and elf use side ears;\n"
        "orc uses a small top-ear layer. This is a temporary test output and does\n"
        "not replace the source face assets.\n",
        encoding="utf-8",
    )
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate one legacy-resolution face sample per race")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--seed", type=int, default=20260726)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        manifest = generate_race_samples(args.output_dir, args.seed)
    except (FileNotFoundError, ValueError) as error:
        print(f"generation failed: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"output_dir": args.output_dir, "sample_count": manifest["sample_count"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
