import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class RaceFaceSampleTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_generates_one_normal_36x34_face_per_race(self):
        from src.tools.test.generate_race_face_samples import generate_race_samples

        with TemporaryDirectory(prefix="face_race_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_race_samples(output, seed=20260727)
            self.assertEqual(manifest["races"], ["human", "elf", "orc"])
            self.assertEqual(manifest["sample_count"], 3)
            self.assertTrue((output / "manifest.json").is_file())
            for race in manifest["races"]:
                with Image.open(output / race / "composite.png") as composite:
                    self.assertEqual(composite.size, (36, 34))
                with Image.open(output / race / "preview.png") as preview:
                    self.assertEqual(preview.size, (144, 136))
                self.assertFalse(manifest["samples"][race]["warnings"])

            persisted = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["sample_count"], 3)

    def test_elf_ear_is_side_placed_and_orc_ear_is_top_placed(self):
        from src.tools.test.generate_race_face_samples import generate_race_samples

        with TemporaryDirectory(prefix="face_race_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            generate_race_samples(output, seed=20260727)
            with Image.open(output / "human" / "ear.png") as human_source:
                human_ear = human_source.convert("RGBA")
            human_pixels = sum(pixel[3] > 0 for pixel in human_ear.get_flattened_data())
            with Image.open(output / "elf" / "ear.png") as elf_source:
                elf_ear = elf_source.convert("RGBA")
            elf_pixels = sum(pixel[3] > 0 for pixel in elf_ear.get_flattened_data())
            with Image.open(output / "orc" / "ear.png") as orc_source:
                orc_ear = orc_source.convert("RGBA")
            orc_bbox = orc_ear.getbbox()
            self.assertGreater(elf_pixels, human_pixels)
            self.assertLess(orc_bbox[1], 14)
            self.assertGreater(orc_bbox[3], orc_bbox[1])


if __name__ == "__main__":
    unittest.main()
