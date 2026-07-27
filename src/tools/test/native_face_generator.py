"""Generate self-owned pixel face components without reference image inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


GENERATOR_VERSION = "native_face_v3"
FRAME_WIDTH = 36
FRAME_HEIGHT = 34
DIRECTIONS = ("D", "L", "R", "U")
STATES = ("stand", "walk")
LAYERS = ("base", "socket_cover", "eye", "brow", "mouth", "ear", "composite")
FRAME_COUNT = len(DIRECTIONS) * (1 + 6)
FACE_ID_PATTERN = re.compile(r"^[a-z0-9_]+$")

RGBA = tuple[int, int, int, int]
Point = tuple[int, int]


@dataclass(frozen=True)
class FacePalette:
    name: str
    skin: RGBA
    skin_shadow: RGBA
    skin_highlight: RGBA
    outline: RGBA
    eye_white: RGBA
    iris: RGBA
    pupil: RGBA
    brow: RGBA
    mouth: RGBA
    back_shadow: RGBA


PALETTES = (
    FacePalette(
        name="coral_01",
        skin=(238, 170, 145, 255),
        skin_shadow=(194, 105, 100, 255),
        skin_highlight=(255, 207, 174, 255),
        outline=(92, 57, 67, 255),
        eye_white=(255, 246, 226, 255),
        iris=(53, 142, 171, 255),
        pupil=(35, 36, 58, 255),
        brow=(98, 61, 72, 255),
        mouth=(139, 61, 75, 255),
        back_shadow=(157, 79, 91, 255),
    ),
    FacePalette(
        name="apricot_02",
        skin=(242, 184, 139, 255),
        skin_shadow=(199, 119, 86, 255),
        skin_highlight=(255, 220, 169, 255),
        outline=(77, 59, 67, 255),
        eye_white=(255, 249, 231, 255),
        iris=(91, 136, 191, 255),
        pupil=(38, 39, 61, 255),
        brow=(84, 62, 72, 255),
        mouth=(153, 75, 73, 255),
        back_shadow=(164, 93, 77, 255),
    ),
    FacePalette(
        name="rose_03",
        skin=(232, 155, 157, 255),
        skin_shadow=(178, 89, 112, 255),
        skin_highlight=(250, 198, 190, 255),
        outline=(76, 53, 78, 255),
        eye_white=(255, 244, 231, 255),
        iris=(95, 170, 145, 255),
        pupil=(42, 39, 65, 255),
        brow=(91, 57, 83, 255),
        mouth=(137, 55, 91, 255),
        back_shadow=(148, 72, 102, 255),
    ),
)


HEAD_SHAPES = (
    (
        (15, 20), (12, 23), (9, 26), (7, 28), (6, 29), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (5, 30), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (5, 30), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (5, 30), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (6, 29), (7, 28),
        (9, 26), (12, 23), (15, 20), (16, 19),
    ),
    (
        (14, 21), (11, 24), (8, 27), (7, 28), (6, 29), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (5, 30), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (5, 30), (5, 30),
        (5, 30), (5, 30), (5, 30), (5, 30), (5, 30), (5, 30),
        (5, 30), (5, 30), (5, 30), (6, 29), (7, 28), (8, 27),
        (11, 24), (14, 21), (15, 20), (16, 19),
    ),
)


WALK_BOB = (0, -1, 0, 1, 0, -1)
EAR_SIZES = ("small", "medium", "large")
EAR_ANGLES = ("down", "neutral", "up")
EAR_POINTS = ("round", "soft_point", "pointed")
EAR_INNER_COLORS = ("warm_rose", "soft_coral", "deep_pink")
EAR_VISIBILITIES = ("full", "subtle", "hidden")


def _seed_factor(seed: int, divisor: int, values: tuple[str, ...]) -> str:
    return values[(seed // divisor) % len(values)]


def _ear_factors(seed: int) -> dict[str, str]:
    return {
        "ear_type": "human",
        "size": _seed_factor(seed, 1, EAR_SIZES),
        "angle": _seed_factor(seed, 3, EAR_ANGLES),
        "point": _seed_factor(seed, 9, EAR_POINTS),
        "inner_color": _seed_factor(seed, 27, EAR_INNER_COLORS),
        "visibility": _seed_factor(seed, 81, EAR_VISIBILITIES),
    }


def _blank() -> Image.Image:
    return Image.new("RGBA", (FRAME_WIDTH, FRAME_HEIGHT), (0, 0, 0, 0))


def _put(image: Image.Image, x: int, y: int, color: RGBA) -> None:
    if 0 <= x < image.width and 0 <= y < image.height:
        image.putpixel((x, y), color)


def _shift(point: Point, dx: int, dy: int) -> Point:
    return point[0] + dx, point[1] + dy


def _draw_head(base: Image.Image, palette: FacePalette, shape_index: int, direction: str, dy: int) -> None:
    rows = HEAD_SHAPES[shape_index]
    pixels = base.load()
    for y, (left, right) in enumerate(rows):
        target_y = y + dy
        if not 0 <= target_y < base.height:
            continue
        for x in range(left, right + 1):
            pixels[x, target_y] = palette.skin
        _put(base, left, target_y, palette.outline)
        _put(base, right, target_y, palette.outline)

        if y in (7, 8, 9) and left + 1 <= right - 1:
            _put(base, left + 1, target_y, palette.skin_highlight)
        if y in (25, 26, 27) and left + 1 <= right - 1:
            _put(base, right - 1, target_y, palette.skin_shadow)

    if direction == "U":
        draw = ImageDraw.Draw(base)
        draw.rectangle((11, 8 + dy, 24, 25 + dy), fill=palette.back_shadow)
        draw.rectangle((13, 8 + dy, 22, 10 + dy), fill=palette.skin_shadow)
        for x in range(14, 23):
            _put(base, x, 11 + dy, palette.skin_highlight)


def _draw_socket_cover(layer: Image.Image, palette: FacePalette, direction: str, dy: int) -> None:
    if direction == "D":
        rectangles = ((7, 13, 16, 23), (20, 13, 29, 23))
    elif direction == "L":
        rectangles = ((9, 14, 18, 24),)
    elif direction == "R":
        rectangles = ((17, 14, 26, 24),)
    else:
        rectangles = ()
    draw = ImageDraw.Draw(layer)
    for x1, y1, x2, y2 in rectangles:
        draw.rectangle((x1, y1 + dy, x2, y2 + dy), fill=palette.skin)


def _ellipse_points(center: Point, radius_x: int, radius_y: int) -> list[Point]:
    cx, cy = center
    points = []
    for y in range(cy - radius_y, cy + radius_y + 1):
        for x in range(cx - radius_x, cx + radius_x + 1):
            dx = (x - cx) / max(1, radius_x)
            dy = (y - cy) / max(1, radius_y)
            if dx * dx + dy * dy <= 1.0:
                points.append((x, y))
    return points


def _draw_eye(
    layer: Image.Image,
    center: Point,
    palette: FacePalette,
    style_index: int,
    dy: int,
) -> None:
    cx, cy = center
    outer = _ellipse_points((cx, cy + dy), 5, 5)
    iris = _ellipse_points((cx, cy + dy), 3 if style_index == 0 else 2, 3)
    pupil = _ellipse_points((cx, cy + dy), 1, 2)
    for point in outer:
        _put(layer, *point, palette.outline)
    for point in _ellipse_points((cx, cy + dy), 4, 4 if style_index == 0 else 3):
        _put(layer, *point, palette.eye_white)
    for point in iris:
        _put(layer, *point, palette.iris)
    for point in pupil:
        _put(layer, *point, palette.pupil)
    highlight_x = cx - 1 if style_index == 0 else cx + 1
    _put(layer, highlight_x, cy - 1 + dy, palette.eye_white)


def _draw_eyes(layer: Image.Image, palette: FacePalette, direction: str, style_index: int, dy: int) -> None:
    if direction == "D":
        centers = ((12, 20), (24, 20))
    elif direction == "L":
        centers = ((14, 20),)
    elif direction == "R":
        centers = ((22, 20),)
    else:
        centers = ()
    for center in centers:
        _draw_eye(layer, center, palette, style_index, dy)


def _draw_brow(layer: Image.Image, palette: FacePalette, direction: str, style_index: int, dy: int) -> None:
    if direction == "D":
        ranges = ((8, 15), (21, 28))
    elif direction == "L":
        ranges = ((10, 17),)
    elif direction == "R":
        ranges = ((19, 26),)
    else:
        ranges = ()
    for index, (start, end) in enumerate(ranges):
        for x in range(start, end + 1):
            curve = 1 if (x - start) in (0, end - start) else 0
            if style_index == 1 and index % 2 == 0:
                curve = 1 - curve
            _put(layer, x, 12 + curve + dy, palette.brow)


def _draw_mouth(layer: Image.Image, palette: FacePalette, direction: str, dy: int) -> None:
    # The slot stays available for future cosmetic overlays; the base face has no mouth.
    return


def _mirror_points(points: list[Point]) -> list[Point]:
    return [(FRAME_WIDTH - 1 - x, y) for x, y in points]


def _ear_polygon(
    outer: int,
    inner: int,
    top: int,
    bottom: int,
    point_style: str,
) -> list[Point]:
    if point_style == "round":
        return [
            (outer + 1, top),
            (inner - 1, top),
            (inner, top + 2),
            (inner, bottom - 2),
            (inner - 1, bottom),
            (outer + 1, bottom),
            (outer, bottom - 2),
            (outer, top + 2),
        ]
    if point_style == "soft_point":
        return [
            (outer + 2, top - 1),
            (inner - 1, top),
            (inner, top + 2),
            (inner, bottom - 2),
            (inner - 1, bottom),
            (outer + 1, bottom),
            (outer, bottom - 2),
            (outer + 1, top + 1),
        ]
    return [
        (outer + 1, top - 1),
        (inner - 1, top),
        (inner, top + 2),
        (inner, bottom - 2),
        (inner - 1, bottom),
        (outer + 1, bottom),
        (outer, bottom - 2),
        (outer + 1, top + 1),
    ]


def _with_alpha(color: RGBA, alpha: int) -> RGBA:
    return color[0], color[1], color[2], alpha


def _draw_ear_side(
    layer: Image.Image,
    palette: FacePalette,
    side: str,
    factors: dict[str, str],
    dy: int,
) -> None:
    size_index = EAR_SIZES.index(factors["size"])
    width = (5, 6, 7)[size_index]
    height = (6, 7, 8)[size_index]
    angle_offset = {"down": 1, "neutral": 0, "up": -1}[factors["angle"]]
    top = 16 + angle_offset + dy
    bottom = top + height - 1
    inner = 5
    outer = inner - width
    outline_points = _ear_polygon(outer, inner, top, bottom, factors["point"])
    if side == "right":
        outline_points = _mirror_points(outline_points)

    inner_color = {
        "warm_rose": palette.back_shadow,
        "soft_coral": palette.skin_shadow,
        "deep_pink": palette.mouth,
    }[factors["inner_color"]]
    if factors["visibility"] == "subtle":
        outline_color = _with_alpha(palette.outline, 190)
        inner_color = _with_alpha(inner_color, 180)
    else:
        outline_color = palette.outline
    draw = ImageDraw.Draw(layer)
    draw.polygon(outline_points, fill=outline_color)

    inner_points = _ear_polygon(outer + 1, inner - 1, top + 2, bottom - 1, "round")
    if side == "right":
        inner_points = _mirror_points(inner_points)
    draw.polygon(inner_points, fill=inner_color)


def _draw_ears(
    layer: Image.Image,
    palette: FacePalette,
    direction: str,
    factors: dict[str, str],
    dy: int,
) -> None:
    if factors["visibility"] == "hidden":
        return
    if direction in ("D", "U"):
        sides = ("left", "right")
    elif direction == "L":
        sides = ("right",)
    else:
        sides = ("left",)
    for side in sides:
        _draw_ear_side(layer, palette, side, factors, dy)


def _frame_names() -> list[tuple[str, str, int]]:
    frames = []
    for direction in DIRECTIONS:
        frames.append(("stand", direction, 0))
        for frame in range(6):
            frames.append(("walk", direction, frame))
    return frames


def _frame_shift(state: str, frame: int) -> int:
    if state == "stand":
        return 0
    return WALK_BOB[frame % len(WALK_BOB)]


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _scale_image(image: Image.Image, pixel_scale: int) -> Image.Image:
    if pixel_scale == 1:
        return image
    return image.resize(
        (FRAME_WIDTH * pixel_scale, FRAME_HEIGHT * pixel_scale),
        resample=Image.Resampling.NEAREST,
    )


def generate_face_catalog(
    output_dir: Path | str,
    seed: int,
    face_id: str = "face_round_01",
    pixel_scale: int = 1,
) -> dict:
    seed = int(seed)
    if seed < 0:
        raise ValueError("seed must be non-negative")
    if pixel_scale not in (1, 2):
        raise ValueError("pixel_scale must be 1 or 2")
    if not FACE_ID_PATTERN.fullmatch(face_id):
        raise ValueError("face_id must contain lowercase letters, digits, and underscores only")

    output_root = Path(output_dir).expanduser().resolve()
    output_root.mkdir(parents=True, exist_ok=True)
    palette = PALETTES[seed % len(PALETTES)]
    shape_index = seed % len(HEAD_SHAPES)
    eye_style = (seed // len(PALETTES)) % 2
    ear_factors = _ear_factors(seed)
    factors = {
        "head_shape": "round_soft" if shape_index == 0 else "round_wide",
        "skin_palette": palette.name,
        "eye_style": "large_round_01" if eye_style == 0 else "large_round_02",
        "brow_style": "soft_arc_01" if eye_style == 0 else "soft_arc_02",
        "mouth_status": "reserved_decoration_only",
        **ear_factors,
    }
    manifest = {
        "generator_version": GENERATOR_VERSION,
        "source": "procedural_local",
        "reference_inputs": [],
        "seed": seed,
        "face_id": face_id,
        "logical_size": {"width": FRAME_WIDTH, "height": FRAME_HEIGHT},
        "pixel_scale": pixel_scale,
        "size": {"width": FRAME_WIDTH * pixel_scale, "height": FRAME_HEIGHT * pixel_scale},
        "directions": list(DIRECTIONS),
        "states": list(STATES),
        "frame_count": FRAME_COUNT,
        "layers": list(LAYERS),
        "slots": {"mouth": "reserved_decoration_only"},
        "style_contract": {
            "face_language": "western_fantasy_chibi",
            "head_coverage": "dominant",
            "eye_scale": "large",
            "mouth": "reserved_empty",
            "rendering": "procedural_pixel_art",
        },
        "factors": factors,
        "frames": {},
    }

    for state, direction, frame in _frame_names():
        dy = _frame_shift(state, frame)
        base = _blank()
        socket_cover = _blank()
        eye = _blank()
        brow = _blank()
        mouth = _blank()
        ear = _blank()
        _draw_head(base, palette, shape_index, direction, dy)
        _draw_socket_cover(socket_cover, palette, direction, dy)
        _draw_eyes(eye, palette, direction, eye_style, dy)
        _draw_brow(brow, palette, direction, eye_style, dy)
        _draw_mouth(mouth, palette, direction, dy)
        _draw_ears(ear, palette, direction, ear_factors, dy)

        layers = {
            "base": base,
            "socket_cover": socket_cover,
            "eye": eye,
            "brow": brow,
            "mouth": mouth,
            "ear": ear,
        }
        composite = _blank()
        for layer_name in ("ear", "base", "socket_cover", "eye", "brow", "mouth"):
            composite.alpha_composite(layers[layer_name])
        layers["composite"] = composite

        frame_name = f"{face_id}_{state}_{direction}_{frame}.png"
        frame_record = {
            "size": {"width": FRAME_WIDTH * pixel_scale, "height": FRAME_HEIGHT * pixel_scale},
            "sha256": {},
        }
        for layer_name in LAYERS:
            path = output_root / layer_name / frame_name
            _save_png(_scale_image(layers[layer_name], pixel_scale), path)
            frame_record["sha256"][layer_name] = _sha256(path)
        manifest["frames"][frame_name] = frame_record

    (output_root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate self-owned procedural face components")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[3] / "assets" / "test" / "native_face_v3")
    parser.add_argument("--seed", type=int, default=20260727)
    parser.add_argument("--face-id", default="face_round_01")
    parser.add_argument("--pixel-scale", type=int, choices=(1, 2), default=1)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    manifest = generate_face_catalog(args.output_dir, args.seed, args.face_id, args.pixel_scale)
    print(json.dumps({"output_dir": str(args.output_dir), "frame_count": manifest["frame_count"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
