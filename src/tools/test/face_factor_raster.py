"""Deterministic pixel rasterizers for parameterized face components."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from typing import Iterable

from PIL import Image, ImageDraw

from .face_factor_model import resolve_seed_variant


RGBA = tuple[int, int, int, int]
Point = tuple[int, int]
Rect = tuple[int, int, int, int]

SKIN_FALLBACK: RGBA = (240, 144, 112, 255)
EYE_WHITE: RGBA = (255, 245, 225, 255)
EYE_IRIS: RGBA = (60, 145, 205, 255)
EYE_PUPIL: RGBA = (30, 25, 40, 255)
EYE_HIGHLIGHT: RGBA = (255, 255, 255, 255)
BROW: RGBA = (95, 58, 45, 255)


@dataclass(frozen=True)
class DirectionAnchors:
    socket_rects: tuple[Rect, ...]
    brow_lines: tuple[tuple[int, int, int], ...]
    eye_centers: tuple[tuple[float, float], ...]
    ear_sides: tuple[str, ...]
    ear_inner_xs: tuple[int, ...]


@dataclass
class RasterResult:
    layers: dict[str, Image.Image]
    warnings: list[str]
    coverage: dict[str, int]
    socket_mask: set[Point] = field(default_factory=set)


def _clamp_point(point: Point, width: int, height: int) -> Point:
    return max(0, min(width - 1, point[0])), max(0, min(height - 1, point[1]))


def _anchors(width: int, height: int, direction: str) -> DirectionAnchors:
    if direction == "D":
        return DirectionAnchors(
            socket_rects=((7, 19, min(28, width - 1), min(29, height - 1)),),
            brow_lines=((7, min(14, width - 1), 20), (20, min(27, width - 1), 20)),
            eye_centers=((11.5, 25.5), (23.5, 25.5)),
            ear_sides=("L", "R"),
            ear_inner_xs=(5, max(0, width - 6)),
        )
    if direction == "L":
        return DirectionAnchors(
            socket_rects=(
                (1, 18, min(10, width - 1), min(29, height - 1)),
                (max(0, width - 18), 20, min(width - 10, width - 1), min(29, height - 1)),
            ),
            brow_lines=((2, min(8, width - 1), 19),),
            eye_centers=((5.5, 24.5),),
            ear_sides=("R",),
            ear_inner_xs=(max(0, width - 17),),
        )
    if direction == "R":
        return DirectionAnchors(
            socket_rects=(
                (max(0, width - 25), 20, min(width - 15, width - 1), min(29, height - 1)),
                (max(0, width - 9), 18, width - 2, min(29, height - 1)),
            ),
            brow_lines=((max(0, width - 9), width - 3, 19),),
            eye_centers=((width - 19.5, 24.5),),
            ear_sides=("R",),
            ear_inner_xs=(max(0, width - 8),),
        )
    if direction == "U":
        return DirectionAnchors(
            socket_rects=(),
            brow_lines=(),
            eye_centers=(),
            ear_sides=("L", "R"),
            ear_inner_xs=(5, max(0, width - 6)),
        )
    raise ValueError(f"不支持的方向: {direction}")


def _opaque_colors(image: Image.Image) -> Counter[tuple[int, int, int]]:
    return Counter(
        (r, g, b)
        for r, g, b, alpha in image.get_flattened_data()
        if alpha >= 128
    )


def _skin_palette(image: Image.Image) -> tuple[RGBA, RGBA, RGBA]:
    colors = _opaque_colors(image)
    base = colors.most_common(1)[0][0] if colors else SKIN_FALLBACK[:3]
    shadow = tuple(max(0, int(channel * 0.86)) for channel in base)
    highlight = tuple(min(255, int(channel * 1.08)) for channel in base)
    return (*base, 255), (*shadow, 255), (*highlight, 255)


def _set_pixel(layer: Image.Image, x: int, y: int, color: RGBA) -> None:
    if 0 <= x < layer.width and 0 <= y < layer.height:
        layer.putpixel((x, y), color)


def _ellipse_points(cx: float, cy: float, rx: int, ry: int) -> Iterable[Point]:
    rx = max(1, rx)
    ry = max(1, ry)
    for y in range(int(cy) - ry, int(cy) + ry + 1):
        for x in range(int(cx) - rx, int(cx) + rx + 1):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                yield x, y


def _draw_brow(layer: Image.Image, line: tuple[int, int, int], thickness: int, curve: int) -> set[Point]:
    x1, x2, y = line
    pixels: set[Point] = set()
    span = max(1, x2 - x1)
    for x in range(min(x1, x2), max(x1, x2) + 1):
        curve_offset = round(curve * (x - x1) / span)
        for dy in range(max(1, thickness)):
            point = (x, y + curve_offset + dy)
            _set_pixel(layer, *point, BROW)
            pixels.add(point)
    return pixels


def _draw_eye(
    layer: Image.Image,
    center: tuple[float, float],
    scale_x: float,
    scale_y: float,
    pupil_offset: list[int],
) -> set[Point]:
    cx, cy = center
    rx = max(1, round(3 * scale_x))
    ry = max(1, round(3 * scale_y))
    pixels: set[Point] = set()
    for point in _ellipse_points(cx, cy, rx, ry):
        _set_pixel(layer, *point, EYE_WHITE)
        pixels.add(point)

    iris_rx = max(1, round(rx * 0.55))
    iris_ry = max(1, round(ry * 0.65))
    iris_center = (cx + pupil_offset[0], cy + pupil_offset[1])
    for point in _ellipse_points(iris_center[0], iris_center[1], iris_rx, iris_ry):
        _set_pixel(layer, *point, EYE_IRIS)
        pixels.add(point)

    pupil_rx = max(1, round(iris_rx * 0.55))
    pupil_ry = max(1, round(iris_ry * 0.65))
    for point in _ellipse_points(iris_center[0], iris_center[1], pupil_rx, pupil_ry):
        _set_pixel(layer, *point, EYE_PUPIL)
        pixels.add(point)

    highlight = (round(iris_center[0] - max(1, iris_rx * 0.55)), round(iris_center[1] - max(1, iris_ry * 0.55)))
    _set_pixel(layer, *highlight, EYE_HIGHLIGHT)
    pixels.add(highlight)
    return pixels


def _ear_polygon(
    width: int,
    height: int,
    side: str,
    ear_type: str,
    length: int,
    tip_raise: int,
    outer_spread: int,
    inner_x: int | None = None,
) -> list[Point]:
    if side == "L":
        inner = (min(width - 1, 5 if inner_x is None else inner_x), min(height - 1, 21))
        outer = (0, min(height - 1, 26))
        tip_x = max(0, inner[0] - length - outer_spread)
        tip = (tip_x, max(0, inner[1] - tip_raise))
    else:
        inner = (max(0, width - 6 if inner_x is None else inner_x), min(height - 1, 21))
        outer = (width - 1, min(height - 1, 26))
        extension = length + outer_spread if inner_x is None else max(7, length + outer_spread + 7)
        tip_x = min(width - 1, inner[0] + extension)
        tip = (tip_x, max(0, inner[1] - tip_raise))

    if ear_type == "beast":
        tip = (tip[0], max(0, tip[1] - 1))
    return [inner, tip, outer, (inner[0], min(height - 1, 29))]


def _draw_ear(
    layer: Image.Image,
    side: str,
    ear_type: str,
    length: int,
    tip_raise: int,
    outer_spread: int,
    skin_palette: tuple[RGBA, RGBA, RGBA],
    inner_x: int | None = None,
) -> set[Point]:
    polygon = _ear_polygon(
        layer.width,
        layer.height,
        side,
        ear_type,
        length,
        tip_raise,
        outer_spread,
        inner_x,
    )
    draw = ImageDraw.Draw(layer)
    draw.polygon(polygon, fill=skin_palette[0])
    inner = polygon[0]
    inner_shadow = [
        (inner[0], inner[1] + 1),
        (polygon[1][0], polygon[1][1] + 1),
        (polygon[2][0], polygon[2][1] - 1),
    ]
    draw.polygon(inner_shadow, fill=skin_palette[1])
    return {
        (x, y)
        for y in range(layer.height)
        for x in range(layer.width)
        if layer.getpixel((x, y))[3] > 0
    }


def _socket_points(rects: Iterable[Rect], width: int, height: int) -> set[Point]:
    points: set[Point] = set()
    for x1, y1, x2, y2 in rects:
        for y in range(max(0, y1), min(height - 1, y2) + 1):
            for x in range(max(0, x1), min(width - 1, x2) + 1):
                points.add((x, y))
    return points


def _draw_socket_cover(
    layer: Image.Image,
    base: Image.Image,
    socket_points: set[Point],
    skin_color: RGBA,
) -> set[Point]:
    covered: set[Point] = set()
    for x, y in socket_points:
        if base.getpixel((x, y))[3] < 128:
            _set_pixel(layer, x, y, skin_color)
            covered.add((x, y))
    return covered


def _alpha_points(image: Image.Image) -> set[Point]:
    return {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if image.getpixel((x, y))[3] > 0
    }


def rasterize_variant(
    base: Image.Image,
    direction: str,
    factors: dict[str, dict],
    seed: int,
) -> RasterResult:
    if base.mode != "RGBA":
        base = base.convert("RGBA")
    factors = resolve_seed_variant(factors, seed)
    anchors = _anchors(base.width, base.height, direction)
    skin_palette = _skin_palette(base)
    layers = {
        name: Image.new("RGBA", base.size, (0, 0, 0, 0))
        for name in ("socket_cover", "brow", "eye", "ear")
    }

    socket_region = _socket_points(anchors.socket_rects, base.width, base.height)
    socket_mask = {
        point for point in socket_region if base.getpixel(point)[3] < 128
    }
    covered = _draw_socket_cover(layers["socket_cover"], base, socket_mask, skin_palette[0])

    brow_factors = factors.get("brow", {})
    brow_pixels: set[Point] = set()
    for line in anchors.brow_lines:
        brow_pixels |= _draw_brow(
            layers["brow"],
            line,
            int(brow_factors.get("thickness", 1)),
            int(brow_factors.get("curve", 0)),
        )

    eye_factors = factors.get("eye", {})
    eye_pixels: set[Point] = set()
    for center in anchors.eye_centers:
        eye_pixels |= _draw_eye(
            layers["eye"],
            center,
            float(eye_factors.get("scale_x", 1.0)),
            float(eye_factors.get("scale_y", 1.0)),
            list(eye_factors.get("pupil_offset", [0, 0])),
        )

    ear_factors = factors.get("ear", {})
    ear_pixels: set[Point] = set()
    for side, inner_x in zip(anchors.ear_sides, anchors.ear_inner_xs):
        ear_pixels |= _draw_ear(
            layers["ear"],
            side,
            str(ear_factors.get("type", "human")),
            int(ear_factors.get("length", 0)),
            int(ear_factors.get("tip_raise", 0)),
            int(ear_factors.get("outer_spread", 0)),
            skin_palette,
            inner_x,
        )

    warnings: list[str] = []
    if socket_mask and len(covered) < len(socket_mask):
        warnings.append(f"socket_cover 覆盖不足: {len(socket_mask) - len(covered)} px")
    if brow_pixels & eye_pixels:
        warnings.append("组件重叠: brow 与 eye")
    if ear_pixels & eye_pixels:
        warnings.append("组件重叠: ear 与 eye")

    return RasterResult(
        layers=layers,
        warnings=warnings,
        coverage={
            "socket_expected": len(socket_mask),
            "socket_covered": len(covered),
            "brow_pixels": len(brow_pixels),
            "eye_pixels": len(eye_pixels),
            "ear_pixels": len(ear_pixels),
        },
        socket_mask=socket_mask,
    )


def validate_coverage(result: RasterResult) -> list[str]:
    warnings = list(result.warnings)
    cover = result.layers["socket_cover"]
    uncovered = [point for point in result.socket_mask if cover.getpixel(point)[3] == 0]
    if uncovered:
        warnings.append(f"socket_cover 仍有透明孔: {len(uncovered)} px")
    return warnings
