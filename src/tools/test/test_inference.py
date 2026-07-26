"""Quick inference test - Counterfeit V3.0"""
import os
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["TEMP"] = r"E:\env\temp"
os.environ["TMP"] = r"E:\env\temp"

import torch
from diffusers import StableDiffusionPipeline

ckpt = r"E:\env\ComfyUI\models\checkpoints\Counterfeit-V3.0_fp16.safetensors"

print("Loading model...")
pipe = StableDiffusionPipeline.from_single_file(
    ckpt,
    torch_dtype=torch.float16,
    load_safety_checker=False,
)
print("Moving to GPU...")
pipe = pipe.to("cuda")
pipe.enable_attention_slicing()

print("Generating...")
with torch.inference_mode():
    image = pipe(
        "pixel art chibi face, looking right",
        num_inference_steps=15,
        height=256,
        width=256,
    ).images[0]

print(f"Done: {image.size}")
image.save(r"E:\env\temp\test_lora_gen.png")
print("Saved!")
