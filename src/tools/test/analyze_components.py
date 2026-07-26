"""Analyze the component structure of RO faces.
Shows what eye/mouth components look like and their sizes.
"""
import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

for comp in ["eye", "mouth"]:
    comp_dir = os.path.join(ROOT, "assets", "img", comp)
    atlas_path = os.path.join(comp_dir, f"{comp}.atlas.png")
    json_path = os.path.join(comp_dir, f"{comp}.atlas.json")

    if not (os.path.exists(atlas_path) and os.path.exists(json_path)):
        print(f"{comp}: not found")
        continue

    with open(json_path) as f:
        data = json.load(f)
    atlas = Image.open(atlas_path).convert("RGBA")

    print(f"\n{comp} ({len(data['frames'])} frames):")
    for fn in sorted(data["frames"].keys())[:4]:
        info = data["frames"][fn]
        frame = info.get("frame", info)
        img = atlas.crop((frame["x"], frame["y"], frame["x"]+frame["w"], frame["y"]+frame["h"]))
        px = img.load()
        w, h = img.size
        print(f"\n  {fn} ({w}x{h}):")
        for y in range(h):
            line = ""
            for x in range(w):
                c = px[x, y]
                if c[3] < 16:
                    line += " "
                else:
                    line += "@"
            print(f"    {y}: |{line}|")
