"""Generate placeholder face decorations for testing the hybrid body+face system.

Each face is a simple pixel art overlay (eyes + mouth) on transparent background.
These are placeholders until we generate real ones via SpriteCook.

Orientation note for Q-style characters: face is roughly the same from all angles,
so we reuse one front-facing image. The CX/CY values align it with the blank face
area on the body sprite.
"""

import json
import os
from PIL import Image

FACE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets/test/face"))

# Face definitions: name -> (width, height, draw_func)
# Each face is ~32x32 overlay for a 44x44 body sprite face area

def _draw_blank_face(img, pixels):
    """Blank/skin-colored face area (for debug)."""
    w, h = img.size
    cx, cy = w // 2, h // 2
    # Simple face oval
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / (w * 0.4)
            dy = (y - cy) / (h * 0.45)
            if dx * dx + dy * dy <= 1.0:
                img.putpixel((x, y), (255, 220, 180, 30))  # very faint skin

def _draw_happy_face(img, pixels):
    w, h = img.size
    cx, cy = w // 2, h // 2
    # Big cute eyes (QQTang style)
    for eye_x_offset in [-6, 6]:
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset)) / 4
                dy = (y - (cy - 2)) / 4.5
                if dx * dx + dy * dy <= 1.0:
                    # White eyeball
                    img.putpixel((x, y), (255, 255, 255, 255))
        # Pupil
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset + 1)) / 2
                dy = (y - (cy - 1)) / 2.5
                if dx * dx + dy * dy <= 1.0:
                    img.putpixel((x, y), (40, 30, 20, 255))
        # Highlight
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset - 1)) / 1.5
                dy = (y - (cy - 4)) / 1.5
                if dx * dx + dy * dy <= 1.0:
                    img.putpixel((x, y), (255, 255, 255, 255))
    # Happy smile
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / 5
            dy = (y - (cy + 4)) / 2.5
            if 0.6 < dx * dx + dy * dy < 1.0 and dy > 0:
                img.putpixel((x, y), (200, 80, 80, 255))


def _draw_angry_face(img, pixels):
    w, h = img.size
    cx, cy = w // 2, h // 2
    # Angry eyes - narrower, angled
    for eye_x_offset in [-5, 5]:
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset)) / 5
                dy = (y - (cy - 2)) / 3.5
                angle_tilt = (x - (cx + eye_x_offset)) * 0.08
                if dx * dx + (dy - angle_tilt) * (dy - angle_tilt) <= 1.0:
                    img.putpixel((x, y), (255, 255, 255, 255))
        # Dark pupil
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset + 1)) / 2.5
                dy = (y - (cy - 1)) / 2.5
                if dx * dx + dy * dy <= 1.0:
                    img.putpixel((x, y), (30, 20, 10, 255))
    # Angry V mouth
    for y in range(h):
        for x in range(w):
            mx, my = x - cx, y - (cy + 5)
            if abs(my) < 2 and abs(mx) < 4 and my < 0 and abs(mx) + abs(my) < 4:
                img.putpixel((x, y), (180, 60, 60, 255))


def _draw_shy_face(img, pixels):
    w, h = img.size
    cx, cy = w // 2, h // 2
    # Big round eyes
    for eye_x_offset in [-6, 6]:
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset)) / 5
                dy = (y - (cy - 1)) / 5.5
                if dx * dx + dy * dy <= 1.0:
                    img.putpixel((x, y), (255, 255, 255, 255))
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset + 1)) / 2.5
                dy = (y - (cy)) / 3
                if dx * dx + dy * dy <= 1.0:
                    img.putpixel((x, y), (40, 30, 20, 255))
    # Blush
    for blush_x in [-8, 8]:
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + blush_x)) / 3.5
                dy = (y - (cy + 3)) / 2.5
                if dx * dx + dy * dy <= 1.0:
                    r, g, b, a = img.getpixel((x, y))
                    img.putpixel((x, y), (min(255, r + 60), g, b, 255))
    # Small wavy mouth
    for y in range(h):
        for x in range(w):
            mx, my = x - cx, y - (cy + 6)
            if abs(my) < 1.5 and abs(mx) < 3:
                wave = (mx * 0.8)
                if abs(my - wave * 0.5) < 1:
                    img.putpixel((x, y), (200, 80, 80, 255))


