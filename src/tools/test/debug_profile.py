"""
Analyze stand_0_0 (profile face) — dimensions, face contour, dark pixels
"""
import json
from PIL import Image

ROOT = "E:/WorkProject/Bomb adventure/BomboAdvanture"

# Load from atlas
atlas = Image.open(f"{ROOT}/assets/img/face/face.atlas.png").convert("RGBA")
with open(f"{ROOT}/assets/img/face/face.atlas.json") as f:
    data = json.load(f)

# Find stand_0_0 frame
ref_key = next(fn for fn in data["frames"] if "face10101" in fn.lower() and "stand_0_0" in fn)
info = data["frames"][ref_key]
frame = info.get("frame", info)
ox, oy = frame["x"], frame["y"]
w, h = frame["w"], frame["h"]
print(f"stand_0_0 frame: ({ox},{oy}) {w}x{h}")

# Also check source standalone PNG
SRC = f"{ROOT}/assets/img/face/face10101_stand_0_0.png"
img = Image.open(SRC).convert("RGBA")
px = img.load()
print(f"Source: {img.size}")

# Face contour (alpha >= 128)
W, H = img.size
print(f"\n=== Face contour (alpha >= 128) ===")
last_L, last_R = -1, -1
for y in range(H):
    L = next((x for x in range(W) if px[x, y][3] >= 128), None)
    R = next((x for x in range(W-1, -1, -1) if px[x, y][3] >= 128), None)
    if L is not None and R is not None and (L != last_L or R != last_R):
        print(f"y={y}: L={L}, R={R}, width={R-L+1}")
        last_L, last_R = L, R

# Find dark pixels (lum < 100) that are within face
print(f"\n=== Dark pixels (lum < 100) per row y=15-33 ===")
for y in range(15, min(34, H)):
    dark = []
    for x in range(W):
        c = px[x, y]
        if c[3] >= 128:
            lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
            if lum < 100:
                dark.append(x)
    if dark:
        ranges = []
        start = dark[0]
        end = dark[0]
        for x in dark[1:]:
            if x == end + 1:
                end = x
            else:
                ranges.append(f"{start}-{end}")
                start = end = x
        ranges.append(f"{start}-{end}")
        print(f"  y={y}: {', '.join(ranges)} ({len(dark)}px)")

# Check edge columns alpha (ears)
print(f"\n=== Edge alpha check (y=15-33) ===")
for y in range(15, min(34, H)):
    left = px[0, y][3] if 0 < W else 0
    right = px[W-1, y][3] if W-1 >= 0 else 0
    if left > 0 or right > 0:
        print(f"  y={y}: x=0 alpha={left}, x={W-1} alpha={right}")
