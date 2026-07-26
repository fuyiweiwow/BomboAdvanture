"""
Build face10301 template from manual pixel grid analysis.
This is a different character from face10101 with different structure.
Hair on right side, eye on left side (mirrored-ish from 10101).
"""

import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

def main():
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    ref_key = next(fn for fn in data["frames"] if "face10301" in fn.lower() and "stand_0_0" in fn)
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    img = atlas.crop((x, y, x + w, y + h))
    px = img.load()

    print(f"face10301: {w}x{h}")

    hair_pixels = []
    skin_pixels = []
    eye_pixels = []
    mouth_pixels = []

    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16:
                continue
            r, g, b, a = c
            lum = 0.299*r + 0.587*g + 0.114*b

            # === EYE: left-of-center, around x=11-15, y=20-23 ===
            # Based on unique non-skin color indices at these positions
            if (xc, yc) in [(11,20),(12,20),(13,20),
                            (11,21),(15,21),
                            (11,22),(12,22),(13,22),
                            (14,23)]:
                eye_pixels.append([xc, yc])
                continue

            # === MOUTH: center, around x=10-22, y=24-27 ===
            if 24 <= yc <= 27 and 10 <= xc <= 22:
                # Filter by luminance - mouth area has mid-range values
                if 70 <= lum <= 150:
                    mouth_pixels.append([xc, yc])
                    continue

            # === HAIR: right side dark outline (x=21-31, y>16) ===
            # Dark colors (indices 14-18, 22-24) on right side
            if lum < 110 and yc > 15 and xc > 18:
                hair_pixels.append([xc, yc])
                continue
            if xc > 23 and yc > 16:
                hair_pixels.append([xc, yc])
                continue
            if xc > 20 and yc > 18 and lum < 150:
                hair_pixels.append([xc, yc])
                continue

            # === SKIN: everything else ===
            skin_pixels.append([xc, yc])

    total = sum(len(p) for p in [hair_pixels, skin_pixels, eye_pixels, mouth_pixels])
    print(f"\nRegions:")
    print(f"  hair:  {len(hair_pixels):4d}")
    print(f"  skin:  {len(skin_pixels):4d}")
    print(f"  eyes:  {len(eye_pixels):4d}")
    print(f"  mouth: {len(mouth_pixels):4d}")
    print(f"  total: {total:4d}")

    # Show map
    hair_s = set(tuple(p) for p in hair_pixels)
    skin_s = set(tuple(p) for p in skin_pixels)
    eye_s = set(tuple(p) for p in eye_pixels)
    mouth_s = set(tuple(p) for p in mouth_pixels)

    print(f"\nRegion map (H=hair, S=skin, E=eye, M=mouth, .=transparent):")
    for yc in range(h):
        row = f"  y={yc:2d}: "
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16:
                row += "."
            elif (xc, yc) in eye_s:
                row += "E"
            elif (xc, yc) in mouth_s:
                row += "M"
            elif (xc, yc) in hair_s:
                row += "H"
            elif (xc, yc) in skin_s:
                row += "S"
            else:
                row += "?"
        print(row)

    # Save template
    tmpl = {
        "name": "face10301_stand_0_0",
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

    out_dir = os.path.join(ROOT, "assets", "train", "face_annotations")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "face10301_region_template.json")
    with open(out_path, "w") as f:
        json.dump(tmpl, f, indent=2)
    print(f"\nSaved: {out_path}")

if __name__ == "__main__":
    main()
