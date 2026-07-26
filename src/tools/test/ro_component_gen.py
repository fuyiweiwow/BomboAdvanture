"""
Component-based RO face generator.

Pipeline:
1. Load existing RO face as template + extract region masks (hair, skin)
2. AI generates reference image (waifu-diffusion + LoRA)
3. Extract per-region color palettes from AI reference
4. Recolor template by region → clean face (no eyes/mouth)
5. Package as atlas + frame JSON
"""

import os, sys, json, math
from PIL import Image
from collections import defaultdict

os.environ["HF_HOME"] = r"E:\env\temp\hf_cache"
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

import torch
from diffusers import StableDiffusionPipeline

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
SRC_FACE = os.path.join(ROOT, "assets", "img", "face")
OUT = os.path.join(ROOT, "assets", "test", "ro_component")
LORA_DIR = os.path.join(ROOT, "assets", "train", "face_lora", "lora_weights")
os.makedirs(OUT, exist_ok=True)


def load_template(atlas, atlas_data, src_face):
    """Load all 28 frames of a face + extract region masks."""
    frames = {}
    for fn, info in atlas_data.get("frames", {}).items():
        prefix = fn.split("_")[0]
        if prefix.lower() == src_face.lower():
            key = "_".join(fn.replace(".png", "").split("_")[1:])
            frame = info.get("frame", info)
            x, y, w, h = frame["x"], frame["y"], frame["w"], frame["h"]
            img = atlas.crop((x, y, x + w, y + h))
            frames[key] = {"img": img, "x": x, "y": y, "w": w, "h": h}
    return frames


def build_region_masks(img, eye_removal=True):
    """
    Build pixel-accurate hair/skin masks for a face frame.
    Returns: hair_mask (PIL 'L'), skin_mask (PIL 'L'), eye_mask (PIL 'L')
    """
    w, h = img.size
    px = img.load()

    hair_mask = Image.new("L", (w, h), 0)
    skin_mask = Image.new("L", (w, h), 0)
    eye_mask = Image.new("L", (w, h), 0)
    hpx = hair_mask.load()
    spx = skin_mask.load()
    epx = eye_mask.load()

    # Analyze luminance distribution to find skin/hair threshold
    all_lums = []
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] > 16:
                lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
                all_lums.append((lum, x, y))

    if not all_lums:
        return hair_mask, skin_mask, eye_mask

    # Split upper/lower to find typical hair vs skin luminance
    upper_lums = [l for l, x, y in all_lums if y < h * 0.4]
    lower_lums = [l for l, x, y in all_lums if y >= h * 0.4]

    upper_avg = sum(upper_lums) / len(upper_lums) if upper_lums else 0
    lower_avg = sum(lower_lums) / len(lower_lums) if lower_lums else 0

    # Hair is typically darker than skin
    mid_threshold = (upper_avg + lower_avg) / 2

    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 16:
                continue
            lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]

            if lum < mid_threshold:
                hpx[x, y] = 255
            else:
                spx[x, y] = 255

    # Detect and mask eyes/mouth as small dark islands in face region
    if eye_removal:
        face_zone_ymin = int(h * 0.35)
        face_zone_ymax = int(h * 0.85)
        for y in range(face_zone_ymin, face_zone_ymax):
            for x in range(w):
                if spx[x, y] == 255:
                    c = px[x, y]
                    lum = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
                    if lum < 100:
                        epx[x, y] = 255
                        spx[x, y] = 0

    return hair_mask, skin_mask, eye_mask


def extract_region_palettes(ai_img, hair_mask, skin_mask, n_hair=6, n_skin=4):
    """
    From an AI-generated pixel face, extract hair and skin color palettes
    using region masks.
    """
    ai_px = ai_img.load()
    w, h = ai_img.size

    hair_colors = []
    skin_colors = []

    for y in range(min(h, hair_mask.height)):
        for x in range(min(w, hair_mask.width)):
            c = ai_px[x, y]
            if c[3] > 16:
                r, g, b = c[0], c[1], c[2]
                if hair_mask.getpixel((x, y)) > 0:
                    hair_colors.append((r, g, b))
                elif skin_mask.getpixel((x, y)) > 0:
                    skin_colors.append((r, g, b))

    def quantize_palette(colors, n):
        if not colors:
            return []
        # Sort by luminance
        sorted_c = sorted(colors, key=lambda c: 0.299*c[0]+0.587*c[1]+0.114*c[2])
        n = min(n, len(sorted_c))
        bin_size = len(sorted_c) // n
        palette = []
        for i in range(n):
            start = i * bin_size
            end = (i + 1) * bin_size if i < n - 1 else len(sorted_c)
            bin_colors = sorted_c[start:end]
            avg = (
                sum(c[0] for c in bin_colors) // len(bin_colors),
                sum(c[1] for c in bin_colors) // len(bin_colors),
                sum(c[2] for c in bin_colors) // len(bin_colors),
            )
            palette.append(avg)
        return palette

    hair_palette = quantize_palette(hair_colors, n_hair)
    skin_palette = quantize_palette(skin_colors, n_skin)

    return hair_palette, skin_palette


