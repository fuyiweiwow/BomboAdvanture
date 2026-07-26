import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from PIL import Image


class EyeVariantCatalogTests(unittest.TestCase):
    project_root = Path(r"E:\WorkProject\Bomb adventure\BomboAdvanture")

    def test_two_common_eye_shapes_apply_to_both_front_bases(self):
        from src.tools.test.eye_variant_pipeline import generate_eye_variants

        with TemporaryDirectory(prefix="eye_variants_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_eye_variants(output)

            self.assertEqual(
                manifest["variants"],
                ["set_a_reference_open", "set_b_round_open"],
            )
            self.assertEqual(manifest["roles"], ["male", "female"])

            for variant in manifest["variants"]:
                for role in manifest["roles"]:
                    role_dir = output / variant / role
                    for filename in (
                        "base.png",
                        "eye_geometry.png",
                        "pupil.png",
                        "highlight.png",
                        "eye.png",
                        "brow.png",
                        "ear.png",
                        "composite.png",
                        "preview.png",
                    ):
                        self.assertTrue((role_dir / filename).is_file(), f"{variant}/{role}/{filename}")
                    with Image.open(role_dir / "composite.png") as image:
                        self.assertEqual(image.size, (36, 34))
                    with Image.open(role_dir / "preview.png") as image:
                        self.assertEqual(image.size, (144, 136))
                    with Image.open(role_dir / "highlight.png") as image:
                        left_highlights = sum(
                            image.getpixel((x, y))[3] > 0
                            for y in range(image.height)
                            for x in range(image.width // 2)
                        )
                        right_highlights = sum(
                            image.getpixel((x, y))[3] > 0
                            for y in range(image.height)
                            for x in range(image.width // 2, image.width)
                        )
                        self.assertGreater(left_highlights, 0)
                        self.assertGreater(right_highlights, 0)
                        left_positions = [
                            x
                            for y in range(image.height)
                            for x in range(image.width // 2)
                            if image.getpixel((x, y))[3] > 0
                        ]
                        right_positions = [
                            x
                            for y in range(image.height)
                            for x in range(image.width // 2, image.width)
                            if image.getpixel((x, y))[3] > 0
                        ]
                        self.assertLess(sum(left_positions) / len(left_positions), 11.5)
                        self.assertLess(sum(right_positions) / len(right_positions), 23.5)

                self.assertEqual(
                    (output / variant / "male" / "eye.png").read_bytes(),
                    (output / variant / "female" / "eye.png").read_bytes(),
                )

            self.assertNotEqual(
                (output / "set_a_reference_open" / "male" / "eye.png").read_bytes(),
                (output / "set_b_round_open" / "male" / "eye.png").read_bytes(),
            )

            with Image.open(output / "set_a_reference_open" / "female" / "composite.png") as image:
                blush_pixels = [
                    image.getpixel((x, y))
                    for y in range(20, 32)
                    for x in range(6, 15)
                    if image.getpixel((x, y))[0] > image.getpixel((x, y))[1] + 20
                ]
                self.assertTrue(blush_pixels)

    def test_full_catalog_contains_all_motion_frames_and_keeps_back_eyes_empty(self):
        from src.tools.test.eye_variant_pipeline import generate_full_eye_variants

        with TemporaryDirectory(prefix="eye_variants_full_", dir=self.project_root / "assets" / "test") as temp_dir:
            output = Path(temp_dir)
            manifest = generate_full_eye_variants(output)

            self.assertEqual(manifest["frame_count"], {
                "set_a_reference_open": {"male": 28, "female": 28},
                "set_b_round_open": {"male": 28, "female": 28},
            })
            for variant in manifest["variants"]:
                for role in manifest["roles"]:
                    role_dir = output / variant / role
                    composites = sorted((role_dir / "composite").glob("*.png"))
                    eyes = sorted((role_dir / "eye").glob("*.png"))
                    self.assertEqual(len(composites), 28)
                    self.assertEqual(len(eyes), 28)
                    self.assertTrue((role_dir / "preview" / "catalog.png").is_file())
                    self.assertTrue((role_dir / "composite" / f"{('face10101' if role == 'male' else 'Face10701')}_stand_D_0.png").is_file())

                    with Image.open(role_dir / "eye" / f"{('face10101' if role == 'male' else 'Face10701')}_stand_U_0.png") as image:
                        self.assertIsNone(image.getbbox())
                    with Image.open(role_dir / "eye" / f"{('face10101' if role == 'male' else 'Face10701')}_walk_U_5.png") as image:
                        self.assertIsNone(image.getbbox())

                self.assertEqual(
                    (output / variant / "male" / "eye" / "face10101_stand_D_0.png").read_bytes(),
                    (output / variant / "female" / "eye" / "Face10701_stand_D_0.png").read_bytes(),
                )

            self.assertNotEqual(
                (output / "set_a_reference_open" / "male" / "eye" / "face10101_stand_D_0.png").read_bytes(),
                (output / "set_b_round_open" / "male" / "eye" / "face10101_stand_D_0.png").read_bytes(),
            )


if __name__ == "__main__":
    unittest.main()
