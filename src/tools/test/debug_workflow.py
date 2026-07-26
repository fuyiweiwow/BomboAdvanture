"""Debug workflow output from ro_ai_gen."""
import sys, json
sys.path.insert(0, r"E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test")
from ro_ai_gen import build_img2img_workflow

workflow, save_id = build_img2img_workflow(
    reference_image="ro_ref_face92001.png",
    prompt="test",
    negative_prompt="bad",
    denoise=0.65,
)

for nid in sorted(workflow.keys()):
    node = workflow[nid]
    print(f"Node {nid}: {node['class_type']}")
    for k, v in node["inputs"].items():
        print(f"  {k}: {v}")
    print()