def recolor_frame(orig_img, hair_mask, skin_mask, hair_palette, skin_palette):
    """
    Recolor a face frame using region-specific palettes.
    Each pixel is mapped to the closest color in its region's palette.
    """
    w, h = orig_img.size
    px = orig_img.load()
    result = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rpx = result.load()

    def closest_color(c, palette):
        best_dist = float("inf")
        best = c
        for pc in palette:
            dr = c[0] - pc[0]
            dg = c[1] - pc[1]
            db = c[2] - pc[2]
            dist = dr*dr + dg*dg + db*db
            if dist < best_dist:
                best_dist = dist
                best = pc
        return best

    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if c[3] < 16:
                continue
            nc = c
            if hair_mask.getpixel((x, y)) > 0 and hair_palette:
                nc = closest_color((c[0], c[1], c[2]), hair_palette)
            elif skin_mask.getpixel((x, y)) > 0 and skin_palette:
                nc = closest_color((c[0], c[1], c[2]), skin_palette)
            rpx[x, y] = (*nc, c[3])

    return result


def init_pipeline():
    print("Loading waifu-diffusion + LoRA...")
    pipe = StableDiffusionPipeline.from_pretrained(
        "hakurei/waifu-diffusion",
        torch_dtype=torch.float16,
        safety_checker=None,
    )
    pipe.to("cuda")
    pipe.enable_attention_slicing()
    lora_path = os.path.join(LORA_DIR, "ro_face_lora.safetensors")
    if os.path.exists(lora_path):
        pipe.load_lora_weights(LORA_DIR)
        print("  LoRA loaded!")
    return pipe


