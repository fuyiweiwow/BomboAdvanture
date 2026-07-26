"""Compare original vs generated faces and create a visual comparison."""

from PIL import Image
import os

GEN_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_pipeline\face"
SRC_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_components\face\img"
OUT_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_pipeline"

os.makedirs(OUT_DIR, exist_ok=True)

# === Color preservation check ===
print("=== Color Preservation ===")
gen_ids = sorted([d for d in os.listdir(GEN_DIR) if os.path.isdir(os.path.join(GEN_DIR, d))])

for fid in gen_ids:
    fdir = os.path.join(GEN_DIR, fid)
    found = [f for f in os.listdir(fdir) if f.endswith('.png') and 'stand_0_0' in f]
    if found:
        img = Image.open(os.path.join(fdir, found[0]))
        px = img.load()
        colors = set()
        for y in range(img.height):
            for x in range(img.width):
                c = px[x, y]
                if c[3] > 16:
                    colors.add((c[0], c[1], c[2]))
        print(f"  {fid}: {img.size}, {len(colors)} colors")

# === Visual comparison grid ===
# Row layout: [orig_10101] [gen_91001] [gen_91004] [gen_91007]
#              [orig_10201] [gen_91002] [gen_91005] [gen_91008]
#              [orig_10301] [gen_91003] [gen_91006] [-]

orig_map = {
    "face10101": ["face91001", "face91004", "face91007"],
    "face10201": ["face91002", "face91005", "face91008"],
    "face10301": ["face91003", "face91006"],
}

ROWS = 3
COLS = 4
CELL_W = 64
CELL_H = 64

grid = Image.new("RGBA", (COLS * CELL_W, ROWS * CELL_H), (64, 64, 64, 255))

for row_idx, (orig_id, gen_ids) in enumerate(orig_map.items()):
    # Find original stand_0_0
    orig_path = None
    for fname in os.listdir(SRC_DIR):
        if fname.startswith(orig_id) and "stand_0_0" in fname:
            orig_path = os.path.join(SRC_DIR, fname)
            break
    
    if orig_path:
        orig = Image.open(orig_path).convert("RGBA")
        x = 0
        y = row_idx * CELL_H
        ox = (CELL_W - orig.width) // 2
        oy = (CELL_H - orig.height) // 2
        grid.paste(orig, (x + ox, y + oy), orig)
    
    for col_idx, gid in enumerate(gen_ids):
        gdir = os.path.join(GEN_DIR, gid)
        found = [f for f in os.listdir(gdir) if f.endswith('.png') and 'stand_0_0' in f]
        if found:
            gen = Image.open(os.path.join(gdir, found[0])).convert("RGBA")
            x = (col_idx + 1) * CELL_W
            y = row_idx * CELL_H
            ox = (CELL_W - gen.width) // 2
            oy = (CELL_H - gen.height) // 2
            grid.paste(gen, (x + ox, y + oy), gen)

grid_path = os.path.join(OUT_DIR, "_comparison.png")
grid.save(grid_path)
print(f"\nComparison grid saved: {grid_path}")

# === Check a specific generated face ===
print("\n=== Sample pixel data (face91001 stand_0_0) ===")
sample = Image.open(os.path.join(GEN_DIR, "face91001", "face91001_stand_0_0.png"))
px = sample.load()
# Get unique colors sorted by luminance
colors = set()
for y in range(sample.height):
    for x in range(sample.width):
        c = px[x, y]
        if c[3] > 16:
            colors.add((c[0], c[1], c[2]))
sorted_colors = sorted(colors, key=lambda c: 0.299*c[0] + 0.587*c[1] + 0.114*c[2])
for i, c in enumerate(sorted_colors[:12]):
    print(f"  {i}: rgb({c[0]:3d},{c[1]:3d},{c[2]:3d})")
if len(sorted_colors) > 12:
    print(f"  ... ({len(sorted_colors)} total)")
