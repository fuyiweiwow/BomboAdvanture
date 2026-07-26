"""RO Sprite AI Generator v2 - High-res approach

Key insight: 32x33 is too small for AI to generate meaningful shape variation.
Solution: Generate at 4x (128x132), then pixel-perfect downscale.
"""

import os, sys, json, time, uuid, requests, io, math
from PIL import Image
from collections import defaultdict

COMFY_UI = "http://127.0.0.1:8188"
ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
SRC = os.path.join(ROOT, "assets", "img")
OUT = os.path.join(ROOT, "assets", "test", "ro_ai_v2")
os.makedirs(OUT, exist_ok=True)
COMFY_INPUT = r"E:\env\ComfyUI\input"
COMFY_OUTPUT = r"E:\env\ComfyUI\output"
CHECKPOINT = "Counterfeit-V3.0_fp16.safetensors"

CLIENT_ID = str(uuid.uuid4())

def queue_workflow(workflow):
    resp = requests.post(f"{COMFY_UI}/prompt", json={"prompt": workflow, "client_id": CLIENT_ID})
    resp.raise_for_status()
    return resp.json()["prompt_id"]

def wait_for_result(prompt_id, max_wait=180):
    start = time.time()
    while time.time() - start < max_wait:
        resp = requests.get(f"{COMFY_UI}/history/{prompt_id}")
        if resp.status_code == 200:
            data = resp.json()
            if prompt_id in data:
                return data[prompt_id]
        time.sleep(2)
    raise TimeoutError(f"Prompt {prompt_id} timeout")

def get_image(filename, subfolder="", folder_type="output"):
    resp = requests.get(f"{COMFY_UI}/view", params={"filename": filename, "subfolder": subfolder, "type": folder_type})
    resp.raise_for_status()
    return resp.content


def make_workflow(ref_filename, prompt, neg_prompt="ugly, deformed, blurry, realistic, photo", 
                  denoise=0.75, steps=35, cfg=5.0, width=128, height=132):
    """Build img2img workflow at target resolution."""
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CHECKPOINT}},
        "2": {"class_type": "LoadImage", "inputs": {"image": ref_filename}},
        "3": {"class_type": "VAEEncode", "inputs": {"pixels": ["2", 0], "vae": ["1", 2]}},
        "4": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"text": neg_prompt, "clip": ["1", 1]}},
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "seed": int(time.time() * 1000) % (2**32),
                "control_after_generate": "fixed",
                "steps": steps, "cfg": cfg,
                "sampler_name": "euler", "scheduler": "normal",
                "denoise": denoise,
                "model": ["1", 0], "positive": ["4", 0],
                "negative": ["5", 0], "latent_image": ["3", 0],
            },
        },
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}},
        "8": {"class_type": "SaveImage", "inputs": {"images": ["7", 0], "filename_prefix": "ro_v2_"}},
    }


def remove_bg_at_pixel_level(pixel_img, border_px=1):
    """Remove background at pixel-art level (32x33) by detecting edge color."""
    px = pixel_img.load()
    w, h = pixel_img.size
    
    # Sample 1-pixel border
    edge_colors = []
    for y in range(h):
        for x in range(w):
            if x < border_px or x >= w-border_px or y < border_px or y >= h-border_px:
                c = px[x, y]
                if c[3] > 16:
                    edge_colors.append((c[0], c[1], c[2]))
    
    if not edge_colors:
        return pixel_img
    
    # Find the most common edge color (mode)
    color_counts = defaultdict(int)
    for c in edge_colors:
        color_counts[c] += 1
    bg_color = max(color_counts, key=color_counts.get)
    bg_count = color_counts[bg_color]
    
    # Compute variance of bg samples
    import math
    bg_samples = [c for c in edge_colors if c == bg_color]
    if not bg_samples:
        return pixel_img
    
    # Threshold: distance from bg_color
    # For pixel art, a simple threshold works well since bg is usually one of ~48 quantized colors
    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rpx = result.load()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 16:
                continue
            # If equals bg color OR on edge, make transparent
            if (c[0], c[1], c[2]) == bg_color:
                rpx[x, y] = (0, 0, 0, 0)
            elif x < border_px or x >= w-border_px or y < border_px or y >= h-border_px:
                rpx[x, y] = (0, 0, 0, 0)
            else:
                rpx[x, y] = c
    
    return result


