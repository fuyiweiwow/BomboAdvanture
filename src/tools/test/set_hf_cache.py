import os
hf_home = r"E:\env\temp\hf_cache"
os.environ["HF_HOME"] = hf_home
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
os.environ["HUGGINGFACE_HUB_CACHE"] = os.path.join(hf_home, "hub")
os.makedirs(hf_home, exist_ok=True)
print(f"HF_HOME set to: {hf_home}")
# Set huggingface_hub config
from huggingface_hub import constants
constants.default_folder_path = hf_home
# Verify
print(f"Cache: {os.path.join(hf_home, 'hub')}")
print(f"Disk free: {__import__('shutil').disk_usage(hf_home).free / 1e9:.1f} GB")
