"""
v5 Component pipeline:
1. Load manually-annotated region template
2. Generate AI reference image (waifu-diffusion + LoRA)
3. Extract per-region dominant colors from AI output
4. Apply colors back to template regions (per-region palette)
5. Output clean pixel-art face component + eye/mouth masks
"""

import os, json, sys
import torch
from PIL import Image
from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
from collections import Counter

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
LORA_PATH = os.path.join(ROOT, "assets", "train", "face_lora", "lora_weights", "ro_face_lora.safetensors")
TEMPLATE_NAME = os.environ.get("FACE_TEMPLATE", "face10101")
TEMPLATE_PATH = os.path.join(ROOT, "assets", "train", "face_annotations", f"{TEMPLATE_NAME}_region_template.json")
OUT_DIR = os.environ.get("FACE_OUT_DIR", os.path.join(ROOT, "assets", "test", "ro_component_v5"))

# Palette size per region (default 6 for any region not listed)
PALETTE_SIZE = {"hair": 6, "skin": 12, "eyes": 4, "mouth": 4, "eyes_brows_ears": 6, "eyes_brows": 6, "ears": 4, "accessory": 4}

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32


def load_template():
    with open(TEMPLATE_PATH) as f:
        tmpl = json.load(f)
    return tmpl

# Global pipeline (load once)
_pipe = None

def get_pipe():
    global _pipe
    if _pipe is not None:
        return _pipe

    # Ensure env vars set BEFORE diffusers imports config
    os.environ["HF_HOME"] = "E:\\env\\cache\\huggingface"
    os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

    ckpt_path = r"E:\env\ComfyUI\models\checkpoints\Counterfeit-V3.0_fp16.safetensors"
    print("Loading Counterfeit-V3.0 pipeline...")
    _pipe = StableDiffusionPipeline.from_single_file(
        ckpt_path,
        torch_dtype=dtype,
        safety_checker=None,
        requires_safety_checker=False,
    ).to(device)
    _pipe.scheduler = DPMSolverMultistepScheduler.from_config(_pipe.scheduler.config)
    _pipe.enable_attention_slicing()
    if device == "cuda":
        _pipe.enable_model_cpu_offload()
    return _pipe


def generate_ai_reference(prompt, seed=42):
    """Generate AI face reference using cached pipeline."""
    pipe = get_pipe()

    gen = torch.Generator(device=device).manual_seed(seed)
    result = pipe(
        prompt=prompt + ", pixel art style, character face, portrait, game sprite",
        negative_prompt="low quality, blurry, noisy, messy, deformed, bad anatomy",
        width=512, height=528,
        num_inference_steps=30,
        guidance_scale=7.5,
        generator=gen,
    )
    return result.images[0]


