# Parameterized Face Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic local pixel generator that turns prompts such as `细眉、小眼、精灵耳` into reusable brow, eye, ear, socket-cover, and composite layers for the extracted male and female face bases.

**Architecture:** Keep prompt parsing, factor normalization, pixel rasterization, and file generation in separate Python modules. The parser produces a JSON-safe factor object; rasterizers consume that object plus direction/frame anchors; the CLI writes component PNGs, metadata, previews, and a manifest without changing `face_bases_v1`.

**Tech Stack:** Python 3.11, Pillow from `E:\env\venv`, standard-library `unittest`, JSON, nearest-neighbor pixel drawing. No Image API or cloud model.

---

## File Map

- Create: `src/tools/test/face_factor_model.py`
  - Dataclasses for normalized factors, prompt aliases, range validation, and deterministic seed handling.
- Create: `src/tools/test/face_factor_raster.py`
  - Direction anchors, socket-cover rasterization, brow/eye/ear pixel drawing, layer composition, and coverage checks.
- Create: `src/tools/test/generate_factor_faces.py`
  - CLI orchestration for both bases, JSON/PNG output, previews, and manifest generation.
- Create: `src/tools/test/test_face_factor_components.py`
  - Standard-library tests for parser behavior, raster geometry, coverage, and reproducibility.
- Create: `assets/test/face_factor_v1/`
  - Generated experimental outputs only; never overwrite `assets/test/face_bases_v1/`.
- Modify: `docs/face_base_extraction.md`
  - Add the parameterized component command and explain `socket_cover`.

## Task 1: Write Parser Tests First

**Files:**
- Create: `src/tools/test/test_face_factor_components.py`

- [ ] **Step 1: Add a failing parser test for the approved prompt.**

```python
import unittest
from src.tools.test.face_factor_model import parse_prompt


class FaceFactorParserTests(unittest.TestCase):
    def test_parse_approved_prompt_to_normalized_factors(self):
        result = parse_prompt("细眉、小眼、精灵耳", seed=20260726)

        self.assertEqual(result.factors["brow"], {
            "style": "thin",
            "thickness": 1,
            "curve": 0,
        })
        self.assertEqual(result.factors["eye"]["size"], "small")
        self.assertEqual(result.factors["eye"]["scale_x"], 0.75)
        self.assertEqual(result.factors["ear"], {
            "type": "elf",
            "length": 4,
            "tip_raise": 3,
            "outer_spread": 2,
        })
        self.assertEqual(result.seed, 20260726)
        self.assertEqual(result.warnings, [])
```

- [ ] **Step 2: Add tests for aliases, unknown words, and the deferred crossed-eye factor.**

```python
    def test_aliases_are_equivalent(self):
        self.assertEqual(
            parse_prompt("细的眉毛,小眼睛,尖耳", seed=1).factors,
            parse_prompt("细眉、小眼、精灵耳", seed=1).factors,
        )

    def test_unknown_prompt_words_are_reported_without_changing_defaults(self):
        result = parse_prompt("细眉、未知装饰", seed=1)

        self.assertEqual(result.factors["brow"]["style"], "thin")
        self.assertEqual(result.warnings, ["未识别提示词: 未知装饰"])

    def test_crossed_eye_is_parsed_but_not_enabled_by_default(self):
        result = parse_prompt("斗鸡眼", seed=1)

        self.assertEqual(result.factors["eye"]["pupil_offset"], [0, 0])
        self.assertEqual(result.warnings, ["因子暂未启用: eye.pupil_offset"])
```

- [ ] **Step 3: Run the parser tests and confirm they fail because the model module does not exist.**

Run from `E:\WorkProject\Bomb adventure\BomboAdvanture`:

```powershell
E:\env\venv\Scripts\python.exe -m unittest src.tools.test.test_face_factor_components -v
```

Expected result: import failure for `face_factor_model`, not a passing test.

## Task 2: Implement the Factor Model and Parser

**Files:**
- Create: `src/tools/test/face_factor_model.py`

- [ ] **Step 1: Implement JSON-safe normalized factor data.**

The module must expose:

```python
@dataclass(frozen=True)
class ParsedPrompt:
    prompt: str
    seed: int
    factors: dict[str, dict]
    warnings: list[str]


def parse_prompt(prompt: str, seed: int) -> ParsedPrompt:
    raise NotImplementedError
```

Use these defaults before applying aliases:

```python
DEFAULT_FACTORS = {
    "brow": {"style": "normal", "thickness": 2, "curve": 0},
    "eye": {
        "size": "normal",
        "scale_x": 1.0,
        "scale_y": 1.0,
        "iris": "blue",
        "pupil_offset": [0, 0],
    },
    "ear": {"type": "human", "length": 0, "tip_raise": 0, "outer_spread": 0},
}
```

