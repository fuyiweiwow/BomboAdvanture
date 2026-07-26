"""
Propose precise region template for face10101 stand_0_0 based on visual analysis.
Outputs a JSON that can be used by the component generator.
"""

import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

def analyze_and_propose():
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    # face10101 stand_0_0
    # Find face10101 stand_0_0
    ref_key = None
    for fn in data["frames"]:
        if "face10101" in fn.lower() and "stand_0_0" in fn:
            ref_key = fn
            break
    if not ref_key:
        print("face10101 stand_0_0 not found")
        return
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    img = atlas.crop((x, y, x + w, y + h))
    px = img.load()

    # Build color index
    color_to_idx = {}
    idx = 0
    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] > 16:
                key = (c[0], c[1], c[2])
                if key not in color_to_idx:
                    color_to_idx[key] = idx
                    idx += 1

    idx_to_color = {v: k for k, v in color_to_idx.items()}

    # Based on visual inspection of the pixel grid:
    # Color indices 17-21: dark hair outline (lum 40-107)
    # Color indices 0-16, 22-30: skin (lum 125-230) 
    # Color index 33: black -> eye pupil
    # Color index 38: blue -> eye iris
    # Color index 42: white -> eye highlight
    # Colors 36-37: gray-blue -> mouth area

    # I'll define regions by coordinate ranges and color groups
    template = {
        "name": "face10101_stand_0_0",
        "width": w,
        "height": h,
        "description": "RO face10101 component template",
        "regions": {
            "hair": {
                "description": "Hair silhouette - dark outline colors",
                "color_indices": [17, 18, 19, 20, 21],  # dark brown/red shades
                "luminance_range": [0, 110],
                "notes": "These are the dark hair outline colors. Row 0-3 also has skin-toned top."
            },
            "skin": {
                "description": "Face skin - mid to light peach tones",
                "color_indices": list(range(0, 17)) + list(range(22, 33)) + [34, 35, 39, 40, 43, 45, 47, 49, 52, 53, 54, 56, 57],
                "luminance_range": [110, 230],
                "notes": "Main face area. Excludes eyes, mouth, and hair outline."
            },
            "eyes": {
                "description": "Eye region - left and right eyes",
                "left_eye": {
                    "bounds": [10, 19, 16, 22],  # x1, y1, x2, y2
                    "color_indices": [33, 38, 42],  # black, blue, white
                    "notes": "Left eye at ~(12,20)"
                },
                "right_eye": {
                    "bounds": [18, 19, 24, 22],  # x1, y1, x2, y2
                    "color_indices": [33, 38, 42],  # black, blue, white
                    "notes": "Right eye at ~(20,20)"
                }
            },
            "mouth": {
                "description": "Mouth region",
                "bounds": [13, 22, 20, 25],  # x1, y1, x2, y2
                "color_indices": [36, 37, 42],  # gray-blue, white
                "notes": "Mouth at ~(16,23)"
            }
        }
    }

    # Build pixel-level masks based on the rules above
    hair_pixels = []
    skin_pixels = []
    eye_pixels = []
    mouth_pixels = []

    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16:
                continue
            key = (c[0], c[1], c[2])
            ci = color_to_idx[key]
            r, g, b, a = c
            lum = 0.299*r + 0.587*g + 0.114*b

            # Check eye regions first
            left = template["regions"]["eyes"]["left_eye"]["bounds"]
            right = template["regions"]["eyes"]["right_eye"]["bounds"]
            mouth_b = template["regions"]["mouth"]["bounds"]

            if (left[0] <= xc <= left[2] and left[1] <= yc <= left[3]) or \
               (right[0] <= xc <= right[2] and right[1] <= yc <= right[3]):
                eye_pixels.append((xc, yc))
            elif mouth_b[0] <= xc <= mouth_b[2] and mouth_b[1] <= yc <= mouth_b[3]:
                mouth_pixels.append((xc, yc))
            elif ci in template["regions"]["hair"]["color_indices"]:
                hair_pixels.append((xc, yc))
            elif lum > 110:
                skin_pixels.append((xc, yc))
            else:
                # Low-luminance pixels not in hair palette - classify by position
                if yc < h * 0.3:
                    hair_pixels.append((xc, yc))
                else:
                    skin_pixels.append((xc, yc))

    # Save the pixel-level template
    pixel_template = {
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
            "total": len(hair_pixels) + len(skin_pixels) + len(eye_pixels) + len(mouth_pixels),
        }
    }

    out_dir = os.path.join(ROOT, "assets", "train", "face_annotations")
    os.makedirs(out_dir, exist_ok=True)

    out_path = os.path.join(out_dir, "face10101_pixel_template.json")
    with open(out_path, "w") as f:
        json.dump(pixel_template, f, indent=2)

    print(f"Template saved: {out_path}")
    print(f"\nPixel breakdown:")
    for k, v in pixel_template["count"].items():
        print(f"  {k}: {v}")
    print(f"\nHair pixels ({len(hair_pixels)}):")
    print(json.dumps(hair_pixels))
    print(f"\nSkin pixels ({len(skin_pixels)}):")
    print(json.dumps(skin_pixels))
    print(f"\nEye pixels ({len(eye_pixels)}):")
    print(json.dumps(eye_pixels))
    print(f"\nMouth pixels ({len(mouth_pixels)}):")
    print(json.dumps(mouth_pixels))

    # Show coverage visually
    print(f"\nRegion visualization (H=hair, S=skin, E=eye, M=mouth, .=transparent):")
    for yc in range(h):
        row = ""
        for xc in range(w):
            if (xc, yc) in hair_pixels:
                row += "H"
            elif (xc, yc) in skin_pixels:
                row += "S"
            elif (xc, yc) in eye_pixels:
                row += "E"
            elif (xc, yc) in mouth_pixels:
                row += "M"
            else:
                c = px[xc, yc]
                if c[3] < 16:
                    row += "."
                else:
                    row += "?"
        print(f"  y={yc:2d}: {row}")

    return pixel_template

if __name__ == "__main__":
    analyze_and_propose()
