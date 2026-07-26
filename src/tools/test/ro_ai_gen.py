"""RO Sprite AI Generator - ComfyUI integration

Generates new RO-style face components using AI img2img.
Pipeline: reference image → AI generate → palette extraction → hue-shift all frames → package atlas
"""

import os, sys, json, time, uuid, requests, base64, io
from PIL import Image
from collections import defaultdict

# === Config ===
COMFY_UI = "http://127.0.0.1:8188"
ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
SRC = os.path.join(ROOT, "assets", "img")
OUT = os.path.join(ROOT, "assets", "test", "ro_ai_generated")
os.makedirs(OUT, exist_ok=True)

# ComfyUI temp directory for input images
COMFY_INPUT = r"E:\env\ComfyUI\input"
COMFY_OUTPUT = r"E:\env\ComfyUI\output"

CHECKPOINT = "pixelArtSpriteDiffusion_safetensors.safetensors"

# Known palettes for RO-style faces (luminance-sorted, ~60 colors from original sprites)
# These are extracted from actual RO face sprites
RO_SKIN_PALETTE = [
    (100, 64, 40), (120, 76, 48), (140, 92, 60), (160, 108, 72),
    (180, 128, 88), (196, 148, 104), (212, 168, 124), (224, 188, 144),
    (236, 208, 164), (244, 220, 184), (252, 232, 204), (255, 244, 224),
]
RO_HAIR_PALETTE = [
    (24, 20, 28), (40, 32, 44), (60, 48, 64), (84, 68, 88),
    (108, 88, 108), (132, 112, 128), (160, 140, 152), (188, 172, 180),
    (212, 200, 208), (236, 228, 236),
]


def rgb_to_hsl(r, g, b):
    r, g, b = r/255.0, g/255.0, b/255.0
    mx, mn = max(r, g, b), min(r, g, b)
    h = s = l = (mx + mn) / 2.0
    if mx == mn: h = s = 0.0
    else:
        d = mx - mn
        s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn)
        if mx == r: h = ((g - b) / d + (6 if g < b else 0)) / 6.0
        elif mx == g: h = ((b - r) / d + 2) / 6.0
        else: h = ((r - g) / d + 4) / 6.0
    return h, s, l

def hsl_to_rgb(h, s, l):
    if s == 0: return int(l*255), int(l*255), int(l*255)
    def hue2rgb(p, q, t):
        if t < 0: t += 1
        if t > 1: t -= 1
        if t < 1/6: return p + (q - p) * 6 * t
        if t < 1/2: return q
        if t < 2/3: return p + (q - p) * (2/3 - t) * 6
        return p
    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q
    return int(hue2rgb(p, q, h + 1/3)*255), int(hue2rgb(p, q, h)*255), int(hue2rgb(p, q, h - 1/3)*255)


# ============================================================
# ComfyUI API helper
# ============================================================

class ComfyClient:
    """Simple client for ComfyUI API."""
    
    def __init__(self, base_url=COMFY_UI):
        self.base = base_url
        self.client_id = str(uuid.uuid4())
    
    def queue_prompt(self, workflow):
        """Send a workflow to ComfyUI and return prompt_id."""
        payload = {
            "prompt": workflow,
            "client_id": self.client_id,
        }
        resp = requests.post(f"{self.base}/prompt", json=payload)
        resp.raise_for_status()
        data = resp.json()
        return data.get("prompt_id")
    
    def get_history(self, prompt_id, max_wait=120):
        """Poll for results until the prompt completes."""
        start = time.time()
        while time.time() - start < max_wait:
            resp = requests.get(f"{self.base}/history/{prompt_id}")
            if resp.status_code == 200:
                data = resp.json()
                if prompt_id in data:
                    return data[prompt_id]
            time.sleep(1)
        raise TimeoutError(f"Prompt {prompt_id} did not complete in {max_wait}s")
    
    def get_image(self, filename, subfolder="", folder_type="output"):
        """Get a generated image by filename."""
        params = {
            "filename": filename,
            "subfolder": subfolder,
            "type": folder_type,
        }
        resp = requests.get(f"{self.base}/view", params=params)
        resp.raise_for_status()
        return resp.content
    
    def upload_image(self, image_path, name=None, subfolder=""):
        """Upload a reference image to ComfyUI input directory."""
        if name is None:
            name = os.path.basename(image_path)
        
        # Direct copy to ComfyUI input folder for reliability
        import shutil
        dst = os.path.join(COMFY_INPUT, subfolder, name)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(image_path, dst)
        return name


