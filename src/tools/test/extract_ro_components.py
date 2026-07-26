"""Extract individual frames from RO sprite atlases for analysis and reuse."""

import os, json, shutil
from PIL import Image

IMG_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\img"
OUT_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_components"
os.makedirs(OUT_DIR, exist_ok=True)

def extract_atlas_frames(atlas_png, atlas_json, component_name):
    """Extract all frames from an atlas to individual PNGs."""
    atlas = Image.open(atlas_png).convert("RGBA")
    with open(atlas_json) as f:
        data = json.load(f)
    
    frames = data.get("frames", {})
    comp_dir = os.path.join(OUT_DIR, component_name, "img")
    os.makedirs(comp_dir, exist_ok=True)
    
    extracted = []
    for fn, info in frames.items():
        frame = info.get("frame", info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        sprite = atlas.crop((x, y, x+w, y+h))
        
        # Get just the base name (e.g., "face10101_stand_0_0.png")
        base = os.path.basename(fn)
        sprite.save(os.path.join(comp_dir, base))
        
        # Extract just the shape (for single-color components)
        px = sprite.load()
        colors = set()
        for sy in range(h):
            for sx in range(w):
                c = px[sx, sy]
                if c[3] > 0:
                    colors.add((c[0], c[1], c[2]))
        
        extracted.append({
            "file": base,
            "size": f"{w}x{h}",
            "colors": len(colors),
        })
    
    return extracted

def extract_faces_with_frames():
    """Extract face frames and their frame definition data."""
    # face is in individual files + atlas
    atlas = Image.open(os.path.join(IMG_DIR, "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(IMG_DIR, "face", "face.atlas.json")) as f:
        data = json.load(f)
    
    frames = data.get("frames", {})
    face_dir = os.path.join(OUT_DIR, "face", "img")
    os.makedirs(face_dir, exist_ok=True)
    
    for fn, info in frames.items():
        frame = info.get("frame", info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        sprite = atlas.crop((x, y, x+w, y+h))
        sprite.save(os.path.join(face_dir, fn))


print("=== Extracting RO Component Frames ===\n")

# Extract all component types
components = [
    ("face", "face/face.atlas.png", "face/face.atlas.json"),
    ("eye", "eye/eye.atlas.png", "eye/eye.atlas.json"),
    ("eye_eyeball", "eye_eyeball/eye_eyeball.atlas.png", "eye_eyeball/eye_eyeball.atlas.json"),
    ("eye_iris", "eye_iris/eye_iris.atlas.png", "eye_iris/eye_iris.atlas.json"),
    ("eye_pupil", "eye_pupil/eye_pupil.atlas.png", "eye_pupil/eye_pupil.atlas.json"),
    ("eye_highlight", "eye_highlight/eye_highlight.atlas.png", "eye_highlight/eye_highlight.atlas.json"),
    ("mouth", "mouth/mouth.atlas.png", "mouth/mouth.atlas.json"),
]

for name, png_rel, json_rel in components:
    png = os.path.join(IMG_DIR, png_rel)
    js = os.path.join(IMG_DIR, json_rel)
    if os.path.exists(png) and os.path.exists(js):
        extracted = extract_atlas_frames(png, js, name)
        print(f"  {name}: {len(extracted)} frames extracted")

# Also copy frame definition JSONs
frame_dir = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\frame\face"
for f in os.listdir(frame_dir):
    if f.endswith(".json"):
        shutil.copy2(os.path.join(frame_dir, f), os.path.join(OUT_DIR, "face", f))

print(f"\nAll files extracted to: {OUT_DIR}")
print(f"\nComponent structure:")
for root, dirs, files in os.walk(OUT_DIR):
    level = root.replace(OUT_DIR, "").count(os.sep)
    indent = "  " * level
    print(f"{indent}{os.path.basename(root)}/")
    if level < 3:
        for f in sorted(files)[:3]:
            print(f"{indent}  {f}")
        if len(files) > 3:
            print(f"{indent}  ... ({len(files)} files total)")
