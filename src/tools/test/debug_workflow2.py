"""Debug: send exact workflow from ro_ai_gen to ComfyUI and check error."""
import sys, json, requests
sys.path.insert(0, r"E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test")
from ro_ai_gen import build_img2img_workflow

workflow, save_id = build_img2img_workflow(
    reference_image="ro_ref_face92001.png",
    prompt="test",
    negative_prompt="bad",
    denoise=0.65,
)

payload = {"prompt": workflow, "client_id": "debug2"}
resp = requests.post("http://127.0.0.1:8188/prompt", json=payload)
print(f"Status: {resp.status_code}")
print(json.dumps(resp.json(), indent=2))