def pixel_postprocess(img, target=(32, 33), max_colors=48):
    """Post-process AI output to clean pixel art with transparency."""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    
    # Step 1: NEAREST downscale to target FIRST
    pixel = img.resize(target, Image.NEAREST)
    
    # Step 2: Quantize to limited palette
    px = pixel.load()
    tw, th = pixel.size
    colors = []
    for y in range(th):
        for x in range(tw):
            c = px[x, y]
            if c[3] > 16:
                colors.append((c[0], c[1], c[2]))
    
    unique = list(set(colors))
    if len(unique) > max_colors:
        colors_lum = [(c, 0.299*c[0]+0.587*c[1]+0.114*c[2]) for c in unique]
        colors_lum.sort(key=lambda x: x[1])
        
        n_bins = min(max_colors, len(unique))
        palette_map = {}
        for i in range(n_bins):
            start = int(i * len(colors_lum) / n_bins)
            end = int((i + 1) * len(colors_lum) / n_bins)
            bin_c = [c[0] for c in colors_lum[start:end]]
            if not bin_c: continue
            avg = (
                sum(c[0] for c in bin_c) // len(bin_c),
                sum(c[1] for c in bin_c) // len(bin_c),
                sum(c[2] for c in bin_c) // len(bin_c),
            )
            for c in bin_c:
                palette_map[c] = avg
        
        quant = Image.new("RGBA", (tw, th))
        qpx = quant.load()
        for y in range(th):
            for x in range(tw):
                c = px[x, y]
                if c[3] > 16:
                    nc = palette_map.get((c[0], c[1], c[2]), (c[0], c[1], c[2]))
                    qpx[x, y] = (*nc, c[3])
                else:
                    qpx[x, y] = (0, 0, 0, 0)
        pixel = quant
    
    # Step 3: Remove background at pixel level
    pixel = remove_bg_at_pixel_level(pixel)
    
    return pixel


def apply_palette_to_frame(orig_pixels, ai_pixels):
    """Apply AI-generated pixel art colors to an original frame.
    
    Maps each pixel in orig to the closest color in AI palette,
    preserving the original pixel positions and transparency.
    """
    # Extract AI palette
    ai_colors = set()
    ai_px = ai_pixels.load()
    for y in range(ai_pixels.height):
        for x in range(ai_pixels.width):
            c = ai_px[x, y]
            if c[3] > 16:
                ai_colors.add((c[0], c[1], c[2]))
    
    ai_list = list(ai_colors)
    
    def closest(c):
        best_dist = float("inf")
        best = c
        for ac in ai_list:
            dr, dg, db = c[0]-ac[0], c[1]-ac[1], c[2]-ac[2]
            dist = dr*dr + dg*dg + db*db
            if dist < best_dist:
                best_dist = dist
                best = ac
        return best
    
    opx = orig_pixels.load()
    w, h = orig_pixels.size
    result = Image.new("RGBA", (w, h))
    rpx = result.load()
    for y in range(h):
        for x in range(w):
            c = opx[x, y]
            if c[3] > 16:
                nc = closest((c[0], c[1], c[2]))
                rpx[x, y] = (*nc, c[3])
    return result


