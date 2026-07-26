"""Reference-shaped HD face catalog for human-like race variants.

The geometry is redrawn from measured reference proportions. Reference pixels
are not copied into the generated textures.
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT_ROOT = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.tools.test import hd_face_pipeline as v1


PROJECT_ROOT = v1.PROJECT_ROOT
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "assets" / "test" / "face_hd_v2_reference"
RACES = v1.RACES
PRESETS = v1.PRESETS
PIXEL_SCALE = 2
LOGICAL_SIZE = (36, 34)
HD_SIZE = (LOGICAL_SIZE[0] * PIXEL_SCALE, LOGICAL_SIZE[1] * PIXEL_SCALE)
LAYERS = ("base", "socket_cover", "eye", "brow", "ear", "composite")

REFERENCE_PALETTES = {
    "human": {
        "skin": (226, 168, 126, 255),
        "shadow": (180, 108, 82, 255),
        "highlight": (255, 211, 166, 255),
    },
    "elf": {
        "skin": (220, 181, 137, 255),
        "shadow": (176, 121, 96, 255),
        "highlight": (252, 220, 180, 255),
    },
    # Muted olive-brown keeps the race readable as a humanoid, not a green blob.
    "orc": {
        "skin": (156, 145, 104, 255),
        "shadow": (103, 96, 76, 255),
        "highlight": (194, 181, 137, 255),
    },
}

REFERENCE_ROW_SPANS = (
    (14, 22),
    (10, 25),
    (8, 27),
    (7, 28),
    (6, 29),
    (5, 30),
    (5, 31),
    (4, 31),
    (4, 31),
    (4, 31),
    (3, 32),
    (3, 32),
    (3, 32),
    (3, 32),
    (3, 32),
    (3, 32),
    (3, 32),
    (4, 31),
    (4, 31),
    (5, 30),
    (5, 30),
    (5, 30),
    (5, 30),
    (5, 30),
    (5, 30),
    (6, 29),
    (7, 28),
    (8, 27),
    (8, 27),
    (9, 26),
    (10, 25),
    (12, 23),
    (14, 21),
    (16, 19),
)


def _inside_project(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    project = PROJECT_ROOT.resolve()
    if resolved.drive.upper() != "E:":
        raise ValueError(f"{label} must be on the E drive: {resolved}")
    try:
        resolved.relative_to(project)
    except ValueError as error:
        raise ValueError(f"{label} must stay under {project}") from error
    return resolved


def _clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def build_reference_factors(preset: str, race: str, seed: int = 0) -> dict[str, dict]:
    if preset not in PRESETS:
        raise ValueError(f"unknown preset: {preset}")
    if race not in RACES:
        raise ValueError(f"unknown race: {race}")

    factors = {
        "race": race,
        "preset": preset,
        "face_shape": "reference_human",
        "pixel_scale": PIXEL_SCALE,
        "brow": copy.deepcopy(v1.PRESET_FACTORS[preset]["brow"]),
        "eye": copy.deepcopy(v1.PRESET_FACTORS[preset]["eye"]),
    }
    if race == "human":
        ear = {"type": "human", "placement": "side", "length": 2, "tip_raise": 0, "outer_spread": 0}
    elif race == "elf":
        ear = {"type": "elf", "placement": "side", "length": 5, "tip_raise": 3, "outer_spread": 0}
    else:
        ear = {"type": "orc", "placement": "top", "length": 7, "tip_raise": 7, "outer_spread": 1}
    ear.update({"style": v1.EAR_PRESET_FACTORS[preset]["style"]})
    ear["length"] = _clamp(ear["length"] + v1.EAR_PRESET_FACTORS[preset]["length_offset"], 1, 10)
    ear["tip_raise"] = _clamp(ear["tip_raise"] + v1.EAR_PRESET_FACTORS[preset]["tip_raise_offset"], 0, 10)
    factors["ear"] = ear
    return factors


def reference_anchors(direction: str) -> dict[str, tuple]:
    if direction == "D":
        return {
            "eye_centers": ((24, 48), (46, 48)),
            "brow_lines": ((14, 28, 40), (42, 56, 40)),
        }
    if direction == "L":
        return {"eye_centers": ((22, 48),), "brow_lines": ((12, 28, 40),)}
    if direction == "R":
        return {"eye_centers": ((50, 48),), "brow_lines": ((44, 60, 40),)}
    if direction == "U":
        return {"eye_centers": (), "brow_lines": ()}
    raise ValueError(f"unsupported direction: {direction}")


def _reference_spans(direction: str, frame_index: int, seed: int) -> tuple[tuple[int, int], ...]:
    sway = ((frame_index + seed) % 3) - 1
    spans = []
    for left, right in REFERENCE_ROW_SPANS:
        spans.append((left + sway, right + sway))
    return tuple(spans)


def create_reference_base(
    race: str,
    direction: str,
    frame_index: int,
    pixel_scale: int = PIXEL_SCALE,
    seed: int = 0,
) -> Image.Image:
    if race not in RACES:
        raise ValueError(f"unknown race: {race}")
    if direction not in ("D", "L", "R", "U"):
        raise ValueError(f"unsupported direction: {direction}")
    if pixel_scale != PIXEL_SCALE:
        raise ValueError(f"this experiment only supports pixel_scale={PIXEL_SCALE}")

    palette = REFERENCE_PALETTES[race]
    logical = Image.new("RGBA", LOGICAL_SIZE, (0, 0, 0, 0))
    spans = _reference_spans(direction, frame_index, seed)
    for y, (left, right) in enumerate(spans):
        y += 2
        if y >= LOGICAL_SIZE[1]:
            continue
        for x in range(max(0, left), min(LOGICAL_SIZE[0] - 1, right) + 1):
            logical.putpixel((x, y), palette["skin"])

    draw = ImageDraw.Draw(logical)
    # Sparse planar shading follows the reference's readable pixel clusters.
    draw.rectangle((6, 27, 29, 29), fill=palette["shadow"])
    draw.rectangle((10, 30, 25, 31), fill=palette["shadow"])
    draw.rectangle((14, 4, 20, 4), fill=palette["highlight"])
    for y, (left, right) in enumerate(spans):
        if left <= 2:
            logical.putpixel((left, y), palette["shadow"])
        if right >= 33:
            logical.putpixel((right, y), palette["shadow"])

    return logical.resize(HD_SIZE, Image.Resampling.NEAREST)


def _socket_rects(direction: str) -> tuple[tuple[int, int, int, int], ...]:
    if direction == "D":
        return ((16, 42, 30, 54), (38, 42, 52, 54))
    if direction == "L":
        return ((8, 42, 28, 54),)
    if direction == "R":
        return ((44, 42, 64, 54),)
    return ()


def _draw_eye(layer: Image.Image, center: tuple[int, int], factors: dict[str, object]) -> set[tuple[int, int]]:
    scale_x = float(factors.get("scale_x", 1.0))
    scale_y = float(factors.get("scale_y", 1.0))
    rx = max(2, round(4 * scale_x))
    ry = max(2, round(3 * scale_y))
    points: set[tuple[int, int]] = set()
    for point in v1._ellipse_points(center[0], center[1], rx, ry):
        if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
            layer.putpixel(point, v1.EYE_WHITE)
            points.add(point)
    iris_center = center
    for point in v1._ellipse_points(iris_center[0], iris_center[1], max(1, round(rx * 0.55)), max(1, round(ry * 0.7))):
        if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
            layer.putpixel(point, v1.EYE_IRIS)
            points.add(point)
    for point in v1._ellipse_points(iris_center[0], iris_center[1], 1, 1):
        if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
            layer.putpixel(point, v1.EYE_PUPIL)
            points.add(point)
    highlight = (iris_center[0] - 1, iris_center[1] - 1)
    if 0 <= highlight[0] < layer.width and 0 <= highlight[1] < layer.height:
        layer.putpixel(highlight, v1.EYE_HIGHLIGHT)
        points.add(highlight)
    return points


def _draw_brow(layer: Image.Image, line: tuple[int, int, int], factors: dict[str, object]) -> set[tuple[int, int]]:
    x1, x2, y = line
    thickness = max(2, int(factors.get("thickness", 2)))
    curve = int(factors.get("curve", 0))
    span = max(1, x2 - x1)
    points: set[tuple[int, int]] = set()
    for x in range(x1, x2 + 1):
        offset = round(curve * (x - x1) / span)
        for dy in range(thickness):
            point = (x, y + offset + dy)
            if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
                layer.putpixel(point, v1.BROW)
                points.add(point)
    return points


def _draw_side_ears(layer: Image.Image, factors: dict[str, object], direction: str, palette: dict[str, tuple[int, int, int, int]]) -> set[tuple[int, int]]:
    length = int(factors.get("length", 2))
    is_elf = factors.get("type") == "elf"
    draw = ImageDraw.Draw(layer)
    points: set[tuple[int, int]] = set()
    if direction == "D":
        sides = ("L", "R")
    elif direction == "L":
        sides = ("R",)
    elif direction == "R":
        sides = ("L",)
    else:
        return points

    for side in sides:
        if side == "L":
            inner = (12, 42)
            tip = (max(0, 4 - length), 40 if is_elf else 43)
            outer = (8, 51)
        else:
            inner = (60, 42)
            tip = (min(layer.width - 1, 68 + length), 40 if is_elf else 43)
            outer = (64, 51)
        polygon = [inner, tip, outer, (inner[0], 52)]
        draw.polygon(polygon, fill=palette["skin"])
        if is_elf:
            draw.line([inner, tip], fill=palette["shadow"], width=2)
        else:
            draw.line([inner, tip], fill=palette["shadow"], width=2)
        points.update(v1._alpha_points(layer))
    return points


def _draw_top_ears(layer: Image.Image, factors: dict[str, object], palette: dict[str, tuple[int, int, int, int]]) -> set[tuple[int, int]]:
    draw = ImageDraw.Draw(layer)
    length = int(factors.get("length", 7))
    tip_raise = int(factors.get("tip_raise", 7))
    top = max(0, 6 - tip_raise)
    half_width = _clamp(2 + length // 4, 3, 5)
    points: set[tuple[int, int]] = set()
    for center in (18, 54):
        outer = [(center - half_width, 24), (center, top), (center + half_width, 24), (center + 3, 28), (center - 3, 28)]
        inner = [(center - max(1, half_width - 2), 23), (center, top + 2), (center + max(1, half_width - 2), 23), (center + 2, 26), (center - 2, 26)]
        draw.polygon(outer, fill=palette["shadow"])
        draw.polygon(inner, fill=palette["skin"])
        draw.line([(center, top + 4), (center + 1, 20)], fill=palette["shadow"], width=1)
        points.update(v1._alpha_points(layer))
    return points


def rasterize_reference_components(
    base: Image.Image,
    direction: str,
    factors: dict[str, dict],
    seed: int,
) -> v1.HdRasterResult:
    race = str(factors.get("race", "human"))
    palette = REFERENCE_PALETTES[race]
    resolved = copy.deepcopy(factors)
    offset = (int(seed) % 3) - 1
    if resolved.get("preset") == "natural":
        resolved["brow"]["curve"] = 0
    else:
        resolved["brow"]["curve"] = _clamp(int(resolved["brow"].get("curve", 0)) + offset, -2, 2)
    resolved["eye"]["scale_x"] = round(max(0.7, min(1.2, float(resolved["eye"].get("scale_x", 1.0)) + offset * 0.03)), 2)
    resolved["eye"]["scale_y"] = round(max(0.7, min(1.2, float(resolved["eye"].get("scale_y", 1.0)) - offset * 0.03)), 2)

    layers = {name: Image.new("RGBA", base.size, (0, 0, 0, 0)) for name in LAYERS if name not in ("base", "composite")}
    for x1, y1, x2, y2 in _socket_rects(direction):
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                if base.getpixel((x, y))[3] > 0:
                    layers["socket_cover"].putpixel((x, y), palette["skin"])

    anchors = reference_anchors(direction)
    eye_points: set[tuple[int, int]] = set()
    brow_points: set[tuple[int, int]] = set()
    for center in anchors["eye_centers"]:
        eye_points |= _draw_eye(layers["eye"], center, resolved["eye"])
    for line in anchors["brow_lines"]:
        brow_points |= _draw_brow(layers["brow"], line, resolved["brow"])

    if resolved["ear"].get("placement") == "top":
        ear_points = _draw_top_ears(layers["ear"], resolved["ear"], palette)
    else:
        ear_points = _draw_side_ears(layers["ear"], resolved["ear"], direction, palette)

    socket_expected = len(v1._alpha_points(layers["socket_cover"]))
    socket_covered = socket_expected
    warnings: list[str] = []
    if socket_covered != socket_expected:
        warnings.append(f"socket coverage incomplete: {socket_expected - socket_covered} px")
    return v1.HdRasterResult(
        layers=layers,
        coverage={
            "socket_expected": socket_expected,
            "socket_covered": socket_covered,
            "eye_pixels": len(eye_points),
            "brow_pixels": len(brow_points),
            "ear_pixels": len(ear_points),
        },
        warnings=warnings,
    )


def _compose(base: Image.Image, result: v1.HdRasterResult, race: str) -> Image.Image:
    composite = Image.new("RGBA", base.size, (0, 0, 0, 0))
    if race == "orc":
        composite.alpha_composite(base)
        composite.alpha_composite(result.layers["ear"])
    else:
        composite.alpha_composite(base)
        composite.alpha_composite(result.layers["ear"])
    for layer_name in ("socket_cover", "eye", "brow"):
        composite.alpha_composite(result.layers[layer_name])
    return composite


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _write_readme(path: Path) -> None:
    path.write_text(
        """# HD Face Reference Experiment v2

