"""
Extract and analyze different faces from RO atlas to understand their structure.
Find front-facing vs profile faces.
"""

import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

def analyze():
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    # Find unique face IDs from frame names
    face_ids = set()
    for fn in data["frames"]:
        # Extract face ID (e.g., Face10301 from Face10301_stand_0_0.png)
        if fn.startswith("F"):
            face_ids.add(fn.split("_")[0])
        elif fn.startswith("f"):
            face_ids.add(fn.split("_")[0])

    print(f"Found {len(face_ids)} unique face IDs:")
    for fid in sorted(face_ids):
        # Get all frames for this face
        frames = [fn for fn in data["frames"] if fn.startswith(fid)]
        sizes = set()
        for fn in frames:
            info = data["frames"][fn]
            frame = info.get("frame", info)
            sizes.add((frame["w"], frame["h"]))
        print(f"  {fid}: {len(frames)} frames, sizes={sizes}")

    # Extract stand_0_0 for each face type and show pixel grid
    face_types = ["face10101", "face10201", "face10301", "face10701"]
    for face_id in face_types:
        # Find the frame
        ref_key = None
        for fn in data["frames"]:
            if fn.lower().startswith(face_id) and "stand_0_0" in fn:
                ref_key = fn
                break
        if not ref_key:
            print(f"\n{face_id}: NOT FOUND")
            continue

        info = data["frames"][ref_key]
        frame = info.get("frame", info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        img = atlas.crop((x, y, x + w, y + h))
        px = img.load()
        print(f"\n{face_id}: {w}x{h} at ({x},{y})")

        # Detect if it has 1 eye or 2 eyes by looking for edge patterns
        # Use color diversity as a simple heuristic
        colors = set()
        for yc in range(h):
            for xc in range(w):
                c = px[xc, yc]
                if c[3] > 16:
                    colors.add((c[0]//16, c[1]//16, c[2]//16))

        # Check symmetry: compare left and right halves
        mid = w // 2
        left_pixels = {}
        right_pixels = {}
        for yc in range(h):
            for xc in range(mid):
                c = px[xc, yc]
                if c[3] > 16:
                    left_pixels[(xc, yc)] = c
                # Mirror right side
                rx = w - 1 - xc
                c2 = px[rx, yc]
                if c2[3] > 16:
                    right_pixels[(rx, yc)] = c2

        # Compare color distributions
        left_colors = set((c[0]//32, c[1]//32, c[2]//32) for c in left_pixels.values())
        right_colors = set((c[0]//32, c[1]//32, c[2]//32) for c in right_pixels.values())
        overlap = len(left_colors & right_colors)
        total = len(left_colors | right_colors)
        symmetry_ratio = overlap / total if total > 0 else 0

        print(f"  Quantized colors: {len(colors)}")
        print(f"  Symmetry ratio: {symmetry_ratio:.2f} (1.0 = perfectly symmetric)")

        # Save face image for analysis
        out_dir = os.path.join(ROOT, "assets", "train", "face_annotations")
        os.makedirs(out_dir, exist_ok=True)
        img.save(os.path.join(out_dir, f"{face_id}_extracted.png"))

        # Show ASCII grid with color index
        color_to_idx = {}
        for yc in range(h):
            for xc in range(w):
                c = px[xc, yc]
                if c[3] > 16:
                    key = (c[0], c[1], c[2])
                    if key not in color_to_idx:
                        color_to_idx[key] = len(color_to_idx)

        idx_to_color = {v: k for k, v in color_to_idx.items()}
        print(f"  Unique RGB colors: {len(color_to_idx)}")
        print(f"  Pixel grid (y rows):")
        for yc in range(h):
            row = f"    y={yc:2d}: "
            for xc in range(w):
                c = px[xc, yc]
                if c[3] > 16:
                    key = (c[0], c[1], c[2])
                    ci = color_to_idx[key]
                    row += f"{ci:3d}"
                else:
                    row += "  ."
            print(row)

if __name__ == "__main__":
    analyze()
