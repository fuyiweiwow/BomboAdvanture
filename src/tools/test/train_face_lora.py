"""Train LoRA on RO face frames using Counterfeit V3.0 base model.

Usage: python train_face_lora.py [--test-only]

Trains a LoRA that learns the RO pixel art face style.
After training, the LoRA weights are saved to assets/train/face_lora/lora_weights/
"""

import os, sys, json, math, random
os.environ["HF_HOME"] = r"E:\env\temp\hf_cache"
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HUGGINGFACE_HUB_CACHE"] = r"E:\env\temp\hf_cache\hub"
os.makedirs(r"E:\env\temp\hf_cache", exist_ok=True)

import torch
from torch.utils.data import Dataset, DataLoader
from PIL import Image
from diffusers import StableDiffusionPipeline, DDPMScheduler, AutoencoderKL
from diffusers.optimization import get_scheduler
from diffusers.training_utils import cast_training_params
from transformers import CLIPTextModel, CLIPTokenizer
from peft import LoraConfig, get_peft_model, get_peft_model_state_dict
import accelerate

ROOT = r"E:\WorkProject\Bomb adventure\BomboAdvanture"
DATASET_DIR = os.path.join(ROOT, "assets", "train", "face_lora")
OUTPUT_DIR = os.path.join(ROOT, "assets", "train", "face_lora", "lora_weights")
os.makedirs(OUTPUT_DIR, exist_ok=True)

CKPT_PATH = "hakurei/waifu-diffusion"

TRAIN_RES = 256
BATCH_SIZE = 2
GRAD_ACCUM = 4
LR = 1e-4
MAX_STEPS = 800
LORA_RANK = 16
SEED = 42

class FaceDataset(Dataset):
    def __init__(self, image_dir, resolution=256):
        self.image_dir = image_dir
        self.resolution = resolution
        self.samples = []
        metadata_path = os.path.join(os.path.dirname(image_dir), "metadata.jsonl")
        if os.path.exists(metadata_path):
            with open(metadata_path) as f:
                for line in f:
                    item = json.loads(line)
                    self.samples.append(item)
        else:
            for fn in sorted(os.listdir(image_dir)):
                if fn.endswith(".png"):
                    fid = fn.split("_")[0]
                    self.samples.append({"file_name": fn, "text": "pixel art chibi face, ro-face style"})
        print(f"Dataset: {len(self.samples)} samples")

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        item = self.samples[idx]
        img = Image.open(os.path.join(self.image_dir, item["file_name"])).convert("RGB")
        img = img.resize((self.resolution, self.resolution), Image.NEAREST)
        import numpy as np
        arr = np.array(img).astype(np.float32) / 127.5 - 1.0
        img_tensor = torch.from_numpy(arr).permute(2, 0, 1)
        return {"pixel_values": img_tensor, "caption": item["text"]}

def collate_fn(batch):
    pixel_values = torch.stack([b["pixel_values"] for b in batch])
    captions = [b["caption"] for b in batch]
    return {"pixel_values": pixel_values, "captions": captions}

