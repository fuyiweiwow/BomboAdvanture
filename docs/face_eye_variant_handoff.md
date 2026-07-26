# Face Eye Variant Handoff

This document is the restart point for face-component experiments on another machine.

## Environment

- Project: `E:\WorkProject\Bomb adventure\BomboAdvanture`
- Python: `E:\env\venv\Scripts\python.exe`
- Processing is CPU-only Pillow code. GPU, CUDA, Torch, and an image API are not required.
- Keep caches and generated output on `E:`.

## Source and annotations

- Original face frames: `assets/img/face`
- Manual annotations: `assets/test/male_face_v2/annotations.json`
- Extracted male/female bases and per-frame components: `assets/test/face_bases_v1`
- Extraction script: `src/tools/test/extract_face_bases.py`
- Extraction manifest: `assets/test/face_bases_v1/manifest.json`

The base extraction is deliberately source-pixel based. Unmarked pixels stay in the base,
so annotation quality is still important before adding new components.

## Current eye outputs

- Previous exaggerated experiment, retained for comparison: `assets/test/face_eye_exaggerated_v1`
- Fixed exaggerated experiment: `assets/test/face_eye_exaggerated_v2_fixed`
- Previous two-style catalog: `assets/test/face_eye_variants_full_v1`
- Fixed two-style catalog: `assets/test/face_eye_variants_full_v2_fixed`

Each fixed catalog has 28 frames for male and female roles. The fixed pipeline uses these
rules:

1. D-facing frames reuse the canonical front eye style and translate each eye using its
   annotated iris center.
2. Side-facing frames keep their annotated geometry but are recolored from the canonical
   front palette, so they do not retain the original blue side-eye colors.
3. D-facing brows use the canonical front brow and the same iris-center translation as the
   eye.
4. The exaggerated variant clips the enlarged eye's lower artifact row.
5. Highlights remain on the local left side of each iris and are never horizontally mirrored.

## Regenerate

Run the focused tests:

```powershell
& 'E:\env\venv\Scripts\python.exe' -m unittest src.tools.test.test_eye_variant_pipeline src.tools.test.test_random_face_pipeline -v
```

Generate the fixed normal catalog:

```powershell
& 'E:\env\venv\Scripts\python.exe' 'E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\eye_variant_pipeline.py' --full --output-dir 'E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\face_eye_variants_full_v2_fixed'
```

Generate the fixed exaggerated catalog:

```powershell
& 'E:\env\venv\Scripts\python.exe' 'E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\eye_variant_pipeline.py' --exaggerated --output-dir 'E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\face_eye_exaggerated_v2_fixed'
```

Main generator and tests:

- `src/tools/test/eye_variant_pipeline.py`
- `src/tools/test/test_eye_variant_pipeline.py`
- `src/tools/test/random_face_pipeline.py`
- `src/tools/test/reference_face_pipeline.py`

## Next ear experiment

Do not put random ear geometry directly into the face base. Keep ears as a separate layer
with the same frame names and anchors as `assets/test/face_bases_v1/*/ear`.

Recommended next steps:

1. Use the annotated human ear masks as the `reference` seed.
2. Define ear factors such as `size`, `angle`, `point`, `inner_color`, and `visibility`.
3. Generate human ears first, then test elf ears as a separate accessory layer.
4. Keep orc ears out of the base-face experiment until their top-of-head anchors are
   annotated separately.
5. Add deterministic seed tests before generating catalog images.

The existing factor pipeline is the starting point for this work:
`src/tools/test/face_factor_model.py`, `src/tools/test/face_factor_raster.py`, and
`src/tools/test/test_face_factor_components.py`.
