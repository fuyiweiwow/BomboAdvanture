"""Standalone 2x pixel face catalog for human, elf, and orc variants."""

from __future__ import annotations

import argparse
import copy
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


PROJECT_ROOT = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "assets" / "test" / "face_hd_v1"
RACES = ("human", "elf", "orc")
PRESETS = ("natural", "gentle", "focused", "bold")
PIXEL_SCALE = 2
LOGICAL_SIZE = (36, 34)
HD_SIZE = (LOGICAL_SIZE[0] * PIXEL_SCALE, LOGICAL_SIZE[1] * PIXEL_SCALE)
LAYERS = ("base", "socket_cover", "eye", "brow", "ear", "composite")
FRAME_SPECS = (
    [("stand", direction, 0) for direction in ("D", "L", "R", "U")]
    + [
        ("walk", direction, index)
        for direction in ("D", "L", "R", "U")
        for index in range(6)
    ]
)

PALETTES = {
    "human": {
        "skin": (224, 164, 119, 255),
        "shadow": (183, 112, 88, 255),
        "highlight": (255, 207, 156, 255),
    },
    "elf": {
        "skin": (216, 176, 130, 255),
        "shadow": (170, 119, 96, 255),
        "highlight": (250, 218, 174, 255),
    },
    "orc": {
        "skin": (128, 161, 91, 255),
        "shadow": (76, 108, 74, 255),
        "highlight": (176, 198, 115, 255),
    },
}

EYE_WHITE = (255, 247, 225, 255)
EYE_IRIS = (76, 151, 186, 255)
EYE_PUPIL = (38, 32, 42, 255)
EYE_HIGHLIGHT = (255, 255, 255, 255)
BROW = (73, 51, 45, 255)

PRESET_FACTORS = {
    "natural": {
        "brow": {"style": "natural", "thickness": 2, "curve": 0},
        "eye": {"size": "normal", "scale_x": 1.0, "scale_y": 1.0, "iris": "blue", "pupil_offset": [0, 0]},
    },
    "gentle": {
        "brow": {"style": "gentle", "thickness": 1, "curve": 1},
        "eye": {"size": "round", "scale_x": 1.05, "scale_y": 1.1, "iris": "blue", "pupil_offset": [0, 0]},
    },
    "focused": {
        "brow": {"style": "focused", "thickness": 1, "curve": -1},
        "eye": {"size": "narrow", "scale_x": 0.9, "scale_y": 0.78, "iris": "blue", "pupil_offset": [0, 0]},
    },
    "bold": {
        "brow": {"style": "bold", "thickness": 3, "curve": 0},
        "eye": {"size": "large", "scale_x": 1.15, "scale_y": 1.12, "iris": "blue", "pupil_offset": [0, 0]},
    },
}

EAR_PRESET_FACTORS = {
    "natural": {"style": "rounded", "length_offset": 0, "tip_raise_offset": 0, "outer_spread_offset": 0},
    "gentle": {"style": "soft", "length_offset": 1, "tip_raise_offset": -1, "outer_spread_offset": 0},
    "focused": {"style": "sharp", "length_offset": -1, "tip_raise_offset": 1, "outer_spread_offset": 0},
    "bold": {"style": "broad", "length_offset": 2, "tip_raise_offset": 1, "outer_spread_offset": 1},
}


@dataclass
class HdRasterResult:
    layers: dict[str, Image.Image]
    coverage: dict[str, int]
    warnings: list[str]


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


def build_preset_factors(preset: str, race: str, seed: int = 0) -> dict[str, dict]:
    if preset not in PRESETS:
        raise ValueError(f"unknown preset: {preset}")
    if race not in RACES:
        raise ValueError(f"unknown race: {race}")

    if race == "human":
        ear = {"type": "human", "placement": "side", "length": 2, "tip_raise": 1, "outer_spread": 1}
    elif race == "elf":
        ear = {"type": "elf", "placement": "side", "length": 6, "tip_raise": 4, "outer_spread": 2}
    else:
        ear = {"type": "orc", "placement": "top", "length": 7, "tip_raise": 7, "outer_spread": 3}
    ear_variant = EAR_PRESET_FACTORS[preset]
    ear["style"] = ear_variant["style"]
    ear["length"] = _clamp(ear["length"] + ear_variant["length_offset"], 1, 10)
    ear["tip_raise"] = _clamp(ear["tip_raise"] + ear_variant["tip_raise_offset"], 0, 10)
    ear["outer_spread"] = _clamp(ear["outer_spread"] + ear_variant["outer_spread_offset"], 0, 8)

    result = {
        "race": race,
        "preset": preset,
        "pixel_scale": PIXEL_SCALE,
        "brow": copy.deepcopy(PRESET_FACTORS[preset]["brow"]),
        "eye": copy.deepcopy(PRESET_FACTORS[preset]["eye"]),
        "ear": ear,
    }
    return result