# ============================================================
# ComfyUI Workflow Builder
# ============================================================

def build_img2img_workflow(
    reference_image,
    checkpoint=CHECKPOINT,
    prompt="pixel art ro sprite face, male character, short hair, game sprite, 32x32",
    negative_prompt="bad anatomy, ugly, deformed, blurry, low quality, realistic, photo",
    denoise=0.65,
    steps=30,
    cfg=5.0,
    width=256,
    height=256,
    seed=-1,
):
    """Build a ComfyUI img2img workflow.
    
    Returns: (workflow_dict, output_node_id)
    """
    # Node IDs as strings
    n = {}
    
    n["load_checkpoint"] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
            "ckpt_name": checkpoint,
        },
    }
    
    n["load_image"] = {
        "class_type": "LoadImage",
        "inputs": {
            "image": reference_image,
        },
    }
    
    n["vae_encode"] = {
        "class_type": "VAEEncode",
        "inputs": {
            "pixels": ["load_image", 0],
            "vae": ["load_checkpoint", 2],
        },
    }
    
    n["clip_text_encode_pos"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": prompt,
            "clip": ["load_checkpoint", 1],
        },
    }
    
    n["clip_text_encode_neg"] = {
        "class_type": "CLIPTextEncode",
        "inputs": {
            "text": negative_prompt,
            "clip": ["load_checkpoint", 1],
        },
    }
    
    n["empty_latent"] = {
        "class_type": "EmptyLatentImage",
        "inputs": {
            "width": width,
            "height": height,
            "batch_size": 1,
        },
    }
    
    actual_seed = seed if seed >= 0 else int(time.time() * 1000) % (2**32)
    n["ksampler"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": actual_seed,
            "control_after_generate": "fixed",
            "steps": steps,
            "cfg": cfg,
            "sampler_name": "euler",
            "scheduler": "normal",
            "denoise": denoise,
            "model": ["load_checkpoint", 0],
            "positive": ["clip_text_encode_pos", 0],
            "negative": ["clip_text_encode_neg", 0],
            "latent_image": ["vae_encode", 0],
        },
    }
    
    n["vae_decode"] = {
        "class_type": "VAEDecode",
        "inputs": {
            "samples": ["ksampler", 0],
            "vae": ["load_checkpoint", 2],
        },
    }
    
    # Use SaveImage to save to output folder (easier to retrieve)
    save_node_id = "save_image"
    n[save_node_id] = {
        "class_type": "SaveImage",
        "inputs": {
            "images": ["vae_decode", 0],
            "filename_prefix": "ro_gen_",
        },
    }
    
    return n, save_node_id


# ============================================================
# Image Post-Processing
# ============================================================

