"""Procedural pixel art chibi character generator.

Generates layered character components (body, face, hair, outfit) as separate
RGBA PNGs for in-engine compositing. Chibi proportions with Ragnarok Online +
QQTang-inspired aesthetic.

Usage:
    python procedural_gen.py [all|body|face|hair|outfit|composite|sheet]
"""

import os
import sys
import math
from PIL import Image

# === Constants ===
W, H = 64, 64
OUT_DIR = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "../../../assets/test/procedural"
))

SKIN = (255, 215, 180, 255)
SKIN_S = (240, 200, 165, 255)
SKIN_D = (220, 180, 145, 255)
SKIN_HD = (190, 155, 125, 255)
EYE_W = (255, 255, 255, 255)
EYE_P = (40, 30, 20, 255)
EYE_H = (255, 255, 255, 255)
MOUTH = (210, 80, 80, 255)
MOUTH_S = (170, 55, 55, 255)
HAIR = (85, 55, 30, 255)
HAIR_L = (120, 85, 55, 255)
HAIR_D = (55, 35, 20, 255)
SHIRT = (100, 190, 255, 255)
SHIRT_S = (75, 155, 230, 255)
SHIRT_D = (55, 125, 200, 255)
PANTS = (75, 75, 115, 255)
PANTS_S = (55, 55, 90, 255)
PANTS_D = (40, 40, 70, 255)
SHOE = (55, 45, 35, 255)
SHOE_L = (75, 60, 45, 255)
OUTLINE = (35, 30, 25, 255)
BLUSH = (255, 180, 170, 255)


def new_canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _oval_mask(cx, cy, rx, ry):
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            if (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) <= 1.0:
                yield (cx + dx, cy + dy)


def fill_oval(img, cx, cy, rx, ry, color):
    px = img.load()
    for x, y in _oval_mask(cx, cy, rx, ry):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = color


def fill_rect(img, x1, y1, x2, y2, color):
    px = img.load()
    for y in range(max(0, y1), min(H, y2 + 1)):
        for x in range(max(0, x1), min(W, x2 + 1)):
            px[x, y] = color


def fill_trapezoid(img, x1_top, x2_top, y_top, x1_bot, x2_bot, y_bot, color):
    px = img.load()
    for y in range(max(0, y_top), min(H, y_bot + 1)):
        t = (y - y_top) / max(1, (y_bot - y_top))
        x1 = int(x1_top + (x1_bot - x1_top) * t + 0.5)
        x2 = int(x2_top + (x2_bot - x2_top) * t + 0.5)
        for x in range(max(0, x1), min(W, x2 + 1)):
            px[x, y] = color