def resolve_seed_variant(factors: dict[str, dict], seed: int) -> dict[str, dict]:
    resolved = copy.deepcopy(factors)
    offset = (int(seed) % 3) - 1
    resolved["brow"]["curve"] = _clamp(int(resolved["brow"].get("curve", 0)) + offset, -3, 3)
    resolved["eye"]["scale_x"] = round(max(0.65, min(1.3, float(resolved["eye"].get("scale_x", 1.0)) + offset * 0.04)), 2)
    resolved["eye"]["scale_y"] = round(max(0.65, min(1.3, float(resolved["eye"].get("scale_y", 1.0)) - offset * 0.04)), 2)
    resolved["ear"]["outer_spread"] = max(0, min(8, int(resolved["ear"].get("outer_spread", 0)) + int(seed) % 2))
    return resolved


def _socket_rects(direction: str, race: str) -> tuple[tuple[int, int, int, int], ...]:
    if direction == "D":
        rects = ((14, 39, 32, 61), (40, 39, 58, 61))
    elif direction == "L":
        rects = ((2, 38, 20, 61),)
        if race != "orc":
            rects += ((30, 38, 47, 61),)
    elif direction == "R":
        rects = ((20, 38, 38, 61),)
        if race != "orc":
            rects += ((50, 38, 69, 61),)
    elif direction == "U":
        rects = ()
    else:
        raise ValueError(f"unsupported direction: {direction}")
    return rects


def _clear_rect(image: Image.Image, rect: tuple[int, int, int, int]) -> None:
    x1, y1, x2, y2 = rect
    for y in range(max(0, y1), min(image.height - 1, y2) + 1):
        for x in range(max(0, x1), min(image.width - 1, x2) + 1):
            image.putpixel((x, y), (0, 0, 0, 0))