This catalog is a reference-shaped redraw for the project's humanoid Q-style.
It uses measured face proportions from the original fox face as geometry guidance,
but redraws the pixels and palette.

All three races share the same human-like face silhouette and eye/brow anchors.
Human and elf use side ears; orc uses small top ears attached to the crown.
Small dot eyes remain an optional random factor, never the elf default.

This is a comparison catalog and does not replace legacy Godot resources.
""",
        encoding="utf-8",
    )


def generate_reference_catalog(output_dir: Path | str = DEFAULT_OUTPUT_DIR, seed: int = 20260727) -> dict:
    output_root = _inside_project(Path(output_dir), "output_dir")
    output_root.mkdir(parents=True, exist_ok=True)
    catalogs: dict[str, dict] = {}
    frame_counts: dict[str, int] = {}
    warning_count = 0

    for race in RACES:
        for preset in PRESETS:
            key = f"{race}/{preset}"
            catalog_root = output_root / race / preset
            for layer in LAYERS + ("preview",):
                (catalog_root / layer).mkdir(parents=True, exist_ok=True)
            factors = build_reference_factors(preset, race, seed)
            frames: list[dict] = []
            preview_paths: dict[str, Path] = {}
            for action, direction, index in v1.FRAME_SPECS:
                name = v1._frame_name(race, preset, action, direction, index)
                base = create_reference_base(race, direction, index, seed=seed)
                result = rasterize_reference_components(base, direction, factors, seed)
                warning_count += len(result.warnings)
                _save_png(base, catalog_root / "base" / name)
                layer_paths = {}
                for layer_name in ("socket_cover", "eye", "brow", "ear"):
                    path = catalog_root / layer_name / name
                    _save_png(result.layers[layer_name], path)
                    layer_paths[layer_name] = path.relative_to(output_root).as_posix()
                composite = _compose(base, result, race)
                composite_path = catalog_root / "composite" / name
                _save_png(composite, composite_path)
                if action == "stand":
                    preview_paths[direction] = composite_path
                frames.append({
                    "file": name,
                    "action": action,
                    "direction": direction,
                    "index": index,
                    "size": {"width": HD_SIZE[0], "height": HD_SIZE[1]},
                    "logical_size": {"width": LOGICAL_SIZE[0], "height": LOGICAL_SIZE[1]},
                    "layers": layer_paths,
                    "composite": composite_path.relative_to(output_root).as_posix(),
                    "coverage": result.coverage,
                    "warnings": result.warnings,
                })
            for direction, source_path in preview_paths.items():
                preview = Image.open(source_path).convert("RGBA").resize((144, 136), Image.Resampling.NEAREST)
                _save_png(preview, catalog_root / "preview" / f"stand_{direction}.png")
            catalogs[key] = {
                "race": race,
                "preset": preset,
                "factors": factors,
                "frame_count": len(frames),
                "frames": frames,
            }
            frame_counts[key] = len(frames)

    manifest = {
        "generator_version": "hd_face_reference_pipeline_v2",
        "seed": int(seed),
        "pixel_scale": PIXEL_SCALE,
        "logical_size": {"width": LOGICAL_SIZE[0], "height": LOGICAL_SIZE[1]},
        "texture_size": {"width": HD_SIZE[0], "height": HD_SIZE[1]},
        "races": list(RACES),
        "presets": list(PRESETS),
        "catalog_count": len(catalogs),
        "frame_counts": frame_counts,
        "warning_count": warning_count,
        "catalogs": catalogs,
    }
    _write_json(output_root / "manifest.json", manifest)
    _write_json(output_root / "presets.json", {"face_shape": "reference_human", "races": list(RACES), "presets": list(PRESETS), "texture_size": {"width": HD_SIZE[0], "height": HD_SIZE[1]}})
    _write_readme(output_root / "README.md")
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate reference-shaped 2x pixel face catalogs")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--seed", type=int, default=20260727)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        manifest = generate_reference_catalog(args.output_dir, args.seed)
    except ValueError as error:
        print(f"generation failed: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"output_dir": args.output_dir, "catalog_count": manifest["catalog_count"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
