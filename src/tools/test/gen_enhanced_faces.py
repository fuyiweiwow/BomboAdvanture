"""Generate enhanced pixel art face atlas with proper RO-style colors.

Combines the facial structure from procedural generation with an improved
color palette inspired by the existing RO face atlas and AI-generated art.
"""

import json, os
from PIL import Image

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets/test/face"))
os.makedirs(OUTPUT_DIR, exist_ok=True)

W, H = 32, 33

# Color palette: RO-inspired + AI blush enhancement
# Format: (R, G, B, A)
BLACK = (0, 0, 0, 255)
DARK_BROWN = (40, 20, 10, 255)      # eye/pupil
DARK_RED = (120, 40, 30, 255)       # mouth
SKIN_BASE = (255, 218, 172, 180)    # base skin (semi-transparent)
SKIN_LIGHT = (255, 228, 190, 200)   # highlight skin
BLUSH = (249, 120, 132, 200)        # rosy cheeks (AI-inspired)
WHITE = (255, 255, 255, 255)        # eye white
EYE_LINE = (60, 30, 20, 255)        # eyelid line (for closed eyes)

def new_face():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))

def draw_pixel(img, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color)

def draw_box(img, x1, y1, x2, y2, color):
    for y in range(y1, y2 + 1):
        for x in range(x1, x2 + 1):
            draw_pixel(img, x, y, color)

def draw_eye(img, cx, cy, is_closed=False, is_angry=False, is_shy=False):
    """Draw an eye at center (cx, cy)."""
    if is_closed:
        # Closed eye: curved line
        for dx in range(-3, 4):
            dy = int(abs(dx) * 0.4)
            draw_pixel(img, cx + dx, cy + dy, EYE_LINE)
            draw_pixel(img, cx + dx, cy + dy + 1, EYE_LINE)
    elif is_angry:
        # Angry eye: angled/narrow
        draw_box(img, cx - 3, cy - 1, cx - 1, cy + 1, WHITE)
        draw_box(img, cx + 1, cy - 1, cx + 3, cy + 1, WHITE)
        draw_pixel(img, cx - 1, cy, DARK_BROWN)
        draw_pixel(img, cx + 1, cy, DARK_BROWN)
        # Angry eyebrow tilt
        draw_box(img, cx - 4, cy - 3, cx - 1, cy - 2, DARK_BROWN)
        draw_box(img, cx + 1, cy - 2, cx + 4, cy - 1, DARK_BROWN)
    elif is_shy:
        # Shy eye: big round
        draw_box(img, cx - 3, cy - 2, cx + 3, cy + 2, WHITE)
        draw_pixel(img, cx - 1, cy, DARK_BROWN)
        draw_pixel(img, cx + 1, cy, DARK_BROWN)
        draw_pixel(img, cx - 2, cy - 2, WHITE)  # highlight
        draw_pixel(img, cx + 2, cy - 2, WHITE)
    else:
        # Normal happy eye
        draw_box(img, cx - 3, cy - 2, cx + 3, cy + 2, WHITE)
        draw_pixel(img, cx - 1, cy, DARK_BROWN)
        draw_pixel(img, cx + 1, cy, DARK_BROWN)
        draw_pixel(img, cx - 2, cy - 2, WHITE)  # highlight
        draw_pixel(img, cx + 2, cy - 1, WHITE)

def draw_mouth(img, cx, cy, expression):
    if expression == "happy":
        # Big smile
        for dx in range(-4, 5):
            dy = 2 - abs(dx) // 2
            draw_pixel(img, cx + dx, cy + dy, DARK_RED)
            if abs(dx) <= 3:
                draw_pixel(img, cx + dx, cy + dy + 1, DARK_RED)
    elif expression == "angry":
        # Angry frown
        for dx in range(-3, 4):
            dy = abs(dx) // 2
            draw_pixel(img, cx + dx, cy - dy, DARK_RED)
    elif expression == "shy":
        # Wavy nervous mouth
        for dx in range(-3, 4):
            dy = int(abs(dx) * 0.3)
            draw_pixel(img, cx + dx, cy + dy, DARK_RED)
    elif expression == "closed_eyes":
        # Small gentle smile
        for dx in range(-3, 4):
            dy = 1 - abs(dx) // 3
            draw_pixel(img, cx + dx, cy + dy, DARK_RED)
    else:  # blank
        # Straight line
        for dx in range(-3, 4):
            draw_pixel(img, cx + dx, cy, DARK_RED)

def draw_blush(img, cx, cy, has_blush=True):
    """Draw blush marks on cheeks."""
    if not has_blush:
        return
    for x_off in [-9, 9]:
        for dy in range(-1, 2):
            for dx in range(-2, 3):
                draw_pixel(img, cx + x_off + dx, cy + dy, BLUSH)

