"""
PixelLab API 像素画角色部件生成管线
Usage: python pixellab_gen.py [body|face|all]
"""
import requests, json, time, os, sys, base64
from pathlib import Path

TOKEN = "d5edb741-8d0a-419a-95d6-4786d04b591f"
BASE = "https://api.pixellab.ai"
HEADERS = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
OUT_DIR = Path("D:/learn/bomboadvanture/assets/test")

def gen_pixflux(desc, w=64, h=64, nobg=True):
    body = {"description": desc, "image_size": {"width": w, "height": h}}
    if nobg:
        body["no_background"] = True
    r = requests.post(f"{BASE}/v2/create-image-pixflux", json=body, headers=HEADERS, timeout=60)
    r.raise_for_status()
    data = r.json()
    img_data = data.get("image", {})
    if "base64" in img_data:
        raw = base64.b64decode(img_data["base64"])
        return raw, img_data.get("format", "png")
    return None, None

def gen_pixen(desc, w=64, h=64):
    body = {"description": desc, "image_size": {"width": w, "height": h}}
    r = requests.post(f"{BASE}/v2/create-image-pixen", json=body, headers=HEADERS, timeout=60)
    r.raise_for_status()
    data = r.json()
    img_data = data.get("image", {})
    if "base64" in img_data:
        raw = base64.b64decode(img_data["base64"])
        return raw, img_data.get("format", "png")
    return None, None

def download(raw, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(raw)
    print(f"  Saved: {path} ({len(raw)} bytes)")

def gen_body():
    print("\n=== Body Mannequin (PixelLab Pixflux) ===")
    prompt = (
        "pixel art game character body mannequin base, front facing, "
        "bald head, no hair, no face features, blank expressionless face, "
        "naked simple body, no clothes, game character base template, "
        "small 64x64 sprite, transparent background"
    )
    raw, fmt = gen_pixflux(prompt, w=64, h=64)
    if raw:
        download(raw, f"{OUT_DIR}/body/pixellab_body_mannequin.png")

def gen_face(emotion, desc):
    print(f"\n=== Face: {emotion} (PixelLab Pixflux) ===")
    prompt = (
        f"pixel art {desc} face, game character face closeup, "
        f"small 64x64 sprite, transparent background"
    )
    raw, fmt = gen_pixflux(prompt, w=64, h=64)
    if raw:
        download(raw, f"{OUT_DIR}/face/pixellab_face_{emotion}.png")

FACES = {
    "happy": "big cute eyes with highlights, big smile, happy expression",
    "angry": "furrowed angry eyebrows, angry eyes, frown mouth",
    "shy": "blushing cheeks, half-closed eyes, embarrassed shy smile",
    "blank": "simple dot eyes, straight small mouth, no expression",
}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd in ("body", "all"):
        gen_body()
    if cmd in ("face", "all"):
        for emo, desc in FACES.items():
            gen_face(emo, desc)
    if cmd not in ("body", "face", "all"):
        print(f"Usage: {sys.argv[0]} [body|face|all]")
