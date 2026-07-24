"""SpriteCook -> bombo-adventure asset converter.

Converts SpriteCook single images or sprite sheets into the game's
frame JSON + atlas PNG format.

Usage:
    # For a single character image (like the front-facing base):
    python spritecook_convert.py --input-front front.png --out-dir ../../assets/test/body/body0
    
    # For a 4-direction sprite sheet (2x2 grid):
    python spritecook_convert.py --sheet 4dir.png --grid 2x2 --orientations R L U D --out-dir ../../assets/test/body/body0
"""

import json
import os
import sys
from PIL import Image

OUTPUT_SIZE = 64  # game target size

def process_single_image(input_path, output_dir, orientation="STAND_D", cx=None, cy=None):
    """Process a single sprite image (one orientation, one frame)."""
    img = Image.open(input_path).convert("RGBA")
    w, h = img.size
    
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(os.path.join(output_dir, "img"), exist_ok=True)
    
    if cx is None:
        cx = w // 2
    if cy is None:
        cy = h // 2
    
    base_name = os.path.splitext(os.path.basename(input_path))[0]
    frame_fn = f"{base_name}_{orientation}.png"
    
    frame_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    frame_img.paste(img, (0, 0), img)
    frame_img.save(os.path.join(output_dir, "img", frame_fn))
    
    frame_json = {
        "NAME": base_name,
        orientation: {
            "IMG": [frame_fn],
            "CX": [cx],
            "CY": [cy]
        }
    }
    
    # Add walking frames (reuse stand as single frame for now)
    walk_orient_map = {"STAND_R": "R", "STAND_U": "U", "STAND_L": "L", "STAND_D": "D"}
    if orientation in walk_orient_map:
        walk_key = walk_orient_map[orientation]
        walk_fn = frame_fn.replace("stand", "walk")
        frame_img.save(os.path.join(output_dir, "img", walk_fn))
        frame_json[walk_key] = {
            "IMG": [walk_fn] * 3,  # 3 walk frames (repeated for now)
            "CX": [cx] * 3,
            "CY": [cy] * 3
        }
    
    out_path = os.path.join(output_dir, f"{base_name}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(frame_json, f, indent=4, ensure_ascii=False)
    
    print(f"  Wrote {out_path}")
    return w, h


def process_sprite_sheet(input_path, output_dir, grid_cols, grid_rows, orientations):
    """Process a sprite sheet with known grid layout.
    
    orientations: list of orientation keys, one per cell, left-to-right top-to-bottom
    """
    sheet = Image.open(input_path).convert("RGBA")
    sw, sh = sheet.size
    cell_w = sw // grid_cols
    cell_h = sh // grid_rows
    
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(os.path.join(output_dir, "img"), exist_ok=True)
    
    base_name = os.path.splitext(os.path.basename(input_path))[0]
    frame_json = {"NAME": base_name}
    
    for idx, orient in enumerate(orientations):
        col = idx % grid_cols
        row = idx // grid_cols
        left = col * cell_w
        top = row * cell_h
        
        cell = sheet.crop((left, top, left + cell_w, top + cell_h))
        
        # Trim transparent edges
        bbox = cell.getbbox()
        if bbox:
            cell = cell.crop(bbox)
        
        cw, ch = cell.size
        cx = cw // 2
        cy = ch // 2
        
        frame_fn = f"{base_name}_{orient}.png"
        cell.save(os.path.join(output_dir, "img", frame_fn))
        
        frame_json[orient] = {
            "IMG": [frame_fn],
            "CX": [cx],
            "CY": [cy]
        }
    
    out_path = os.path.join(output_dir, f"{base_name}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(frame_json, f, indent=4, ensure_ascii=False)
    print(f"  Wrote {out_path}")


def build_atlas(component_dir, output_dir=None):
    """Build atlas PNG + atlas JSON from individual frame PNGs.
    Uses simple shelf-packing (same algorithm as sprite_sheet_packer.gd).
    """
    if output_dir is None:
        output_dir = component_dir
    
    img_dir = os.path.join(component_dir, "img")
    if not os.path.isdir(img_dir):
        img_dir = component_dir
    
    pngs = [f for f in os.listdir(img_dir) if f.endswith(".png") and not f.endswith(".atlas.png")]
    if not pngs:
        print("  No PNGs found")
        return
    
    images = []
    for fn in pngs:
        img = Image.open(os.path.join(img_dir, fn)).convert("RGBA")
        images.append({"filename": fn, "image": img, "w": img.width, "h": img.height})
    
    images.sort(key=lambda x: (-x["h"], -x["w"]))
    
    atlas_w = 64
    shelves = []
    frames = {}
    
    for img_data in images:
        fw, fh = img_data["w"], img_data["h"]
        placed = False
        
        for shelf in shelves:
            if fw <= atlas_w - shelf["cursor_x"] and fh <= shelf["h"]:
                frames[img_data["filename"]] = {"x": shelf["cursor_x"], "y": shelf["y"], "w": fw, "h": fh}
                shelf["cursor_x"] += fw
                placed = True
                break
        
        if placed:
            continue
        
        new_y = shelves[-1]["y"] + shelves[-1]["h"] if shelves else 0
        if fw > atlas_w:
            atlas_w = 1
            while atlas_w < fw:
                atlas_w <<= 1
        
        shelves.append({"y": new_y, "h": fh, "cursor_x": fw})
        frames[img_data["filename"]] = {"x": 0, "y": new_y, "w": fw, "h": fh}
    
    if not shelves:
        return
    
    total_h = shelves[-1]["y"] + shelves[-1]["h"]
    atlas_h = 1
    while atlas_h < total_h:
        atlas_h <<= 1
    
    atlas_img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    for img_data in images:
        fn = img_data["filename"]
        f = frames[fn]
        atlas_img.paste(img_data["image"], (f["x"], f["y"]), img_data["image"])
        img_data["image"] = None
    
    component_name = os.path.basename(component_dir)
    atlas_png = os.path.join(output_dir, f"{component_name}.atlas.png")
    atlas_img.save(atlas_png)
    
    atlas_json_data = {"frames": {}}
    for fn in frames:
        f = frames[fn]
        atlas_json_data["frames"][fn] = {"frame": {"x": f["x"], "y": f["y"], "w": f["w"], "h": f["h"]}}
    
    atlas_json = os.path.join(output_dir, f"{component_name}.atlas.json")
    with open(atlas_json, "w", encoding="utf-8") as f:
        json.dump(atlas_json_data, f, indent=4, ensure_ascii=False)
    
    print(f"  Atlas: {atlas_png} ({atlas_w}x{atlas_h})")
    print(f"  Atlas JSON: {atlas_json}")
    print(f"  Packed {len(images)} frames")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="SpriteCook asset converter")
    parser.add_argument("--input", help="Input PNG file")
    parser.add_argument("--out-dir", required=True, help="Output directory")
    parser.add_argument("--orientation", default="STAND_D", help="Orientation key for single image")
    parser.add_argument("--cx", type=int, help="Center X (auto if omitted)")
    parser.add_argument("--cy", type=int, help="Center Y (auto if omitted)")
    parser.add_argument("--atlas-only", action="store_true", help="Only rebuild atlas from existing PNGs")
    
    args = parser.parse_args()
    
    if args.atlas_only:
        build_atlas(args.out_dir)
    elif args.input:
        process_single_image(args.input, args.out_dir, args.orientation, args.cx, args.cy)
        build_atlas(args.out_dir)
