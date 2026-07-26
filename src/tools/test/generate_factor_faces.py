"""Generate deterministic, composable face-factor pixel assets."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Iterable

from PIL import Image

try:
    from .face_factor_model import parse_prompt, resolve_seed_variant
    from .face_factor_raster import rasterize_variant, validate_coverage
except ImportError:  # Support running this file by absolute path.
    project_root = Path(__file__).resolve().parents[3]
    if str(project_root) not in sys.path:
        sys.path.insert(0, str(project_root))
    from src.tools.test.face_factor_model import parse_prompt, resolve_seed_variant
    from src.tools.test.face_factor_raster import rasterize_variant, validate_coverage


GENERATOR_VERSION = "face_factor_generator_v1"
PROJECT_ROOT = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")
DEFAULT_SOURCE_DIR = PROJECT_ROOT / "assets" / "test" / "face_bases_v1"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "assets" / "test" / "face_factor_v1"
ROLES = ("male", "female")
LAYERS = ("socket_cover", "eye", "brow", "ear")
FRAME_PATTERN = re.compile(r"_(?P<direction>[DLRU])_(?P<index>\d+)\.png$", re.IGNORECASE)


def _inside_project(path: Path, label: str) -> Path:
    resolved = path.expanduser().resolve()
    project = PROJECT_ROOT.resolve()
    if resolved.drive.upper() != "E:":
        raise ValueError(f"{label} 必须位于 E: 盘工程目录内: {resolved}")
    try:
        resolved.relative_to(project)
    except ValueError as error:
        raise ValueError(f"{label} 必须位于工程目录内: {project}") from error
    return resolved


def _frame_sort_key(path: Path) -> tuple[int, int, str]:
    match = FRAME_PATTERN.search(path.name)
    if match is None:
        return (99, 99, path.name)
    direction_order = {"D": 0, "L": 1, "R": 2, "U": 3}
    return (
        direction_order[match.group("direction").upper()],
        int(match.group("index")),
        path.name,
    )


def _frame_info(path: Path) -> tuple[str, int]:
    match = FRAME_PATTERN.search(path.name)
    if match is None:
        raise ValueError(f"无法从基础脸文件名识别方向和帧编号: {path.name}")
    return match.group("direction").upper(), int(match.group("index"))


def _write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def _composite(base: Image.Image, layers: Iterable[Image.Image]) -> Image.Image:
    result = base.convert("RGBA").copy()
    for layer in layers:
        result.alpha_composite(layer)
    return result


def _write_previews(role_dir: Path, frame_paths: dict[str, Path]) -> None:
    preview_dir = role_dir / "preview"
    preview_frames_dir = preview_dir / "frames"
    for frame_name, composite_path in frame_paths.items():
        image = Image.open(composite_path).convert("RGBA")
        preview = image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST)
        _save_png(preview, preview_frames_dir / frame_name)

    for direction in ("D", "L", "R", "U"):
        candidates = [
            path for name, path in frame_paths.items()
            if re.search(rf"_stand_{direction}_\d+\.png$", name, re.IGNORECASE)
        ]
        if candidates:
            image = Image.open(candidates[0]).convert("RGBA")
            preview = image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST)
            _save_png(preview, preview_dir / f"stand_{direction}.png")


def _generate_role(
    role: str,
    source_dir: Path,
    output_dir: Path,
    factors: dict[str, dict],
    seed: int,
) -> tuple[dict, dict[str, Path]]:
    base_dir = source_dir / role / "base"
    frame_paths = sorted(base_dir.glob("*.png"), key=_frame_sort_key)
    if not frame_paths:
        raise FileNotFoundError(f"找不到 {role} 基础脸 PNG: {base_dir}")

    role_output = output_dir / role
    for layer_name in LAYERS + ("composite",):
        (role_output / layer_name).mkdir(parents=True, exist_ok=True)

    manifest_frames: list[dict] = []
    composite_paths: dict[str, Path] = {}
    for frame_index, source_path in enumerate(frame_paths):
        direction, logical_index = _frame_info(source_path)
        base = Image.open(source_path).convert("RGBA")
        result = rasterize_variant(
            base=base,
            direction=direction,
            factors=factors,
            seed=seed,
        )
        warnings = validate_coverage(result)
        layer_paths: dict[str, str] = {}
        for layer_name in LAYERS:
            layer_path = role_output / layer_name / source_path.name
            _save_png(result.layers[layer_name], layer_path)
            layer_paths[layer_name] = layer_path.relative_to(output_dir).as_posix()

        composite = _composite(base, (result.layers[name] for name in ("socket_cover", "eye", "brow", "ear")))
        composite_path = role_output / "composite" / source_path.name
        _save_png(composite, composite_path)
        composite_paths[source_path.name] = composite_path

        manifest_frames.append({
            "source": source_path.relative_to(source_dir).as_posix(),
            "file": source_path.name,
            "direction": direction,
            "logical_index": logical_index,
            "size": {"width": base.width, "height": base.height},
            "layers": layer_paths,
            "composite": composite_path.relative_to(output_dir).as_posix(),
            "coverage": result.coverage,
            "warnings": warnings,
        })

    _write_previews(role_output, composite_paths)
    return {
        "frame_count": len(manifest_frames),
        "frames": manifest_frames,
    }, composite_paths


def generate_faces(
    prompt: str,
    seed: int,
    source_dir: Path | str = DEFAULT_SOURCE_DIR,
    output_dir: Path | str = DEFAULT_OUTPUT_DIR,
    faces: Iterable[str] = ROLES,
) -> dict:
    """Generate selected face roles and return the JSON-safe manifest."""
    source_root = _inside_project(Path(source_dir), "source-dir")
    output_root = _inside_project(Path(output_dir), "output-dir")
    selected_faces = tuple(faces)
    unknown_faces = sorted(set(selected_faces) - set(ROLES))
    if not selected_faces:
        raise ValueError("至少选择一个脸型: male 或 female")
    if unknown_faces:
        raise ValueError(f"不支持的脸型: {', '.join(unknown_faces)}")
    if source_root == output_root or output_root.is_relative_to(source_root):
        raise ValueError("output-dir 不能覆盖或位于 source-dir 内")

    parsed = parse_prompt(prompt, seed)
    output_root.mkdir(parents=True, exist_ok=True)
    role_manifests: dict[str, dict] = {}
    for role in selected_faces:
        role_manifests[role], _ = _generate_role(
            role=role,
            source_dir=source_root,
            output_dir=output_root,
            factors=parsed.factors,
            seed=parsed.seed,
        )

    factors_data = {
        "generator_version": GENERATOR_VERSION,
        "prompt": parsed.prompt,
        "seed": parsed.seed,
        "factors": parsed.factors,
        "resolved_factors": resolve_seed_variant(parsed.factors, parsed.seed),
        "warnings": parsed.warnings,
        "parser_version": parsed.parser_version,
    }
    _write_json(output_root / "prompts" / "factors.json", factors_data)

    manifest = {
        "generator_version": GENERATOR_VERSION,
        "prompt": parsed.prompt,
        "seed": parsed.seed,
        "faces": list(selected_faces),
        "frame_count": {role: role_manifests[role]["frame_count"] for role in selected_faces},
        "warnings": parsed.warnings,
        "roles": role_manifests,
    }
    _write_json(output_root / "manifest.json", manifest)
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate local parameterized pixel face components")
    parser.add_argument("--prompt", default="细眉、小眼、精灵耳")
    parser.add_argument("--seed", type=int, default=20260726)
    parser.add_argument("--source-dir", default=str(DEFAULT_SOURCE_DIR))
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--faces", nargs="+", choices=ROLES, default=list(ROLES))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        manifest = generate_faces(
            prompt=args.prompt,
            seed=args.seed,
            source_dir=args.source_dir,
            output_dir=args.output_dir,
            faces=args.faces,
        )
    except (FileNotFoundError, ValueError) as error:
        print(f"生成失败: {error}", file=sys.stderr)
        return 2
    print(json.dumps({"output_dir": args.output_dir, "frame_count": manifest["frame_count"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
