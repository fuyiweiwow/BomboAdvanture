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
            self.assertEqual(manifest["generator_version"], "native_face_v3")
            self.assertEqual(set(manifest["layers"]), set(LAYERS))

            for layer in LAYERS:
                files = sorted((Path(temp_dir) / layer).glob("*.png"))
                self.assertEqual(len(files), FRAME_COUNT)
                with Image.open(files[0]) as image:
                    self.assertEqual(image.size, (36, 34))
                    self.assertEqual(image.mode, "RGBA")

    def test_q_face_keeps_mouth_slot_empty_and_eyes_large(self):
        with tempfile.TemporaryDirectory(prefix="native_face_v3_style_") as temp_dir:
            manifest = generate_face_catalog(Path(temp_dir), seed=0)

            self.assertEqual(manifest["factors"]["mouth_status"], "reserved_decoration_only")
            self.assertEqual(manifest["style_contract"]["face_language"], "western_fantasy_chibi")
            self.assertEqual(manifest["style_contract"]["eye_scale"], "large")

            eye_path = Path(temp_dir) / "eye" / "face_round_01_stand_D_0.png"
            mouth_path = Path(temp_dir) / "mouth" / "face_round_01_stand_D_0.png"
            with Image.open(eye_path) as eye:
                bbox = eye.getbbox()
                self.assertIsNotNone(bbox)
                self.assertGreaterEqual(bbox[2] - bbox[0], 23)
                self.assertGreaterEqual(bbox[3] - bbox[1], 11)
                self.assertGreaterEqual(sum(1 for pixel in eye.getdata() if pixel[3] > 0), 100)
            with Image.open(mouth_path) as mouth:
                self.assertIsNone(mouth.getbbox())

    def test_hd_output_doubles_logical_pixel_distribution(self):
        with tempfile.TemporaryDirectory(prefix="native_face_v3_hd_") as temp_dir:
            manifest = generate_face_catalog(Path(temp_dir), seed=0, pixel_scale=2)

            self.assertEqual(manifest["pixel_scale"], 2)
            self.assertEqual(manifest["logical_size"], {"width": 36, "height": 34})
            self.assertEqual(manifest["size"], {"width": 72, "height": 68})
            for layer in LAYERS:
                path = Path(temp_dir) / layer / "face_round_01_stand_D_0.png"
                with Image.open(path) as image:
                    self.assertEqual(image.size, (72, 68))

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

    def test_ear_factors_are_recorded_and_visible_ear_is_rendered(self):
        with tempfile.TemporaryDirectory(prefix="native_face_ears_") as temp_dir:
            manifest = generate_face_catalog(Path(temp_dir), seed=0)

            factors = manifest["factors"]
            self.assertEqual(factors["ear_type"], "human")
            self.assertIn(factors["size"], {"small", "medium", "large"})
            self.assertIn(factors["angle"], {"down", "neutral", "up"})
            self.assertIn(factors["point"], {"round", "soft_point", "pointed"})
            self.assertIn(factors["inner_color"], {"warm_rose", "soft_coral", "deep_pink"})
            self.assertIn(factors["visibility"], {"full", "subtle", "hidden"})

            ear_path = Path(temp_dir) / "ear" / "face_round_01_stand_D_0.png"
            with Image.open(ear_path) as image:
                self.assertIsNotNone(image.getbbox())

    def test_ear_seed_changes_pixels_and_hidden_visibility_is_empty(self):
        with tempfile.TemporaryDirectory(prefix="native_face_ear_seed_a_") as first_dir:
            with tempfile.TemporaryDirectory(prefix="native_face_ear_seed_b_") as second_dir:
                first = generate_face_catalog(Path(first_dir), seed=0)
                second = generate_face_catalog(Path(second_dir), seed=1)

                self.assertNotEqual(first["factors"]["size"], second["factors"]["size"])
                first_ear = Path(first_dir) / "ear" / "face_round_01_stand_D_0.png"
                second_ear = Path(second_dir) / "ear" / "face_round_01_stand_D_0.png"
                self.assertNotEqual(first_ear.read_bytes(), second_ear.read_bytes())

        with tempfile.TemporaryDirectory(prefix="native_face_ear_hidden_") as temp_dir:
            manifest = generate_face_catalog(Path(temp_dir), seed=162)
            self.assertEqual(manifest["factors"]["visibility"], "hidden")
            ear_path = Path(temp_dir) / "ear" / "face_round_01_stand_D_0.png"
            with Image.open(ear_path) as image:
                self.assertIsNone(image.getbbox())

    def test_composite_keeps_head_in_front_of_ear_overlap(self):
        with tempfile.TemporaryDirectory(prefix="native_face_ear_order_") as temp_dir:
            generate_face_catalog(Path(temp_dir), seed=0)

            base_path = Path(temp_dir) / "base" / "face_round_01_stand_D_0.png"
            ear_path = Path(temp_dir) / "ear" / "face_round_01_stand_D_0.png"
            composite_path = Path(temp_dir) / "composite" / "face_round_01_stand_D_0.png"
            with Image.open(base_path) as base, Image.open(ear_path) as ear, Image.open(composite_path) as composite:
                overlap = 0
                for coordinate in ((x, y) for y in range(34) for x in range(36)):
                    if base.getpixel(coordinate)[3] and ear.getpixel(coordinate)[3]:
                        overlap += 1
                        self.assertEqual(composite.getpixel(coordinate), base.getpixel(coordinate))
                self.assertGreater(overlap, 0)

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
