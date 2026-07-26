"""
Propose precise region template for face10101 stand_0_0 based on visual analysis of pixel grid.
Manual pixel-level annotation approach.
"""

import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

def get_color_index_map(px, w, h):
    """Build color index map for the image."""
    color_to_idx = {}
    idx_map = [[-1]*w for _ in range(h)]
    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] > 16:
                key = (c[0], c[1], c[2])
                if key not in color_to_idx:
                    color_to_idx[key] = len(color_to_idx)
                idx_map[yc][xc] = color_to_idx[key]
            else:
                idx_map[yc][xc] = -1  # transparent
    idx_to_color = {v: k for k, v in color_to_idx.items()}
    return idx_map, idx_to_color

def analyze():
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    ref_key = None
    for fn in data["frames"]:
        if "face10101" in fn.lower() and "stand_0_0" in fn:
            ref_key = fn
            break
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    img = atlas.crop((x, y, x + w, y + h))
    px = img.load()

    idx_map, idx_to_color = get_color_index_map(px, w, h)

    print(f"Image size: {w}x{h}")
    print(f"\nPixel grid with color indices (Row: [col indices]):")
    for yc in range(h):
        row = f"y={yc:2d}: "
        colors_in_row = []
        for xc in range(w):
            ci = idx_map[yc][xc]
            if ci >= 0:
                colors_in_row.append(str(ci).rjust(2))
            else:
                colors_in_row.append(" .")
        row += " ".join(colors_in_row)
        print(row)

    # Now let me do a MUCH more precise classification
    # Based on the pixel grid:

    # EYES - I can see:
    # Left eye: row 20-21, col 12-15 (4x2 = 8 pixels)
    # Right eye: row 20-21, col 19-22 (4x2 = 8 pixels)
    # Eye white/highlight around them

    # Let me list EXACT eye pixels from the grid:
    # Row 19, col 12-15, 19-22 (surrounding skin-toned areas? No - at row 19, col 12=18, 13=18, etc)

    # Actually, I need to be more careful. In the grid output from the earlier tool:
    # Row 19: eyes at col 12-15 and col 19-22, with some dark colors
    # Row 20: eyes at same range
    # Row 21: eyes

    # Let me manually define exact regions based on color index analysis:
    # Hair colors (dark): indices 17-21 (lum < 110)
    # Eye-specific colors: index 33 (black eye dot), 38 (blue iris), 42 (white highlight)
    # Mouth-specific colors: 36, 37 (gray-blue)
    # Everything else = skin

    # First, identify which color indices are "special" (not skin)
    hair_color_indices = {17, 18, 19, 20, 21}
    eye_color_indices = {33, 38, 42}
    mouth_color_indices = {36, 37}
    # Also 34, 35 might be part of eye or mouth depending on position

    # Build region map manually
    hair_pixels = []
    skin_pixels = []
    eye_pixels = []
    mouth_pixels = []
    unmapped = []

    for yc in range(h):
        for xc in range(w):
            ci = idx_map[yc][xc]
            if ci < 0:
                continue

            c = px[xc, yc]
            r, g, b, a = c
            lum = 0.299*r + 0.587*g + 0.114*b

            # Check position-based regions FIRST (overrides color-based)
            # Left eye: approximate pixel range
            if (xc, yc) in [(12,19),(13,19),(14,19),(15,19),
                            (12,20),(13,20),(14,20),(15,20),
                            (12,21),(13,21),(14,21),(15,21),
                            (11,20),(11,21)]:
                eye_pixels.append((xc, yc, ci, lum))
            # Right eye  
            elif (xc, yc) in [(19,19),(20,19),(21,19),(22,19),
                              (19,20),(20,20),(21,20),(22,20),
                              (19,21),(20,21),(21,21),(22,21),
                              (23,20),(23,21)]:
                eye_pixels.append((xc, yc, ci, lum))
            # Mouth
            elif yc == 23 and xc in range(13, 21):
                mouth_pixels.append((xc, yc, ci, lum))
            elif yc == 24 and xc in range(13, 21):
                mouth_pixels.append((xc, yc, ci, lum))
            elif yc == 25 and xc in range(14, 21):
                mouth_pixels.append((xc, yc, ci, lum))
            elif yc == 22 and xc in range(16, 19):
                mouth_pixels.append((xc, yc, ci, lum))
            # Hair (dark outline on sides)
            elif ci in hair_color_indices or (xc > 28 and yc > 15):
                hair_pixels.append((xc, yc, ci, lum))
            elif lum < 40 and yc > 17:
                # Dark pixels near bottom = shadow, classify as skin shadow
                skin_pixels.append((xc, yc, ci, lum))
            elif lum < 50 and yc > 22:
                # Dark chin area
                skin_pixels.append((xc, yc, ci, lum))
            else:
                skin_pixels.append((xc, yc, ci, lum))

    print(f"\n\n=== MANUAL REGION CLASSIFICATION ===")
    print(f"Hair: {len(hair_pixels)}")
    print(f"Skin: {len(skin_pixels)}")
    print(f"Eyes: {len(eye_pixels)}")
    print(f"Mouth: {len(mouth_pixels)}")
    total = len(hair_pixels) + len(skin_pixels) + len(eye_pixels) + len(mouth_pixels)
    print(f"Total opaque: {total}")

    # Output region visualization
    print(f"\nRegion visualization (H=hair, S=skin, E=eye, M=mouth, .=transparent):")
    for yc in range(h):
        row = ""
        for xc in range(w):
            ci = idx_map[yc][xc]
            if ci < 0:
                row += "."
            elif any(p[0]==xc and p[1]==yc for p in hair_pixels):
                row += "H"
            elif any(p[0]==xc and p[1]==yc for p in skin_pixels):
                row += "S"
            elif any(p[0]==xc and p[1]==yc for p in eye_pixels):
                row += "E"
            elif any(p[0]==xc and p[1]==yc for p in mouth_pixels):
                row += "M"
            else:
                row += "?"
        print(f"  y={yc:2d}: {row}")

    # Save
    out = {
        "name": "face10101_stand_0_0",
        "width": w, "height": h,
        "pixels": {
            "hair": [[p[0], p[1]] for p in hair_pixels],
            "skin": [[p[0], p[1]] for p in skin_pixels],
            "eyes": [[p[0], p[1]] for p in eye_pixels],
            "mouth": [[p[0], p[1]] for p in mouth_pixels],
        },
        "count": {
            "hair": len(hair_pixels),
            "skin": len(skin_pixels),
            "eyes": len(eye_pixels),
            "mouth": len(mouth_pixels),
            "total": total
        }
    }
    out_path = os.path.join(ROOT, "assets", "train", "face_annotations", "face10101_pixel_template_v2.json")
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)
    print(f"\nSaved: {out_path}")

    # Show unique colors per region
    for region_name, pixels in [("hair", hair_pixels), ("skin", skin_pixels), ("eyes", eye_pixels), ("mouth", mouth_pixels)]:
        colors = set()
        for xc, yc, ci, lum in pixels:
            col = idx_to_color[ci]
            colors.add((col, ci))
        sorted_colors = sorted(colors, key=lambda x: 0.299*x[0][0] + 0.587*x[0][1] + 0.114*x[0][2])
        print(f"\n{region_name} ({len(pixels)} pixels, {len(colors)} unique colors):")
        for col, ci in sorted_colors:
            r, g, b = col
            lum = 0.299*r + 0.587*g + 0.114*b
            print(f"  idx={ci:2d} RGB=({r:3d},{g:3d},{b:3d}) lum={lum:.0f}")

if __name__ == "__main__":
    analyze()
