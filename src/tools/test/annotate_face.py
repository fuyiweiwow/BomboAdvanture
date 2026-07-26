"""
RO Face Pixel Annotation Tool.

Displays a face frame with pixel coordinates so the user can
mark which pixels belong to: hair, skin, eyes, mouth.
"""

import os, json, sys
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
FACE = os.path.join(ROOT, "assets", "img", "face")

def show_face_grid(face_id="face10101"):
    """Display the face frame as an annotated pixel grid."""
    atlas = Image.open(os.path.join(FACE, "face.atlas.png")).convert("RGBA")
    with open(os.path.join(FACE, "face.atlas.json")) as f:
        data = json.load(f)

    # Find stand_0_0 for this face
    ref_fn = None
    for fn in data["frames"]:
        if fn.lower().startswith(face_id.lower()) and "stand_0_0" in fn:
            ref_fn = fn
            break
    if not ref_fn:
        print(f"No stand_0_0 found for {face_id}")
        return

    info = data["frames"][ref_fn]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    img = atlas.crop((x, y, x + w, y + h))
    px = img.load()

    print(f"\n{'='*80}")
    print(f"  {face_id} stand_0_0 ({w}x{h})")
    print(f"  ↓ Each pixel shown as: color_index")
    print(f"  ↓ '.' = transparent")
    print(f"{'='*80}\n")

    # Color index per pixel
    color_idx = {}
    idx = 0
    for yc in range(h):
        row = ""
        for xc in range(w):
            c = px[xc, yc]
            if c[3] < 16:
                row += " ."
            else:
                key = (c[0], c[1], c[2])
                if key not in color_idx:
                    color_idx[key] = idx
                    idx += 1
                row += f"{color_idx[key]:2d}"
        print(f"  y={yc:2d}: {row}")

    print(f"\n  Color palette ({len(color_idx)} colors):")
    for c, i in sorted(color_idx.items(), key=lambda x: x[1]):
        r, g, b = c
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        print(f"    [{i}] RGB({r:3d},{g:3d},{b:3d}) lum={lum:.0f}  {'■' * 3}")

    # Generate automated region proposal
    print(f"\n{'='*80}")
    print(f"  PROPOSED REGION TEMPLATE (based on luminance analysis)")
    print(f"{'='*80}\n")

    # Get all solid pixels sorted by luminance
    solid = []
    for yc in range(h):
        for xc in range(w):
            c = px[xc, yc]
            if c[3] > 16:
                lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
                solid.append((xc, yc, c, lum))

    # Separate upper/lower to find split
    upper = [s for s in solid if s[1] < h * 0.4]
    lower = [s for s in solid if s[1] >= h * 0.4]

    upper_avg = sum(s[3] for s in upper) / len(upper) if upper else 0
    lower_avg = sum(s[3] for s in lower) / len(lower) if lower else 0
    threshold = (upper_avg + lower_avg) / 2

    print(f"  Hair/skin luminance threshold: {threshold:.0f}")
    print(f"  Upper half avg luminance: {upper_avg:.0f}")
    print(f"  Lower half avg luminance: {lower_avg:.0f}")

    hair_cells = []
    skin_cells = []
    for xc, yc, c, lum in solid:
        if lum < threshold:
            hair_cells.append((xc, yc))
        else:
            skin_cells.append((xc, yc))

    # Output as coordinate lists
    print(f"\n  Hair pixels ({len(hair_cells)}):")
    print(f"  [{', '.join(f'({x},{y})' for x,y in sorted(hair_cells))}]")

    print(f"\n  Skin pixels ({len(skin_cells)}):")
    print(f"  [{', '.join(f'({x},{y})' for x,y in sorted(skin_cells))}]")

    # Identify potential eye/mouth dark pixel clusters in skin region
    eye_candidates = []
    for xc, yc in skin_cells:
        c = px[xc, yc]
        lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
        if lum < 150 and yc >= h * 0.3 and yc <= h * 0.7:
            eye_candidates.append((xc, yc))

    if eye_candidates:
        print(f"\n  Potential eye/mouth pixels ({len(eye_candidates)}):")
        print(f"  [{', '.join(f'({x},{y})' for x,y in sorted(eye_candidates)[:30])}{'...' if len(eye_candidates) > 30 else ''}]")

    # Save proposal
    proposal = {
        "face_id": face_id,
        "width": w,
        "height": h,
        "hair_skin_threshold": threshold,
        "hair": hair_cells,
        "skin": skin_cells,
        "eye_mouth_candidates": eye_candidates,
    }

    # Save as JSON
    out_dir = os.path.join(ROOT, "assets", "train", "face_annotations")
    os.makedirs(out_dir, exist_ok=True)
    prop_path = os.path.join(out_dir, f"{face_id}_proposal.json")
    with open(prop_path, "w") as f:
        json.dump(proposal, f, indent=2)
    print(f"\n  Proposal saved: {prop_path}")

    return proposal


if __name__ == "__main__":
    face_id = sys.argv[1] if len(sys.argv) > 1 else "face10101"
    show_face_grid(face_id)
