# HD Face Component Experiment v1

This directory is an isolated 2x pixel experiment. It does not replace the
legacy Godot face resources.

## Catalogs

There are 12 catalogs: four factor presets for each of three races.

- `natural`: normal eyes and natural brows
- `gentle`: rounder eyes and softer brows
- `focused`: narrower eyes and angled brows
- `bold`: larger eyes and stronger brows

Race rules are independent from the eye and brow preset:

- `human`: short side ears and the project's general Q-style direction
- `elf`: longer pointed side ears, with the same normal eyes and brows as human
- `orc`: top-mounted ears only; no ordinary side ears

Within each race, the four presets also select a restrained ear profile:
`rounded`, `soft`, `sharp`, or `broad`. This keeps ears independently
composable while preserving the race-specific placement.

Small dot eyes remain an optional random factor for NPC, monster, or player
creation. They are not the default elf style and are not enabled by a preset.

## Component order

For each frame, compose the layers in this order:

1. `base`
2. `socket_cover`
3. `eye`
4. `brow`
5. `ear`

The `composite` directory contains the result of that order. Each catalog has
28 frames: four standing directions and six walking frames for each direction.
The `preview` directory contains enlarged nearest-neighbor previews.

## Metadata

- Logical size: 36x34
- Texture size: 72x68
- Pixel scale: 2
- Manifest: `manifest.json`
- Factor definitions: `presets.json`

The `manifest.json` file records resolved factors, per-frame coverage, and a
total `warning_count`. A clean generation has `warning_count: 0`.

## Regeneration

Run this from the project root with the E-drive environment:

```powershell
E:\env\venv\Scripts\python.exe src\tools\test\hd_face_pipeline.py `
  --output-dir assets\test\face_hd_v1 `
  --seed 20260726
```

This remains a test catalog until the layer anchors, palette, and runtime
integration are reviewed against the full character body and animation set.
