"""Check the generated face output."""
import os, json
from PIL import Image

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
DIR = os.path.join(ROOT, "assets", "test", "ro_component", "face", "face95001")

atlas = Image.open(os.path.join(DIR, "face95001.atlas.png"))
with open(os.path.join(DIR, "face95001.atlas.json")) as f:
    data = json.load(f)

print(f"Atlas: {atlas.size}")
print(f"Frames: {len(data['frames'])}")

keys = set()
for fn in data["frames"]:
    key = "_".join(fn.replace(".png", "").split("_")[1:])
    keys.add(key)

expected = set()
for d in range(4):
    expected.add(f"stand_{d}_0")
    for w in range(6):
        expected.add(f"walk_{d}_{w}")

missing = expected - keys
extra = keys - expected
print(f"Expected: {len(expected)}, Missing: {len(missing)}")
if missing:
    for m in sorted(missing):
        print(f"  MISSING: {m}")

p = atlas.load()
total_colors = 0
for fn, info in data["frames"].items():
    frame = info["frame"]
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    colors = set()
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            c = p[xx, yy]
            if c[3] > 16:
                colors.add((c[0], c[1], c[2]))
    total_colors += len(colors)

print(f"Total unique colors across all frames: {total_colors}")
print(f"Avg per frame: {total_colors / len(data['frames']):.1f}")