def extract_per_region_colors(ai_img, tmpl):
    """Extract dominant colors from AI image for each region."""
    ai_img_64 = ai_img.resize((tmpl["width"], tmpl["height"]), Image.LANCZOS)
    if ai_img_64.mode != "RGBA":
        ai_img_64 = ai_img_64.convert("RGBA")
    ai_px = ai_img_64.load()

    region_colors = {}
    for region_name in tmpl["pixels"]:
        pixels = tmpl["pixels"].get(region_name, [])
        if not pixels:
            continue

        # Collect all AI pixel colors for this region
        color_list = []
        for xc, yc in pixels:
            c = ai_px[xc, yc]
            # Quantize to reduce noise
            qc = (c[0] // 16 * 16, c[1] // 16 * 16, c[2] // 16 * 16)
            color_list.append(qc)

        # Count frequency, take top N
        counter = Counter(color_list)
        n = PALETTE_SIZE.get(region_name, 8)
        most_common = counter.most_common(n * 2)  # get more, then deduplicate by luminance

        # Deduplicate by luminance similarity
        palette = []
        seen_lums = set()
        for color, count in most_common:
            r, g, b = color
            lum = round((0.299*r + 0.587*g + 0.114*b) / 8) * 8  # quantize luminance
            if lum not in seen_lums:
                seen_lums.add(lum)
                palette.append({"color": list(color), "count": count})
                if len(palette) >= n:
                    break

        # Sort by luminance
        palette.sort(key=lambda x: 0.299*x["color"][0] + 0.587*x["color"][1] + 0.114*x["color"][2])
        region_colors[region_name] = palette
        print(f"  {region_name}: {len(palette)} colors from {len(color_list)} samples")

    return region_colors


def apply_palette_to_template(tmpl, region_colors):
    """Apply per-region palettes to template and generate output image."""
    w, h = tmpl["width"], tmpl["height"]

    # Create output image
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_px = out.load()

    # For each region, map template pixel colors to closest palette color
    # Load original face for reference colors
    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)
    name_parts = tmpl["name"].split("_")
    face_id = name_parts[0]
    stand_dir = "_".join(name_parts[1:]) if len(name_parts) > 1 else "stand_0_0"
    ref_key = next(fn for fn in data["frames"] if face_id.lower() in fn.lower() and stand_dir in fn)
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    ox, oy = frame["x"], frame["y"]
    offset_x, offset_y = tmpl.get("crop_offset", [0, 0])
    original = atlas.crop((ox + offset_x, oy + offset_y, ox + offset_x + w, oy + offset_y + h))
    orig_px = original.load()

    for region_name in tmpl["pixels"]:
        pixels = tmpl["pixels"].get(region_name, [])
        palette = region_colors.get(region_name, [{"color": [255, 192, 128]}])
        if not palette:
            continue
        palette_colors = [p["color"] for p in palette]

        # For edge regions (ears), use original colors directly (AI edges are unreliable)
        use_original = region_name == "ears"

        for xc, yc in pixels:
            orig_c = orig_px[xc, yc]

            if use_original:
                out_px[xc, yc] = (*orig_c[:3], 255)
                continue

            orig_lum = 0.299*orig_c[0] + 0.587*orig_c[1] + 0.114*orig_c[2]

            # Find closest palette color by luminance, then by RGB distance
            best = None
            best_dist = float("inf")
            for pc in palette_colors:
                pl = 0.299*pc[0] + 0.587*pc[1] + 0.114*pc[2]
                lum_dist = abs(pl - orig_lum)
                color_dist = (pc[0]-orig_c[0])**2 + (pc[1]-orig_c[1])**2 + (pc[2]-orig_c[2])**2
                dist = lum_dist * 2 + color_dist * 0.01
                if dist < best_dist:
                    best_dist = dist
                    best = pc

            out_px[xc, yc] = (*best, 255)

    return out