def create_hd_base(race: str, direction: str, frame_index: int, pixel_scale: int = PIXEL_SCALE, seed: int = 0) -> Image.Image:
    if race not in RACES:
        raise ValueError(f"unknown race: {race}")
    if pixel_scale != PIXEL_SCALE:
        raise ValueError(f"this experiment only supports pixel_scale={PIXEL_SCALE}")
    if frame_index < 0:
        raise ValueError("frame_index must be non-negative")

    image = Image.new("RGBA", HD_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    palette = PALETTES[race]
    sway = ((frame_index + seed) % 3) - 1
    x_shift = sway * 2

    if race == "orc":
        outer_box = (10 + x_shift, 8, 62 + x_shift, 66)
        inner_box = (12 + x_shift, 7, 60 + x_shift, 64)
    elif race == "elf":
        outer_box = (14 + x_shift, 6, 58 + x_shift, 66)
        inner_box = (16 + x_shift, 5, 56 + x_shift, 64)
    else:
        outer_box = (12 + x_shift, 6, 60 + x_shift, 66)
        inner_box = (14 + x_shift, 5, 58 + x_shift, 64)

    draw.ellipse(outer_box, fill=palette["shadow"])
    draw.ellipse(inner_box, fill=palette["skin"])
    draw.rectangle((27 + x_shift, 13, 43 + x_shift, 16), fill=palette["highlight"])
    draw.rectangle((18 + x_shift, 58, 53 + x_shift, 62), fill=palette["shadow"])

    for rect in _socket_rects(direction, race):
        _clear_rect(image, rect)
    return image


def _alpha_points(image: Image.Image) -> set[tuple[int, int]]:
    return {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if image.getpixel((x, y))[3] > 0
    }


def _socket_points(rects: Iterable[tuple[int, int, int, int]], base: Image.Image) -> set[tuple[int, int]]:
    points: set[tuple[int, int]] = set()
    for x1, y1, x2, y2 in rects:
        for y in range(max(0, y1), min(base.height - 1, y2) + 1):
            for x in range(max(0, x1), min(base.width - 1, x2) + 1):
                if base.getpixel((x, y))[3] < 128:
                    points.add((x, y))
    return points


def _draw_brow(layer: Image.Image, line: tuple[int, int, int], factors: dict[str, object]) -> set[tuple[int, int]]:
    x1, x2, y = line
    thickness = max(2, int(factors.get("thickness", 2)))
    curve = int(factors.get("curve", 0)) * 2
    points: set[tuple[int, int]] = set()
    span = max(1, x2 - x1)
    for x in range(x1, x2 + 1):
        curve_offset = round(curve * (x - x1) / span)
        for dy in range(thickness):
            point = (x, y + curve_offset + dy)
            if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
                layer.putpixel(point, BROW)
                points.add(point)
    return points


def _ellipse_points(cx: float, cy: float, rx: int, ry: int) -> set[tuple[int, int]]:
    points: set[tuple[int, int]] = set()
    for y in range(int(cy) - ry, int(cy) + ry + 1):
        for x in range(int(cx) - rx, int(cx) + rx + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                points.add((x, y))
    return points


def _draw_eye(layer: Image.Image, center: tuple[float, float], factors: dict[str, object]) -> set[tuple[int, int]]:
    scale_x = float(factors.get("scale_x", 1.0))
    scale_y = float(factors.get("scale_y", 1.0))
    rx = max(3, round(6 * scale_x))
    ry = max(2, round(5 * scale_y))
    offset = factors.get("pupil_offset", [0, 0])
    pupil_offset = (int(offset[0]) * 2, int(offset[1]) * 2)
    points: set[tuple[int, int]] = set()
    for point in _ellipse_points(center[0], center[1], rx, ry):
        if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
            layer.putpixel(point, EYE_WHITE)
            points.add(point)

    iris_center = (center[0] + pupil_offset[0], center[1] + pupil_offset[1])
    for point in _ellipse_points(iris_center[0], iris_center[1], max(2, round(rx * 0.55)), max(2, round(ry * 0.65))):
        if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
            layer.putpixel(point, EYE_IRIS)
            points.add(point)

    for point in _ellipse_points(iris_center[0], iris_center[1], max(1, round(rx * 0.25)), max(1, round(ry * 0.35))):
        if 0 <= point[0] < layer.width and 0 <= point[1] < layer.height:
            layer.putpixel(point, EYE_PUPIL)
            points.add(point)
    highlight = (round(iris_center[0] - max(1, rx * 0.35)), round(iris_center[1] - max(1, ry * 0.35)))
    if 0 <= highlight[0] < layer.width and 0 <= highlight[1] < layer.height:
        layer.putpixel(highlight, EYE_HIGHLIGHT)
        points.add(highlight)
    return points


def _draw_side_ear(
    layer: Image.Image,
    side: str,
    ear: dict[str, object],
    palette: dict[str, tuple[int, int, int, int]],
    direction: str,
) -> set[tuple[int, int]]:
    length = int(ear.get("length", 0))
    raise_amount = int(ear.get("tip_raise", 0)) * 2
    spread = int(ear.get("outer_spread", 0)) * 2
    is_elf = ear.get("type") == "elf"
    if direction == "D":
        if side == "L":
            inner = (14, 45)
            tip = (max(0, inner[0] - 8 - length), max(8, inner[1] - 7 - raise_amount))
            outer = (max(2, tip[0] + 2), 57)
        else:
            inner = (58, 45)
            tip = (min(layer.width - 1, inner[0] + 8 + length), max(8, inner[1] - 7 - raise_amount))
            outer = (min(layer.width - 3, tip[0] - 2), 57)
    elif side == "L":
        inner = (20, 43)
        tip = (max(0, inner[0] - 10 - length - spread), max(8, inner[1] - 8 - raise_amount))
        outer = (max(0, tip[0] + 2), 57)
    else:
        inner = (52, 43)
        tip = (min(layer.width - 1, inner[0] + 10 + length + spread), max(8, inner[1] - 8 - raise_amount))
        outer = (min(layer.width - 1, tip[0] - 2), 57)

    if not is_elf:
        tip = (tip[0], min(60, tip[1] + 3))

    polygon = [inner, tip, outer, (inner[0], 62)]
    draw = ImageDraw.Draw(layer)
    draw.polygon(polygon, fill=palette["skin"])
    inner_shadow = [polygon[0], polygon[1], (polygon[2][0], polygon[2][1] - 3)]
    draw.polygon(inner_shadow, fill=palette["shadow"])
    return _alpha_points(layer)


def _draw_top_orc_ears(layer: Image.Image, ear: dict[str, object], palette: dict[str, tuple[int, int, int, int]]) -> set[tuple[int, int]]:
    draw = ImageDraw.Draw(layer)
    length = int(ear.get("length", 7))
    raise_amount = int(ear.get("tip_raise", 7)) * 2
    half_width = _clamp(7 + length // 3, 7, 11)
    ears = []
    for center in (21, 51):
        ears.append([(center - half_width, 25), (center, max(0, 19 - raise_amount)), (center + half_width, 25), (center + 4, 34), (center - 4, 34)])
    for polygon in ears:
        draw.polygon(polygon, fill=palette["skin"])
        shadow = [polygon[0], polygon[1], (polygon[2][0] - 2, polygon[2][1] - 3), (polygon[3][0], polygon[3][1] - 3)]
        draw.polygon(shadow, fill=palette["shadow"])
    return _alpha_points(layer)


def _component_anchors(direction: str) -> tuple[tuple[tuple[float, float], ...], tuple[tuple[int, int, int], ...]]:
    if direction == "D":
        return ((23, 51), (49, 51)), ((15, 37, 38), (43, 37, 66))
    if direction == "L":
        return ((11, 50),), ((5, 36, 20),)
    if direction == "R":
        return ((27, 50),), ((52, 36, 67),)
    return (), ()


def rasterize_hd_components(base: Image.Image, direction: str, factors: dict[str, dict], seed: int) -> HdRasterResult:
    if base.mode != "RGBA":
        base = base.convert("RGBA")
    race = str(factors.get("race", "human"))
    if race not in RACES:
        raise ValueError(f"unknown race: {race}")
    resolved = resolve_seed_variant(factors, seed)
    palette = PALETTES[race]
    layers = {name: Image.new("RGBA", base.size, (0, 0, 0, 0)) for name in LAYERS if name != "base"}

    socket_mask = _socket_points(_socket_rects(direction, race), base)
    for point in socket_mask:
        layers["socket_cover"].putpixel(point, palette["skin"])

    eyes, brows = _component_anchors(direction)
    eye_points: set[tuple[int, int]] = set()
    brow_points: set[tuple[int, int]] = set()
    for center in eyes:
        eye_points |= _draw_eye(layers["eye"], center, resolved["eye"])
    for line in brows:
        brow_points |= _draw_brow(layers["brow"], line, resolved["brow"])

    ear_points: set[tuple[int, int]] = set()
    placement = resolved["ear"].get("placement", "side")
    if placement == "top":
        ear_points = _draw_top_orc_ears(layers["ear"], resolved["ear"], palette)
    elif direction == "D":
        ear_points |= _draw_side_ear(layers["ear"], "L", resolved["ear"], palette, direction)
        ear_points |= _draw_side_ear(layers["ear"], "R", resolved["ear"], palette, direction)
    elif direction == "L":
        ear_points = _draw_side_ear(layers["ear"], "R", resolved["ear"], palette, direction)
    elif direction == "R":
        ear_points = _draw_side_ear(layers["ear"], "L", resolved["ear"], palette, direction)

    covered = sum(1 for point in socket_mask if layers["socket_cover"].getpixel(point)[3] > 0)
    warnings: list[str] = []
    if covered != len(socket_mask):
        warnings.append(f"socket coverage incomplete: {len(socket_mask) - covered} px")
    return HdRasterResult(
        layers=layers,
        coverage={
            "socket_expected": len(socket_mask),
            "socket_covered": covered,
            "eye_pixels": len(eye_points),
            "brow_pixels": len(brow_points),
            "ear_pixels": len(ear_points),
        },
        warnings=warnings,
    )


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _frame_name(race: str, preset: str, action: str, direction: str, index: int) -> str:
    return f"{race}_{preset}_{action}_{direction}_{index}.png"


def generate_hd_catalog(output_dir: Path | str = DEFAULT_OUTPUT_DIR, seed: int = 20260726, pixel_scale: int = PIXEL_SCALE) -> dict:
    if pixel_scale != PIXEL_SCALE:
        raise ValueError(f"this experiment only supports pixel_scale={PIXEL_SCALE}")
    output_root = _inside_project(Path(output_dir), "output_dir")
    output_root.mkdir(parents=True, exist_ok=True)
    catalog_manifest: dict[str, dict] = {}
    frame_counts: dict[str, int] = {}
    warning_count = 0

    for race in RACES:
        for preset in PRESETS:
            catalog_key = f"{race}/{preset}"
            catalog_root = output_root / race / preset
            for layer in LAYERS + ("preview",):
                (catalog_root / layer).mkdir(parents=True, exist_ok=True)
            factors = build_preset_factors(preset, race, seed)
            resolved = resolve_seed_variant(factors, seed)
            frames: list[dict] = []
            preview_paths: dict[str, Path] = {}
            for action, direction, index in FRAME_SPECS:
                name = _frame_name(race, preset, action, direction, index)
                base = create_hd_base(race, direction, index, pixel_scale, seed)
                result = rasterize_hd_components(base, direction, factors, seed)
                warning_count += len(result.warnings)
                _save_png(base, catalog_root / "base" / name)
                layer_paths: dict[str, str] = {}
                for layer_name in ("socket_cover", "eye", "brow", "ear"):
                    layer_path = catalog_root / layer_name / name
                    _save_png(result.layers[layer_name], layer_path)
                    layer_paths[layer_name] = layer_path.relative_to(output_root).as_posix()

                composite = base.copy()
                for layer_name in ("socket_cover", "eye", "brow", "ear"):
                    composite.alpha_composite(result.layers[layer_name])
                composite_path = catalog_root / "composite" / name
                _save_png(composite, composite_path)
                if action == "stand":
                    preview_paths[direction] = composite_path
                frames.append({
                    "file": name,
                    "action": action,
                    "direction": direction,
                    "index": index,
                    "size": {"width": base.width, "height": base.height},
                    "logical_size": {"width": LOGICAL_SIZE[0], "height": LOGICAL_SIZE[1]},
                    "layers": layer_paths,
                    "composite": composite_path.relative_to(output_root).as_posix(),
                    "coverage": result.coverage,
                    "warnings": result.warnings,
                })

            for direction, source_path in preview_paths.items():
                preview = Image.open(source_path).convert("RGBA").resize((144, 136), Image.Resampling.NEAREST)
                _save_png(preview, catalog_root / "preview" / f"stand_{direction}.png")

            catalog_manifest[catalog_key] = {
                "race": race,
                "preset": preset,
                "factors": factors,
                "resolved_factors": resolved,
                "frame_count": len(frames),
                "frames": frames,
            }
            frame_counts[catalog_key] = len(frames)

    presets_data = {
        "pixel_scale": PIXEL_SCALE,
        "logical_size": {"width": LOGICAL_SIZE[0], "height": LOGICAL_SIZE[1]},
        "texture_size": {"width": HD_SIZE[0], "height": HD_SIZE[1]},
        "presets": {preset: PRESET_FACTORS[preset] for preset in PRESETS},
        "races": {
            race: build_preset_factors("natural", race, seed)["ear"]
            for race in RACES
        },
        "dot_eye_note": "small_dot_eye remains an optional random factor and is not a default preset",
    }
    _write_json(output_root / "presets.json", presets_data)
    manifest = {
        "generator_version": "hd_face_pipeline_v1",
        "seed": int(seed),
        "pixel_scale": PIXEL_SCALE,
        "logical_size": {"width": LOGICAL_SIZE[0], "height": LOGICAL_SIZE[1]},
        "texture_size": {"width": HD_SIZE[0], "height": HD_SIZE[1]},
        "races": list(RACES),
        "presets": list(PRESETS),
        "catalog_count": len(catalog_manifest),
        "frame_counts": frame_counts,
        "warning_count": warning_count,
        "catalogs": catalog_manifest,
    }
    _write_json(output_root / "manifest.json", manifest)
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate standalone 2x pixel face catalogs")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--seed", type=int, default=20260726)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        manifest = generate_hd_catalog(args.output_dir, args.seed)
    except ValueError as error:
        print(f"generation failed: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"output_dir": args.output_dir, "catalog_count": manifest["catalog_count"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
