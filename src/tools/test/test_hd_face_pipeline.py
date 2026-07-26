import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class HdFacePipelineTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_four_presets_cover_three_races_and_elf_keeps_normal_face(self):
        from src.tools.test.hd_face_pipeline import PRESETS, RACES, build_preset_factors

        self.assertEqual(PRESETS, ("natural", "gentle", "focused", "bold"))
        self.assertEqual(RACES, ("human", "elf", "orc"))
        for preset in PRESETS:
            human = build_preset_factors(preset, "human", seed=1)
            elf = build_preset_factors(preset, "elf", seed=1)
            orc = build_preset_factors(preset, "orc", seed=1)
            self.assertEqual(human["brow"], elf["brow"])
            self.assertEqual(human["eye"], elf["eye"])
            self.assertNotEqual(human["ear"], elf["ear"])
            self.assertEqual(orc["ear"]["placement"], "top")
        self.assertEqual(build_preset_factors("natural", "elf", 1)["eye"]["size"], "normal")

    def test_hd_base_is_72_by_68_and_not_a_scaled_legacy_face(self):
        from src.tools.test.hd_face_pipeline import create_hd_base

        hd_base = create_hd_base("human", "D", 0, pixel_scale=2, seed=1)
        self.assertEqual(hd_base.size, (72, 68))
        self.assertEqual(hd_base.mode, "RGBA")
        self.assertIsNotNone(hd_base.getbbox())

        legacy = Image.open(
            self.project_root
            / "assets"
            / "test"
            / "face_bases_v1"
            / "male"
            / "base"
            / "face10101_stand_D_0.png"
        ).convert("RGBA")
        scaled_legacy = legacy.resize((72, 68), Image.Resampling.NEAREST)
        self.assertNotEqual(
            list(hd_base.get_flattened_data()),
            list(scaled_legacy.get_flattened_data()),
        )

    def test_orc_ear_is_top_placed_and_elf_ear_is_side_placed(self):
        from src.tools.test.hd_face_pipeline import (
            build_preset_factors,
            create_hd_base,
            rasterize_hd_components,
        )

        elf_base = create_hd_base("elf", "D", 0, pixel_scale=2, seed=1)
        orc_base = create_hd_base("orc", "D", 0, pixel_scale=2, seed=1)
        elf_result = rasterize_hd_components(elf_base, "D", build_preset_factors("natural", "elf", 1), seed=1)
        orc_result = rasterize_hd_components(orc_base, "D", build_preset_factors("natural", "orc", 1), seed=1)
        self.assertLess(elf_result.layers["ear"].getbbox()[0], elf_base.width // 4)
        self.assertLess(orc_result.layers["ear"].getbbox()[1], orc_base.height // 4)

    def test_elf_ears_are_longer_than_human_ears_and_natural_brow_stays_thin(self):
        from src.tools.test.hd_face_pipeline import (
            build_preset_factors,
            create_hd_base,
            rasterize_hd_components,
        )

        human_base = create_hd_base("human", "D", 0, pixel_scale=2, seed=1)
        elf_base = create_hd_base("elf", "D", 0, pixel_scale=2, seed=1)
        human_result = rasterize_hd_components(human_base, "D", build_preset_factors("natural", "human", 1), seed=1)
        elf_result = rasterize_hd_components(elf_base, "D", build_preset_factors("natural", "elf", 1), seed=1)
        human_ear_width = human_result.layers["ear"].getbbox()[2] - human_result.layers["ear"].getbbox()[0]
        elf_ear_width = elf_result.layers["ear"].getbbox()[2] - elf_result.layers["ear"].getbbox()[0]
        self.assertLess(human_ear_width, elf_ear_width)
        brow_box = human_result.layers["brow"].getbbox()
        self.assertLessEqual(brow_box[3] - brow_box[1], 4)

    def test_ear_profiles_vary_by_preset_while_preserving_race_placement(self):
        from src.tools.test.hd_face_pipeline import PRESETS, build_preset_factors

        for race, placement in (("human", "side"), ("elf", "side"), ("orc", "top")):
            ears = [build_preset_factors(preset, race, 1)["ear"] for preset in PRESETS]
            self.assertEqual({ear["style"] for ear in ears}, {"rounded", "soft", "sharp", "broad"})
            self.assertEqual({ear["placement"] for ear in ears}, {placement})
            self.assertNotEqual(ears[0]["length"], ears[-1]["length"])

    def test_generator_writes_twelve_catalogs_with_28_frames_each(self):
        from src.tools.test.hd_face_pipeline import generate_hd_catalog

        with TemporaryDirectory(prefix="face_hd_catalog_", dir=self.project_root / "assets" / "test") as temp_dir:
            output_dir = Path(temp_dir)
            manifest = generate_hd_catalog(output_dir, seed=20260726)
            self.assertEqual(manifest["catalog_count"], 12)
            self.assertEqual(set(manifest["frame_counts"].values()), {28})
            self.assertEqual(manifest["pixel_scale"], 2)
            self.assertEqual(manifest["texture_size"], {"width": 72, "height": 68})
            self.assertEqual(manifest["warning_count"], 0)
            self.assertTrue((output_dir / "manifest.json").is_file())
            self.assertTrue((output_dir / "presets.json").is_file())
            persisted = json.loads((output_dir / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["catalog_count"], 12)


if __name__ == "__main__":
    unittest.main()
