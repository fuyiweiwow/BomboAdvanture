"""
Front face template v17: full 36x34 (crop_offset=[0,0]) to include outer ear pixels
"""
import json
from PIL import Image

ROOT = "E:/WorkProject/Bomb adventure/BomboAdvanture"
SRC = f"{ROOT}/assets/img/face/face10101_stand_3_0.png"
DST = f"{ROOT}/assets/train/face_annotations/front_region_template.json"

img = Image.open(SRC).convert("RGBA")
px = img.load()
crop_x = 0
W, H = 36, 34

# Load original face atlas for luminance check
atlas = Image.open(f"{ROOT}/assets/img/face/face.atlas.png").convert("RGBA")
with open(f"{ROOT}/assets/img/face/face.atlas.json") as f:
    data = json.load(f)
ref_key = next(fn for fn in data["frames"] if "face10101" in fn.lower() and "stand_3_0" in fn)
info = data["frames"][ref_key]
frame = info.get("frame", info)
ox, oy = frame["x"], frame["y"]
original = atlas.crop((ox + crop_x, oy, ox + crop_x + W, oy + H))
orig_px = original.load()

grid = [[0]*W for _ in range(H)]
for y in range(H):
    for x in range(W):
        ox2 = x + crop_x
        c = px[ox2, y]
        if c[3] >= 128:
            grid[y][x] = 4  # skin

def luminance(r, g, b):
    return 0.299*r + 0.587*g + 0.114*b

EYES = 2
EARS = 3

# === Ears — trim outermost 1px to avoid adjacent-frame bleeding ===
for y in range(19, 27):
    for x in range(1, 4):  # x=1,2,3 (skip x=0)
        if 0 <= x < W and grid[y][x] > 0:
            grid[y][x] = EARS
    for x in range(32, 35):  # x=32,33,34 (skip x=35)
        if 0 <= x < W and grid[y][x] > 0:
            grid[y][x] = EARS

# === Find dark eye+brow pixels by searching in broad areas ===
left_area = []
for y in range(20, 31):
    for x in range(5, 18):
        if grid[y][x] > 0:
            oc = orig_px[x, y]
            lum = luminance(*oc[:3])
            if lum < 100:
                left_area.append((x, y))

right_area = []
for y in range(20, 31):
    for x in range(19, 31):
        if grid[y][x] > 0:
            oc = orig_px[x, y]
            lum = luminance(*oc[:3])
            if lum < 100:
                right_area.append((x, y))

for x, y in left_area:
    grid[y][x] = EYES
for x, y in right_area:
    grid[y][x] = EYES

# Build
regions = {"skin": [], "eyes_brows": [], "ears": []}
for y in range(H):
    for x in range(W):
        if grid[y][x] == EYES:
            regions["eyes_brows"].append([x, y])
        elif grid[y][x] == EARS:
            regions["ears"].append([x, y])
        elif grid[y][x] == 4:
            regions["skin"].append([x, y])

for k in regions:
    regions[k].sort(key=lambda p: (p[1], p[0]))

template = {
    "name": "face10101_stand_3_0",
    "width": W, "height": H,
    "crop_offset": [0, 0],
    "pixels": regions,
    "count": {k: len(v) for k, v in regions.items()},
}

total = sum(template["count"].values())
print(f"Template (total {total}):")
for k, v in template["count"].items():
    print(f"  {k}: {v}")

chars = {0: '.', 2: 'E', 3: 'r', 4: 'S'}
print(f"\nRegion map ({W}x{H}):")
for y in range(H):
    print(f"{y:2d} {''.join(chars.get(grid[y][x], '?') for x in range(W))}")

# Sanity
ear_px = set(tuple(p) for p in regions["ears"])
eye_px = set(tuple(p) for p in regions["eyes_brows"])
touching = False
for ex, ey in eye_px:
    for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]:
        if (ex+dx, ey+dy) in ear_px:
            touching = True
            print(f"WARN: eyes & ears touch at ({ex},{ey}) <-> ({ex+dx},{ey+dy})")
if not touching:
    print("OK: eyes and ears separated")

with open(DST, "w") as f:
    json.dump(template, f, indent=2)
print(f"\nSaved: {DST}")
