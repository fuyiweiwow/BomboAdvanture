"""RO Sprite Pipeline - Palette Shifter + Component Packager

Usage:
  python ro_pipeline.py new-face  # Generate new face variants from existing
  python ro_pipeline.py pack      # Package components into atlas

This is the "AI Artist" core - generates new RO-style components
by intelligently repurposing existing sprites + color theory.
"""

import os, json, sys, colorsys, random
from PIL import Image
from collections import defaultdict

# === Config ===
ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
SRC = os.path.join(ROOT, "assets", "img")
OUT = os.path.join(ROOT, "assets", "test", "ro_pipeline")
os.makedirs(OUT, exist_ok=True)

# === Color Palettes (RO-style) ===
# Skin tones (RO uses VERY limited skin colors - 3-4 shades max)
SKIN_PALETTES = {
    "light":  [(254, 220, 184), (248, 196, 152), (240, 168, 116), (220, 140, 88)],
    "tan":    [(244, 204, 160), (232, 180, 128), (212, 156, 100), (188, 128, 68)],
    "dark":   [(208, 168, 120), (184, 140, 88), (156, 112, 68), (128, 84, 48)],
    "pale":   [(255, 236, 212), (252, 216, 184), (244, 192, 152), (228, 164, 120)],
}

# Hair color palettes (4 shades each)
HAIR_PALETTES = {
    "blonde": [(250, 220, 120), (232, 192, 80), (192, 156, 48), (140, 108, 28)],
    "red":    [(224, 96, 48), (196, 68, 32), (160, 48, 20), (112, 28, 8)],
    "brown":  [(180, 140, 100), (148, 108, 72), (112, 76, 48), (72, 48, 28)],
    "black":  [(120, 120, 128), (80, 80, 88), (48, 48, 56), (24, 24, 32)],
    "blue":   [(140, 180, 240), (96, 140, 216), (60, 96, 180), (32, 56, 120)],
    "green":  [(140, 200, 120), (96, 164, 80), (60, 124, 48), (32, 80, 24)],
    "pink":   [(240, 160, 200), (220, 120, 168), (188, 76, 128), (128, 40, 80)],
    "white":  [(240, 240, 248), (200, 200, 216), (156, 156, 172), (108, 108, 124)],
}

# Eye colors
EYE_PALETTES = {
    "blue":    (38, 102, 204),
    "green":   (60, 160, 80),
    "brown":   (140, 100, 60),
    "red":     (200, 60, 60),
    "gold":    (204, 170, 50),
    "purple":  (140, 80, 180),
    "cyan":    (40, 180, 200),
    "gray":    (140, 140, 160),
}

def rgb_to_hsl(r, g, b):
    r, g, b = r/255.0, g/255.0, b/255.0
    mx, mn = max(r, g, b), min(r, g, b)
    h = s = l = (mx + mn) / 2.0
    if mx == mn: h = s = 0.0
    else:
        d = mx - mn
        s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
        if mx == r: h = ((g - b) / d + (6 if g < b else 0)) / 6.0
        elif mx == g: h = ((b - r) / d + 2) / 6.0
        else: h = ((r - g) / d + 4) / 6.0
    return h, s, l

def hsl_to_rgb(h, s, l):
    if s == 0: return int(l*255), int(l*255), int(l*255)
    def hue2rgb(p, q, t):
        if t < 0: t += 1
        if t > 1: t -= 1
        if t < 1/6: return p + (q - p) * 6 * t
        if t < 1/2: return q
        if t < 2/3: return p + (q - p) * (2/3 - t) * 6
        return p
    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q
    return int(hue2rgb(p, q, h + 1/3)*255), int(hue2rgb(p, q, h)*255), int(hue2rgb(p, q, h - 1/3)*255)

