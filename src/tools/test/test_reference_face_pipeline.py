import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class ReferenceFacePipelineTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_front_selector_uses_original_direction_index_three(self):
        from src.tools.test.reference_face_pipeline import source_frame_name

        self.assertEqual(
            source_frame_name("face10101", "stand", "D", 0),
            "face10101_stand_3_0.png",
        )
        self.assertEqual(
            source_frame_name("face10101", "walk", "D", 2),
            "face10101_walk_3_2.png",
        )

    def test_reference_replay_preserves_curved_brow_and_layered_eye(self):
        from src.tools.test.reference_face_pipeline import (
            load_annotations,
            load_source_frame,
            build_reference_layers,
        )

        annotations = load_annotations()
        source = load_source_frame("male", "stand", "D", 0)
        result = build_reference_layers(source, annotations["stand_D_0"], normalize_front_ears=True)

        brow_points = {
            (x, y)
            for y in range(result.layers["brow"].height)
            for x in range(result.layers["brow"].width)
            if result.layers["brow"].getpixel((x, y))[3] > 0
        }
        eye_colors = {
            pixel
            for pixel in result.layers["eye"].get_flattened_data()
            if pixel[3] > 0
        }
        self.assertGreaterEqual(max(y for _, y in brow_points) - min(y for _, y in brow_points), 3)
        self.assertGreaterEqual(len(eye_colors), 4)
        self.assertTrue(result.reference_mismatch == 0)

        ear_points = {
            (x, y)
            for y in range(result.layers["ear_normalized"].height)
            for x in range(result.layers["ear_normalized"].width)
            if result.layers["ear_normalized"].getpixel((x, y))[3] > 0
        }
        self.assertEqual(
            ear_points,
            {(source.width - 1 - x, y) for x, y in ear_points},
        )

    def test_catalog_keeps_exact_sizes_for_front_and_motion_frames(self):
        from src.tools.test.reference_face_pipeline import generate_reference_catalog

        with TemporaryDirectory(prefix="face_reference_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_reference_catalog(output, role="male")

            self.assertEqual(manifest["generator_version"], "reference_face_pipeline_v1")
            self.assertEqual(manifest["role"], "male")
            self.assertEqual(manifest["frame_count"], 28)
            self.assertEqual(manifest["front_frame"], "stand_D_0")
            self.assertTrue((output / "male" / "stand_D_0" / "composite.png").is_file())

            with Image.open(output / "male" / "stand_D_0" / "composite.png") as front:
                self.assertEqual(front.size, (36, 34))
            with Image.open(output / "male" / "walk_D_2" / "composite.png") as motion:
                self.assertEqual(motion.size, (33, 34))

            persisted = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["reference_mismatch_pixels"], 0)


if __name__ == "__main__":
    unittest.main()