def main():
    test_only = "--test-only" in sys.argv

    # Create accelerator
    accelerator = accelerate.Accelerator(
        gradient_accumulation_steps=GRAD_ACCUM,
        mixed_precision="fp16",
    )

    device = accelerator.device
    weight_dtype = torch.float16

    print(f"Device: {device}, mixed_precision: fp16")

    # Load model
    print(f"Loading model: {CKPT_PATH}...")
    pipe = StableDiffusionPipeline.from_pretrained(
        CKPT_PATH,
        torch_dtype=weight_dtype,
        safety_checker=None,
    )
    pipe.to(device)
    pipe.enable_attention_slicing()

    if test_only:
        print("Test mode: generating sample...")
        with torch.inference_mode():
            image = pipe("pixel art chibi face, looking right, ro-face style",
                        num_inference_steps=15, height=256, width=256).images[0]
        image.save(os.path.join(OUTPUT_DIR, "..", "test_before_lora.png"))
        print("Saved. LoRA training can proceed.")
        return

    # Freeze VAE and text encoder, move to device
    pipe.vae.requires_grad_(False)
    pipe.text_encoder.requires_grad_(False)
    pipe.vae.to(device, dtype=weight_dtype)
    pipe.text_encoder.to(device, dtype=weight_dtype)

    # Set up LoRA on UNet
    lora_config = LoraConfig(
        r=LORA_RANK,
        lora_alpha=LORA_RANK,
        target_modules=["to_q", "to_k", "to_v", "to_out.0", "ff.net.0.proj", "ff.net.2"],
        lora_dropout=0.1,
        bias="none",
    )
    pipe.unet = get_peft_model(pipe.unet, lora_config)
    pipe.unet.train()

    print(f"LoRA params: {sum(p.numel() for p in pipe.unet.parameters() if p.requires_grad):,}")

    # Dataset
    dataset = FaceDataset(os.path.join(DATASET_DIR, "images"), TRAIN_RES)
    dataloader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True, collate_fn=collate_fn, num_workers=0)

    # Optimizer
    params = [p for p in pipe.unet.parameters() if p.requires_grad]
    optimizer = torch.optim.AdamW(params, lr=LR)

    # LR scheduler
    lr_scheduler = get_scheduler(
        "cosine",
        optimizer=optimizer,
        num_warmup_steps=100,
        num_training_steps=MAX_STEPS,
    )

    # Prepare with accelerator
    pipe.unet, dataloader, optimizer, lr_scheduler = accelerator.prepare(
        pipe.unet, dataloader, optimizer, lr_scheduler
    )

    # Noise scheduler
    noise_scheduler = DDPMScheduler(
        beta_start=0.00085, beta_end=0.012,
        beta_schedule="scaled_linear",
        num_train_timesteps=1000,
    )

    # Text embeddings for prompts
    tokenizer = pipe.tokenizer
    text_encoder = pipe.text_encoder

    global_step = 0
    while global_step < MAX_STEPS:
        for batch in dataloader:
            if global_step >= MAX_STEPS:
                break

            with accelerator.accumulate(pipe.unet):
                pixel_values = batch["pixel_values"].to(weight_dtype)
                bs = pixel_values.shape[0]

                # Encode captions
                tokens = tokenizer(batch["captions"], padding="max_length",
                                   max_length=tokenizer.model_max_length,
                                   truncation=True, return_tensors="pt")
                tokens = {k: v.to(device) for k, v in tokens.items()}
                encoder_hidden_states = text_encoder(**tokens)[0]

                # Encode to latent space with VAE
                with torch.no_grad():
                    latents = pipe.vae.encode(pixel_values).latent_dist.sample()
                    latents = latents * pipe.vae.config.scaling_factor

                # Add noise
                noise = torch.randn_like(latents)
                timesteps = torch.randint(0, noise_scheduler.config.num_train_timesteps,
                                          (bs,), device=device).long()
                noisy_latents = noise_scheduler.add_noise(latents, noise, timesteps)

                # Predict noise
                noise_pred = pipe.unet(noisy_latents, timesteps,
                                       encoder_hidden_states).sample
                loss = torch.nn.functional.mse_loss(noise_pred.float(), noise.float())

                accelerator.backward(loss)

                if accelerator.sync_gradients:
                    accelerator.clip_grad_norm_(pipe.unet.parameters(), 1.0)

                optimizer.step()
                lr_scheduler.step()
                optimizer.zero_grad()

            global_step += 1
            if global_step % 50 == 0:
                print(f"Step {global_step}/{MAX_STEPS} loss={loss.item():.6f}")

    # Save LoRA in diffusers-compatible format
    accelerator.wait_for_everyone()
    unwrapped = accelerator.unwrap_model(pipe.unet)
    lora_state = get_peft_model_state_dict(unwrapped)

    # Re-key with "unet." prefix for diffusers format
    diffusers_state = {}
    for k, v in lora_state.items():
        new_k = k.replace("base_model.model.", "unet.")
        diffusers_state[new_k] = v

    # Save as safetensors
    import safetensors.torch
    safetensors.torch.save_file(diffusers_state, os.path.join(OUTPUT_DIR, "ro_face_lora.safetensors"))

    # Save adapter config
    lora_config.save_pretrained(OUTPUT_DIR)
    print(f"LoRA saved to {OUTPUT_DIR}")

    # Test generation
    print("Generating test image...")
    pipe.unet.eval()
    with torch.inference_mode():
        image = pipe("pixel art chibi face, looking right, ro-face style",
                    num_inference_steps=15, height=256, width=256).images[0]
    image.save(os.path.join(OUTPUT_DIR, "..", "test_after_lora.png"))
    print("Done!")

if __name__ == "__main__":
    main()
