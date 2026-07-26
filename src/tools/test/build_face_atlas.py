"""Build a unified face atlas from procedural face expressions.

Takes the 5 procedural face expressions and builds:
1. A unified atlas PNG (face_atlas.png) with all expressions in one row
2. A unified atlas JSON for the game engine
3. A stand/walk frame definition referencing the atlas
"""

import json, os
from PIL import Image

# The procedural faces were generated to assets/test/face/{name}/img/face_{name}.png
TEST_FACE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets/test/face"))
OUTPUT_DIR = os.path.join(TEST_FACE_DIR, "..")  # assets/test/
os.makedirs(OUTPUT_DIR, exist_ok=True)

EXPRESSIONS = ["happy", "angry", "shy", "closed_eyes", "blank"]
GENDERS = ["f", "m"]  # female and male variants

# We'll generate male faces by modifying the female face images slightly
# (e.g., narrower eyes, less blush, different mouth)

def modify_for_male(img):
    """Convert a female face to male by removing blush and making eyes narrower."""
    px = img.load()
    w, h = img.size
    out = img.copy()
    out_px = out.load()
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0:
                # Reduce blush (redness) by ~20%
                if r > g + 30 and r > b + 30:
                    # This is a reddish pixel (blush/mouth)
                    r = max(0, r - 20)
                    g = min(255, g + 10)
                out_px[x, y] = (r, g, b, a)
    return out

def build_combined_atlas():
    """Build a single atlas with all expressions for both genders."""
    all_frames = {}
    
    # Layout: row 0 = female, row 1 = male
    # Columns: 5 expressions
    frame_w, frame_h = 32, 32
    cols = len(EXPRESSIONS)
    rows = len(GENDERS)
    
    atlas_w = frame_w * cols
    atlas_h = frame_h * rows
    
    atlas_img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    
    x = 0
    for expr in EXPRESSIONS:
        src = os.path.join(TEST_FACE_DIR, expr, "img", f"face_{expr}.png")
        if not os.path.exists(src):
            print(f"  [SKIP] {src} not found")
            continue
        
        female_img = Image.open(src).convert("RGBA")
        male_img = modify_for_male(female_img)
        
        for row_idx, (gender, img) in enumerate(zip(GENDERS, [female_img, male_img])):
            px = x
            py = row_idx * frame_h
            atlas_img.paste(img, (px, py), img)
            
            fn = f"face_{expr}_{gender}.png"
            all_frames[fn] = {
                "frame": {
                    "x": px,
                    "y": py,
                    "w": frame_w,
                    "h": frame_h
                }
            }
        
        x += frame_w
    
    # Save atlas
    atlas_png = os.path.join(OUTPUT_DIR, "face_atlas.png")
    atlas_img.save(atlas_png)
    print(f"Atlas: {atlas_png} ({atlas_w}x{atlas_h})")
    
    # Save JSON
    atlas_json = {"frames": all_frames}
    atlas_json_path = os.path.join(OUTPUT_DIR, "face_atlas.json")
    with open(atlas_json_path, "w", encoding="utf-8") as f:
        json.dump(atlas_json, f, indent=4, ensure_ascii=False)
    print(f"JSON: {atlas_json_path}")
    
    return atlas_w, atlas_h

def build_frame_def(atlas_w, atlas_h):
    """Build a frame definition JSON for the game engine."""
    cx, cy = 16, 16  # center of 32x32 frame
    
    # Build expression sets
    female_files = [f"face_{expr}_f.png" for expr in EXPRESSIONS]
    male_files = [f"face_{expr}_m.png" for expr in EXPRESSIONS]
    
    # Each gender gets its own face definition
    for gender, files in [("f", female_files), ("m", male_files)]:
        face_def = {
            "NAME": f"test_face_{gender}",
            "STAND_R": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},  # blank as default
            "STAND_U": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
            "STAND_L": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
            "STAND_D": {"IMG": [files[4]], "CX": [cx], "CY": [cy]},
        }
        
        # Walk uses expression cycle
        # We'll cycle through expressions: blank -> happy -> angry -> shy -> closed_eyes -> blank
        cycle = [files[4], files[0], files[1], files[2], files[3], files[4]]
        
        for direction in ["R", "U", "L", "D"]:
            face_def[direction] = {
                "IMG": cycle,
                "CX": [cx] * 6,
                "CY": [cy] * 6,
            }
        
        def_path = os.path.join(OUTPUT_DIR, f"test_face_{gender}.json")
        with open(def_path, "w", encoding="utf-8") as f:
            json.dump(face_def, f, indent=4, ensure_ascii=False)
        print(f"Frame def: {def_path}")


if __name__ == "__main__":
    print("=== Building Unified Face Atlas ===\n")
    w, h = build_combined_atlas()
    build_frame_def(w, h)
    print("\nDone!")