class PaletteShifter:
    """Shifts sprite colors using HSL operations.
    
    Two modes:
    1. hue_shift: Shift hue of certain regions while preserving full shading
    2. palette_map: Map source colors to target palette (lossy)
    """
    
    @staticmethod
    def shift_hue(img, hue_offset):
        """Shift ALL pixel hues by hue_offset degrees, preserving L and S."""
        px = img.load()
        w, h = img.size
        new_img = Image.new("RGBA", (w, h))
        new_px = new_img.load()
        
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                if c[3] < 16:
                    new_px[x, y] = c
                else:
                    h_val, s, l = rgb_to_hsl(*c[:3])
                    h_new = (h_val + hue_offset) % 1.0
                    rc = hsl_to_rgb(h_new, s, l)
                    new_px[x, y] = (rc[0], rc[1], rc[2], c[3])
        
        return new_img
    
    @staticmethod
    def shift_hue_luminance_layered(img, src_colors, target_hue):
        """Shift hue of specific colors to target_hue, preserving luminance.
        
        src_colors: set of (r,g,b) tuples to shift
        target_hue: float 0-1
        """
        px = img.load()
        w, h = img.size
        new_img = Image.new("RGBA", (w, h))
        new_px = new_img.load()
        
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                if c[3] < 16:
                    new_px[x, y] = c
                else:
                    key = (c[0], c[1], c[2])
                    if key in src_colors:
                        _, s, l = rgb_to_hsl(*c[:3])
                        # Shift to target hue while keeping the original saturation and luminance
                        # But blend: new saturation = max(s, target_saturation)
                        new_s = max(s, 0.15)  # Ensure minimum saturation
                        rc = hsl_to_rgb(target_hue, new_s, l)
                        new_px[x, y] = (rc[0], rc[1], rc[2], c[3])
                    else:
                        new_px[x, y] = c
        
        return new_img


class SpriteExtractor:
    """Extract and analyze RO sprite palettes."""
    
    @staticmethod
    def extract_palette(img):
        """Get unique colors from image."""
        px = img.load()
        w, h = img.size
        colors = set()
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                if c[3] > 16:  # Skip near-transparent
                    colors.add((c[0], c[1], c[2]))
        return sorted(colors, key=lambda c: 0.299*c[0] + 0.587*c[1] + 0.114*c[2])
    
    @staticmethod
    def detect_palette_regions(img, face_id=None):
        """Guess which pixels are skin vs hair by position + color.
        
        In RO face sprites:
        - Bottom portion ~60% = face/skin
        - Top portion ~40% = hair
        - Side pixels = hair
        """
        px = img.load()
        w, h = img.size
        palette = SpriteExtractor.extract_palette(img)
        
        # For each color, check if it appears more in top half (hair) or bottom half (skin)
        color_zones = defaultdict(lambda: {"top": 0, "bottom": 0, "side": 0})
        for y in range(h):
            for x in range(w):
                c = px[x, y]
                if c[3] > 16:
                    key = (c[0], c[1], c[2])
                    if y < h * 0.4:
                        color_zones[key]["top"] += 1
                    else:
                        color_zones[key]["bottom"] += 1
                    if x < 4 or x > w - 5:
                        color_zones[key]["side"] += 1
        
        skin_colors = set()
        hair_colors = set()
        for color, zones in color_zones.items():
            total = zones["top"] + zones["bottom"]
            if total == 0: continue
            if zones["bottom"] > zones["top"]:
                skin_colors.add(color)
            else:
                hair_colors.add(color)
        
        return skin_colors, hair_colors


SKIN_HSV_RANGES = {
    "light":  (0.05, 0.10, 0.08),  # (hue, sat_offset, lum_offset)
    "tan":    (0.08, 0.15, 0.05),
    "dark":   (0.10, 0.20, -0.05),
    "pale":   (0.03, 0.05, 0.10),
}

HAIR_HSV_RANGES = {
    "blonde": (0.12, 0.20, 0.05),
    "red":    (0.02, 0.20, 0.0),
    "brown":  (0.08, 0.15, -0.05),
    "black":  (0.0,  0.0,  -0.15),
    "blue":   (0.60, 0.20, 0.0),
    "green":  (0.33, 0.20, 0.0),
    "pink":   (0.92, 0.15, 0.05),
    "white":  (0.0,  0.0,  0.10),
}


