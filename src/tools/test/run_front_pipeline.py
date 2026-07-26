"""
Front face pipeline wrapper.
Sets FACE_TEMPLATE=front and FACE_OUT_DIR to call the main v5 pipeline.
"""
import os, sys, subprocess

BASE = "E:/WorkProject/Bomb adventure/BomboAdvanture"
PIPELINE = f"{BASE}/src/tools/test/ro_pipeline_v5.py"
OUT_DIR = f"{BASE}/assets/test/ro_component_v5_front"

os.makedirs(OUT_DIR, exist_ok=True)

env = os.environ.copy()
env["FACE_TEMPLATE"] = "front"
env["FACE_OUT_DIR"] = OUT_DIR

subprocess.run([sys.executable, PIPELINE], env=env)
