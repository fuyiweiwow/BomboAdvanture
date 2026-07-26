"""RO Sprite AI Generator v3 - Diffusers + LoRA integrated pipeline.

Uses waifu-diffusion + RO face LoRA for direct generation.
No ComfyUI dependency.
"""

import os, sys, json, io, math
from PIL import Image
from collections import defaultdict

os.environ["HF_HOME"] = r"E:\env\temp\hf_cache"
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

import torch
from diffusers import StableDiffusionPipeline
from safetensors.torch import load_file

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
SRC = os.path.join(ROOT, "assets", "img")
OUT = os.path.join(ROOT, "assets", "test", "ro_ai_v3")
os.makedirs(OUT, exist_ok=True)

LORA_DIR = os.path.join(ROOT, "assets", "train", "face_lora", "lora_weights")

def init_pipeline():
    print("Loading waifu-diffusion + LoRA...")
    pipe = StableDiffusionPipeline.from_pretrained(
        "hakurei/waifu-diffusion",
        torch_dtype=torch.float16,
        safety_checker=None,
    )
    pipe.to("cuda")
    pipe.enable_attention_slicing()

    # Load LoRA
    lora_path = os.path.join(LORA_DIR, "ro_face_lora.safetensors")
    if os.path.exists(lora_path):
        pipe.load_lora_weights(LORA_DIR)
        print("  LoRA loaded!")
    else:
        print("  WARNING: No LoRA weights found, using base model only")

    return pipe

