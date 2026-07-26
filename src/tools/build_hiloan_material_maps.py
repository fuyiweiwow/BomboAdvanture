#!/usr/bin/env python3
"""Build tintable skin and garment maps from the vendored texture sources."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from PIL import ImageDraw

import build_hiloan_3d_assets as assets


PROJECT_ROOT = Path(__file__).resolve().parents[2]
TEXTURE_ROOT = PROJECT_ROOT / "assets/creator/hiloan_3d/textures"
STYLES = ("academy", "field", "coastal")
OUTPUT_SIZE = (1024, 1024)
TINTABLE_ALPHA = (
    "hair_short",
    "hair_crop",
    "hair_swept",
    "eyebrow_natural",
    "eyebrow_arched",
    "eyebrow_full",
)
EXTERNAL_TINTABLE = {
    "coastal_tunic": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/rehmanpolanski_viking_tunic/TUNIC_Viking.png"
    ),
    "coastal_pants": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/rehmanpolanski_viking_pants/PantsViking.png"
    ),
    "field_uniform": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/thegreatengineer_galactic_warrior_uniform/Glactic_Warrior_02.png"
    ),
    "academy_robe": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/donitz_monk_robe/robe_brown__diffuse.png"
    ),
    "travel_shoes": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/culturalibre_male_boots/boot.png"
    ),
    "low_shoes": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/toigo_ankle_boots_male/BootsAnkleM.png"
    ),
    "travel_boots": (
        PROJECT_ROOT
        / "assets/creator/hiloan_3d/vendor/makehuman/clothes/rehmanpolanski_viking_boots/BootsViking.png"
    ),
}


def build_style(name: str) -> None:
    source_image = Image.open(TEXTURE_ROOT / f"{name}_source.png").convert("RGB").resize(OUTPUT_SIZE, Image.Resampling.LANCZOS)
    source = np.asarray(source_image, dtype=np.float32)
    luminance = source @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    low, high = np.percentile(luminance, (3.0, 97.0))
    normalized = np.clip((luminance - low) / max(1.0, high - low), 0.0, 1.0)

    detail = (0.52 + normalized * 0.48) * 255.0
    detail_rgb = np.repeat(detail[:, :, None], 3, axis=2).astype(np.uint8)
    Image.fromarray(detail_rgb, "RGB").save(TEXTURE_ROOT / f"{name}_detail.png", optimize=True)

    source_normal_path = TEXTURE_ROOT / f"{name}_normal_source.png"
    if source_normal_path.exists():
        Image.open(source_normal_path).convert("RGB").resize(OUTPUT_SIZE, Image.Resampling.LANCZOS).save(
            TEXTURE_ROOT / f"{name}_normal.png",
            optimize=True,
        )
    else:
        write_normal_map(normalized, TEXTURE_ROOT / f"{name}_normal.png", 2.4)


def write_normal_map(height: np.ndarray, path: Path, strength: float) -> None:
    gradient_y, gradient_x = np.gradient(height)
    normal = np.dstack((-gradient_x * strength, gradient_y * strength, np.ones_like(height)))
    normal /= np.maximum(np.linalg.norm(normal, axis=2, keepdims=True), 1e-6)
    normal_rgb = np.clip((normal * 0.5 + 0.5) * 255.0, 0.0, 255.0).astype(np.uint8)
    Image.fromarray(normal_rgb, "RGB").save(path, optimize=True)


def build_skin() -> None:
    width, height = OUTPUT_SIZE
    rng = np.random.default_rng(1947)
    source = np.clip(rng.normal(0.5, 0.15, (height, width)), 0.0, 1.0)
    source_image = Image.fromarray((source * 255.0).astype(np.uint8), "L")
    broad = np.asarray(source_image.filter(ImageFilter.GaussianBlur(18.0)), dtype=np.float32) / 255.0
    pores = np.asarray(source_image.filter(ImageFilter.GaussianBlur(0.75)), dtype=np.float32) / 255.0

    broad = np.clip((broad - broad.mean()) / max(broad.std(), 1e-6), -2.5, 2.5)
    pores = np.clip((pores - pores.mean()) / max(pores.std(), 1e-6), -2.5, 2.5)
    detail = np.clip(0.970 + broad * 0.0030 + pores * 0.0045, 0.950, 0.987)
    detail_rgb = np.repeat((detail * 255.0).astype(np.uint8)[:, :, None], 3, axis=2)
    Image.fromarray(detail_rgb, "RGB").save(TEXTURE_ROOT / "skin_detail.png", optimize=True)
    pore_height = 0.5 + pores * 0.026
    write_normal_map(pore_height, TEXTURE_ROOT / "skin_normal.png", 1.7)
    roughness = np.clip(0.76 + broad * 0.010 + pores * 0.020, 0.68, 0.84)
    Image.fromarray((roughness * 255.0).astype(np.uint8), "L").save(
        TEXTURE_ROOT / "skin_roughness.png",
        optimize=True,
    )


def build_lips() -> None:
    width, height = OUTPUT_SIZE
    rng = np.random.default_rng(3141)
    source = np.clip(rng.normal(0.5, 0.16, (height, width)), 0.0, 1.0)
    source_image = Image.fromarray((source * 255.0).astype(np.uint8), "L")
    fine = np.asarray(source_image.filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float32) / 255.0
    fine = np.clip((fine - fine.mean()) / max(fine.std(), 1e-6), -2.5, 2.5)
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    ridges = np.sin(y * np.pi * 2.0 / 23.0 + np.sin(x * np.pi * 2.0 / 83.0) * 0.42)
    height_map = 0.5 + ridges * 0.030 + fine * 0.010

    detail = np.clip(0.88 + ridges * 0.025 + fine * 0.012, 0.82, 0.94)
    detail_rgb = np.repeat((detail * 255.0).astype(np.uint8)[:, :, None], 3, axis=2)
    Image.fromarray(detail_rgb, "RGB").save(TEXTURE_ROOT / "lip_detail.png", optimize=True)
    write_normal_map(height_map, TEXTURE_ROOT / "lip_normal.png", 1.8)
    roughness = np.clip(0.42 - ridges * 0.035 + fine * 0.018, 0.34, 0.52)
    Image.fromarray((roughness * 255.0).astype(np.uint8), "L").save(
        TEXTURE_ROOT / "lip_roughness.png",
        optimize=True,
    )


def build_lip_mask() -> None:
    source_mesh = assets.parse_obj(assets.SOURCE_ROOT / "base.obj")
    lip_vertices = set().union(
        assets.target("mouth-upperlip-volume-incr.target").keys(),
        assets.target("mouth-lowerlip-volume-incr.target").keys(),
    )
    lip_core_faces = [
        face
        for face in source_mesh.groups["body"]
        if all(corner[0] in lip_vertices for corner in face)
        and all(source_mesh.vertices[corner[0]][2] > 1.52 for corner in face)
        and sum(source_mesh.vertices[corner[0]][1] for corner in face) / len(face) > 6.535
    ]
    lip_faces = assets.expand_face_region(
        source_mesh.groups["body"],
        lip_core_faces,
        1,
        lambda face: (
            all(source_mesh.vertices[corner[0]][2] > 1.47 for corner in face)
            and sum(source_mesh.vertices[corner[0]][1] for corner in face) / len(face) > 6.48
        ),
    )
    size = 2048
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    for face in lip_faces:
        points = []
        for _, uv_index in face:
            if uv_index is None:
                continue
            u, v = source_mesh.uvs[uv_index]
            points.append((u * size, v * size))
        if len(points) >= 3:
            draw.polygon(points, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2.4))
    mask.resize(OUTPUT_SIZE, Image.Resampling.LANCZOS).save(
        TEXTURE_ROOT / "lip_mask.png",
        optimize=True,
    )


def build_eyelashes() -> None:
    width, height = OUTPUT_SIZE
    rgba = np.zeros((height, width, 4), dtype=np.uint8)
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    eye_regions = (
        (0.658073, 0.706815),
        (0.709693, 0.758435),
    )
    for u_min, u_max in eye_regions:
        local_x = (x / width - u_min) / (u_max - u_min)
        local_y = (y / height - 0.052972) / (0.073065 - 0.052972)
        inside = (local_x >= 0.0) & (local_x <= 1.0) & (local_y >= 0.0) & (local_y <= 1.0)
        lash_curve = 0.54 - 0.18 * (1.0 - (local_x * 2.0 - 1.0) ** 2)
        base_alpha = np.exp(-((local_y - lash_curve) / 0.115) ** 2)
        tapered = np.maximum(
            0.0,
            np.sin(np.clip(local_x, 0.0, 1.0) * np.pi),
        ) ** 0.45
        strands = 0.72 + 0.28 * np.maximum(0.0, np.sin(local_x * np.pi * 21.0))
        alpha = np.clip(base_alpha * tapered * strands * inside, 0.0, 1.0)
        rgba[:, :, :3] = np.maximum(rgba[:, :, :3], (alpha[:, :, None] * 245.0).astype(np.uint8))
        rgba[:, :, 3] = np.maximum(rgba[:, :, 3], (alpha * 255.0).astype(np.uint8))
    Image.fromarray(rgba, "RGBA").save(TEXTURE_ROOT / "eyelash_detail.png", optimize=True)


def build_underwear() -> None:
    width, height = OUTPUT_SIZE
    rng = np.random.default_rng(2718)
    source = np.clip(rng.normal(0.5, 0.14, (height, width)), 0.0, 1.0)
    source_image = Image.fromarray((source * 255.0).astype(np.uint8), "L")
    fibers = np.asarray(source_image.filter(ImageFilter.GaussianBlur(0.55)), dtype=np.float32) / 255.0
    fibers = np.clip((fibers - fibers.mean()) / max(fibers.std(), 1e-6), -2.5, 2.5)
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    warp = np.sin(x * np.pi * 2.0 / 9.0 + np.sin(y * np.pi * 2.0 / 37.0) * 0.16)
    weft = np.sin(y * np.pi * 2.0 / 11.0)
    knit = warp * 0.56 + weft * 0.26 + fibers * 0.18

    detail = np.clip(0.79 + knit * 0.025, 0.73, 0.85)
    detail_rgb = np.repeat((detail * 255.0).astype(np.uint8)[:, :, None], 3, axis=2)
    Image.fromarray(detail_rgb, "RGB").save(TEXTURE_ROOT / "underwear_detail.png", optimize=True)
    write_normal_map(0.5 + knit * 0.035, TEXTURE_ROOT / "underwear_normal.png", 1.9)


def build_tintable_alpha(name: str) -> None:
    source = Image.open(TEXTURE_ROOT / f"{name}.png").convert("RGBA").resize(
        OUTPUT_SIZE,
        Image.Resampling.LANCZOS,
    )
    rgba = np.asarray(source, dtype=np.float32)
    luminance = rgba[:, :, :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    visible = rgba[:, :, 3] > 8
    if np.any(visible):
        low, high = np.percentile(luminance[visible], (2.0, 98.0))
    else:
        low, high = 0.0, 255.0
    normalized = np.clip((luminance - low) / max(1.0, high - low), 0.0, 1.0)
    detail = (0.34 + normalized * 0.66) * 255.0
    output = np.dstack((detail, detail, detail, rgba[:, :, 3])).astype(np.uint8)
    Image.fromarray(output, "RGBA").save(TEXTURE_ROOT / f"{name}_detail.png", optimize=True)


def build_external_tintable(name: str, source_path: Path) -> None:
    source = Image.open(source_path).convert("RGB").resize(
        OUTPUT_SIZE,
        Image.Resampling.LANCZOS,
    )
    rgb = np.asarray(source, dtype=np.float32)
    luminance = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    low, high = np.percentile(luminance, (2.0, 98.0))
    normalized = np.clip((luminance - low) / max(1.0, high - low), 0.0, 1.0)
    detail = np.clip(0.42 + normalized * 0.58, 0.38, 1.0)
    detail_rgb = np.repeat((detail * 255.0).astype(np.uint8)[:, :, None], 3, axis=2)
    Image.fromarray(detail_rgb, "RGB").save(
        TEXTURE_ROOT / f"{name}_detail.png",
        optimize=True,
    )


def main() -> None:
    for style in STYLES:
        build_style(style)
    build_skin()
    build_lips()
    build_lip_mask()
    build_eyelashes()
    build_underwear()
    for name in TINTABLE_ALPHA:
        build_tintable_alpha(name)
    for name, source_path in EXTERNAL_TINTABLE.items():
        build_external_tintable(name, source_path)
    print(f"Built Hiloan material maps in {TEXTURE_ROOT}")


if __name__ == "__main__":
    main()
