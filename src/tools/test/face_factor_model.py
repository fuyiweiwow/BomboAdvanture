"""Deterministic prompt-to-factor normalization for pixel face components."""

from __future__ import annotations

import copy
import re
from dataclasses import dataclass


PARSER_VERSION = "face_factor_parser_v1"

DEFAULT_FACTORS = {
    "brow": {"style": "normal", "thickness": 2, "curve": 0},
    "eye": {
        "size": "normal",
        "scale_x": 1.0,
        "scale_y": 1.0,
        "iris": "blue",
        "pupil_offset": [0, 0],
    },
    "ear": {
        "type": "human",
        "length": 0,
        "tip_raise": 0,
        "outer_spread": 0,
    },
}


@dataclass(frozen=True)
class ParsedPrompt:
    prompt: str
    seed: int
    factors: dict[str, dict]
    warnings: list[str]
    parser_version: str = PARSER_VERSION


def _thin_brow(factors: dict[str, dict]) -> None:
    factors["brow"].update(style="thin", thickness=1, curve=0)


def _small_eye(factors: dict[str, dict]) -> None:
    factors["eye"].update(size="small", scale_x=0.75, scale_y=0.8)


def _elf_ear(factors: dict[str, dict]) -> None:
    factors["ear"].update(type="elf", length=4, tip_raise=3, outer_spread=2)


def _beast_ear(factors: dict[str, dict]) -> None:
    factors["ear"].update(type="beast", length=3, tip_raise=2, outer_spread=2)


def _deferred_crossed_eye(factors: dict[str, dict]) -> None:
    factors["eye"]["pupil_offset"] = [0, 0]


ALIASES = {
    "细眉": _thin_brow,
    "细的眉毛": _thin_brow,
    "小眼": _small_eye,
    "小眼睛": _small_eye,
    "精灵耳": _elf_ear,
    "尖耳": _elf_ear,
    "兽耳": _beast_ear,
}

DEFERRED_ALIASES = {"斗鸡眼": _deferred_crossed_eye}
TOKEN_SPLIT = re.compile(r"[\s,，、。；;|/]+")


def parse_prompt(prompt: str, seed: int) -> ParsedPrompt:
    normalized_seed = int(seed)
    if normalized_seed < 0:
        raise ValueError("seed 必须是非负整数")

    factors = copy.deepcopy(DEFAULT_FACTORS)
    warnings: list[str] = []
    tokens = [token for token in TOKEN_SPLIT.split(prompt.strip()) if token]
    for token in tokens:
        handler = ALIASES.get(token)
        if handler is not None:
            handler(factors)
            continue
        deferred_handler = DEFERRED_ALIASES.get(token)
        if deferred_handler is not None:
            deferred_handler(factors)
            warnings.append("因子暂未启用: eye.pupil_offset")
            continue
        warnings.append(f"未识别提示词: {token}")

    return ParsedPrompt(
        prompt=prompt,
        seed=normalized_seed,
        factors=factors,
        warnings=warnings,
    )


def resolve_seed_variant(factors: dict[str, dict], seed: int) -> dict[str, dict]:
    """Resolve small deterministic shape variations without changing factor categories."""
    resolved = copy.deepcopy(factors)
    offset = (int(seed) % 3) - 1

    brow = resolved["brow"]
    brow["curve"] = max(-2, min(2, int(brow.get("curve", 0)) + offset))

    eye = resolved["eye"]
    eye["scale_x"] = round(max(0.5, min(1.2, float(eye.get("scale_x", 1.0)) + offset * 0.05)), 2)
    eye["scale_y"] = round(max(0.5, min(1.2, float(eye.get("scale_y", 1.0)) - offset * 0.05)), 2)

    ear = resolved["ear"]
    ear["outer_spread"] = max(0, min(6, int(ear.get("outer_spread", 0)) + (int(seed) % 2)))
    return resolved
