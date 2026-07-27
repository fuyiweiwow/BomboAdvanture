import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from src.tools.test.native_face_3d_generator import (
    DIRECTIONS,
    LAYERS,
    MODEL_VARIANTS,
    RENDER_SIZE,
    generate_3d_face_catalog,
)


class NativeFace3DGeneratorTests(unittest.TestCase):
    def test_catalog_writes_original_male_and_female_obj_models(self):
        with tempfile.TemporaryDirectory(prefix="native_face_3d_models_") as temp_dir:
            manifest = generate_3d_face_catalog(Path(temp_dir), seed=20260727)

            self.assertEqual(manifest["generator_version"], "native_face_3d_v2")
            self.assertEqual(manifest["source"], "imported_local_cc0_base")
            self.assertEqual(manifest["source_license"], "CC0-1.0")
            self.assertEqual(manifest["source_pack"], "kenney_mini_characters")
            self.assertEqual(manifest["reference_inputs"], [])
            self.assertEqual(set(manifest["variants"]), set(MODEL_VARIANTS))
            self.assertEqual(manifest["source_models"]["male"], "character-male-a.glb")
            self.assertEqual(manifest["source_models"]["female"], "character-female-a.glb")

            for variant in MODEL_VARIANTS:
                obj_path = Path(temp_dir) / "models" / f"native_chibi_{variant}.obj"
                mtl_path = Path(temp_dir) / "models" / f"native_chibi_{variant}.mtl"
                obj_text = obj_path.read_text(encoding="utf-8")
                self.assertTrue(obj_path.exists())
                self.assertTrue(mtl_path.exists())
                self.assertGreater(obj_text.count("\nv "), 100)
                self.assertGreater(obj_text.count("\nf "), 100)
                self.assertIn("usemtl skin", obj_text)
                self.assertNotIn("assets/img/face", obj_text)
                self.assertNotIn("face10101", obj_text)

    def test_four_directions_emit_layered_preview_without_mouth_or_neck(self):
        with tempfile.TemporaryDirectory(prefix="native_face_3d_preview_") as temp_dir:
            manifest = generate_3d_face_catalog(Path(temp_dir), seed=17)

            self.assertEqual(manifest["logical_size"], {"width": 36, "height": 34})
            self.assertEqual(manifest["render_size"], {"width": 72, "height": 68})
            self.assertEqual(manifest["style_contract"]["neck"], "source_preserved")
            self.assertEqual(manifest["style_contract"]["face_language"], "western_fantasy_chibi")
            self.assertEqual(manifest["style_contract"]["body_proportion"], "chibi_exaggerated")

            for variant in MODEL_VARIANTS:
                for direction in DIRECTIONS:
                    for layer in LAYERS:
                        path = Path(temp_dir) / "renders" / variant / layer / f"{variant}_{direction}.png"
                        self.assertTrue(path.exists(), path)
                        with Image.open(path) as image:
                            self.assertEqual(image.size, RENDER_SIZE)
                            self.assertEqual(image.mode, "RGBA")

                    composite_path = Path(temp_dir) / "renders" / variant / "composite" / f"{variant}_{direction}.png"
                    mouth_path = Path(temp_dir) / "renders" / variant / "mouth" / f"{variant}_{direction}.png"
                    with Image.open(composite_path) as composite:
                        self.assertIsNotNone(composite.getbbox())
                    with Image.open(mouth_path) as mouth:
                        self.assertIsNone(mouth.getbbox())

            stored = json.loads((Path(temp_dir) / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(stored["source"], "procedural_local_3d")
            self.assertEqual(stored["variants"], list(MODEL_VARIANTS))


if __name__ == "__main__":
    unittest.main()