def remove_background(img, border=16):
    """Remove background from AI-generated image.
    
    Detects background by sampling edges, then removes matching pixels.
    """
    px = img.load()
    w, h = img.size
    
    # Sample background from border region
    bg_samples = []
    for y in range(min(border, h)):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                bg_samples.append((c[0], c[1], c[2]))
    for y in range(max(0, h-border), h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                bg_samples.append((c[0], c[1], c[2]))
    for x in range(min(border, w)):
        for y in range(border, h-border):
            c = px[x, y]
            if c[3] > 16:
                bg_samples.append((c[0], c[1], c[2]))
    for x in range(max(0, w-border), w):
        for y in range(border, h-border):
            c = px[x, y]
            if c[3] > 16:
                bg_samples.append((c[0], c[1], c[2]))
    
    if not bg_samples:
        return img
    
    # Compute average background color
    bg_avg = (
        sum(c[0] for c in bg_samples) // len(bg_samples),
        sum(c[1] for c in bg_samples) // len(bg_samples),
        sum(c[2] for c in bg_samples) // len(bg_samples),
    )
    
    # Compute threshold as standard deviation of bg samples
    import math
    variance = sum(
        (c[0]-bg_avg[0])**2 + (c[1]-bg_avg[1])**2 + (c[2]-bg_avg[2])**2
        for c in bg_samples
    ) / len(bg_samples)
    threshold = math.sqrt(variance) * 2.5  # 2.5 sigma
    
    # Remove background
    new_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    new_px = new_img.load()
    
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 16:
                continue
            dist = math.sqrt(
                (c[0]-bg_avg[0])**2 + (c[1]-bg_avg[1])**2 + (c[2]-bg_avg[2])**2
            )
            if dist <= threshold:
                new_px[x, y] = (0, 0, 0, 0)  # transparent
            else:
                new_px[x, y] = c
    
    return new_img


def postprocess_to_pixel(img, target_size=(32, 33)):
    """Convert generated image to pixel art style.
    
    Pipeline:
    1. Remove background using edge color detection
    2. LANCZOS downscale to 2x target (preserves structure)
    3. Palette quantization
    4. NEAREST downscale to final target (crisp pixels)
    """
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    
    # Step 1: Remove background
    img_clean = remove_background(img)
    
    # Step 2: Smooth downscale to 2x target
    double_size = (target_size[0] * 2, target_size[1] * 2)
    img_2x = img_clean.resize(double_size, Image.LANCZOS)
    
    # Step 3: Quantize at 2x size
    img_quant = quantize_palette(img_2x, max_colors=48)
    
    # Step 4: NEAREST downscale to final target
    pixel_img = img_quant.resize(target_size, Image.NEAREST)
    
    return pixel_img


def quantize_palette(img, max_colors=48):
    """Quantize image to limited palette while preserving alpha.
    
    Uses median-cut style luminance binning for better color distribution.
    """
    px = img.load()
    w, h = img.size
    
    # Collect all visible colors
    colors = []
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                colors.append((c[0], c[1], c[2]))
    
    if not colors:
        return img
    
    unique = list(set(colors))
    if len(unique) <= max_colors:
        return img
    
    # Sort by luminance for balanced binning
    colors_with_lum = [(c, 0.299*c[0] + 0.587*c[1] + 0.114*c[2]) for c in unique]
    colors_with_lum.sort(key=lambda x: x[1])
    
    n_bins = min(max_colors, len(unique))
    bin_size = len(colors_with_lum) / n_bins
    
    palette_map = {}
    for i in range(n_bins):
        start = int(i * bin_size)
        end = int((i + 1) * bin_size)
        bin_colors = [c[0] for c in colors_with_lum[start:end]]
        if not bin_colors:
            continue
        
        avg_r = sum(c[0] for c in bin_colors) // len(bin_colors)
        avg_g = sum(c[1] for c in bin_colors) // len(bin_colors)
        avg_b = sum(c[2] for c in bin_colors) // len(bin_colors)
        avg = (avg_r, avg_g, avg_b)
        
        for c in bin_colors:
            palette_map[c] = avg
    
    new_img = Image.new("RGBA", (w, h))
    new_px = new_img.load()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                key = (c[0], c[1], c[2])
                nc = palette_map.get(key, key)
                new_px[x, y] = (nc[0], nc[1], nc[2], c[3])
            else:
                new_px[x, y] = c
    
    return new_img


def extract_palette_from_face(img):
    """Extract skin and hair color clusters from a generated face image."""
    px = img.load()
    w, h = img.size
    # Collect all colors with positions
    color_positions = defaultdict(list)
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                color_positions[(c[0], c[1], c[2])].append((x, y))
    
    # Classify by luminance-based position
    colors = list(color_positions.keys())
    lum_colors = [(c, 0.299*c[0] + 0.587*c[1] + 0.114*c[2]) for c in colors]
    lum_colors.sort(key=lambda x: x[1])
    
    # Rough split: darker = hair, middle = skin
    total = len(lum_colors)
    hair = [c for c, l in lum_colors[:total//3]]
    skin = [c for c, l in lum_colors[total//3:]]
    
    # Further refine: skin should be in the middle/bottom of the image
    skin_clean = []
    for c in skin:
        avg_y = sum(p[1] for p in color_positions[c]) / max(len(color_positions[c]), 1)
        if avg_y > h * 0.3:  # skin is mostly in the bottom 70%
            skin_clean.append(c)
    
    hair_clean = []
    for c in hair:
        avg_y = sum(p[1] for p in color_positions[c]) / max(len(color_positions[c]), 1)
        if avg_y < h * 0.7:  # hair is mostly in the top 70%
            hair_clean.append(c)
    
    return skin_clean, hair_clean


def shift_hue_layered(img, target_colors, target_hue):
    """Shift hue of target_colors pixels to target_hue, preserving luminance."""
    px = img.load()
    w, h = img.size
    new_img = Image.new("RGBA", (w, h))
    new_px = new_img.load()
    
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 16:
                new_px[x, y] = c
            elif c[:3] in target_colors:
                _, s, l = rgb_to_hsl(*c[:3])
                new_s = max(s, 0.15)
                rc = hsl_to_rgb(target_hue, new_s, l)
                new_px[x, y] = (rc[0], rc[1], rc[2], c[3])
            else:
                new_px[x, y] = c
    
    return new_img


# ============================================================
# Frame Processing (from ro_pipeline.py)
# ============================================================

def generate_face_from_atlas(
    src_face_id,
    dst_face_id,
    gen_face_img,
    hair_color="blonde",
    skin_tone="light",
):
    """Take a generated face image, extract its palette,
    and apply to all frames of the source face."""
    
    atlas_path = os.path.join(SRC, "face", "face.atlas.png")
    atlas_json_path = os.path.join(SRC, "face", "face.atlas.json")
    
    if not os.path.exists(atlas_path) or not os.path.exists(atlas_json_path):
        print(f"  [ERR] Source atlas missing")
        return False
    
    atlas = Image.open(atlas_path).convert("RGBA")
    with open(atlas_json_path) as f:
        data = json.load(f)
    
    frames = data.get("frames", {})
    
    # Group frames by face ID
    face_frames = {}
    for fn, info in frames.items():
        parts = os.path.splitext(fn)[0].split("_")
        face_id = parts[0].replace("Face", "face", 1)
        if face_id != src_face_id:
            continue
        key = "_".join(parts[1:]) if len(parts) > 1 else parts[0]
        face_frames[key] = info
    
    if not face_frames:
        print(f"  [ERR] No frames found for {src_face_id}")
        return False
    
    # Extract palette from generated face
    gen_small = gen_face_img.resize((32, 33), Image.NEAREST)
    skin_colors, hair_colors = extract_palette_from_face(gen_small)
    
    # Target hues
    hair_hues = {
        "blonde": 0.12, "red": 0.02, "brown": 0.08, "black": 0.0,
        "blue": 0.60, "green": 0.33, "pink": 0.92, "white": 0.0,
        "orange": 0.05, "purple": 0.75, "cyan": 0.55, "gray": 0.0,
    }
    skin_hues = {
        "light": 0.05, "tan": 0.08, "dark": 0.10, "pale": 0.03,
    }
    
    target_hair_hue = hair_hues.get(hair_color, 0.12)
    target_skin_hue = skin_hues.get(skin_tone, 0.05)
    
    print(f"  Extracted palette: {len(skin_colors)} skin + {len(hair_colors)} hair colors")
    print(f"  Applying: skin_hue={target_skin_hue:.2f}, hair_hue={target_hair_hue:.2f}")
    
    # Output directory
    out_face_dir = os.path.join(OUT, "face", dst_face_id)
    os.makedirs(out_face_dir, exist_ok=True)
    
    # Source frame definition for CX/CY
    src_frame_file = os.path.join(ROOT, "assets", "frame", "face", f"{src_face_id}.json")
    src_frame_data = None
    if os.path.exists(src_frame_file):
        with open(src_frame_file) as f:
            src_frame_data = json.load(f)
    
    # Process all frames
    new_images = {}
    for key, info in face_frames.items():
        frame = info.get("frame", info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        img = atlas.crop((x, y, x+w, y+h))
        
        # Apply hue shifts based on extracted palette
        if skin_colors:
            img = shift_hue_layered(img, set(skin_colors), target_skin_hue)
        if hair_colors:
            img = shift_hue_layered(img, set(hair_colors), target_hair_hue)
        
        out_fn = f"{dst_face_id}_{key}.png"
        img.save(os.path.join(out_face_dir, out_fn))
        new_images[key] = out_fn
    
    # Generate frame definition JSON
    frame_out = {"NAME": dst_face_id}
    dir_map = {"0": "R", "1": "U", "2": "L", "3": "D"}
    for dir_key in ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D"]:
        frame_out[dir_key] = {"IMG": [], "CX": [], "CY": []}
    
    for key in face_frames:
        out_fn = f"{dst_face_id}_{key}.png"
        parts = key.split("_")
        anim_type = parts[0]
        dir_idx = parts[1]
        dir_name = dir_map.get(dir_idx, "R")
        frame_key = f"STAND_{dir_name}" if anim_type == "stand" else dir_name
        
        cx, cy = 0, 0
        if src_frame_data:
            src_entry = src_frame_data.get(frame_key, {})
            if src_entry:
                img_list = src_entry.get("IMG", [])
                cx_list = src_entry.get("CX", [])
                cy_list = src_entry.get("CY", [])
                orig_fn = f"{src_face_id}_{key}.png"
                try:
                    idx = img_list.index(orig_fn)
                    if idx < len(cx_list):
                        cx = cx_list[idx]
                        cy = cy_list[idx]
                except ValueError:
                    pass
        
        frame_out[frame_key]["IMG"].append(out_fn)
        frame_out[frame_key]["CX"].append(cx)
        frame_out[frame_key]["CY"].append(cy)
    
    # Save JSON
    with open(os.path.join(out_face_dir, f"{dst_face_id}.json"), "w") as f:
        json.dump(frame_out, f, indent=4)
    
    # Save generated reference face
    gen_small.save(os.path.join(out_face_dir, f"{dst_face_id}_ai_ref.png"))
    
    print(f"  -> {len(new_images)} frames saved to {out_face_dir}")
    return True


def pack_frames(frame_dir, name):
    """Pack individual frames into atlas format."""
    pngs = sorted([f for f in os.listdir(frame_dir) if f.endswith(".png") and "ai_ref" not in f and "atlas" not in f])
    if not pngs:
        print(f"  [ERR] No PNGs in {frame_dir}")
        return None
    
    widths = [Image.open(os.path.join(frame_dir, p)).width for p in pngs]
    heights = [Image.open(os.path.join(frame_dir, p)).height for p in pngs]
    
    cell_w = max(widths)
    cell_h = max(heights)
    cols = 8
    rows = (len(pngs) + cols - 1) // cols
    atlas_w = cols * cell_w
    atlas_h = rows * cell_h
    
    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    frame_data = {"frames": {}}
    
    for i, p in enumerate(pngs):
        col = i % cols
        row = i // cols
        x = col * cell_w
        y = row * cell_h
        
        img = Image.open(os.path.join(frame_dir, p))
        ox = (cell_w - img.width) // 2
        oy = (cell_h - img.height) // 2
        atlas.paste(img, (x + ox, y + oy))
        
        frame_data["frames"][p] = {
            "frame": {"x": x + ox, "y": y + oy, "w": img.width, "h": img.height},
            "rotated": False, "trimmed": False,
            "spriteSourceSize": {"x": 0, "y": 0, "w": img.width, "h": img.height},
            "sourceSize": {"w": img.width, "h": img.height},
        }
    
    atlas.save(os.path.join(frame_dir, f"{name}.atlas.png"))
    with open(os.path.join(frame_dir, f"{name}.atlas.json"), "w") as f:
        json.dump(frame_data, f, indent=4)
    
    print(f"  Packed {len(pngs)} frames -> {name}.atlas.png ({atlas_w}x{atlas_h})")


# ============================================================
# Main Pipeline
# ============================================================

def generate_new_face(
    prompt_description,
    src_face_id="face10101",
    dst_face_id="face92001",
    hair_color="blonde",
    skin_tone="light",
    denoise=0.7,
):
    """Full pipeline: AI generate face → extract palette → apply to all frames → package."""
    
    print(f"\n{'='*60}")
    print(f"Generating: {dst_face_id}")
    print(f"  Prompt: {prompt_description}")
    print(f"  Source: {src_face_id}")
    print(f"  Hair: {hair_color}, Skin: {skin_tone}")
    print(f"{'='*60}")
    
    # Step 1: Get a reference frame from source face
    atlas = Image.open(os.path.join(SRC, "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(SRC, "face", "face.atlas.json")) as f:
        data = json.load(f)
    
    # Find stand_0_0 of source face
    # Atlas keys may be lowercase (face10101) or uppercase (Face10301)
    ref_fn = None
    possible_prefixes = [src_face_id, src_face_id.capitalize(), "Face" + src_face_id[4:]]
    for fn in data.get("frames", {}):
        if any(fn.startswith(p) for p in possible_prefixes) and "stand_0_0" in fn:
            ref_fn = fn
            break
    
    if not ref_fn:
        print(f"  [ERR] Reference frame not found for {src_face_id}")
        return False
    
    info = data["frames"][ref_fn]
    frame = info.get("frame", info)
    x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
    ref_img = atlas.crop((x, y, x+w, y+h))
    
    # Step 2: Upscale reference for img2img (from ~33px to 256px)
    # Use LANCZOS for smoother reference (model handles it better)
    ref_large = ref_img.resize((256, 256), Image.LANCZOS)
    ref_path = os.path.join(COMFY_INPUT, "ro_ref_" + dst_face_id + ".png")
    ref_large.save(ref_path)
    
    # Step 3: Build prompt
    full_prompt = f"pixel art {prompt_description}, ro style game sprite character face, 32x33 pixels, colored, transparent background"
    neg_prompt = "ugly, deformed, blurry, low quality, realistic, photo, extra limbs, bad anatomy"
    
    # Step 4: Run ComfyUI workflow
    print(f"  Running ComfyUI img2img...")
    client = ComfyClient()
    
    workflow, save_node_id = build_img2img_workflow(
        reference_image="ro_ref_" + dst_face_id + ".png",
        prompt=full_prompt,
        negative_prompt=neg_prompt,
        denoise=denoise,
        steps=30,
        cfg=5.0,
        width=256,
        height=256,
    )
    
    try:
        prompt_id = client.queue_prompt(workflow)
        print(f"  Prompt ID: {prompt_id}")
        result = client.get_history(prompt_id)
        
        # Find generated image
        outputs = result.get("outputs", {})
        gen_images = []
        for node_id, node_output in outputs.items():
            if "images" in node_output:
                gen_images.extend(node_output["images"])
        
        if not gen_images:
            print(f"  [ERR] No images generated")
            return False
        
        # Download the generated image
        img_info = gen_images[0]
        img_data = client.get_image(
            img_info["filename"],
            img_info.get("subfolder", ""),
            img_info.get("type", "output"),
        )
        
        gen_img = Image.open(io.BytesIO(img_data)).convert("RGBA")
        print(f"  Generated: {img_info['filename']} ({gen_img.size})")
        
    except Exception as e:
        print(f"  [ERR] ComfyUI generation failed: {e}")
        return False
    
    # Step 5: Post-process to pixel art (32x33, ~48 colors)
    gen_pixel = postprocess_to_pixel(gen_img, (32, 33))
    gen_pixel = quantize_palette(gen_pixel, max_colors=48)
    print(f"  Post-processed: {gen_pixel.size}")
    
    # Step 6: Use AI face DIRECTLY as stand_0_0, apply palette to other frames
    # First save AI reference
    ai_ref_path = os.path.join(os.path.join(OUT, "face", dst_face_id), f"{dst_face_id}_ai_ref.png")
    os.makedirs(os.path.join(OUT, "face", dst_face_id), exist_ok=True)
    gen_pixel.save(ai_ref_path)
    print(f"  AI reference face saved: {gen_pixel.size}")
    
    # Generate all frames using AI face as palette source
    success = generate_face_from_atlas(
        src_face_id=src_face_id,
        dst_face_id=dst_face_id,
        gen_face_img=gen_pixel,
        hair_color=hair_color,
        skin_tone=skin_tone,
    )
    
    # Step 7: Overwrite stand_0_0 with the actual AI-generated pixel face
    # (This gives the user a VISIBLY NEW face shape, not just recolored)
    gen_pixel_resized = gen_pixel.resize((33, 33), Image.NEAREST) if gen_pixel.size != (33, 33) else gen_pixel
    stand_out = os.path.join(os.path.join(OUT, "face", dst_face_id), f"{dst_face_id}_stand_0_0.png")
    gen_pixel_resized.save(stand_out)
    print(f"  Replaced stand_0_0 with AI-generated face shape")
    
    if success:
        # Step 7: Package atlas
        out_dir = os.path.join(OUT, "face", dst_face_id)
        pack_frames(out_dir, dst_face_id)
        print(f"\n  [OK] {dst_face_id} complete!")
    
    return success


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ro_ai_gen.py <config_name>")
        print("")
        print("Configs:")
        print("  test     - Quick test: blonde hair variant")
        print("  batch    - Run all 8 face variants")
        print("  custom   - Custom generation with prompts")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "test":
        generate_new_face(
            prompt_description="male character face with short blonde spiky hair, brown eyes",
            src_face_id="face10101",
            dst_face_id="face92001",
            hair_color="blonde",
            skin_tone="light",
            denoise=0.65,
        )
    
    elif cmd == "test2":
        generate_new_face(
            prompt_description="female character face with long red hair, green eyes, pony tail",
            src_face_id="face10201",
            dst_face_id="face92002",
            hair_color="red",
            skin_tone="pale",
            denoise=0.65,
        )
    
    elif cmd == "test3":
        generate_new_face(
            prompt_description="male character face with blue spiky anime hair, stern expression",
            src_face_id="face10301",
            dst_face_id="face92003",
            hair_color="blue",
            skin_tone="light",
            denoise=0.65,
        )
    
    elif cmd == "custom" and len(sys.argv) >= 4:
        generate_new_face(
            prompt_description=sys.argv[2],
            dst_face_id=sys.argv[3],
            hair_color=sys.argv[4] if len(sys.argv) > 4 else "blonde",
            skin_tone=sys.argv[5] if len(sys.argv) > 5 else "light",
        )
    
    else:
        print(f"Unknown command: {cmd}")
        print("Usage: python ro_ai_gen.py test")
