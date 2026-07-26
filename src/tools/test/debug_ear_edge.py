"""
Check ear pixel alpha at extreme edges of original face10101_stand_3_0.png
"""
from PIL import Image

ROOT = "E:/WorkProject/Bomb adventure/BomboAdvanture"
SRC = f"{ROOT}/assets/img/face/face10101_stand_3_0.png"
img = Image.open(SRC).convert("RGBA")
px = img.load()
W, H = 36, 34  # original uncropped size

print("=== Edge alpha check (x=0, x=35, y=19-26) ===")
for y in range(19, 27):
    left = px[0, y]
    right = px[35, y]
    print(f"  y={y}: x=0 alpha={left[3]}, x=35 alpha={right[3]}")

print("\n=== Left edge (x=0-3) full color, y=19-26 ===")
for y in range(19, 27):
    colors = []
    for x in range(0, 4):
        c = px[x, y]
        colors.append(f"({c[0]},{c[1]},{c[2]},{c[3]})")
    print(f"  y={y}: {' | '.join(colors)}")

print("\n=== Right edge (x=32-35) full color, y=19-26 ===")
for y in range(19, 27):
    colors = []
    for x in range(32, 36):
        c = px[x, y]
        colors.append(f"({c[0]},{c[1]},{c[2]},{c[3]})")
    print(f"  y={y}: {' | '.join(colors)}")