def generate_face(
    pipe,
    prompt,
    face_id,
    src_face="face10101",
    gen_size=(512, 528),
    pixel_size=(64, 66),
    clean_face=True,
):
    print(f"\n{'='*50}")
    print(f"Generating {face_id}")
    print(f"  Prompt: {prompt}")
    print(f"  Source: {src_face}")
    print(f"  Gen res: {gen_size[0]}x{gen_size[1]} -> pixel: {pixel_size[0]}x{pixel_size[1]}")
    print(f"{'='*50}")

    # Step 1: Load reference from atlas
    atlas = Image.open(os.path.join(SRC, "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(SRC, "face", "face.atlas.json")) as f:
        atlas_data = json.load(f)

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

    # Step 2: Generate with diffusers (text2img with LoRA)
    print(f"  Generating with diffusers + LoRA...")
    full_prompt = f"{prompt}, pixel art chibi face, ro-face style"
    with torch.inference_mode():
        gen_img = pipe(
            full_prompt,
            num_inference_steps=25,
            height=gen_size[1],
            width=gen_size[0],
            cross_attention_kwargs={"scale": 1.0},
        ).images[0]
    gen_img = gen_img.convert("RGBA")
    print(f"  Generated: {gen_img.size}")

    # Step 3: Post-process to pixel art
    pixel = pixel_postprocess(gen_img, pixel_size)

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

    # Step 4: Save
    out_dir = os.path.join(OUT, "face", face_id)
    os.makedirs(out_dir, exist_ok=True)

    # Step 5: Generate clean face
    if clean_face:
        pixel_clean = remove_eye_mouth_region(pixel, face_id)
        pixel_clean.save(os.path.join(out_dir, f"{face_id}_clean_{pixel_size[0]}x{pixel_size[1]}.png"))
    else:
        pixel_clean = pixel

    # Step 6: Generate all 28 frames
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

    src_json = os.path.join(ROOT, "assets", "frame", "face", f"{src_face}.json")
    src_frame_data = None
    if os.path.exists(src_json):
        with open(src_json) as f:
            src_frame_data = json.load(f)

    dir_map = {"0": "R", "1": "U", "2": "L", "3": "D"}
    frame_out = {"NAME": face_id}
    for dk in ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D"]:
        frame_out[dk] = {"IMG": [], "CX": [], "CY": []}

    for key, info in src_frames.items():
        frame = info.get("frame", info)
        x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
        orig = atlas.crop((x, y, x+w, y+h))

        recolored = apply_palette_to_frame(orig, pixel if not clean_face else pixel_clean)
        out_fn = f"{face_id}_{key}.png"
        recolored.save(os.path.join(out_dir, out_fn))

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

    with open(os.path.join(out_dir, f"{face_id}.json"), "w") as f:
        json.dump(frame_out, f, indent=4)

    # Step 7: Save reference images
    pixel.save(os.path.join(out_dir, f"{face_id}_ai_face_{pixel_size[0]}x{pixel_size[1]}.png"))
    pixel_clean.save(os.path.join(out_dir, f"{face_id}_clean_{pixel_size[0]}x{pixel_size[1]}.png"))

    # Step 8: Package atlas
    pngs = sorted([f for f in os.listdir(out_dir) if f.endswith(".png")
                   and "atlas" not in f and "ai_" not in f and "clean_" not in f and "debug_" not in f])
    if pngs:
        cw = max(Image.open(os.path.join(out_dir, p)).width for p in pngs)
        ch = max(Image.open(os.path.join(out_dir, p)).height for p in pngs)
        cols = 8
        rows = (len(pngs) + cols - 1) // cols
        atlas_out = Image.new("RGBA", (cols*cw, rows*ch), (0, 0, 0, 0))
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

# Shared pixel post-processing functions
def pixel_postprocess(img, target=(32, 33), max_colors=48):
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    pixel = img.resize(target, Image.NEAREST)
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
    pixel = remove_bg_at_pixel_level(pixel)
    return pixel

def remove_bg_at_pixel_level(pixel_img, border_px=1):
    px = pixel_img.load()
    w, h = pixel_img.size
    edge_colors = []
    for y in range(h):
        for x in range(w):
            if x < border_px or x >= w-border_px or y < border_px or y >= h-border_px:
                c = px[x, y]
                if c[3] > 16:
                    edge_colors.append((c[0], c[1], c[2]))
    if not edge_colors:
        return pixel_img
    color_counts = defaultdict(int)
    for c in edge_colors:
        color_counts[c] += 1
    bg_color = max(color_counts, key=color_counts.get)
    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rpx = result.load()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 16:
                continue
            if (c[0], c[1], c[2]) == bg_color:
                rpx[x, y] = (0, 0, 0, 0)
            elif x < border_px or x >= w-border_px or y < border_px or y >= h-border_px:
                rpx[x, y] = (0, 0, 0, 0)
            else:
                rpx[x, y] = c
    return result

def remove_eye_mouth_region(pixel_img, face_id):
    px = pixel_img.load()
    w, h = pixel_img.size
    result = Image.new("RGBA", (w, h))
    rpx = result.load()

    lower_start = int(h * 0.45)
    skin_colors = {}
    for y in range(lower_start, h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
                if 60 < lum < 220:
                    key = (c[0], c[1], c[2])
                    skin_colors[key] = skin_colors.get(key, 0) + 1
    if not skin_colors:
        return pixel_img
    dominant_skin = max(skin_colors, key=skin_colors.get)

    face_region_y_start = int(h * 0.35)
    face_region_y_end = int(h * 0.85)

    dark_clusters = []
    for y in range(face_region_y_start, face_region_y_end):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                lum = 0.299*c[0] + 0.587*c[1] + 0.114*c[2]
                if lum < 100:
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

    for y in range(face_region_y_start, face_region_y_end):
        for x in range(w):
            if (x, y) in dark_clusters:
                rpx[x, y] = (*dominant_skin, 255)
            else:
                rpx[x, y] = px[x, y]

    print(f"  Removed {len(dark_clusters)} dark pixels (eyes/mouth) replaced with skin")
    return result

def apply_palette_to_frame(orig_pixels, ai_pixels):
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

if __name__ == "__main__":
    configs = [
        ("male character with short spiky anime hair, angular face", "face94001", "face10101"),
        ("female character with long flowing hair parted in middle, round face", "face94002", "face10201"),
        ("bald male character with no hair at all, shiny scalp", "face94003", "face10101"),
        ("male character with full beard and moustache, long wild hair", "face94004", "face10301"),
        ("female character with twin tail pigtails", "face94005", "face10201"),
        ("female character with bob cut hair and bangs", "face94006", "face10701"),
        ("male character with mohawk hairstyle, serious expression", "face94007", "face10301"),
        ("female character with ponytail hair, gentle smile", "face94008", "face10201"),
    ]

    if len(sys.argv) > 1:
        if sys.argv[1] == "all":
            pipe = init_pipeline()
            for cfg in configs:
                generate_face(pipe, *cfg, gen_size=(512, 528), pixel_size=(64, 66))
        elif sys.argv[1] == "list":
            for prompt, fid, src in configs:
                print(f"  {fid}: {prompt} (from {src})")
        elif sys.argv[1].startswith("face"):
            pipe = init_pipeline()
            for prompt, fid, src in configs:
                if fid == sys.argv[1]:
                    generate_face(pipe, prompt, fid, src, gen_size=(512, 528), pixel_size=(64, 66))
                    break
            else:
                print(f"Face {sys.argv[1]} not found")
        else:
            pipe = init_pipeline()
            generate_face(pipe, sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "face94999",
                         sys.argv[3] if len(sys.argv) > 3 else "face10101",
                         gen_size=(512, 528), pixel_size=(64, 66))
    else:
        pipe = init_pipeline()
        generate_face(pipe, *configs[0], gen_size=(512, 528), pixel_size=(64, 66))
