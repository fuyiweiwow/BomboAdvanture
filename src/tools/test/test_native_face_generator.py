import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from src.tools.test.native_face_generator import (
    FRAME_COUNT,
    LAYERS,
    generate_face_catalog,
)


class NativeFaceGeneratorTests(unittest.TestCase):
    def test_catalog_emits_complete_component_contract(self):
        with tempfile.TemporaryDirectory(prefix="native_face_contract_") as temp_dir:
            manifest = generate_face_catalog(Path(temp_dir), seed=20260727)

            self.assertEqual(manifest["source"], "procedural_local")
            self.assertEqual(manifest["frame_count"], FRAME_COUNT)
            self.assertEqual(manifest["generator_version"], "native_face_v1")
            self.assertEqual(set(manifest["layers"]), set(LAYERS))

            for layer in LAYERS:
                files = sorted((Path(temp_dir) / layer).glob("*.png"))
                self.assertEqual(len(files), FRAME_COUNT)
                with Image.open(files[0]) as image:
                    self.assertEqual(image.size, (36, 34))
                    self.assertEqual(image.mode, "RGBA")

    def test_same_seed_reproduces_every_layer_byte_for_byte(self):
        with tempfile.TemporaryDirectory(prefix="native_face_repro_a_") as first_dir:
            with tempfile.TemporaryDirectory(prefix="native_face_repro_b_") as second_dir:
                generate_face_catalog(Path(first_dir), seed=17)
                generate_face_catalog(Path(second_dir), seed=17)

                for layer in LAYERS:
                    first = sorted((Path(first_dir) / layer).glob("*.png"))
                    second = sorted((Path(second_dir) / layer).glob("*.png"))
                    self.assertEqual([path.name for path in first], [path.name for path in second])
                    for left, right in zip(first, second):
                        self.assertEqual(left.read_bytes(), right.read_bytes(), left.name)

    def test_different_seed_changes_face_pixels_and_keeps_provenance_local(self):
        with tempfile.TemporaryDirectory(prefix="native_face_seed_a_") as first_dir:
            with tempfile.TemporaryDirectory(prefix="native_face_seed_b_") as second_dir:
                first_manifest = generate_face_catalog(Path(first_dir), seed=1)
                second_manifest = generate_face_catalog(Path(second_dir), seed=2)

                self.assertNotEqual(first_manifest["seed"], second_manifest["seed"])
                self.assertEqual(first_manifest["source"], "procedural_local")
                self.assertEqual(second_manifest["source"], "procedural_local")
                first_hash = hashlib.sha256(
                    (Path(first_dir) / "composite" / "face_round_01_stand_D_0.png").read_bytes()
                ).hexdigest()
                second_hash = hashlib.sha256(
                    (Path(second_dir) / "composite" / "face_round_01_stand_D_0.png").read_bytes()
                ).hexdigest()
                self.assertNotEqual(first_hash, second_hash)

    def test_directional_layers_follow_face_contract(self):
        with tempfile.TemporaryDirectory(prefix="native_face_directions_") as temp_dir:
            generate_face_catalog(Path(temp_dir), seed=9)

            front_eye = Path(temp_dir) / "eye" / "face_round_01_stand_D_0.png"
            back_eye = Path(temp_dir) / "eye" / "face_round_01_stand_U_0.png"
            front_brow = Path(temp_dir) / "brow" / "face_round_01_stand_D_0.png"
            back_brow = Path(temp_dir) / "brow" / "face_round_01_stand_U_0.png"

            with Image.open(front_eye) as image:
                self.assertIsNotNone(image.getbbox())
            with Image.open(front_brow) as image:
                self.assertIsNotNone(image.getbbox())
            with Image.open(back_eye) as image:
                self.assertIsNone(image.getbbox())
            with Image.open(back_brow) as image:
                self.assertIsNone(image.getbbox())

    def test_manifest_contains_frame_hashes_without_reference_paths(self):
        with tempfile.TemporaryDirectory(prefix="native_face_manifest_") as temp_dir:
            manifest = generate_face_catalog(Path(temp_dir), seed=3)
            manifest_path = Path(temp_dir) / "manifest.json"
            stored = json.loads(manifest_path.read_text(encoding="utf-8"))

            self.assertEqual(stored["source"], "procedural_local")
            self.assertNotIn("assets/img/face", json.dumps(stored))
            self.assertNotIn("face10101", json.dumps(stored))
            self.assertTrue(stored["frames"]["face_round_01_stand_D_0.png"]["sha256"])


if __name__ == "__main__":
    unittest.main()