def remove_eye_mouth_region(pixel_img, face_id):
    """Remove eyes and mouth from a pixel art face, replacing with skin tone.
    
    Returns clean face component (head + hair only, no features).
    Also saves a debug overlay showing what was removed.
    """
    px = pixel_img.load()
    w, h = pixel_img.size
    result = Image.new("RGBA", (w, h))
    rpx = result.load()
    
    # Step 1: Find the dominant skin color
    # Skin is in the middle luminance range, most frequent
    skin_colors = {}  # color -> count
    shadow_colors = {}
    # Lower half of face (below hair, above neck)
    lower_start = int(h * 0.45)
    for y in range(lower_start, h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
                if 60 < lum < 220:  # skin range
                    key = (c[0], c[1], c[2])
                    skin_colors[key] = skin_colors.get(key, 0) + 1
    
    if not skin_colors:
        return pixel_img
    
    # Most common skin color
    dominant_skin = max(skin_colors, key=skin_colors.get)
    
    # Step 2: Find dark pixel clusters in the face region (not hair)
    # Hair is in the top ~40%, features (eyes/mouth) are in the middle
    face_region_y_start = int(h * 0.35)
    face_region_y_end = int(h * 0.85)
    
    dark_clusters = []
    for y in range(face_region_y_start, face_region_y_end):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
                if lum < 100:  # dark pixel candidate
                    # Check if surrounded by skin-toned pixels (±2 px neighborhood)
                    skin_neighbors = 0
                    total_neighbors = 0
                    for dy in [-2, -1, 0, 1, 2]:
                        for dx in [-2, -1, 0, 1, 2]:
                            nx, ny = x+dx, y+dy
                            if 0 <= nx < w and 0 <= ny < h:
                                nc = px[nx, ny]
                                if nc[3] > 16:
                                    total_neighbors += 1
                                    nlum = 0.299*nc[0] + 0.587*nc[1] + 0.114*nc[2]
                                    if 60 < nlum < 220:
                                        skin_neighbors += 1
                    if total_neighbors > 0 and skin_neighbors / total_neighbors > 0.4:
                        dark_clusters.append((x, y))
    
    debug = pixel_img.copy()
    dpx = debug.load()
    
    # Step 3: Replace dark clusters with skin color
    for y in range(face_region_y_start, face_region_y_end):
        for x in range(w):
            if (x, y) in dark_clusters:
                rpx[x, y] = (*dominant_skin, 255)
                dpx[x, y] = (255, 0, 0, 255)  # mark removed area red for debug
            else:
                c = px[x, y]
                rpx[x, y] = c
                dpx[x, y] = (c[0], c[1], c[2], c[3])
    
    # Save debug image
    import os
    out_dir = os.path.join(OUT, "face", face_id)
    os.makedirs(out_dir, exist_ok=True)
    debug.save(os.path.join(out_dir, f"{face_id}_debug_removed_features.png"))
    
    print(f"  Removed {len(dark_clusters)} dark pixels (eyes/mouth) replaced with skin")
    return result


def generate_face(
    prompt,
    face_id,
    src_face="face10101",
    denoise=0.75,
    gen_size=(128, 132),
    pixel_size=(32, 33),
    clean_face=True,
):
    """Full pipeline: generate at 4x → pixel post-process → apply palette → package."""
    
    print(f"\n{'='*50}")
    print(f"Generating {face_id}")
    print(f"  Prompt: {prompt}")
    print(f"  Source: {src_face}")
    print(f"  Gen res: {gen_size[0]}x{gen_size[1]} → pixel: {pixel_size[0]}x{pixel_size[1]}")
    print(f"{'='*50}")
    
    # Step 1: Load reference from atlas
    atlas = Image.open(os.path.join(SRC, "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(SRC, "face", "face.atlas.json")) as f:
        atlas_data = json.load(f)
    
    # Find reference frame
    ref_fn = None
    for fn in atlas_data.get("frames", {}):
        if fn.startswith(src_face) or fn.startswith(src_face.capitalize()):
            if "stand_0_0" in fn:
                ref_fn = fn
                break
    
    if not ref_fn:
        print(f"  [ERR] Reference not found for {src_face}")
        return False
    
    info = atlas_data["frames"][ref_fn]
    frame = info.get("frame", info)
    ref_img = atlas.crop((frame["x"], frame["y"], frame["x"]+frame["w"], frame["y"]+frame["h"]))
    
    # Step 2: Upscale reference to gen_size with LANCZOS
    ref_up = ref_img.resize(gen_size, Image.LANCZOS)
    ref_path = os.path.join(COMFY_INPUT, f"ro_v2_ref_{face_id}.png")
    ref_up.save(ref_path)
    
    # Step 3: Run ComfyUI img2img
    print(f"  ComfyUI img2img...")
    wf = make_workflow(f"ro_v2_ref_{face_id}.png", prompt, denoise=denoise, 
                       width=gen_size[0], height=gen_size[1])
    
    try:
        pid = queue_workflow(wf)
        result = wait_for_result(pid)
        
        outputs = result.get("outputs", {})
        gen_images = []
        for node_id, node_out in outputs.items():
            if "images" in node_out:
                gen_images.extend(node_out["images"])
        
        if not gen_images:
            print(f"  [ERR] No images generated")
            return False
        
        img_info = gen_images[0]
        img_data = get_image(img_info["filename"], img_info.get("subfolder", ""), img_info.get("type", "output"))
        gen_img = Image.open(io.BytesIO(img_data)).convert("RGBA")
        print(f"  Generated: {img_info['filename']} ({gen_img.size})")
        
    except Exception as e:
        print(f"  [ERR] Generation failed: {e}")
        return False
    
    # Step 4: Post-process to pixel art
    pixel = pixel_postprocess(gen_img, pixel_size)
    
    # Count pixels and colors
    px = pixel.load()
    non_trans = 0
    colors = set()
    for y in range(pixel.height):
        for x in range(pixel.width):
            c = px[x, y]
            if c[3] > 16:
                non_trans += 1
                colors.add((c[0], c[1], c[2]))
    print(f"  Pixel art: {pixel.size}, {non_trans} solid px, {len(colors)} colors")
    
    # Step 5: Save to output directory
    out_dir = os.path.join(OUT, "face", face_id)
    os.makedirs(out_dir, exist_ok=True)
    pixel.save(os.path.join(out_dir, f"{face_id}_ai_ref.png"))
    
    # Step 6: Generate all 28 frames using AI palette
    # Group source frames by face ID
    src_frames = {}
    all_src_prefixes = [src_face, src_face.capitalize()]
    for fn, info in atlas_data.get("frames", {}).items():
        prefix = fn.split("_")[0]
        if prefix in all_src_prefixes or prefix.lower() in all_src_prefixes:
            key = "_".join(os.path.splitext(fn)[0].split("_")[1:])
            src_frames[key] = info
    
    if not src_frames:
        print(f"  [ERR] No frames for {src_face}")
        return False
    
    # Load source frame def for CX/CY
    src_json = os.path.join(ROOT, "assets", "frame", "face", f"{src_face}.json")
    src_frame_data = None
    if os.path.exists(src_json):
        with open(src_json) as f:
            src_frame_data = json.load(f)
    
    # Process each frame
    dir_map = {"0": "R", "1": "U", "2": "L", "3": "D"}
    frame_out = {"NAME": face_id}
    for dk in ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D"]:
        frame_out[dk] = {"IMG": [], "CX": [], "CY": []}
    
    for key, info in src_frames.items():
        frame = info.get("frame", info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        orig = atlas.crop((x, y, x+w, y+h))
        
        # Apply AI palette to this frame
        recolored = apply_palette_to_frame(orig, pixel)
        
        out_fn = f"{face_id}_{key}.png"
        recolored.save(os.path.join(out_dir, out_fn))
        
        # Frame JSON
        parts = key.split("_")
        anim_type = parts[0]
        dir_idx = parts[1]
        dir_name = dir_map.get(dir_idx, "R")
        fk = f"STAND_{dir_name}" if anim_type == "stand" else dir_name
        
        cx, cy = 0, 0
        if src_frame_data:
            entry = src_frame_data.get(fk, {})
            if entry:
                try:
                    idx = entry["IMG"].index(f"{src_face}_{key}.png")
                    cx = entry["CX"][idx]
                    cy = entry["CY"][idx]
                except (ValueError, IndexError):
                    pass
        
        frame_out[fk]["IMG"].append(out_fn)
        frame_out[fk]["CX"].append(cx)
        frame_out[fk]["CY"].append(cy)
    
    # Save frame JSON
    with open(os.path.join(out_dir, f"{face_id}.json"), "w") as f:
        json.dump(frame_out, f, indent=4)
    
    # Step 7: Save the high-resolution AI face as reference
    pixel.save(os.path.join(out_dir, f"{face_id}_ai_face_{pixel_size[0]}x{pixel_size[1]}.png"))
    print(f"  AI face saved at {pixel_size[0]}x{pixel_size[1]} for visual inspection")
    
    # Step 7b: Generate clean face (no eyes/mouth) if requested
    if clean_face:
        pixel_clean = remove_eye_mouth_region(pixel, face_id)
        pixel_clean.save(os.path.join(out_dir, f"{face_id}_clean_{pixel_size[0]}x{pixel_size[1]}.png"))
        print(f"  Clean face (eyes/mouth removed) saved")
    else:
        pixel_clean = pixel
    
    # Step 8: For the atlas, resize AI face to original stand_0_0 size
    # and apply its palette to all other frames
    orig_stand_fn = None
    for fn, info in atlas_data.get("frames", {}).items():
        prefix = fn.split("_")[0]
        if (prefix == src_face or prefix == src_face.capitalize()) and "stand_0_0" in fn:
            orig_stand_fn = fn
            break
    
    if orig_stand_fn:
        info = atlas_data["frames"][orig_stand_fn]
        frame = info.get("frame", info)
        sw, sh = frame["w"], frame["h"]
        ai_resized = pixel.resize((sw, sh), Image.NEAREST)
        ai_resized.save(os.path.join(out_dir, f"{face_id}_stand_0_0.png"))
        print(f"  stand_0_0 atlas frame: {sw}x{sh}")
    
    # Step 8: Package atlas
    pngs = sorted([f for f in os.listdir(out_dir) if f.endswith(".png") and "atlas" not in f and "ai_ref" not in f])
    if pngs:
        widths = [Image.open(os.path.join(out_dir, p)).width for p in pngs]
        heights = [Image.open(os.path.join(out_dir, p)).height for p in pngs]
        cw = max(widths)
        ch = max(heights)
        cols = 8
        rows = (len(pngs) + cols - 1) // cols
        atlas_out = Image.new("RGBA", (cols*cw, rows*ch), (0,0,0,0))
        atlas_frames = {"frames": {}}
        
        for i, p in enumerate(pngs):
            col = i % cols
            row = i // cols
            img = Image.open(os.path.join(out_dir, p))
            ox = (cw - img.width) // 2
            oy = (ch - img.height) // 2
            pos = (col*cw+ox, row*ch+oy)
            atlas_out.paste(img, pos)
            atlas_frames["frames"][p] = {
                "frame": {"x": pos[0], "y": pos[1], "w": img.width, "h": img.height},
                "rotated": False, "trimmed": False,
                "spriteSourceSize": {"x": 0, "y": 0, "w": img.width, "h": img.height},
                "sourceSize": {"w": img.width, "h": img.height},
            }
        
        atlas_out.save(os.path.join(out_dir, f"{face_id}.atlas.png"))
        with open(os.path.join(out_dir, f"{face_id}.atlas.json"), "w") as f:
            json.dump(atlas_frames, f, indent=4)
        print(f"  Atlas: {atlas_out.size} ({len(pngs)} frames)")
    
    print(f"  [OK] {face_id} complete!")
    return True


if __name__ == "__main__":
    configs = [
        ("male character with short spiky anime hair, angular face, looking right", "face93001", "face10101", 0.80),
        ("female character with long flowing hair parted in middle, round face, looking right", "face93002", "face10201", 0.80),
        ("bald male character with no hair at all, shiny scalp, angry eyebrows", "face93003", "face10101", 0.85),
        ("male character with full beard and moustache, long wild hair", "face93004", "face10301", 0.85),
        ("female character with twin tail pigtails, big round eyes, looking right", "face93005", "face10201", 0.80),
    ]
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "all":
            for cfg in configs:
                generate_face(*cfg, gen_size=(512, 528), pixel_size=(64, 66))
        elif sys.argv[1] == "list":
            for prompt, fid, src, den in configs:
                print(f"  {fid}: {prompt} (from {src}, denoise={den})")
        elif sys.argv[1].startswith("face"):
            for prompt, fid, src, den in configs:
                if fid == sys.argv[1]:
                    generate_face(prompt, fid, src, den, gen_size=(512, 528), pixel_size=(64, 66))
                    break
            else:
                print(f"Face {sys.argv[1]} not found in configs")
        else:
            generate_face(
                prompt=sys.argv[1],
                face_id=sys.argv[2] if len(sys.argv) > 2 else "face93999",
                src_face=sys.argv[3] if len(sys.argv) > 3 else "face10101",
                gen_size=(512, 528), pixel_size=(64, 66),
            )
    else:
        generate_face(*configs[0], gen_size=(512, 528), pixel_size=(64, 66))
