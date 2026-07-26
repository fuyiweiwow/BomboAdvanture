import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class RandomFacePipelineTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_seeded_catalog_is_reproducible_and_contains_multiple_variants(self):
        from src.tools.test.random_face_pipeline import generate_random_faces

        with TemporaryDirectory(prefix="random_faces_a_", dir=self.project_root / "assets" / "test") as first_dir:
            with TemporaryDirectory(prefix="random_faces_b_", dir=self.project_root / "assets" / "test") as second_dir:
                first = generate_random_faces(Path(first_dir), count=6, seed=20260727)
                second = generate_random_faces(Path(second_dir), count=6, seed=20260727)
                self.assertEqual(first["factors"], second["factors"])
                self.assertEqual(first["sample_count"], 6)

                first_bytes = []
                second_bytes = []
                for sample in first["samples"]:
                    first_path = Path(first_dir) / sample["id"] / "composite.png"
                    second_path = Path(second_dir) / sample["id"] / "composite.png"
                    first_bytes.append(first_path.read_bytes())
                    second_bytes.append(second_path.read_bytes())
                    self.assertEqual(first_path.read_bytes(), second_path.read_bytes())
                    with Image.open(first_path) as image:
                        self.assertEqual(image.size, (36, 34))
                self.assertGreater(len(set(first_bytes)), 1)
                self.assertEqual(first_bytes, second_bytes)

    def test_random_faces_keep_reference_ears_and_record_factor_ranges(self):
        from src.tools.test.random_face_pipeline import generate_random_faces

        with TemporaryDirectory(prefix="random_faces_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_random_faces(output, count=4, seed=7)
            self.assertEqual(manifest["source_frame"], "stand_D_0")
            self.assertEqual(manifest["generator_version"], "random_face_pipeline_v1")
            self.assertEqual(len(manifest["factors"]), 4)
            self.assertTrue(all(sample["factors"]["ear"] == "reference" for sample in manifest["samples"]))
            self.assertTrue(all(-1 <= sample["factors"]["brow_curve"] <= 1 for sample in manifest["samples"]))
            self.assertTrue(all(0.85 <= sample["factors"]["eye_scale_y"] <= 1.15 for sample in manifest["samples"]))
            self.assertTrue((output / "random_faces_preview.png").is_file())

            persisted = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["sample_count"], 4)


if __name__ == "__main__":
    unittest.main()