class FaceGenerator:
    """Generate new RO-style faces from existing sprites using hue-shift."""
    
    def __init__(self):
        self.face_dir = os.path.join(SRC, "face")
        self.atlas = Image.open(os.path.join(self.face_dir, "face.atlas.png")).convert("RGBA")
        with open(os.path.join(self.face_dir, "face.atlas.json")) as f:
            self.data = json.load(f)
        self.frames = self.data.get("frames", {})
        
        # Group frames by face ID
        self.faces = defaultdict(dict)
        for fn, info in self.frames.items():
            parts = os.path.splitext(fn)[0].split("_")
            face_id = parts[0].replace("Face", "face", 1)
            key = "_".join(parts[1:]) if len(parts) > 1 else parts[0]
            self.faces[face_id][key] = info
    
    def list_faces(self):
        """List available face IDs."""
        print("Available faces:")
        for fid in sorted(self.faces.keys()):
            print(f"  {fid}: {len(self.faces[fid])} frames")
    
    def generate_face_variant(self, src_face_id, dst_face_id, skin_tone="light", hair_color="blonde"):
        """Generate a new face variant by hue-shifting an existing one."""
        face_frames = self.faces.get(src_face_id)
        if not face_frames:
            print(f"  [ERR] Face {src_face_id} not found")
            return False
        
        # Use stand_0_0 as reference for color region detection
        ref_key = None
        for key in face_frames:
            if "stand" in key and key.endswith("_0"):
                ref_key = key
                break
        if not ref_key:
            ref_key = list(face_frames.keys())[0]
        
        ref_info = face_frames[ref_key]
        frame = ref_info.get("frame", ref_info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        ref_img = self.atlas.crop((x, y, x+w, y+h))
        
        # Detect skin/hair color regions
        skin_colors, hair_colors = SpriteExtractor.detect_palette_regions(ref_img)
        
        # Get target hue for skin and hair
        skin_hsv = SKIN_HSV_RANGES.get(skin_tone, (0.05, 0.10, 0.05))
        hair_hsv = HAIR_HSV_RANGES.get(hair_color, (0.12, 0.20, 0.0))
        
        print(f"  Generating {dst_face_id} from {src_face_id}")
        print(f"    Skin: {len(skin_colors)} colors -> {skin_tone} (hue={skin_hsv[0]:.2f})")
        print(f"    Hair: {len(hair_colors)} colors -> {hair_color} (hue={hair_hsv[0]:.2f})")
        
        # Generate all frames
        out_face_dir = os.path.join(OUT, "face", dst_face_id)
        os.makedirs(out_face_dir, exist_ok=True)
        
        frame_dir = os.path.join(ROOT, "assets", "frame", "face")
        src_frame_file = os.path.join(frame_dir, f"{src_face_id}.json")
        if os.path.exists(src_frame_file):
            with open(src_frame_file) as f:
                src_frame_data = json.load(f)
        
        new_images = {}
        for key, info in face_frames.items():
            frame = info.get("frame", info)
            x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
            img = self.atlas.crop((x, y, x+w, y+h))
            
            # Hue-shift skin pixels
            if skin_colors:
                img = PaletteShifter.shift_hue_luminance_layered(img, skin_colors, skin_hsv[0])
            # Hue-shift hair pixels  
            if hair_colors:
                img = PaletteShifter.shift_hue_luminance_layered(img, hair_colors, hair_hsv[0])
            
            out_fn = f"{dst_face_id}_{key}.png"
            img.save(os.path.join(out_face_dir, out_fn))
            new_images[key] = out_fn
        
        frame_out = {
            "NAME": dst_face_id,
        }
        
        # Map walk/stand directions
        dir_map = {"0": "R", "1": "U", "2": "L", "3": "D"}
        for dir_key in ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D"]:
            frame_out[dir_key] = {"IMG": [], "CX": [], "CY": []}
        
        for key, info in face_frames.items():
            out_fn = f"{dst_face_id}_{key}.png"
            parts = key.split("_")
            # key = "stand_0_0" -> parts = ["stand", "0", "0"]
            # key = "walk_0_0" -> parts = ["walk", "0", "0"]
            anim_type = parts[0]  # "stand" or "walk"
            dir_idx = parts[1]
            dir_name = dir_map.get(dir_idx, "R")
            
            if anim_type == "stand":
                frame_key = f"STAND_{dir_name}"
            else:
                frame_key = dir_name
            
            # Try to find CX/CY from source
            cx = 0
            cy = 0
            if os.path.exists(src_frame_file):
                src_entry = src_frame_data.get(frame_key, {})
                if src_entry:
                    img_list = src_entry.get("IMG", [])
                    cx_list = src_entry.get("CX", [])
                    cy_list = src_entry.get("CY", [])
                    # Find index by matching original filename
                    orig_fn = f"{src_face_id}_{key}.png"
                    try:
                        idx = img_list.index(orig_fn)
                        if idx < len(cx_list):
                            cx = cx_list[idx]
                            cy = cy_list[idx]
                    except ValueError:
                        pass
            
            if frame_key not in frame_out:
                frame_out[frame_key] = {"IMG": [], "CX": [], "CY": []}
            frame_out[frame_key]["IMG"].append(out_fn)
            frame_out[frame_key]["CX"].append(cx)
            frame_out[frame_key]["CY"].append(cy)
        
        out_json = os.path.join(out_face_dir, f"{dst_face_id}.json")
        with open(out_json, "w") as f:
            json.dump(frame_out, f, indent=4)
        
        print(f"  -> {len(new_images)} frames saved to {out_face_dir}")
        return True
    
    def batch_generate(self, configs):
        """Generate multiple face variants from a list of configs.
        
        configs: list of dicts with keys:
            src, dst, skin, hair
        """
        for cfg in configs:
            self.generate_face_variant(
                src_face_id=cfg.get("src", "10101"),
                dst_face_id=cfg.get("dst", "90001"),
                skin_tone=cfg.get("skin", "light"),
                hair_color=cfg.get("hair", "blonde"),
            )


class ComponentGenerator:
    """Generate eye/mouth/ear components in RO style."""
    
    @staticmethod
    def extract_component_shapes(comp_name):
        """Extract the shape mask from an existing component.
        
        Since eye/mouth are single-color sprites tinted at runtime,
        we just need the shape (alpha mask).
        """
        comp_dir = os.path.join(SRC, comp_name)
        atlas = Image.open(os.path.join(comp_dir, f"{comp_name}.atlas.png")).convert("RGBA")
        with open(os.path.join(comp_dir, f"{comp_name}.atlas.json")) as f:
            data = json.load(f)
        
        frames = data.get("frames", {})
        shapes = {}
        for fn, info in frames.items():
            frame = info.get("frame", info)
            x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
            sprite = atlas.crop((x, y, x+w, y+h))
            shapes[fn] = sprite
        
        return shapes, frames
    
    @staticmethod
    def copy_component(src_comp, dst_comp, color=None):
        """Copy a component's shapes to a new component ID.
        
        Since components are single-color masks, we just copy the shape
        with (optionally) a new base color.
        """
        shapes, frame_data = ComponentGenerator.extract_component_shapes(src_comp)
        
        dst_dir = os.path.join(OUT, dst_comp)
        os.makedirs(dst_dir, exist_ok=True)
        
        new_frame_data = {"frames": {}}
        for fn, img in shapes.items():
            if color:
                # Recolor: set all non-transparent pixels to new color
                px = img.load()
                w, h = img.size
                new_img = Image.new("RGBA", (w, h))
                new_px = new_img.load()
                for y in range(h):
                    for x in range(w):
                        c = px[x, y]
                        if c[3] > 0:
                            new_px[x, y] = (*color, c[3])
                        else:
                            new_px[x, y] = (0, 0, 0, 0)
                new_img.save(os.path.join(dst_dir, fn))
            else:
                img.save(os.path.join(dst_dir, fn))
            
            # Copy frame data
            new_frame_data["frames"][fn] = frame_data[fn]
        
        # Save frame data JSON
        with open(os.path.join(dst_dir, f"{dst_comp}.json"), "w") as f:
            json.dump(new_frame_data, f, indent=4)
        
        print(f"  Copied {src_comp} -> {dst_dir} ({len(shapes)} frames)")
        return True


class AtlasBuilder:
    """Build atlas PNG + JSON from individual frame images."""
    
    @staticmethod
    def pack_frames(frame_dir, name):
        """Pack individual frame PNGs into an atlas.
        
        Uses a simple grid layout (8 cols, varying rows).
        """
        pngs = sorted([f for f in os.listdir(frame_dir) if f.endswith(".png")])
        if not pngs:
            print(f"  [ERR] No PNGs in {frame_dir}")
            return None
        
        # Get max size
        widths = []
        heights = []
        for p in pngs:
            img = Image.open(os.path.join(frame_dir, p))
            widths.append(img.width)
            heights.append(img.height)
        
        cell_w = max(widths)
        cell_h = max(heights)
        cols = 8
        rows = (len(pngs) + cols - 1) // cols
        atlas_w = cols * cell_w
        atlas_h = rows * cell_h
        
        atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
        frame_data = {"frames": {}}
        
        for i, p in enumerate(pngs):
            col = i % cols
            row = i // cols
            x = col * cell_w
            y = row * cell_h
            
            img = Image.open(os.path.join(frame_dir, p))
            # Center within cell
            ox = (cell_w - img.width) // 2
            oy = (cell_h - img.height) // 2
            atlas.paste(img, (x + ox, y + oy))
            
            frame_data["frames"][p] = {
                "frame": {"x": x + ox, "y": y + oy, "w": img.width, "h": img.height},
                "rotated": False,
                "trimmed": False,
                "spriteSourceSize": {"x": 0, "y": 0, "w": img.width, "h": img.height},
                "sourceSize": {"w": img.width, "h": img.height},
            }
        
        atlas_path = os.path.join(frame_dir, f"{name}.atlas.png")
        json_path = os.path.join(frame_dir, f"{name}.atlas.json")
        
        atlas.save(atlas_path)
        with open(json_path, "w") as f:
            json.dump(frame_data, f, indent=4)
        
        print(f"  Packed {len(pngs)} frames -> {atlas_path} ({atlas_w}x{atlas_h})")
        return (atlas_path, json_path)


def cmd_new_face():
    """Generate new face variants from existing RO faces."""
    generator = FaceGenerator()
    generator.list_faces()
    
    configs = [
        # src            dst        skin      hair
        ("face10101", "face91001", "light",  "blonde"),
        ("face10201", "face91002", "tan",    "brown"),
        ("face10301", "face91003", "pale",   "red"),
        ("face10101", "face91004", "dark",   "black"),
        ("face10201", "face91005", "light",  "blue"),
        ("face10301", "face91006", "tan",    "green"),
        ("face10101", "face91007", "pale",   "pink"),
        ("face10201", "face91008", "dark",   "white"),
    ]
    
    for src, dst, skin, hair in configs:
        generator.generate_face_variant(
            src_face_id=src,
            dst_face_id=dst,
            skin_tone=skin,
            hair_color=hair,
        )
    
    print(f"\nAll faces generated in {OUT}/face/")


def cmd_pack():
    """Pack generated components into atlas format."""
    # Pack faces
    face_dir = os.path.join(OUT, "face")
    for fid in os.listdir(face_dir):
        fid_dir = os.path.join(face_dir, fid)
        if os.path.isdir(fid_dir):
            print(f"\nPacking {fid}...")
            AtlasBuilder.pack_frames(fid_dir, fid)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ro_pipeline.py <command>")
        print("Commands:")
        print("  new-face   - Generate new face variants")
        print("  pack       - Package into atlas format")
        sys.exit(1)
    
    cmd = sys.argv[1]
    if cmd == "new-face":
        cmd_new_face()
    elif cmd == "pack":
        cmd_pack()
    else:
        print(f"Unknown command: {cmd}")