def draw_skin_base(img):
    """Draw a subtle skin oval as base."""
    cx, cy = W // 2, H // 2
    # Simple face oval
    for y in range(cy - 10, cy + 12):
        for x in range(cx - 11, cx + 12):
            dx = (x - cx) / 11
            dy = (y - cy) / 12
            if dx * dx + dy * dy <= 1.0:
                r = int(SKIN_BASE[0] - abs(dy) * 10)
                g = int(SKIN_BASE[1] - abs(dy) * 5)
                b = int(SKIN_BASE[2] - abs(dy) * 3)
                a = SKIN_BASE[3]
                draw_pixel(img, x, y, (r, g, b, a))

def generate_face(expression, is_male=False):
    img = new_face()
    cx, cy = W // 2, H // 2

    # 1. Skin base
    draw_skin_base(img)

    # 2. Eyes
    eye_y = cy - 2
    has_blush = not is_male
    
    if expression == "happy":
        draw_eye(img, cx - 7, eye_y)
        draw_eye(img, cx + 7, eye_y)
        draw_mouth(img, cx, cy + 6, "happy")
        draw_blush(img, cx, cy + 3, has_blush)
    elif expression == "angry":
        draw_eye(img, cx - 7, eye_y, is_angry=True)
        draw_eye(img, cx + 7, eye_y, is_angry=True)
        draw_mouth(img, cx, cy + 6, "angry")
        draw_blush(img, cx, cy + 3, False)
    elif expression == "shy":
        draw_eye(img, cx - 7, eye_y, is_shy=True)
        draw_eye(img, cx + 7, eye_y, is_shy=True)
        draw_mouth(img, cx, cy + 6, "shy")
        draw_blush(img, cx, cy + 3, True)
    elif expression == "closed_eyes":
        draw_eye(img, cx - 7, eye_y, is_closed=True)
        draw_eye(img, cx + 7, eye_y, is_closed=True)
        draw_mouth(img, cx, cy + 6, "closed_eyes")
        draw_blush(img, cx, cy + 3, has_blush)
    else:  # blank
        draw_eye(img, cx - 7, eye_y)
        draw_eye(img, cx + 7, eye_y)
        draw_mouth(img, cx, cy + 6, "blank")
        draw_blush(img, cx, cy + 3, False)

    return img

# Generate all faces
EXPRESSIONS = ["happy", "angry", "shy", "closed_eyes", "blank"]
GENDERS = ["f", "m"]

print("=== Generating Enhanced Face Atlas ===\n")

atlas_w = len(EXPRESSIONS) * W
atlas_h = len(GENDERS) * H
atlas_img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
frames = {}

for row_idx, gender in enumerate(GENDERS):
    is_male = (gender == "m")
    x = 0
    for expr in EXPRESSIONS:
        img = generate_face(expr, is_male)
        fn = f"face_{expr}_{gender}.png"
        path = os.path.join(OUTPUT_DIR, fn)
        img.save(path)
        
        # Paste into atlas
        atlas_img.paste(img, (x, row_idx * H), img)
        frames[fn] = {"frame": {"x": x, "y": row_idx * H, "w": W, "h": H}}
        
        colors = len(set(img.getdata()))
        visible = sum(1 for c in img.getdata() if c[3] > 0)
        print(f"  [{expr}_{gender}] saved, colors={colors}, visible={visible}/{W*H}")
        
        x += W

# Save atlas
atlas_png = os.path.join(OUTPUT_DIR, "face.atlas.png")
atlas_img.save(atlas_png)
print(f"\n  Atlas: {atlas_png} ({atlas_w}x{atlas_h})")

atlas_json_path = os.path.join(OUTPUT_DIR, "face.atlas.json")
with open(atlas_json_path, "w", encoding="utf-8") as f:
    json.dump({"frames": frames}, f, indent=4, ensure_ascii=False)
print(f"  Atlas JSON: {atlas_json_path}")

# Frame definitions
cx, cy = W // 2, H // 2
for gender, suffix in [("f", "_f"), ("m", "_m")]:
    files = [f"face_{expr}_{gender}.png" for expr in EXPRESSIONS]
    face_def = {
        "NAME": f"test_face_{gender}",
        "STAND_R": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
        "STAND_U": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
        "STAND_L": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
        "STAND_D": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
        "R": {"IMG": files + [files[4]], "CX": [cx]*6, "CY": [cy]*6},
        "U": {"IMG": files + [files[4]], "CX": [cx]*6, "CY": [cy]*6},
        "L": {"IMG": files + [files[4]], "CX": [cx]*6, "CY": [cy]*6},
        "D": {"IMG": files + [files[4]], "CX": [cx]*6, "CY": [cy]*6},
    }
    def_path = os.path.join(OUTPUT_DIR, f"test_face_{gender}.json")
    with open(def_path, "w", encoding="utf-8") as f:
        json.dump(face_def, f, indent=4, ensure_ascii=False)
    print(f"  Frame def: {def_path}")

print("\nDone! All faces generated in", OUTPUT_DIR)
