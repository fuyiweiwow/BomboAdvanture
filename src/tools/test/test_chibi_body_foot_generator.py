import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from src.tools.test.chibi_body_foot_generator import (
    DIRECTIONS,
    FRAME_SIZE,
    LAYERS,
    WALK_FRAMES,
    generate_body_foot_catalog,
)


class ChibiBodyFootGeneratorTests(unittest.TestCase):
    def setUp(self):
        self.temp_dirs = []

    def tearDown(self):
        for path in self.temp_dirs:
            shutil.rmtree(path, ignore_errors=True)

    def make_output_dir(self):
        path = Path(tempfile.mkdtemp(prefix="chibi_body_foot_"))
        self.temp_dirs.append(path)
        return path

    def test_manifest_declares_project_owned_short_body_contract(self):
        manifest = generate_body_foot_catalog(self.make_output_dir(), seed=7)

        self.assertEqual(manifest["generator_version"], "chibi_body_foot_v1")
        self.assertEqual(manifest["source"], "project_owned_redraw")
        self.assertEqual(manifest["frame_size"], {"width": 18, "height": 26})
        self.assertEqual(manifest["layers"], list(LAYERS))
        self.assertEqual(manifest["directions"], list(DIRECTIONS))
        self.assertEqual(manifest["walk_frame_count"], WALK_FRAMES)
        self.assertEqual(manifest["style_contract"]["mouth"], "not_present_in_body_or_foot")
        self.assertEqual(manifest["style_contract"]["body_height_limit"], 12)
        self.assertEqual(manifest["style_contract"]["foot_height_limit"], 7)

    def test_all_layers_have_fixed_canvas_and_expected_frame_count(self):
        output_dir = self.make_output_dir()
        manifest = generate_body_foot_catalog(output_dir, seed=11)

        for layer in LAYERS:
            layer_dir = output_dir / layer
            stand = sorted(layer_dir.glob(f"{layer}_short_v1_stand_*.png"))
            walk = sorted(layer_dir.glob(f"{layer}_short_v1_walk_*.png"))
            self.assertEqual(len(stand), len(DIRECTIONS))
            self.assertEqual(len(walk), len(DIRECTIONS) * WALK_FRAMES)
            for path in stand + walk:
                with Image.open(path) as image:
                    self.assertEqual(image.size, FRAME_SIZE)
                    self.assertEqual(image.mode, "RGBA")

        self.assertEqual(
            manifest["frame_counts"],
            {"stand_per_direction": 1, "walk_per_direction": WALK_FRAMES},
        )

    def test_body_and_foot_are_short_separate_layers(self):
        output_dir = self.make_output_dir()
        generate_body_foot_catalog(output_dir, seed=13)
        body_path = output_dir / "body" / "body_short_v1_stand_D_0.png"
        foot_path = output_dir / "foot" / "foot_short_v1_stand_D_0.png"

        with Image.open(body_path) as body, Image.open(foot_path) as foot:
            self.assertLessEqual(body.getbbox()[3] - body.getbbox()[1], 12)
            self.assertLessEqual(foot.getbbox()[3] - foot.getbbox()[1], 7)
            self.assertLess(body.getbbox()[3], FRAME_SIZE[1])
            self.assertLess(foot.getbbox()[3], FRAME_SIZE[1])
            self.assertNotEqual(body.getbbox(), foot.getbbox())

    def test_same_seed_produces_same_pngs_and_manifest(self):
        first_dir = self.make_output_dir()
        second_dir = self.make_output_dir()
        generate_body_foot_catalog(first_dir, seed=19)
        generate_body_foot_catalog(second_dir, seed=19)

        first_manifest = json.loads((first_dir / "manifest.json").read_text(encoding="utf-8"))
        second_manifest = json.loads((second_dir / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(first_manifest, second_manifest)
        for layer in LAYERS:
            paths = sorted((first_dir / layer).glob("*.png"))
            for first_path in paths:
                second_path = second_dir / layer / first_path.name
                self.assertEqual(
                    hashlib.sha256(first_path.read_bytes()).hexdigest(),
                    hashlib.sha256(second_path.read_bytes()).hexdigest(),
                )


if __name__ == "__main__":
    unittest.main()