def set_px(img, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.load()[x, y] = color


def hline(img, x1, x2, y, color):
    px = img.load()
    for x in range(max(0, x1), min(W, x2 + 1)):
        px[x, y] = color


def vline(img, x, y1, y2, color):
    px = img.load()
    for y in range(max(0, y1), min(H, y2 + 1)):
        px[x, y] = color


# ============================================================
# BODY MANNEQUIN
# ============================================================

def gen_body_mannequin():
    img = new_canvas()

    # --- Big round head (chibi style) ---
    fill_oval(img, 32, 20, 14, 15, SKIN)
    # Head bottom shading
    fill_oval(img, 32, 23, 13, 11, SKIN_S)

    # --- Neck ---
    fill_rect(img, 28, 34, 36, 36, SKIN)

    # --- Body (narrow tapered for chibi) ---
    fill_trapezoid(img, 24, 40, 36, 27, 37, 47, SKIN)
    # Body center highlight
    fill_rect(img, 28, 37, 36, 46, SKIN_S)

    # --- Arms (thin, slightly separated from body) ---
    fill_rect(img, 21, 36, 23, 46, SKIN)
    fill_rect(img, 41, 36, 43, 46, SKIN)
    # Arm inner shadow
    vline(img, 23, 36, 46, SKIN_S)
    vline(img, 41, 36, 46, SKIN_S)

    # --- Legs ---
    fill_rect(img, 26, 47, 30, 56, SKIN)
    fill_rect(img, 34, 47, 38, 56, SKIN)
    # Leg inner shadow
    fill_rect(img, 28, 47, 30, 56, SKIN_S)
    fill_rect(img, 34, 47, 36, 56, SKIN_S)

    # --- Feet (slightly wider than legs, with gap) ---
    fill_rect(img, 24, 56, 31, 60, SKIN_D)
    fill_rect(img, 33, 56, 40, 60, SKIN_D)
    hline(img, 25, 30, 60, SKIN_HD)
    hline(img, 34, 39, 60, SKIN_HD)

    # --- Subtle outline on head edge ---
    for x, y in _oval_mask(32, 20, 14, 15):
        if 0 <= x < W and 0 <= y < H:
            c = img.load()[x, y]
            if c == SKIN:
                dx, dy = x - 32, y - 20
                edge = (dx * dx) / (13 * 13) + (dy * dy) / (14 * 14)
                if edge > 0.90:
                    set_px(img, x, y, SKIN_HD)

    return img


# ============================================================
# FACES
# ============================================================

def gen_face_default():
    img = new_canvas()
    # --- Eyes (big round QQTang style) ---
    # Left eye
    fill_oval(img, 25, 22, 4, 5, EYE_W)
    fill_oval(img, 25, 23, 3, 3, EYE_P)
    set_px(img, 23, 20, EYE_H)
    # Right eye
    fill_oval(img, 39, 22, 4, 5, EYE_W)
    fill_oval(img, 39, 23, 3, 3, EYE_P)
    set_px(img, 37, 20, EYE_H)
    # --- Mouth (small cute smile) ---
    for dx in range(-3, 4):
        x = 32 + dx
        y = 30 + int(abs(dx) * 0.3)
        set_px(img, x, y, MOUTH)
    set_px(img, 32, 31, MOUTH_S)
    # --- Blush ---
    fill_oval(img, 20, 27, 4, 2, BLUSH)
    fill_oval(img, 44, 27, 4, 2, BLUSH)
    return img


def gen_face_happy():
    img = new_canvas()
    # --- Big happy eyes (curved up = ^ ^) ---
    for dx in range(-5, 6):
        x = 25 + dx
        y = 21 - int(abs(dx) * 0.6)
        set_px(img, x, y, OUTLINE)
    for dx in range(-5, 6):
        x = 39 + dx
        y = 21 - int(abs(dx) * 0.6)
        set_px(img, x, y, OUTLINE)
    # Eye shine below
    set_px(img, 25, 23, EYE_W)
    set_px(img, 39, 23, EYE_W)
    # --- Wide open smile ---
    for dx in range(-6, 7):
        x = 32 + dx
        y = 30 + int(abs(dx) * 0.3)
        set_px(img, x, y, MOUTH)
    fill_oval(img, 32, 31, 5, 3, MOUTH_S)
    hline(img, 28, 36, 30, EYE_W)
    # --- Blush ---
    fill_oval(img, 19, 27, 4, 3, BLUSH)
    fill_oval(img, 45, 27, 4, 3, BLUSH)
    return img


def gen_face_angry():
    img = new_canvas()
    # --- Angry eyebrows (angled inward) ---
    for dx in range(-7, 3):
        x = 25 + dx
        y = 17 - int(abs(dx + 2) * 0.4)
        set_px(img, x, y, OUTLINE)
    for dx in range(-2, 8):
        x = 40 + dx
        y = 17 + int(abs(dx - 3) * 0.4)
        set_px(img, x, y, OUTLINE)
    # --- Narrowed angry eyes ---
    fill_oval(img, 25, 22, 4, 3, EYE_W)
    fill_oval(img, 25, 22, 2, 2, EYE_P)
    fill_oval(img, 39, 22, 4, 3, EYE_W)
    fill_oval(img, 39, 22, 2, 2, EYE_P)
    # Squint lines under eyes
    hline(img, 22, 28, 24, SKIN_D)
    hline(img, 36, 42, 24, SKIN_D)
    # --- Frown ---
    for dx in range(-4, 5):
        x = 32 + dx
        y = 30 - int(abs(dx) * 0.4)
        set_px(img, x, y, MOUTH)
    set_px(img, 32, 29, MOUTH_S)
    return img


# ============================================================
# HAIR
# ============================================================

def gen_hair_default():
    img = new_canvas()

    # --- Hair dome (manually constructed, flat bottom to avoid eyes) ---
    # Top rows (y=2 to y=13): full width
    for y in range(2, 14):
        margin = max(0, int(8 - y * 0.4))
        for x in range(16 + margin, 48 - margin):
            set_px(img, x, y, HAIR)

    # Highlight arc (top)
    for y in range(3, 10):
        margin = max(0, int(10 - y * 0.7))
        for x in range(18 + margin, 46 - margin):
            set_px(img, x, y, HAIR_L)

    # Shading at hair bottom
    for y in range(12, 15):
        for x in range(19, 45):
            set_px(img, x, y, HAIR_D)

    # Left side strip (narrow, stops at y=20)
    fill_rect(img, 16, 13, 20, 20, HAIR)
    fill_rect(img, 17, 20, 20, 21, HAIR)
    # Right side strip
    fill_rect(img, 44, 13, 48, 20, HAIR)
    fill_rect(img, 44, 20, 47, 21, HAIR)

    # Side highlights
    vline(img, 18, 14, 20, HAIR_L)
    vline(img, 46, 14, 20, HAIR_L)
    vline(img, 20, 14, 20, HAIR_D)
    vline(img, 44, 14, 20, HAIR_D)

    # --- Bangs (thin strands stopping above eyes) ---
    # Left bang clump
    for x in range(27, 31):
        for y in range(14, 18):
            set_px(img, x, y, HAIR)
    for x in [28, 29]:
        set_px(img, x, 18, HAIR)
        set_px(img, x, 19, HAIR)
    set_px(img, 28, 20, HAIR)

    # Right bang clump
    for x in range(33, 37):
        for y in range(14, 18):
            set_px(img, x, y, HAIR)
    for x in [35, 36]:
        set_px(img, x, 18, HAIR)
        set_px(img, x, 19, HAIR)
    set_px(img, 36, 20, HAIR)

    # Center bang (shorter)
    for x in range(31, 33):
        for y in range(14, 17):
            set_px(img, x, y, HAIR)
    set_px(img, 31, 17, HAIR)
    set_px(img, 32, 17, HAIR)

    # Bang highlights
    for x in [28, 29, 34, 35]:
        set_px(img, x, 15, HAIR_L)
        set_px(img, x, 16, HAIR_L)

    # Bang strand lines
    for x in [30, 34]:
        set_px(img, x, 16, HAIR_D)
        set_px(img, x, 17, HAIR_D)

    return img


# ============================================================
# OUTFIT
# ============================================================

def gen_outfit_default():
    img = new_canvas()

    # --- T-Shirt (light blue, narrow chibi body) ---
    fill_trapezoid(img, 23, 41, 36, 26, 38, 47, SHIRT)
    # Shirt V-neck collar (reveals skin)
    fill_rect(img, 29, 36, 35, 38, SKIN)
    set_px(img, 29, 36, SHIRT_D)
    set_px(img, 35, 36, SHIRT_D)

    # Shirt shading (darker edges)
    for y in range(37, 47):
        t = (y - 36) / 11
        x1 = int(23 + 3 * t)
        x2 = int(41 - 3 * t)
        hline(img, x1, x1 + 1, y, SHIRT_S)
        hline(img, x2 - 1, x2, y, SHIRT_S)
        if y >= 45:
            hline(img, x1, x2, y, SHIRT_D)

    # Sleeves
    fill_rect(img, 23, 37, 24, 40, SHIRT_S)
    fill_rect(img, 40, 37, 41, 40, SHIRT_S)

    # --- Pants (dark blue shorts) ---
    fill_rect(img, 26, 46, 30, 56, PANTS)
    fill_rect(img, 34, 46, 38, 56, PANTS)
    # Waistband
    hline(img, 25, 39, 46, PANTS_D)
    hline(img, 26, 38, 47, PANTS_S)
    # Pants shading
    vline(img, 29, 47, 55, PANTS_S)
    vline(img, 35, 47, 55, PANTS_S)
    # Hem
    hline(img, 26, 30, 56, PANTS_D)
    hline(img, 34, 38, 56, PANTS_D)

    # --- Shoes (with gap between) ---
    fill_rect(img, 24, 56, 31, 60, SHOE)
    fill_rect(img, 33, 56, 40, 60, SHOE)
    hline(img, 25, 30, 59, SHOE_L)
    hline(img, 34, 39, 59, SHOE_L)
    hline(img, 25, 30, 60, SHOE_L)
    hline(img, 34, 39, 60, SHOE_L)

    return img


# ============================================================
# COMPOSITE
# ============================================================

def gen_composite():
    img = new_canvas()
    parts = [
        gen_body_mannequin(),
        gen_face_default(),
        gen_hair_default(),
        gen_outfit_default(),
    ]
    for part in parts:
        img.paste(part, (0, 0), part)
    return img


# ============================================================
# SPRITESHEET (4-frame walk cycle)
# ============================================================

def _walk_frame(leg_offset, arm_offset, face_func):
    img = new_canvas()
    body = gen_body_mannequin()

    # Clear body area so we can redraw with offsets
    # We'll rebuild from scratch with walk pose adjustments
    img.paste(body, (0, 0), body)

    # Override face
    face = face_func()
    img.paste(face, (0, 0), face)

    # Override hair
    hair = gen_hair_default()
    img.paste(hair, (0, 0), hair)

    # Override outfit adjusted for walk
    outfit = gen_outfit_default()
    img.paste(outfit, (0, 0), outfit)

    # Now apply walk animation by modifying colors directly
    # For a 32x32 pixel art style, we'll move leg/arm pixels
    px = img.load()

    leg_colors = {PANTS, PANTS_S, PANTS_D, SKIN, SKIN_S, SKIN_HD, SHOE, SHOE_L}

    for y in range(46, 62):
        for x in range(23, 42):
            c = px[x, y]
            if c in leg_colors:
                px[x, y] = (0, 0, 0, 0)

    lo = leg_offset
    fill_rect(img, 26 + lo, 47, 30 + lo, 56, PANTS)
    hline(img, 26 + lo, 30 + lo, 46, PANTS_D)
    vline(img, 29 + lo, 47, 55, PANTS_S)
    hline(img, 26 + lo, 30 + lo, 56, PANTS_D)
    fill_rect(img, 24 + lo, 56, 31 + lo, 60, SHOE)
    hline(img, 25 + lo, 30 + lo, 59, SHOE_L)
    hline(img, 25 + lo, 30 + lo, 60, SHOE_L)

    ro = leg_offset  # right leg moves opposite
    fill_rect(img, 34 - ro, 47, 38 - ro, 56, PANTS)
    hline(img, 34 - ro, 38 - ro, 46, PANTS_D)
    vline(img, 35 - ro, 47, 55, PANTS_S)
    hline(img, 34 - ro, 38 - ro, 56, PANTS_D)
    fill_rect(img, 33 - ro, 56, 40 - ro, 60, SHOE)
    hline(img, 34 - ro, 39 - ro, 59, SHOE_L)
    hline(img, 34 - ro, 39 - ro, 60, SHOE_L)

    for y in range(34, 50):
        for x in range(19, 25):
            c = px[x, y]
            if c in leg_colors:
                px[x, y] = (0, 0, 0, 0)
        for x in range(39, 45):
            c = px[x, y]
            if c in leg_colors:
                px[x, y] = (0, 0, 0, 0)

    la = arm_offset
    ra = -arm_offset
    fill_rect(img, 21 + la, 36, 23 + la, 46, SKIN)
    vline(img, 23 + la, 36, 46, SKIN_S)
    fill_rect(img, 41 + ra, 36, 43 + ra, 46, SKIN)
    vline(img, 41 + ra, 36, 46, SKIN_S)
    fill_rect(img, 22 + la, 37, 23 + la, 40, SHIRT_S)
    fill_rect(img, 41 + ra, 37, 42 + ra, 40, SHIRT_S)

    return img


def gen_walk_frame(frame_idx):
    """Generate a single walk cycle frame.
    
    Frame 0: standing (neutral)
    Frame 1: stride wide (legs spread + arms spread)
    Frame 2: standing (neutral)
    Frame 3: stride close (legs together + arms together)
    """
    offsets = [
        (0, 0),
        (-2, -2),
        (0, 0),
        (2, 2),
    ]
    if frame_idx >= len(offsets):
        frame_idx = 0
    leg_off, arm_off = offsets[frame_idx]
    return _walk_frame(leg_off, arm_off, gen_face_default)


def gen_spritesheet():
    sheet = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i in range(4):
        frame = gen_walk_frame(i)
        sheet.paste(frame, (i * W, 0), frame)
    return sheet


# ============================================================
# MAIN
# ============================================================

GENERATORS = {
    "body": ("body_mannequin.png", gen_body_mannequin),
    "face_default": ("face_default.png", gen_face_default),
    "face_happy": ("face_happy.png", gen_face_happy),
    "face_angry": ("face_angry.png", gen_face_angry),
    "hair_default": ("hair_default.png", gen_hair_default),
    "outfit_default": ("outfit_default.png", gen_outfit_default),
    "composite": ("bombo_composite.png", gen_composite),
    "sheet": ("bombo_spritesheet.png", gen_spritesheet),
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    args = sys.argv[1:] if len(sys.argv) > 1 else ["all"]
    targets = set()
    for arg in args:
        if arg == "all":
            targets.update(GENERATORS.keys())
        elif arg in GENERATORS:
            targets.add(arg)
        else:
            print(f"Unknown target: {arg}")
            print(f"Valid: all, {', '.join(GENERATORS.keys())}")
            return

    for key in sorted(targets, key=lambda k: list(GENERATORS.keys()).index(k)
                      if k in GENERATORS else 99):
        if key not in GENERATORS:
            continue
        fn, gen_func = GENERATORS[key]
        path = os.path.join(OUT_DIR, fn)
        print(f"Generating {fn}...")
        img = gen_func()
        img.save(path)
        print(f"  -> {path} ({img.size[0]}x{img.size[1]})")

    print(f"\nDone! Generated {len(targets)} file(s) in {OUT_DIR}")


if __name__ == "__main__":
    main()