Map `细眉`, `细的眉毛`, `小眼`, `小眼睛`, `精灵耳`, and `尖耳` to the exact factors in the approved spec. Map `兽耳` to `ear.type=beast` with `length=3`, `tip_raise=2`, `outer_spread=2`. Record the crossed-eye warning without applying a nonzero offset. Split prompt text only on Chinese and ASCII punctuation; preserve the original prompt unchanged in `ParsedPrompt.prompt`.

- [ ] **Step 2: Run the parser tests and confirm they pass.**

```powershell
E:\env\venv\Scripts\python.exe -m unittest src.tools.test.test_face_factor_components -v
```

Expected result: all parser tests pass; raster tests may still be absent.

- [ ] **Step 3: Commit the parser unit.**

```powershell
git add src/tools/test/face_factor_model.py src/tools/test/test_face_factor_components.py
git commit -m "feat: add face factor prompt parser"
```

## Task 3: Write Rasterizer Tests Before Drawing Code

**Files:**
- Modify: `src/tools/test/test_face_factor_components.py`

- [ ] **Step 1: Add a deterministic synthetic face frame and raster behavior tests.**

The tests must call real rasterizer functions, not mocks:

```python
from PIL import Image
from src.tools.test.face_factor_model import parse_prompt
from src.tools.test.face_factor_raster import rasterize_variant, validate_coverage


    def test_small_eye_thin_brow_elf_ear_covers_the_feature_socket(self):
        base = Image.new("RGBA", (36, 34), (0, 0, 0, 0))
        factors = parse_prompt("细眉、小眼、精灵耳", seed=1).factors
        result = rasterize_variant(base, direction="D", factors=factors, seed=1)

        self.assertIsNotNone(result.layers["brow"].getbbox())
        self.assertIsNotNone(result.layers["eye"].getbbox())
        self.assertIsNotNone(result.layers["ear"].getbbox())
        self.assertEqual(validate_coverage(result), [])

    def test_same_seed_produces_identical_layer_bytes(self):
        base = Image.new("RGBA", (36, 34), (0, 0, 0, 0))
        factors = parse_prompt("细眉、小眼、精灵耳", seed=99).factors
        left = rasterize_variant(base, direction="D", factors=factors, seed=99)
        right = rasterize_variant(base, direction="D", factors=factors, seed=99)

        for name in ("socket_cover", "brow", "eye", "ear"):
            self.assertEqual(
                list(left.layers[name].getdata()),
                list(right.layers[name].getdata()),
            )
```

- [ ] **Step 2: Run the new raster tests and confirm they fail because the raster module does not exist.**

```powershell
E:\env\venv\Scripts\python.exe -m unittest src.tools.test.test_face_factor_components -v
```

Expected result: import failure for `face_factor_raster`.

## Task 4: Implement Anchors, Socket Cover, and Component Rasterizers

**Files:**
- Create: `src/tools/test/face_factor_raster.py`

- [ ] **Step 1: Define the rasterizer result contract.**

Expose:

```python
@dataclass
class RasterResult:
    layers: dict[str, Image.Image]
    warnings: list[str]
    coverage: dict[str, int]


def rasterize_variant(
    base: Image.Image,
    direction: str,
    factors: dict[str, dict],
    seed: int,
) -> RasterResult:
    raise NotImplementedError


def validate_coverage(result: RasterResult) -> list[str]:
    raise NotImplementedError
```

Layers must include `socket_cover`, `brow`, `eye`, and `ear`. All images use the input dimensions, RGBA mode, and nearest-neighbor integer pixels.

- [ ] **Step 2: Add fixed direction anchors.**

Use the existing face coordinate contract: `D` is front, `R` and `L` are side views, and `U` is back. Store per-direction anchor rectangles in one constant dictionary. Every anchor must be inside the input frame; otherwise return a warning and an empty variant instead of drawing outside the image.

- [ ] **Step 3: Draw the `socket_cover` layer.**

Create a compact cover only inside the known face feature socket. Sample the nearest opaque base pixels above, below, or beside the socket; choose the most frequent sampled skin color and fill only integer pixels in the socket rectangle. Keep the cover as its own layer so it can be audited or replaced. Never use flood fill beyond the socket rectangle.

- [ ] **Step 4: Draw the approved factor components.**

Implement these deterministic primitives:

```python
draw_thin_brow(layer, anchor, curve, color)
draw_small_eye(layer, anchor, scale_x, scale_y, iris_color, pupil_offset)
draw_elf_ear(layer, anchor, length, tip_raise, outer_spread, palette)
```

Use integer rounding only. `draw_small_eye` must draw eye white, iris, pupil, and highlight in the same scaled bounding box. `draw_elf_ear` must connect to the inner ear anchor and draw the pointed outer polygon. Do not create semi-transparent anti-aliasing.

- [ ] **Step 5: Validate coverage and component separation.**

`validate_coverage` must report a named warning if the socket remains uncovered, if an eye pixel intersects the brow forbidden band, or if an ear pixel intersects the eye forbidden band. The first implementation must return `[]` for the approved synthetic test.

