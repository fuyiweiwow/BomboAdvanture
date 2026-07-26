"""Final summary of RO AI pipeline results."""
from PIL import Image
import os

GEN_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_ai_generated"
OUT_DIR = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_ai_generated"

print("=" * 60)
print("RO AI PIPELINE - FINAL RESULTS")
print("=" * 60)

# Check each generated face
for fid in ["face92001", "face92002", "face92003"]:
    fdir = os.path.join(GEN_DIR, "face", fid)
    if not os.path.isdir(fdir):
        continue
    
    # AI reference
    ref_file = os.path.join(fdir, f"{fid}_ai_ref.png")
    ref = Image.open(ref_file)
    px = ref.load()
    ref_colors = set()
    for y in range(ref.height):
        for x in range(ref.width):
            c = px[x, y]
            if c[3] > 16:
                ref_colors.add((c[0], c[1], c[2]))
    
    # Stand frame
    stand_file = os.path.join(fdir, f"{fid}_stand_0_0.png")
    stand = Image.open(stand_file)
    px = stand.load()
    st_colors = set()
    for y in range(stand.height):
        for x in range(stand.width):
            c = px[x, y]
            if c[3] > 16:
                st_colors.add((c[0], c[1], c[2]))
    
    # Atlas
    atlas_file = os.path.join(fdir, f"{fid}.atlas.png")
    atlas = Image.open(atlas_file)
    
    # Frame count
    png_count = len([f for f in os.listdir(fdir) if f.endswith(".png") and "atlas" not in f and "ai_ref" not in f])
    
    print(f"\n{fid}:")
    print(f"  AI ref:    {ref.size[0]}x{ref.size[1]}, {len(ref_colors)} colors")
    print(f"  Stand:     {stand.size[0]}x{stand.size[1]}, {len(st_colors)} colors")
    print(f"  Atlas:     {atlas.size[0]}x{atlas.size[1]}")
    print(f"  Frames:    {png_count}")

# Create visual comparison strip
print("\n--- Creating visual comparison ---")

# Source comparison frames (original RO stand_0_0)
SRC = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_components\face\img"

# Layout: 3 rows (one per character), 4 cols
# [orig_10101] [gen_92001] [orig_10201] [gen_92002]
# [orig_10301] [gen_92003] ... etc
# Actually let's make it simpler:
# Row: [orig_name] [ai_gen_ref] [gen_stand] 
ROWS = 3
COLS = 4
CELL_W = 64
CELL_H = 64

grid = Image.new("RGBA", (COLS * CELL_W, ROWS * CELL_H), (64, 64, 64, 255))

# Original -> generated mapping
mapping = [
    ("face10101", "face92001", "blonde"),
    ("face10201", "face92002", "red"),
    ("face10301", "face92003", "blue"),
]

for row, (orig_id, gen_id, hair) in enumerate(mapping):
    # Col 0: Label (color bar)
    y = row * CELL_H
    
    # Col 1: Original stand frame
    orig_files = [f for f in os.listdir(SRC) if f.startswith(orig_id) and "stand_0_0" in f]
    if orig_files:
        orig = Image.open(os.path.join(SRC, orig_files[0])).convert("RGBA")
        ox = (CELL_W - orig.width) // 2
        oy = (CELL_H - orig.height) // 2
        grid.paste(orig, (1 * CELL_W + ox, y + oy), orig)
    
    # Col 2: AI reference
    gen_dir = os.path.join(GEN_DIR, "face", gen_id)
    ref_file = os.path.join(gen_dir, f"{gen_id}_ai_ref.png")
    if os.path.exists(ref_file):
        ref = Image.open(ref_file).convert("RGBA")
        ox = (CELL_W - ref.width) // 2
        oy = (CELL_H - ref.height) // 2
        # Upscale for visibility
        ref_large = ref.resize((CELL_W - 8, CELL_H - 8), Image.NEAREST)
        grid.paste(ref_large, (2 * CELL_W + 4, y + 4), ref_large)
    
    # Col 3: Generated stand frame
    stand_file = os.path.join(gen_dir, f"{gen_id}_stand_0_0.png")
    if os.path.exists(stand_file):
        gen_stand = Image.open(stand_file).convert("RGBA")
        gen_large = gen_stand.resize((CELL_W - 8, CELL_H - 8), Image.NEAREST)
        grid.paste(gen_large, (3 * CELL_W + 4, y + 4), gen_large)

grid_path = os.path.join(OUT_DIR, "_comparison.png")
grid.save(grid_path)
print(f"Comparison grid: {grid_path}")

print("\n" + "=" * 60)
print("PIPELINE FILES")
print("=" * 60)
print(f"  Script:        src/tools/test/ro_ai_gen.py")
print(f"  Generated:     assets/test/ro_ai_generated/face/")
print(f"  Each face:     28 frames + atlas.png + atlas.json + frame.json + ai_ref.png")
print("\nUsage:")
print("  python ro_ai_gen.py test         # Generate face92001 (blonde)")
print("  python ro_ai_gen.py test2        # Generate face92002 (red)")
print("  python ro_ai_gen.py test3        # Generate face92003 (blue)")
print("  python ro_ai_gen.py custom <prompt> <face_id> <hair> <skin>")
