"""
Visualize region extraction: each region shown in isolation with everything else blacked out.
This helps verify hair/skin/eye/mouth pixel assignments are correct.
"""

import os, json, sys
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
OUT = os.path.join(ROOT, "assets", "test", "ro_component_v5", "region_inspect")
os.makedirs(OUT, exist_ok=True)

REGION_COLORS = {
    "hair": (200, 50, 50),    # reddish
    "skin": (240, 200, 150),  # skin tone for empty areas
    "eyes": (50, 150, 255),   # blue
    "mouth": (255, 100, 100), # red
}

def inspect(face_id):
    print(f"\n{'='*50}")
    print(f"Inspecting: {face_id}")
    print(f"{'='*50}")

    # Load atlas
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    # Find frame
    ref_key = next(fn for fn in data["frames"] if face_id.lower() in fn.lower() and "stand_0_0" in fn)
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    ox, oy, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    original = atlas.crop((ox, oy, ox + w, oy + h)).copy()
    orig_px = original.load()

    # Load template
    tmpl_path = os.path.join(ROOT, "assets", "train", "face_annotations", f"{face_id}_region_template.json")
    try:
        with open(tmpl_path) as f:
            tmpl = json.load(f)
    except FileNotFoundError:
        print(f"  No template found at {tmpl_path}")
        return

    # Build pixel lookup
    region_map = {}
    for region in ["hair", "skin", "eyes", "mouth"]:
        for px in tmpl["pixels"].get(region, []):
            region_map[tuple(px)] = region

    # For each region, create images
    for region_name, fill_color in REGION_COLORS.items():
        # Version 1: region keeps original color, rest = black
        isolate = Image.new("RGBA", (w, h), (0, 0, 0, 255))
        isolate_px = isolate.load()
        for yc in range(h):
            for xc in range(w):
                if (xc, yc) in region_map and region_map[(xc, yc)] == region_name:
                    isolate_px[xc, yc] = orig_px[xc, yc]
                elif orig_px[xc, yc][3] < 16:
                    isolate_px[xc, yc] = (0, 0, 0, 0)  # transparent

        # Version 2: region with colored outline, rest = semi-transparent original
        overlay = original.copy()
        overlay_px = overlay.load()
        for yc in range(h):
            for xc in range(w):
                c = orig_px[xc, yc]
                if c[3] < 16:
                    overlay_px[xc, yc] = (0, 0, 0, 0)
                elif (xc, yc) in region_map and region_map[(xc, yc)] == region_name:
                    overlay_px[xc, yc] = c  # full color
                else:
                    # Dim non-region pixels
                    overlay_px[xc, yc] = (c[0]//3, c[1]//3, c[2]//3, 255)

        # Version 3: region only (no background)
        region_only = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ro_px = region_only.load()
        for yc in range(h):
            for xc in range(w):
                if (xc, yc) in region_map and region_map[(xc, yc)] == region_name:
                    ro_px[xc, yc] = orig_px[xc, yc]

        iso_path = os.path.join(OUT, f"{face_id}_{region_name}_isolated.png")
        isolate.save(iso_path)

        ovr_path = os.path.join(OUT, f"{face_id}_{region_name}_highlighted.png")
        overlay.save(ovr_path)

        ro_path = os.path.join(OUT, f"{face_id}_{region_name}_only.png")
        region_only.save(ro_path)

        count = len(tmpl["pixels"].get(region_name, []))
        print(f"  {region_name}: {count} pixels -> {iso_path}")

    # Create combined check: 2x2 grid of all region-only images
    side = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    positions = [("hair", 0, 0), ("skin", w, 0), ("eyes", 0, h), ("mouth", w, h)]
    for region, dx, dy in positions:
        path = os.path.join(OUT, f"{face_id}_{region}_only.png")
        if os.path.exists(path):
            img = Image.open(path)
            side.paste(img, (dx, dy), img if img.mode == "RGBA" else None)
    side.save(os.path.join(OUT, f"{face_id}_4panel.png"))
    print(f"  4-panel saved: {os.path.join(OUT, f'{face_id}_4panel.png')}")

    # Print verification: pixel counts per region
    print(f"\n  Verification:")
    for region in ["hair", "skin", "eyes", "mouth"]:
        count = len(tmpl["pixels"].get(region, []))
        print(f"    {region}: {count} pixels")


if __name__ == "__main__":
    face_ids = sys.argv[1:] if len(sys.argv) > 1 else ["face10101", "face10301"]
    for fid in face_ids:
        inspect(fid)
    print(f"\nAll images saved to: {OUT}")