- [ ] **Step 6: Run all unit tests and commit the rasterizer.**

```powershell
E:\env\venv\Scripts\python.exe -m unittest src.tools.test.test_face_factor_components -v
```

Expected result: all parser and raster tests pass.

```powershell
git add src/tools/test/face_factor_raster.py src/tools/test/test_face_factor_components.py
git commit -m "feat: rasterize parameterized face components"
```

## Task 5: Build the Generation CLI

**Files:**
- Create: `src/tools/test/generate_factor_faces.py`

- [ ] **Step 1: Add CLI arguments with E-drive defaults.**

The CLI must support:

```text
--prompt "细眉、小眼、精灵耳"
--seed 20260726
--source-dir E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\face_bases_v1
--output-dir E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\face_factor_v1
--faces male female
```

Do not use a relative default that could resolve to C:. Reject an output directory outside the E-drive project root with a clear error.

- [ ] **Step 2: Generate one variant per selected base.**

For each role, load the 28 `base` frames from `face_bases_v1`, infer the logical direction from the filename, call `rasterize_variant`, and save:

```text
male/socket_cover/*.png
male/brow/*.png
male/eye/*.png
male/ear/*.png
male/composite/*.png
female/socket_cover/*.png
female/brow/*.png
female/eye/*.png
female/ear/*.png
female/composite/*.png
```

Composite order is `base -> socket_cover -> eye -> brow -> ear`; preserve the female base blush by using the extracted female `base` unchanged.

- [ ] **Step 3: Write metadata and previews.**

Write `prompts/factors.json` with the prompt, seed, normalized factors, warnings, and parser version. Write `manifest.json` with each frame's size, layer pixel counts, coverage warnings, and output path. Create nearest-neighbor previews for four standing directions and all generated frames.

- [ ] **Step 4: Run the CLI into an E-drive experiment directory.**

```powershell
E:\env\venv\Scripts\python.exe "E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\generate_factor_faces.py" --prompt "细眉、小眼、精灵耳" --seed 20260726
```

Expected result: exit code 0, two role directories, 28 composite PNGs per role, and a manifest with no coverage warnings.

## Task 6: Add Integration and Regression Tests

**Files:**
- Modify: `src/tools/test/test_face_factor_components.py`

- [ ] **Step 1: Test output frame dimensions and source immutability.**

Load one `D`, `L`, `R`, and `U` frame from each role. Assert each composite has the same width and height as the corresponding base. Hash the source base files before and after generation and assert the hashes are identical.

- [ ] **Step 2: Test manifest reproducibility.**

Run the CLI twice with the same prompt and seed into two E-drive test directories and compare every layer PNG byte-for-byte plus the normalized `factors.json`. Run once with a different seed and assert the metadata seed differs while the factor categories remain the same.

- [ ] **Step 3: Test female blush preservation.**

Compare the female generated composite against the female input base outside the component socket. Assert the known pink blush pixels remain present in the generated composite and no male output contains those female blush pixels.

- [ ] **Step 4: Run the complete test suite.**

```powershell
E:\env\venv\Scripts\python.exe -m unittest src.tools.test.test_face_factor_components -v
```

Expected result: all tests pass with no traceback. Any generated test directories must remain under `E:\WorkProject\Bomb adventure\BomboAdvanture\.test-output\` or be explicitly removed after verification; never use the C: temporary directory.

## Task 7: Document and Review the Experimental Output

**Files:**
- Modify: `docs/face_base_extraction.md`
- Create: `assets/test/face_factor_v1/README.md`

- [ ] **Step 1: Document the command, prompt aliases, factor JSON, layer order, and `socket_cover` behavior.**

- [ ] **Step 2: Record the actual generated counts and coverage results from `manifest.json`; do not write guessed values.**

- [ ] **Step 3: Inspect the male and female standing previews with nearest-neighbor scaling.**

Check front, left, right, and back views for black holes, shifted eyes, broken ear connections, and accidental loss of female blush.

- [ ] **Step 4: Commit the experiment implementation and documentation.**

```powershell
git add src/tools/test/face_factor_model.py src/tools/test/face_factor_raster.py src/tools/test/generate_factor_faces.py src/tools/test/test_face_factor_components.py docs/face_base_extraction.md assets/test/face_factor_v1
git commit -m "feat: generate parameterized face factor experiment"
```

## Plan Self-Review

- Spec coverage: parser aliases and warnings are covered by Tasks 1-2; factor rasterization and socket cover by Tasks 3-4; both roles, 28 frames, manifests, and previews by Task 5; reproducibility, dimensions, blush, and immutability by Task 6; documentation and visual review by Task 7.
- Placeholder scan: this plan contains no unfilled placeholder instruction or unspecified implementation step.
- Type consistency: `ParsedPrompt` is consumed through `.factors`, `.seed`, and `.warnings`; `RasterResult` is consumed through `.layers`, `.warnings`, and `.coverage`; the CLI uses the exact parser and rasterizer names defined above.
