"""
ModelScope API 角色部件生成管线
Usage: python modelscope_gen.py [body|face|all|lora|lora2|lora_test]
"""
import urllib.request, json, time, os, sys

TOKEN = "ms-083d56a6-068b-47e5-ae1e-0114f35a2fa4"
BASE = "https://api-inference.modelscope.cn"
OUT_DIR = "D:/learn/bomboadvanture/assets/test"

MODEL = "Qwen/Qwen-Image-2512"
LORA = "prithivMLmods/Qwen-Image-2512-Pixel-Art-LoRA"
LORA_TURBO = "Wuli-Art/Qwen-Image-2512-Turbo-LoRA"

STYLE_ANCHOR = "Pixel Art, chibi pixel art, Ragnarok Online style, QQTang proportions big head small body, 16-bit RPG sprite, transparent background"

def generate(prompt, model=MODEL, size="1024x1024", n=1, loras=None):
    headers = {
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        "X-ModelScope-Async-Mode": "true",
    }
    body = {"model": model, "prompt": prompt, "n": n, "size": size}
    if loras:
        body["loras"] = loras

    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(f"{BASE}/v1/images/generations", data=data, headers=headers)
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=60).read())
    except urllib.error.HTTPError as e:
        print(f"  HTTP Error: {e.code} {e.reason}")
        print(f"  Response: {e.read().decode()}")
        return None
    task_id = resp.get("task_id")
    print(f"  Task: {task_id}")

    for _ in range(120):
        time.sleep(5)
        h = {"Authorization": f"Bearer {TOKEN}", "X-ModelScope-Task-Type": "image_generation"}
        r = urllib.request.Request(f"{BASE}/v1/tasks/{task_id}", headers=h)
        result = json.loads(urllib.request.urlopen(r, timeout=30).read())
        s = result.get("task_status", "")
        print(f"  Status: {s}")
        if s == "SUCCEED":
            return result.get("output_images", [])
        elif s == "FAILED":
            raise Exception(f"Failed: {result}")
    raise Exception("Timeout")

def download(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    urllib.request.urlretrieve(url, path)
    sz = os.path.getsize(path)
    print(f"  Saved: {path} ({sz} bytes)")
    # Try to convert to RGBA if it's not
    try:
        from PIL import Image
        img = Image.open(path)
        if img.mode == "RGB":
            rgba = img.convert("RGBA")
            rgba.save(path)
            print(f"  Converted to RGBA")
    except:
        pass

def gen_body():
    """Generate body mannequin"""
    print("\n=== Body Mannequin ===")
    prompt = (
        "Pixel Art, chibi pixel art character body mannequin, front facing, "
        "bald, naked, blank face no eyes no mouth, simple body, "
        f"{STYLE_ANCHOR}"
    )
    urls = generate(prompt, size="1024x1024")
    if urls:
        download(urls[0], f"{OUT_DIR}/body/body_mannequin_front.png")
    return urls

def gen_body_lora():
    """Test with Pixel Art LoRA (loras param)"""
    print("\n=== Body Mannequin (LoRA loras param) ===")
    prompt = (
        "Pixel Art, chibi pixel art character body mannequin, front facing, "
        "bald, naked, blank face no eyes no mouth, simple body, "
        "Ragnarok Online style, QQTang proportions, transparent background"
    )
    urls = generate(prompt, loras=LORA, size="1024x1024")
    if urls:
        download(urls[0], f"{OUT_DIR}/body/body_mannequin_front_lora.png")
    return urls

def test_lora_mechanism():
    """Test if loras parameter works with a known ModelScope LoRA"""
    print("\n=== Test LoRA mechanism (Wuli Turbo LoRA) ===")
    prompt = (
        "Pixel Art, chibi pixel art character body mannequin, front facing, "
        "bald, naked, blank face no eyes no mouth, simple body, "
        "Ragnarok Online style, QQTang proportions, transparent background"
    )
    urls = generate(prompt, loras=LORA_TURBO, size="1024x1024")
    if urls:
        download(urls[0], f"{OUT_DIR}/body/body_turbo_lora_test.png")
    return urls

def gen_face(emotion, desc):
    """Generate a face decoration with given emotion"""
    print(f"\n=== Face: {emotion} ===")
    prompt = (
        f"Pixel Art, chibi pixel art {desc} face close up, "
        f"transparent background, {STYLE_ANCHOR}"
    )
    urls = generate(prompt, size="1024x1024")
    if urls:
        download(urls[0], f"{OUT_DIR}/face/face_{emotion}.png")
    return urls

FACES = {
    "happy": "big cute eyes with white highlights, big smile, round face, happy",
    "angry": "furrowed eyebrows, angry eyes, frown mouth, cute tantrum, angry",
    "shy": "blushing cheeks, half-closed eyes, small wavy mouth, embarrassed, shy",
    "closed_eyes": "closed upward curved eyes, big smile, peaceful, closed eyes",
    "blank": "simple dot eyes, straight small mouth, calm, no expression, blank",
}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "body"

    if cmd == "body" or cmd == "all":
        gen_body()
    if cmd == "lora":
        gen_body_lora()
    if cmd == "lora_test":
        test_lora_mechanism()
    if cmd == "face" or cmd == "all":
        for emo, desc in FACES.items():
            gen_face(emo, desc)
    if cmd not in ("body", "face", "all", "lora", "lora_test"):
        print(f"Usage: {sys.argv[0]} [body|face|all|lora|lora_test]")
