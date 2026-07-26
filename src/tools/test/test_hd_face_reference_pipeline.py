import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class HdFaceReferencePipelineTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_reference_base_uses_human_facial_proportions_for_all_races(self):
        from src.tools.test.hd_face_reference_pipeline import create_reference_base

        bases = [create_reference_base(race, "D", 0, seed=1) for race in ("human", "elf", "orc")]
        self.assertTrue(all(base.size == (72, 68) for base in bases))
        self.assertTrue(all(base.mode == "RGBA" for base in bases))
        self.assertEqual(bases[0].getbbox(), bases[1].getbbox())
        self.assertEqual(bases[0].getbbox(), bases[2].getbbox())

    def test_orc_uses_top_ears_without_side_ear_geometry(self):
        from src.tools.test.hd_face_reference_pipeline import (
            build_reference_factors,
            create_reference_base,
            rasterize_reference_components,
            _compose,
        )

        orc_base = create_reference_base("orc", "D", 0, seed=1)
        orc = rasterize_reference_components(
            orc_base,
            "D",
            build_reference_factors("natural", "orc", seed=1),
            seed=1,
        )
        human = rasterize_reference_components(
            create_reference_base("human", "D", 0, seed=1),
            "D",
            build_reference_factors("natural", "human", seed=1),
            seed=1,
        )
        self.assertLess(orc.layers["ear"].getbbox()[1], 20)
        orc_composite = _compose(orc_base, orc, "orc")
        self.assertTrue(any(
            y < 32
            and pixel[3] > 0
            and pixel == orc.layers["ear"].getpixel((x, y))
            and pixel != orc_base.getpixel((x, y))
            for y in range(orc_composite.height)
            for x in range(orc_composite.width)
            for pixel in (orc_composite.getpixel((x, y)),)
        ))
        self.assertGreater(human.layers["ear"].getbbox()[1], 30)

    def test_reference_eye_and_brow_anchors_match_human_and_elf(self):
        from src.tools.test.hd_face_reference_pipeline import build_reference_factors, reference_anchors

        human = build_reference_factors("natural", "human", seed=1)
        elf = build_reference_factors("natural", "elf", seed=1)
        self.assertEqual(human["eye"], elf["eye"])
        self.assertEqual(human["brow"], elf["brow"])
        self.assertEqual(reference_anchors("D")["eye_centers"], ((24, 48), (46, 48)))
        self.assertEqual(reference_anchors("D")["brow_lines"], ((14, 28, 40), (42, 56, 40)))

    def test_generator_writes_reference_catalog_with_explicit_style_version(self):
        from src.tools.test.hd_face_reference_pipeline import generate_reference_catalog

        with TemporaryDirectory(prefix="face_hd_v2_", dir=self.project_root / "assets" / "test") as temp_dir:
            manifest = generate_reference_catalog(Path(temp_dir), seed=20260727)
            self.assertEqual(manifest["generator_version"], "hd_face_reference_pipeline_v2")
            self.assertEqual(manifest["catalog_count"], 12)
            self.assertEqual(set(manifest["frame_counts"].values()), {28})
            self.assertEqual(manifest["warning_count"], 0)
            self.assertEqual(manifest["texture_size"], {"width": 72, "height": 68})
            persisted = json.loads((Path(temp_dir) / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["generator_version"], "hd_face_reference_pipeline_v2")
            self.assertTrue((Path(temp_dir) / "README.md").is_file())


if __name__ == "__main__":
    unittest.main()
