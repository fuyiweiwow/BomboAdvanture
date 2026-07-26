"""
Visualize the region template as an image (H=red, S=green, E=blue, M=yellow, .=transparent).
Saves annotated overlay and region-only images.
"""

import os, json
from PIL import Image, ImageDraw

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"

def visualize():
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)

    # Load pixel template
    tmpl_path = os.path.join(ROOT, "assets", "train", "face_annotations", "face10101_pixel_template.json")
    with open(tmpl_path) as f:
        tmpl = json.load(f)

    # Find source frame
    ref_key = None
    for fn in data["frames"]:
        if "face10101" in fn.lower() and "stand_0_0" in fn:
            ref_key = fn
            break
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    img = atlas.crop((x, y, x + w, y + h)).copy()

    # Build pixel -> region lookup
    region_lookup = {}
    for region, pixels in tmpl["pixels"].items():
        for px in pixels:
            region_lookup[tuple(px)] = region

    # Color mapping for regions
    region_colors = {
        "hair": (255, 0, 0, 200),    # red overlay
        "skin": (0, 255, 0, 100),    # green overlay
        "eyes": (0, 0, 255, 200),    # blue overlay
        "mouth": (255, 255, 0, 150), # yellow overlay
    }

    # Create overlay version
    overlay = img.copy()
    overlay_px = overlay.load()
    for yc in range(h):
        for xc in range(w):
            key = (xc, yc)
            if key in region_lookup:
                region = region_lookup[key]
                color = region_colors.get(region, (128, 128, 128, 100))
                r0, g0, b0, a0 = overlay_px[xc, yc]
                r1, g1, b1, a1 = color
                # Blend
                alpha = a1 / 255.0
                overlay_px[xc, yc] = (
                    int(r0 * (1 - alpha) + r1 * alpha),
                    int(g0 * (1 - alpha) + g1 * alpha),
                    int(b0 * (1 - alpha) + b1 * alpha),
                    255
                )
            elif img.getpixel((xc, yc))[3] < 16:
                pass  # transparent

    # Create region-only image (color-coded by region type)
    region_only = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    region_px = region_only.load()
    for yc in range(h):
        for xc in range(w):
            key = (xc, yc)
            if key in region_lookup:
                region = region_lookup[key]
                color = region_colors.get(region, (128, 128, 128, 255))
                region_px[xc, yc] = color

    # Create individual region masks (white = region, black = not)
    for region_name in ["hair", "skin", "eyes", "mouth"]:
        mask = Image.new("L", (w, h), 0)
        mask_px = mask.load()
        for px_coord in tmpl["pixels"].get(region_name, []):
            xc, yc = px_coord
            if 0 <= xc < w and 0 <= yc < h:
                mask_px[xc, yc] = 255
        mask_path = os.path.join(ROOT, "assets", "train", "face_annotations", f"face10101_mask_{region_name}.png")
        mask.save(mask_path)
        print(f"Saved mask: {mask_path} ({tmpl['count'][region_name]} pixels)")

    # Save visualizations
    out_dir = os.path.join(ROOT, "assets", "train", "face_annotations")
    overlay.save(os.path.join(out_dir, "face10101_overlay.png"))
    region_only.save(os.path.join(out_dir, "face10101_region_only.png"))
    img.save(os.path.join(out_dir, "face10101_original.png"))

    print(f"\nSaved:")
    print(f"  face10101_original.png - original face")
    print(f"  face10101_overlay.png - original + region colors overlaid")
    print(f"  face10101_region_only.png - region colors only")

    # Print pixel stats per region
    coverage = {}
    for region, pixels in tmpl["pixels"].items():
        unique_colors = set()
        for xc, yc in pixels:
            c = img.getpixel((xc, yc))
            if c[3] > 16:
                unique_colors.add((c[0], c[1], c[2]))
        coverage[region] = {
            "pixel_count": len(pixels),
            "unique_colors": len(unique_colors),
            "colors": sorted(unique_colors, key=lambda c: 0.299*c[0] + 0.587*c[1] + 0.114*c[2])
        }

    print(f"\nRegion coverage:")
    for region, info in coverage.items():
        print(f"  {region}: {info['pixel_count']} pixels, {info['unique_colors']} unique colors")
        lum_list = [0.299*c[0] + 0.587*c[1] + 0.114*c[2] for c in info['colors']]
        if lum_list:
            print(f"    luminance range: {min(lum_list):.0f} - {max(lum_list):.0f}")

if __name__ == "__main__":
    visualize()
