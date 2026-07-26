"""
Build region templates for all RO face types based on pixel grid analysis.
Each face has unique hair/skin/eye/mouth layout.
"""

import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
OUT_DIR = os.path.join(ROOT, "assets", "train", "face_annotations")
os.makedirs(OUT_DIR, exist_ok=True)

def get_face_img(face_id):
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)
    ref_key = next(fn for fn in data["frames"] if fn.lower().startswith(face_id) and "stand_0_0" in fn)
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    img = atlas.crop((frame["x"], frame["y"], frame["x"]+frame["w"], frame["y"]+frame["h"]))
    return img, frame["w"], frame["h"]

def build_face10101_template():
    """face10101: 3/4 profile, right side hair outline, single eye on right."""
    img, w, h = get_face_img("face10101")
    px = img.load()

    hair, skin, eyes, mouth = [], [], [], []
    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16: continue
            r, g, b, a = c
            lum = 0.299*r + 0.587*g + 0.114*b

            # Single eye at right (col 27-28, row 21-24)
            if (xc, yc) in [(27,21),(28,21),(27,22),(28,22),(27,23),(28,23),(27,24)]:
                eyes.append([xc, yc])
            # Mouth center (row 22-25, col 13-20)
            elif 22 <= yc <= 25 and 13 <= xc <= 20:
                if yc == 22 and 16 <= xc <= 18: mouth.append([xc, yc])
                elif yc == 23: mouth.append([xc, yc])
                elif yc == 24: mouth.append([xc, yc])
                elif yc == 25 and 14 <= xc <= 20: mouth.append([xc, yc])
            # Hair: dark outline right side
            elif (lum < 110 and yc > 15) or (xc >= 25 and yc > 17):
                hair.append([xc, yc])
            else:
                skin.append([xc, yc])

    return {"name": "face10101", "w": w, "h": h,
            "pixels": {"hair": hair, "skin": skin, "eyes": eyes, "mouth": mouth},
            "count": {k: len(v) for k, v in zip(["hair","skin","eyes","mouth"],[hair,skin,eyes,mouth])}}

def build_face10301_template():
    """
    face10301 (32x33): Left-side hair (headband/accessory on left), 
    face on right, single visible eye near center-left.
    Based on pixel grid analysis.
    """
    img, w, h = get_face_img("face10301")
    px = img.load()

    # Build color index
    color_to_idx = {}
    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] > 16:
                key = (c[0], c[1], c[2])
                if key not in color_to_idx:
                    color_to_idx[key] = len(color_to_idx)
    idx_to_color = {v: k for k, v in color_to_idx.items()}

    hair_pixels, skin_pixels, eye_pixels, mouth_pixels = [], [], [], []

    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16: continue
            r, g, b, a = c
            key = (r, g, b)
            ci = color_to_idx[key]
            lum = 0.299*r + 0.587*g + 0.114*b

            # Hair colors from grid analysis (indices 14-18, 22-24 are dark brown/red)
            # Left side hair: x < 10, y > 15
            # Top hair/accessory: y < 10, x < 12
            
            if ci in [14, 15, 16, 17, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35, 36]:
                # Higher indices tend to be hair on left side
                if xc < 18 and yc > 15:
                    hair_pixels.append([xc, yc])
                    continue
                elif xc < 14 and yc > 10:
                    hair_pixels.append([xc, yc])
                    continue
                elif yc > 25 and xc < 10:
                    hair_pixels.append([xc, yc])
                    continue

            # Detect dark vs light by luminance - hair is dark
            if lum < 100 and (xc < 16 and yc > 15):
                hair_pixels.append([xc, yc])
                continue

            # Light colors near top = skin or headband
            # everything else = skin
            skin_pixels.append([xc, yc])

    # Post-process: find eye by looking for dark pixels in mid face area
    # The eye(s) should be at rows 20-24, center of face
    eye_candidates = []
    for yc in range(19, 25):
        for xc in range(8, 24):
            if [xc, yc] in skin_pixels:
                c = px[xc, yc]
                r, g, b, a = c
                lum = 0.299*r + 0.587*g + 0.114*b
                if lum < 80:
                    eye_candidates.append([xc, yc])

    # Remove eye candidates from skin
    for ec in eye_candidates:
        if ec in skin_pixels:
            skin_pixels.remove(ec)
        eye_pixels.append(ec)

    # Mouth area: around rows 24-27, center columns
    mouth_candidates = []
    for yc in range(24, 28):
        for xc in range(10, 22):
            if [xc, yc] in skin_pixels:
                c = px[xc, yc]
                r, g, b, a = c
                lum = 0.299*r + 0.587*g + 0.114*b
                if 80 <= lum <= 140:
                    mouth_candidates.append([xc, yc])

    for mc in mouth_candidates:
        if mc in skin_pixels:
            skin_pixels.remove(mc)
        mouth_pixels.append(mc)

    return {
        "name": "face10301", "w": w, "h": h,
        "pixels": {"hair": hair_pixels, "skin": skin_pixels, "eyes": eye_pixels, "mouth": mouth_pixels},
        "count": {k: len(v) for k, v in zip(["hair","skin","eyes","mouth"],
                  [hair_pixels, skin_pixels, eye_pixels, mouth_pixels])}
    }


def show_region_map(name, tmpl):
    """Display region map and save template."""
    img, w, h = get_face_img(tmpl["name"])
    px = img.load()
    hair_set = set(tuple(p) for p in tmpl["pixels"]["hair"])
    skin_set = set(tuple(p) for p in tmpl["pixels"]["skin"])
    eye_set = set(tuple(p) for p in tmpl["pixels"]["eyes"])
    mouth_set = set(tuple(p) for p in tmpl["pixels"]["mouth"])

    print(f"\n{name} ({w}x{h}):")
    print(f"  hair={len(hair_set)}, skin={len(skin_set)}, eyes={len(eye_set)}, mouth={len(mouth_set)}")
    print(f"  Region map:")
    for yc in range(h):
        row = f"    y={yc:2d}: "
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

    # Save
    path = os.path.join(OUT_DIR, f"{name}_template.json")
    with open(path, "w") as f:
        json.dump(tmpl, f, indent=2)
    print(f"  Saved: {path}")
    return path


if __name__ == "__main__":
    # Build templates
    t1 = build_face10101_template()
    show_region_map("face10101", t1)

    t2 = build_face10301_template()
    show_region_map("face10301", t2)
