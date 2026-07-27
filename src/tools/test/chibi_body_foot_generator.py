"""Generate project-owned short chibi body and foot layers."""

from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw


GENERATOR_VERSION = "chibi_body_foot_v1"
FRAME_SIZE = (18, 26)
DIRECTIONS = ("R", "U", "L", "D")
LAYERS = ("body", "foot")
WALK_FRAMES = 6

OUTLINE = (43, 34, 48, 255)
BODY_PALETTES = (
    ((91, 68, 104, 255), (121, 94, 132, 255), (157, 126, 153, 255)),
    ((65, 78, 103, 255), (91, 111, 139, 255), (133, 151, 168, 255)),
    ((103, 74, 62, 255), (137, 96, 76, 255), (174, 131, 98, 255)),
)
FOOT_PALETTE = (
    (47, 40, 57, 255),
    (72, 59, 77, 255),
    (118, 93, 101, 255),
)


def _new_canvas() -> Image.Image:
    return Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))


def _draw_body_front(image: Image.Image, palette, direction: str, walk_phase: int) -> None:
    draw = ImageDraw.Draw(image)
    shadow, base, highlight = palette
    arm_shift = -1 if walk_phase in (1, 2) else 1 if walk_phase in (4, 5) else 0

    if direction == "D":
        draw.polygon(
            [(5, 9), (6, 8), (12, 8), (13, 9), (14, 11), (13, 12),
             (12, 12), (12, 17), (13, 18), (11, 19), (7, 19),
             (5, 18), (6, 17), (6, 12), (5, 12), (4, 11)],
            fill=base,
            outline=OUTLINE,
        )
        draw.rectangle((7, 10, 11, 16), fill=base)
        draw.rectangle((7, 11, 8, 17), fill=highlight)
        draw.rectangle((10, 12, 11, 17), fill=shadow)
        draw.line((5, 10, 3, 12 + arm_shift), fill=OUTLINE, width=2)
        draw.line((13, 10, 15, 12 - arm_shift), fill=OUTLINE, width=2)
    elif direction == "U":
        draw.polygon(
            [(5, 9), (6, 8), (12, 8), (13, 9), (14, 11), (12, 12),
             (12, 17), (13, 18), (11, 19), (7, 19), (5, 18),
             (6, 17), (6, 12), (4, 11)],
            fill=shadow,
            outline=OUTLINE,
        )
        draw.rectangle((7, 10, 11, 16), fill=base)
        draw.rectangle((7, 10, 8, 16), fill=highlight)
        draw.line((5, 10, 3, 12 + arm_shift), fill=OUTLINE, width=2)
        draw.line((13, 10, 15, 12 - arm_shift), fill=OUTLINE, width=2)
    else:
        side = direction == "R"
        left = 6 if side else 5
        right = 12 if side else 11
        draw.polygon(
            [(left, 9), (left + 1, 8), (right, 8), (right + 1, 10),
             (right, 12), (right, 17), (right + 1, 18), (right - 1, 19),
             (left, 19), (left - 1, 17), (left, 12), (left - 2, 11)],
            fill=base,
            outline=OUTLINE,
        )
        draw.rectangle((left + 1, 10, right - 1, 16), fill=base)
        draw.rectangle((left + 1, 10, left + 2, 16), fill=highlight)
        draw.rectangle((right - 1, 12, right, 17), fill=shadow)
        draw.line((left - 1, 10, left - 3, 12 + arm_shift), fill=OUTLINE, width=2)


def _draw_foot_front(image: Image.Image, direction: str, walk_phase: int) -> None:
    draw = ImageDraw.Draw(image)
    shadow, base, highlight = FOOT_PALETTE
    stride = -1 if walk_phase in (1, 2) else 1 if walk_phase in (4, 5) else 0

    if direction in ("D", "U"):
        left_x = 3 + stride
        right_x = 10 - stride
        pairs = ((left_x, 8), (right_x, 15))
    elif direction == "R":
        pairs = ((5 + stride, 10), (9 - stride, 14))
    else:
        pairs = ((4 - stride, 9), (8 + stride, 13))

    for x1, x2 in pairs:
        draw.polygon(
            [(x1, 19), (x2 - 1, 19), (x2, 20), (x2, 23),
             (x2 - 1, 24), (x1, 24), (x1 - 1, 23), (x1 - 1, 20)],
            fill=base,
            outline=OUTLINE,
        )
        draw.rectangle((x1, 20, x2 - 1, 21), fill=highlight)
        draw.rectangle((x2 - 1, 22, x2, 23), fill=shadow)


def _write_image(path: Path, image: Image.Image) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False)
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate_body_foot_catalog(output_dir: Path | str, seed: int = 20260727) -> dict:
    """Write deterministic project-owned Body and Foot layers and return metadata."""
    output_path = Path(output_dir).resolve()
    output_path.mkdir(parents=True, exist_ok=True)
    palette = random.Random(seed).choice(BODY_PALETTES)
    frame_hashes = {layer: {} for layer in LAYERS}

    for layer in LAYERS:
        for direction in DIRECTIONS:
            stand_name = f"{layer}_short_v1_stand_{direction}_0.png"
            image = _new_canvas()
            if layer == "body":
                _draw_body_front(image, palette, direction, 0)
            else:
                _draw_foot_front(image, direction, 0)
            frame_hashes[layer][stand_name] = _write_image(
                output_path / layer / stand_name, image
            )

            for walk_phase in range(WALK_FRAMES):
                walk_name = f"{layer}_short_v1_walk_{direction}_{walk_phase}.png"
                image = _new_canvas()
                if layer == "body":
                    _draw_body_front(image, palette, direction, walk_phase)
                else:
                    _draw_foot_front(image, direction, walk_phase)
                frame_hashes[layer][walk_name] = _write_image(
                    output_path / layer / walk_name, image
                )

    manifest = {
        "generator_version": GENERATOR_VERSION,
        "seed": seed,
        "source": "project_owned_redraw",
        "reference_policy": "abstract_proportion_study_only",
        "frame_size": {"width": FRAME_SIZE[0], "height": FRAME_SIZE[1]},
        "layers": list(LAYERS),
        "directions": list(DIRECTIONS),
        "walk_frame_count": WALK_FRAMES,
        "frame_counts": {"stand_per_direction": 1, "walk_per_direction": WALK_FRAMES},
        "style_contract": {
            "head": "owned_face_layer_composes above body",
            "body": "short rounded torso with compact limbs",
            "foot": "separate wide grounded foot layer",
            "mouth": "not_present_in_body_or_foot",
            "body_height_limit": 12,
            "foot_height_limit": 7,
        },
        "frames": frame_hashes,
    }
    (output_path / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20260727)
    args = parser.parse_args()
    generate_body_foot_catalog(args.output, seed=args.seed)


if __name__ == "__main__":
    main()
