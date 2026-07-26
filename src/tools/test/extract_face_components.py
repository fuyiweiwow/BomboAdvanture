"""Extract clean face components from RO face atlas.
Separates: face (head+hair, no eyes/mouth), eye region, mouth region.
"""

import os, json, copy
from PIL import Image
from collections import defaultdict

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
FACE_ATLAS = os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")
FACE_JSON = os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")
OUT_DIR = os.path.join(ROOT, "assets", "train", "face_components")

os.makedirs(OUT_DIR, exist_ok=True)

def extract_components():
    atlas = Image.open(FACE_ATLAS).convert("RGBA")
    with open(FACE_JSON) as f:
        data = json.load(f)

    # Group by face ID
    face_frames = defaultdict(dict)
    for fn, info in data["frames"].items():
        parts = fn.replace(".png", "").split("_")
        fid = parts[0].lower()
        key = "_".join(parts[1:])
        face_frames[fid][key] = info

    for fid, frames in sorted(face_frames.items()):
        print(f"\n=== {fid} ({len(frames)} frames) ===")
        # Use stand_0_0 as reference for region detection
        ref = frames.get("stand_0_0")
        if not ref:
            # Try other stand frames
            for k, v in frames.items():
                if "stand" in k:
                    ref = v
                    break
        if not ref:
            print(f"  No reference frame for {fid}")
            continue

        frame = ref.get("frame", ref)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        ref_img = atlas.crop((x, y, x + w, y + h))
        px = ref_img.load()

        # Analyze and build region masks
        # First, detect background (transparent)
        # Then classify remaining pixels into: hair, skin, eye, mouth

        hair_mask = Image.new("L", (w, h), 0)
        skin_mask = Image.new("L", (w, h), 0)
        eye_mask = Image.new("L", (w, h), 0)
        mouth_mask = Image.new("L", (w, h), 0)

        hpx = hair_mask.load()
        spx = skin_mask.load()
        epx = eye_mask.load()
        mpx = mouth_mask.load()

        # Step 1: Classify pixels
        # Hair is in upper portion and sides
        # Skin is in lower/center portion
        # Eyes/mouth are small dark clusters in specific region

        # Collect all colors with positions
        skin_colors = {}
        hair_colors = {}

        for yc in range(h):
            for xc in range(w):
                c = px[xc, yc]
                if c[3] < 16:
                    continue
                r, g, b = c[0], c[1], c[2]
                lum = 0.299*r + 0.587*g + 0.114*b

                # Upper 40% tends to be hair
                if yc < h * 0.4:
                    key = (r, g, b)
                    hair_colors[key] = hair_colors.get(key, 0) + 1
                else:
                    key = (r, g, b)
                    skin_colors[key] = skin_colors.get(key, 0) + 1

        # Determine dominant hair vs skin colors by luminance
        hair_lums = {c: 0.299*c[0]+0.587*c[1]+0.114*c[2] for c in hair_colors}
        skin_lums = {c: 0.299*c[0]+0.587*c[1]+0.114*c[2] for c in skin_colors}

        # Hair is generally darker, skin is mid-luminance
        # Find the threshold

        # Build mask
        eye_mouth_region_y = (int(h * 0.35), int(h * 0.85))
        eye_mouth_region_x = (int(w * 0.2), int(w * 0.8))

        for yc in range(h):
            for xc in range(w):
                c = px[xc, yc]
                if c[3] < 16:
                    continue
                r, g, b = c[0], c[1], c[2]
                lum = 0.299*r + 0.587*g + 0.114*b

                # Check if in defined "face feature" zone
                in_feature_zone = (eye_mouth_region_y[0] <= yc <= eye_mouth_region_y[1] and
                                   eye_mouth_region_x[0] <= xc <= eye_mouth_region_x[1])

                # Detect eyes/mouth: small dark islands in the face zone
                if in_feature_zone and lum < 100:
                    # Check if surrounded by skin
                    skin_count = 0
                    for dy in [-2, -1, 0, 1, 2]:
                        for dx in [-2, -1, 0, 1, 2]:
                            nx, ny = xc+dx, yc+dy
                            if 0 <= nx < w and 0 <= ny < h:
                                nc = px[nx, ny]
                                if nc[3] > 16:
                                    nlum = 0.299*nc[0] + 0.587*nc[1] + 0.114*nc[2]
                                    if 100 <= nlum <= 220:
                                        skin_count += 1
                    if skin_count >= 4:
                        epx[xc, yc] = 255  # eye/mouth
                        continue

                # Hair vs skin: hair is in upper zone or uses dark hair colors
                if lum < 100 or yc < h * 0.35:
                    hpx[xc, yc] = 255
                elif lum < 220:
                    spx[xc, yc] = 255
                else:
                    spx[xc, yc] = 255

        # Build clean face = hair + skin, no eyes/mouth
        clean_face = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        cpx = clean_face.load()
        for yc in range(h):
            for xc in range(w):
                if hpx[xc, yc] or spx[xc, yc]:
                    if not epx[xc, yc]:  # NOT eye/mouth
                        cpx[xc, yc] = px[xc, yc]

        # Build component debug view
        debug = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dpx = debug.load()
        for yc in range(h):
            for xc in range(w):
                if hpx[xc, yc]:
                    dpx[xc, yc] = (100, 100, 255, 255)  # blue = hair
                if spx[xc, yc]:
                    dpx[xc, yc] = (255, 200, 150, 255)  # skin tone
                if epx[xc, yc]:
                    dpx[xc, yc] = (255, 0, 0, 255)  # red = eyes/mouth

        # Save
        ref_dir = os.path.join(OUT_DIR, fid)
        os.makedirs(ref_dir, exist_ok=True)

        clean_face.save(os.path.join(ref_dir, f"{fid}_clean_face.png"))
        debug.save(os.path.join(ref_dir, f"{fid}_debug_regions.png"))
        ref_img.save(os.path.join(ref_dir, f"{fid}_original.png"))
        eye_mask.save(os.path.join(ref_dir, f"{fid}_eye_mask.png"))
        mouth_mask.save(os.path.join(ref_dir, f"{fid}_mouth_mask.png"))

        # Stats
        solid = sum(1 for yc in range(h) for xc in range(w) if cpx[xc, yc][3] > 16)
        eyes = sum(1 for yc in range(h) for xc in range(w) if epx[xc, yc])
        hair_px = sum(1 for yc in range(h) for xc in range(w) if hpx[xc, yc])
        skin_px = sum(1 for yc in range(h) for xc in range(w) if spx[xc, yc])
        print(f"  Clean face: {solid}px, hair={hair_px}, skin={skin_px}, eye/mouth removed={eyes}")
        print(f"    Saved to {ref_dir}")

    print(f"\nAll components extracted to {OUT_DIR}")

if __name__ == "__main__":
    extract_components()
