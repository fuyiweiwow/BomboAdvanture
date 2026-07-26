"""
Build corrected region template for face10101 after pixel-accurate analysis.
Eye is a single eye at col 27-28 (right side of face in 3/4 view).
Hair is dark outline on right side only.
"""

import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

def build():
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    ref_key = next(fn for fn in data["frames"] if "face10101" in fn.lower() and "stand_0_0" in fn)
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    img = atlas.crop((x, y, x + w, y + h))
    px = img.load()

    hair_pixels = []
    skin_pixels = []
    eye_pixels = []
    mouth_pixels = []

    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16:
                continue

            # Eye: single eye at right side (col 26-28, row 21-24) with distinctive black/blue/white
            if (xc, yc) in [(27,21),(28,21),
                            (27,22),(28,22),
                            (27,23),(28,23),
                            (27,24)]:
                eye_pixels.append([xc, yc])
                continue

            # Mouth: center rows 22-25, cols 13-20
            if (22 <= yc <= 25) and (13 <= xc <= 20) and yc < h and xc >= 0:
                if yc == 22:
                    if 16 <= xc <= 18:
                        mouth_pixels.append([xc, yc])
                        continue
                elif yc == 23:
                    if 13 <= xc <= 20:
                        mouth_pixels.append([xc, yc])
                        continue
                elif yc == 24:
                    if 13 <= xc <= 20:
                        mouth_pixels.append([xc, yc])
                        continue
                elif yc == 25:
                    if 14 <= xc <= 20:
                        mouth_pixels.append([xc, yc])
                        continue

            # Hair: dark outline right side
            r, g, b, a = c
            lum = 0.299*r + 0.587*g + 0.114*b
            if lum < 110 and yc > 15:
                hair_pixels.append([xc, yc])
                continue
            if xc >= 25 and yc > 17:
                hair_pixels.append([xc, yc])
                continue

            skin_pixels.append([xc, yc])

    total = len(hair_pixels) + len(skin_pixels) + len(eye_pixels) + len(mouth_pixels)

    print(f"Region breakdown:")
    print(f"  hair:  {len(hair_pixels):4d}")
    print(f"  skin:  {len(skin_pixels):4d}")
    print(f"  eyes:  {len(eye_pixels):4d}")
    print(f"  mouth: {len(mouth_pixels):4d}")
    print(f"  total: {total:4d}")

    # Show ASCII region map
    print(f"\nRegion map (H=hair, S=skin, E=eye, M=mouth, .=transparent):")
    hair_set = set(tuple(p) for p in hair_pixels)
    skin_set = set(tuple(p) for p in skin_pixels)
    eye_set = set(tuple(p) for p in eye_pixels)
    mouth_set = set(tuple(p) for p in mouth_pixels)
    for yc in range(h):
        row = f"y={yc:2d}: "
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16:
                row += "."
            elif (xc, yc) in eye_set:
                row += "E"
            elif (xc, yc) in mouth_set:
                row += "M"
            elif (xc, yc) in hair_set:
                row += "H"
            elif (xc, yc) in skin_set:
                row += "S"
            else:
                row += "?"
        print(row)

    tmpl = {
        "name": "face10101_stand_0_0",
        "width": w,
        "height": h,
        "pixels": {
            "hair": hair_pixels,
            "skin": skin_pixels,
            "eyes": eye_pixels,
            "mouth": mouth_pixels,
        },
        "count": {
            "hair": len(hair_pixels),
            "skin": len(skin_pixels),
            "eyes": len(eye_pixels),
            "mouth": len(mouth_pixels),
            "total": total
        }
    }

    out_path = os.path.join(ROOT, "assets", "train", "face_annotations", "face10101_region_template.json")
    with open(out_path, "w") as f:
        json.dump(tmpl, f, indent=2)
    print(f"\nSaved: {out_path}")

if __name__ == "__main__":
    build()