def _draw_closed_eyes_face(img, pixels):
    w, h = img.size
    cx, cy = w // 2, h // 2
    for eye_x_offset in [-6, 6]:
        # Closed eyes (curved lines)
        for y in range(h):
            for x in range(w):
                dx = (x - (cx + eye_x_offset)) / 4.5
                dy = (y - (cy - 1)) / 1.5
                if abs(dx * dx + dy * dy - 0.5) < 0.3 and dy > 0:
                    img.putpixel((x, y), (40, 30, 20, 255))
    # Smile
    for y in range(h):
        for x in range(w):
            mx, my = x - cx, y - (cy + 4)
            if 0.5 < (mx/4)*(mx/4) + (my/2)*(my/2) < 1.0 and my > 0:
                img.putpixel((x, y), (200, 80, 80, 255))


FACES = {
    "happy": (32, 32, _draw_happy_face),
    "angry": (32, 32, _draw_angry_face),
    "shy": (32, 32, _draw_shy_face),
    "closed_eyes": (32, 32, _draw_closed_eyes_face),
    "blank": (32, 32, _draw_blank_face),
}


def generate_face(face_name, w, h, draw_func):
    """Generate a single face overlay PNG."""
    out_dir = os.path.join(FACE_DIR, face_name, "img")
    os.makedirs(out_dir, exist_ok=True)
    
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = img.load()
    draw_func(img, pixels)
    
    fn = f"face_{face_name}.png"
    img.save(os.path.join(out_dir, fn))
    
    # Create frame JSON
    cx = w // 2
    cy = h // 2
    
    face_json = {
        "NAME": face_name,
        "STAND_R": {"IMG": [fn], "CX": [cx], "CY": [cy]},
        "STAND_U": {"IMG": [fn], "CX": [cx], "CY": [cy]},
        "STAND_L": {"IMG": [fn], "CX": [cx], "CY": [cy]},
        "STAND_D": {"IMG": [fn], "CX": [cx], "CY": [cy]},
        "R": {"IMG": [fn, fn, fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
        "U": {"IMG": [fn, fn, fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
        "L": {"IMG": [fn, fn, fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
        "D": {"IMG": [fn, fn, fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
    }
    
    face_dir = os.path.join(FACE_DIR, face_name)
    json_path = os.path.join(face_dir, f"{face_name}.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(face_json, f, indent=4, ensure_ascii=False)
    
    print(f"  Generated: {face_name} ({w}x{h}) -> {json_path}")
    return fn


def build_face_atlas(face_name):
    """Build atlas for a face component."""
    face_dir = os.path.join(FACE_DIR, face_name)
    img_dir = os.path.join(face_dir, "img")
    
    pngs = [f for f in os.listdir(img_dir) if f.endswith(".png") and not f.endswith(".atlas.png")]
    if not pngs:
        return
    
    images = []
    for fn in pngs:
        img = Image.open(os.path.join(img_dir, fn)).convert("RGBA")
        images.append({"filename": fn, "image": img, "w": img.width, "h": img.height})
    
    atlas_w = max(64, images[0]["w"])
    atlas_h = images[0]["h"]
    # power of 2
    while atlas_w & (atlas_w - 1):
        atlas_w += atlas_w & -atlas_w
    
    atlas_img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    frames = {}
    x = 0
    for img_data in images:
        frames[img_data["filename"]] = {"x": x, "y": 0, "w": img_data["w"], "h": img_data["h"]}
        atlas_img.paste(img_data["image"], (x, 0), img_data["image"])
        x += img_data["w"]
    
    atlas_png = os.path.join(face_dir, f"{face_name}.atlas.png")
    atlas_img.save(atlas_png)
    
    atlas_json = {"frames": {}}
    for fn in frames:
        f = frames[fn]
        atlas_json["frames"][fn] = {"frame": {"x": f["x"], "y": f["y"], "w": f["w"], "h": f["h"]}}
    
    atlas_json_path = os.path.join(face_dir, f"{face_name}.atlas.json")
    with open(atlas_json_path, "w", encoding="utf-8") as f:
        json.dump(atlas_json, f, indent=4, ensure_ascii=False)
    
    print(f"  Atlas: {atlas_png} ({atlas_w}x{atlas_h})")


if __name__ == "__main__":
    print("=== Generating Test Face Decorations ===\n")
    
    for face_name, (w, h, draw_func) in FACES.items():
        generate_face(face_name, w, h, draw_func)
        build_face_atlas(face_name)
    
    print("\nDone! Generated %d face decorations." % len(FACES))
    print("Faces:", ", ".join(FACES.keys()))
