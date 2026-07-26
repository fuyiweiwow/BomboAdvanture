"""Prepare RO face dataset for LoRA training.

Extracts all 112 face frames from atlas, upscales to 256x256,
creates captions, and saves in diffusers-compatible format.
"""

import os, json, random
from PIL import Image
from collections import defaultdict

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
FACE_DIR = os.path.join(ROOT, "assets", "img", "face")
OUT_DIR = os.path.join(ROOT, "assets", "train", "face_lora")
os.makedirs(OUT_DIR, exist_ok=True)

# Direction descriptions
DIR_MAP = {
    "0": "looking right",
    "1": "looking up",
    "2": "looking left",
    "3": "looking down",
}

ANIM_MAP = {
    "stand": "standing",
    "walk": "walking",
}

TRAIN_SIZE = 256

def main():
    atlas = Image.open(os.path.join(FACE_DIR, "face.atlas.png")).convert("RGBA")
    with open(os.path.join(FACE_DIR, "face.atlas.json")) as f:
        data = json.load(f)

    # Group frames by face ID
    face_groups = defaultdict(list)
    for fn, info in data["frames"].items():
        parts = fn.replace(".png", "").split("_")
        fid = parts[0].lower()
        key_parts = parts[1:]
        face_groups[fid].append((fn, info, key_parts))

    image_dir = os.path.join(OUT_DIR, "images")
    os.makedirs(image_dir, exist_ok=True)

    metadata = []

    for fid in sorted(face_groups):
        frames = face_groups[fid]
        for fn, info, key_parts in frames:
            frame = info.get("frame", info)
            x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
            img = atlas.crop((x, y, x + w, y + h))

            # Upscale to training size with NEAREST (preserve pixel art)
            img_big = img.resize((TRAIN_SIZE, TRAIN_SIZE), Image.NEAREST)

            # Save as PNG
            out_fn = f"{fid}_{'_'.join(key_parts)}.png"
            img_big.save(os.path.join(image_dir, out_fn))

            # Build caption
            anim_type = key_parts[0]
            dir_idx = key_parts[1] if len(key_parts) > 1 else "0"
            frame_idx = key_parts[2] if len(key_parts) > 2 else "0"

            direction = DIR_MAP.get(dir_idx, "looking right")
            animation = ANIM_MAP.get(anim_type, "standing")

            caption = f"pixel art chibi face, {animation}, {direction}, ro-face style"
            metadata.append({"file_name": out_fn, "text": caption})

    # Save metadata JSONL (diffusers format)
    with open(os.path.join(OUT_DIR, "metadata.jsonl"), "w") as f:
        for item in metadata:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")

    print(f"Dataset prepared: {OUT_DIR}")
    print(f"  Images: {len(metadata)}")
    print(f"  Sample captions:")
    for item in metadata[:5]:
        print(f"    {item['file_name']}: {item['text']}")

if __name__ == "__main__":
    main()