def create_eye_mouth_masks(tmpl):
    """Extract eye and mouth masks as separate images."""
    w, h = tmpl["width"], tmpl["height"]
    eye_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mouth_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    atlas = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
    with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
        data = json.load(f)
    name_parts = tmpl["name"].split("_")
    face_id = name_parts[0]
    stand_dir = "_".join(name_parts[1:]) if len(name_parts) > 1 else "stand_0_0"
    ref_key = next(fn for fn in data["frames"] if face_id.lower() in fn.lower() and stand_dir in fn)
    info = data["frames"][ref_key]
    frame = info.get("frame", info)
    ox, oy = frame["x"], frame["y"]
    offset_x, offset_y = tmpl.get("crop_offset", [0, 0])
    original = atlas.crop((ox + offset_x, oy + offset_y, ox + offset_x + w, oy + offset_y + h))
    orig_px = original.load()

    eye_region = [k for k in ("eyes_brows", "eyes_brows_ears", "eyes") if k in tmpl["pixels"]]
    eye_region = eye_region[0] if eye_region else None
    mouth_region = "accessory" if "accessory" in tmpl["pixels"] else "mouth"

    eye_px = eye_img.load()
    for xc, yc in tmpl["pixels"].get(eye_region, []):
        eye_px[xc, yc] = orig_px[xc, yc]

    mouth_px = mouth_img.load()
    for xc, yc in tmpl["pixels"].get(mouth_region, []):
        mouth_px[xc, yc] = orig_px[xc, yc]

    # Also extend eye/mouth by 1 pixel for blending
    for xc in range(w):
        for yc in range(h):
            c = orig_px[xc, yc]
            if c[3] < 16:
                continue
            # Check if adjacent to eye/mouth
            for dx, dy in [(1,0),(-1,0),(0,1),(0,-1)]:
                nx, ny = xc + dx, yc + dy
                if 0 <= nx < w and 0 <= ny < h:
                    eye_pixels = tmpl["pixels"].get(eye_region, [])
                    if any((nx, ny) == tuple(ep) for ep in eye_pixels):
                        if eye_px[xc, yc][3] < 16:
                            eye_px[xc, yc] = (c[0], c[1], c[2], 200)
                    mouth_pixels = tmpl["pixels"].get(mouth_region, [])
                    if any((nx, ny) == tuple(mp) for mp in mouth_pixels):
                        if mouth_px[xc, yc][3] < 16:
                            mouth_px[xc, yc] = (c[0], c[1], c[2], 200)

    return eye_img, mouth_img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    print("Loading template...")
    tmpl = load_template()
    print(f"  Size: {tmpl['width']}x{tmpl['height']}")
    print(f"  Regions: {tmpl['count']}")

    seeds = [42, 43, 44, 45, 46]
    prompts = [
        "RO character face, game pixel art style, cute anime portrait",
        "anime game character portrait, pixel art face, cute expression",
        "retro game character face, pixel art style portrait",
        "pixel art character portrait, game sprite face, cute anime style",
        "Ragnarok Online style face, pixel art character portrait",
    ]
    for idx, (seed, prompt) in enumerate(zip(seeds, prompts)):
        print(f"\n{'='*50}")
        print(f"Generating [{idx+1}/{len(seeds)}]: seed={seed}")
        print(f"{'='*50}")

        try:
            ai_img = generate_ai_reference(prompt, seed=seed)
            ai_ref_path = os.path.join(OUT_DIR, f"face_ai_ref_{seed}.png")
            ai_img.save(ai_ref_path)
            print(f"Saved AI ref ({ai_img.size}, mode={ai_img.mode}): {ai_ref_path}")
        except Exception as e:
            print(f"AI generation failed: {e}")
            import traceback
            traceback.print_exc()
            continue

        try:
            print("Extracting per-region colors...")
            region_colors = extract_per_region_colors(ai_img, tmpl)
            print(f"  Palettes: {', '.join([f'{k}={len(v)}' for k,v in region_colors.items()])}")
        except Exception as e:
            print(f"Color extraction failed: {e}")
            import traceback
            traceback.print_exc()
            continue

        try:
            print("Applying palette to template...")
            output = apply_palette_to_template(tmpl, region_colors)
            out_path = os.path.join(OUT_DIR, f"face_component_{seed}.png")
            output.save(out_path)

            # Count output colors
            px = output.load()
            colors = set()
            for xc in range(tmpl["width"]):
                for yc in range(tmpl["height"]):
                    c = px[xc, yc]
                    if len(c) > 3 and c[3] > 16:
                        colors.add((c[0], c[1], c[2]))
            print(f"  Saved component: {len(colors)} unique colors")
        except Exception as e:
            print(f"Palette application failed: {e}")
            import traceback
            traceback.print_exc()
            continue

        try:
            eye_img, mouth_img = create_eye_mouth_masks(tmpl)
            eye_img.save(os.path.join(OUT_DIR, f"face_eye_{seed}.png"))
            mouth_img.save(os.path.join(OUT_DIR, f"face_mouth_{seed}.png"))

            # Extract ears as separate image (use original face colors)
            atlas2 = Image.open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.png")).convert("RGBA")
            with open(os.path.join(ROOT, "assets", "img", "face", "face.atlas.json")) as f:
                data2 = json.load(f)
            name_parts2 = tmpl["name"].split("_")
            face_id2 = name_parts2[0]
            stand_dir2 = "_".join(name_parts2[1:]) if len(name_parts2) > 1 else "stand_0_0"
            ref_key2 = next(fn for fn in data2["frames"] if face_id2.lower() in fn.lower() and stand_dir2 in fn)
            info2 = data2["frames"][ref_key2]
            frame2 = info2.get("frame", info2)
            ox2, oy2 = frame2["x"], frame2["y"]
            offset_x2, offset_y2 = tmpl.get("crop_offset", [0, 0])
            original2 = atlas2.crop((ox2 + offset_x2, oy2 + offset_y2, ox2 + offset_x2 + tmpl["width"], oy2 + offset_y2 + tmpl["height"]))
            orig2_px = original2.load()
            ear_img = Image.new("RGBA", (tmpl["width"], tmpl["height"]), (0, 0, 0, 0))
            ear_px = ear_img.load()
            if "ears" in tmpl["pixels"]:
                for xc, yc in tmpl["pixels"]["ears"]:
                    ear_px[xc, yc] = orig2_px[xc, yc]
            ear_img.save(os.path.join(OUT_DIR, f"face_ear_{seed}.png"))
            print(f"  Ear image saved")

            atlas_out = Image.new("RGBA", (tmpl["width"] * 4, tmpl["height"]), (0, 0, 0, 0))
            atlas_out.paste(output, (0, 0))
            atlas_out.paste(eye_img, (tmpl["width"], 0))
            atlas_out.paste(ear_img, (tmpl["width"] * 2, 0))
            atlas_out.paste(mouth_img, (tmpl["width"] * 3, 0))
            atlas_out.save(os.path.join(OUT_DIR, f"face_atlas_component_{seed}.png"))
            print(f"  Atlas saved")
        except Exception as e:
            print(f"Masks/atlas failed: {e}")
            import traceback
            traceback.print_exc()

    print(f"\nDone! Output in: {OUT_DIR}")


if __name__ == "__main__":
    main()
