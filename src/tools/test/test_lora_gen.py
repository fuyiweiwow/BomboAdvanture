"""Test generation with trained LoRA weights."""
import os
os.environ["HF_HOME"] = r"E:\env\temp\hf_cache"
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

import torch
from diffusers import StableDiffusionPipeline
from peft import PeftModel

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
LORA_PATH = os.path.join(ROOT, "assets", "train", "face_lora", "lora_weights", "ro_face_lora.safetensors")

print("Loading base model...")
pipe = StableDiffusionPipeline.from_pretrained(
    "hakurei/waifu-diffusion",
    torch_dtype=torch.float16,
    safety_checker=None,
)
pipe.to("cuda")
pipe.enable_attention_slicing()

# Load LoRA using PEFT directly
print("Loading LoRA via PEFT...")
import safetensors.torch
lora_state = safetensors.torch.load_file(LORA_PATH)
pipe.unet = PeftModel.from_pretrained(pipe.unet, LORA_PATH)
print(f"LoRA applied! Trainable params: {sum(p.numel() for p in pipe.unet.parameters() if p.requires_grad):,}")

# Test prompts
prompts = [
    "pixel art chibi face, looking right, ro-face style",
    "pixel art chibi face with short spiky hair, looking right, ro-face style",
    "pixel art chibi face with long flowing hair, looking forward, ro-face style",
    "pixel art chibi face with twin tail pigtails, looking right, ro-face style",
]

for i, prompt in enumerate(prompts):
    print(f"Generating {i+1}/{len(prompts)}: {prompt[:50]}...")
    with torch.inference_mode():
        image = pipe(
            prompt,
            num_inference_steps=20,
            height=256,
            width=256,
            cross_attention_kwargs={"scale": 1.0},
        ).images[0]
    out_path = os.path.join(ROOT, "assets", "train", "face_lora", f"test_lora_{i}.png")
    image.save(out_path)
    print(f"  Saved: {out_path}")

print("Done!")
