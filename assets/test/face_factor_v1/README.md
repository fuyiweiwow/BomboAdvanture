# Local parameterized face factor experiment

This directory is generated locally from `assets/test/face_bases_v1/`. It does not use an Image API or a cloud model.

## Command

```powershell
E:\env\venv\Scripts\python.exe "E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\generate_factor_faces.py" --prompt "<prompt tokens>" --seed <integer>
```

## Layers

- `base`: read-only source in `face_bases_v1`; never overwrite it.
- `socket_cover`: fills only transparent feature sockets with the source skin palette.
- `eye`, `brow`, `ear`: independent transparent component layers.
- `composite`: preview result in the order `base -> socket_cover -> eye -> brow -> ear`.
- `preview`: nearest-neighbor enlarged previews for standing directions and all frames.

The female base keeps blush. `prompts/factors.json` records the prompt, seed, normalized factors, resolved seed variant, parser version, and warnings. `manifest.json` records frame sizes, output paths, coverage counts, and per-frame warnings.