def generate_face_v2(
    pipe,
    prompt,
    face_id,
    src_face="face10101",
    gen_size=(512, 528),
    pixel_size=(64, 66),
):
    print(f"\n{'='*60}")
    print(f"Generating {face_id} (component-based)")
    print(f"  Prompt: {prompt}")
    print(f"  Source: {src_face}")
    print(f"{'='*60}")

    atlas = Image.open(os.path.join(SRC_FACE, "face.atlas.png")).convert("RGBA")
    with open(os.path.join(SRC_FACE, "face.atlas.json")) as f:
        atlas_data = json.load(f)

    frames = load_template(atlas, atlas_data, src_face)
    if not frames:
        print(f"  [ERR] No frames for {src_face}")
        return False

    # Use stand_0_0 as reference for region masks
    ref = frames.get("stand_0_0")
    if not ref:
        for k, v in frames.items():
            if "stand" in k:
                ref = v
                break
    if not ref:
        print(f"  [ERR] No reference frame")
        return False

    ref_img = ref["img"]
    hair_mask, skin_mask, eye_mask = build_region_masks(ref_img)
    print(f"  Template: {ref_img.size}, hair={sum(1 for y in range(hair_mask.height) for x in range(hair_mask.width) if hair_mask.getpixel((x,y))>0)}px, "
          f"skin={sum(1 for y in range(skin_mask.height) for x in range(skin_mask.width) if skin_mask.getpixel((x,y))>0)}px")
    print(f"  Eye/mouth pixels identified: {sum(1 for y in range(eye_mask.height) for x in range(eye_mask.width) if eye_mask.getpixel((x,y))>0)}")

    # Step 2: AI generate reference image
    print(f"  Generating AI reference...")
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

    # Downscale to pixel size
    pixel = gen_img.resize(pixel_size, Image.NEAREST)

    # Quantize to limited palette
    px = pixel.load()
    tw, th = pixel.size
    all_colors = []
    for y in range(th):
        for x in range(tw):
            c = px[x, y]
            if c[3] > 16:
                all_colors.append((c[0], c[1], c[2]))

    unique = list(set(all_colors))
    max_colors = 48
    if len(unique) > max_colors:
        colors_lum = [(c, 0.299*c[0]+0.587*c[1]+0.114*c[2]) for c in unique]
        colors_lum.sort(key=lambda x: x[1])
        n_bins = min(max_colors, len(unique))
        palette_map = {}
        for i in range(n_bins):
            start = int(i * len(colors_lum) / n_bins)
            end = int((i + 1) * len(colors_lum) / n_bins)
            bin_c = [c[0] for c in colors_lum[start:end]]
            if not bin_c:
                continue
            avg = (
                sum(c[0] for c in bin_c) // len(bin_c),
                sum(c[1] for c in bin_c) // len(bin_c),
                sum(c[2] for c in bin_c) // len(bin_c),
            )
            for c in bin_c:
                palette_map[c] = avg

        quant = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
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

    # Resize masks to match pixel size for palette extraction
    hair_mask_big = hair_mask.resize(pixel_size, Image.NEAREST)
    skin_mask_big = skin_mask.resize(pixel_size, Image.NEAREST)

    # Extract per-region palettes
    hair_palette, skin_palette = extract_region_palettes(pixel, hair_mask_big, skin_mask_big)
    print(f"  Hair palette: {len(hair_palette)} colors")
    print(f"  Skin palette: {len(skin_palette)} colors")

    out_dir = os.path.join(OUT, "face", face_id)
    os.makedirs(out_dir, exist_ok=True)

    # Save reference images
    pixel.save(os.path.join(out_dir, f"{face_id}_ai_ref_64x66.png"))

    # Build and save debug: region overlay
    debug_rgba = Image.new("RGBA", pixel_size, (0, 0, 0, 0))
    dpx = debug_rgba.load()
    for y in range(pixel_size[1]):
        for x in range(pixel_size[0]):
            c = pixel.getpixel((x, y))
            if c[3] > 16:
                if hair_mask_big.getpixel((x, y)) > 0:
                    dpx[x, y] = (*c[:3], 200)
                elif skin_mask_big.getpixel((x, y)) > 0:
                    dpx[x, y] = (*c[:3], 200)
    debug_rgba.save(os.path.join(out_dir, f"{face_id}_region_debug.png"))

    # Step 4: Recolor all 28 frames
    print(f"  Recoloring {len(frames)} frames...")
    dir_map = {"0": "R", "1": "U", "2": "L", "3": "D"}
    frame_out = {"NAME": face_id}
    for dk in ["STAND_R", "STAND_U", "STAND_L", "STAND_D", "R", "U", "L", "D"]:
        frame_out[dk] = {"IMG": [], "CX": [], "CY": []}

    # Load source frame data for CX/CY
    src_json = os.path.join(ROOT, "assets", "frame", "face", f"{src_face}.json")
    src_frame_data = None
    if os.path.exists(src_json):
        with open(src_json) as f:
            src_frame_data = json.load(f)

    for key, frame_info in frames.items():
        img = frame_info["img"]
        w, h = img.size

        # Build per-frame masks using same logic
        f_hair_mask, f_skin_mask, _ = build_region_masks(img, eye_removal=True)
        recolor = recolor_frame(img, f_hair_mask, f_skin_mask, hair_palette, skin_palette)

        out_fn = f"{face_id}_{key}.png"
        recolor.save(os.path.join(out_dir, out_fn))

        # Frame JSON mapping
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

    # Package atlas
    pngs = sorted([f for f in os.listdir(out_dir) if f.endswith(".png")
                   and "atlas" not in f and "ai_ref" not in f and "debug" not in f])
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


if __name__ == "__main__":
    configs = [
        ("male character with short spiky anime hair, angular face", "face95001", "face10101"),
        ("female character with long flowing hair, round face", "face95002", "face10201"),
        ("bald male character, shiny scalp", "face95003", "face10101"),
        ("male with beard and long wild hair", "face95004", "face10301"),
        ("female with twin tail pigtails", "face95005", "face10201"),
        ("female with bob cut hair and bangs", "face95006", "face10701"),
        ("male with mohawk hairstyle", "face95007", "face10301"),
        ("female with ponytail hair", "face95008", "face10201"),
    ]

    if len(sys.argv) > 1:
        if sys.argv[1] == "all":
            pipe = init_pipeline()
            for cfg in configs:
                generate_face_v2(pipe, *cfg)
        elif sys.argv[1].startswith("face"):
            pipe = init_pipeline()
            for prompt, fid, src in configs:
                if fid == sys.argv[1]:
                    generate_face_v2(pipe, prompt, fid, src)
                    break
        else:
            pipe = init_pipeline()
            generate_face_v2(pipe, sys.argv[1],
                             sys.argv[2] if len(sys.argv) > 2 else "face95999",
                             sys.argv[3] if len(sys.argv) > 3 else "face10101")
    else:
        pipe = init_pipeline()
        generate_face_v2(pipe, *configs[0])
