"""
Debug: check pixel luminance in eyes_brows area of original face
"""
import json
from PIL import Image

ROOT = "E:/WorkProject/Bomb adventure/BomboAdvanture"
with open(f"{ROOT}/assets/train/face_annotations/front_region_template.json") as f:
    tmpl = json.load(f)
atlas = Image.open(f"{ROOT}/assets/img/face/face.atlas.png").convert("RGBA")
with open(f"{ROOT}/assets/img/face/face.atlas.json") as f:
    data = json.load(f)
ref_key = next(fn for fn in data["frames"] if "face10101" in fn.lower() and "stand_3_0" in fn)
info = data["frames"][ref_key]
frame = info.get("frame", info)
ox, oy = frame["x"], frame["y"]
offset_x, offset_y = tmpl.get("crop_offset", [0, 0])
w, h = tmpl["width"], tmpl["height"]
original = atlas.crop((ox + offset_x, oy + offset_y, ox + offset_x + w, oy + offset_y + h))
orig_px = original.load()

# Check all eye_brow pixel luminances
eye_pixels = tmpl["pixels"]["eyes_brows"]
lums = {}
for x, y in eye_pixels:
    c = orig_px[x, y]
    lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
    key = f"lum_{int(lum//10)}"
    lums.setdefault(key, []).append((x, y, int(lum), c[:3]))

print("=== Eyes_brows pixel luminance distribution ===")
for k in sorted(lums.keys()):
    pts = lums[k]
    print(f"  {k}: {len(pts)} pixels")
    # show a few examples
    for x, y, lum, rgb in pts[:3]:
        print(f"    ({x},{y}) lum={lum} rgb={rgb}")

dark = sum(1 for p in eye_pixels if 0.299*orig_px[p[0],p[1]][0] + 0.587*orig_px[p[0],p[1]][1] + 0.114*orig_px[p[0],p[1]][2] < 100)
bright = len(eye_pixels) - dark
print(f"\nTotal eyes_brows pixels: {len(eye_pixels)}")
print(f"  Dark (lum<100): {dark}")
print(f"  Bright (lum>=100): {bright}")
print(f"  Ratio: {dark/len(eye_pixels)*100:.0f}% dark")

# Also check ears
ear_pixels = tmpl["pixels"]["ears"]
print(f"\n=== Ears pixel luminance ===")
ear_lums = {}
for x, y in ear_pixels:
    c = orig_px[x, y]
    lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
    key = f"lum_{int(lum//10)}"
    ear_lums.setdefault(key, []).append((x, y, int(lum), c[:3]))
for k in sorted(ear_lums.keys()):
    pts = ear_lums[k]
    print(f"  {k}: {len(pts)} pixels")
